#!/usr/bin/env python3
"""Cuts "The Dishes" ad into one MP4 from the ElevenLabs clips, voiceover, effects and music.

    python3 tools/voiceover/cut_ad.py

Cut like a cartoon, not a storybook: each shot lasts as long as its motion and no longer (no frozen
frames), narration runs on across cuts, and captions appear with their line and leave at the cut.
Lip-synced talking shots keep their own timing so mouths stay on the words.

Reads launch/marketing/{clips,voiceover,sfx}/ and the Play Store phone screenshots, writes
launch/marketing/the-dishes.mp4 (1280x720, 24 fps). Needs ffmpeg and swiftc.
"""
import array, subprocess, tempfile, pathlib

ROOT = pathlib.Path(__file__).resolve().parents[2]
M = ROOT / "launch/marketing"
CLIPS, VO, SFX = M / "clips", M / "voiceover", M / "sfx"
REC = M / "screen/take1-cfr.mp4"   # full-resolution screen recording of the app (iPhone simulator), at a steady 24 fps
FONT = str(ROOT / "fonts/SchibstedGrotesk-Black.ttf")
OUT = M / "the-dishes.mp4"
PLUM = "0x1D1530"
TMP = pathlib.Path(tempfile.mkdtemp(prefix="dishes-"))

TEMPO = 1.12   # narration speed-up
LEAD = 0.2     # silence before a talking shot's line
GAP = 0.12     # between narration lines
TAIL = 0.25    # after a talking shot's line, before the cut
MAX_STRETCH = 1.25  # the most a shot may be slowed to keep up with its narration


def run(*args):
    subprocess.run(["ffmpeg", "-v", "error", "-y", *args], check=True)


def duration(path):
    return float(subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(path)],
                                capture_output=True, text=True).stdout)


def onset(path, threshold=0.03, rate=16000):
    """Seconds until the first sample louder than `threshold` (where speech starts)."""
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", str(path), "-ac", "1", "-ar", str(rate), "-f", "s16le", "-"],
                         capture_output=True, check=True).stdout
    samples = array.array("h", raw)
    return next((i / rate for i, v in enumerate(samples) if abs(v) > threshold * 32768), 0.0)


def prepare_line(name):
    """A voice line with its silence trimmed at both ends, sped up a little."""
    out = TMP / f"vo-{name}.wav"
    trim = "silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.03"
    run("-i", str(VO / f"{name}.mp3"), "-af", f"{trim},areverse,{trim},areverse,atempo={TEMPO}", str(out))
    return out


# ---- caption pills, drawn by textcard.swift (this ffmpeg has no text filter) ----
TEXTCARD = TMP / "textcard"
subprocess.run(["swiftc", "-O", str(ROOT / "tools/voiceover/textcard.swift"), "-o", str(TEXTCARD)], check=True)
_n = [0]


def png(text, size=44, style="card"):
    _n[0] += 1
    out = TMP / f"text{_n[0]}.png"
    subprocess.run([str(TEXTCARD), FONT, str(size), style, str(out), text], check=True)
    return out


# ---- the shots, in order ----
# clip: the file in clips/ (a "-lipsync" version is used when there is one). pieces: (from, to, speed)
# parts of the clip to play, in order; speed > 1 zips through a stretch with nothing happening.
# talk: a lip-synced line spoken on screen, `lead` seconds into the shot. lines: narration that
# starts in this shot (it may run on into the next), each with the caption shown while it plays
# (until the cut). sfx: (effect, seconds into the shot).
SHOTS_LIST = [
    dict(clip="1a-call", talk="dad1", lead=0.3),
    dict(clip="1b-bed", talk="mom1", lead=0.3),
    # The car passes the window 1.5-2.1 s in and Dad yells from 3.9 s: zip through the stare between
    # so the horn, starting as the car goes by, lands on the yell.
    # 2-kitchen-gag (made below) moves the passing car to the moment Dad opens his mouth to curse,
    # 4.1 s into the clip. That is 2.0 s into this shot; the horn peaks 0.65 s after it starts.
    dict(clip="2-kitchen-gag", pieces=[(0.9, 2.1, 1.0), (2.1, 3.6, 5.0), (3.6, 5.05, 1.0)], sfx=[("honk", 2.0 - 0.75)]),
    dict(clip="3a-mom", talk="mom2", lead=LEAD, lines=[("n2", "Say it once")]),
    # Cut when the boy walks off with the bag; the narrator's line carries on over the next shot.
    dict(clip="3b-trash", talk="dad2", lead=LEAD, lines=[("n3", "Stop getting asked")]),
    dict(clip="4-tablet", lines=[("n4", "One phone, the whole family")]),
    # The real app, from the screen recording: (from, to) parts with the waits between taps cut out.
    dict(rec=[(12.0, 13.2), (18.7, 19.4), (25.2, 26.0)], words=["Pick 25 minutes", "of chores"],
         lines=[("n5", None)]),
    dict(rec=[(35.4, 37.0), (42.8, 43.6), (52.2, 56.0)],
         words=["Send it in", "and a game", "unlocks"], lines=[("n5b", None)]),
    dict(rec=[(105.4, 106.4), (114.1, 114.8), (115.8, 117.2), (118.3, 119.6)], words=["A parent", "approves"],
         lines=[("n6", None)]),
    dict(clip="5-bowling", sfx=[("strike", 0)], lines=[("n7", None), ("n8", "Download"), ("n9", "Add your family"), ("n10", "Play")]),
    dict(clip="6-dares", lines=[("n11a", None), ("pause", 0.45), ("n11b", "Dare each other"), ("n12", "Revealed at midnight")]),
    dict(clip="7-finale", lines=[("n13", None)]),
    dict(end=True, lines=[("n14", None)], sfx=[("chime", 0)]),
]
SFX_VOL = {"honk": 1.4, "strike": 0.7, "pop": 0.5, "chime": 0.5}

