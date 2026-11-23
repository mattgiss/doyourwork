package com.doyourwork.app.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.doyourwork.app.widget.WidgetSnapshot
import java.time.LocalDate
import java.time.format.DateTimeFormatter

/**
 * The right-hand pane on a wide screen (a tablet, a foldable's inner screen) before anyone's
 * picked: where everyone's at today, instead of an empty half of the screen. One band per player,
 * in this week's order and the scoreboard's colours; tapping a band opens that player's day.
 *
 * The numbers come from the same snapshot the widgets show, so the two never disagree. As on iOS
 * (`TodayOverview.swift`).
 */
@Composable
fun TodayOverview(snapshot: WidgetSnapshot, onPick: (String) -> Unit) {
    val fb = LocalFeedback.current
    val heat = Palette.HEAT
    val ink = heat.ink
    val bands = snapshot.players.size + 1
    Column(Modifier.fillMaxSize().background(Bg).verticalScroll(rememberScrollState()).padding(bottom = 24.dp)) {
        Column(Modifier.fillMaxWidth().background(heat.band(0, bands)).statusBarsPadding().padding(start = 20.dp, end = 20.dp, top = 16.dp, bottom = 14.dp),
            verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text("Today", color = ink, fontWeight = FontWeight.Black, style = MaterialTheme.typography.headlineLarge.copy(fontSize = 28.sp))
            Text(LocalDate.now().format(DateTimeFormatter.ofPattern("EEEE, MMMM d")), color = ink.copy(alpha = 0.85f), fontWeight = FontWeight.SemiBold)
        }
        if (snapshot.players.isEmpty()) Text("> add players in the admin area", color = Done, modifier = Modifier.padding(20.dp))
        snapshot.players.forEachIndexed { i, p ->
            val progress = if (p.minutesPlanned > 0) p.minutesDone.toFloat() / p.minutesPlanned else 0f
            Column(
                Modifier.fillMaxWidth().background(heat.band(i + 1, bands))
                    .clickable(onClickLabel = "Open ${p.name}'s card") { fb.tap(); onPick(p.id) }
                    .padding(horizontal = 20.dp, vertical = 14.dp),
                verticalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(p.name, color = ink, fontWeight = FontWeight.Black, style = MaterialTheme.typography.titleMedium, maxLines = 1,
                        overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f))
                    Text(todayMinutes(p), color = ink, fontWeight = FontWeight.Bold, style = MaterialTheme.typography.titleSmall)
                }
                Text(todayStatus(p), color = ink.copy(alpha = 0.85f), fontWeight = FontWeight.SemiBold, maxLines = 2)
                // How far through today's card: empty before one's picked.
                Box(Modifier.fillMaxWidth().height(6.dp).background(ink.copy(alpha = 0.25f))) {
                    Box(Modifier.fillMaxWidth(progress.coerceIn(0f, 1f)).fillMaxHeight().background(ink))
                }
            }
        }
        Text("Pick someone to see their card.", color = Done, style = MaterialTheme.typography.bodySmall,
            modifier = Modifier.padding(start = 20.dp, end = 20.dp, top = 14.dp))
    }
}

fun todayMinutes(p: WidgetSnapshot.Player): String =
    if (p.minutesPlanned > 0) "${p.minutesDone}/${p.minutesPlanned} min" else "–"

/** Where a player's day stands, in a few words. */
fun todayStatus(p: WidgetSnapshot.Player): String = when (p.card) {
    "playing" -> p.next?.let { "Playing · next: $it" } ?: "Playing"
    "sent" -> "Waiting on an admin"
    "approved" -> "All approved. Nice work!"
    else -> "No card picked yet"
}
