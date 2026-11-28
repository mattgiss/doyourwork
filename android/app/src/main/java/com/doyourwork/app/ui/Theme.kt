package com.doyourwork.app.ui

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.unit.dp
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.remember
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.luminance
import android.content.Context
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import com.doyourwork.app.R

/**
 * A look for the app, chosen per phone (the same list as iOS's AppTheme). "Fuego" is the default
 * (saved as "clear", its old name, so phones that chose it keep it): black, with the Clear app's
 * red-to-yellow heat map for the players, its ocean blues for the admin area and
 * its plums for the dares. The rest are four colours each (background, main, muted, text), an idea
 * borrowed from monkeytype's themes; the palettes are from its dark themes, under names of our own.
 */
data class AppTheme(val id: String, val name: String, val bg: Color, val main: Color, val sub: Color, val text: Color) {
    val isClear get() = id == "clear"
    /** Text on a band of the main colour: the background colour when the main colour is light. */
    val ink get() = if (main.luminance() > 0.45f) bg else Color.White
    val surface get() = lerp(bg, text, if (isClear) 0.08f else 0.07f)
    /** Muted text and finished rows. */
    val muted get() = if (isClear) sub else lerp(sub, text, 0.25f)

    val heat get() = if (isClear) Palette(listOf(Color(0xFFD90015), Color(0xFFDB2A15), Color(0xFFE04A19), Color(0xFFE2751C), Color(0xFFE99A22), Color(0xFFEDB82A)), Color.White)
        else Palette(listOf(main, lerp(main, bg, 0.18f), lerp(main, bg, 0.34f), lerp(main, bg, 0.48f)), ink)
    val ocean get() = if (isClear) Palette(listOf(Color(0xFF3E9FC4), Color(0xFF45AAC0), Color(0xFF4FAFAE), Color(0xFF58B6A1), Color(0xFF60BD8F), Color(0xFF6BC276)), Color.White)
        else lerp(main, text, 0.25f).let { top -> Palette(listOf(top, lerp(main, bg, 0.2f), lerp(main, bg, 0.4f)), if (top.luminance() > 0.45f) bg else Color.White) }
    /** The dares: a quieter, after-dark version of the theme. */
    val plum get() = if (isClear) Palette(listOf(Color(0xFF34207A), Color(0xFF2B1869), Color(0xFF281760), Color(0xFF26165C), Color(0xFF201453)), Color(0xFFB9A2FF))
        else Palette(listOf(lerp(sub, bg, 0.2f), lerp(sub, bg, 0.45f), lerp(sub, bg, 0.6f)), text)

    companion object {
        val CLEAR = AppTheme("clear", "Fuego", Color(0xFF000000), Color(0xFFD90015), Color(0xFF5A5A5E), Color(0xFFFFFFFF))
        val ALL = listOf(
            CLEAR,
            AppTheme("mustard", "Mustard", Color(0xFF323437), Color(0xFFE2B714), Color(0xFF646669), Color(0xFFD1D0C5)),
            AppTheme("ember", "Ember", Color(0xFF313131), Color(0xFFF66E0D), Color(0xFF616161), Color(0xFFF5E6C8)),
            AppTheme("bubblegum", "Bubblegum", Color(0xFF333A45), Color(0xFFF44C7F), Color(0xFF939EAE), Color(0xFFE9ECF0)),
            AppTheme("coral", "Coral", Color(0xFF2D394D), Color(0xFFFF7A90), Color(0xFF4A768D), Color(0xFFFFFAF8)),
            AppTheme("grape", "Grape", Color(0xFF282A36), Color(0xFFBD93F9), Color(0xFF6272A4), Color(0xFFF8F8F2)),
            AppTheme("fjord", "Fjord", Color(0xFF242933), Color(0xFF88C0D0), Color(0xFF929AAA), Color(0xFFD8DEE9)),
            AppTheme("lavender", "Lavender", Color(0xFF1E1E2E), Color(0xFFCBA6F7), Color(0xFF7F849C), Color(0xFFCDD6F4)),
            AppTheme("lagoon", "Lagoon", Color(0xFF1F1D27), Color(0xFF9CCFD8), Color(0xFFC4A7E7), Color(0xFFE0DEF4)),
            AppTheme("campfire", "Campfire", Color(0xFF282828), Color(0xFFD79921), Color(0xFF665C54), Color(0xFFEBDBB2)),
            AppTheme("matcha", "Matcha", Color(0xFF523525), Color(0xFF7EC160), Color(0xFF9E6749), Color(0xFFECDDCC)),
            AppTheme("neon", "Neon", Color(0xFF262A33), Color(0xFF43FFAF), Color(0xFF526777), Color(0xFFE5F7EF)),
            AppTheme("sunset", "Sunset", Color(0xFF18181A), Color(0xFFE4609B), Color(0xFF47BAC0), Color(0xFFFFFFFF)),
            AppTheme("aurora", "Aurora", Color(0xFF011926), Color(0xFF00E980), Color(0xFF245C69), Color(0xFFFFFFFF)),
            AppTheme("peach", "Peach", Color(0xFF1C1B1D), Color(0xFFDEAF9D), Color(0xFF4E3E3E), Color(0xFFF2EFED)),
        )
    }
}

