import SwiftUI

/// A look for the app, chosen per phone. "Fuego" is the default (saved as "clear", its old name, so
/// phones that chose it keep it): black, with the Clear app's red-to-yellow heat map for the players, its ocean blues for the admin area and its plums for the dares. The rest
/// are built from four colours each (background, main, muted and text), an idea borrowed from
/// monkeytype's themes; their palettes come from monkeytype's dark themes, under names of our own.
/// The same list as Android's AppTheme.
struct AppTheme: Identifiable, Equatable {
    let id: String
    let name: String
    let bg: Color, main: Color, sub: Color, text: Color

    static let clear = AppTheme(id: "clear", name: "Fuego", bg: .hex(0x000000), main: .hex(0xD90015), sub: .hex(0x5A5A5E), text: .hex(0xFFFFFF))

    static let all: [AppTheme] = [
        clear,
        AppTheme(id: "mustard", name: "Mustard", bg: .hex(0x323437), main: .hex(0xE2B714), sub: .hex(0x646669), text: .hex(0xD1D0C5)),
        AppTheme(id: "ember", name: "Ember", bg: .hex(0x313131), main: .hex(0xF66E0D), sub: .hex(0x616161), text: .hex(0xF5E6C8)),
        AppTheme(id: "bubblegum", name: "Bubblegum", bg: .hex(0x333A45), main: .hex(0xF44C7F), sub: .hex(0x939EAE), text: .hex(0xE9ECF0)),
        AppTheme(id: "coral", name: "Coral", bg: .hex(0x2D394D), main: .hex(0xFF7A90), sub: .hex(0x4A768D), text: .hex(0xFFFAF8)),
        AppTheme(id: "grape", name: "Grape", bg: .hex(0x282A36), main: .hex(0xBD93F9), sub: .hex(0x6272A4), text: .hex(0xF8F8F2)),
        AppTheme(id: "fjord", name: "Fjord", bg: .hex(0x242933), main: .hex(0x88C0D0), sub: .hex(0x929AAA), text: .hex(0xD8DEE9)),
        AppTheme(id: "lavender", name: "Lavender", bg: .hex(0x1E1E2E), main: .hex(0xCBA6F7), sub: .hex(0x7F849C), text: .hex(0xCDD6F4)),
        AppTheme(id: "lagoon", name: "Lagoon", bg: .hex(0x1F1D27), main: .hex(0x9CCFD8), sub: .hex(0xC4A7E7), text: .hex(0xE0DEF4)),
        AppTheme(id: "campfire", name: "Campfire", bg: .hex(0x282828), main: .hex(0xD79921), sub: .hex(0x665C54), text: .hex(0xEBDBB2)),
        AppTheme(id: "matcha", name: "Matcha", bg: .hex(0x523525), main: .hex(0x7EC160), sub: .hex(0x9E6749), text: .hex(0xECDDCC)),
        AppTheme(id: "neon", name: "Neon", bg: .hex(0x262A33), main: .hex(0x43FFAF), sub: .hex(0x526777), text: .hex(0xE5F7EF)),
        AppTheme(id: "sunset", name: "Sunset", bg: .hex(0x18181A), main: .hex(0xE4609B), sub: .hex(0x47BAC0), text: .hex(0xFFFFFF)),
        AppTheme(id: "aurora", name: "Aurora", bg: .hex(0x011926), main: .hex(0x00E980), sub: .hex(0x245C69), text: .hex(0xFFFFFF)),
        AppTheme(id: "peach", name: "Peach", bg: .hex(0x1C1B1D), main: .hex(0xDEAF9D), sub: .hex(0x4E3E3E), text: .hex(0xF2EFED)),
    ]

    var isClear: Bool { id == AppTheme.clear.id }
    /// Text on a band of the main colour: the background colour when the main colour is light.
    var ink: Color { main.luminance > 0.55 ? bg : .white }
    /// A step up from the background, for quiet buttons and empty cells.
    var surface: Color { .mix(bg, text, isClear ? 0.08 : 0.07) }
    /// Muted text and finished rows: the theme's own muted colour, nudged towards the text so it reads.
    var muted: Color { isClear ? sub : .mix(sub, text, 0.25) }

