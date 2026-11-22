// Records the lines for "The Dishes" ad (launch/marketing) with ElevenLabs, one MP3 per line.
//
//   npm run record            # every line
//   npm run record -- n3 n4   # just these lines
//
// Reads ELEVENLABS_API_KEY from the repo's .env.local (see package.json). Writes to
// launch/marketing/voiceover/<id>.mp3, which go into launch/marketing/the-dishes.html.
import { ElevenLabsClient } from "@elevenlabs/elevenlabs-js";
import { mkdirSync, writeFileSync } from "node:fs";

const VOICES = {
  narrator: "NQMJRVvPew6HsaebYnZj", // Cecily: warm, confident Black woman's voiceover voice (Voice Library)
  dad: "iP95p4xoKVk53GoZ742B",      // Chris: charming, down-to-earth (premade)
  mom: "6aDn1KB0hjpdcocrUkmq",      // Tiffany: relaxed, conversational (in this account)
};

// The words follow launch/marketing/dishes-ad-script.md. Tags in [brackets] steer the delivery
// on eleven_v4 and aren't spoken.
export const LINES = [
  ["dad1", "dad", "[mouth full of toothpaste] Wan' coffee, hon?"],
  ["mom1", "mom", "[sleepy, happy] Yes please!"],
  ["mom2", "mom", "[warm, matter-of-fact] Hey baby, dishwasher before dinner, okay?"],
  ["dad2", "dad", "[casual, then surprised] Hey bud, can you take out the tr... oh."],
  ["n1", "narrator", "[dry, amused] Every house has the dishes talk."],
  ["n2", "narrator", "Parents, say it once."],
  ["n3", "narrator", "Kids, stop getting asked to do what you were already gonna do."],
  ["n4", "narrator", "[warm] Meet Do Your Work. Everyone picks today's chores on one phone or tablet."],
  ["n5", "narrator", "Fill your card up to twenty-five minutes."],
  ["n6", "narrator", "A parent approves. Points go up."],
  ["n5b", "narrator", "[excited] Send it in, and a game unlocks."],
  ["n7", "narrator", "[playful] It's as simple as going bowling."],
  ["n8", "narrator", "Download the app."],
  ["n9", "narrator", "Put in a name for everyone."],
  ["n10", "narrator", "Then play. Do the chores already in there, or add your own."],
  ["n11", "narrator", "[conspiratorial] Got your own phones? Dare each other."],
  ["n11a", "narrator", "[conspiratorial] Got your own phones?"],
  ["n11b", "narrator", "[sly] Dare each other."],
  ["n12", "narrator", "Guess which chores someone will do. It's revealed after midnight."],
  ["n13", "narrator", "[satisfied] Clean sink. Hot coffee. Otter wins the week."],
  ["n14", "narrator", "Do Your Work. Free on iPhone and Android."],
];

const OUT = new URL("../../launch/marketing/voiceover/", import.meta.url);
mkdirSync(OUT, { recursive: true });
const only = new Set(process.argv.slice(2));
const client = new ElevenLabsClient();
const plain = (t) => t.replace(/\[[^\]]*\]\s*/g, "");

const narration = LINES.filter(([, who]) => who === "narrator");
for (const [id, who, text] of LINES) {
  if (only.size && !only.has(id)) continue;
  // Narrator lines know their neighbours, so the read flows like one take.
  const i = narration.findIndex(([n]) => n === id);
  const audio = await client.textToSpeech.convert(VOICES[who], {
    text,
    modelId: "eleven_v4",
    outputFormat: "mp3_44100_128",
    voiceSettings: { stability: 0.45, similarityBoost: 0.8 },
    ...(i > 0 ? { previousText: plain(narration[i - 1][2]) } : {}),
    ...(i >= 0 && i < narration.length - 1 ? { nextText: plain(narration[i + 1][2]) } : {}),
  });
  const chunks = [];
  for await (const c of audio) chunks.push(c);
  writeFileSync(new URL(`${id}.mp3`, OUT), Buffer.concat(chunks.map((c) => Buffer.from(c))));
  console.log(`recorded ${id} (${who})`);
}
