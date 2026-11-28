package com.doyourwork.app.engine

import com.doyourwork.app.model.Player

/**
 * A decoration drawn around someone's photo on their family tile: ears, hearts, a crown. Each
 * unlocks once the person has earned [unlockXp] points in all (total xp, the same number their
 * version comes from), so there's something to work towards and nothing to buy.
 *
 * The drawing is a stack of layers on a [Borders.SIZE] square, painted in order behind the photo,
 * which is the circle at ([Borders.PHOTO_X], [Borders.PHOTO_Y]) with radius [Borders.PHOTO_RADIUS].
 * Each layer is filled even-odd, so a ring is an outer circle with an inner one cut out. A layer
 * with no colour takes the theme's text colour. The same as iOS's `ProfileBorder`.
 */
data class ProfileBorder(val id: String, val name: String, val unlockXp: Int, val layers: List<Layer>) {
    /** [color] is 0xFFRRGGBB, or null for the theme's text colour. */
    data class Layer(val color: Long?, val path: String)
}

/** The borders and who can use which. The same on iOS (`Borders.swift`). */
object Borders {
    const val SIZE = 100f
    const val PHOTO_X = 50f
    const val PHOTO_Y = 58f
    const val PHOTO_RADIUS = 30f

    /** The drawings themselves are in [BorderArt], written out from `tools/borders`. */
    val all: List<ProfileBorder> get() = BorderArt.ALL

    /** The border with this id; null for none, or one this version doesn't know. */
    fun named(id: String?): ProfileBorder? = id?.let { i -> all.firstOrNull { it.id == i } }

    fun isUnlocked(border: ProfileBorder, xp: Int): Boolean = xp >= border.unlockXp

    /** The next border this many points doesn't open yet, and how many more points it needs. */
    data class Next(val border: ProfileBorder, val pointsToGo: Int)

    fun next(xp: Int): Next? =
        all.filter { it.unlockXp > xp }.minByOrNull { it.unlockXp }?.let { Next(it, it.unlockXp - xp) }

    /**
     * The border someone shows: the one they chose, or none. A border from a newer version, or one
     * they haven't earned (chosen on another phone before a points correction), still shows if
     * it's known; only choosing is limited to the unlocked ones.
     */
    fun shown(player: Player): ProfileBorder? = named(player.border)?.takeIf { it.layers.isNotEmpty() }
}

/**
 * Profile photos: a small square JPEG, sent to the family's other phones as one sealed state entry
 * (`photo|<id>`), so it has to stay well under the relay's 64 KB a record. The same as iOS.
 */
object ProfilePhoto {
    /** Pixels on each side. Plenty for a tile; small enough to sync every few seconds. */
    const val SIDE = 192
    /** The most base64 text a photo may take. The apps lower the JPEG quality until it fits. */
    const val MAX_BASE64 = 24_000

    /** The photo's base64 if it's one the apps will show: a JPEG within the size limit. */
    fun clean(base64: String?): String? {
        val b = base64?.trim()?.takeIf { it.isNotEmpty() && it.length <= MAX_BASE64 } ?: return null
        val data = runCatching { java.util.Base64.getDecoder().decode(b) }.getOrNull() ?: return null
        if (data.size <= 3 || data[0] != 0xFF.toByte() || data[1] != 0xD8.toByte()) return null
        return b
    }
}
