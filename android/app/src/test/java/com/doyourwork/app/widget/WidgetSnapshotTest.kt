package com.doyourwork.app.widget

import com.doyourwork.app.engine.Engine
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

/** The same cases as iOS's WidgetSnapshotTests. */
class WidgetSnapshotTest {
    private fun snap() = WidgetSnapshot("2026-11-21", "2026-11-16", listOf(
        WidgetSnapshot.Player("1", "Riley", 18, 25, "playing", "Dishes", 4, true, 40, "v1.3"),
        WidgetSnapshot.Player("2", "Sam", 25, 25, "sent", null, 3, false, 90, "v1.1"),
    ), me = "1", linked = true, daresLeftToday = 1,
        yesterdaysDares = listOf(WidgetSnapshot.Revealed("2", "1", "Sam", "Riley", "Dishes", true)))

    @Test fun sameDayIsUnchanged() {
        val s = snap()
        assertSame(s, s.asOf("2026-11-21", "2026-11-16", "2026-11-20"))
    }

    @Test fun nextDayStartsAFreshCard() {
        val s = snap().asOf("2026-11-22", "2026-11-16", "2026-11-21")
        assertEquals(listOf("pick", "pick"), s.players.map { it.card })
        assertEquals(listOf(0, 0), s.players.map { it.minutesDone })
        // Riley's yesterday counted, so the streak carries; Sam's didn't, so it broke.
        assertEquals(listOf(4, 0), s.players.map { it.streak })
        assertEquals(listOf(40, 90), s.players.map { it.weekPoints })
        assertTrue(s.yesterdaysDares.isEmpty())
        assertEquals(Engine.MAX_DARES_PER_DAY, s.daresLeftToday)
    }

    @Test fun twoDaysLaterEveryStreakHasBroken() {
        val s = snap().asOf("2026-11-23", "2026-11-23", "2026-11-22")
        assertEquals(listOf(0, 0), s.players.map { it.streak })
        assertEquals(listOf(0, 0), s.players.map { it.weekPoints })
        assertEquals("2026-11-23", s.weekStart)
    }

    @Test fun places() {
        val s = snap()
        assertEquals(1, s.place("2"))
        assertEquals(2, s.place("1"))
        assertNull(s.place("9"))
    }
}
