package com.doyourwork.app.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import com.doyourwork.app.AppViewModel
import com.doyourwork.app.engine.Engine
import com.doyourwork.app.model.ChoreLog
import com.doyourwork.app.model.Dare
import com.doyourwork.app.model.Player
import com.doyourwork.app.model.Status
import com.doyourwork.app.sync.LocalEntry
import java.time.Instant
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.time.format.TextStyle
import java.util.Locale

/** The most the feed lists. */
const val FEED_MAX = 100
/** How many days back the feed goes, today included. */
const val FEED_DAYS = 7

/** What everyone's done over the last [FEED_DAYS] days, newest first, at most [FEED_MAX]. */
fun feedLogs(logs: List<ChoreLog>, today: LocalDate, zone: java.time.ZoneId): List<ChoreLog> {
    val from = today.minusDays((FEED_DAYS - 1).toLong())
    return logs.filter { !Engine.dayOf(it.timestamp, zone).isBefore(from) }.sortedByDescending { it.timestamp }.take(FEED_MAX)
}

/** "Today", "Yesterday", or the weekday's name. */
fun feedDay(day: LocalDate, today: LocalDate): String = when (day) {
    today -> "Today"
    today.minusDays(1) -> "Yesterday"
    else -> day.dayOfWeek.getDisplayName(TextStyle.FULL, Locale.getDefault())
}

/** A chore's status as the feed says it. */
fun feedStatus(status: String): String = when (status) {
    Status.APPROVED -> "approved"
    Status.REJECTED -> "turned down"
    else -> "waiting"
}

/**
 * The feed page: on a linked phone the dares first (making today's, and yesterday's revealed), then
 * what everyone has done this week, grouped by day.
 */
@Composable
fun FeedPage(
    vm: AppViewModel,
    players: List<Player>,
    logs: List<ChoreLog>,
    shared: Map<String, LocalEntry>,
    me: String?,
    onDares: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val fb = LocalFeedback.current
    val linked by vm.relayLinked.collectAsState()
    val family by vm.store.family.collectAsState()
    val zone = vm.zone
    val today = vm.today()
    val dares = vm.dares(shared)
    val names = family.members.associate { it.id to it.shownName }
    val byId = family.members.associateBy { it.id }
    val characters = vm.characters(players)
    Column(modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(Gap).padding(bottom = LocalPageBottom.current), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        if (linked && me != null && me in names) {
            val mineToday = dares.filter { it.from == me && it.day == today.toString() }
            CompositionLocalProvider(LocalPalette provides Palette.PLUM) {
                MainButton("Make a dare · ${Engine.MAX_DARES_PER_DAY - mineToday.size} left today") { fb.tap(); onDares() }
            }
        }
        // Yesterday's dares, revealed after midnight.
        val yesterday = today.minusDays(1).toString()
        val revealed = dares.filter { it.day == yesterday }
        if (linked && revealed.isNotEmpty()) RoundCard {
            Text("Yesterday's dares", color = Ink, fontWeight = FontWeight.Bold, style = MaterialTheme.typography.titleSmall)
            val myPoints = me?.let { id -> revealed.sumOf { Engine.darePoints(id, it, logs, zone) } } ?: 0
            if (myPoints > 0) {
                LaunchedEffect(yesterday) { if (vm.firstReveal(yesterday)) fb.dareLanded() }
                Text("You earned $myPoints points from dares.", color = Palette.PLUM.ink, fontWeight = FontWeight.Bold, modifier = Modifier.padding(top = 4.dp))
            }
            for (d in revealed) DareLine(d, names, vm.choreName(d.choreId), Engine.dareLanded(d, logs, zone))
        }

        val items = feedLogs(logs.filter { it.playerId in byId }, today, zone)
        if (items.isEmpty()) {
            Text("Nothing done yet this week. Chores show up here as they're sent in.", color = Done, modifier = Modifier.padding(8.dp))
        } else {
            val time = DateTimeFormatter.ofLocalizedTime(FormatStyle.SHORT)
            for ((day, group) in items.groupBy { Engine.dayOf(it.timestamp, zone) }) {
                Text(feedDay(day, today), color = Done, fontWeight = FontWeight.Bold, style = MaterialTheme.typography.titleSmall,
                    modifier = Modifier.padding(top = 8.dp))
                for (l in group) {
                    val who = byId.getValue(l.playerId)
                    Row(Modifier.fillMaxWidth().panel(TileShape).padding(horizontal = 12.dp, vertical = 10.dp).semantics(mergeDescendants = true) {},
                        verticalAlignment = Alignment.CenterVertically) {
                        AvatarCircle(who, characters[l.playerId], 34.dp)
                        Column(Modifier.weight(1f).padding(start = 12.dp)) {
                            Text(buildAnnotatedString {
                                withStyle(SpanStyle(fontWeight = FontWeight.Bold)) { append(who.shownName) }
                                append(" "); append(l.choreName)
                            }, color = Ink, style = MaterialTheme.typography.bodyMedium, maxLines = 2)
                            Row {
                                Text(Instant.ofEpochMilli(l.timestamp).atZone(zone).toLocalTime().format(time), color = Done,
                                    style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.SemiBold)
                                Text("  " + feedStatus(l.status), color = when (l.status) { Status.APPROVED -> Good; Status.REJECTED -> Bad; else -> Done },
                                    style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.SemiBold)
                            }
                        }
                    }
                }
            }
        }
    }
}

/**
 * One revealed dare: who dared whom on a small line, the chore beneath it, the result on the right.
 */
@Composable
fun DareLine(d: Dare, names: Map<String, String>, choreName: String, landed: Boolean) {
    Row(Modifier.fillMaxWidth().padding(vertical = 5.dp), verticalAlignment = Alignment.CenterVertically) {
        Text("${names[d.from] ?: d.from} dared ${names[d.target] ?: d.target} to $choreName.", style = MaterialTheme.typography.bodyMedium,
            color = Ink, modifier = Modifier.weight(1f))
        Text(if (landed) "Done, +${Engine.DARE_GUESSER_POINTS}" else "Didn't happen", color = if (landed) Good else Done,
            modifier = Modifier.padding(start = 12.dp))
    }
}
