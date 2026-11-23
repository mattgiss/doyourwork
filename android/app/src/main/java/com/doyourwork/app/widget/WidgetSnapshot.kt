package com.doyourwork.app.widget

import com.doyourwork.app.engine.Engine
import kotlinx.serialization.Serializable

/**
 * What the home screen widgets show, written by the app to its own files every time the scoreboard
 * changes (see [WidgetWriter]). The widgets only read this file, so they can't change a score or
 * see a dare before it's revealed. The same fields as iOS's WidgetSnapshot.
 */
@Serializable
data class WidgetSnapshot(
    /** Local date the numbers are for (yyyy-MM-dd), and the Monday of that week. */
    val day: String,
    val weekStart: String,
    /** Everyone who plays, highest week points first. */
    val players: List<Player>,
    /** Whose phone this is, if it's been set (a linked family only). */
    val me: String? = null,
    /** Dares need a family on more than one phone. */
    val linked: Boolean = false,
    val daresLeftToday: Int = Engine.MAX_DARES_PER_DAY,
    val yesterdaysDares: List<Revealed> = emptyList(),
    val colors: Colors = Colors.FUEGO,
) {
    @Serializable
    data class Player(
        val id: String,
        val name: String,
        /** Minutes ticked off on today's card, and the card's total. Both 0 before a card is picked. */
        val minutesDone: Int,
        val minutesPlanned: Int,
        /** "pick" (no card yet), "playing", "sent" (waiting on a parent) or "approved". */
        val card: String,
        /** The first chore on today's card not ticked off yet. */
        val next: String? = null,
        val streak: Int,
        /** True when today already counts towards the streak (something was approved today). */
        val streakToday: Boolean,
        val weekPoints: Int,
        /** Their rank, such as "v1.3". */
        val version: String,
    )

    /** A dare from the day before [day], already revealed in the app. */
    @Serializable
    data class Revealed(val from: String, val target: String, val fromName: String, val targetName: String, val chore: String, val landed: Boolean)

    /** The theme's colours as 0xRRGGBB, so the widgets match the app. */
    @Serializable
    data class Colors(
        val bg: Long, val text: Long, val muted: Long, val surface: Long, val accent: Long,
        /** The scoreboard's bands, top to bottom, and the colour of text on them. */
        val heat: List<Long>, val heatInk: Long,
        val plum: Long, val plumInk: Long,
    ) {
        companion object {
            /** Fuego, the default look, for a widget added before the app has run. */
            val FUEGO = Colors(0x000000, 0xFFFFFF, 0x5A5A5E, 0x141414, 0xE8572A,
                listOf(0xD90015, 0xDB2A15, 0xE04A19, 0xE2751C, 0xE99A22, 0xEDB82A), 0xFFFFFF, 0x34207A, 0xB9A2FF)
        }
    }

    /**
     * The snapshot as it reads on [today], [week] being that day's Monday. A widget can outlive the
     * day its snapshot was written: from midnight a new card hasn't been picked, a streak without an
     * approved day yesterday has broken, and yesterday's dares are ones the app hasn't revealed to
     * this file yet. From Monday the week's points start again.
     */
    fun asOf(today: String, week: String, yesterday: String): WidgetSnapshot {
        if (today == day) return this
        val newWeek = week != weekStart
        val ps = players.map { p ->
            p.copy(minutesDone = 0, minutesPlanned = 0, card = "pick", next = null,
                // Snapshot day was yesterday: the streak carries if that day counted. Older: it broke.
                streak = if (day == yesterday && p.streakToday) p.streak else 0,
                streakToday = false,
                weekPoints = if (newWeek) 0 else p.weekPoints)
        }
        return copy(day = today, weekStart = if (newWeek) week else weekStart,
            players = if (newWeek) ps.sortedByDescending { it.weekPoints } else ps,
            daresLeftToday = Engine.MAX_DARES_PER_DAY, yesterdaysDares = emptyList())
    }

    fun player(id: String?): Player? = id?.let { i -> players.firstOrNull { it.id == i } }

    /** Place on this week's board, 1 for first; players on the same points share a place. */
    fun place(id: String): Int? = player(id)?.let { p -> players.count { it.weekPoints > p.weekPoints } + 1 }
}
