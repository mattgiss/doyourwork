package com.doyourwork.app.ui

import android.graphics.BitmapFactory
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathFillType
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.Dp
import com.doyourwork.app.engine.Borders
import com.doyourwork.app.engine.Characters
import com.doyourwork.app.engine.PlayerCharacter
import com.doyourwork.app.engine.ProfileBorder
import com.doyourwork.app.engine.ProfilePhoto
import com.doyourwork.app.model.Player

/** A drawing's path, read with the same reader the characters use, filled even-odd. */
private fun evenOdd(path: String): Path = Path().apply {
    fillType = PathFillType.EvenOdd
    for (s in Characters.steps(path)) when (s) {
        is Characters.Step.Move -> moveTo(s.x, s.y)
        is Characters.Step.Line -> lineTo(s.x, s.y)
        is Characters.Step.Quad -> quadraticTo(s.cx, s.cy, s.x, s.y)
        is Characters.Step.Cubic -> cubicTo(s.c1x, s.c1y, s.c2x, s.c2y, s.x, s.y)
        Characters.Step.Close -> close()
    }
}

/** A photo's base64 JPEG as an image, or null if it isn't one the apps show. */
private fun photoBitmap(base64: String?): ImageBitmap? {
    val b = ProfilePhoto.clean(base64) ?: return null
    return runCatching {
        val bytes = android.util.Base64.decode(b, android.util.Base64.DEFAULT)
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size)?.asImageBitmap()
    }.getOrNull()
}

/**
 * Someone's face: their photo cropped to a circle; with no photo, their character on a circle of
 * the theme's main colour. No border: for small places, like the feed.
 */
@Composable
fun AvatarCircle(player: Player?, character: PlayerCharacter?, size: Dp, modifier: Modifier = Modifier) {
    val photo = remember(player?.photo) { photoBitmap(player?.photo) }
    Box(modifier.size(size).clip(CircleShape).background(Themes.current.main), contentAlignment = Alignment.Center) {
        if (photo != null) Image(photo, contentDescription = null, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize())
        else if (character != null) CharacterIcon(character, size * 0.66f)
    }
}

/**
 * The avatar as a tile shows it: the whole 100 × 100 square, with their border painted behind the
 * circle at (50, 58), radius 30, each layer even-odd in its own colour or the theme's text colour.
 * [border] defaults to the one they show; pass one to preview it (the borders picker).
 */
@Composable
fun BorderedAvatar(
    player: Player?,
    character: PlayerCharacter?,
    modifier: Modifier = Modifier,
    border: ProfileBorder? = player?.let { Borders.shown(it) },
) {
    val layers = remember(border?.id) { border?.layers.orEmpty().map { (it.color?.let { c -> Color(c) }) to evenOdd(it.path) } }
    // A layer with no colour of its own (the Ring) takes the theme's text colour, so it shows against the main-colour circle.
    val plain = Ink
    BoxWithConstraints(modifier.aspectRatio(1f)) {
        val unit = maxWidth / Borders.SIZE
        Canvas(Modifier.fillMaxSize()) {
            scale(size.width / Borders.SIZE, pivot = Offset.Zero) {
                for ((color, path) in layers) drawPath(path, color ?: plain)
            }
        }
        val r = Borders.PHOTO_RADIUS
        AvatarCircle(player, character, unit * (r * 2),
            Modifier.offset(unit * (Borders.PHOTO_X - r), unit * (Borders.PHOTO_Y - r)))
    }
}
