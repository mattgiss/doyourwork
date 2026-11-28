package com.doyourwork.app.ui

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.key
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.snapshotFlow
import com.doyourwork.app.model.Player
import kotlinx.coroutines.launch
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Settings
import androidx.compose.ui.graphics.vector.rememberVectorPainter
import androidx.compose.ui.res.painterResource
import com.doyourwork.app.R
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.WindowInsetsSides
import androidx.compose.foundation.layout.only
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.layout.width

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.VerticalDivider
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.runtime.remember
import com.doyourwork.app.widget.WidgetWriter
import androidx.compose.runtime.CompositionLocalProvider
import androidx.window.layout.FoldingFeature
import com.doyourwork.app.AppViewModel

/** Two panes need at least this much room for the list and for what opens beside it. */
private val MinPane = 300.dp
/** Wide enough for the list; any wider and it only pushes the names away from the numbers. */
private val MaxListPane = 420.dp
/** Rows stretched across a tablet are hard to read; keep the open screen column-width. */
private val MaxDetailPane = 640.dp

/**
 * How wide the list pane is beside the open screen.
 *
 * With a hinge running top to bottom (a foldable opened like a book), the list takes the half
 * left of the hinge, so nothing straddles the fold. Otherwise — a tablet, or a foldable turned on
 * its side, where the hinge runs across — it gets a little under half the width, within limits.
 */
fun listPaneWidth(window: Dp, hingeLeft: Dp?): Dp =
    hingeLeft?.takeIf { it >= MinPane && window - it >= MinPane }
        ?: (window * 0.42f).coerceIn(MinPane, MaxListPane)

/** The pages a layout swipes between: all three on a phone, or the two beside the family pane. */
fun pagesFor(twoPane: Boolean): List<String> = if (twoPane) listOf("feed", "settings") else listOf("family", "feed", "settings")

/** Dares need each phone to be someone's: only a linked phone that knows whose it is has them. */
fun canDare(linked: Boolean, me: String?, players: List<Player>): Boolean = linked && players.any { it.id == me }

/** The profile's "Dare": when you can dare, and not on your own profile. */
fun daresFromProfile(linked: Boolean, me: String?, players: List<Player>, profileId: String): Boolean =
    canDare(linked, me, players) && me != profileId

/** The profile's "Photo and border": your own on your own phone, or anyone's on a phone that isn't someone's. */
fun editsLookFromProfile(linked: Boolean, me: String?, profileId: String): Boolean = !linked || me == null || me == profileId

private val TAB_PAGES = mapOf(
    "family" to TabPage("family", "Family") { painterResource(R.drawable.ic_tab_family) },
    "feed" to TabPage("feed", "Feed") { painterResource(R.drawable.ic_tab_feed) },
    "settings" to TabPage("settings", "Settings") { rememberVectorPainter(Icons.Filled.Settings) },
)

/**
 * The whole app (docs/design/whiteboard-redesign.md): the heading, and three pages swiped between
 * (family · feed · settings) under a floating tab bar. Tapping a family tile opens that person's
 * profile over the pages. Once there's room for two panes, family stays on the left and the right
 * pane swipes between feed and settings, or shows the profile. The puzzle and snake take the whole
 * window; dares and the admin area open over everything (in the right pane on a wide screen).
 * Kept apart from the activity so it can be drawn without the activity's sync loop.
 */
