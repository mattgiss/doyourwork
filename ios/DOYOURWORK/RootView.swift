import SwiftUI
import DoYourWorkCore

/// Decides how the app is laid out.
///
/// - Narrow (an iPhone, or an iPad app squeezed into a slim window): one screen at a time. Picking
///   a player pushes their day; the admin area covers the screen.
/// - Wide (an iPad): two panes, like the Android app on a foldable's inner screen. The home list
///   stays on the left and the player's day or the admin area opens on the right.
struct RootView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var fb: Feedback
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.scenePhase) private var scenePhase

    // What's open lives here, above both layouts, so rotating an iPad or resizing its window
    // lands on the same screen.
    @State private var selectedId: String?
    @State private var adminOpen = false
    @State private var daresOpen = false
    /// A foldable (the iPhone Duo) open on its inner screen, flat or half open: its fold runs top
    /// to bottom down the middle of the screen, so the two panes split there rather than across it.
    @State private var unfolded = false

    private var selected: Player? { store.players.first { $0.id == selectedId } }

    var body: some View {
        layout
            .modifier(WatchesHinge(unfolded: $unfolded))
            // Sync on open and every 10 seconds while the app is on screen, as on Android.
            .task { while !Task.isCancelled { store.requestSync(); try? await Task.sleep(for: .seconds(10)) } }
            // The two daily notifications: asked about once the family is set up, and rescheduled
            // whenever the app opens or leaves the screen (a new day, a new player, a new phone owner).
            .onChange(of: scenePhase, initial: true) { _, _ in remind() }
            .onChange(of: store.isSetUp) { _, _ in remind() }
            .onChange(of: store.me) { _, _ in remind() }
    }

    @ViewBuilder private var layout: some View {
        // A phone that just joined a family: until its lists have loaded once, no players doesn't
        // mean a new family.
        if store.isLinked && !store.hasSynced && !store.isSetUp { FamilyLoadingView() }
        else if !store.isSetUp { SetupView().onAppear(perform: reset) }
        else if sizeClass == .regular { twoPane } else { onePane }
    }

    private func remind() {
        if store.isSetUp && scenePhase == .active { ReminderScheduler.shared.askPermission(store) }
        ReminderScheduler.shared.reschedule(store, force: true)
    }

    /// The scoreboard was erased and set up again: don't reopen whatever was open before.
    private func reset() {
        adminOpen = false; selectedId = nil
        daresOpen = false
    }

    private func home(highlighting id: String?) -> HomeView {
        HomeView(
            selectedId: id,
            onPick: { adminOpen = false; daresOpen = false; selectedId = $0.id },
            onAdmin: { daresOpen = false; adminOpen = true },
            onDares: { adminOpen = false; daresOpen = true }
        )
    }

    // MARK: One screen at a time

    private var onePane: some View {
        // The path holds the player's id, not the player: a new display name then redraws the
        // screen that's open instead of counting as somewhere new to go.
        NavigationStack(path: Binding(
            get: { selected.map { [$0.id] } ?? [] },
            set: { selectedId = $0.last }
        )) {
            home(highlighting: nil)
                .navigationDestination(for: String.self) { id in
                    if let player = store.players.first(where: { $0.id == id }) { PlayerView(player: player) }
                }
                .toolbar(.hidden, for: .navigationBar)
        }
        .fullScreenCover(isPresented: $adminOpen) {
            AdminView().environmentObject(store).environmentObject(fb).font(.app(.body)).tint(Theme.accent)
        }
        .sheet(isPresented: $daresOpen) { DaresView().appChrome(store, fb) }
    }

    // MARK: Two panes

    private var twoPane: some View {
        GeometryReader { geo in
            let listWidth = Self.listWidth(geo, unfolded: unfolded)
            HStack(spacing: 0) {
                home(highlighting: adminOpen ? nil : selectedId)
                    .frame(width: listWidth)
                Divider()
                detail
                    // Rows stretched across a 13-inch screen are hard to read, so the words keep to a
                    // column. It's padding to the safe area rather than a narrower frame, so the
                    // screen's colour bands and buttons still run edge to edge across the pane, not
                    // as an island with black on either side. Today's bands are short lines of a
                    // few words, so they get the full width.
                    .safeAreaPadding(.horizontal, showsOverview ? 0 : Self.columnInset(paneWidth: geo.size.width - listWidth - 1))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    /// How wide the home list is beside the open screen. Roughly a third of the width, as on
    /// Android, kept between limits so the list is neither cramped on an upright iPad nor
    /// sprawling on a big one turned sideways. On an unfolded iPhone Duo the split lands on the
    /// fold instead (the middle of the whole screen, wherever the safe area puts this pane), so
    /// neither side has anything in the crease, as Android does on a foldable in book posture.
    /// How far in from each side of the right-hand pane its words sit, so they read as a column
    /// of at most 640 points.
    static func columnInset(paneWidth: CGFloat) -> CGFloat { max(0, (paneWidth - 640) / 2) }

    static func listWidth(_ geo: GeometryProxy, unfolded: Bool) -> CGFloat {
        let ordinary = min(max(geo.size.width * 0.36, 320), 420)
        guard unfolded else { return ordinary }
        let frame = geo.frame(in: .global)
        let screenWidth = frame.minX + geo.size.width + geo.safeAreaInsets.trailing
        let atFold = screenWidth / 2 - frame.minX
        // Only when both halves still fit; otherwise the usual split is the better one.
        return atFold >= 320 && geo.size.width - atFold >= 320 ? atFold : ordinary
    }

    /// Nothing's open on the right yet, so it shows `TodayOverview`.
    private var showsOverview: Bool { !adminOpen && !daresIsOpen && selected == nil }

    private var daresIsOpen: Bool {
        daresOpen && store.me != nil && store.isLinked
    }

    @ViewBuilder private var detail: some View {
        if adminOpen {
            AdminView(onBack: { adminOpen = false })
        } else if daresIsOpen {
            DaresView(onBack: { daresOpen = false })
        } else if let selected {
            // A fresh screen per player, so one kid's half-picked card doesn't carry over to the next.
            PlayerView(player: selected, showsBack: false).id(selected.id)
        } else {
            // Nobody picked yet: where everyone's at today, rather than half a screen of nothing.
            TodayOverview(onPick: { adminOpen = false; daresOpen = false; selectedId = $0.id })
        }
    }
}

/// A phone that just joined a family: waiting for the family's players to load.
private struct FamilyLoadingView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        VStack(spacing: 16) {
            Text("DOYOURWORK").font(.app(fixedSize: 34, weight: .black)).lineLimit(1).minimumScaleFactor(0.6).foregroundStyle(Palette.heat.stops[0])
            if store.syncStatus == "offline" {
                Text("Can't reach the family's scoreboard. Check the connection and try again.").foregroundStyle(.secondary).multilineTextAlignment(.center)
                Button("Try again") { store.requestSync() }.buttonStyle(.bordered)
            } else {
                ProgressView()
                Text("Loading the family…").foregroundStyle(.secondary)
            }
        }
        .padding(24)
    }
}

/// Keeps `unfolded` up to date on a foldable: true while its hinge is open, flat or partly, so the
/// inner screen is lit. Hinge updates arrived with iOS 27.1; before that, and on devices with no
/// hinge, it stays false.
///
/// The hinge API is only in the iOS 27.1 SDK (Xcode 27.1 and later, Swift 6.4). CI still builds
/// with older Xcodes, which don't know these types at all, so there the app builds without it and
/// simply doesn't split at the fold. Release builds come from a Mac with the new Xcode.
private struct WatchesHinge: ViewModifier {
    @Binding var unfolded: Bool

    func body(content: Content) -> some View {
        #if compiler(>=6.4)
        if #available(iOS 27.1, *) {
            content.onHingeChange { _, now in
                unfolded = Self.isOpen(now.hinge)
            }
        } else {
            content
        }
        #else
        content
        #endif
    }

    #if compiler(>=6.4)
    @available(iOS 27.1, *)
    private static func isOpen(_ hinge: DeviceHinge?) -> Bool {
        guard let status = hinge?.status else { return false }
        return status == .fullyOpen || status == .partiallyOpen
    }
    #endif
}
