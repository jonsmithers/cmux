public import Foundation

/// One page row within a workspace's `pages` list (the legacy `v2PagePayload`
/// dictionary, minus the coordinator-minted ref).
public struct ControlPageSummary: Sendable, Equatable {
    /// The page's identifier.
    public let id: UUID
    /// The page's display title.
    public let title: String
    /// The page's pane count (1 for a single unsplit pane).
    public let paneCount: Int
    /// The page's surface (panel) count across all its panes.
    public let surfaceCount: Int

    /// Creates a page summary.
    ///
    /// - Parameters:
    ///   - id: The page's identifier.
    ///   - title: The display title.
    ///   - paneCount: The pane count.
    ///   - surfaceCount: The surface count.
    public init(id: UUID, title: String, paneCount: Int, surfaceCount: Int) {
        self.id = id
        self.title = title
        self.paneCount = paneCount
        self.surfaceCount = surfaceCount
    }
}
