import SwiftUI
import DoYourWorkCore

/// The one main action on a screen: a full-width band of the screen's first colour, like the top
/// row of a Clear list. Dark grey when it can't be pressed yet.
struct TermButton: View {
    let label: String
    var enabled = true
    let action: () -> Void
    var body: some View {
        Button(action: action) { Text(label) }
            .buttonStyle(TermButtonStyle(filled: true)).disabled(!enabled)
            .accessibilityIdentifier("main")
    }
}

/// A secondary action: a quiet dark band, so it never competes with the main one.
struct OutlineButton: View {
    let label: String
    let action: () -> Void
    var body: some View {
        Button(action: action) { Text(label) }.buttonStyle(TermButtonStyle(filled: false))
    }
}

/// The app's buttons: rounded, full width with a margin, the main one in the screen's first colour.
struct TermButtonStyle: ButtonStyle {
    let filled: Bool

    func makeBody(configuration: Configuration) -> some View {
        Face(configuration: configuration, filled: filled)
    }

    private struct Face: View {
        let configuration: ButtonStyleConfiguration
        let filled: Bool
        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.palette) private var palette

        var body: some View {
            let solid = filled && isEnabled
            configuration.label
                .font(.app(filled ? .headline : .callout))
                .fontWeight(filled ? .bold : .semibold)
                .lineLimit(1).minimumScaleFactor(0.7)
                .foregroundStyle(solid ? palette.ink : (isEnabled ? Color.appText : Color.done))
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity, minHeight: filled ? 54 : 46)
                .background(solid ? palette.stops[0] : Color.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 16).padding(.vertical, 4)
                .opacity(configuration.isPressed ? 0.7 : 1)
                .scaleEffect(configuration.isPressed ? 0.98 : 1)
                .animation(.spring(duration: 0.25), value: configuration.isPressed)
        }
    }
}

struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        // Said plainly, as a heading in a sentence would be, not spaced-out capitals.
        Text(text.prefix(1).uppercased() + text.dropFirst()).font(.app(.subheadline)).fontWeight(.bold).foregroundStyle(Color.done)
            .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16).padding(.top, 18).padding(.bottom, 8)
    }
}

/// One chore, as a rounded tile in a grid two across. Picking: a tile lights up when picked. On a
/// card: an unchecked tile is lit, and checking it off drops it to the surface colour, struck
/// through; after it's sent, it shows the admin's verdict.
struct ChoreTile: View {
    @Environment(\.palette) private var palette
    /// Not a parent's verdict: another player got this chore in first today.
    static let taken = "taken"
    let name: String
    let minutes: Int
    var escalLevel = 0
    let checked: Bool
    var status: String? = nil
    /// Where the tile sits in its list: kept for the callers, not used for colour any more.
    var index = 0
    var count = 1
    /// The picker, where a picked tile lights up (instead of a card, where a ticked tile goes dark).
    var picking = false
    var onToggle: (() -> Void)? = nil

    var body: some View {
        let verdict: (String, Color)? = switch status {
        case Status.approved: ("approved", Theme.good)
        case Status.rejected: ("turned down", Theme.bad)
        case Status.pending: ("waiting", palette.ink.opacity(0.85))
        case ChoreTile.taken: ("taken", Color.done)
        default: nil
        }
        let lit = picking ? checked : (status == nil ? !checked : status == Status.pending)
        let struck = !picking && (status == nil ? checked : status == Status.approved || status == ChoreTile.taken)
        let ink = lit ? palette.ink : (picking || status == Status.rejected ? Color.appText : Color.done)
        VStack(alignment: .leading, spacing: 6) {
            Text(name).font(.app(.callout)).fontWeight(.semibold).strikethrough(struck).foregroundStyle(ink)
                .lineLimit(3).minimumScaleFactor(0.8).frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)
            HStack(spacing: 6) {
                if let verdict { Text(verdict.0).font(.app(.footnote)).fontWeight(.bold).foregroundStyle(lit ? palette.ink : verdict.1) }
                else { Text("\(minutes) min").font(.app(.footnote)).fontWeight(.semibold).foregroundStyle(lit ? palette.ink.opacity(0.85) : Color.done) }
                Spacer(minLength: 0)
                if escalLevel > 0 { Text(escalLevel == 1 ? "!" : "!!").font(.app(.callout)).fontWeight(.black).foregroundStyle(lit ? palette.ink : (escalLevel == 1 ? Theme.warn : Theme.bad)) }
                if !picking && status == nil { Image(systemName: checked ? "checkmark.circle.fill" : "circle").foregroundStyle(ink) }
                if picking && checked { Image(systemName: "checkmark").fontWeight(.bold).foregroundStyle(ink) }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 70, alignment: .topLeading)
        .background(lit ? palette.stops[0] : Color.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onTapGesture { if status == nil { onToggle?() } }
        .animation(.easeOut(duration: 0.2), value: checked)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(verdict.map { "\(name), \($0.0)" } ?? name)
        .accessibilityAddTraits(status == nil && onToggle != nil ? .isButton : [])
        .accessibilityValue(status == nil ? (checked ? "checked" : "not checked") : "")
    }

    /// The grid the tiles sit in.
    static let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
}

/// Version, XP bar and streak for one player.
/// Sits on the screen's top band, so everything is white.
struct StatsHeader: View {
    let rank: Rank
    let streak: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(rank.version).font(.app(fixedSize: 32, weight: .black))
                Spacer()
                Text(streak == 0 ? "No streak yet" : "\(streak)-day streak · \(String(format: "%.1f", Engine.momentumMult(streak)))x points")
                    .font(.app(.footnote)).fontWeight(.semibold)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.heat.ink.opacity(0.25))
                    Capsule().fill(Palette.heat.ink).frame(width: g.size.width * CGFloat(rank.pct) / 100)
                }
            }
            .frame(height: 6)
            .animation(.easeOut(duration: 0.7), value: rank.pct)
            Text("\(rank.into) of \(rank.need) xp to \(rank.nextVersion)").font(.app(.caption)).fontWeight(.semibold).opacity(0.75)
        }
        .foregroundStyle(Palette.heat.ink)
    }
}

