public import Foundation

/// A routed page mutation outcome shared by `page.current`, `page.create`,
/// `page.duplicate`, `page.select`, `page.rename`, `page.next`,
/// `page.previous`, and `page.last`: resolve a TabManager and workspace, act
/// on (or read) a page, echo the owning window/workspace/page on success.
public enum ControlPageMutationResolution: Sendable, Equatable {
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
    /// The mutation (or read) succeeded. Carries the owning window id (may be
    /// absent), the resolved workspace id, the resulting page, and its index
    /// within the workspace's page list (if resolvable).
    case resolved(windowID: UUID?, workspaceID: UUID, page: ControlPageSummary, index: Int?)
}
