package com.doyourwork.app

import androidx.compose.ui.unit.dp
import com.doyourwork.app.model.ChoreLog
import com.doyourwork.app.model.Status
import com.doyourwork.app.model.Player
import com.doyourwork.app.ui.FEED_MAX
import com.doyourwork.app.ui.canDare
import com.doyourwork.app.ui.daresFromProfile
import com.doyourwork.app.ui.editsLookFromProfile
import com.doyourwork.app.ui.pagesFor
import com.doyourwork.app.ui.feedDay
import com.doyourwork.app.ui.feedLogs
import com.doyourwork.app.ui.feedStatus
import com.doyourwork.app.ui.listPaneWidth
import com.doyourwork.app.ui.tilesAcross
import java.time.LocalDate
import java.time.ZoneId
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** How the screen is split between the list and what's open beside it. */
class LayoutTest {
    // The Z Fold 7's inner screen is about 750dp by 832dp.

    @Test fun foldTurnedSidewaysGivesTheListAProperShare() {
        // The hinge runs across, so there's nothing to split at. This used to come out at 246dp
        // (0.42 against 1, not 0.42 of the width), which broke the title over two lines.
        val list = listPaneWidth(832.dp, hingeLeft = null)
        assertEquals(349.44f, list.value, 0.01f)
        assertTrue("the list needs room for a full-size title", list >= 300.dp)
        assertTrue("and so does what opens beside it", 832.dp - list >= 300.dp)
    }

    @Test fun foldHeldUprightSplitsAtTheHinge() {
        assertEquals(375.dp, listPaneWidth(750.dp, hingeLeft = 375.dp))
    }

    @Test fun aHingeTooNearAnEdgeIsIgnored() {
        // A dual-screen or oddly reported hinge mustn't leave either pane a sliver.
        assertEquals(listPaneWidth(832.dp, null), listPaneWidth(832.dp, hingeLeft = 120.dp))
        assertEquals(listPaneWidth(832.dp, null), listPaneWidth(832.dp, hingeLeft = 700.dp))
    }

    @Test fun theListNeverGetsTooNarrowOrTooWide() {
        assertEquals(300.dp, listPaneWidth(600.dp, null))    // the narrowest window that shows two panes
        assertEquals(420.dp, listPaneWidth(1280.dp, null))   // a tablet: the open screen gets the rest
        assertEquals(420.dp, listPaneWidth(2000.dp, null))
    }

    @Test fun familyTilesAreThreeAcrossOnAPhoneAndMoreWhereThereIsRoom() {
        assertEquals(3, tilesAcross(336.dp))   // a phone, inside its gutters
        assertEquals(3, tilesAcross(200.dp))   // never fewer than three
        assertEquals(4, tilesAcross(480.dp))   // one per 120dp
        assertEquals(6, tilesAcross(2000.dp))  // and no more than six
    }

    @Test fun theFeedIsTheLastSevenDaysNewestFirstAndAtMostAHundred() {
        val zone = ZoneId.of("UTC")
        val today = LocalDate.of(2026, 11, 27)
        val day = 86_400_000L
        val noon = today.atTime(12, 0).atZone(zone).toInstant().toEpochMilli()
        fun log(i: Int, at: Long) = ChoreLog("$i", null, "1", "kid", "c$i", "chore $i", 1, null, Status.APPROVED, at)
        val logs = listOf(log(1, noon - 6 * day), log(2, noon - 7 * day), log(3, noon), log(4, noon - day))
        assertEquals(listOf("3", "4", "1"), feedLogs(logs, today, zone).map { it.id })
        assertEquals(FEED_MAX, feedLogs(List(150) { log(it, noon - it * 1000L) }, today, zone).size)
        assertEquals("Today", feedDay(today, today))
        assertEquals("Yesterday", feedDay(today.minusDays(1), today))
        assertEquals("turned down", feedStatus(Status.REJECTED))
        assertEquals("waiting", feedStatus(Status.PENDING))
    }

    @Test fun threePagesOnAPhoneAndTwoBesideTheFamily() {
        assertEquals(listOf("family", "feed", "settings"), pagesFor(twoPane = false))
        assertEquals(listOf("feed", "settings"), pagesFor(twoPane = true))
    }

    @Test fun daringNeedsALinkedPhoneThatKnowsWhoseItIs() {
        val family = listOf(Player("1", "mom"), Player("2", "kid"))
        assertTrue(canDare(linked = true, me = "1", players = family))
        assertFalse("an unlinked phone has no dares", canDare(linked = false, me = "1", players = family))
        assertFalse("nor one that doesn't know whose it is", canDare(linked = true, me = null, players = family))
        assertFalse("or whose owner isn't playing", canDare(linked = true, me = "9", players = family))
        assertTrue(daresFromProfile(true, "1", family, profileId = "2"))
        assertFalse("not yourself", daresFromProfile(true, "1", family, profileId = "1"))
    }

    @Test fun photoAndBorderFromYourOwnProfileOrAnyoneOnASharedPhone() {
        assertTrue(editsLookFromProfile(linked = true, me = "1", profileId = "1"))
        assertFalse("someone else's, on your phone", editsLookFromProfile(linked = true, me = "1", profileId = "2"))
        assertTrue("a phone that isn't someone's", editsLookFromProfile(linked = true, me = null, profileId = "2"))
        assertTrue("a family on one phone", editsLookFromProfile(linked = false, me = "1", profileId = "2"))
    }
}
