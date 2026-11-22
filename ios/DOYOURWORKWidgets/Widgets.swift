import CoreText
import DoYourWorkCore
import SwiftUI
import WidgetKit

/// DOYOURWORK's home and lock screen widgets. They show what the app last wrote; tapping one opens the app.
@main
struct DOYOURWORKWidgets: WidgetBundle {
    init() {
        // The app's typeface, bundled in this extension too.
        let urls = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? []
        CTFontManagerRegisterFontURLs(urls as CFArray, .process, true, nil)
    }

    var body: some Widget {
        TodayWidget()
        ScoreboardWidget()
        DaresWidget()
        StreakWidget()
    }
}

/// One player's card today: minutes ticked off out of 25, and what's next. Home screen (small) and lock screen.
struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "today", intent: PickPlayer.self, provider: PlayerProvider()) { TodayView(entry: $0) }
            .configurationDisplayName("Today's card")
            .description("Minutes done today, your streak and the next chore.")
            .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

/// This week's points for everyone, in the scoreboard's bands.
struct ScoreboardWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "scoreboard", provider: FamilyProvider()) { ScoreboardView(entry: $0) }
            .configurationDisplayName("Scoreboard")
            .description("This week's points for the whole family.")
            .supportedFamilies([.systemMedium, .systemLarge])
    }
}

/// Yesterday's dares, revealed, or how many are left to make today. Today's stay secret.
struct DaresWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "dares", intent: PickPlayer.self, provider: PlayerProvider()) { DaresView(entry: $0) }
            .configurationDisplayName("Dares")
            .description("Yesterday's dares, revealed after midnight.")
            .supportedFamilies([.systemSmall])
    }
}

/// A player's streak, for the lock screen.
struct StreakWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "streak", intent: PickPlayer.self, provider: PlayerProvider()) { StreakView(entry: $0) }
            .configurationDisplayName("Streak")
            .description("Days in a row with a chore approved.")
            .supportedFamilies([.accessoryCircular])
    }
}

// MARK: Look

extension Color {
    init(hex v: UInt32) {
        self.init(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }
}

extension Font {
    /// Schibsted Grotesk, as in the app.
    static func app(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font { .custom("Schibsted Grotesk", size: size).weight(weight) }
}

extension WidgetSnapshot.Colors {
    var background: Color { Color(hex: bg) }
    var foreground: Color { Color(hex: text) }
    var quiet: Color { Color(hex: muted) }
    func band(_ i: Int) -> Color { Color(hex: heat[min(i, heat.count - 1)]) }
}

/// Shown before the app has been opened and set up.
struct SetUpFirst: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("DOYOURWORK").font(.app(13, .black)).foregroundStyle(Color(hex: WidgetSnapshot.Colors.fuego.accent))
            Spacer(minLength: 0)
            Text("Open the app to set up your family").font(.app(14, .semibold)).foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(Color.black, for: .widget)
    }
}

/// The line under a card's minutes.
private func cardLine(_ p: WidgetSnapshot.Player) -> String {
    switch p.card {
    case "pick": "Pick today's card"
    case "sent": "Sent, waiting on a parent"
    case "approved": "Approved"
    default: p.next.map { "Next: \($0)" } ?? "All done, send it in"
    }
}

private func ordinal(_ n: Int) -> String {
    let suffix = (11...13).contains(n % 100) ? "th" : [1: "st", 2: "nd", 3: "rd"][n % 10] ?? "th"
    return "\(n)\(suffix)"
}

// MARK: Today

