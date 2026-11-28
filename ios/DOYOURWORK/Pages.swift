import SwiftUI
import DoYourWorkCore

/// The pages the app swipes between (docs/design/whiteboard-redesign.md). A person's day opens
/// from their family tile, over these.
enum Page: String, CaseIterable, Identifiable {
    case family, feed, settings
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .family: "person.3.fill"
        case .feed: "list.bullet.rectangle.fill"
        case .settings: "gearshape.fill"
        }
    }
}

/// Pages side by side, swiped between, with the tab bar floating over the bottom.
struct PagesView<Content: View>: View {
    let pages: [Page]
    @Binding var selection: Page
    /// The round button beside the bar: make a dare. Nil hides it (dares need a linked phone).
    var onDare: (() -> Void)?
    @ViewBuilder let content: (Page) -> Content

    var body: some View {
        TabView(selection: $selection) {
            ForEach(pages) { page in
                // Room at the bottom so the last tile can scroll out from under the bar.
                content(page).safeAreaPadding(.bottom, 76).tag(page)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .overlay(alignment: .bottom) { TabBar(pages: pages, selection: $selection, onDare: onDare).padding(.bottom, 4) }
    }
}

/// The bar along the bottom, in the iOS 27 style: a floating pill holding the pages, the current
/// one on a darker bubble, and a round button of its own beside it for daring someone.
struct TabBar: View {
    @EnvironmentObject var fb: Feedback
    let pages: [Page]
    @Binding var selection: Page
    var onDare: (() -> Void)?
    @Namespace private var bubble

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 2) {
                ForEach(pages) { page in item(page) }
            }
            .padding(5)
            .barFill(Capsule())
            if let onDare {
                Button { fb.tap(); onDare() } label: {
                    Image(systemName: "bolt.fill").font(.system(size: 19, weight: .semibold)).foregroundStyle(Palette.heat.stops[0])
                        .frame(width: 58, height: 58)
                        .barFill(Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(BandPress())
                .accessibilityLabel("Make a dare")
                .accessibilityIdentifier("dare")
            }
        }
        .padding(.horizontal, 16)
    }

    private func item(_ page: Page) -> some View {
        let on = page == selection
        return Button {
            fb.tap(); withAnimation(.spring(duration: 0.3)) { selection = page }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: page.icon).font(.system(size: 17, weight: .semibold))
                Text(page.rawValue.prefix(1).uppercased() + page.rawValue.dropFirst()).font(.app(fixedSize: 11, weight: .semibold))
            }
            .foregroundStyle(on ? Palette.heat.stops[0] : Color.appText.opacity(0.85))
            .frame(width: 72, height: 48)
            .background {
                if on { Capsule().fill(TabBar.bubbleColor).matchedGeometryEffect(id: "bubble", in: bubble) }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(page.rawValue)
        .accessibilityAddTraits(on ? .isSelected : [])
        .accessibilityIdentifier("page-\(page.rawValue)")
    }

    /// The selected page's bubble: darker than the bar, as iOS 27 does it.
    static var bubbleColor: Color {
        let s = ThemeStore.shared
        switch s.appearance {
        case .dark: return Color.appBackground
        case .light: return Color.hex(0xE6E6EB)
        case .glass: return Color.black.opacity(0.28)
        }
    }
}

private extension View {
    /// The bar's own fill: lighter than the page in dark, white in light, frosted in glass.
    @ViewBuilder func barFill<S: Shape>(_ shape: S) -> some View {
        let s = ThemeStore.shared
        switch s.appearance {
        case .glass:
            self.background(.ultraThinMaterial, in: shape).overlay(shape.stroke(Color.white.opacity(0.22), lineWidth: 0.75))
                .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
        case .light:
            self.background(Color.white, in: shape).shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        case .dark:
            self.background(Color.mix(s.current.bg, s.current.text, 0.16), in: shape)
                .overlay(shape.stroke(Color.white.opacity(0.06), lineWidth: 0.75))
                .shadow(color: .black.opacity(0.4), radius: 12, y: 4)
        }
    }
}

/// A rounded card on the background: the redesign's building block for anything grouped.
struct GroupCard<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 10) { content }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .panel(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

// MARK: - family

/// Everyone who does chores, as photo tiles. Tapping one opens their chores.
struct FamilyPage: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var fb: Feedback
    /// Highlighted on a wide screen, where their day is open beside this.
    var selectedId: String?
    let onPick: (Player) -> Void

    var body: some View {
        GeometryReader { geo in
            // As big as the page allows: one person fills it, and the tiles shrink as more join
            // (`FamilyGrid`), leaving room below for "whose phone" on a linked phone.
            let below: CGFloat = store.isLinked ? 64 : 0
            let layout = FamilyGrid.layout(count: store.players.count, width: Double(geo.size.width - 32),
                                           height: Double(geo.size.height - 16 - below))
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if store.players.isEmpty {
                        Text("Nobody's doing chores yet. An admin can add people in Settings, under Admin.")
                            .font(.app(.callout)).foregroundStyle(Color.done)
                    }
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(layout.tileWidth), spacing: FamilyGrid.gap), count: layout.columns),
                              spacing: FamilyGrid.gap) {
                        ForEach(store.players) { p in tile(p, layout) }
                    }
                    if store.isLinked { WhosePhone() }
                }
                .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 8)
            }
            .scrollDisabled(!layout.scrolls)
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private func tile(_ p: Player, _ layout: FamilyGrid.Layout) -> some View {
        let streak = store.streak(p.id)
        let on = p.id == selectedId
        let a = CGFloat(layout.avatar)
        // The name and streak grow with the tile, within limits.
        let scale = min(1.8, max(1, a / 110))
        return Button { fb.tap(); onPick(p) } label: {
            VStack(spacing: 2 * scale) {
                AvatarView(player: p, size: a)
                Text(store.shownName(p)).font(.app(fixedSize: 15 * scale, weight: .bold)).foregroundStyle(Color.appText)
                    .lineLimit(1).minimumScaleFactor(0.6)
                StreakBadge(streak: streak).scaleEffect(scale).frame(height: 18 * scale)
            }
            .padding(.horizontal, 6)
            .frame(width: layout.tileWidth, height: layout.tileHeight)
            .panel(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay { if on { RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Palette.heat.stops[0], lineWidth: 3) } }
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(BandPress())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(store.shownName(p)), \(streak)-day streak")
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("tile-\(p.id)")
    }
}

