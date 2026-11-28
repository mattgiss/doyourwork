package com.doyourwork.app

import com.doyourwork.app.engine.FamilyGrid
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** The family page's tiles: as big as the page allows. The same as iOS's FamilyGridTests. */
class FamilyGridTest {
    /** A phone's family page, below the heading and above the tab bar. */
    private val w = 370.0
    private val h = 600.0

    @Test fun onePersonFillsThePage() {
        val l = FamilyGrid.layout(1, w, h)
        assertEquals(1, l.columns)
        assertEquals(1, l.rows)
        assertEquals(w, l.tileWidth, 0.01)
        assertTrue("nearly the whole page", l.tileHeight > h * 0.8)
        assertTrue(l.tileHeight <= l.tileWidth * FamilyGrid.MAX_TALLNESS + 0.01)
        assertFalse(l.scrolls)
    }

    @Test fun tilesShrinkAsPeopleJoin() {
        var last = Double.POSITIVE_INFINITY
        for (n in 1..9) {
            val l = FamilyGrid.layout(n, w, h)
            assertTrue("$n people", l.avatar <= last + 0.01)
            assertTrue(l.columns * l.rows >= n)
            // Everything fits on the page without scrolling.
            assertTrue("$n people", l.rows * l.tileHeight + (l.rows - 1) * FamilyGrid.GAP <= h + 0.01)
            last = l.avatar
        }
    }

    @Test fun twoStackAndFourMakeASquare() {
        assertEquals(1, FamilyGrid.layout(2, w, h).columns)
        val four = FamilyGrid.layout(4, w, h)
        assertEquals(2, four.columns)
        assertEquals(2, four.rows)
    }

    @Test fun aBigFamilyScrolls() {
        val l = FamilyGrid.layout(30, w, h)
        assertTrue(l.scrolls)
        assertTrue(l.columns >= 3)
    }

    @Test fun aWideScreenUsesItsWidth() {
        val l = FamilyGrid.layout(3, 1000.0, 600.0)
        assertEquals(3, l.columns)
        assertEquals(1, l.rows)
    }
}
