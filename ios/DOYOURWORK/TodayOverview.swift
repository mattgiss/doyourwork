import SwiftUI
import DoYourWorkCore

/// The right-hand pane on a wide screen (an iPad, an unfolded iPhone Duo) before anyone's picked:
/// where everyone's at today, instead of an empty half of the screen. One band per player, in this
/// week's order and the scoreboard's colours; tapping a band opens that player's day.
///
/// The numbers come from the same snapshot the widgets show, so the two never disagree.
struct TodayOverview: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var fb: Feedback
    let onPick: (Player) -> Void

    var body: some View {
        let snapshot = WidgetBridge.snapshot(store)
        let bands = snapshot.players.count + 1
        VStack(spacing: 0) {
            // The title stays put above the list. Its band runs up under the status bar and on under
            // a side bar (the clock on an iPhone Duo), as the player's screen does; the words stay
            // inside the safe area.
            VStack(alignment: .leading, spacing: 4) {
                Text("Today").font(.app(fixedSize: 28, weight: .black))
                Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.app(.callout)).fontWeight(.semibold).opacity(0.85)
            }
            .foregroundStyle(Palette.heat.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 14)
            .background(Palette.heat.band(0, of: bands), ignoresSafeAreaEdges: [.top, .horizontal])

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if snapshot.players.isEmpty {
                        Text("> add players in the admin area").foregroundStyle(.secondary).padding(20)
                    }
                    ForEach(Array(snapshot.players.enumerated()), id: \.element.id) { i, p in
                        row(p, band: i + 1, of: bands)
                    }
                    Text("Pick someone to see their card.").font(.app(.footnote)).foregroundStyle(Color.done)
                        .padding(.horizontal, 20).padding(.top, 14)
                }
                .padding(.bottom, 24)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(Color.appBackground)
    }

    private func row(_ p: WidgetSnapshot.Player, band: Int, of bands: Int) -> some View {
        let ink = Palette.heat.ink
        let progress = p.minutesPlanned > 0 ? Double(p.minutesDone) / Double(p.minutesPlanned) : 0
        return Button {
            fb.tap()
            if let player = store.players.first(where: { $0.id == p.id }) { onPick(player) }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(p.name).font(.app(.headline)).fontWeight(.black).lineLimit(1)
                    Spacer(minLength: 8)
                    Text(Self.minutes(p)).font(.app(.subheadline)).fontWeight(.bold).monospacedDigit()
                }
                Text(Self.status(p)).font(.app(.subheadline)).fontWeight(.semibold).opacity(0.85).lineLimit(2)
                // How far through today's card: empty before one's picked.
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(ink.opacity(0.25))
                        Rectangle().fill(ink).frame(width: geo.size.width * progress)
                    }
                }
                .frame(height: 6)
                .accessibilityHidden(true)
            }
            .foregroundStyle(ink)
            .padding(.horizontal, 20).padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.heat.band(band, of: bands), ignoresSafeAreaEdges: .horizontal)
            .contentShape(Rectangle())
        }
        .buttonStyle(BandPress())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens \(p.name)'s card")
    }

    static func minutes(_ p: WidgetSnapshot.Player) -> String {
        p.minutesPlanned > 0 ? "\(p.minutesDone)/\(p.minutesPlanned) min" : "–"
    }

    /// Where a player's day stands, in a few words.
    static func status(_ p: WidgetSnapshot.Player) -> String {
        switch p.card {
        case "playing": p.next.map { "Playing · next: \($0)" } ?? "Playing"
        case "sent": "Waiting on an admin"
        case "approved": "All approved. Nice work!"
        default: "No card picked yet"
        }
    }
}
