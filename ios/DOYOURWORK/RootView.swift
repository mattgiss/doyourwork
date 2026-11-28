import SwiftUI
import DoYourWorkCore

/// Decides how the app is laid out (docs/design/whiteboard-redesign.md).
///
/// - Narrow (an iPhone, or an iPad app squeezed into a slim window): the heading, then three pages
///   swiped between (family, feed, settings) with the tab bar floating at the bottom. Tapping a
///   family tile pushes that person's profile.
/// - Wide (an iPad, an unfolded iPhone Duo): the family stays on the left as a pane; the right
///   pane swipes between feed and settings, or shows the profile of whoever was tapped.
struct RootView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var fb: Feedback
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.scenePhase) private var scenePhase

    // Kept in the scene, not the view: changing the theme or the appearance redraws the whole app,
    // and that shouldn't throw you back to the family page.
    @SceneStorage("page") private var page = Page.family
    /// Whose profile is open, if anyone's.
    @SceneStorage("profile") private var profileId = ""
    /// Whose photo and border settings shows: picked there, or from a profile. Empty falls back to
    /// whose phone this is.
    @SceneStorage("person") private var personId = ""
    /// "Switch person" was tapped in settings: ask whose profile, even on a phone that's someone's.
    @SceneStorage("choosing") private var choosing = false
    @State private var adminOpen = false
    @State private var dareTarget: DareSheet?
    /// A foldable (the iPhone Duo) open on its inner screen, flat or half open: its fold runs top
    /// to bottom down the middle of the screen, so the two panes split there rather than across it.
    @State private var unfolded = false

    private struct DareSheet: Identifiable { let target: String?; var id: String { target ?? "-" } }

    /// The person settings shows, if there is one.
    private var person: Player? {
        guard !choosing else { return nil }
        let id = personId.isEmpty ? store.me : personId
        return store.players.first { $0.id == id }
    }

    private var profile: Player? { store.players.first { $0.id == profileId } }

    /// Dares need each phone to be someone's: only a family on more than one phone has them.
    private var canDare: Bool { store.isLinked && store.me.map { id in store.players.contains { $0.id == id } } == true }

    /// Once per launch: a UI test starting from nothing shouldn't find the last run's page or profile
    /// still open (the scene keeps them across launches).
    private static var testResetDone = false

    var body: some View {
        layout
            .onAppear {
                if AppStore.uiTesting && AppStore.launchArguments.contains("-resetData") && !Self.testResetDone {
                    Self.testResetDone = true; reset()
                }
            }
            .modifier(WatchesHinge(unfolded: $unfolded))
            // Sync on open and every 10 seconds while the app is on screen, as on Android.
            .task { while !Task.isCancelled { store.requestSync(); try? await Task.sleep(for: .seconds(10)) } }
            // The two daily notifications: asked about once the family is set up, and rescheduled
            // whenever the app opens or leaves the screen (a new day, a new player, a new phone owner).
            .onChange(of: scenePhase, initial: true) { _, _ in remind() }
            .onChange(of: store.isSetUp) { _, _ in remind() }
            .onChange(of: store.me) { _, _ in remind() }
            .fullScreenCover(isPresented: $adminOpen) {
                AdminView().environmentObject(store).environmentObject(fb).font(.app(.body)).tint(Theme.accent)
            }
            .sheet(item: $dareTarget) { DaresView(initialTarget: $0.target).appChrome(store, fb) }
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

    /// The scoreboard was erased and set up again: start from the family page.
    private func reset() {
        adminOpen = false; dareTarget = nil
        page = .family; profileId = ""; personId = ""; choosing = false
    }

    private func choose(_ p: Player) { personId = p.id; choosing = false }

    /// From a profile to that person's photo and border, in settings.
    private func editLook(_ p: Player) {
        personId = p.id; choosing = false; profileId = ""
        withAnimation(.easeInOut(duration: 0.25)) { page = .settings }
    }

    @ViewBuilder private func content(_ p: Page) -> some View {
        switch p {
        case .family: FamilyPage(onPick: { profileId = $0.id })
        case .feed: FeedPage(onDares: { dareTarget = DareSheet(target: nil) })
        case .settings: SettingsPage(person: person, onChoose: choose, onSwitch: { choosing = true }, onAdmin: { adminOpen = true })
        }
    }

    /// Someone's profile, with the ways out of it.
    private func profileView(_ p: Player) -> some View {
        // On your own phone, your own look; on a shared one, anyone's.
        let mine = !store.isLinked || store.me == nil || store.me == p.id
        return PlayerView(player: p,
                          onBack: { profileId = "" },
                          onDare: canDare && store.me != p.id ? { dareTarget = DareSheet(target: p.id) } : nil,
                          onEditLook: mine ? { editLook(p) } : nil)
            // A fresh screen per person, so one kid's half-picked card doesn't carry over to the next.
            .id(p.id)
    }

    // MARK: One screen

    private var onePane: some View {
        NavigationStack(path: Binding(
            get: { profile.map { [$0.id] } ?? [] },
            set: { profileId = $0.last ?? "" }
        )) {
            VStack(spacing: 0) {
                LogoHeading()
                PagesView(pages: Page.allCases, selection: $page, onDare: canDare ? { dareTarget = DareSheet(target: nil) } : nil) { content($0) }
            }
            .background(AppBackdrop())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: String.self) { id in
                if let p = store.players.first(where: { $0.id == id }) {
                    profileView(p).background(AppBackdrop()).toolbar(.hidden, for: .navigationBar)
                }
            }
        }
    }

    // MARK: Two panes

    private var twoPane: some View {
        GeometryReader { geo in
            let listWidth = Self.listWidth(geo, unfolded: unfolded)
            let right: [Page] = [.feed, .settings]
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    LogoHeading()
                    FamilyPage(selectedId: profile?.id, onPick: { profileId = $0.id })
                }
                .frame(width: listWidth)
                Divider()
                Group {
                    if let profile { profileView(profile) }
                    else {
                        PagesView(pages: right, selection: Binding(get: { right.contains(page) ? page : .feed }, set: { page = $0 }),
                                  onDare: canDare ? { dareTarget = DareSheet(target: nil) } : nil) { content($0) }
                    }
                }
                // Rows stretched across a 13-inch screen are hard to read, so the pages keep to a
                // column of at most 640 points.
                .safeAreaPadding(.horizontal, Self.columnInset(paneWidth: geo.size.width - listWidth - 1))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(AppBackdrop())
    }

    /// How far in from each side of the right-hand pane its words sit, so they read as a column
    /// of at most 640 points.
    static func columnInset(paneWidth: CGFloat) -> CGFloat { max(0, (paneWidth - 640) / 2) }

    /// How wide the family pane is beside the pages. Roughly a third of the width, kept between
    /// limits so it's neither cramped on an upright iPad nor sprawling on a big one turned sideways.
    /// On an unfolded iPhone Duo the split lands on the fold instead (the middle of the whole
    /// screen, wherever the safe area puts this pane), so neither side has anything in the crease.
    static func listWidth(_ geo: GeometryProxy, unfolded: Bool) -> CGFloat {
        let ordinary = min(max(geo.size.width * 0.36, 320), 420)
        guard unfolded else { return ordinary }
        let frame = geo.frame(in: .global)
        let screenWidth = frame.minX + geo.size.width + geo.safeAreaInsets.trailing
        let atFold = screenWidth / 2 - frame.minX
        // Only when both halves still fit; otherwise the usual split is the better one.
        return atFold >= 320 && geo.size.width - atFold >= 320 ? atFold : ordinary
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
