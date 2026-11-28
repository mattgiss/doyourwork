package com.doyourwork.app.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.ui.text.style.TextAlign
import com.doyourwork.app.engine.FamilyGrid
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.doyourwork.app.AppViewModel
import com.doyourwork.app.engine.Engine
import com.doyourwork.app.model.ChoreLog
import com.doyourwork.app.model.Player

/**
 * The family page: the people who do chores as tiles, in family order, as big as the page allows
 * (see FamilyGrid). A tile is their avatar with its border, their name, and their streak; tapping it
 * opens their profile. Below, on a linked phone, whose phone this is (or the question, until it's answered).
 */
@Composable
fun FamilyPage(
    vm: AppViewModel,
    players: List<Player>,
    logs: List<ChoreLog>,
    me: String?,
    /** Outlined: the person open beside the family on a wide screen. */
    selectedId: String?,
    onPick: (Player) -> Unit,
    modifier: Modifier = Modifier,
) {
    val fb = LocalFeedback.current
    val linked by vm.relayLinked.collectAsState()
    val now = vm.now()
    val characters = vm.characters(players)
    val names = players.associate { it.id to it.shownName }
    BoxWithConstraints(modifier.fillMaxSize()) {
        // As big as the page allows: one person fills it, and the tiles shrink as more join
        // (FamilyGrid), leaving room below for "whose phone" on a linked phone. As on iOS.
        val bottom = LocalPageBottom.current
        val below = if (linked) 64.dp else 0.dp
        val layout = FamilyGrid.layout(players.size, (maxWidth - 32.dp).value.toDouble(),
            (maxHeight - 16.dp - bottom - below).value.toDouble())
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState(), enabled = layout.scrolls)
            .padding(horizontal = 16.dp).padding(top = 8.dp, bottom = 8.dp + bottom), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            if (players.isEmpty()) Text("Nobody's doing chores yet. An admin can add people in Settings, under Admin.", color = Done)
            val gap = FamilyGrid.GAP.toFloat().dp
            Column(verticalArrangement = Arrangement.spacedBy(gap)) {
                for (row in players.chunked(layout.columns)) Row(horizontalArrangement = Arrangement.spacedBy(gap)) {
                    for (p in row) FamilyTile(p, characters[p.id], Engine.streak(p.id, logs, now, vm.zone), selected = p.id == selectedId,
                        layout = layout) { fb.tap(); onPick(p) }
                }
            }

            // Whose phone is this? Asked once; changing it later needs the admin unlock. Only a phone
            // linked to the family's others needs to know, for the dares.
            if (linked && players.isNotEmpty()) {
                if (me == null || me !in names) {
                    RoundCard {
                        Text("Whose phone is this?", color = Ink, fontWeight = FontWeight.Bold, style = MaterialTheme.typography.titleSmall)
                        Row(Modifier.padding(top = 8.dp).horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            for (p in players) Text(p.shownName, fontWeight = FontWeight.Bold, color = Ink,
                                modifier = Modifier.clip(CircleShape).background(InCard).clickable { fb.tap(); vm.setMe(p) }
                                    .padding(horizontal = 18.dp, vertical = 12.dp))
                        }
                    }
                } else {
                    Text("This is ${names[me]}'s phone.", style = MaterialTheme.typography.labelMedium, color = Done,
                        textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth())
                }
            }
        }
    }
}