# ---- the kitchen gag: the car in the clip passes the window 2 s before Dad yells. Paint that pane
# of the window empty (a frame from after the car), then play the car across it at the yell. ----
PANE = "215:170:945:140"   # w:h:x:y, the window pane right of the dish tower; nothing else moves there
CAR_FROM, CAR_TO, CURSE = 1.35, 2.35, 4.1
kitchen = CLIPS / "2-kitchen.mp4"
run("-i", str(kitchen), "-ss", "2.6", "-i", str(kitchen), "-ss", str(CAR_FROM), "-t", str(CAR_TO - CAR_FROM), "-i", str(kitchen),
    "-filter_complex",
    f"[1:v]trim=end_frame=1,crop={PANE},loop=-1:size=1,setpts=N/24/TB[plate];"
    f"[2:v]crop={PANE},setpts=PTS-STARTPTS+{CURSE - 0.45:.2f}/TB[car];"
    f"[0:v][plate]overlay=x=945:y=140:enable='between(t,{CAR_FROM - 0.05},{CAR_TO + 0.05})'[a];"
    f"[a][car]overlay=x=945:y=140:eof_action=pass:enable='between(t,{CURSE - 0.45:.2f},{CURSE + 0.55:.2f})',format=yuv420p[out]",
    "-map", "[out]", "-an", "-t", str(duration(kitchen)), str(CLIPS / "2-kitchen-gag.mp4"))

voice = {}
for sh in SHOTS_LIST:
    for name in ([sh["talk"]] if sh.get("talk") else []) + [n for n, _ in sh.get("lines", []) if n != "pause"]:
        voice[name] = prepare_line(name)


def source(sh):
    synced = CLIPS / f"{sh['clip']}-lipsync.mp4"
    return synced if synced.exists() else CLIPS / f"{sh['clip']}.mp4"