@Composable
fun AppRoot(vm: AppViewModel, fold: FoldingFeature?) {
    val logs by vm.store.logs.collectAsState()
    val family by vm.store.family.collectAsState()
    val syncedOnce by vm.syncedOnce.collectAsState()
    val linked by vm.relayLinked.collectAsState()
    val notice by vm.notice.collectAsState()
    notice?.let { m ->
        androidx.compose.material3.AlertDialog(onDismissRequest = { vm.notice.value = null }, text = { Text(m) },
            confirmButton = { androidx.compose.material3.TextButton(onClick = { vm.notice.value = null }) { Text("OK") } })
    }
    val players = family.players
    val cards by vm.store.cards.collectAsState()
    val syncStatus by vm.syncStatus.collectAsState()
    val shared by vm.store.state.collectAsState()
    val me by vm.store.me.collectAsState()
    // Saved state, so fold/unfold, a theme change and process death land on the same screen.
    var page by rememberSaveable { mutableStateOf("family") }
    /** Whose profile is open, if anyone's. */
    var profileId by rememberSaveable { mutableStateOf<String?>(null) }
    /** Whose photo and border settings shows: picked there or from a profile; null falls back to whose phone this is. */
    var personId by rememberSaveable { mutableStateOf<String?>(null) }
    /** "Switch person" was tapped in settings: ask whose profile, even on a phone that's someone's. */
    var choosing by rememberSaveable { mutableStateOf(false) }
    var adminOpen by rememberSaveable { mutableStateOf(false) }
    var daresOpen by rememberSaveable { mutableStateOf(false) }
    var dareTarget by rememberSaveable { mutableStateOf<String?>(null) }
    // The puzzle takes the whole window, even beside the list on a foldable, so its flash fills the screen.
    var puzzleId by rememberSaveable { mutableStateOf<String?>(null) }
    var snakeId by rememberSaveable { mutableStateOf<String?>(null) }
    val person = if (choosing) null else players.firstOrNull { it.id == (personId ?: me) }
    val profile = players.firstOrNull { it.id == profileId }
    val puzzlePlayer = players.firstOrNull { it.id == puzzleId }
    val snakePlayer = players.firstOrNull { it.id == snakeId }
    val dares = canDare(linked, me, players)

    // Tabletop: half-open with a horizontal hinge. Content above it, controls below.
    val hinge = if (fold != null && fold.state == FoldingFeature.State.HALF_OPENED && fold.orientation == FoldingFeature.Orientation.HORIZONTAL)
        Hinge(fold.bounds.top, fold.bounds.bottom) else null
    // Book posture or a flat inner screen held upright: the hinge runs top to bottom.
    val hingeX = if (fold != null && fold.orientation == FoldingFeature.Orientation.VERTICAL) fold.bounds.left else null

    val myId = me
    val showDares = daresOpen && dares
    val scope = rememberCoroutineScope()
    val openDares = { target: String? -> adminOpen = false; dareTarget = target; daresOpen = true }

    // Transparent over the backdrop (the wash shows through in glass), still setting the text colour for everything inside.
    Surface(Modifier.fillMaxSize().appBackdrop(), color = androidx.compose.ui.graphics.Color.Transparent, contentColor = MaterialTheme.colorScheme.onBackground) {
        if (!family.isSetUp) {
            Box(Modifier.fillMaxSize().safeDrawingPadding()) {
                // Only a phone that just joined a family waits for it; an unlinked one has nothing to wait for.
                if (linked && !syncedOnce) WaitingForFamily(vm, syncStatus) else SetupScreen(vm)
            }
            return@Surface
        }
        BoxWithConstraints(Modifier.fillMaxSize().windowInsetsPadding(WindowInsets.safeDrawing.only(WindowInsetsSides.Horizontal + WindowInsetsSides.Bottom))) {
            // Two panes whenever both fit. The Z Fold 7's inner screen is about 750dp by 830dp, so
            // it gets two panes whichever way up it's held; its cover screen and other phones don't.
            val windowWidth = maxWidth
            val twoPane = windowWidth >= MinPane * 2
            val names = pagesFor(twoPane)
            val pager = key(twoPane) { rememberPagerState(initialPage = names.indexOf(page).coerceAtLeast(0)) { names.size } }
            LaunchedEffect(pager, names) { snapshotFlow { pager.currentPage }.collect { page = names[it] } }
            fun go(name: String) { names.indexOf(name).takeIf { it >= 0 }?.let { scope.launch { pager.animateScrollToPage(it) } } }
            val openProfile = { p: Player -> adminOpen = false; daresOpen = false; profileId = p.id }

            BackHandler(enabled = puzzlePlayer != null || snakePlayer != null || adminOpen || showDares || profile != null || pager.currentPage != 0) {
                when {
                    puzzlePlayer != null -> puzzleId = null
                    snakePlayer != null -> snakeId = null
                    adminOpen -> adminOpen = false
                    showDares -> daresOpen = false
                    profile != null -> profileId = null
                    else -> scope.launch { pager.animateScrollToPage(0) }
                }
            }

            val familyPage = @Composable { m: Modifier ->
                FamilyPage(vm, players, logs, me, profile?.id.takeIf { twoPane }, onPick = openProfile, modifier = m)
            }
            val pages = @Composable { m: Modifier ->
                Box(m) {
                    CompositionLocalProvider(LocalPageBottom provides TabBarRoom) {
                        HorizontalPager(pager, Modifier.fillMaxSize(), key = { names[it] }) { i ->
                            when (names[i]) {
                                "family" -> familyPage(Modifier)
                                "feed" -> FeedPage(vm, players, logs, shared, me, onDares = { openDares(null) })
                                else -> SettingsPage(vm, person, players, logs, shared, syncStatus,
                                    onPick = { personId = it.id; choosing = false }, onSwitch = { choosing = true },
                                    onAdmin = { daresOpen = false; adminOpen = true })
                            }
                        }
                    }
                    TabBar(names.map { TAB_PAGES.getValue(it) }, pager.currentPage, onPick = { scope.launch { pager.animateScrollToPage(it) } },
                        onDare = if (dares) ({ openDares(null) }) else null, modifier = Modifier.align(Alignment.BottomCenter))
                }
            }
            // Someone's profile, with the ways out of it. A fresh screen per person, so one kid's
            // half-picked card doesn't carry over to the next.
            val profileView = @Composable { p: Player ->
                key(p.id) {
                    PlayerScreen(vm, p, logs, cards, hinge, onBack = { profileId = null },
                        onDare = if (daresFromProfile(linked, me, players, p.id)) ({ openDares(p.id) }) else null,
                        onEditLook = if (editsLookFromProfile(linked, me, p.id)) ({
                            personId = p.id; choosing = false; profileId = null; go("settings")
                        }) else null,
                        onPuzzle = { puzzleId = p.id }, onSnake = { snakeId = p.id })
                }
            }
            // What opens over the pages: the admin area or the dares, as before.
            val over = @Composable {
                when {
                    adminOpen -> AdminScreen(vm, logs, onBack = { adminOpen = false })
                    showDares -> DaresScreen(vm, players, logs, shared, myId!!, onBack = { daresOpen = false }, initialTarget = dareTarget)
                }
            }

            if (puzzlePlayer != null) {
                Box(Modifier.statusBarsPadding()) { PuzzleScreen(vm, puzzlePlayer, onBack = { puzzleId = null }) }
            } else if (snakePlayer != null) {
                Box(Modifier.statusBarsPadding()) { SnakeScreen(vm, snakePlayer, onBack = { snakeId = null }) }
            } else if (twoPane) {
                val hingeLeft = hingeX?.let { with(LocalDensity.current) { it.toDp() } }
                Row(Modifier.fillMaxSize()) {
                    // The heading sits over the family, so nothing straddles a fold down the middle.
                    Column(Modifier.width(listPaneWidth(windowWidth, hingeLeft)).fillMaxHeight().statusBarsPadding()) {
                        Heading()
                        familyPage(Modifier.weight(1f))
                    }
                    VerticalDivider()
                    BoxWithConstraints(Modifier.weight(1f).fillMaxHeight()) {
                        // Rows stretched across a big tablet are hard to read: keep the open screen column-width.
                        val inset = ((maxWidth - MaxDetailPane) / 2).coerceAtLeast(0.dp)
                        when {
                            adminOpen || showDares -> CompositionLocalProvider(LocalColumnInset provides inset) { Box(Modifier.fillMaxSize()) { over() } }
                            profile != null -> Box(Modifier.fillMaxSize().statusBarsPadding().padding(horizontal = inset)) { profileView(profile) }
                            else -> pages(Modifier.fillMaxSize().statusBarsPadding().padding(horizontal = inset))
                        }
                    }
                }
            } else if (adminOpen || showDares) {
                over()
            } else if (profile != null) {
                // Pushed over the pages, and the tab bar goes with them.
                Box(Modifier.fillMaxSize().statusBarsPadding()) { profileView(profile) }
            } else {
                Column(Modifier.fillMaxSize().statusBarsPadding()) {
                    Heading()
                    pages(Modifier.weight(1f))
                }
            }
        }
    }
}
