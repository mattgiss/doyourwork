import Foundation

/// How the family page lays out its tiles: as big as the space allows, so one person fills the page
/// and the tiles shrink as more join, until they'd be too small, when it becomes a scrolling grid of
/// small tiles. The same on Android.
public enum FamilyGrid {
    public struct Layout: Equatable, Sendable {
        public let columns: Int
        public let rows: Int
        public let tileWidth: Double
        public let tileHeight: Double
        /// The side of the avatar's square (its border included), inside a tile.
        public let avatar: Double
        /// Too many people to fit: small tiles in a grid that scrolls.
        public let scrolls: Bool
    }

    /// Space between tiles.
    public static let gap: Double = 12
    /// A tile is never taller than this many times its width, so a lone tile stays a card, not a strip.
    public static let maxTallness: Double = 1.4
    /// Below this the tiles scroll instead of shrinking further.
    public static let minAvatar: Double = 84

    /// The avatar that fits a tile: most of its width, leaving room under it for the name and streak.
    public static func avatar(width: Double, height: Double) -> Double {
        max(0, min(width * 0.8, height - 64 - height * 0.08))
    }

    /// The layout for `count` tiles in a `width` × `height` space. Tries every number of columns up
    /// to `maxColumns` and keeps the one with the biggest avatars (fewer columns on a tie).
    public static func layout(count: Int, width: Double, height: Double, maxColumns: Int = 6) -> Layout {
        let n = max(1, count)
        var best: Layout?
        for columns in 1...min(n, maxColumns) {
            let rows = (n + columns - 1) / columns
            let w = (width - gap * Double(columns - 1)) / Double(columns)
            let h = min((height - gap * Double(rows - 1)) / Double(rows), w * maxTallness)
            let a = avatar(width: w, height: h)
            if best == nil || a > best!.avatar + 0.5 {
                best = Layout(columns: columns, rows: rows, tileWidth: w, tileHeight: h, avatar: a, scrolls: false)
            }
        }
        if let best, best.avatar >= minAvatar { return best }
        // A big family on a small screen: small tiles, three or more across, scrolling.
        let columns = min(maxColumns, max(3, Int(width / 120)))
        let w = (width - gap * Double(columns - 1)) / Double(columns)
        let h = w * 1.25
        return Layout(columns: columns, rows: (n + columns - 1) / columns, tileWidth: w, tileHeight: h,
                      avatar: avatar(width: w, height: h), scrolls: true)
    }
}
