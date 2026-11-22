// Lists the voices this ElevenLabs account can use, with their descriptions, to pick a narrator.
import { ElevenLabsClient } from "@elevenlabs/elevenlabs-js";

const client = new ElevenLabsClient();
const sub = await client.user.subscription.get().catch(() => null);
if (sub) console.log(`Plan: ${sub.tier}  characters left: ${sub.characterLimit - sub.characterCount}`);
const { voices } = await client.voices.getAll();
for (const v of voices) {
  const l = v.labels || {};
  console.log([v.voiceId, v.name, v.category, l.gender, l.age, l.accent, l.descriptive || l.description, l.use_case || l.useCase].filter(Boolean).join(" | "));
}
