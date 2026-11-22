package com.doyourwork.app.widget

import android.content.Context
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import com.doyourwork.app.AppViewModel
import com.doyourwork.app.engine.Engine
import com.doyourwork.app.model.Status
import com.doyourwork.app.ui.Themes
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.FlowPreview
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.debounce
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import androidx.lifecycle.viewModelScope
import java.io.File

/**
 * Keeps the home screen widgets up to date: whenever the scoreboard or the theme changes, writes a
 * [WidgetSnapshot] to the app's files and redraws the widgets. Only what the widgets show goes in
 * it; today's dares stay secret until midnight.
 */
object WidgetWriter {
    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }
    private var last: WidgetSnapshot? = null

    fun file(ctx: Context) = File(ctx.filesDir, "widget.json")

    fun read(ctx: Context): WidgetSnapshot? = runCatching { json.decodeFromString<WidgetSnapshot>(file(ctx).readText()) }.getOrNull()

    /** Starts watching the view model's store. Writes once straight away, then a moment after each change settles. */
    @OptIn(FlowPreview::class)
    fun start(vm: AppViewModel) {
        val s = vm.store
        vm.viewModelScope.launch {
            combine(s.logs, s.cards, s.family, s.state, s.me) { _, _, _, _, _ -> }
                .combine(snapshotFlow { Themes.current }) { _, _ -> }
                .combine(vm.relayLinked) { _, _ -> }
                .debounce(400)
                .collect { write(vm) }
        }
    }

    /** Writes the snapshot if it changed. Also called when the app comes back on screen, since the day may have turned over. */
    fun write(vm: AppViewModel) {
        val ctx = vm.getApplication<android.app.Application>()
        if (!vm.store.family.value.isSetUp) return
        val snap = snapshot(vm)
        if (snap == last) return
        last = snap
        vm.viewModelScope.launch {
            withContext(Dispatchers.IO) { file(ctx).writeText(json.encodeToString(WidgetSnapshot.serializer(), snap)) }
            refreshWidgets(ctx)
        }
    }

    fun snapshot(vm: AppViewModel): WidgetSnapshot {
        val store = vm.store
        val logs = store.logs.value
        val state = store.state.value
        val family = store.family.value
        val today = vm.today()
        val dares = vm.dares(state)
        val players = family.players.map { p ->
            val card = vm.cardFor(p.id, store.cards.value, logs)
            var cardState = "pick"
            var done = 0
            var planned = 0
            var next: String? = null
            if (card != null) {
                planned = card.minutes.sum()
                done = card.minutes.indices.filter { card.checked.getOrElse(it) { false } }.sumOf { card.minutes[it] }
                next = card.choreIds.indices.firstOrNull { !card.checked.getOrElse(it) { false } }?.let { vm.choreName(card.choreIds[it]) }
                cardState = if (!card.submitted) "playing" else {
                    val status = Engine.statusToday(vm.todaysLogs(p.id, logs))
                    if (status.isNotEmpty() && status.values.all { it == Status.APPROVED }) "approved" else "sent"
                }
            }
            WidgetSnapshot.Player(
                id = p.id, name = p.shownName, minutesDone = done, minutesPlanned = planned, card = cardState, next = next,
                streak = Engine.streak(p.id, logs, vm.now(), vm.zone),
                streakToday = vm.todaysLogs(p.id, logs).any { it.status == Status.APPROVED },
                weekPoints = Engine.weekPoints(p.id, logs, dares, today, vm.zone),
                version = Engine.rank(vm.totalXp(p.id, logs, state)).version,
            )
        }.sortedByDescending { it.weekPoints }

        val names = family.members.associate { it.id to it.shownName }
        val yesterday = today.minusDays(1).toString()
        val revealed = dares.filter { it.day == yesterday }.map {
            WidgetSnapshot.Revealed(it.from, it.target, names[it.from] ?: it.from, names[it.target] ?: it.target,
                vm.choreName(it.choreId), Engine.dareLanded(it, logs, vm.zone))
        }
        val me = store.me.value
        val used = me?.let { m -> dares.count { it.from == m && it.day == today.toString() } } ?: 0

        val t = Themes.current
        val accent = if (t.isClear) Color(0xFFE8572A) else t.main
        val colors = WidgetSnapshot.Colors(
            bg = t.bg.rgb(), text = t.text.rgb(), muted = t.muted.rgb(), surface = t.surface.rgb(), accent = accent.rgb(),
            heat = (0 until 6).map { t.heat.band(it, 6).rgb() }, heatInk = t.heat.ink.rgb(),
            plum = t.plum.stops[0].rgb(), plumInk = t.plum.ink.rgb(),
        )
        return WidgetSnapshot(today.toString(), Engine.weekStart(today).toString(), players, me, vm.relayLinked.value,
            maxOf(0, Engine.MAX_DARES_PER_DAY - used), revealed, colors)
    }

    private fun Color.rgb(): Long = (toArgb().toLong() and 0xFFFFFF)
}
