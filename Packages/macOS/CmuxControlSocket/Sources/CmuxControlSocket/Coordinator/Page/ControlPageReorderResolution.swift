public import Foundation

/// The outcome of `page.reorder`, after the coordinator has confirmed a
/// single target (`index`, `before_page_id`, or `after_page_id`) was given.
public enum ControlPageReorderResolution: Sendable, Equatable {
    /// No TabManager resolved (legacy `unavailable` / "TabManager not
    /// available").
    case tabManagerUnavailable
    /// A TabManager resolved but no workspace resolved (legacy `not_found` /
    /// "Workspace not found").
    case workspaceNotFound
    /// The workspace resolved but the moved page id was not one of its pages
    /// (legacy `not_found` / "Page not found").
    case pageNotFound(pageID: UUID)
    /// The workspace resolved but the `before_page_id` / `after_page_id`
    /// anchor was not one of its pages (legacy `not_found` / "Anchor page
    /// not found").
    case anchorNotFound(anchorPageID: UUID, pageID: UUID)
    /// The page resolved but is the workspace's only page, so there is
    /// nothing to reorder against (legacy `invalid_state` / "Cannot reorder:
    /// workspace has only one page").
    case cannotReorderSinglePage(pageID: UUID)
    /// The page moved. Carries the owning window id (may be absent), the
    /// resolved workspace id, the moved page, and its new index.
    case resolved(windowID: UUID?, workspaceID: UUID, page: ControlPageSummary, index: Int)
}
