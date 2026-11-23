import Foundation

/// What the home and lock screen widgets show, written by the app to the shared App Group folder
/// every time the scoreboard changes. The widgets only read this file: they never open the app's
/// own data, so they can't change a score or see a dare before it's revealed.
public struct WidgetSnapshot: Codable, Equatable, Sendable {
    /// The App Group the app and the widget extension share.
    public static let appGroup = "group.com.gyattchores.app"
    public static let fileName = "widget.json"

    /// One person on the scoreboard, as of `day`.
    public struct Player: Codable, Equatable, Sendable, Identifiable {
        public var id: String
        public var name: String
        /// Minutes ticked off on today's card, and the card's total. Both 0 before a card is picked.
        public var minutesDone: Int
        public var minutesPlanned: Int
        /// "pick" (no card yet), "playing", "sent" (waiting on a parent) or "approved".
        public var card: String
        /// The first chore on today's card not ticked off yet.
        public var next: String?
        public var streak: Int
        /// True when today already counts towards the streak (something was approved today).
        public var streakToday: Bool
        public var weekPoints: Int
        /// Their rank, such as "v1.3".
        public var version: String
        public init(id: String, name: String, minutesDone: Int, minutesPlanned: Int, card: String, next: String?,
                    streak: Int, streakToday: Bool, weekPoints: Int, version: String) {
            self.id = id; self.name = name; self.minutesDone = minutesDone; self.minutesPlanned = minutesPlanned; self.card = card
            self.next = next; self.streak = streak; self.streakToday = streakToday; self.weekPoints = weekPoints; self.version = version
        }
    }

    /// A dare from `day - 1`, already revealed in the app.
    public struct Revealed: Codable, Equatable, Sendable {
        public var from: String, target: String, fromName: String, targetName: String, chore: String
        public var landed: Bool
        public init(from: String, target: String, fromName: String, targetName: String, chore: String, landed: Bool) {
            self.from = from; self.target = target; self.fromName = fromName; self.targetName = targetName; self.chore = chore; self.landed = landed
        }
    }

    /// The theme's colours as 0xRRGGBB, so the widgets match the app.
    public struct Colors: Codable, Equatable, Sendable {
        public var bg: UInt32, text: UInt32, muted: UInt32, surface: UInt32, accent: UInt32
        /// The scoreboard's bands, top to bottom, and the colour of text on them.
        public var heat: [UInt32]
        public var heatInk: UInt32
        public var plum: UInt32, plumInk: UInt32
        public init(bg: UInt32, text: UInt32, muted: UInt32, surface: UInt32, accent: UInt32, heat: [UInt32], heatInk: UInt32, plum: UInt32, plumInk: UInt32) {
            self.bg = bg; self.text = text; self.muted = muted; self.surface = surface; self.accent = accent
            self.heat = heat; self.heatInk = heatInk; self.plum = plum; self.plumInk = plumInk
        }
        /// Fuego, the default look, for a widget added before the app has run.
        public static let fuego = Colors(bg: 0x000000, text: 0xFFFFFF, muted: 0x5A5A5E, surface: 0x141414, accent: 0xE8572A,
                                         heat: [0xD90015, 0xDB2A15, 0xE04A19, 0xE2751C, 0xE99A22, 0xEDB82A], heatInk: 0xFFFFFF,
                                         plum: 0x34207A, plumInk: 0xB9A2FF)
    }

    /// Local date the numbers are for (yyyy-MM-dd), and the Monday of that week.
    public var day: String
    public var weekStart: String
    /// Everyone who plays, highest week points first.
    public var players: [Player]
    /// Whose phone this is, if it's been set (a linked family only).
    public var me: String?
    /// Dares need a family on more than one phone.
    public var linked: Bool
    public var daresLeftToday: Int
    public var yesterdaysDares: [Revealed]
    public var colors: Colors

    public init(day: String, weekStart: String, players: [Player], me: String?, linked: Bool, daresLeftToday: Int,
                yesterdaysDares: [Revealed], colors: Colors) {
        self.day = day; self.weekStart = weekStart; self.players = players; self.me = me; self.linked = linked
        self.daresLeftToday = daresLeftToday; self.yesterdaysDares = yesterdaysDares; self.colors = colors
    }

    /// The snapshot as it reads on `today` (yyyy-MM-dd), `week` being that day's Monday. A widget can
    /// outlive the day its snapshot was written: from midnight a new card hasn't been picked, a streak
    /// without an approved day yesterday has broken, and yesterday's dares are ones the app hasn't
    /// revealed to this file yet. From Monday the week's points start again.
    public func asOf(today: String, week: String, yesterday: String) -> WidgetSnapshot {
        guard today != day else { return self }
        var s = self
        s.day = today
        s.players = players.map { p in
            var p = p
            p.minutesDone = 0; p.minutesPlanned = 0; p.card = "pick"; p.next = nil
            // Snapshot day was yesterday: the streak carries if that day counted. Older: it broke.
            p.streak = (day == yesterday && p.streakToday) ? p.streak : 0
            p.streakToday = false
            if week != weekStart { p.weekPoints = 0 }
            return p
        }
        if week != weekStart { s.weekStart = week; s.players.sort { $0.weekPoints > $1.weekPoints } }
        s.daresLeftToday = Engine.maxDaresPerDay
        s.yesterdaysDares = []
        return s
    }

    public func player(_ id: String?) -> Player? {
        guard let id else { return nil }
        return players.first { $0.id == id }
    }

    /// Place on this week's board, 1 for first; players on the same points share a place.
    public func place(of id: String) -> Int? {
        guard let p = player(id) else { return nil }
        return players.filter { $0.weekPoints > p.weekPoints }.count + 1
    }
}
