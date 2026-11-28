// Writes the profile borders out for both apps.
//
//   node tools/borders/build.mjs
//
// A border is drawn around a person's photo on their family tile: ears, hearts, a crown and so on.
// Each one unlocks once the person has earned enough points in all (Engine's total xp). The
// drawings are made here from circles, ellipses and polygons, in a 100 × 100 square where the
// photo is the circle at (50, 58) with radius 30. Every layer is filled even-odd, so a ring is an
// outer circle with an inner one cut out.
//
// It rewrites three files; change a border here and run this again, never edit them by hand:
//   android/app/src/main/java/com/doyourwork/app/engine/BorderArt.kt
//   ios/DoYourWorkCore/Sources/DoYourWorkCore/BorderArt.swift
//   launch/brand/borders.svg   (a sheet of all of them, for looking at)
import { writeFileSync } from 'node:fs';

const root = new URL('../../', import.meta.url);
const note = 'Written by tools/borders/build.mjs. Change the borders there.';

const F = (n) => (Math.round(n * 10) / 10).toString();
const rot = (x, y, cx, cy, deg) => {
  const a = (deg * Math.PI) / 180, dx = x - cx, dy = y - cy;
  return [cx + dx * Math.cos(a) - dy * Math.sin(a), cy + dx * Math.sin(a) + dy * Math.cos(a)];
};

/** An ellipse as four cubic curves, turned `deg` degrees about its centre. */
function ellipse(cx, cy, rx, ry, deg = 0) {
  const k = 0.5523;
  const pts = [
    [cx + rx, cy],
    [cx + rx, cy + ry * k], [cx + rx * k, cy + ry], [cx, cy + ry],
    [cx - rx * k, cy + ry], [cx - rx, cy + ry * k], [cx - rx, cy],
    [cx - rx, cy - ry * k], [cx - rx * k, cy - ry], [cx, cy - ry],
    [cx + rx * k, cy - ry], [cx + rx, cy - ry * k], [cx + rx, cy],
  ].map(([x, y]) => rot(x, y, cx, cy, deg));
  let d = `M${F(pts[0][0])} ${F(pts[0][1])}`;
  for (let i = 1; i < pts.length; i += 3) d += ` C${pts.slice(i, i + 3).map(([x, y]) => `${F(x)} ${F(y)}`).join(' ')}`;
  return d + ' Z';
}
const circle = (cx, cy, r) => ellipse(cx, cy, r, r);
const poly = (pts) => `M${pts.map(([x, y]) => `${F(x)} ${F(y)}`).join(' L')} Z`;

/** A heart of width `s`, centred on (cx, cy). */
function heart(cx, cy, s) {
  const h = s / 2, P = (x, y) => `${F(cx + x * h)} ${F(cy + y * h)}`;
  return `M${P(0, 0.9)} C${P(-1.1, 0.15)} ${P(-1.05, -0.85)} ${P(-0.5, -0.85)} C${P(-0.2, -0.85)} ${P(0, -0.6)} ${P(0, -0.4)} `
    + `C${P(0, -0.6)} ${P(0.2, -0.85)} ${P(0.5, -0.85)} C${P(1.05, -0.85)} ${P(1.1, 0.15)} ${P(0, 0.9)} Z`;
}
/** A five-pointed star of outer radius `r`. */
function star(cx, cy, r, deg = 0) {
  const pts = [];
  for (let i = 0; i < 10; i++) {
    const a = ((i * 36 - 90 + deg) * Math.PI) / 180, rr = i % 2 ? r * 0.45 : r;
    pts.push([cx + rr * Math.cos(a), cy + rr * Math.sin(a)]);
  }
  return poly(pts);
}
/** A flame of height `h` standing on (cx, by). */
function flame(cx, by, w, h) {
  const P = (x, y) => `${F(cx + x * w)} ${F(by - y * h)}`;
  return `M${P(0, 0)} C${P(-0.55, 0)} ${P(-0.6, 0.45)} ${P(-0.25, 0.7)} C${P(-0.15, 0.8)} ${P(-0.05, 0.9)} ${P(0, 1)} `
    + `C${P(0.1, 0.85)} ${P(0.35, 0.7)} ${P(0.45, 0.5)} C${P(0.65, 0.2)} ${P(0.45, 0)} ${P(0, 0)} Z`;
}
/** Points on the photo's circle, at `deg` degrees (0 is right, -90 is the top). */
const onRing = (deg, r = 36) => [50 + r * Math.cos((deg * Math.PI) / 180), 58 + r * Math.sin((deg * Math.PI) / 180)];

