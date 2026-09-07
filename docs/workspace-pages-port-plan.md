# Workspace Pages (#4766) — port plan onto v0.64.22

Status: commit 1 (clean-merge resolutions) landed. `Sources/Workspace.swift` and
`Sources/TerminalController.swift` still need the page layer ported against
v0.64.22's current architecture. This file is the working plan for that port.

Do not resurrect #4766's merge-base versions of `sessionSnapshot()` /
`restoreSessionSnapshot()`. v0.64.22 rewrote both; the page layer must be folded
into the v0.64.22 versions.

## Reference material

- #4766 net Workspace.swift diff vs its merge-base: `/tmp/port/Workspace.pr4766.diff`
  (also reproducible: `git diff $(git merge-base pr-4766 v0.64.22) pr-4766 -- Sources/Workspace.swift`).
- #4766 net TerminalController.swift diff: `git diff $(git merge-base pr-4766 v0.64.22) pr-4766 -- Sources/TerminalController.swift`.
- Annotated Workspace conflict hunks from the merge attempt: `/tmp/port/ws_hunks.txt`.
- Spec: `docs/workspace-pages-spec.md`.

## v0.64.22 architecture deltas that matter

| #4766 assumed | v0.64.22 reality |
| --- | --- |
| `sessionLayoutSnapshot(from: tree)` builds the raw layout | `SessionSplitContainerLayoutCodec(controller: bonsplitController).snapshot(panelIdForTabId:)` (Workspace.swift ~L80) |
| `applySessionDividerPositions(snapshotNode:liveNode:)` | `SessionSplitContainerLayoutCodec(controller: bonsplitController).applyDividerPositions(...)` (Workspace.swift ~L269) |
| `restoreSessionSnapshot(_:)` | `restoreSessionSnapshot(_ snapshot:excludingStableIdentities:)` (Workspace.swift L193) |
| `SessionWorkspaceSnapshot.init(workspaceId:processTitle:...)` short list | init now also takes `stableId`, `taskCreateOperationID`, `customTitleSource`, `environment`, `taskStatusOverride`, `taskStatusInferredAtOverride`, `taskStatusHidden`, `checklist`, `dock` |
| `reconcileSurfaceResumeBindings(using:)` | `reconcileSurfaceResumeBindings(using:restorableAgentIndex:)` |
| `restoredSessionNotifications(from:oldToNewPanelIds:)` | same signature in v0.64.22 (L~1958 area); #4766 adds `activePageState:` — keep #4766's added param, thread it through |
| `Self.shouldAutoConnectRestoredRemote(...)` | now `sessionRestorePolicy.shouldAutoConnectRestoredRemote(...)` |
| title/desc/color/pin/group restored inline | `restoreTitleState(from:restoredPanelIds:)`, `restoreTodoState(from:)` |
| `terminalInheritanceFontPointsByPanelId` on Workspace | RENAMED/moved in the `WorkspaceTerminalFontSize*` coordinator refactor — locate the current equivalent before using it in `StoredPageState.RuntimeState` |
| `metadataBlocks`, `pullRequest`, `panelPullRequests` reset inline in restore | still exist on Workspace (verified) |

Types the page code needs — all still exist, some moved to packages:
`DetachedSurfaceTransfer` (`Sources/Workspace+DetachedSurfaceTransfer.swift`),
`SidebarStatusEntry` / `SidebarMetadataBlock` / `SidebarLogEntry` /
`SidebarProgressState` / `SidebarGitBranchState` / `SidebarPullRequestState`
(`Packages/macOS/CmuxSidebar/...`), `PanelShellActivityState`
(`Packages/macOS/CmuxWorkspaces/.../Core/Values/PanelShellActivityState.swift`).

