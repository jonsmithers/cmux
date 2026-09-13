public import Foundation

/// One page row of the `system.tree` snapshot, nested under its workspace
/// (workspace -> page -> pane -> surface; see
/// docs/workspace-pages-spec.md). The legacy `v2TreePageNode` dictionary,
/// minus the coordinator-minted refs.
public struct ControlSystemTreePageNode: Sendable, Equatable {
    /// The page's identifier.
    public let pageID: UUID
    /// The page's index within its workspace's page list.
    public let index: Int
    /// The page's display title.
    public let title: String
    /// Whether this is the workspace's active page.
    public let isSelected: Bool
    /// The page's pane count.
    public let paneCount: Int
    /// The page's surface (panel) count.
    public let surfaceCount: Int
    /// The page's pane nodes, in pane order. For the active page these are
    /// live; for an inactive (stashed) page they are read from its stored
    /// session-state snapshot, so their `paneID`s are not resolvable live
    /// identities until the page is next selected.
    public let panes: [ControlSystemTreePaneNode]

    /// Creates a page node.
    ///
    /// - Parameters:
    ///   - pageID: The page's identifier.
    ///   - index: The index within the workspace's page list.
    ///   - title: The display title.
    ///   - isSelected: Whether this is the active page.
    ///   - paneCount: The pane count.
    ///   - surfaceCount: The surface count.
    ///   - panes: The page's pane nodes.
    public init(
        pageID: UUID,
        index: Int,
        title: String,
        isSelected: Bool,
        paneCount: Int,
        surfaceCount: Int,
        panes: [ControlSystemTreePaneNode]
    ) {
        self.pageID = pageID
        self.index = index
        self.title = title
        self.isSelected = isSelected
        self.paneCount = paneCount
        self.surfaceCount = surfaceCount
        self.panes = panes
    }
}
