package com.doyourwork.app.ui

import android.os.SystemClock
import android.provider.Settings
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.focusable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.onKeyEvent
import androidx.compose.ui.input.key.type
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.repeatOnLifecycle
import com.doyourwork.app.AppViewModel
import com.doyourwork.app.engine.SnakeGame
import com.doyourwork.app.engine.SnakeGame.Direction
import com.doyourwork.app.model.Player
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.math.abs
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.random.Random

/**
 * The second reward game, "EAT THE DOTS": a snake-style game. Swipe anywhere to steer the line,
 * eat the dots to grow, and don't hit a wall or your own tail. It gets faster as it grows. It
 * shares the puzzle's 30 minutes a day, and each player's best score is kept on this phone.
 */
@Composable
fun SnakeScreen(vm: AppViewModel, player: Player, onBack: () -> Unit) {
    val fb = LocalFeedback.current
    val scope = rememberCoroutineScope()
    val ctx = LocalContext.current
    // "Remove animations" in the system settings turns off the shake, the pulse and the big flash.
    val calm = remember {
        Settings.Global.getFloat(ctx.contentResolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f) == 0f
    }
    val bg = MaterialTheme.colorScheme.background
    val dotColor = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.6f)

    var game by remember(player.id) { mutableStateOf(SnakeGame.new(Random.nextLong())) }
    // The game is a mutable object: bumping this redraws the screen after it changes.
    var frame by remember { mutableIntStateOf(0) }
    /** Set when the app goes to the background mid-game; the next swipe carries on. */
    var paused by remember { mutableStateOf(false) }
    var best by remember(player.id) { mutableIntStateOf(vm.snakeBest(player.id)) }
    var newBest by remember { mutableStateOf(false) }
    var showOver by remember { mutableStateOf(false) }
    val flash = remember { Animatable(0f) }
    val shakeX = remember { Animatable(0f) }

    // The shared hour a day, counted the same way as the puzzle's.
    var msLeft by remember(player.id) { mutableLongStateOf(vm.puzzleMsLeft(player.id)) }
    val lifecycle = LocalLifecycleOwner.current.lifecycle
    LaunchedEffect(player.id) {
        lifecycle.repeatOnLifecycle(Lifecycle.State.RESUMED) {
            var last = SystemClock.elapsedRealtime()
            while (msLeft > 0) {
                delay(1_000)
                val t = SystemClock.elapsedRealtime()
                vm.addPuzzleTime(player.id, t - last)
                last = t
                msLeft = vm.puzzleMsLeft(player.id)
            }
        }
    }

    fun finish(event: SnakeGame.Event) {
        if (event == SnakeGame.Event.WON) fb.levelUp() else fb.reject()
        newBest = vm.snakeFinished(player.id, game.score)
        best = vm.snakeBest(player.id)
        scope.launch { flash.snapTo(if (calm) 0.3f else 0.7f); flash.animateTo(0f, tween(450)) }
        if (!calm) scope.launch {
            for (s in listOf(1f, -0.8f, 0.55f, -0.3f, 0f)) shakeX.animateTo(s * 24f, tween(35, easing = LinearEasing))
        }
        scope.launch {
            delay(450)
            if (newBest) fb.unlock()
            showOver = true
        }
    }

    // The game clock: one step every `stepMillis`, only while the app is in front.
    LaunchedEffect(game) {
        lifecycle.repeatOnLifecycle(Lifecycle.State.RESUMED) {
            try {
                while (true) {
                    delay(game.stepMillis)
                    if (paused || showOver || msLeft <= 0) continue
                    when (val e = game.step()) {
                        null, SnakeGame.Event.MOVED -> {}
                        SnakeGame.Event.ATE -> fb.puzzleSelect()
                        SnakeGame.Event.DIED, SnakeGame.Event.WON -> finish(e)
                    }
                    frame++
                }
            } finally {
                if (game.status == SnakeGame.Status.PLAYING) paused = true
            }
        }
    }

    fun steer(d: Direction) {
        if (showOver || msLeft <= 0) return
        paused = false
        if (game.turn(d)) fb.tap()
        frame++
    }

    /** A tap starts a game that's waiting, or carries on after a pause. */
    fun carryOn() {
        if (showOver || msLeft <= 0) return
        paused = false
        game.start()
        frame++
    }

    fun playAgain() {
        fb.tap()
        game = SnakeGame.new(Random.nextLong())
        paused = false; newBest = false; showOver = false
    }

    // The gesture detectors outlive compositions; these always reach the current game.
    val onSteer by rememberUpdatedState<(Direction) -> Unit> { steer(it) }
    val onTap by rememberUpdatedState<() -> Unit> { carryOn() }
    val swipePx = with(LocalDensity.current) { 22.dp.toPx() }
    val focus = remember { FocusRequester() }
    LaunchedEffect(Unit) { runCatching { focus.requestFocus() } }

    val pulse by rememberInfiniteTransition(label = "dot").animateFloat(
        0f, 1f, infiniteRepeatable(tween(520), RepeatMode.Reverse), label = "pulse",
    )

    Box(
        Modifier.fillMaxSize().background(bg)
            // A hardware keyboard steers with the arrow keys.
            .focusRequester(focus).focusable()
            .onKeyEvent { e ->
                if (e.type != KeyEventType.KeyDown) return@onKeyEvent false
                val d = when (e.key) {
                    Key.DirectionUp -> Direction.UP
                    Key.DirectionDown -> Direction.DOWN
                    Key.DirectionLeft -> Direction.LEFT
                    Key.DirectionRight -> Direction.RIGHT
                    else -> return@onKeyEvent false
                }
                onSteer(d); true
            },
    ) {
        Column(
            Modifier.fillMaxSize()
                .offset { IntOffset(shakeX.value.roundToInt(), (-shakeX.value * 0.6f).roundToInt()) }
                // Swipe anywhere on the screen, not just the board: easier on a tablet or an open fold.
                .pointerInput(swipePx) {
                    var acc = Offset.Zero
                    detectDragGestures(onDragStart = { acc = Offset.Zero }) { change, drag ->
                        change.consume()
                        acc += drag
                        if (maxOf(abs(acc.x), abs(acc.y)) >= swipePx) {
                            onSteer(if (abs(acc.x) > abs(acc.y)) (if (acc.x > 0) Direction.RIGHT else Direction.LEFT)
                                    else (if (acc.y > 0) Direction.DOWN else Direction.UP))
                            acc = Offset.Zero
                        }
                    }
                }
                .pointerInput(Unit) { detectTapGestures { onTap() } },
        ) {
            frame   // read, so a step redraws
            Row(Modifier.fillMaxWidth().padding(horizontal = 12.dp), verticalAlignment = Alignment.CenterVertically) {
                TextButton(onClick = { fb.tap(); onBack() }) { Text("Back") }
                FitText("Eat the dots · best ${maxOf(best, game.score)}", style = MaterialTheme.typography.labelMedium, letterSpacing = 3.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant, minScale = 0.5f, modifier = Modifier.weight(1f).padding(horizontal = 4.dp))
                Text("Score ${game.score}", color = Accent, fontWeight = FontWeight.Bold, style = MaterialTheme.typography.titleMedium,
                    modifier = Modifier.padding(end = 12.dp))
            }
            Text(
                when {
                    paused -> "Paused. Swipe to keep going."
                    game.status == SnakeGame.Status.READY -> "Swipe to steer. Eat the dots; don't hit the walls or your tail."
                    else -> "Swipe to steer."
                },
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                style = MaterialTheme.typography.bodySmall,
                modifier = Modifier.padding(horizontal = 24.dp, vertical = 4.dp),
            )
            BoxWithConstraints(Modifier.weight(1f).fillMaxWidth().padding(20.dp), contentAlignment = Alignment.Center) {
                val cell = min(maxWidth.value / game.width, maxHeight.value / game.height)
                Canvas(
                    Modifier.size((cell * game.width).dp, (cell * game.height).dp)
                        .background(MaterialTheme.colorScheme.onSurface.copy(alpha = 0.04f))
                        .border(1.dp, MaterialTheme.colorScheme.outlineVariant)
                        .semantics { contentDescription = "Eat the dots board, length ${game.length}" },
                ) {
                    frame
                    drawSnake(game, size.width / game.width, if (calm) 0f else pulse, dotColor, bg)
                }
            }
            Spacer(Modifier.height(12.dp))
        }

        if (flash.value > 0f) Box(Modifier.fillMaxSize().background(Accent.copy(alpha = flash.value)))
        if (showOver) {
            Column(
                Modifier.fillMaxSize().background(bg.copy(alpha = 0.88f)).pointerInput(Unit) { detectTapGestures { } }.padding(32.dp),
                verticalArrangement = Arrangement.Center,
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Text(if (game.status == SnakeGame.Status.WON) "You filled the board!" else "Game over",
                    style = MaterialTheme.typography.displaySmall, fontWeight = FontWeight.Black, textAlign = TextAlign.Center)
                Text("${game.score}", fontSize = 64.sp, fontWeight = FontWeight.Black, color = Accent,
                    modifier = Modifier.padding(top = 12.dp).semantics { contentDescription = "Score ${game.score}" })
                Text(if (newBest) "New best!" else "Best $best",
                    color = if (newBest) Accent else MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(top = 8.dp))
                Spacer(Modifier.height(28.dp))
                TermButton("Play again", onClick = ::playAgain)
                QuietButton("Back to my chores", modifier = Modifier.padding(top = 8.dp)) { fb.tap(); onBack() }
            }
        }
        // Out of time for today. A game-over card already up stays until it's dismissed.
        if (msLeft <= 0L && !showOver) {
            Column(
                Modifier.fillMaxSize().background(bg.copy(alpha = 0.96f)).pointerInput(Unit) { detectTapGestures { } }.padding(24.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp, Alignment.CenterVertically),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Text("Time's up", color = Accent, fontWeight = FontWeight.Black, style = MaterialTheme.typography.headlineMedium, letterSpacing = 3.sp)
                Text("That's your 30 minutes of games for today. See you tomorrow!", color = MaterialTheme.colorScheme.onSurfaceVariant,
                    textAlign = TextAlign.Center)
                TextButton(onClick = { fb.tap(); onBack() }) { Text("Back") }
            }
        }
    }
}

