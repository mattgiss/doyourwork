package com.doyourwork.app.engine

/**
 * The second game a submitted card unlocks: steer a line round the board, eat the dots to grow,
 * and don't run into a wall or your own tail. It shares the puzzle's hour a day.
 *
 * Plain Kotlin with no UI, so it can be tested; the iOS `SnakeGame` (DoYourWorkCore) follows the
 * same rules and the same random numbers, and both are tested against the same sequences.
 */
class SnakeGame private constructor(
    val width: Int,
    val height: Int,
    body: List<Point>,
    direction: Direction,
    food: Point?,
    score: Int,
    status: Status,
    private val random: SnakeRandom,
) {
    data class Point(val x: Int, val y: Int)

    enum class Direction(val dx: Int, val dy: Int) {
        UP(0, -1), DOWN(0, 1), LEFT(-1, 0), RIGHT(1, 0);
        val opposite: Direction get() = when (this) { UP -> DOWN; DOWN -> UP; LEFT -> RIGHT; RIGHT -> LEFT }
    }

    enum class Status { READY, PLAYING, OVER, WON }

    /** What a step did. */
    enum class Event { MOVED, ATE, DIED, WON }

    /** The line, head first. */
    var body: List<Point> = body; private set
    /** The way the head moved last (or will move first). */
    var direction: Direction = direction; private set
    private val turns = ArrayDeque<Direction>()
    val queuedTurns: List<Direction> get() = turns.toList()
    /** Null only once the line fills the board. */
    var food: Point? = food; private set
    var score: Int = score; private set
    var status: Status = status; private set

    val head: Point get() = body[0]
    val length: Int get() = body.size
    val isFinished: Boolean get() = status == Status.OVER || status == Status.WON

    /** How long each step takes: it speeds up as the line grows, down to a floor. */
    val stepMillis: Long get() = maxOf(70, 160 - score * 4).toLong()

    /**
     * Steer. A ready game starts on the first swipe. A turn back on itself, or the way it's already
     * going, is ignored. Returns whether the turn was queued.
     */
    fun turn(d: Direction): Boolean {
        if (isFinished) return false
        if (status == Status.READY) status = Status.PLAYING
        val heading = turns.lastOrNull() ?: direction
        if (d == heading || d == heading.opposite || turns.size >= MAX_QUEUED_TURNS) return false
        turns.addLast(d)
        return true
    }

    /** Starts a ready game going the way it faces. */
    fun start() { if (status == Status.READY) status = Status.PLAYING }

    /** One tick: take the next queued turn and move the head a cell. Null when the game isn't running. */
    fun step(): Event? {
        if (status != Status.PLAYING) return null
        turns.removeFirstOrNull()?.let { direction = it }
        val next = Point(head.x + direction.dx, head.y + direction.dy)
        if (next.x !in 0 until width || next.y !in 0 until height) { status = Status.OVER; return Event.DIED }
        val eats = next == food
        // The tail moves out of the way this step, unless the line is growing.
        if (next in (if (eats) body else body.dropLast(1))) { status = Status.OVER; return Event.DIED }
        if (!eats) { body = listOf(next) + body.dropLast(1); return Event.MOVED }
        body = listOf(next) + body
        score += 1
        food = placeFood()
        if (food == null) { status = Status.WON; return Event.WON }
        return Event.ATE
    }

    /** A free cell, picked at random from the free cells in row order. */
    private fun placeFood(): Point? {
        val taken = body.toHashSet()
        val free = ArrayList<Point>()
        for (y in 0 until height) for (x in 0 until width) Point(x, y).let { if (it !in taken) free += it }
        return if (free.isEmpty()) null else free[random.nextBelow(free.size)]
    }

    companion object {
        /** The board is square so it fits phones, tablets and foldables alike. */
        const val DEFAULT_SIZE = 15
        /** Turns waiting to be used: two, so a quick swipe-swipe (a U-turn) isn't lost between steps. */
        const val MAX_QUEUED_TURNS = 2

        /** A line three long in the middle, heading right, and the first dot. */
        fun new(seed: Long, width: Int = DEFAULT_SIZE, height: Int = DEFAULT_SIZE): SnakeGame {
            require(width >= 5 && height >= 3) { "snake board too small" }
            val x = width / 2; val y = height / 2
            val g = SnakeGame(width, height, listOf(Point(x, y), Point(x - 1, y), Point(x - 2, y)), Direction.RIGHT,
                null, 0, Status.READY, SnakeRandom(seed))
            g.food = g.placeFood()
            return g
        }

        /** A game set up mid-play, for tests. The line runs from `body[0]`, the head. */
        internal fun playing(width: Int, height: Int, body: List<Point>, direction: Direction, food: Point?, score: Int = 0, seed: Long = 1) =
            SnakeGame(width, height, body, direction, food, score, Status.PLAYING, SnakeRandom(seed))
    }
}

/** A small repeatable random number generator (a 64-bit LCG), so a seed gives the same dots on Android and iOS. */
class SnakeRandom(seed: Long) {
    private var state = seed

    /** 0 until n. */
    fun nextBelow(n: Int): Int {
        state = state * 6364136223846793005L + 1442695040888963407L
        return ((state ushr 33) % n).toInt()
    }
}
