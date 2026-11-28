package com.doyourwork.app.ui

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.selection.toggleable
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.Icon
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.draw.scale
import com.doyourwork.app.engine.FamilyGrid
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.graphics.painter.Painter
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.doyourwork.app.R
import com.doyourwork.app.engine.PlayerCharacter
import com.doyourwork.app.model.Player

/*
 * The pieces of the whiteboard redesign (docs/design/whiteboard-redesign.md): the heading, the
 * page indicator, rounded tiles and cards on the theme's background, and the buttons that sit on them.
 */

/** Corner radius of a tile (a person, a chore) and of a card (a section of settings, the person on chores). */
val TileShape = RoundedCornerShape(18.dp)
val CardShape = RoundedCornerShape(22.dp)

/** The gap around and between tiles and cards: nothing touches. */
val Gap = 12.dp

/** Pacifico, the font the icon's lettering comes from (SIL Open Font License). Only for the heading. */
val Pacifico = FontFamily(Font(R.font.pacifico, FontWeight.Normal))

/** The heat gradient the heading is filled with, left to right. */
private val HeadingHeat = listOf(Color(0xFFFF3B2F), Color(0xFFE2751C), Color(0xFFEDB82A))

/** "doyourwork" in Pacifico, filled with the heat gradient, over a thin rule in the muted colour. Stays put while the pages move. */
@Composable
fun Heading(modifier: Modifier = Modifier) {
    Column(modifier.fillMaxWidth().padding(horizontal = 20.dp).padding(top = 4.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        Text("doyourwork", style = TextStyle(fontFamily = Pacifico, fontSize = 34.sp, brush = Brush.horizontalGradient(HeadingHeat)),
            maxLines = 1, modifier = Modifier.semantics { contentDescription = "DOYOURWORK" })
        Box(Modifier.fillMaxWidth().padding(top = 2.dp).height(1.dp).background(Done.copy(alpha = 0.6f)))
    }
}

/** Room the pages leave at the bottom, so their last item scrolls out from under the tab bar. */
val TabBarRoom = 80.dp

/** How much room the page being drawn leaves at the bottom: [TabBarRoom] under the tab bar, none elsewhere. */
val LocalPageBottom = androidx.compose.runtime.compositionLocalOf { 0.dp }

/** One of the pages in the tab bar: its name and icon. */
data class TabPage(val id: String, val label: String, val icon: @Composable () -> Painter)

/**
 * The tab bar, floating over the bottom of the pages as iOS 27 draws it: a pill holding the pages
 * (each an icon over its name, the current one on a darker bubble in the main colour), and beside
 * it a round "Make a dare" button with a bolt, when [onDare] is given. As on iOS (`TabBar`).
 */
@Composable
fun TabBar(pages: List<TabPage>, current: Int, onPick: (Int) -> Unit, onDare: (() -> Unit)?, modifier: Modifier = Modifier) {
    val fb = LocalFeedback.current
    val main = Palette.HEAT.stops[0]
    Row(modifier.fillMaxWidth().padding(horizontal = 16.dp).padding(bottom = 4.dp), horizontalArrangement = Arrangement.spacedBy(10.dp, Alignment.CenterHorizontally),
        verticalAlignment = Alignment.CenterVertically) {
        Row(Modifier.barFill(CircleShape).padding(5.dp), horizontalArrangement = Arrangement.spacedBy(2.dp)) {
            pages.forEachIndexed { i, page ->
                val on = i == current
                val tint = if (on) main else Ink.copy(alpha = 0.85f)
                Column(
                    Modifier.size(72.dp, 48.dp).clip(CircleShape).background(if (on) bubbleColor() else Color.Transparent)
                        .clickable(onClickLabel = "go to ${page.label}") { fb.tap(); onPick(i) }
                        .semantics { selected = on },
                    horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center,
                ) {
                    Icon(page.icon(), contentDescription = null, tint = tint, modifier = Modifier.size(21.dp))
                    Text(page.label, color = tint, fontWeight = FontWeight.SemiBold, fontSize = 11.sp, maxLines = 1)
                }
            }
        }
        if (onDare != null) Box(
            Modifier.size(58.dp).barFill(CircleShape).clip(CircleShape)
                .clickable(onClickLabel = "Make a dare") { fb.tap(); onDare() }
                .semantics { contentDescription = "Make a dare" },
            contentAlignment = Alignment.Center,
        ) { Icon(painterResource(R.drawable.ic_bolt), contentDescription = null, tint = main, modifier = Modifier.size(22.dp)) }
    }
}

/** The selected page's bubble: darker than the bar. */
private fun bubbleColor(): Color = when (Themes.appearance) {
    Appearance.DARK -> Bg
    Appearance.LIGHT -> Color(0xFFE6E6EB)
    Appearance.GLASS -> Color.Black.copy(alpha = 0.28f)
}

/**
 * The bar's own fill: lighter than the page in dark (the background mixed 16% towards the text,
 * a faint outline and a shadow), white with a soft shadow in light, frosted in glass. There's no
 * real blur here, so glass is the deep background lit a little, nearly opaque, so what scrolls
 * under the bar doesn't show through its labels.
 */
private fun Modifier.barFill(shape: Shape): Modifier = when (Themes.appearance) {
    Appearance.DARK -> shadow(10.dp, shape, ambientColor = Color.Black, spotColor = Color.Black)
        .background(lerp(Themes.current.bg, Themes.current.text, 0.16f), shape).border(0.75.dp, Color.White.copy(alpha = 0.06f), shape)
    Appearance.LIGHT -> shadow(8.dp, shape, ambientColor = Color.Black.copy(alpha = 0.4f), spotColor = Color.Black.copy(alpha = 0.4f)).background(Color.White, shape)
    Appearance.GLASS -> shadow(10.dp, shape, ambientColor = Color.Black, spotColor = Color.Black)
        .background(lerp(Bg, Color.White, 0.16f).copy(alpha = 0.94f), shape).border(0.75.dp, Color.White.copy(alpha = 0.22f), shape)
}

/** A rounded card on the surface colour: one section of a page. */
@Composable
fun RoundCard(modifier: Modifier = Modifier, content: @Composable ColumnScope.() -> Unit) {
    Column(modifier.fillMaxWidth().panel(CardShape).padding(16.dp), content = content)
}

/** A page's main action, as a rounded button in the theme's main colour; muted when it can't be pressed yet. */
@Composable
fun MainButton(label: String, enabled: Boolean = true, modifier: Modifier = Modifier, onClick: () -> Unit) {
    val palette = LocalPalette.current
    Button(
        onClick = onClick, enabled = enabled, shape = TileShape,
        colors = ButtonDefaults.buttonColors(containerColor = palette.stops[0], contentColor = palette.ink,
            disabledContainerColor = SurfaceDark, disabledContentColor = Done),
        contentPadding = PaddingValues(horizontal = 18.dp, vertical = 8.dp),
        modifier = modifier.fillMaxWidth().heightIn(min = 52.dp),
    ) { FitText(label, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold, color = LocalContentColor.current) }
}

/** A secondary action: rounded, on the surface colour, so it never competes with the main one. */
@Composable
fun SoftButton(label: String, modifier: Modifier = Modifier, onSurface: Boolean = false, onClick: () -> Unit) {
    Button(
        onClick = onClick, shape = TileShape,
        // On a card (already the surface colour) it sits on the background, so it still reads as a button.
        colors = ButtonDefaults.buttonColors(containerColor = if (onSurface) InCard else SurfaceDark, contentColor = Ink),
        contentPadding = PaddingValues(horizontal = 18.dp, vertical = 8.dp),
        modifier = modifier.fillMaxWidth().heightIn(min = 46.dp),
    ) { FitText(label, style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.SemiBold, color = LocalContentColor.current) }
}

/** The DYW mark (the icon's lettering) and "×N": someone's streak, under their name. ×0 is faded to 40%. */
@Composable
fun StreakBadge(streak: Int, modifier: Modifier = Modifier, color: Color = Ink) {
    Row(modifier.alpha(if (streak == 0) 0.4f else 1f).semantics(mergeDescendants = true) { contentDescription = "$streak-day streak" }, verticalAlignment = Alignment.CenterVertically) {
        Image(painterResource(R.drawable.dyw_mark), contentDescription = null, modifier = Modifier.height(12.dp).width(15.3.dp))
        Text("×$streak", color = color, fontWeight = FontWeight.Bold, style = MaterialTheme.typography.labelMedium, modifier = Modifier.padding(start = 3.dp))
    }
}

/**
 * Someone on the family page: their avatar with its border, their shown name and their streak
 * (everyone shows one, so they line up). [selected] outlines the tile, for the person open beside it on a wide screen.
 */
@Composable
fun FamilyTile(player: Player, character: PlayerCharacter?, streak: Int, selected: Boolean, layout: FamilyGrid.Layout,
               modifier: Modifier = Modifier, onClick: () -> Unit) {
    val avatar = layout.avatar.toFloat()
    // The name and streak grow with the tile, within limits.
    val scale = (avatar / 110f).coerceIn(1f, 1.8f)
    Column(
        modifier.size(layout.tileWidth.toFloat().dp, layout.tileHeight.toFloat().dp).panel(TileShape).clip(TileShape)
            .then(if (selected) Modifier.border(3.dp, Themes.current.main, TileShape) else Modifier)
            .clickable(onClickLabel = "open ${player.shownName}'s profile", onClick = onClick)
            .padding(horizontal = 6.dp),
        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy((2 * scale).dp, Alignment.CenterVertically),
    ) {
        BorderedAvatar(player, character, Modifier.size(avatar.dp))
        FitText(player.shownName, style = MaterialTheme.typography.titleSmall.copy(fontSize = (15 * scale).sp, textAlign = TextAlign.Center),
            fontWeight = FontWeight.Bold, color = Ink)
        Box(Modifier.height((18 * scale).dp), contentAlignment = Alignment.Center) { StreakBadge(streak, Modifier.scale(scale)) }
    }
}

/** How many tiles across: 3 on a phone, one per 120dp where there's more room, up to 6. */
fun tilesAcross(width: Dp): Int = (width / 120.dp).toInt().coerceIn(3, 6)

/** Tiles in rows of [across], each the same width, with [Gap] between them. Give tiles a fixed height so rows line up. */
@Composable
fun <T> TileGrid(items: List<T>, across: Int, modifier: Modifier = Modifier, gap: Dp = Gap, tile: @Composable (T, Modifier) -> Unit) {
    Column(modifier, verticalArrangement = Arrangement.spacedBy(gap)) {
        for (row in items.chunked(across)) Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(gap)) {
            for (item in row) tile(item, Modifier.weight(1f))
            repeat(across - row.size) { Spacer(Modifier.weight(1f)) }
        }
    }
}