// MARK: Characters

/// One layer of a character's drawing, scaled to whatever square it's given.
struct CharacterShape: Shape {
    let path: String

    func path(in rect: CGRect) -> Path {
        let s = Double(min(rect.width, rect.height)) / Characters.size
        let left = Double(rect.minX), top = Double(rect.minY)
        func at(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: left + x * s, y: top + y * s) }
        var p = Path()
        for step in Characters.steps(path) {
            switch step {
            case let .move(x, y): p.move(to: at(x, y))
            case let .line(x, y): p.addLine(to: at(x, y))
            case let .quad(cx, cy, x, y): p.addQuadCurve(to: at(x, y), control: at(cx, cy))
            case let .cubic(ax, ay, bx, by, x, y): p.addCurve(to: at(x, y), control1: at(ax, ay), control2: at(bx, by))
            case .close: p.closeSubpath()
            }
        }
        return p
    }
}

/// A player's character, drawn in two colours: the theme's background for the body and its text
/// colour for the eyes and other details, so it stands out on any band of any theme.
struct CharacterIcon: View {
    let character: PlayerCharacter
    let size: CGFloat

    var body: some View {
        ZStack {
            ForEach(Array(character.layers.enumerated()), id: \.offset) { _, layer in
                CharacterShape(path: layer.path).fill(layer.detail ? Color.appText : Color.appBackground)
            }
        }
        .frame(width: size, height: size)
    }
}

/// The little flame beside a streak count: the Flame character's outline, in the text's colour.
struct StreakFlame: View {
    let size: CGFloat
    var body: some View {
        CharacterShape(path: Characters.named("flame")?.layers.first?.path ?? "").frame(width: size, height: size)
    }
}

/// Pick a character. Each is shown on a band of the theme, as it will be on the scoreboard. One
/// another player already has is faded and says whose it is: everyone gets their own.
struct CharacterPicker: View {
    let current: PlayerCharacter?
    /// Character id to the name of the other player who has it.
    let takenBy: [String: String]
    let onPick: (PlayerCharacter) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let all = Characters.all
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Pick your character").font(.app(fixedSize: 26, weight: .black)).lineLimit(1).minimumScaleFactor(0.6)
                Spacer()
                Button("Done") { dismiss() }.font(.app(.callout)).fontWeight(.bold).frame(minHeight: 44)
            }
            .foregroundStyle(Color.appText).tint(Color.appText)
            .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 8)
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 4), spacing: 4) {
                    ForEach(Array(all.enumerated()), id: \.element.id) { i, c in
                        let owner = takenBy[c.id]
                        let mine = c.id == current?.id
                        Button { onPick(c); dismiss() } label: {
                            Palette.heat.band(i % 8, of: 8)
                                .aspectRatio(1, contentMode: .fit)
                                .overlay { CharacterIcon(character: c, size: 48) }
                                .overlay { if mine { Rectangle().strokeBorder(Palette.heat.ink, lineWidth: 3) } }
                                .opacity(owner == nil ? 1 : 0.35)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(owner != nil)
                        .accessibilityLabel(c.name)
                        .accessibilityValue(owner.map { "\($0) has this one" } ?? "")
                        .accessibilityAddTraits(mine ? .isSelected : [])
                        .accessibilityIdentifier("character-\(c.id)")
                    }
                }
                if !takenBy.isEmpty {
                    Text("The faded ones are already someone else's.").font(.app(.footnote)).foregroundStyle(Color.done)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 10)
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 16)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .presentationDetents([.medium, .large])
    }
}