    /// The bands for the players and their chores.
    var heat: Palette {
        isClear ? Palette(stops: [.hex(0xD90015), .hex(0xDB2A15), .hex(0xE04A19), .hex(0xE2751C), .hex(0xE99A22), .hex(0xEDB82A)], ink: .white)
                : Palette(stops: [main, .mix(main, bg, 0.18), .mix(main, bg, 0.34), .mix(main, bg, 0.48)], ink: ink)
    }
    /// The admin area's bands.
    var ocean: Palette {
        isClear ? Palette(stops: [.hex(0x3E9FC4), .hex(0x45AAC0), .hex(0x4FAFAE), .hex(0x58B6A1), .hex(0x60BD8F), .hex(0x6BC276)], ink: .white)
                : Palette(stops: [.mix(main, text, 0.25), .mix(main, bg, 0.2), .mix(main, bg, 0.4)], ink: Color.mix(main, text, 0.25).luminance > 0.55 ? bg : .white)
    }
    /// The dares' bands: a quieter, after-dark version of the theme.
    var plum: Palette {
        isClear ? Palette(stops: [.hex(0x34207A), .hex(0x2B1869), .hex(0x281760), .hex(0x26165C), .hex(0x201453)], ink: .hex(0xB9A2FF))
                : Palette(stops: [.mix(sub, bg, 0.2), .mix(sub, bg, 0.45), .mix(sub, bg, 0.6)], ink: text)
    }
}

/// How the whole app is lit, chosen per phone, on top of the theme's colours: dark (the theme as
/// it is), light (a pale background with dark text), or glass (frosted panels over a wash of the
/// theme's colours).
enum Appearance: String, CaseIterable, Identifiable {
    case dark, light, glass
    var id: String { rawValue }
    var name: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }
}

/// The theme this phone uses, kept on the phone. The app's root redraws when it changes.
final class ThemeStore: ObservableObject {
    static let shared = ThemeStore()
    private static let key = "theme"
    private static let appearanceKey = "appearance"
    @Published var current: AppTheme {
        didSet { UserDefaults.standard.set(current.id, forKey: Self.key) }
    }
    @Published var appearance: Appearance {
        didSet { UserDefaults.standard.set(appearance.rawValue, forKey: Self.appearanceKey) }
    }
    @Published var picking = false
    private init() {
        // A UI test that starts from nothing starts from the default look too, not the last test's.
        if AppStore.uiTesting && AppStore.launchArguments.contains("-resetData") {
            UserDefaults.standard.removeObject(forKey: Self.key)
            UserDefaults.standard.removeObject(forKey: Self.appearanceKey)
        }
        let id = UserDefaults.standard.string(forKey: Self.key)
        current = AppTheme.all.first { $0.id == id } ?? .clear
        appearance = Appearance(rawValue: UserDefaults.standard.string(forKey: Self.appearanceKey) ?? "") ?? .dark
    }

    var isLight: Bool { appearance == .light }
    var isGlass: Bool { appearance == .glass }
}

/// A run of colours that list rows step down, Clear-style, with the colour for text on them.
struct Palette: Equatable {
    let stops: [Color]
    let ink: Color

    static var heat: Palette { ThemeStore.shared.current.heat }
    static var ocean: Palette { ThemeStore.shared.current.ocean }
    static var plum: Palette { ThemeStore.shared.current.plum }

    /// The colour of row `index` in a list of `count`. As in Clear, each row is a small step down
    /// the gradient (a short list stays near the top colour); a long list spreads the whole gradient out.
    func band(_ index: Int, of count: Int) -> Color {
        let s = stops
        guard count > 1, index > 0, s.count > 1 else { return s[0] }
        let span = Double(max(count - 1, 7))
        let t = min(1, Double(index) / span) * Double(s.count - 1)
        let i = min(Int(t), s.count - 2)
        return Color.mix(s[i], s[i + 1], t - Double(i))
    }
}

extension Color {
    static func hex(_ v: UInt32) -> Color {
        Color(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }

    static func mix(_ a: Color, _ b: Color, _ t: Double) -> Color {
        let x = UIColor(a).rgb, y = UIColor(b).rgb
        return Color(red: x.0 + (y.0 - x.0) * t, green: x.1 + (y.1 - x.1) * t, blue: x.2 + (y.2 - x.2) * t)
    }

    var luminance: Double { let c = UIColor(self).rgb; return 0.2126 * c.0 + 0.7152 * c.1 + 0.0722 * c.2 }

    /// The colour as 0xRRGGBB, for the widgets' snapshot (`WidgetBridge`).
    var hexValue: UInt32 {
        let c = UIColor(self).rgb
        func byte(_ v: Double) -> UInt32 { UInt32(max(0, min(255, (v * 255).rounded()))) }
        return byte(c.0) << 16 | byte(c.1) << 8 | byte(c.2)
    }

    /// The theme's background, behind everything. In glass, a deep shade of the theme under the
    /// wash of colour (`AppBackdrop`).
    static var appBackground: Color {
        let s = ThemeStore.shared
        switch s.appearance {
        case .dark: return s.current.bg
        case .light: return .mix(.hex(0xF2F2F7), s.current.main, 0.015)
        case .glass: return .mix(s.current.bg, .black, 0.35)
        }
    }
    /// Ordinary text on the background.
    static var appText: Color { ThemeStore.shared.isLight ? .hex(0x141416) : ThemeStore.shared.current.text }
    /// Where a finished item goes, and quiet text, like a ticked-off row in Clear.
    static var done: Color { ThemeStore.shared.isLight ? .hex(0x6E6E73) : ThemeStore.shared.current.muted }
    /// Tiles, cards and quiet buttons. In glass it's see-through, so the colour behind shows.
    static var surface: Color {
        let s = ThemeStore.shared
        switch s.appearance {
        case .dark: return s.current.surface
        case .light: return .white
        case .glass: return Color.white.opacity(0.13)
        }
    }
}

private extension UIColor {
    var rgb: (Double, Double, Double) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b)
    }
}

