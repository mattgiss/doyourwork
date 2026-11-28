package com.doyourwork.app.ui

import android.Manifest
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.ImageDecoder
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import com.doyourwork.app.engine.ProfilePhoto
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.ByteArrayOutputStream
import java.io.File

/**
 * Turns a picture into a profile photo: the middle square, scaled to [ProfilePhoto.SIDE] on each
 * side, as a JPEG whose quality starts at 80 and drops by 10 until its base64 fits in
 * [ProfilePhoto.MAX_BASE64]. Only the pixels are kept: a fresh JPEG has no location or other
 * details, and the original isn't saved. Null if even the lowest quality is too big.
 */
fun profilePhoto(source: Bitmap): String? {
    val side = minOf(source.width, source.height)
    if (side <= 0) return null
    val square = Bitmap.createBitmap(source, (source.width - side) / 2, (source.height - side) / 2, side, side)
    val scaled = Bitmap.createScaledBitmap(square, ProfilePhoto.SIDE, ProfilePhoto.SIDE, true)
    var quality = 80
    while (quality > 0) {
        val out = ByteArrayOutputStream()
        scaled.compress(Bitmap.CompressFormat.JPEG, quality, out)
        val b64 = android.util.Base64.encodeToString(out.toByteArray(), android.util.Base64.NO_WRAP)
        if (b64.length <= ProfilePhoto.MAX_BASE64) return b64
        quality -= 10
    }
    return null
}

/** Reads a picture the camera or the photo library handed over, turned the right way up and not much bigger than needed. */
private fun readPicture(ctx: Context, uri: Uri): Bitmap? = runCatching {
    ImageDecoder.decodeBitmap(ImageDecoder.createSource(ctx.contentResolver, uri)) { decoder, info, _ ->
        decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
        // A camera's 12 megapixels aren't needed for 192 × 192: decode at a few times that.
        val short = minOf(info.size.width, info.size.height)
        val want = ProfilePhoto.SIDE * 3
        if (short > want) {
            val f = want.toFloat() / short
            decoder.setTargetSize((info.size.width * f).toInt().coerceAtLeast(1), (info.size.height * f).toInt().coerceAtLeast(1))
        }
    }
}.getOrNull()

/** The two ways to get a photo, for the profile card. */
class PhotoTaker(val selfie: () -> Unit, val library: () -> Unit)

/**
 * The system photo picker for "Choose a photo", and the camera (asking for the front one) for
 * "Take a selfie". The camera writes to a file in the app's cache, which is deleted once read.
 * [onPhoto] gets the finished base64 JPEG; [onProblem] a sentence to show when it didn't work.
 */
@Composable
fun rememberPhotoTaker(onPhoto: (String) -> Unit, onProblem: (String) -> Unit): PhotoTaker {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    val onPhoto by rememberUpdatedState(onPhoto)
    val onProblem by rememberUpdatedState(onProblem)
    // Survives the camera app pushing this one out of memory.
    var pending by rememberSaveable { mutableStateOf<String?>(null) }

    fun use(uri: Uri, cleanUp: () -> Unit = {}) {
        scope.launch {
            val photo = withContext(Dispatchers.Default) { readPicture(ctx, uri)?.let(::profilePhoto) }
            cleanUp()
            if (photo != null) onPhoto(photo) else onProblem("That picture couldn't be used. Try another one.")
        }
    }

    val pick = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri -> if (uri != null) use(uri) }
    val camera = rememberLauncherForActivityResult(FrontCamera()) { ok ->
        val path = pending ?: return@rememberLauncherForActivityResult
        pending = null
        val file = File(path)
        if (ok && file.length() > 0) use(Uri.fromFile(file)) { file.delete() } else file.delete()
    }
    fun openCamera() {
        val dir = File(ctx.cacheDir, "selfies").apply { mkdirs() }
        val file = File(dir, "selfie.jpg").apply { delete() }
        val uri = FileProvider.getUriForFile(ctx, "${ctx.packageName}.photos", file)
        pending = file.path
        try { camera.launch(uri) } catch (e: ActivityNotFoundException) {
            pending = null; onProblem("There's no camera app on this phone to take a selfie with.")
        }
    }
    // The app holds the camera permission for scanning codes, so the camera app needs it granted too.
    val askCamera = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted) openCamera() else onProblem("To take a selfie, let DOYOURWORK use the camera in Settings.")
    }
    return remember(ctx) {
        PhotoTaker(
            selfie = {
                if (ContextCompat.checkSelfPermission(ctx, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) openCamera()
                else askCamera.launch(Manifest.permission.CAMERA)
            },
            library = { pick.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)) },
        )
    }
}

/** The camera, asked to start on the front lens. Camera apps treat these as hints; most follow them. */
private class FrontCamera : ActivityResultContracts.TakePicture() {
    override fun createIntent(context: Context, input: Uri): Intent = super.createIntent(context, input).apply {
        putExtra("android.intent.extras.CAMERA_FACING", 1)
        putExtra("android.intent.extras.LENS_FACING_FRONT", 1)
        putExtra("android.intent.extra.USE_FRONT_CAMERA", true)
    }
}