struct TodayView: View {
    let entry: FamilyEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let s = entry.snapshot, let p = entry.player {
            switch family {
            case .accessoryCircular: circular(p)
            case .accessoryRectangular: rectangular(s, p)
            case .accessoryInline: inline(p)
            default: small(s.colors, p)
            }
        } else if family == .systemSmall {
            SetUpFirst()
        } else {
            Text("DOYOURWORK").containerBackground(.clear, for: .widget)
        }
    }

    private var goal: Int { Engine.dailyMinutes }

    private func small(_ c: WidgetSnapshot.Colors, _ p: WidgetSnapshot.Player) -> some View {
        let fraction = min(1, Double(p.minutesDone) / Double(goal))
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(p.name).font(.app(14, .bold)).lineLimit(1)
                Spacer(minLength: 4)
                if p.streak > 0 {
                    Label("\(p.streak)", systemImage: "flame.fill").labelStyle(.titleAndIcon).font(.app(13, .bold))
                        .foregroundStyle(c.band(5))
                }
            }
            Spacer(minLength: 0)
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text("\(p.minutesDone)").font(.app(38, .black)).contentTransition(.numericText())
                Text("/\(goal)").font(.app(16, .bold)).foregroundStyle(c.quiet)
            }
            Text("minutes today").font(.app(11)).foregroundStyle(c.quiet)
            Spacer(minLength: 0)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(hex: c.surface))
                    Capsule().fill(p.card == "approved" ? Color(hex: 0x6BC276) : c.band(min(5, Int(fraction * 5))))
                        .frame(width: max(fraction > 0 ? 8 : 0, g.size.width * fraction))
                }
            }
            .frame(height: 8)
            Text(cardLine(p)).font(.app(12, .semibold)).lineLimit(1).minimumScaleFactor(0.8).padding(.top, 6)
        }
        .foregroundStyle(c.foreground)
        .containerBackground(c.background, for: .widget)
    }

    private func circular(_ p: WidgetSnapshot.Player) -> some View {
        Gauge(value: Double(min(p.minutesDone, goal)), in: 0...Double(goal)) {
            Text("min")
        } currentValueLabel: {
            Text("\(p.minutesDone)").font(.app(18, .bold))
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .containerBackground(.clear, for: .widget)
    }

    private func rectangular(_ s: WidgetSnapshot, _ p: WidgetSnapshot.Player) -> some View {
        let place = s.place(of: p.id) ?? 1
        let behind = s.players.first { $0.weekPoints < p.weekPoints }?.weekPoints
        let ahead = s.players.last { $0.weekPoints > p.weekPoints }?.weekPoints
        let gap = place == 1 ? behind.map { "+\(p.weekPoints - $0) lead" } : ahead.map { "\($0 - p.weekPoints) behind" }
        return VStack(alignment: .leading, spacing: 1) {
            Text("\(p.name) · \(ordinal(place))").font(.app(15, .bold)).widgetAccentable()
            Text(["\(p.weekPoints) pts", gap].compactMap { $0 }.joined(separator: " · ")).font(.app(13))
            Text("\(p.minutesDone) of \(goal) min today").font(.app(13)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(.clear, for: .widget)
    }

    private func inline(_ p: WidgetSnapshot.Player) -> some View {
        Label("\(p.name) \(p.minutesDone)/\(goal) min" + (p.streak > 0 ? " · \(p.streak) days" : ""), systemImage: "flame")
            .containerBackground(.clear, for: .widget)
    }
}

// MARK: Scoreboard

struct ScoreboardView: View {
    let entry: FamilyEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let s = entry.snapshot, !s.players.isEmpty {
            let c = s.colors, rows = family == .systemLarge ? 8 : 4
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text("This week").font(.app(13, .bold))
                    Spacer()
                    Text("DOYOURWORK").font(.app(11, .black)).foregroundStyle(c.quiet)
                }
                .padding(.bottom, 4)
                ForEach(Array(s.players.prefix(rows).enumerated()), id: \.element.id) { i, p in
                    HStack(spacing: 6) {
                        if i == 0 && p.weekPoints > 0 { Image(systemName: "crown.fill").font(.system(size: 11)) }
                        Text(p.name).font(.app(14, .bold)).lineLimit(1)
                        if family == .systemLarge { Text(p.version).font(.app(12)).opacity(0.75) }
                        Spacer(minLength: 4)
                        if family == .systemLarge && p.streak > 0 {
                            Label("\(p.streak)", systemImage: "flame.fill").font(.app(12, .semibold)).opacity(0.85)
                        }
                        Text("\(p.weekPoints)").font(.app(15, .black)).monospacedDigit()
                    }
                    .foregroundStyle(Color(hex: c.heatInk))
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity, maxHeight: family == .systemLarge ? 36 : 28)
                    .background(c.band(i), in: RoundedRectangle(cornerRadius: 6))
                }
                Spacer(minLength: 0)
                // Room to spare: today's minutes for each player.
                if s.players.count < rows {
                    Text("Today: " + s.players.prefix(rows).map { "\($0.name) \($0.minutesDone) min" }.joined(separator: " · "))
                        .font(.app(12)).foregroundStyle(c.quiet).lineLimit(1).minimumScaleFactor(0.8)
                }
            }
            .foregroundStyle(c.foreground)
            .containerBackground(c.background, for: .widget)
        } else {
            SetUpFirst()
        }
    }
}

// MARK: Dares

struct DaresView: View {
    let entry: FamilyEntry

    var body: some View {
        if let s = entry.snapshot {
            let c = s.colors, plumInk = Color(hex: c.plumInk)
            VStack(alignment: .leading, spacing: 6) {
                Text(s.yesterdaysDares.isEmpty ? "Dares" : "Yesterday's dares").font(.app(13, .bold))
                Spacer(minLength: 0)
                if !s.linked {
                    Text("Dares need two phones. Add one in the app.").font(.app(13, .semibold)).foregroundStyle(plumInk)
                } else if s.yesterdaysDares.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(s.daresLeftToday) left today").font(.app(17, .black)).foregroundStyle(c.foreground)
                        Text("Guess who'll do what").font(.app(12)).foregroundStyle(plumInk)
                    }
                    .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(hex: c.plum), in: RoundedRectangle(cornerRadius: 10))
                } else {
                    let me = entry.player?.id
                    let earned = me.map { id in s.yesterdaysDares.filter(\.landed).reduce(0) { total, d in
                        total + (d.from == id ? Engine.dareGuesserPoints : 0) + (d.target == id ? Engine.dareDoerPoints : 0) } } ?? 0
                    if earned > 0 { Text("You earned \(earned)").font(.app(15, .black)).foregroundStyle(c.foreground) }
                    ForEach(Array(s.yesterdaysDares.prefix(earned > 0 ? 2 : 3).enumerated()), id: \.offset) { _, d in
                        HStack(alignment: .top, spacing: 4) {
                            Image(systemName: d.landed ? "checkmark" : "xmark").font(.system(size: 10, weight: .bold))
                                .foregroundStyle(d.landed ? Color(hex: 0x6BC276) : c.quiet).padding(.top, 2)
                            Text("\(d.fromName): \(d.targetName), \(d.chore)").font(.app(11)).lineLimit(2).foregroundStyle(plumInk)
                        }
                    }
                }
                Spacer(minLength: 0)
                Label("Revealed at midnight", systemImage: "moon").font(.app(10)).foregroundStyle(c.quiet)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(c.foreground)
            .containerBackground(c.background, for: .widget)
        } else {
            SetUpFirst()
        }
    }
}

// MARK: Streak

struct StreakView: View {
    let entry: FamilyEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Image(systemName: "flame.fill").font(.system(size: 15)).widgetAccentable()
                Text("\(entry.player?.streak ?? 0)").font(.app(17, .bold))
            }
        }
        .containerBackground(.clear, for: .widget)
    }
}