# ---- plan the timeline: shot lengths, when each line is heard, captions ----
cues, captions, plan = [], [], []   # cues: (audio, at, volume); captions: (png, start, end)
t0, cursor = 0.0, 0.0               # cursor: when the narration is free to speak again
for sh in SHOTS_LIST:
    lines_at = []
    if sh.get("talk"):
        # On-screen dialogue starts at the shot's lead; it waits for nothing (nothing runs over it).
        at = t0 + sh["lead"]
        cues.append((voice[sh["talk"]], at, 1.0))
        cursor = at + duration(voice[sh["talk"]]) + GAP
    for name, caption in sh.get("lines", []):
        if name == "pause":
            cursor += caption
            continue
        at = max(cursor, t0 + LEAD)
        cues.append((voice[name], at, 1.0))
        lines_at.append((at, caption))
        cursor = at + duration(voice[name]) + GAP
    for name, at in sh.get("sfx", []):
        cues.append((SFX / f"{name}.mp3", t0 + at, SFX_VOL[name]))

    if "clip" in sh:
        src = source(sh)
        pieces = sh.get("pieces") or [(0.0, duration(src), 1.0)]
        motion = sum((b - a) / s for a, b, s in pieces)
        if sh.get("talk"):
            # A talking shot alone cuts right after its line; with narration it plays its motion out.
            said = sh["lead"] + duration(voice[sh["talk"]]) + TAIL
            length = motion if sh.get("lines") else min(motion, said)
            heard = sh["lead"] + onset(voice[sh["talk"]])
            shift = heard - onset(src)      # >0: hold the first frame that long; <0: skip into the clip
            stretch = 1.0
        else:
            # As long as the motion, slowed a little (or, past that, held briefly) so the last line
            # that starts in this shot gets a second on screen before the cut.
            need = (lines_at[-1][0] - t0 + 1.0) if lines_at else 0.0
            stretch = min(MAX_STRETCH, max(1.0, need / motion))
            length, shift = max(motion * stretch, need), 0.0
    elif "rec" in sh:
        motion = sum(b - a for a, b in sh["rec"])
        need = (cursor - GAP) - t0 + 0.2            # until its line ends
        stretch = min(MAX_STRETCH, max(1.0, need / motion))
        length = max(motion * stretch, need)
    else:
        length = (cursor - GAP) - t0 + 0.6          # end card holds until the last line ends
    length = round(length, 3)
    plan.append((sh, length, locals().get("shift", 0.0) if "clip" in sh else 0.0,
                 locals().get("stretch", 1.0) if ("clip" in sh or "rec" in sh) else 1.0))
    # Captions: each shows from its line until the next caption or the cut, whichever comes first.
    for k, (at, caption) in enumerate(lines_at):
        if not caption:
            continue
        nxt = next((a for a, c in lines_at[k + 1:] if c), t0 + length)
        if at < t0 + length - 0.3:
            captions.append((png(caption, 60, "pill"), at, min(nxt, t0 + length)))
    print(f"{t0:5.1f}s  {sh.get('clip') or ('app: ' + sh['words'][0] if 'rec' in sh else 'end card'):20} {length:4.1f}s"
          + "".join(f"  [{n} @{a - t0:+.1f}]" for (n, _), (a, _) in zip([l for l in sh.get('lines', []) if l[0] != "pause"], lines_at)))
    t0 += length
    cursor = max(cursor, t0 + 0.0) if sh.get("end") else cursor
total = t0


# ---- render each shot ----
def render_clip(sh, length, shift, stretch, out):
    src = source(sh)
    pieces = sh.get("pieces") or [(0.0, duration(src), 1.0)]
    if shift < 0:  # skip into the clip
        pieces = [(a - shift if i == 0 else a, b, s) for i, (a, b, s) in enumerate(pieces)]
    parts = []
    for i, (a, b, s) in enumerate(pieces):
        parts.append(f"[0:v]trim=start={a:.3f}:end={b:.3f},setpts=(PTS-STARTPTS)/{s}*{stretch:.3f},"
                     f"scale=1280:720,fps=24,format=yuv420p[p{i}]")
    joined = "".join(f"[p{i}]" for i in range(len(parts)))
    hold = max(0.0, shift)
    chain = ";".join(parts) + f";{joined}concat=n={len(parts)}:v=1:a=0," \
        f"tpad=start_mode=clone:start_duration={hold:.3f}:stop_mode=clone:stop_duration={length:.3f}," \
        f"trim=duration={length:.3f}[out]"
    run("-i", str(src), "-an", "-filter_complex", chain, "-map", "[out]", "-t", f"{length:.3f}", str(out))


def render_rec(sh, length, stretch, out):
    """The app recording, full resolution, as a phone on the plum backdrop with big words beside it."""
    words = [png(w, 72, "white") for w in sh["words"]]
    parts = [f"[0:v]trim=start={a:.3f}:end={b:.3f},setpts=(PTS-STARTPTS)*{stretch:.3f},fps=24,"
             f"scale=-2:664:flags=lanczos,format=yuv420p[p{i}]" for i, (a, b) in enumerate(sh["rec"])]
    chain = ";".join(parts) + f";{''.join(f'[p{i}]' for i in range(len(parts)))}concat=n={len(parts)}:v=1:a=0," \
        f"tpad=stop_mode=clone:stop_duration={length:.3f},trim=duration={length:.3f}," \
        f"pad=iw+12:ih+12:6:6:color=0x2B2340[ph];" \
        f"[1:v][ph]overlay=x=W-w-120:y=(H-h)/2[b0]"
    inputs = ["-i", str(REC), "-f", "lavfi", "-i", f"color=c={PLUM}:s=1280x720:d={length:.3f}:r=24"]
    top = 360 - len(words) * 46
    for j, w in enumerate(words):
        inputs += ["-loop", "1", "-t", f"{length:.3f}", "-i", str(w)]
        chain += f";[b{j}][{2 + j}:v]overlay=x=110:y={top + j * 92}[b{j + 1}]"
    # A steady push-in so the shot keeps moving while the screen waits between taps.
    frames = max(1, int(length * 24))
    chain += (f";[b{len(words)}]scale=2560:1440,zoompan=z='1+0.08*on/{frames}':x='iw/2-(iw/zoom/2)':"
              f"y='ih/2-(ih/zoom/2)':d=1:s=1280x720:fps=24,format=yuv420p[out]")
    run(*inputs, "-filter_complex", chain, "-map", "[out]", "-t", f"{length:.3f}", str(out))


