import AppKit
import CmuxControlSocket
import Foundation

/// The page-domain witnesses (workspace-pages, see
/// docs/workspace-pages-spec.md), ported from PR #4766's
/// `TerminalController.v2Page*` bodies onto the ``ControlPageContext`` seam.
/// Mirrors the shape of `TerminalController+ControlWorkspaceContext.swift`:
/// resolve a TabManager/Workspace from the routing selectors (now page-id
/// aware via `resolveWorkspace(routing:tabManager:)`), then read/mutate the
/// workspace's page list.
extension TerminalController: ControlPageContext {
    /// Resolves the workspace a routed page command targets within an
    /// already-resolved TabManager. A private, file-scoped twin of the
    /// identically-named helper in `TerminalController+ControlWorkspaceContext.swift`
    /// (Swift's per-file `private` means the two coexist without conflict);
    /// duplicated rather than shared because that helper is `private` there
    /// too, matching every other domain file's (Notification, Pane, …) own
    /// copy of this exact precedence walk.
    private func resolveWorkspace(
        routing: ControlRoutingSelectors,
        tabManager: TabManager
    ) -> Workspace? {
        if let workspaceId = routing.workspaceID {
            return tabManager.tabs.first(where: { $0.id == workspaceId })
        }
        if let pageId = routing.pageID,
           let located = v2LocatePage(pageId) {
            guard located.tabManager === tabManager else { return nil }
            return located.workspace
        }
        if let surfaceId = routing.surfaceID {
            return tabManager.tabs.first(where: { $0.panels[surfaceId] != nil })
        }
        if let paneId = routing.paneID,
           let located = v2LocatePane(paneId) {
            guard located.tabManager === tabManager else { return nil }
            return located.workspace
        }
        guard let workspaceId = tabManager.selectedTabId else { return nil }
        return tabManager.tabs.first(where: { $0.id == workspaceId })
    }

    private func pageSummary(_ page: WorkspacePage, workspace: Workspace) -> ControlPageSummary {
        let structure = workspace.pageStructureSummary(pageId: page.id)
        return ControlPageSummary(
            id: page.id,
            title: page.title,
            paneCount: structure?.paneCount ?? 0,
            surfaceCount: structure?.surfaceCount ?? 0
        )
    }

    /// Brings the workspace's owning window forward and selects it, mirroring
    /// `controlSelectWorkspace`'s focus handling.
    private func focusAndSelectWorkspace(_ tabManager: TabManager, workspace: Workspace) -> UUID? {
        let windowId = AppDelegate.shared?.windowId(for: tabManager)
        if let windowId {
            _ = AppDelegate.shared?.focusMainWindow(windowId: windowId)
            setActiveTabManager(tabManager)
        }
        tabManager.selectWorkspace(workspace)
        return windowId
    }

    // MARK: - page.list / page.current

    func controlPageList(routing: ControlRoutingSelectors) -> ControlPageListResolution {
        guard let tabManager = resolveTabManager(routing: routing) else {
            return .tabManagerUnavailable
        }
        guard let workspace = resolveWorkspace(routing: routing, tabManager: tabManager) else {
            return .workspaceNotFound
        }
        let windowId = AppDelegate.shared?.windowId(for: tabManager)
        let pages = workspace.pages.map { pageSummary($0, workspace: workspace) }
        return .resolved(windowID: windowId, workspaceID: workspace.id, pages: pages, selectedPageID: workspace.activePageId)
    }

    func controlPageCurrent(routing: ControlRoutingSelectors) -> ControlPageMutationResolution {
        guard let tabManager = resolveTabManager(routing: routing) else {
            return .tabManagerUnavailable
        }
        guard let workspace = resolveWorkspace(routing: routing, tabManager: tabManager) else {
            return .workspaceNotFound
        }
        guard let page = workspace.activePage else { return .pageNotFound(pageID: nil) }
        let windowId = AppDelegate.shared?.windowId(for: tabManager)
        return .resolved(
            windowID: windowId,
            workspaceID: workspace.id,
            page: pageSummary(page, workspace: workspace),
            index: workspace.activePageIndex
        )
    }

    // MARK: - page.create / page.duplicate

