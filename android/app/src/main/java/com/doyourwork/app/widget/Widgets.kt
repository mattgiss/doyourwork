package com.doyourwork.app.widget

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.datastore.preferences.core.longPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.glance.ColorFilter
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.LocalContext
import androidx.glance.LocalSize
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.LinearProgressIndicator
import androidx.glance.appwidget.SizeMode
import androidx.glance.action.actionStartActivity
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.appwidget.state.updateAppWidgetState
import androidx.glance.background
import androidx.glance.currentState
import androidx.glance.layout.Alignment
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.size
import androidx.glance.layout.width
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import com.doyourwork.app.MainActivity
import com.doyourwork.app.R
import com.doyourwork.app.engine.Engine
import java.time.LocalDate
import kotlin.math.min

// The widgets' own state: when the app last wrote a snapshot (so a running widget redraws), and
// for the one-player widgets, whose card it shows.
internal val STAMP = longPreferencesKey("stamp")
internal val PLAYER = stringPreferencesKey("player")

/** Redraws every DOYOURWORK widget on the home screen. Called after the app writes a new snapshot. */
suspend fun refreshWidgets(ctx: Context) {
    val manager = GlanceAppWidgetManager(ctx)
    val now = System.currentTimeMillis()
    for (widget in listOf(TodayWidget(), ScoreboardWidget(), DaresWidget())) {
        for (id in manager.getGlanceIds(widget.javaClass)) {
            updateAppWidgetState(ctx, id) { it[STAMP] = now }
            widget.update(ctx, id)
        }
    }
}

/** The snapshot as it reads today (see [WidgetSnapshot.asOf]), or null before the app has been set up. */
@Composable
private fun snapshot(): WidgetSnapshot? {
    currentState(STAMP) // read, so a new snapshot redraws a widget that's already running
    val today = LocalDate.now()
    return WidgetWriter.read(LocalContext.current)?.asOf(today.toString(), Engine.weekStart(today).toString(), today.minusDays(1).toString())
}

/** The player a one-player widget is set to, else this phone's player, else the first on the scoreboard. */
@Composable
private fun chosenPlayer(s: WidgetSnapshot): WidgetSnapshot.Player? = s.player(currentState(PLAYER)) ?: s.player(s.me) ?: s.players.firstOrNull()

private fun c(v: Long) = ColorProvider(Color(0xFF000000 or v))
private val GOOD = 0x6BC276L
private val openApp get() = actionStartActivity<MainActivity>()

@Composable
private fun SetUpFirst() {
    Column(GlanceModifier.fillMaxSize().background(c(0x000000)).padding(12.dp).clickable(openApp)) {
        Text("DOYOURWORK", style = TextStyle(color = c(0xE8572A), fontSize = 13.sp, fontWeight = FontWeight.Bold))
        Spacer(GlanceModifier.defaultWeight())
        Text("Open the app to set up your family", style = TextStyle(color = c(0xFFFFFF), fontSize = 14.sp, fontWeight = FontWeight.Medium))
    }
}

@Composable
private fun Icon(res: Int, tint: Long, size: Int) {
    Image(ImageProvider(res), contentDescription = null, modifier = GlanceModifier.size(size.dp), colorFilter = ColorFilter.tint(c(tint)))
}

private fun cardLine(p: WidgetSnapshot.Player) = when (p.card) {
    "pick" -> "Pick today's card"
    "sent" -> "Sent, waiting on a parent"
    "approved" -> "Approved"
    else -> p.next?.let { "Next: $it" } ?: "All done, send it in"
}

// ─── Today's card ───────────────────────────────────────────────────────────

/** One player's card today: minutes ticked off out of 25, their streak and what's next. */
class TodayWidget : GlanceAppWidget() {
    override val sizeMode = SizeMode.Single
    override suspend fun provideGlance(context: Context, id: GlanceId) = provideContent { Today() }
}

@Composable
private fun Today() {
    val s = snapshot()
    val p = s?.let { chosenPlayer(it) }
    if (s == null || p == null) return SetUpFirst()
    val k = s.colors
    val goal = Engine.DAILY_MINUTES
    val fraction = min(1f, p.minutesDone.toFloat() / goal)
    Column(GlanceModifier.fillMaxSize().background(c(k.bg)).padding(14.dp).clickable(openApp)) {
        Row(GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Text(p.name, maxLines = 1, style = TextStyle(color = c(k.text), fontSize = 15.sp, fontWeight = FontWeight.Bold),
                modifier = GlanceModifier.defaultWeight())
            if (p.streak > 0) {
                Icon(R.drawable.ic_widget_flame, k.heat.last(), 14)
                Text(" ${p.streak}", style = TextStyle(color = c(k.heat.last()), fontSize = 13.sp, fontWeight = FontWeight.Bold))
            }
        }
        Spacer(GlanceModifier.defaultWeight())
        Row(verticalAlignment = Alignment.Bottom) {
            Text("${p.minutesDone}", style = TextStyle(color = c(k.text), fontSize = 36.sp, fontWeight = FontWeight.Bold))
            Text("/$goal", style = TextStyle(color = c(k.muted), fontSize = 16.sp, fontWeight = FontWeight.Bold), modifier = GlanceModifier.padding(bottom = 5.dp))
        }
        Text("minutes today", style = TextStyle(color = c(k.muted), fontSize = 11.sp))
        Spacer(GlanceModifier.defaultWeight())
        LinearProgressIndicator(progress = fraction, modifier = GlanceModifier.fillMaxWidth().height(8.dp),
            color = c(if (p.card == "approved") GOOD else k.heat[min(5, (fraction * 5).toInt())]), backgroundColor = c(k.surface))
        Spacer(GlanceModifier.height(6.dp))
        Text(cardLine(p), maxLines = 1, style = TextStyle(color = c(k.text), fontSize = 12.sp, fontWeight = FontWeight.Medium))
    }
}

