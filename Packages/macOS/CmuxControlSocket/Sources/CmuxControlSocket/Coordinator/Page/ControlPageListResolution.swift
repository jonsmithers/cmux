public import Foundation

/// The outcome of `page.list`, preserving the legacy body's two distinct
/// failures and the resolved window/workspace/pages the success echoes back.
public enum ControlPageListResolution: Sendable, Equatable {
    /// No TabManager resolved (legacy `unavailable` / "TabManager not
    /// available").
    case tabManagerUnavailable
    /// A TabManager resolved but no workspace resolved (legacy `not_found` /
    /// "Workspace not found").
    case workspaceNotFound
    /// The pages were snapshotted. Carries the owning window id (may be
    /// absent), the resolved workspace id, the page summaries in order, and
    /// the active page's id.
    case resolved(
        windowID: UUID?,
        workspaceID: UUID,
        pages: [ControlPageSummary],
        selectedPageID: UUID
    )
}