const PINK = '#FF8FB1', WHITE = '#F4F4F6', GOLD = '#F5C542', RED = '#E0262E';

export const borders = [
  { id: 'none', name: 'No border', unlock: 0, layers: [] },
  { id: 'ring', name: 'Ring', unlock: 0, layers: [{ color: 'accent', d: `${circle(50, 58, 35)} ${circle(50, 58, 30.5)}` }] },
  { id: 'bunny', name: 'Bunny ears', unlock: 100, layers: [
    { color: WHITE, d: `${ellipse(37, 20, 7.5, 17, -14)} ${ellipse(63, 20, 7.5, 17, 14)}` },
    { color: PINK, d: `${ellipse(37, 21, 3.6, 12, -14)} ${ellipse(63, 21, 3.6, 12, 14)}` },
  ] },
  { id: 'cat', name: 'Cat ears', unlock: 250, layers: [
    { color: '#F2994A', d: `${poly([[22, 44], [24, 12], [46, 30]])} ${poly([[78, 44], [76, 12], [54, 30]])}` },
    { color: PINK, d: `${poly([[27, 37], [28, 20], [40, 30]])} ${poly([[73, 37], [72, 20], [60, 30]])}` },
  ] },
  { id: 'hearts', name: 'Hearts', unlock: 500, layers: [
    { color: '#FF4D6D', d: [-160, -125, -90, -55, -20].map((a, i) => heart(...onRing(a, 37), i === 2 ? 13 : 10)).join(' ') },
  ] },
  { id: 'bear', name: 'Bear ears', unlock: 800, layers: [
    { color: '#8B5A2B', d: `${circle(25, 33, 11)} ${circle(75, 33, 11)}` },
    { color: '#D9A066', d: `${circle(25, 33, 5.5)} ${circle(75, 33, 5.5)}` },
  ] },
  { id: 'crown', name: 'Crown', unlock: 1200, layers: [
    { color: GOLD, d: poly([[30, 30], [28, 10], [39, 20], [50, 5], [61, 20], [72, 10], [70, 30]]) },
    { color: RED, d: `${circle(50, 22, 3)} ${circle(37, 25, 2.2)} ${circle(63, 25, 2.2)}` },
  ] },
  { id: 'flames', name: 'Flames', unlock: 1800, layers: [
    { color: '#FF3B2F', d: [[-150, 14], [-120, 18], [-90, 22], [-60, 18], [-30, 14]].map(([a, h]) => { const [x, y] = onRing(a, 31); return flame(x, y + 2, 11, h); }).join(' ') },
    { color: '#EDB82A', d: [[-150, 7], [-120, 9], [-90, 11], [-60, 9], [-30, 7]].map(([a, h]) => { const [x, y] = onRing(a, 31); return flame(x, y + 1, 6, h); }).join(' ') },
  ] },
  { id: 'stars', name: 'Stars', unlock: 2500, layers: [
    { color: '#FFD93D', d: [[-165, 6], [-130, 8], [-90, 10], [-50, 8], [-15, 6], [160, 5], [20, 5]].map(([a, r], i) => star(...onRing(a, 38), r, i * 12)).join(' ') },
  ] },
  { id: 'horns', name: 'Little horns', unlock: 3500, layers: [
    { color: RED, d: `M26 38 C22 30 22 20 27 12 C29 22 34 28 40 31 Z M74 38 C78 30 78 20 73 12 C71 22 66 28 60 31 Z` },
  ] },
  { id: 'halo', name: 'Halo', unlock: 5000, layers: [
    { color: GOLD, d: `${ellipse(50, 15, 22, 6.5)} ${ellipse(50, 15, 17, 3.5)}` },
  ] },
  // Added with the second round of the redesign: more animals and fun hats.
  { id: 'puppy', name: 'Puppy ears', unlock: 50, layers: [
    { color: '#A86B3C', d: `${ellipse(20, 52, 9, 19, 18)} ${ellipse(80, 52, 9, 19, -18)}` },
    { color: '#7A4A26', d: `${ellipse(19, 57, 4.5, 12, 18)} ${ellipse(81, 57, 4.5, 12, -18)}` },
  ] },
  { id: 'panda', name: 'Panda ears', unlock: 150, layers: [
    { color: '#1C1C1E', d: `${circle(26, 32, 11)} ${circle(74, 32, 11)}` },
    { color: '#F4F4F6', d: `${circle(26, 32, 11)} ${circle(26, 32, 12.5)} ${circle(74, 32, 11)} ${circle(74, 32, 12.5)}` },
  ] },
  { id: 'mouse', name: 'Mouse ears', unlock: 350, layers: [
    { color: '#8E8E93', d: `${circle(22, 28, 15)} ${circle(78, 28, 15)}` },
    { color: PINK, d: `${circle(22, 28, 9)} ${circle(78, 28, 9)}` },
  ] },
  { id: 'fox', name: 'Fox ears', unlock: 650, layers: [
    { color: '#E8672A', d: `${poly([[20, 46], [18, 8], [46, 28]])} ${poly([[80, 46], [82, 8], [54, 28]])}` },
    { color: WHITE, d: `${poly([[24, 38], [22, 16], [38, 28]])} ${poly([[76, 38], [78, 16], [62, 28]])}` },
    { color: '#1C1C1E', d: `${poly([[18, 8], [19.5, 17], [24.5, 12.5]])} ${poly([[82, 8], [80.5, 17], [75.5, 12.5]])}` },
  ] },
  { id: 'frog', name: 'Frog eyes', unlock: 1000, layers: [
    { color: '#5DBB63', d: `${circle(33, 30, 12)} ${circle(67, 30, 12)}` },
    { color: WHITE, d: `${circle(33, 28, 7.5)} ${circle(67, 28, 7.5)}` },
    { color: '#1C1C1E', d: `${circle(34, 27, 3.8)} ${circle(66, 27, 3.8)}` },
  ] },
  { id: 'flowers', name: 'Flower crown', unlock: 1500, layers: [
    { color: '#5DBB63', d: [-150, -120, -90, -60, -30].map((a) => { const [x, y] = onRing(a, 33); return ellipse(x, y + 3, 6, 2.5, a + 90); }).join(' ') },
    { color: '#FF8FB1', d: [-155, -90, -25].map((a) => { const [x, y] = onRing(a, 34); return [0, 72, 144, 216, 288].map((t) => { const [px, py] = rot(x, y - 5, x, y, t); return circle(px, py, 3.6); }).join(' '); }).join(' ') },
    { color: '#FFD93D', d: [-122, -58].map((a) => { const [x, y] = onRing(a, 34); return [0, 72, 144, 216, 288].map((t) => { const [px, py] = rot(x, y - 4.5, x, y, t); return circle(px, py, 3.2); }).join(' '); }).join(' ') },
    { color: '#E0262E', d: [-155, -122, -90, -58, -25].map((a) => circle(...onRing(a, 34), 2.4)).join(' ') },
  ] },
  { id: 'party', name: 'Party hat', unlock: 2100, layers: [
    { color: '#6C5CE7', d: poly([[36, 32], [50, 2], [64, 32]]) },
    { color: '#FFD93D', d: `${poly([[43.5, 16], [56.5, 16], [58.4, 20], [41.6, 20]])} ${poly([[39.8, 24], [60.2, 24], [62, 28], [38, 28]])}` },
    { color: '#FF4D6D', d: circle(50, 4, 4) },
  ] },
  { id: 'unicorn', name: 'Unicorn horn', unlock: 3000, layers: [
    { color: GOLD, d: poly([[43, 30], [50, 1], [57, 30]]) },
    { color: '#FFF3C4', d: `${poly([[44.4, 24], [55.6, 24], [55, 26.5], [45, 26.5]])} ${poly([[46, 15], [54, 15], [53.4, 17.5], [46.6, 17.5]])} ${poly([[47.8, 7], [52.2, 7], [51.7, 9], [48.3, 9]])}` },
    { color: '#C9A7FF', d: `${ellipse(30, 30, 6, 10, -30)} ${ellipse(70, 30, 6, 10, 30)}` },
  ] },
];
// The order they unlock in, which is also the order they're listed in.
borders.sort((a, b) => a.unlock - b.unlock || (a.id === 'none' ? -1 : b.id === 'none' ? 1 : 0));