/** "Whose profile?" over the people as small avatar tiles; tapping one picks them. */
@Composable
fun WhoPicker(players: List<Player>, characters: Map<String, PlayerCharacter>, onPick: (Player) -> Unit, modifier: Modifier = Modifier,
              title: String = "Whose profile?") {
    val fb = LocalFeedback.current
    BoxWithConstraints(modifier.fillMaxWidth()) {
        val across = (maxWidth / 96.dp).toInt().coerceIn(3, 6)
        Column {
            Text(title, color = Ink, fontWeight = FontWeight.Black, style = MaterialTheme.typography.titleLarge,
                modifier = Modifier.padding(bottom = Gap))
            if (players.isEmpty()) Text("Nobody's playing yet. An admin can add players in Settings, under Admin.", color = Done)
            TileGrid(players, across, gap = 8.dp) { p, m ->
                Column(
                    m.panel(TileShape).clip(TileShape).clickable(onClickLabel = "pick ${p.shownName}") { fb.tap(); onPick(p) }
                        .padding(8.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    AvatarCircle(p, characters[p.id], 48.dp)
                    FitText(p.shownName, style = MaterialTheme.typography.labelLarge, fontWeight = FontWeight.Bold, color = Ink,
                        modifier = Modifier.padding(top = 6.dp))
                }
            }
        }
    }
}

/**
 * One chore as a rounded tile, two across on the chores page: its name and minutes (or its verdict
 * once sent), "!" or "!!" when it's been left too long. Lit in the theme's main colour when picked
 * (while picking) or still to do (on a card); otherwise on the surface colour.
 */
@Composable
fun ChoreTile(
    name: String,
    minutes: Int,
    escalLevel: Int,
    checked: Boolean,
    modifier: Modifier = Modifier,
    status: String? = null,
    picking: Boolean = false,
    faded: Boolean = false,
    onToggle: (() -> Unit)? = null,
) {
    val palette = LocalPalette.current
    val badge = listOf("", "!", "!!").getOrElse(escalLevel) { "" }
    val verdict = when (status) {
        "approved" -> "approved" to Good
        "rejected" -> "turned down" to Bad
        "pending" -> "waiting" to null
        TAKEN -> "taken" to Done
        else -> null
    }
    val lit = if (picking) checked else if (status == null) !checked else status == "pending"
    val struck = !picking && (if (status == null) checked else status == "approved" || status == TAKEN)
    val ink = if (lit) palette.ink else Ink
    val quiet = if (lit) palette.ink.copy(alpha = 0.85f) else Done
    val action = if (onToggle != null && status == null) {
        Modifier.toggleable(value = checked, role = Role.Checkbox, onValueChange = { onToggle() })
    } else Modifier.semantics(mergeDescendants = true) { contentDescription = "$name, ${verdict?.first ?: "${minutes} minutes"}" }
    Column(
        (if (lit) modifier.clip(TileShape).background(palette.stops[0]) else modifier.panel(TileShape).clip(TileShape)).then(action)
            .alpha(if (faded) 0.45f else 1f).height(92.dp).padding(horizontal = 14.dp, vertical = 12.dp),
        verticalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(name, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold, maxLines = 2, overflow = TextOverflow.Ellipsis,
            color = if (lit || picking || status == "rejected") ink else Done, textDecoration = if (struck) TextDecoration.LineThrough else null)
        Row(Modifier.fillMaxWidth().padding(top = 6.dp), verticalAlignment = Alignment.CenterVertically) {
            if (verdict != null) Text(verdict.first, color = verdict.second ?: quiet, style = MaterialTheme.typography.labelLarge, fontWeight = FontWeight.SemiBold,
                modifier = Modifier.weight(1f))
            else Text("${minutes}m", color = quiet, style = MaterialTheme.typography.labelLarge, modifier = Modifier.weight(1f))
            if (badge.isNotEmpty()) Text(badge, fontWeight = FontWeight.Black, color = if (lit) palette.ink else if (escalLevel == 1) Warn else Bad)
        }
    }
}
