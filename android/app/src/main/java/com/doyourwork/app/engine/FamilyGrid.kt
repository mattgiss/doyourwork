package com.doyourwork.app.engine

/**
 * How the family page lays out its tiles: as big as the space allows, so one person fills the page
 * and the tiles shrink as more join, until they'd be too small, when it becomes a scrolling grid of
 * small tiles. The same on iOS (`FamilyGrid.swift`). Sizes are in dp.
 */
object FamilyGrid {
    data class Layout(
        val columns: Int,
        val rows: Int,
        val tileWidth: Double,
        val tileHeight: Double,
        /** The side of the avatar's square (its border included), inside a tile. */
        val avatar: Double,
        /** Too many people to fit: small tiles in a grid that scrolls. */
        val scrolls: Boolean,
    )

    /** Space between tiles. */
    const val GAP = 12.0
    /** A tile is never taller than this many times its width, so a lone tile stays a card, not a strip. */
    const val MAX_TALLNESS = 1.4
    /** Below this the tiles scroll instead of shrinking further. */
    const val MIN_AVATAR = 84.0

    /** The avatar that fits a tile: most of its width, leaving room under it for the name and streak. */
    fun avatar(width: Double, height: Double): Double = maxOf(0.0, minOf(width * 0.8, height - 64 - height * 0.08))

    /**
     * The layout for [count] tiles in a [width] × [height] space. Tries every number of columns up
     * to [maxColumns] and keeps the one with the biggest avatars (fewer columns on a tie).
     */
    fun layout(count: Int, width: Double, height: Double, maxColumns: Int = 6): Layout {
        val n = maxOf(1, count)
        var best: Layout? = null
        for (columns in 1..minOf(n, maxColumns)) {
            val rows = (n + columns - 1) / columns
            val w = (width - GAP * (columns - 1)) / columns
            val h = minOf((height - GAP * (rows - 1)) / rows, w * MAX_TALLNESS)
            val a = avatar(w, h)
            if (best == null || a > best.avatar + 0.5) best = Layout(columns, rows, w, h, a, scrolls = false)
        }
        if (best != null && best.avatar >= MIN_AVATAR) return best
        // A big family on a small screen: small tiles, three or more across, scrolling.
        val columns = minOf(maxColumns, maxOf(3, (width / 120).toInt()))
        val w = (width - GAP * (columns - 1)) / columns
        val h = w * 1.25
        return Layout(columns, (n + columns - 1) / columns, w, h, avatar(w, h), scrolls = true)
    }
}
