package com.doyourwork.app

import com.doyourwork.app.engine.SnakeGame
import com.doyourwork.app.engine.SnakeGame.Direction.DOWN
import com.doyourwork.app.engine.SnakeGame.Direction.LEFT
import com.doyourwork.app.engine.SnakeGame.Direction.RIGHT
import com.doyourwork.app.engine.SnakeGame.Direction.UP
import com.doyourwork.app.engine.SnakeGame.Event
import com.doyourwork.app.engine.SnakeGame.Point as P
import com.doyourwork.app.engine.SnakeGame.Status
import com.doyourwork.app.engine.SnakeRandom
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The snake game's rules. The iOS `SnakeTests` (DoYourWorkCore) checks the same cases and the same
 * random numbers, so the two games play alike.
 */
class SnakeGameTest {
    @Test fun randomNumbersMatchIos() {
        val r = SnakeRandom(42)
        assertEquals(listOf(334, 26, 538, 503, 294, 156), List(6) { r.nextBelow(1000) })
        assertEquals(P(8, 11), SnakeGame.new(7).food)
    }

    @Test fun startsInTheMiddleWaitingForASwipe() {
        val g = SnakeGame.new(1)
        assertEquals(Status.READY, g.status)
        assertEquals(listOf(P(7, 7), P(6, 7), P(5, 7)), g.body)
        assertEquals(RIGHT, g.direction)
        assertNotNull(g.food)
        assertFalse("the first dot isn't under the line", g.food in g.body)
        assertNull("nothing moves before the first swipe", g.step())
        assertEquals(P(7, 7), g.head)
        assertEquals(160L, g.stepMillis)
    }

    @Test fun firstSwipeStartsAndTurns() {
        val g = SnakeGame.new(1)
        assertTrue(g.turn(UP))
        assertEquals(Status.PLAYING, g.status)
        g.step()
        assertEquals(listOf(P(7, 6), P(7, 7), P(6, 7)), g.body)
    }

    @Test fun swipingBackwardsStillStartsButDoesntTurn() {
        val g = SnakeGame.new(1)
        assertFalse(g.turn(LEFT))
        assertEquals(Status.PLAYING, g.status)
        g.step()
        assertEquals(P(8, 7), g.head)
    }

    @Test fun reversingAndRepeatingAreIgnored() {
        val g = SnakeGame.playing(10, 10, listOf(P(5, 5), P(4, 5), P(3, 5)), RIGHT, null)
        assertFalse("can't turn back on itself", g.turn(LEFT))
        assertFalse("already going that way", g.turn(RIGHT))
        assertTrue(g.turn(DOWN))
        assertFalse("reverse of the queued turn", g.turn(UP))
        assertTrue("a quick U-turn: down, then left", g.turn(LEFT))
        assertFalse("only two turns wait at once", g.turn(DOWN))
        g.step(); g.step()
        assertEquals(listOf(P(4, 6), P(5, 6), P(5, 5)), g.body)
    }

    @Test fun eatingGrowsScoresAndSpeedsUp() {
        val g = SnakeGame.playing(10, 10, listOf(P(5, 5), P(4, 5), P(3, 5)), RIGHT, P(6, 5))
        assertEquals(Event.ATE, g.step())
        assertEquals(1, g.score)
        assertEquals(listOf(P(6, 5), P(5, 5), P(4, 5), P(3, 5)), g.body)
        assertNotNull(g.food)
        assertFalse(g.food in g.body)
        assertEquals(156L, g.stepMillis)
        assertEquals(Event.MOVED, g.step())
        assertEquals(4, g.length)
    }

    @Test fun speedHasAFloor() {
        val body = listOf(P(5, 5), P(4, 5), P(3, 5))
        assertEquals(120L, SnakeGame.playing(10, 10, body, RIGHT, null, score = 10).stepMillis)
        assertEquals(70L, SnakeGame.playing(10, 10, body, RIGHT, null, score = 23).stepMillis)
        assertEquals(70L, SnakeGame.playing(10, 10, body, RIGHT, null, score = 80).stepMillis)
    }

    @Test fun hittingAWallEndsIt() {
        val g = SnakeGame.playing(5, 3, listOf(P(4, 1), P(3, 1), P(2, 1)), RIGHT, null)
        assertEquals(Event.DIED, g.step())
        assertEquals(Status.OVER, g.status)
        assertNull(g.step())
        assertFalse("no steering once it's over", g.turn(UP))
    }

    @Test fun bitingYourselfEndsIt() {
        // A hook: head at (2,2) going up runs into its own body at (2,1).
        val g = SnakeGame.playing(6, 6, listOf(P(2, 2), P(3, 2), P(3, 1), P(2, 1), P(1, 1)), LEFT, null)
        g.turn(UP)
        assertEquals(Event.DIED, g.step())
        assertEquals(Status.OVER, g.status)
    }

    @Test fun chasingYourTailIsFine() {
        // A ring of four: the head moves into the cell the tail is leaving.
        val g = SnakeGame.playing(4, 4, listOf(P(1, 1), P(1, 2), P(2, 2), P(2, 1)), UP, P(3, 3))
        g.turn(RIGHT)
        assertEquals(Event.MOVED, g.step())
        assertEquals(P(2, 1), g.head)
        assertEquals(Status.PLAYING, g.status)
    }

    @Test fun fillingTheBoardWins() {
        // 5 by 3 with one free cell, (4,2), and the dot on it.
        val body = listOf(P(3, 2), P(2, 2), P(1, 2), P(0, 2), P(0, 1), P(1, 1), P(2, 1), P(3, 1), P(4, 1),
            P(4, 0), P(3, 0), P(2, 0), P(1, 0), P(0, 0))
        val g = SnakeGame.playing(5, 3, body, RIGHT, P(4, 2))
        assertEquals(Event.WON, g.step())
        assertEquals(Status.WON, g.status)
        assertNull(g.food)
        assertEquals(15, g.length)
        assertEquals(1, g.score)
    }
}