APIs the page code calls — all present (verified): `detachSurface`,
`attachDetachedSurface`, `hideAllTerminalPortalViews`,
`hideAllBrowserPortalViews`, `restoreSessionLayout`, `closePanel`,
`reorderSurface`, `sidebarOrderedPanelIds`, `withClosedPanelHistorySuppressed`,
`normalizePinnedTabs`, `recomputeListeningPorts`,
`createReplacementTerminalPanel`, `surfaceIdFromPanelId`, `panelIdFromSurfaceId`,
`requestBackgroundPrimeTerminalSurfaceStartIfNeeded` (already on Workspace at
~L4603 — #4766 only calls it, does not redefine), `syncRemotePortScanTTYs`,
`focusPanel`, `scheduleFocusReconcile`, `syncUnreadBadgeStateForAllPanels`,
`syncUnreadBadgeStateForPanel`, `pruneSurfaceMetadata`.

## Port steps (each should build before moving on)

1. **Model types** (pure additions, near end of file / in the `final class
   Workspace` body):
   - `struct WorkspacePage: Identifiable, Equatable { let id: UUID; var title: String }`
   - `private struct StoredPageState { struct RuntimeState { ... }; var sessionState: SessionWorkspacePageStateSnapshot; var runtimeState: RuntimeState? }`
     — fix `terminalInheritanceFontPointsByPanelId` to the current name.
   - `@Published private(set) var pages: [WorkspacePage]`, `@Published private(set) var activePageId: UUID`
   - `private var storedPageStates: [UUID: StoredPageState] = [:]`, `private var nextAutoPageNumber: Int = 2`
   - `Workspace.init`: seed `initialPage`, set `self.pages = [initialPage]`,
     `self.activePageId = initialPage.id`. Do NOT take #4766's `self.id = UUID()`
     line wholesale — keep v0.64.22's `self.id = id ?? UUID()` and injected
     services; only add the two page lines.
   - `enum SurfaceKind` / `enum PanelShellActivityState` in the #4766 hunk at
     old-L10701: check whether v0.64.22 already declares these (decomposition may
     own them) before adding — likely SKIP, they moved to CmuxWorkspaces.

2. **`currentPageSessionStateSnapshot(includeScrollback:restorableAgentIndex:surfaceResumeBindingIndex:) -> SessionWorkspacePageStateSnapshot`**
   — extract the per-page body from v0.64.22's `sessionSnapshot()`: everything
   that builds `layout` / `panels` / `statusEntries` / `logEntries` / `progress`
   / `gitBranch` / `focusedPanelId` / `currentDirectory`, using
   `SessionSplitContainerLayoutCodec`. Return a `SessionWorkspacePageStateSnapshot`,
   not a `SessionWorkspaceSnapshot`.

3. **Rewrite `sessionSnapshot()`** to: call `currentPageSessionStateSnapshot`
   for the active page, map `pages` to `SessionWorkspacePageSnapshot` (active =
   fresh, inactive = `exportedPageStateSnapshot(storedPageStates[id].sessionState)`
   or `emptyPageSessionStateSnapshot`), then build the `SessionWorkspaceSnapshot`
   with v0.64.22's full init param list PLUS `activePageId:` and `pages:`, sourcing
   the legacy top-level `currentDirectory`/`focusedPanelId`/`layout`/`panels`/
   `statusEntries`/`logEntries`/`progress`/`gitBranch` fields from the active
   page snapshot (mirror for old consumers, per spec §Persistence item 11).

4. **Helpers** (from #4766, adapt bodies): `exportedPageStateSnapshot`,
   `emptyPageSessionStateSnapshot`, `legacyPageStateSnapshot(from:)`,
   `sessionLayoutSnapshot`/`prunedSessionLayoutSnapshot`/`sessionPanelIDs`/
   `sessionPanelID(forExternalTabIDString:)`/`sessionSurfaceUUID` — v0.64.22 may
   already have equivalents via the codec; prefer reusing the codec over adding
   these. `collapseBonsplitToSinglePaneForSessionRestore`.

5. **`restoreSessionPageState(_ snapshot: SessionWorkspacePageStateSnapshot, snapshotWorkspaceId: UUID? = nil) -> [UUID: UUID]`**
   — carve from v0.64.22's `restoreSessionSnapshot` body: the layout restore +
   per-pane surface restore + divider apply + focus reconcile, minus the
   workspace-level title/notify/remote handling. Use
   `SessionSplitContainerLayoutCodec(...).applyDividerPositions`.

6. **Rewrite `restoreSessionSnapshot(_:excludingStableIdentities:)`** to be
   page-aware: build `restoredPages` (fallback to `legacyPageStateSnapshot` when
   `snapshot.pages` empty), make `WorkspacePage` models, set `pages` /
   `activePageId` / `nextAutoPageNumber`, `restoreSessionPageState` the active
   one, stash the rest in `storedPageStates`, keep v0.64.22's remote-config
   restore, `restoreTitleState`, `restoreTodoState`, `sessionRestorePolicy`,
   manual-unread + notification restore (threading `activePageState:` into
   `restoredSessionNotifications`).

7. **Page lifecycle methods** (from #4766, ~L11550 hunk, mostly clean additions):
   `activePage`, `activePageIndex`, `pageIndex`, `pageTitle`, `pageStateSnapshot`,
   `pageStructureSummary`, `canClosePage`, `newPage`, `duplicatePage`,
   `selectPage`, `selectNextPage`/`selectPreviousPage`/`selectPage(at:)`/
   `selectLastPage`, `movePage`/`movePageLeft`/`movePageRight`, `setPageTitle`,
   `closePage`, `closeOtherPages`, title helpers, `duplicatedPageStateSnapshot`/
   `duplicatedPageLayoutSnapshot`, `captureActivePageStoredState`,
   `detachAllLivePanelsForPageSwitch`, `restoreStoredPage`,
   `restorePageSwitchNotifications`, `identityPanelIdMap`,
   `canRestoreRuntimeLayout` + `runtimeLayoutPanelIds`, `restoreRuntimePageState`,
   `runtimePageRestoreSelectedPanelId`, `teardownStoredPageState`,
   `teardownDetachedSurfaces`, `promptRenamePage`. Fix `applySessionDividerPositions`
   → codec, `terminalInheritanceFontPointsByPanelId` → current name.

8. **Teardown**: in v0.64.22's Workspace teardown/`prepareForRemoval` path add
   `teardownStoredPageStates()` + `storedPageStates.removeAll()` (#4766 hunk at
   old-L15501).

9. **TerminalController.swift**: port the v2 socket `page.*` handlers
   (`page.list/current/create/duplicate/select/rename/close/reorder/next/previous/last`),
   `system.tree` page nesting (`workspace -> page -> pane -> surface`, keep
   selected page mirrored into legacy `panes`), and `system.identify`
   `page_id`/`page_ref`/`page_index`/`page_title`. Adapt to v0.64.22's socket
   dispatch structure (two command switches; see `CLI/cmux.swift` resolution).
   Verify `parsePageCommandContextOptions` / `resolvePageCommandContext` /
   `applyPageCommandContext` helpers referenced by `CLI/cmux.swift` are ported
   (they live in the TerminalController/socket side in #4766).

10. **Verify auto-merged wiring** still lines up: page menu items in
    `Sources/cmuxApp.swift` + `Sources/AppDelegate.swift`, shortcut routing in
    `cmuxTests/AppDelegateShortcutRoutingTests.swift`. They call the Workspace
    page API added above.

11. Build loop: `xcodebuild -project cmux.xcodeproj -scheme cmux -configuration
    Debug -destination 'platform=macOS' -derivedDataPath /tmp/cmux-wp4766 build`
    (GhosttyKit via `./scripts/setup.sh` first). Then
    `./scripts/lint-pbxproj-test-wiring.sh`.

## Open decisions (resolve during port, mark `// PORT-TODO(#4766):`)

- Whether `SurfaceKind` / `PanelShellActivityState` are re-declared by #4766 or
  already owned by `CmuxWorkspaces` in v0.64.22 (skip the re-declaration if so).
- The exact current name for `terminalInheritanceFontPointsByPanelId` after the
  font-size coordinator refactor.
- Whether v0.64.22's codec already exposes a page-usable layout snapshot such
  that #4766's `sessionLayoutSnapshot` family can be dropped entirely.
