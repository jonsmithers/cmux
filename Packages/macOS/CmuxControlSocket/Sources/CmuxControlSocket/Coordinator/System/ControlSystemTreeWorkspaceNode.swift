public import Foundation

/// One workspace row of the `system.tree` snapshot (the legacy
/// `v2TreeWorkspaceNode` dictionary, minus the coordinator-minted refs).
public struct ControlSystemTreeWorkspaceNode: Sendable, Equatable {
    /// The workspace's identifier.
    public let workspaceID: UUID
    /// The workspace's index within its window's tab list.
    public let index: Int
    /// The workspace's display title.
    public let title: String
    /// The custom description, if any.
    public let description: String?
    /// Whether this is the window's selected workspace.
    public let isSelected: Bool
    /// Whether the workspace is pinned.
    public let isPinned: Bool
    /// The workspace's pane nodes, in pane order. Mirrors the selected page's
    /// panes (see ``pages``), preserved at this level for older tree
    /// consumers that predate workspace pages
    /// (docs/workspace-pages-spec.md).
    public let panes: [ControlSystemTreePaneNode]
    /// The active page's identifier.
    public let selectedPageID: UUID
    /// The workspace's page nodes, in page order.
    public let pages: [ControlSystemTreePageNode]

    /// Creates a workspace node.
    ///
    /// - Parameters:
    ///   - workspaceID: The workspace's identifier.
    ///   - index: The index within the window's tab list.
    ///   - title: The display title.
    ///   - description: The custom description, if any.
    ///   - isSelected: Whether this is the selected workspace.
    ///   - isPinned: Whether the workspace is pinned.
    ///   - panes: The selected page's pane nodes (legacy mirror).
    ///   - selectedPageID: The active page's identifier.
    ///   - pages: The workspace's page nodes.
    public init(
        workspaceID: UUID,
        index: Int,
        title: String,
        description: String?,
        isSelected: Bool,
        isPinned: Bool,
        panes: [ControlSystemTreePaneNode],
        selectedPageID: UUID,
        pages: [ControlSystemTreePageNode]
    ) {
        self.workspaceID = workspaceID
        self.index = index
        self.title = title
        self.description = description
        self.isSelected = isSelected
        self.isPinned = isPinned
        self.panes = panes
        self.selectedPageID = selectedPageID
        self.pages = pages
    }
}