// ─── Scoreboard ─────────────────────────────────────────────────────────────

/** This week's points for everyone, in the scoreboard's bands. Taller widgets show more players. */
class ScoreboardWidget : GlanceAppWidget() {
    override val sizeMode = SizeMode.Exact
    override suspend fun provideGlance(context: Context, id: GlanceId) = provideContent { Scoreboard() }
}

@Composable
private fun Scoreboard() {
    val s = snapshot()
    if (s == null || s.players.isEmpty()) return SetUpFirst()
    val k = s.colors
    val tall = LocalSize.current.height > 200.dp
    val rows = if (tall) 8 else 4
    Column(GlanceModifier.fillMaxSize().background(c(k.bg)).padding(12.dp).clickable(openApp)) {
        Row(GlanceModifier.fillMaxWidth().padding(bottom = 6.dp)) {
            Text("This week", style = TextStyle(color = c(k.text), fontSize = 13.sp, fontWeight = FontWeight.Bold), modifier = GlanceModifier.defaultWeight())
            Text("DOYOURWORK", style = TextStyle(color = c(k.muted), fontSize = 11.sp, fontWeight = FontWeight.Bold))
        }
        s.players.take(rows).forEachIndexed { i, p ->
            val ink = c(k.heatInk)
            Row(GlanceModifier.fillMaxWidth().height(if (tall) 34.dp else 26.dp).background(c(k.heat[min(i, k.heat.size - 1)]))
                .cornerRadius(6.dp).padding(horizontal = 10.dp), verticalAlignment = Alignment.CenterVertically) {
                if (i == 0 && p.weekPoints > 0) { Icon(R.drawable.ic_widget_crown, k.heatInk, 13); Spacer(GlanceModifier.width(5.dp)) }
                Text(p.name, maxLines = 1, style = TextStyle(color = ink, fontSize = 14.sp, fontWeight = FontWeight.Bold), modifier = GlanceModifier.defaultWeight())
                if (tall) Text("${p.version}   ", style = TextStyle(color = ink, fontSize = 12.sp))
                Text("${p.weekPoints}", style = TextStyle(color = ink, fontSize = 15.sp, fontWeight = FontWeight.Bold))
            }
            Spacer(GlanceModifier.height(3.dp))
        }
        Spacer(GlanceModifier.defaultWeight())
        // Room to spare: today's minutes for each player.
        if (s.players.size < rows) {
            Text("Today: " + s.players.take(rows).joinToString(" · ") { "${it.name} ${it.minutesDone} min" }, maxLines = 1,
                style = TextStyle(color = c(k.muted), fontSize = 12.sp))
        }
    }
}

// ─── Dares ──────────────────────────────────────────────────────────────────

/** Yesterday's dares, revealed, or how many are left to make today. Today's stay secret. */
class DaresWidget : GlanceAppWidget() {
    override val sizeMode = SizeMode.Single
    override suspend fun provideGlance(context: Context, id: GlanceId) = provideContent { Dares() }
}

@Composable
private fun Dares() {
    val s = snapshot() ?: return SetUpFirst()
    val k = s.colors
    val me = chosenPlayer(s)?.id
    Column(GlanceModifier.fillMaxSize().background(c(k.bg)).padding(12.dp).clickable(openApp)) {
        Text(if (s.yesterdaysDares.isEmpty()) "Dares" else "Yesterday's dares", style = TextStyle(color = c(k.text), fontSize = 13.sp, fontWeight = FontWeight.Bold))
        Spacer(GlanceModifier.defaultWeight())
        when {
            !s.linked -> Text("Dares need two phones. Add one in the app.", style = TextStyle(color = c(k.plumInk), fontSize = 13.sp, fontWeight = FontWeight.Medium))
            s.yesterdaysDares.isEmpty() -> Column(GlanceModifier.fillMaxWidth().background(c(k.plum)).cornerRadius(10.dp).padding(10.dp)) {
                Text("${s.daresLeftToday} left today", style = TextStyle(color = c(k.text), fontSize = 17.sp, fontWeight = FontWeight.Bold))
                Text("Guess who'll do what", style = TextStyle(color = c(k.plumInk), fontSize = 12.sp))
            }
            else -> {
                val earned = me?.let { id -> s.yesterdaysDares.filter { it.landed }.sumOf {
                    (if (it.from == id) Engine.DARE_GUESSER_POINTS else 0) + (if (it.target == id) Engine.DARE_DOER_POINTS else 0) } } ?: 0
                if (earned > 0) Text("You earned $earned", style = TextStyle(color = c(k.text), fontSize = 15.sp, fontWeight = FontWeight.Bold))
                s.yesterdaysDares.take(if (earned > 0) 2 else 3).forEach { d ->
                    Text((if (d.landed) "✓ " else "✗ ") + "${d.fromName}: ${d.targetName}, ${d.chore}", maxLines = 2,
                        style = TextStyle(color = c(if (d.landed) k.plumInk else k.muted), fontSize = 11.sp))
                }
            }
        }
        Spacer(GlanceModifier.defaultWeight())
        Text("Revealed at midnight", style = TextStyle(color = c(k.muted), fontSize = 10.sp))
    }
}

class TodayWidgetReceiver : GlanceAppWidgetReceiver() { override val glanceAppWidget: GlanceAppWidget = TodayWidget() }
class ScoreboardWidgetReceiver : GlanceAppWidgetReceiver() { override val glanceAppWidget: GlanceAppWidget = ScoreboardWidget() }
class DaresWidgetReceiver : GlanceAppWidgetReceiver() { override val glanceAppWidget: GlanceAppWidget = DaresWidget() }
