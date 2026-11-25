// Topic colors (SPEC.md §2.2), ported from LessonKit's Palette.swift so web and iOS agree.
// Topic colors are for fills and strokes; topicInk is a darker (light mode) or lighter (dark mode)
// version that reaches 4.6:1 on both paper and card, for topic-colored text.

const BASE = {
  paper: ['#F6F1E7', '#14161C'],
  card: ['#FFFDF8', '#1E2129'],
  ink: ['#1F2430', '#ECE7DC'],
};

function rgb(hex) {
  const v = parseInt(hex.replace('#', ''), 16);
  return [(v >> 16) & 255, (v >> 8) & 255, v & 255].map(c => c / 255);
}
function hex(c) {
  return '#' + c.map(x => Math.round(Math.max(0, Math.min(1, x)) * 255).toString(16).padStart(2, '0')).join('');
}
function luminance(c) {
  const lin = x => (x <= 0.04045 ? x / 12.92 : ((x + 0.055) / 1.055) ** 2.4);
  return 0.2126 * lin(c[0]) + 0.7152 * lin(c[1]) + 0.0722 * lin(c[2]);
}
export function contrast(a, b) {
  const [hi, lo] = [luminance(rgb(a)), luminance(rgb(b))].sort((x, y) => y - x);
  return (hi + 0.05) / (lo + 0.05);
}
function mix(a, b, t) { return a.map((x, i) => x + (b[i] - x) * t); }

export function topicInk(topicHex, dark) {
  const i = dark ? 1 : 0;
  const target = rgb(BASE.ink[i]);
  const backgrounds = [BASE.card[i], BASE.paper[i]];
  let t = 0, c = topicHex;
  while (backgrounds.some(bg => contrast(c, bg) < 4.6) && t < 1) {
    t += 0.05;
    c = hex(mix(rgb(topicHex), target, t));
  }
  return c;
}

export function topicSoft(topicHex, dark) {
  const i = dark ? 1 : 0;
  return hex(mix(rgb(topicHex), rgb(BASE.card[i]), dark ? 0.72 : 0.82));
}

/** CSS custom properties for a topic, for both color schemes (styles.css picks one). */
export function topicStyle(topic) {
  if (!topic) return '';
  const { light, dark } = topic.color;
  return [
    `--topic-l:${light}`, `--topic-d:${dark}`,
    `--topic-ink-l:${topicInk(light, false)}`, `--topic-ink-d:${topicInk(dark, true)}`,
    `--topic-soft-l:${topicSoft(light, false)}`, `--topic-soft-d:${topicSoft(dark, true)}`,
  ].join(';');
}