/**
 * How the whole app is lit, chosen per phone, on top of the theme's colours: dark (the theme as it
 * is), light (a pale background with dark text), or glass (see-through panels over a wash of the
 * theme's colours). The theme's main and band colours stay the same. As on iOS (`Appearance`).
 */
enum class Appearance(val id: String, val label: String) {
    DARK("dark", "Dark"), LIGHT("light", "Light"), GLASS("glass", "Glass");
    companion object { fun of(id: String?) = entries.firstOrNull { it.id == id } ?: DARK }
}

/** This phone's theme and appearance. Read during drawing, so a change redraws every screen. */
object Themes {
    var current by mutableStateOf(AppTheme.CLEAR)
    var appearance by mutableStateOf(Appearance.DARK)
    private const val KEY = "theme"
    private const val APPEARANCE_KEY = "appearance"
    val isLight get() = appearance == Appearance.LIGHT
    val isGlass get() = appearance == Appearance.GLASS
    fun load(ctx: Context) {
        val prefs = ctx.getSharedPreferences("look", Context.MODE_PRIVATE)
        current = AppTheme.ALL.firstOrNull { it.id == prefs.getString(KEY, null) } ?: AppTheme.CLEAR
        appearance = Appearance.of(prefs.getString(APPEARANCE_KEY, null))
    }
    fun pick(ctx: Context, t: AppTheme) {
        current = t
        ctx.getSharedPreferences("look", Context.MODE_PRIVATE).edit().putString(KEY, t.id).apply()
    }
    fun pick(ctx: Context, a: Appearance) {
        appearance = a
        ctx.getSharedPreferences("look", Context.MODE_PRIVATE).edit().putString(APPEARANCE_KEY, a.id).apply()
    }
}

/** Links and highlights. */
val Accent: Color get() = if (Themes.current.isClear) Color(0xFFE8572A) else Themes.current.main
val Warn = Color(0xFFEDB82A)
val Bad = Color(0xFFFF4D3D)
val Good = Color(0xFF6BC276)
/** Where a finished row goes, and quiet text. */
val Done: Color get() = if (Themes.isLight) Color(0xFF6E6E73) else Themes.current.muted
/** Tiles, cards and quiet buttons. In glass it's see-through, so the wash behind shows. */
val SurfaceDark: Color get() = when (Themes.appearance) {
    Appearance.DARK -> Themes.current.surface
    Appearance.LIGHT -> Color.White
    Appearance.GLASS -> Color.White.copy(alpha = 0.13f)
}
/** The background behind everything. In glass, a deep shade of the theme under the wash ([appBackdrop]). */
val Bg: Color get() = when (Themes.appearance) {
    Appearance.DARK -> Themes.current.bg
    Appearance.LIGHT -> lerp(Color(0xFFF2F2F7), Themes.current.main, 0.015f)
    Appearance.GLASS -> lerp(Themes.current.bg, Color.Black, 0.35f)
}
/** Ordinary text on the background. */
val Ink: Color get() = if (Themes.isLight) Color(0xFF141416) else Themes.current.text
/** A button or field inside a card: the background again, let through a little in glass. */
val InCard: Color get() = if (Themes.isGlass) Bg.copy(alpha = 0.35f) else Bg

/**
 * What's behind every screen: the plain background, or in glass a wash of the theme's colours
 * (the first band colour at 75% top left, through the background, to the last at 55% bottom right,
 * and a glow of the muted colour at 45% from the bottom left) for the see-through panels to sit on.
 */
fun Modifier.appBackdrop(): Modifier = drawBehind {
    drawRect(Bg)
    if (Themes.isGlass) {
        val stops = Themes.current.heat.stops
        drawRect(Brush.linearGradient(listOf(stops[0].copy(alpha = 0.75f), Bg.copy(alpha = 0.2f), stops.last().copy(alpha = 0.55f)),
            start = Offset.Zero, end = Offset(size.width, size.height)))
        drawRect(Brush.radialGradient(listOf(Themes.current.sub.copy(alpha = 0.45f), Color.Transparent),
            center = Offset(0f, size.height), radius = 420.dp.toPx()))
    }
}

/**
 * A tile's or card's fill: the surface colour, with a faint white outline in glass and a soft
 * shadow in light. As on iOS (`panel`).
 */
fun Modifier.panel(shape: Shape): Modifier = when (Themes.appearance) {
    Appearance.GLASS -> background(SurfaceDark, shape).border(0.75.dp, Color.White.copy(alpha = 0.18f), shape)
    Appearance.LIGHT -> shadow(3.dp, shape, ambientColor = Color.Black.copy(alpha = 0.3f), spotColor = Color.Black.copy(alpha = 0.3f)).background(SurfaceDark, shape)
    Appearance.DARK -> background(SurfaceDark, shape)
}
/** The puzzle's two colours of block. */
val BlockA: Color get() = if (Themes.current.isClear) Color(0xFFD90015) else Themes.current.main
val BlockB: Color get() = if (Themes.current.isClear) Color(0xFF45AAC0) else lerp(Themes.current.sub, Themes.current.text, 0.35f)

