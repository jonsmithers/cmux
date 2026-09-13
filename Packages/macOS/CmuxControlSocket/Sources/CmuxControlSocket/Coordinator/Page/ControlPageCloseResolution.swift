public import Foundation

/// The outcome of `page.close`, preserving the legacy body's failures and the
/// resolved window/workspace/page the success echoes back.
public enum ControlPageCloseResolution: Sendable, Equatable {
    /// No TabManager resolved (legacy `unavailable` / "TabManager not
    /// available").
    case tabManagerUnavailable
    /// A TabManager resolved but no workspace resolved (legacy `not_found` /
    /// "Workspace not found").
    case workspaceNotFound
    /// The workspace resolved but the requested page id was not one of its
    /// pages (legacy `not_found` / "Page not found"). Carries the requested
    /// page id, if the request named one explicitly.
    case pageNotFound(pageID: UUID?)
    /// The page resolved but is the workspace's only page (legacy
    /// `invalid_state` / "Cannot close the last page in a workspace").
    case cannotCloseLastPage(pageID: UUID)
    /// The page was closed. Carries the owning window id (may be absent), the
    /// resolved workspace id, the closed page's id, and the page now
    /// selected in its place.
    case resolved(windowID: UUID?, workspaceID: UUID, closedPageID: UUID, selectedPage: ControlPageSummary)
}
