import AppIntents
import DoYourWorkCore
import WidgetKit

/// Reads the snapshot the app writes (`WidgetBridge` in the app), as it reads at `date`.
enum Snapshot {
    static func load(at date: Date = Date()) -> WidgetSnapshot? {
        guard let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: WidgetSnapshot.appGroup)?
                .appendingPathComponent(WidgetSnapshot.fileName),
              let data = try? Data(contentsOf: url),
              let s = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) else { return nil }
        let cal = Calendar.current
        let yesterday = cal.date(byAdding: .day, value: -1, to: date)!
        return s.asOf(today: Engine.dayKey(date, calendar: cal), week: Engine.dayKey(Engine.weekStart(date, calendar: cal), calendar: cal),
                      yesterday: Engine.dayKey(yesterday, calendar: cal))
    }

    /// The made-up family shown in the widget gallery and while a widget loads.
    static let sample = WidgetSnapshot(
        day: "", weekStart: "",
        players: [
            .init(id: "1", name: "Riley", minutesDone: 18, minutesPlanned: 25, card: "playing", next: "Dishwasher", streak: 4, streakToday: false, weekPoints: 142, version: "v1.3"),
            .init(id: "2", name: "Sam", minutesDone: 25, minutesPlanned: 25, card: "sent", next: nil, streak: 2, streakToday: false, weekPoints: 118, version: "v1.1"),
            .init(id: "3", name: "Mom", minutesDone: 0, minutesPlanned: 0, card: "pick", next: nil, streak: 6, streakToday: true, weekPoints: 96, version: "v1.5"),
            .init(id: "4", name: "Dad", minutesDone: 10, minutesPlanned: 20, card: "playing", next: "Trash out", streak: 1, streakToday: false, weekPoints: 61, version: "v1.0"),
        ],
        me: "1", linked: true, daresLeftToday: 2,
        yesterdaysDares: [.init(from: "2", target: "1", fromName: "Sam", targetName: "Riley", chore: "Fold laundry", landed: true)],
        colors: .fuego)

    /// The next local midnight after `date`, when the day's numbers start over.
    static func midnight(after date: Date) -> Date {
        Calendar.current.nextDate(after: date, matching: DateComponents(hour: 0, minute: 0, second: 5), matchingPolicy: .nextTime) ?? date.addingTimeInterval(86_400)
    }
}

struct FamilyEntry: TimelineEntry {
    let date: Date
    /// Nil until the app has been opened once and set up.
    let snapshot: WidgetSnapshot?
    /// The player this widget is for, if it shows one.
    let playerId: String?

    var player: WidgetSnapshot.Player? {
        guard let s = snapshot else { return nil }
        return s.player(playerId) ?? s.player(s.me) ?? s.players.first
    }
}

// MARK: Picking a player

/// A player, offered when you edit a widget ("Edit Widget" > Player).
struct PlayerEntity: AppEntity {
    let id: String
    let name: String
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Player"
    static let defaultQuery = PlayerQuery()
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}

struct PlayerQuery: EntityQuery {
    private func all() -> [PlayerEntity] {
        (Snapshot.load()?.players ?? []).map { PlayerEntity(id: $0.id, name: $0.name) }
    }
    func entities(for identifiers: [String]) async throws -> [PlayerEntity] { all().filter { identifiers.contains($0.id) } }
    func suggestedEntities() async throws -> [PlayerEntity] { all() }
    /// This phone's player when it has one, else the first on the scoreboard.
    func defaultResult() async -> PlayerEntity? {
        let s = Snapshot.load()
        return (s?.player(s?.me) ?? s?.players.first).map { PlayerEntity(id: $0.id, name: $0.name) }
    }
}

struct PickPlayer: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Player"
    static let description = IntentDescription("Whose card this widget shows.")
    @Parameter(title: "Player") var player: PlayerEntity?
    init() {}
}

/// For widgets about one player: redraws now and again at midnight, when a new day starts.
struct PlayerProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> FamilyEntry { FamilyEntry(date: Date(), snapshot: Snapshot.sample, playerId: "1") }

    func snapshot(for configuration: PickPlayer, in context: Context) async -> FamilyEntry {
        if context.isPreview { return placeholder(in: context) }
        return FamilyEntry(date: Date(), snapshot: Snapshot.load(), playerId: configuration.player?.id)
    }

    func timeline(for configuration: PickPlayer, in context: Context) async -> Timeline<FamilyEntry> {
        let now = Date(), midnight = Snapshot.midnight(after: now)
        let entries = [now, midnight].map { FamilyEntry(date: $0, snapshot: Snapshot.load(at: $0), playerId: configuration.player?.id) }
        return Timeline(entries: entries, policy: .after(midnight))
    }
}

/// For the whole-family scoreboard.
struct FamilyProvider: TimelineProvider {
    func placeholder(in context: Context) -> FamilyEntry { FamilyEntry(date: Date(), snapshot: Snapshot.sample, playerId: nil) }

    func getSnapshot(in context: Context, completion: @escaping (FamilyEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : FamilyEntry(date: Date(), snapshot: Snapshot.load(), playerId: nil))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FamilyEntry>) -> Void) {
        let now = Date(), midnight = Snapshot.midnight(after: now)
        let entries = [now, midnight].map { FamilyEntry(date: $0, snapshot: Snapshot.load(at: $0), playerId: nil) }
        completion(Timeline(entries: entries, policy: .after(midnight)))
    }
}