private fun DrawScope.drawSnake(game: SnakeGame, cell: Float, pulse: Float, dot: Color, bg: Color) {
    // A faint dot in each empty cell, like the puzzle's board.
    for (y in 0 until game.height) for (x in 0 until game.width) {
        drawCircle(dot, cell * 0.04f, Offset((x + 0.5f) * cell, (y + 0.5f) * cell))
    }
    game.food?.let { f ->
        // The dot breathes, so it's easy to spot.
        val side = cell * (0.62f + 0.12f * pulse)
        val c = Offset((f.x + 0.5f) * cell, (f.y + 0.5f) * cell)
        // Round, so it never reads as part of the line, even in a theme where both are the same colour.
        drawCircle(BlockA.copy(alpha = 0.25f), side / 2 + cell * 0.1f, c)
        drawCircle(BlockA, side / 2, c)
    }
    val pad = cell * 0.08f
    val n = game.body.size
    for (i in n - 1 downTo 0) {
        val p = game.body[i]
        val topLeft = Offset(p.x * cell + pad, p.y * cell + pad)
        val s = Size(cell - 2 * pad, cell - 2 * pad)
        val color = if (i == 0) Accent else BlockB.copy(alpha = 1f - 0.45f * i / maxOf(n - 1, 1))
        drawRoundRect(color, topLeft, s, CornerRadius(cell * 0.2f))
        // A highlight so each piece reads as a solid tile, the same as the puzzle's blocks.
        drawRoundRect(Color.White.copy(alpha = 0.18f), topLeft + Offset(s.width * 0.12f, s.height * 0.1f),
            Size(s.width * 0.76f, s.height * 0.14f), CornerRadius(cell * 0.06f))
    }
    // Two eyes on the head, looking the way it's going.
    val h = game.head
    val d = game.direction
    val c = Offset((h.x + 0.5f) * cell, (h.y + 0.5f) * cell)
    val ahead = Offset(d.dx * cell * 0.16f, d.dy * cell * 0.16f)
    val side = Offset(-d.dy * cell * 0.18f, d.dx * cell * 0.18f)
    for (s in listOf(-1f, 1f)) drawCircle(bg, cell * 0.07f, c + ahead + side * s)
}
