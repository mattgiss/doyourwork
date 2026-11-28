# The whiteboard redesign

A new layout for both apps, sketched on a whiteboard in November 2026: the family as photo tiles,
and four pages you swipe between instead of buttons and pushed screens. Both apps follow this
document; where it says something, both do exactly that.

## The pages

Second round (late November 2026): the chores page is gone, the footer is an iOS 27-style tab
bar, and there's a choice of dark, light or glass.

One screen with a heading at the top and **three pages** below it that you swipe sideways
between: **family · feed · settings**. The app opens on **family**. Tapping a family tile opens
that person's **profile** over the pages.

- **Heading.** "doyourwork" in Pacifico (the font the icon's lettering comes from; bundled, SIL
  Open Font License), filled with the heat gradient left to right (`#FF3B2F` → `#E2751C` →
  `#EDB82A`), with a thin underline in the theme's muted colour below it. It stays put while the
  pages move.
- **Tab bar**, floating over the bottom of the pages, as iOS 27 draws it:
  - A pill holding the three pages, each an icon over its name ("Family", "Feed", "Settings";
    icons: three people, a list, a gear). The current one sits on a **darker** bubble (the page
    background in dark, `#E6E6EB` in light, black at 28% in glass) with its icon and name in the
    theme's main colour; the others are in the text colour. Tapping one goes to that page.
  - The pill itself is **lighter** than the page: in dark, the background mixed 16% towards the
    text colour, with a faint outline and a shadow; white with a soft shadow in light; frosted
    glass in glass.
  - Beside the pill, a round button of the same fill with a lightning bolt in the main colour:
    **Make a dare**, opening the dares screen. Only on a linked phone that knows whose it is
    (dares need two phones); otherwise there's no round button.
  - Pages leave room at the bottom so their last item scrolls out from under the bar.
- **Style.** Rounded tiles and cards (corner radius 18 for tiles, 22 for cards) with gaps between
  them, like iOS. Nothing touches.

### family

- The people who do chores, as tiles in a grid, in family order, **as big as the page allows**:
  one person fills it, and the tiles shrink as more join (`FamilyGrid` in the core, the same on
  Android). Every number of columns up to 6 is tried and the one giving the biggest avatars wins
  (fewer columns on a tie); a tile is never taller than 1.4 times its width. The avatar is
  min(80% of the tile's width, the tile's height − 64 − 8% of it). Once avatars would be smaller
  than 84 points, the tiles are small instead (3 across, or one per 120 points up to 6, each 1.25
  times as tall as wide) and the page scrolls. The name is 15 points times a scale, and the streak
  badge is scaled by it, where scale = avatar ÷ 110, kept between 1 and 1.8.
