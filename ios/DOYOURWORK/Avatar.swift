import SwiftUI
import UIKit
import DoYourWorkCore

/// A person's face for the family tiles, the feed and the settings: their photo cropped to a
/// circle, or their character on a circle of the theme's colour, with their border drawn behind it.
/// The view is the whole `Borders.size` square, so ears and crowns have room above the circle.
struct AvatarView: View {
    @EnvironmentObject var store: AppStore
    let player: Player
    /// The side of the whole square.
    let size: CGFloat
    var showsBorder = true
    /// Shows this border instead of the one they wear: the borders list previews each one.
    var borderOverride: ProfileBorder?? = nil

    var body: some View {
        let border: ProfileBorder? = borderOverride ?? (showsBorder ? Borders.shown(player) : nil)
        let unit = size / Borders.size
        let r = Borders.photoRadius * unit
        ZStack(alignment: .topLeading) {
            if let border { BorderLayers(border: border).frame(width: size, height: size) }
            Face(player: player, character: store.characters[player.id], diameter: r * 2)
                .offset(x: Borders.photoCenter.x * unit - r, y: Borders.photoCenter.y * unit - r)
        }
        .frame(width: size, height: size, alignment: .topLeading)
        .accessibilityHidden(true)
    }
}

/// Just the circle: photo, or character on the theme's colour.
private struct Face: View {
    let player: Player
    let character: PlayerCharacter?
    let diameter: CGFloat

    var body: some View {
        Group {
            if let image = PhotoCache.image(player.photo) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                ZStack {
                    Palette.heat.stops[0]
                    if let character { CharacterIcon(character: character, size: diameter * 0.66) }
                    else { Text(player.shownName.prefix(1).uppercased()).font(.app(fixedSize: diameter * 0.45, weight: .black)).foregroundStyle(Palette.heat.ink) }
                }
            }
        }
        .frame(width: diameter, height: diameter)
        .clipShape(Circle())
    }
}

/// A border's layers, each filled even-odd in its own colour (or the theme's text colour).
struct BorderLayers: View {
    let border: ProfileBorder

    var body: some View {
        ZStack {
            ForEach(Array(border.layers.enumerated()), id: \.offset) { _, layer in
                BorderShape(path: layer.path)
                    .fill(layer.color.map { Color.hex($0) } ?? Color.appText, style: FillStyle(eoFill: true))
            }
        }
    }
}

/// One layer of a border's drawing, scaled to whatever square it's given.
struct BorderShape: Shape {
    let path: String

    func path(in rect: CGRect) -> Path {
        let s = Double(min(rect.width, rect.height)) / Borders.size
        func at(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: Double(rect.minX) + x * s, y: Double(rect.minY) + y * s) }
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

/// Decoded photos, so a tile doesn't decode base64 on every redraw.
enum PhotoCache {
    private static let cache = NSCache<NSString, UIImage>()

    static func image(_ base64: String?) -> UIImage? {
        guard let b = ProfilePhoto.clean(base64) else { return nil }
        let key = "\(b.count):\(b.suffix(64))" as NSString
        if let hit = cache.object(forKey: key) { return hit }
        guard let data = Data(base64Encoded: b), let image = UIImage(data: data) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }

    /// A picture from the camera or the library as a profile photo: the middle square, 192 pixels a
    /// side, as JPEG at the best quality that fits `ProfilePhoto.maxBase64`. Nothing else is kept.
    static func profilePhoto(from image: UIImage) -> String? {
        let side = CGFloat(ProfilePhoto.side)
        let w = image.size.width, h = image.size.height
        guard w > 0, h > 0 else { return nil }
        let scale = side / min(w, h)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let square = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { _ in
            image.draw(in: CGRect(x: (side - w * scale) / 2, y: (side - h * scale) / 2, width: w * scale, height: h * scale))
        }
        var quality: CGFloat = 0.8
        while quality > 0.05 {
            if let b = square.jpegData(compressionQuality: quality)?.base64EncodedString(), b.count <= ProfilePhoto.maxBase64 { return b }
            quality -= 0.1
        }
        return nil
    }
}

/// The heading over every page: "doyourwork" in Pacifico, the lettering of the app's icon, filled
/// with its heat colours, over a thin rule.
struct LogoHeading: View {
    static let gradient = LinearGradient(colors: [.hex(0xFF3B2F), .hex(0xE2751C), .hex(0xEDB82A)], startPoint: .leading, endPoint: .trailing)

    var body: some View {
        VStack(spacing: 2) {
            Text("doyourwork")
                .font(.custom("Pacifico", fixedSize: 34))
                .foregroundStyle(Self.gradient)
                .padding(.horizontal, 8)
                .accessibilityAddTraits(.isHeader)
                .accessibilityLabel("DOYOURWORK")
            Rectangle().fill(Color.done.opacity(0.6)).frame(height: 1.5).padding(.horizontal, 40)
        }
        .padding(.top, 2).padding(.bottom, 6)
    }
}

/// The streak under a name on a family tile: the icon's "dyw" lettering and "×N".
struct StreakBadge: View {
    let streak: Int
    var body: some View {
        HStack(spacing: 3) {
            Image("DYWMark").resizable().scaledToFit().frame(width: 22, height: 14)
            Text("×\(streak)").font(.app(fixedSize: 13, weight: .black)).foregroundStyle(Color.appText)
        }
        // Shown for everyone, so the streaks line up: no streak yet is there, faded.
        .opacity(streak > 0 ? 1 : 0.4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(streak)-day streak")
    }
}