/** A run of colours that list rows step down, Clear-style, with the colour for text on them. */
data class Palette(val stops: List<Color>, val ink: Color) {
    /** Row [index] of [count]: as in Clear, a small step per row; a long list spreads the whole gradient out. */
    fun band(index: Int, count: Int): Color {
        if (count <= 1 || index <= 0 || stops.size < 2) return stops[0]
        val t = (index.toFloat() / maxOf(count - 1, 7)).coerceAtMost(1f) * (stops.size - 1)
        val i = minOf(t.toInt(), stops.size - 2)
        return lerp(stops[i], stops[i + 1], t - i)
    }

    companion object {
        val HEAT get() = Themes.current.heat
        val OCEAN get() = Themes.current.ocean
        val PLUM get() = Themes.current.plum
    }
}

/** Which run of bands this part of the app uses. */
val LocalPalette = compositionLocalOf { Palette.HEAT }

/** Schibsted Grotesk, in the four weights the app uses (anything else snaps to the nearest). */
val AppFont = FontFamily(
    Font(R.font.schibsted_grotesk_regular, FontWeight.Normal),
    Font(R.font.schibsted_grotesk_semibold, FontWeight.SemiBold),
    Font(R.font.schibsted_grotesk_bold, FontWeight.Bold),
    Font(R.font.schibsted_grotesk_black, FontWeight.Black),
)

/**
 * The theme's colours in this phone's appearance (dark, light or glass); the colour is in the rows. One typeface
 * everywhere: Schibsted Grotesk (SIL Open Font License), bundled so it looks the same as on the iPhone.
 */
@Composable
fun DoYourWorkTheme(content: @Composable () -> Unit) {
    val ctx = LocalContext.current
    LaunchedEffect(Unit) { Themes.load(ctx) }
    val t = Themes.current
    // The appearance's colours, so dialogs, fields and switches follow it too. Glass's dialogs sit on
    // the plain (unwashed) background, since a dialog has no wash behind it.
    val bg = Bg
    val text = Ink
    val muted = Done
    val surface = if (Themes.isGlass) lerp(bg, Color.White, 0.1f) else SurfaceDark
    val scheme = (if (Themes.isLight) lightColorScheme(
        primary = Accent, onPrimary = t.ink, secondary = Accent,
        background = bg, onBackground = text, surface = bg, onSurface = text,
        surfaceVariant = Color(0xFFE6E6EB), onSurfaceVariant = muted, outline = muted,
        surfaceContainer = Color.White, surfaceContainerHigh = Color.White, surfaceContainerHighest = Color(0xFFF7F7FA),
        surfaceContainerLow = Color.White, secondaryContainer = Color(0xFFE6E6EB), onSecondaryContainer = text, error = Bad,
    ) else darkColorScheme(
        primary = Accent, onPrimary = t.ink, secondary = Accent,
        background = bg, onBackground = text, surface = bg, onSurface = text,
        surfaceVariant = surface, onSurfaceVariant = muted, outline = muted,
        surfaceContainer = surface, surfaceContainerHigh = lerp(bg, text, 0.1f), surfaceContainerHighest = lerp(bg, text, 0.13f),
        secondaryContainer = lerp(bg, text, 0.16f), onSecondaryContainer = text, error = Bad,
    ))
    // The status bar and the system's controls follow: dark icons in light, light ones otherwise.
    val light = Themes.isLight
    val activity = ctx as? androidx.activity.ComponentActivity
    androidx.compose.runtime.DisposableEffect(light, activity) {
        val clear = android.graphics.Color.TRANSPARENT
        val style = if (light) androidx.activity.SystemBarStyle.light(clear, clear) else androidx.activity.SystemBarStyle.dark(clear)
        activity?.enableEdgeToEdge(statusBarStyle = style, navigationBarStyle = style)
        onDispose { }
    }
    val ty = Typography()
    fun TextStyle.m() = copy(fontFamily = AppFont)
    val type = Typography(
        displayLarge = ty.displayLarge.m(), displayMedium = ty.displayMedium.m(), displaySmall = ty.displaySmall.m(),
        headlineLarge = ty.headlineLarge.m(), headlineMedium = ty.headlineMedium.m(), headlineSmall = ty.headlineSmall.m(),
        titleLarge = ty.titleLarge.m(), titleMedium = ty.titleMedium.m(), titleSmall = ty.titleSmall.m(),
        bodyLarge = ty.bodyLarge.m(), bodyMedium = ty.bodyMedium.m(), bodySmall = ty.bodySmall.m(),
        labelLarge = ty.labelLarge.m(), labelMedium = ty.labelMedium.m(), labelSmall = ty.labelSmall.m(),
    )
    val fb = remember { Feedback(ctx.applicationContext) }
    // The default bands follow the theme; a part of the app can still ask for another run (admin, dares).
    CompositionLocalProvider(LocalFeedback provides fb, LocalPalette provides t.heat) {
        MaterialTheme(colorScheme = scheme, typography = type, content = content)
    }
}
