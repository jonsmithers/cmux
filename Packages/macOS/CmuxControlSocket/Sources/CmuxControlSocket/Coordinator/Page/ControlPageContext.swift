public import Foundation

/// The page-domain slice of the control-command seam (a constituent of the
/// ``ControlCommandContext`` umbrella), covering the `page.*` methods added by
/// the workspace-pages feature (see docs/workspace-pages-spec.md).
///
/// A "page" is a titlebar-level layout inside a workspace: a workspace keeps
/// one live Bonsplit controller and swaps a page's layout/panel state in and
/// out around it, so only the active page is "live" at any time. The app
/// target (today `TerminalController`) conforms by resolving a
/// `TabManager`/`Workspace` from the routing selectors (which now also
/// support a `page_id` selector, resolved by containment) and reading/
/// mutating the workspace's page list.
///
/// No app types (`TabManager` / `Workspace`) cross the seam: each method takes
/// pre-parsed selectors/ids/inputs and returns Sendable resolution enums.
@MainActor
public protocol ControlPageContext: AnyObject {
    /// Snapshots every page of the resolved workspace for `page.list`.
    ///
    /// - Parameter routing: The routing selectors used for TabManager +
    ///   workspace resolution.
    /// - Returns: The list resolution.
    func controlPageList(routing: ControlRoutingSelectors) -> ControlPageListResolution

    /// Reads the resolved workspace's active page for `page.current`.
    ///
    /// - Parameter routing: The routing selectors used for TabManager +
    ///   workspace resolution.
    /// - Returns: The mutation resolution (no mutation; carries the active
    ///   page).
    func controlPageCurrent(routing: ControlRoutingSelectors) -> ControlPageMutationResolution

    /// Creates a page in the resolved workspace for `page.create`.
    ///
    /// - Parameters:
    ///   - routing: The routing selectors used for TabManager + workspace
    ///     resolution.
    ///   - title: The requested title, if any (falls back to the default
    ///     `Page N` title).
    ///   - select: Whether to focus the window/workspace and select the new
    ///     page (already through the app's focus-allowance gate app-side).
    /// - Returns: The mutation resolution.
    func controlPageCreate(
        routing: ControlRoutingSelectors,
        title: String?,
        select: Bool
    ) -> ControlPageMutationResolution

    /// Duplicates a page in the resolved workspace for `page.duplicate`.
    ///
    /// - Parameters:
    ///   - routing: The routing selectors used for TabManager + workspace
    ///     resolution.
    ///   - pageID: The source page id, or `nil` to duplicate the active page.
    ///   - title: The requested title, if any (falls back to a "Copy" suffix
    ///     of the source title).
    ///   - select: Whether to focus the window/workspace and select the new
    ///     page.
    /// - Returns: The mutation resolution.
    func controlPageDuplicate(
        routing: ControlRoutingSelectors,
        pageID: UUID?,
        title: String?,
        select: Bool
    ) -> ControlPageMutationResolution

    /// Selects a page in the resolved workspace for `page.select` (focuses the
    /// owning window/workspace when it belongs to another one).
    ///
    /// - Parameters:
    ///   - routing: The routing selectors used for TabManager + workspace
    ///     resolution.
    ///   - pageID: The page to select.
    /// - Returns: The mutation resolution.
    func controlSelectPage(
        routing: ControlRoutingSelectors,
        pageID: UUID
    ) -> ControlPageMutationResolution

    /// Closes a page in the resolved workspace for `page.close`, honoring the
    /// last-page-protection guard.
    ///
    /// - Parameters:
    ///   - routing: The routing selectors used for TabManager + workspace
    ///     resolution.
    ///   - pageID: The page to close, or `nil` to close the active page.
    ///   - force: Whether to skip the close confirmation.
    /// - Returns: The close resolution.
    func controlClosePage(
        routing: ControlRoutingSelectors,
        pageID: UUID?,
        force: Bool
    ) -> ControlPageCloseResolution

    /// Reorders a page in the resolved workspace for `page.reorder`.
    ///
    /// - Parameters:
    ///   - routing: The routing selectors used for TabManager + workspace
    ///     resolution.
    ///   - pageID: The page to move.
    ///   - toIndex: The absolute target index, if provided.
    ///   - beforePageID: The peer to move before, if provided.
    ///   - afterPageID: The peer to move after, if provided.
    /// - Returns: The reorder resolution.
    func controlReorderPage(
        routing: ControlRoutingSelectors,
        pageID: UUID,
        toIndex: Int?,
        beforePageID: UUID?,
        afterPageID: UUID?
    ) -> ControlPageReorderResolution

    /// Renames a page in the resolved workspace for `page.rename`.
    ///
    /// - Parameters:
    ///   - routing: The routing selectors used for TabManager + workspace
    ///     resolution.
    ///   - pageID: The page to rename, or `nil` to rename the active page.
    ///   - title: The new title.
    /// - Returns: The mutation resolution.
    func controlRenamePage(
        routing: ControlRoutingSelectors,
        pageID: UUID?,
        title: String
    ) -> ControlPageMutationResolution

    /// Selects the next page for `page.next`.
    ///
    /// - Parameter routing: The routing selectors used for TabManager +
    ///   workspace resolution.
    /// - Returns: The mutation resolution.
    func controlSelectNextPage(routing: ControlRoutingSelectors) -> ControlPageMutationResolution

    /// Selects the previous page for `page.previous`.
    ///
    /// - Parameter routing: The routing selectors used for TabManager +
    ///   workspace resolution.
    /// - Returns: The mutation resolution.
    func controlSelectPreviousPage(routing: ControlRoutingSelectors) -> ControlPageMutationResolution

    /// Selects the last page for `page.last`.
    ///
    /// - Parameter routing: The routing selectors used for TabManager +
    ///   workspace resolution.
    /// - Returns: The mutation resolution.
    func controlSelectLastPage(routing: ControlRoutingSelectors) -> ControlPageMutationResolution
}
