import Combine
import DoYourWorkCore
import SwiftUI
import WidgetKit

/// Keeps the home and lock screen widgets up to date: whenever the scoreboard or the theme changes,
/// writes a `WidgetSnapshot` to the App Group folder the widget extension reads, then asks WidgetKit
/// to redraw. Only what the widgets show goes in it; today's dares stay secret until midnight.
@MainActor
final class WidgetBridge {
    static let shared = WidgetBridge()
    private var watching: AnyCancellable?
    private var last: WidgetSnapshot?

    /// Starts watching the store. Writes once straight away, then a moment after each change settles.
    func start(_ store: AppStore) {
        guard watching == nil else { return }
        watching = store.objectWillChange.merge(with: ThemeStore.shared.objectWillChange)
            .debounce(for: .milliseconds(400), scheduler: RunLoop.main)
            .sink { [weak self, weak store] _ in if let store { self?.write(store) } }
        write(store)
    }

    /// Writes the snapshot if it changed. Also called when the app comes to the front, since the
    /// day may have turned over while it was away.
    func write(_ store: AppStore) {
        guard store.isSetUp, let url = Self.fileURL else { return }
        let snapshot = Self.snapshot(store)
        guard snapshot != last, let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: url, options: .atomic)
        last = snapshot
        WidgetCenter.shared.reloadAllTimelines()
    }

    static var fileURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: WidgetSnapshot.appGroup)?
            .appendingPathComponent(WidgetSnapshot.fileName)
    }

    static func snapshot(_ store: AppStore) -> WidgetSnapshot {
        let cal = store.calendar, now = Date(), today = store.todayKey
        let players = store.players.map { p -> WidgetSnapshot.Player in
            let card = store.card(for: p.id)
            var state = "pick", done = 0, planned = 0, next: String?
            if let card {
                planned = card.minutes.reduce(0, +)
                done = zip(card.minutes, card.checked).filter(\.1).reduce(0) { $0 + $1.0 }
                next = zip(card.choreIds, card.checked).first { !$0.1 }.map { store.choreName($0.0) }
                if !card.submitted { state = "playing" } else {
                    let status = Engine.statusToday(store.todaysLogs(p.id))
                    state = !status.isEmpty && status.values.allSatisfy { $0 == Status.approved } ? "approved" : "sent"
                }
            }
            let approvedToday = store.todaysLogs(p.id).contains { $0.status == Status.approved }
            return .init(id: p.id, name: p.shownName, minutesDone: done, minutesPlanned: planned, card: state, next: next,
                         streak: store.streak(p.id), streakToday: approvedToday, weekPoints: store.weekPoints(p.id),
                         version: store.rank(p.id).version)
        }.sorted { $0.weekPoints > $1.weekPoints }

        let names = Dictionary(store.members.map { ($0.id, $0.shownName) }, uniquingKeysWith: { a, _ in a })
        let yesterday = Engine.dayKey(cal.date(byAdding: .day, value: -1, to: now)!, calendar: cal)
        let dares = store.dares
        let revealed = dares.filter { $0.day == yesterday }.map {
            WidgetSnapshot.Revealed(from: $0.from, target: $0.target, fromName: names[$0.from] ?? $0.from, targetName: names[$0.target] ?? $0.target,
                                    chore: store.choreName($0.choreId), landed: Engine.dareLanded($0, logs: store.logs, calendar: cal))
        }
        let used = store.me.map { me in dares.filter { $0.from == me && $0.day == today }.count } ?? 0

        let theme = ThemeStore.shared.current
        let heat = theme.heat
        let colors = WidgetSnapshot.Colors(
            bg: theme.bg.hexValue, text: theme.text.hexValue, muted: theme.muted.hexValue, surface: theme.surface.hexValue,
            accent: Theme.accent.hexValue, heat: (0..<6).map { heat.band($0, of: 6).hexValue }, heatInk: heat.ink.hexValue,
            plum: theme.plum.stops[0].hexValue, plumInk: theme.plum.ink.hexValue)

        return WidgetSnapshot(day: today, weekStart: Engine.dayKey(Engine.weekStart(now, calendar: cal), calendar: cal), players: players,
                              me: store.me, linked: store.isLinked, daresLeftToday: max(0, Engine.maxDaresPerDay - used),
                              yesterdaysDares: revealed, colors: colors)
    }
}
