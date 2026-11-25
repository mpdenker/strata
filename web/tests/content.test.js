// Checks the bundled lessons from the website's side: every file loads, every icon name maps to a
// drawn icon, and topic colors stay readable. (The full rule check is the Swift validator.)
import { test, eq, ok } from './harness.js';
import { loadContent, allQuestions, stepCount } from '../js/content.js';
import { resolveIcon } from '../js/icons.js';
import { contrast, topicInk } from '../js/palette.js';

const fileText = globalThis.read
  ? path => read(`${globalThis.arguments[0]}/Content/${path}`)
  : path => fetch(`../content/${path}`).then(r => r.text());
const lessonList = globalThis.arguments
  ? JSON.parse(globalThis.arguments[1])
  : null;

async function library() {
  return loadContent(async path => {
    if (path === 'index.json') return JSON.stringify({ lessons: lessonList ?? (await fetch('../content/index.json').then(r => r.json())).lessons });
    return fileText(path);
  });
}

test('every bundled lesson loads with no problems', async () => {
  const lib = await library();
  eq(lib.problems, []);
  ok(lib.lessons.length >= 5, `only ${lib.lessons.length} lessons`);
});

test('every topic has at least one lesson, and question IDs are unique', async () => {
  const lib = await library();
  for (const t of lib.topics) ok(lib.lessonsIn(t.id).length > 0, `${t.id} has no lessons`);
  const ids = lib.lessons.flatMap(l => allQuestions(l).map(q => q.globalID));
  eq(new Set(ids).size, ids.length);
});

test('every icon name used in lessons maps to a drawn icon', async () => {
  const lib = await library();
  const names = new Set(lib.topics.map(t => t.symbol));
  const walk = o => {
    if (Array.isArray(o)) return o.forEach(walk);
    if (o && typeof o === 'object') {
      if (typeof o.symbol === 'string') names.add(o.symbol);
      if (o.kind === 'symbol' || o.shape === 'symbol' || o.kind === 'iconArray') names.add(o.name ?? o.symbol);
      Object.values(o).forEach(walk);
    }
  };
  lib.lessons.forEach(walk);
  const missing = [...names].filter(n => n && !resolveIcon(n));
  eq(missing, []);
});

test('every visual has a build step count of at least 1', async () => {
  const lib = await library();
  for (const l of lib.lessons) for (const s of l.sections) if (s.visual) ok(stepCount(s.visual) >= 1, `${l.id}/${s.id}`);
});

test('topic text colors reach 4.5:1 on paper and card, light and dark', async () => {
  const lib = await library();
  for (const t of lib.topics) {
    for (const [hex, dark, bgs] of [[t.color.light, false, ['#F6F1E7', '#FFFDF8']], [t.color.dark, true, ['#14161C', '#1E2129']]]) {
      const ink = topicInk(hex, dark);
      for (const bg of bgs) ok(contrast(ink, bg) >= 4.5, `${t.id} ${dark ? 'dark' : 'light'} ${ink} on ${bg}: ${contrast(ink, bg).toFixed(2)}`);
    }
  }
});

test('topic colors as graphics reach 3:1 on paper', async () => {
  const lib = await library();
  for (const t of lib.topics) {
    ok(contrast(t.color.light, '#F6F1E7') >= 3, `${t.id} light`);
    ok(contrast(t.color.dark, '#14161C') >= 3, `${t.id} dark`);
  }
});

test('a broken lesson file is reported with its path, not a crash', async () => {
  const lib = await loadContent(async path => {
    if (path === 'topics.json') return JSON.stringify({ topics: [{ id: 'science', name: 'S', symbol: 'atom', order: 1, color: { light: '#127C7A', dark: '#3BB8B2' } }] });
    if (path === 'index.json') return JSON.stringify({ lessons: ['a.json', 'b.json'] });
    if (path === 'a.json') return '{ "id": "a", ';
    return JSON.stringify({ id: 'b', topic: 'science', title: 'B', goal: 'g', minutes: 10, finalQuiz: [], sources: [],
      sections: [{ id: 'x', type: 'timelime' }] });
  });
  eq(lib.lessons.length, 0);
  eq(lib.problems.length, 2);
  ok(lib.problems[0].message.startsWith('not valid JSON'), lib.problems[0].message);
  ok(lib.problems[1].message.includes('sections[0] ("x").type: "timelime" is not one of'), lib.problems[1].message);
});
