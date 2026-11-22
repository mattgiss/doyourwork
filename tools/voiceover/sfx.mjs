// Sound effects and a music bed for "The Dishes" ad, made with ElevenLabs.
//
//   node --env-file=../../.env.local sfx.mjs
//
// Writes to launch/marketing/sfx/<name>.mp3.
import { ElevenLabsClient } from "@elevenlabs/elevenlabs-js";
import { mkdirSync, writeFileSync } from "node:fs";

const OUT = new URL("../../launch/marketing/sfx/", import.meta.url);
mkdirSync(OUT, { recursive: true });
const client = new ElevenLabsClient();

async function save(name, stream) {
  const chunks = [];
  for await (const c of stream) chunks.push(Buffer.from(c));
  writeFileSync(new URL(`${name}.mp3`, OUT), Buffer.concat(chunks));
  console.log(`made ${name}`);
}

const EFFECTS = [
  ["brush", "Someone briskly brushing their teeth with a toothbrush, close up, foamy scrubbing", 3],
  ["honk", "A loud comedic car horn honk from a car speeding past outside a window, doppler whoosh", 2],
  ["strike", "A bowling ball crashing into ten pins for a strike in a busy bowling alley, then a small crowd cheer", 3],
  ["pop", "A soft cheerful cartoon UI pop", 0.5],
  ["chime", "A bright happy four-note success chime", 2],
];
const only = new Set(process.argv.slice(2));
for (const [name, text, seconds] of EFFECTS) {
  if (only.size && !only.has(name)) continue;
  await save(name, await client.textToSoundEffects.convert({ text, modelId: "eleven_text_to_sound_v3", durationSeconds: seconds, promptInfluence: 0.6 }));
}
if (!only.size || only.has("music")) {
  await save("music", await client.music.compose({
    prompt: "Light, playful, upbeat instrumental for a family sitcom-style commercial: plucky ukulele, soft hand claps, bouncy bass, glockenspiel accents, warm and cheerful, no vocals",
    musicLengthMs: 66000,
    forceInstrumental: true,
  }));
}