// The apps' path reader wants a space between every letter and number: "M 50 58 L …".
for (const b of borders) for (const l of b.layers) l.d = l.d.replace(/([MLCZ])/g, ' $1 ').replace(/\s+/g, ' ').trim();

for (const b of borders) for (const l of b.layers) {
  if (!/^[MLCZ0-9. -]+$/.test(l.d)) throw new Error(`${b.id}: a path uses something other than M, L, C and Z`);
  for (const v of l.d.match(/-?[0-9.]+/g)) if (+v < 0 || +v > 100) throw new Error(`${b.id}: ${v} is outside the 100 × 100 square`);
}

const color = (c) => (c === 'accent' ? 'null' : `0x${c.slice(1)}`);

writeFileSync(new URL('android/app/src/main/java/com/doyourwork/app/engine/BorderArt.kt', root), `// ${note}
package com.doyourwork.app.engine

internal object BorderArt {
    val ALL: List<ProfileBorder> = listOf(
${borders.map((b) => `        ProfileBorder("${b.id}", "${b.name}", ${b.unlock}, listOf(
${b.layers.map((l) => `            ProfileBorder.Layer(${l.color === 'accent' ? 'null' : `0xFF${l.color.slice(1)}`}, "${l.d}"),`).join('\n')}
        )),`).join('\n')}
    )
}
`);