/// Pressing a tile dims it a touch and settles it back.
struct BandPress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .brightness(configuration.isPressed ? -0.08 : 0)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// A linked phone: whose phone it is, asked once.
private struct WhosePhone: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var fb: Feedback

    var body: some View {
        if let me = store.me, let mine = store.members.first(where: { $0.id == me }) {
            Text("This is \(store.shownName(mine))'s phone.").font(.app(.caption)).foregroundStyle(Color.done)
                .frame(maxWidth: .infinity)
        } else if !store.players.isEmpty {
            GroupCard {
                Text("Whose phone is this?").font(.app(.headline)).foregroundStyle(Color.appText)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(store.players) { p in
                            Button(store.shownName(p)) { fb.tap(); store.setMe(p) }
                                .font(.app(.callout)).fontWeight(.bold).foregroundStyle(Color.appText)
                                .padding(.horizontal, 18).frame(minHeight: 44).background(Color.appBackground, in: Capsule())
                        }
                    }
                }
            }
        }
    }
}

// MARK: - feed

/// What everyone's done this week, newest first, with the dares on top on a linked phone.
struct FeedPage: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var fb: Feedback
    let onDares: () -> Void

    var body: some View {
        let byId = Dictionary(store.members.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let cal = store.calendar
        let since = cal.date(byAdding: .day, value: -6, to: cal.startOfDay(for: Date()))!
        let items = Array(store.logs.filter { $0.timestamp >= since && byId[$0.playerId] != nil }
            .sorted { $0.timestamp > $1.timestamp }.prefix(100))
        let days = Dictionary(grouping: items) { cal.startOfDay(for: $0.timestamp) }.sorted { $0.key > $1.key }
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                if store.isLinked { FeedDares(onDares: onDares) }
                if items.isEmpty {
                    Text("Nothing done yet this week. Chores show up here as they're sent in.")
                        .font(.app(.callout)).foregroundStyle(Color.done).padding(.top, 8)
                }
                ForEach(days, id: \.key) { day, logs in
                    Text(Self.dayName(day, cal)).font(.app(.subheadline)).fontWeight(.bold).foregroundStyle(Color.done).padding(.top, 8)
                    ForEach(logs) { l in if let p = byId[l.playerId] { item(l, p) } }
                }
            }
            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 20)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private func item(_ l: ChoreLog, _ p: Player) -> some View {
        let (word, color): (String, Color) = switch l.status {
        case Status.approved: ("approved", Theme.good)
        case Status.rejected: ("turned down", Theme.bad)
        default: ("waiting", Color.done)
        }
        return HStack(spacing: 10) {
            AvatarView(player: p, size: 52, showsBorder: false).frame(width: 40, height: 40).offset(y: -4)
            VStack(alignment: .leading, spacing: 2) {
                (Text(store.shownName(p)).fontWeight(.bold) + Text(" \(store.choreName(l.choreId))"))
                    .font(.app(.callout)).foregroundStyle(Color.appText).lineLimit(2)
                HStack(spacing: 6) {
                    Text(l.timestamp.formatted(date: .omitted, time: .shortened)).foregroundStyle(Color.done)
                    Text(word).foregroundStyle(color)
                }
                .font(.app(.footnote)).fontWeight(.semibold)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .panel(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    static func dayName(_ day: Date, _ cal: Calendar) -> String {
        if cal.isDateInToday(day) { return "Today" }
        if cal.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.weekday(.wide))
    }
}

/// The dares, as on the old home screen: the button, and yesterday's revealed.
private struct FeedDares: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var fb: Feedback
    let onDares: () -> Void

    var body: some View {
        let names = Dictionary(store.members.map { ($0.id, store.shownName($0)) }, uniquingKeysWith: { a, _ in a })
        let dares = store.dares
        let yesterday = Engine.dayKey(store.calendar.date(byAdding: .day, value: -1, to: Date())!, calendar: store.calendar)
        let revealed = dares.filter { $0.day == yesterday }
        if let me = store.me, names[me] != nil {
            let used = dares.filter { $0.from == me && $0.day == store.todayKey }.count
            TermButton(label: "Make a dare · \(Engine.maxDaresPerDay - used) left today") { fb.tap(); onDares() }
                .environment(\.palette, .plum)
        }
        if !revealed.isEmpty {
            GroupCard {
                Text("Yesterday's dares").font(.app(.headline)).foregroundStyle(Color.appText)
                let myPoints = store.me.map { id in revealed.reduce(0) { $0 + Engine.darePoints(playerId: id, $1, logs: store.logs, calendar: store.calendar) } } ?? 0
                if myPoints > 0 {
                    Text("You earned \(myPoints) points from dares.").bold().foregroundStyle(Palette.plum.ink)
                        .task { if store.firstReveal(yesterday) { fb.dareLanded() } }
                }
                ForEach(revealed, id: \.self) { d in
                    let landed = Engine.dareLanded(d, logs: store.logs, calendar: store.calendar)
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(names[d.from] ?? d.from) dared \(names[d.target] ?? d.target) to \(store.choreName(d.choreId)).").font(.app(.callout))
                        Spacer()
                        Text(landed ? "Done, +\(Engine.dareGuesserPoints)" : "Didn't happen").font(.app(.footnote)).foregroundStyle(landed ? Theme.good : Color.done)
                    }
                }
            }
        }
    }
}