private struct PaletteKey: EnvironmentKey { static var defaultValue: Palette { .heat } }
extension EnvironmentValues {
    /// Which run of bands this part of the app uses.
    var palette: Palette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}

/// One full-width row of colour: Clear's whole idea. Content is in the palette's ink, bold enough to
/// read on any step; a finished row drops to the background with its text muted.
struct Band<Content: View>: View {
    @Environment(\.palette) private var palette
    let index: Int
    let count: Int
    var done = false
    var minHeight: CGFloat = 56
    @ViewBuilder let content: Content

    var body: some View {
        content
            .font(.app(.headline))
            .foregroundStyle(done ? Color.done : palette.ink)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
            .background(done ? Color.appBackground : palette.band(index, of: count))
            .contentShape(Rectangle())
    }
}

/// Pick a look, monkeytype-style: every theme's button is painted in that theme, so you see it
/// before you choose. Picking applies straight away and the picker stays open to try another.
struct ThemePicker: View {
    @ObservedObject var themes = ThemeStore.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let current = themes.current
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Pick a look").font(.app(fixedSize: 26, weight: .black))
                Spacer()
                Button("Done") { dismiss() }.font(.app(.callout)).fontWeight(.bold).frame(minHeight: 44)
            }
            .foregroundStyle(current.text).tint(current.text)
            .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 4)
            Text("Just for this phone. Everyone can pick their own.").font(.app(.footnote)).foregroundStyle(current.muted)
                .padding(.horizontal, 16).padding(.bottom, 12)
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    ForEach(AppTheme.all) { t in
                        Button { themes.current = t } label: {
                            HStack(spacing: 10) {
                                Text(t.name).font(.app(.callout)).fontWeight(.bold).foregroundStyle(t.isClear ? .white : t.main)
                                Spacer(minLength: 4)
                                HStack(spacing: 3) {
                                    ForEach(Array(t.heat.stops.prefix(3).enumerated()), id: \.offset) { _, c in Circle().fill(c).frame(width: 9, height: 9) }
                                }
                            }
                            .padding(.horizontal, 14).frame(maxWidth: .infinity, minHeight: 52)
                            .background(t.bg, in: RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(t.id == current.id ? current.text : Color.white.opacity(0.08), lineWidth: t.id == current.id ? 2 : 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(t.id == current.id ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 24)
            }
        }
        .background(current.bg.ignoresSafeArea())
        .presentationDetents([.medium, .large])
    }
}

extension View {
    /// The colour runs right up under the status bar, so the system's darkening at the top edge of
    /// a scroll view only muddies it.
    @ViewBuilder func noScrollEdgeShade() -> some View {
        // Built with Xcode 26 or later (the iOS 26 SDK); Xcode 16, which CI also uses, doesn't have it.
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) { scrollEdgeEffectHidden(true, for: .top) } else { self }
        #else
        self
        #endif
    }
}

/// What's behind every page: the plain background, or in glass a wash of the theme's colours for
/// the frosted panels to sit on.
struct AppBackdrop: View {
    var body: some View {
        let s = ThemeStore.shared
        if s.isGlass {
            let stops = s.current.heat.stops
            ZStack {
                Color.appBackground
                LinearGradient(colors: [stops[0].opacity(0.75), Color.appBackground.opacity(0.2), (stops.last ?? stops[0]).opacity(0.55)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                RadialGradient(colors: [s.current.sub.opacity(0.45), .clear], center: .bottomLeading, startRadius: 10, endRadius: 420)
            }
            .ignoresSafeArea()
        } else {
            Color.appBackground.ignoresSafeArea()
        }
    }
}

extension View {
    /// A tile's or card's fill: the surface colour, or real frosted glass in the glass appearance.
    @ViewBuilder func panel<S: Shape>(_ shape: S) -> some View {
        if ThemeStore.shared.isGlass {
            self.background(.ultraThinMaterial, in: shape)
                .overlay(shape.stroke(Color.white.opacity(0.18), lineWidth: 0.75))
        } else if ThemeStore.shared.isLight {
            self.background(Color.surface, in: shape).shadow(color: .black.opacity(0.06), radius: 6, y: 2)
        } else {
            self.background(Color.surface, in: shape)
        }
    }
}