writeFileSync(new URL('ios/DoYourWorkCore/Sources/DoYourWorkCore/BorderArt.swift', root), `// ${note}

enum BorderArt {
    static let all: [ProfileBorder] = [
${borders.map((b) => `        ProfileBorder(id: "${b.id}", name: "${b.name}", unlockXp: ${b.unlock}, layers: [
${b.layers.map((l) => `            .init(color: ${color(l.color) === 'null' ? 'nil' : color(l.color)}, path: "${l.d}"),`).join('\n')}
        ]),`).join('\n')}
    ]
}
`);

const cell = 120, cols = 4;
writeFileSync(new URL('launch/brand/borders.svg', root), `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${cols * cell} ${Math.ceil(borders.length / cols) * cell}">
<!-- ${note} -->
${borders.map((b, i) => { const x = (i % cols) * cell, y = Math.floor(i / cols) * cell;
  return `<g transform="translate(${x} ${y})"><title>${b.name} (${b.unlock} points)</title><rect width="${cell}" height="${cell}" rx="18" fill="#1C1C1E"/><g transform="translate(10 6)"><circle cx="50" cy="58" r="30" fill="#5A5A5E"/>${b.layers.map((l) => `<path d="${l.d}" fill="${l.color === 'accent' ? '#FFFFFF' : l.color}" fill-rule="evenodd"/>`).join('')}</g></g>`; }).join('\n')}
</svg>
`);
console.log(`${borders.length} borders written for Android and iOS.`);