    func controlPageCreate(
        routing: ControlRoutingSelectors,
        title: String?,
        select: Bool
    ) -> ControlPageMutationResolution {
        guard let tabManager = resolveTabManager(routing: routing) else {
            return .tabManagerUnavailable
        }
        guard let workspace = resolveWorkspace(routing: routing, tabManager: tabManager) else {
            return .workspaceNotFound
        }
        let windowId = select
            ? focusAndSelectWorkspace(tabManager, workspace: workspace)
            : AppDelegate.shared?.windowId(for: tabManager)
        let page = workspace.newPage(select: select)
        if let title {
            workspace.setPageTitle(pageId: page.id, title: title)
        }
        guard let created = workspace.pages.first(where: { $0.id == page.id }) else {
            return .pageNotFound(pageID: page.id)
        }
        return .resolved(
            windowID: windowId,
            workspaceID: workspace.id,
            page: pageSummary(created, workspace: workspace),
            index: workspace.pageIndex(pageId: page.id)
        )
    }

    func controlPageDuplicate(
        routing: ControlRoutingSelectors,
        pageID: UUID?,
        title: String?,
        select: Bool
    ) -> ControlPageMutationResolution {
        guard let tabManager = resolveTabManager(routing: routing) else {
            return .tabManagerUnavailable
        }
        guard let workspace = resolveWorkspace(routing: routing, tabManager: tabManager) else {
            return .workspaceNotFound
        }
        let sourcePageId = pageID ?? workspace.activePageId
        guard workspace.pageIndex(pageId: sourcePageId) != nil else {
            return .pageNotFound(pageID: pageID)
        }
        let windowId = select
            ? focusAndSelectWorkspace(tabManager, workspace: workspace)
            : AppDelegate.shared?.windowId(for: tabManager)
        guard let page = workspace.duplicatePage(sourcePageId: sourcePageId, select: select, title: title) else {
            return .pageNotFound(pageID: sourcePageId)
        }
        return .resolved(
            windowID: windowId,
            workspaceID: workspace.id,
            page: pageSummary(page, workspace: workspace),
            index: workspace.pageIndex(pageId: page.id)
        )
    }

    // MARK: - page.select

    func controlSelectPage(
        routing: ControlRoutingSelectors,
        pageID: UUID
    ) -> ControlPageMutationResolution {
        guard let tabManager = resolveTabManager(routing: routing) else {
            return .tabManagerUnavailable
        }
        guard let workspace = resolveWorkspace(routing: routing, tabManager: tabManager) else {
            return .workspaceNotFound
        }
        guard workspace.pageIndex(pageId: pageID) != nil else {
            return .pageNotFound(pageID: pageID)
        }
        let windowId = focusAndSelectWorkspace(tabManager, workspace: workspace)
        workspace.selectPage(pageID)
        guard let page = workspace.activePage else { return .pageNotFound(pageID: pageID) }
        return .resolved(
            windowID: windowId,
            workspaceID: workspace.id,
            page: pageSummary(page, workspace: workspace),
            index: workspace.activePageIndex
        )
    }

    // MARK: - page.close

    func controlClosePage(
        routing: ControlRoutingSelectors,
        pageID: UUID?,
        force: Bool
    ) -> ControlPageCloseResolution {
        guard let tabManager = resolveTabManager(routing: routing) else {
            return .tabManagerUnavailable
        }
        guard let workspace = resolveWorkspace(routing: routing, tabManager: tabManager) else {
            return .workspaceNotFound
        }
        let targetPageId = pageID ?? workspace.activePageId
        guard workspace.pageIndex(pageId: targetPageId) != nil else {
            return .pageNotFound(pageID: pageID)
        }
        guard workspace.canClosePage(targetPageId) else {
            return .cannotCloseLastPage(pageID: targetPageId)
        }
        let windowId = AppDelegate.shared?.windowId(for: tabManager)
        workspace.closePage(targetPageId, skipConfirmation: force)
        // `canClosePage` guarantees >1 page existed, so a page always remains
        // selected after close.
        guard let selectedPage = workspace.activePage else {
            return .pageNotFound(pageID: nil)
        }
        return .resolved(
            windowID: windowId,
            workspaceID: workspace.id,
            closedPageID: targetPageId,
            selectedPage: pageSummary(selectedPage, workspace: workspace)
        )
    }

    // MARK: - page.reorder