- A tile holds their **avatar** (below), their shown name under it, and their streak under the
  name: the DYW mark (the icon's lettering) and "×N", N being their streak in days. **Everyone
  shows a streak**, so they line up at a glance; ×0 is drawn at 40% opacity.
- Tapping a tile opens that person's **profile**.
- Below the grid, on a linked phone: "This is <name>'s phone." or, when it hasn't been set, the
  "Whose phone is this?" row of names.
- The weekly standings and the 30-day log are gone from view (the data behind them, streaks and
  points, still drives everything).

### feed

- On a linked phone, the dares first: the "Make a dare · N left today" button and yesterday's dares
  revealed.
- Then what everyone has done, newest first, over the last 7 days, grouped under "Today",
  "Yesterday" and the weekday name. Each item: the person's avatar (small, no border) on the left,
  their shown name in bold with the chore name after it ("**Mateo** load dishwasher"), and under that
  the time and the chore's status: "waiting", "approved" or "turned down". At most 100 items.
- Empty: "Nothing done yet this week. Chores show up here as they're sent in."

### A profile

Opened from a family tile: pushed over the pages on a phone (the tab bar goes with it), in the
right-hand pane on a wide screen.

- A rounded card in the theme's main colour at the top: a back chevron, their avatar with its
  border, their name (tap to rename) with "v2.4 · N points this week", their xp bar with the
  streak and what's left to the next version.
- On that card's right:
  - **Dare** (a bolt and "Dare"), opening the dares screen with them already picked. Only when
    you can dare: a linked phone that knows whose it is, and not on your own profile.
  - A **camera** button, "Photo and border", that goes to settings with this person chosen.
    Only on your own profile (a linked phone that knows whose it is), or on anyone's on a phone
    that isn't someone's.
- Below, their day exactly as before (pick a card, check it off, send it, games, bonus round),
  with the chores as **rounded tiles in a grid, 2 across**, each with the chore name and its
  minutes (or its verdict once sent). A picked tile (when picking) or an unchecked one (on a card)
  is lit in the theme's main colour; the others are on the surface colour. "!" and "!!" for
  neglected chores stay. The buttons stay at the bottom.

### settings

Rounded cards, top to bottom:

1. **Profile.** For the person chosen from a profile's camera button, else whose phone this is,
   else "Whose profile?" over the people as small avatar tiles. Their avatar large, with their
   border. Buttons: "Take a selfie", "Choose a photo", "Remove photo" (only when there is one),
   "Use a character instead" (the character picker; picking one takes the photo off). Their name,
   tap to rename. "Switch person".
2. **Borders.** Every border as a small tile showing it around their avatar. Unlocked ones can be
   tapped to wear; the one worn is outlined. Locked ones are faded with "at N points". Above the
   tiles: "N points so far. M more for <next border>." (or "Every border unlocked." at the end).
3. **Look.**
   - Three buttons side by side, one lit: **Dark** (a moon), **Light** (a sun), **Glass** (a
     drop). See Appearance.
   - Theme (the existing theme picker) and sound on/off.
4. **Admin.** One row, "Admin", with "N waiting" when chores are waiting for approval. It opens
   the existing admin area (code, or Face ID / fingerprint), which keeps approvals, players, chores
   and the device settings.
5. **About.** Sync status on a linked phone ("Everything here stays on this device." otherwise) and
   the version.

### Appearance

Chosen per phone, kept on the phone, on top of whichever theme is picked. The theme's main and
band colours don't change; the background, text and surfaces do:

| | background | text | muted text | tiles and cards |
|---|---|---|---|---|
| Dark | the theme's background | the theme's text | the theme's muted | the theme's surface |
| Light | `#F2F2F7` mixed 1.5% towards the theme's main colour | `#141416` | `#6E6E73` | white, with a soft shadow |
| Glass | the theme's background mixed 35% towards black, under a wash of the theme's colours | the theme's text | the theme's muted | frosted glass (white at 13% where a real blur isn't possible), with a faint white outline |

- **The wash** (glass only), behind every page: the band colours' first stop at 75% in the top
  left, fading through the background to the last stop at 55% in the bottom right, with a glow of
  the theme's muted colour at 45% from the bottom left.
- The status bar and system controls follow: light in Light, dark otherwise.

### Wide screens

On a tablet or an unfolded foldable (iOS: regular width; Android: the same test the two-pane
layout uses today), **family** stays on the left as a pane, sized and split at the fold as the
home list was, and the right pane holds feed · settings with its own tab bar, or the profile of
whoever was tapped.

## Avatars

A person's avatar is their photo cropped to a circle; with no photo, their character on a circle
of the theme's main colour. Their border is drawn behind it.

The drawings are on a 100 × 100 square: the avatar is the circle at (50, 58), radius 30, and the
border's layers are painted in order **behind** it, each filled even-odd, in its own colour, or
the theme's text colour when the layer has none (so the Ring shows against a character on the
theme's main colour). The tile shows the whole square.

## Borders

Written for both apps by `node tools/borders/build.mjs` (`BorderArt.swift`, `BorderArt.kt`, and a
sheet at `launch/brand/borders.svg`). A border unlocks once the person's total xp (the number their
version comes from) reaches its points:

| id | name | points |
|---|---|---|
| none | No border | 0 |
| ring | Ring | 0 |
| puppy | Puppy ears | 50 |
| bunny | Bunny ears | 100 |
| panda | Panda ears | 150 |
| cat | Cat ears | 250 |
| mouse | Mouse ears | 350 |
| hearts | Hearts | 500 |
| fox | Fox ears | 650 |
| bear | Bear ears | 800 |
| frog | Frog eyes | 1000 |
| crown | Crown | 1200 |
| flowers | Flower crown | 1500 |
| flames | Flames | 1800 |
| party | Party hat | 2100 |
| stars | Stars | 2500 |
| unicorn | Unicorn horn | 3000 |
| horns | Little horns | 3500 |
| halo | Halo | 5000 |

Only unlocked borders can be chosen. A border chosen elsewhere that this phone doesn't know, or
hasn't been earned, still shows if it's known; an unknown one shows as none.

## Photos

- Taken with the front camera or picked from the photo library, cropped to the middle square,
  scaled to 192 × 192 and saved as JPEG, lowering the quality from 0.8 in steps of 0.1 until the
  base64 is at most 24,000 characters. Nothing else about the photo is kept (no location, no
  original).
- Saved with the person on the phone. On a linked phone it goes to the family's other phones like
  the rest of the family's data: as a state entry sealed with the family key, so the server can't
  see it.
- A photo is shown only if it's base64 of a JPEG (starts FF D8) within the limit; anything else is
  shown as no photo.

## Sync and backups

Two new `family_state` keys, written for every member like `character|<id>` (an empty list when
there's none, so removing reaches the other phones), and emptied for removed members:

| key | items |
|---|---|
| `photo\|<id>` | one item: the photo's base64 JPEG |
| `border\|<id>` | one item: the border id |

Older app versions ignore both. Backups gain optional `photo` and `border` on each member.