def render_end(length, out):
    line1, line2 = png("Free on iPhone and Android", 52, "ink"), png("doyourwork.today", 40, "orange")
    chain = ("[1:v]scale=360:-1[logo];[0:v][logo]overlay=x=(W-w)/2:y=70[a];[a][2:v]overlay=x=(W-w)/2:y=460[b];"
             f"[b][3:v]overlay=x=(W-w)/2:y=545,scale=2560:1440,zoompan=z='1+0.05*on/{max(1, int(length * 24))}':"
             "x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=1:s=1280x720:fps=24,fade=t=in:st=0:d=0.25,format=yuv420p[out]")
    run("-f", "lavfi", "-i", f"color=c=white:s=1280x720:d={length:.3f}:r=24",
        "-loop", "1", "-t", f"{length:.3f}", "-i", str(CLIPS / "dyw-mark.png"),
        "-loop", "1", "-t", f"{length:.3f}", "-i", str(line1),
        "-loop", "1", "-t", f"{length:.3f}", "-i", str(line2),
        "-filter_complex", chain, "-map", "[out]", "-t", f"{length:.3f}", str(out))


segments = []
for i, (sh, length, shift, stretch) in enumerate(plan):
    out = TMP / f"seg{i}.mp4"
    if "clip" in sh:
        render_clip(sh, length, shift, stretch, out)
    elif "rec" in sh:
        render_rec(sh, length, stretch, out)
    else:
        render_end(length, out)
    segments.append(out)

listing = TMP / "list.txt"
listing.write_text("".join(f"file '{p}'\n" for p in segments))
joined = TMP / "joined.mp4"
run("-f", "concat", "-safe", "0", "-i", str(listing), "-c", "copy", str(joined))

# Captions go on over the whole picture, at their absolute times.
inputs, chain, cur = ["-i", str(joined)], [], "0:v"
for k, (img, start, end) in enumerate(captions):
    inputs += ["-loop", "1", "-t", f"{total:.3f}", "-i", str(img)]
    chain.append(f"[{cur}][{k + 1}:v]overlay=x=(W-w)/2:y=H-h-48:enable='between(t,{start:.3f},{end:.3f})'[v{k}]")
    cur = f"v{k}"
picture = TMP / "picture.mp4"
run(*inputs, "-filter_complex", ";".join(chain) + f";[{cur}]format=yuv420p[out]", "-map", "[out]",
    "-c:v", "libx264", "-preset", "veryfast", "-crf", "16", "-t", f"{total:.3f}", str(picture))

# Sound: dialogue, narration and effects at their times, over a quiet music bed.
inputs, chains, labels = ["-i", str(picture), "-i", str(SFX / "music.mp3")], [], []
for k, (path, at, vol) in enumerate(cues, start=2):
    inputs += ["-i", str(path)]
    ms = int(at * 1000)
    chains.append(f"[{k}:a]aformat=channel_layouts=stereo,volume={vol},adelay={ms}|{ms}[a{k}]")
    labels.append(f"[a{k}]")
chains.append(f"[1:a]volume=0.14,afade=t=out:st={total - 1.5:.2f}:d=1.5[bed]")
chains.append(f"[bed]{''.join(labels)}amix=inputs={len(labels) + 1}:normalize=0,alimiter=limit=0.95,atrim=0:{total:.2f}[mix]")
run(*inputs, "-filter_complex", ";".join(chains), "-map", "0:v", "-map", "[mix]",
    "-c:v", "libx264", "-preset", "medium", "-crf", "20", "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart",
    "-t", f"{total:.2f}", str(OUT))
print(f"Wrote {OUT.relative_to(ROOT)} ({total:.1f} s)")