    func controlReorderPage(
        routing: ControlRoutingSelectors,
        pageID: UUID,
        toIndex: Int?,
        beforePageID: UUID?,
        afterPageID: UUID?
    ) -> ControlPageReorderResolution {
        guard let tabManager = resolveTabManager(routing: routing) else {
            return .tabManagerUnavailable
        }
        guard let workspace = resolveWorkspace(routing: routing, tabManager: tabManager) else {
            return .workspaceNotFound
        }
        guard let currentIndex = workspace.pageIndex(pageId: pageID) else {
            return .pageNotFound(pageID: pageID)
        }

        let moved: Bool
        if let toIndex {
            moved = workspace.movePage(pageId: pageID, toIndex: toIndex)
        } else if let beforePageID {
            guard let beforeIndex = workspace.pageIndex(pageId: beforePageID) else {
                return .anchorNotFound(anchorPageID: beforePageID, pageID: pageID)
            }
            let targetIndex = currentIndex < beforeIndex ? beforeIndex - 1 : beforeIndex
            moved = workspace.movePage(pageId: pageID, toIndex: targetIndex)
        } else if let afterPageID {
            guard let afterIndex = workspace.pageIndex(pageId: afterPageID) else {
                return .anchorNotFound(anchorPageID: afterPageID, pageID: pageID)
            }
            let targetIndex = currentIndex < afterIndex + 1 ? afterIndex : afterIndex + 1
            moved = workspace.movePage(pageId: pageID, toIndex: targetIndex)
        } else {
            moved = false
        }

        guard moved else { return .cannotReorderSinglePage(pageID: pageID) }
        guard let page = workspace.pages.first(where: { $0.id == pageID }) else {
            return .pageNotFound(pageID: pageID)
        }
        let windowId = AppDelegate.shared?.windowId(for: tabManager)
        return .resolved(
            windowID: windowId,
            workspaceID: workspace.id,
            page: pageSummary(page, workspace: workspace),
            index: workspace.pageIndex(pageId: pageID) ?? currentIndex
        )
    }

    // MARK: - page.rename

    func controlRenamePage(
        routing: ControlRoutingSelectors,
        pageID: UUID?,
        title: String
    ) -> ControlPageMutationResolution {
        guard let tabManager = resolveTabManager(routing: routing) else {
            return .tabManagerUnavailable
        }
        guard let workspace = resolveWorkspace(routing: routing, tabManager: tabManager) else {
            return .workspaceNotFound
        }
        let targetPageId = pageID ?? workspace.activePageId
        guard workspace.pageIndex(pageId: targetPageId) != nil else {
            return .pageNotFound(pageID: pageID)
        }
        workspace.setPageTitle(pageId: targetPageId, title: title)
        guard let page = workspace.pages.first(where: { $0.id == targetPageId }) else {
            return .pageNotFound(pageID: pageID)
        }
        let windowId = AppDelegate.shared?.windowId(for: tabManager)
        return .resolved(
            windowID: windowId,
            workspaceID: workspace.id,
            page: pageSummary(page, workspace: workspace),
            index: workspace.pageIndex(pageId: targetPageId)
        )
    }

    // MARK: - Navigation

    func controlSelectNextPage(routing: ControlRoutingSelectors) -> ControlPageMutationResolution {
        navigatePage(routing: routing) { $0.selectNextPage() }
    }

    func controlSelectPreviousPage(routing: ControlRoutingSelectors) -> ControlPageMutationResolution {
        navigatePage(routing: routing) { $0.selectPreviousPage() }
    }

    func controlSelectLastPage(routing: ControlRoutingSelectors) -> ControlPageMutationResolution {
        navigatePage(routing: routing) { $0.selectLastPage() }
    }

    private func navigatePage(
        routing: ControlRoutingSelectors,
        _ navigate: (Workspace) -> Void
    ) -> ControlPageMutationResolution {
        guard let tabManager = resolveTabManager(routing: routing) else {
            return .tabManagerUnavailable
        }
        guard let workspace = resolveWorkspace(routing: routing, tabManager: tabManager) else {
            return .workspaceNotFound
        }
        let windowId = focusAndSelectWorkspace(tabManager, workspace: workspace)
        navigate(workspace)
        guard let page = workspace.activePage else { return .pageNotFound(pageID: nil) }
        return .resolved(
            windowID: windowId,
            workspaceID: workspace.id,
            page: pageSummary(page, workspace: workspace),
            index: workspace.activePageIndex
        )
    }
}
