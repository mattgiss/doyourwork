package com.doyourwork.app.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Switch
import androidx.compose.material3.Icon
import androidx.compose.material3.TextButton
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.res.painterResource
import com.doyourwork.app.R
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.doyourwork.app.AppViewModel
import com.doyourwork.app.engine.Borders
import com.doyourwork.app.model.ChoreLog
import com.doyourwork.app.model.Player
import com.doyourwork.app.model.Status
import com.doyourwork.app.sync.LocalEntry

/**
 * The settings page, as rounded cards: the profile of the person on chores (photo, character,
 * name), their borders, the look of this phone, the admin area and what this is.
 */
@Composable
fun SettingsPage(
    vm: AppViewModel,
    player: Player?,
    players: List<Player>,
    logs: List<ChoreLog>,
    shared: Map<String, LocalEntry>,
    syncStatus: String,
    onPick: (Player) -> Unit,
    /** "Switch person": ask whose profile again, even on a phone that's someone's. */
    onSwitch: () -> Unit,
    onAdmin: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val fb = LocalFeedback.current
    val ctx = LocalContext.current
    val linked by vm.relayLinked.collectAsState()
    val family by vm.store.family.collectAsState()
    val characters = remember(family) { vm.characters(family.players) }
    Column(modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(Gap).padding(bottom = LocalPageBottom.current), verticalArrangement = Arrangement.spacedBy(Gap)) {
        // 1. Profile: the person picked from a profile's camera button, else whose phone this is, else asked.
        RoundCard {
            if (player == null) WhoPicker(players, characters, onPick)
            else Profile(vm, player, characters, onSwitch)
        }

        // 2. Borders.
        if (player != null) RoundCard { BordersPicker(vm, player, characters, vm.totalXp(player.id, logs, shared)) }

        // 3. Look: the theme and sound.
        RoundCard {
            var picking by remember { mutableStateOf(false) }
            if (picking) ThemePicker { picking = false }
            var soundOn by remember { mutableStateOf(fb.soundOn) }
            Text("Look", color = Ink, fontWeight = FontWeight.Black, style = MaterialTheme.typography.titleMedium)
            // Dark, light or glass, on top of the theme. Kept on this phone.
            Row(Modifier.fillMaxWidth().padding(top = 10.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                for (a in Appearance.entries) {
                    val on = Themes.appearance == a
                    val tint = if (on) Palette.HEAT.ink else Ink
                    Column(
                        Modifier.weight(1f).heightIn(min = 60.dp).clip(RoundedCornerShape(14.dp)).background(if (on) Palette.HEAT.stops[0] else InCard)
                            .clickable(onClickLabel = "use ${a.label} mode") { fb.tap(); Themes.pick(ctx, a) }
                            .semantics(mergeDescendants = true) { contentDescription = "${a.label} mode"; selected = on; role = Role.Button }
                            .padding(vertical = 8.dp),
                        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center,
                    ) {
                        Icon(painterResource(when (a) { Appearance.DARK -> R.drawable.ic_moon; Appearance.LIGHT -> R.drawable.ic_sun; Appearance.GLASS -> R.drawable.ic_drop }),
                            contentDescription = null, tint = tint, modifier = Modifier.size(20.dp))
                        Text(a.label, color = tint, fontWeight = FontWeight.Bold, style = MaterialTheme.typography.labelLarge, modifier = Modifier.padding(top = 4.dp))
                    }
                }
            }
            Row(Modifier.fillMaxWidth().clip(TileShape).clickable(onClickLabel = "pick a theme") { fb.tap(); picking = true }.padding(vertical = 12.dp),
                verticalAlignment = Alignment.CenterVertically) {
                Text("Theme", color = Ink, modifier = Modifier.weight(1f))
                Text(Themes.current.name, color = Done, fontWeight = FontWeight.SemiBold)
            }
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                Text("Sound", color = Ink, modifier = Modifier.weight(1f))
                Switch(checked = soundOn, onCheckedChange = { soundOn = it; fb.soundOn = it; fb.tick(it) })
            }
        }

        // 4. Admin: approvals, players, chores and the device settings, behind an admin's code.
        val waiting = logs.count { it.status == Status.PENDING }
        Row(
            Modifier.fillMaxWidth().panel(CardShape).clip(CardShape).clickable(onClickLabel = "open the admin area") { fb.tap(); onAdmin() }
                .padding(horizontal = 16.dp, vertical = 18.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text("Admin", color = Ink, fontWeight = FontWeight.Black, style = MaterialTheme.typography.titleMedium, modifier = Modifier.weight(1f))
            if (waiting > 0) Text("$waiting waiting", color = Themes.current.main, fontWeight = FontWeight.Bold)
            Text("  ›", color = Done, fontWeight = FontWeight.Bold)
        }

        // 5. About.
        RoundCard {
            Text("About", color = Ink, fontWeight = FontWeight.Black, style = MaterialTheme.typography.titleMedium)
            Text(if (linked) syncStatus.replaceFirstChar { it.uppercase() } + "." else "Everything here stays on this device.",
                color = Done, modifier = Modifier.padding(top = 6.dp))
            // Lets you confirm which build a phone is running (useful after installing an update by hand).
            val version = remember { runCatching { ctx.packageManager.getPackageInfo(ctx.packageName, 0).versionName }.getOrNull() ?: "?" }
            Text("Version $version", style = MaterialTheme.typography.labelMedium, color = Done, modifier = Modifier.padding(top = 4.dp))
        }
    }
}

/** Their avatar large, with their border; a selfie, a photo, no photo, or a character; and their name. */
@Composable
private fun Profile(vm: AppViewModel, player: Player, characters: Map<String, com.doyourwork.app.engine.PlayerCharacter>, onSwitch: () -> Unit) {
    val fb = LocalFeedback.current
    val family by vm.store.family.collectAsState()
    var naming by remember { mutableStateOf(false) }
    if (naming) DisplayNameDialog(player, onDismiss = { naming = false }) { vm.setDisplayName(player.id, it); naming = false }
    var choosing by remember { mutableStateOf(false) }
    val character = characters[player.id]
    if (choosing) CharacterPicker(
        current = character,
        takenBy = family.players.filter { it.id != player.id }.mapNotNull { o -> characters[o.id]?.let { it.id to o.shownName } }.toMap(),
        // Picking a character takes the photo off, so the character is what shows.
        onPick = { vm.setCharacter(player.id, it.id); if (player.photo != null) vm.setPhoto(player.id, null); choosing = false },
        onDismiss = { choosing = false },
    )
    val photos = rememberPhotoTaker(onPhoto = { vm.setPhoto(player.id, it); fb.tap() }, onProblem = { vm.notice.value = it })
    Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
        BorderedAvatar(player, character, Modifier.width(180.dp).semantics {
            contentDescription = if (player.photo != null) "Your photo" else "Your character: ${character?.name ?: "none"}"
        })
        Text(player.shownName, color = Ink, fontWeight = FontWeight.Black, style = MaterialTheme.typography.headlineSmall, textAlign = TextAlign.Center,
            modifier = Modifier.clip(TileShape).clickable(onClickLabel = "rename") { fb.tap(); naming = true }.padding(horizontal = 12.dp, vertical = 4.dp))
        Text("Tap your name to change it.", color = Done, style = MaterialTheme.typography.labelMedium)
        TextButton(onClick = { fb.tap(); onSwitch() }) { Text("Switch person", color = Ink, fontWeight = FontWeight.Bold) }
    }
    Column(Modifier.fillMaxWidth().padding(top = Gap), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        SoftButton("Take a selfie", onSurface = true) { fb.tap(); photos.selfie() }
        SoftButton("Choose a photo", onSurface = true) { fb.tap(); photos.library() }
        if (player.photo != null) SoftButton("Remove photo", onSurface = true) { fb.tap(); vm.setPhoto(player.id, null) }
        SoftButton(if (player.photo == null) "Change character" else "Use a character instead", onSurface = true) { fb.tap(); choosing = true }
    }
}

