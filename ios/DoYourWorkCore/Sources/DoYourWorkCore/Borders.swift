import Foundation

/// A decoration drawn around someone's photo on their family tile: ears, hearts, a crown. Each
/// unlocks once the person has earned `unlockXp` points in all (`Engine` total xp, the same number
/// their version comes from), so there's something to work towards and nothing to buy.
///
/// The drawing is a stack of layers on a `Borders.size` square, painted in order behind the photo,
/// which is the circle at `Borders.photoCenter` with radius `Borders.photoRadius`. Each layer is
/// filled even-odd, so a ring is an outer circle with an inner one cut out. A layer with no colour
/// takes the theme's text colour, so it stands out from an avatar on the theme's main colour.
public struct ProfileBorder: Identifiable, Hashable, Sendable {
    public struct Layer: Hashable, Sendable {
        /// 0xRRGGBB, or nil for the theme's text colour.
        public let color: UInt32?
        public let path: String
    }
    public let id: String
    public let name: String
    public let unlockXp: Int
    public let layers: [Layer]
}

/// The borders and who can use which. The same on Android.
public enum Borders {
    public static let size: Double = 100
    public static let photoCenter = (x: 50.0, y: 58.0)
    public static let photoRadius: Double = 30

    /// The drawings themselves are in `BorderArt`, written out from `tools/borders`.
    public static var all: [ProfileBorder] { BorderArt.all }

    /// The border with this id; nil for none, or one this version doesn't know.
    public static func named(_ id: String?) -> ProfileBorder? {
        guard let id else { return nil }
        return all.first { $0.id == id }
    }

    public static func isUnlocked(_ border: ProfileBorder, xp: Int) -> Bool { xp >= border.unlockXp }

    /// The next border this many points doesn't open yet, and how many more points it needs.
    public static func next(xp: Int) -> (border: ProfileBorder, pointsToGo: Int)? {
        all.filter { $0.unlockXp > xp }.min { $0.unlockXp < $1.unlockXp }.map { ($0, $0.unlockXp - xp) }
    }

    /// The border someone shows: the one they chose, or none. A border from a newer version, or one
    /// they haven't earned (chosen on another phone before a points correction), still shows; only
    /// choosing is limited to the unlocked ones.
    public static func shown(_ player: Player) -> ProfileBorder? {
        named(player.border).flatMap { $0.layers.isEmpty ? nil : $0 }
    }
}

/// Profile photos: a small square JPEG, sent to the family's other phones as one sealed state entry
/// (`FamilyState.photoKey`), so it has to stay well under the relay's 64 KB a record.
public enum ProfilePhoto {
    /// Pixels on each side. Plenty for a tile; small enough to sync every few seconds.
    public static let side = 192
    /// The most base64 text a photo may take. The apps lower the JPEG quality until it fits.
    public static let maxBase64 = 24_000

    /// The photo's base64 if it's one the apps will show: a JPEG within the size limit.
    public static func clean(_ base64: String?) -> String? {
        guard let b = base64?.trimmingCharacters(in: .whitespacesAndNewlines), !b.isEmpty, b.count <= maxBase64,
              let data = Data(base64Encoded: b), data.count > 3, data[0] == 0xFF, data[1] == 0xD8 else { return nil }
        return b
    }
}
