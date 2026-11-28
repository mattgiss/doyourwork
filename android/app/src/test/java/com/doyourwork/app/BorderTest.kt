package com.doyourwork.app

import com.doyourwork.app.engine.AdminCode
import com.doyourwork.app.engine.Backup
import com.doyourwork.app.engine.Borders
import com.doyourwork.app.engine.Characters
import com.doyourwork.app.engine.ProfilePhoto
import com.doyourwork.app.model.Family
import com.doyourwork.app.model.FamilyState
import com.doyourwork.app.model.Player
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Base64

/** Borders, profile photos, and how both travel. The same as iOS's BorderTests. */
class BorderTest {
    /** A tiny but real JPEG header, as base64: enough for ProfilePhoto.clean. */
    private val jpeg = Base64.getEncoder().encodeToString(byteArrayOf(0xFF.toByte(), 0xD8.toByte(), 0xFF.toByte(), 0xE0.toByte(), 0, 0x10))

    @Test fun catalogue() {
        val ids = Borders.all.map { it.id }
        assertEquals("ids are unique", ids.size, ids.toSet().size)
        assertEquals("none", ids.first())
        assertEquals("listed in the order they unlock", Borders.all.map { it.unlockXp }.sorted(), Borders.all.map { it.unlockXp })
        assertTrue("one to wear from the start", Borders.all.any { it.unlockXp == 0 && it.layers.isNotEmpty() })
        // Every drawing parses with the same reader the characters use.
        for (b in Borders.all) for (l in b.layers) assertFalse(b.id, Characters.steps(l.path).isEmpty())
    }

    @Test fun unlocking() {
        val bunny = Borders.named("bunny")!!
        assertFalse(Borders.isUnlocked(bunny, bunny.unlockXp - 1))
        assertTrue(Borders.isUnlocked(bunny, bunny.unlockXp))
        val puppy = Borders.named("puppy")!!
        assertEquals("puppy", Borders.next(0)?.border?.id)
        assertEquals(puppy.unlockXp, Borders.next(0)?.pointsToGo)
        assertEquals("bunny", Borders.next(puppy.unlockXp)?.border?.id)
        assertEquals("panda", Borders.next(bunny.unlockXp)?.border?.id)
        assertNull(Borders.next(1_000_000))
        assertNull(Borders.named("from-a-newer-version"))
        assertNull(Borders.shown(Player("1", "a", border = "none")))
        assertEquals("halo", Borders.shown(Player("1", "a", border = "halo"))?.id)
    }

    @Test fun photoCleaning() {
        assertEquals(jpeg, ProfilePhoto.clean(jpeg))
        assertNull(ProfilePhoto.clean(""))
        assertNull(ProfilePhoto.clean("not base64!"))
        assertNull("only JPEGs", ProfilePhoto.clean(Base64.getEncoder().encodeToString(byteArrayOf(0x89.toByte(), 0x50, 0x4E, 0x47))))
        assertNull("too big to sync", ProfilePhoto.clean("A".repeat(ProfilePhoto.MAX_BASE64 + 4)))
    }

    @Test fun photoAndBorderSync() {
        val family = Family(
            members = listOf(Player("1", "mom", isAdmin = true, photo = jpeg, border = "hearts"), Player("2", "kid")),
            removed = setOf("3"))
        val state = FamilyState.encode(family)
        assertEquals(listOf(jpeg), state["photo|1"])
        assertEquals(listOf("hearts"), state["border|1"])
        // Written as empty, so taking a photo off reaches the other phones too.
        assertEquals(emptyList<String>(), state["photo|2"])
        assertEquals(emptyList<String>(), state["border|2"])
        assertEquals(emptyList<String>(), state["photo|3"])
        val back = FamilyState.decode(state, Family())
        assertEquals(family.members, back.members)
        // A phone that wrote something that isn't a photo: shown as no photo.
        val bad = state + ("photo|1" to listOf("garbage"))
        assertNull(FamilyState.decode(bad, family).members.first().photo)
        // Taking the photo off on another phone takes it off here.
        assertNull(FamilyState.decode(state + ("photo|1" to emptyList()), family).members.first().photo)
    }

    @Test fun backupKeepsPhotoAndBorder() {
        val p = Player("1", "mom", isAdmin = true, photo = jpeg, border = "crown")
        val code = AdminCode.make("2468", salt = "s")!!
        val family = Family(members = listOf(p), adminCodes = mapOf("1" to code))
        val b = Backup.decode(Backup.encode(Backup.make(family, emptyList(), emptyList(), emptyList(), emptyMap(), "android", "test", 0)))
        val back = Backup.replace(b).family.members.first()
        assertEquals(jpeg, back.photo)
        assertEquals("crown", back.border)
        // Merged into another family, the person keeps them too.
        val merged = Backup.merge(Family(), emptyList(), emptyList(), emptyMap(), b, java.time.ZoneId.of("UTC"), 0).family.members.first()
        assertEquals(jpeg, merged.photo)
        assertEquals("crown", merged.border)
    }
}