/** Every border around their avatar: unlocked ones to wear, locked ones faded with the points they open at. */
@Composable
private fun BordersPicker(vm: AppViewModel, player: Player, characters: Map<String, com.doyourwork.app.engine.PlayerCharacter>, xp: Int) {
    val fb = LocalFeedback.current
    val next = Borders.next(xp)
    val worn = player.border ?: "none"
    Text("Borders", color = Ink, fontWeight = FontWeight.Black, style = MaterialTheme.typography.titleMedium)
    Text(if (next == null) "Every border unlocked." else "$xp points so far. ${next.pointsToGo} more for ${next.border.name}.",
        color = Done, modifier = Modifier.padding(top = 4.dp, bottom = Gap))
    BoxWithConstraints(Modifier.fillMaxWidth()) {
        val across = (maxWidth / 84.dp).toInt().coerceIn(3, 6)
        TileGrid(Borders.all, across, gap = 8.dp) { b, m ->
            val open = Borders.isUnlocked(b, xp)
            val on = b.id == worn
            Column(
                m.clip(TileShape).background(InCard)
                    .then(if (on) Modifier.border(2.dp, Themes.current.main, TileShape) else Modifier)
                    .clickable(enabled = open && !on, onClickLabel = "wear ${b.name}") { fb.tap(); vm.setBorder(player.id, b.id) }
                    .semantics(mergeDescendants = true) {
                        contentDescription = b.name; role = Role.Button; selected = on
                        if (!open) stateDescription = "at ${b.unlockXp} points"
                    }
                    .alpha(if (open) 1f else 0.4f).padding(6.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                BorderedAvatar(player, characters[player.id], Modifier.fillMaxWidth(), border = b.takeIf { it.layers.isNotEmpty() })
                FitText(if (open) b.name else "at ${b.unlockXp} points", style = MaterialTheme.typography.labelSmall, color = Ink,
                    fontWeight = FontWeight.SemiBold)
            }
        }
    }
}
