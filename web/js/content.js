// Loads topics.json and every lesson file listed in content/index.json (the index is generated
// from the Content folder by scripts/serve.py and scripts/build_web.py, so adding a lesson is still
// just one JSON file). The full rule check is the Swift validator (`validate-lessons`); this loader
// catches what would break the page and reports it instead of crashing.

export const SECTION_TYPES = ['hook', 'textVisual', 'keyIdea', 'comparison', 'timeline', 'steps', 'chart', 'quote', 'check', 'recap'];
export const VISUAL_KINDS = ['diagram', 'shapes', 'iconArray', 'formula', 'bigNumber', 'layers', 'symbol'];

/** readText(path) → Promise<string>, with path relative to the content folder. */
export async function loadContent(readText) {
  const problems = [];
  let topics = [];
  try {
    topics = JSON.parse(await readText('topics.json')).topics.slice().sort((a, b) => a.order - b.order);
  } catch (e) {
    problems.push({ file: 'topics.json', message: e.message });
  }
  let files = [];
  try {
    files = JSON.parse(await readText('index.json')).lessons;
  } catch (e) {
    problems.push({ file: 'index.json', message: `lesson index missing (${e.message}). Start the site with scripts/serve.py.` });
  }
  const topicIDs = new Set(topics.map(t => t.id));
  const lessons = [];
  const results = await Promise.all(files.map(async file => {
    try { return { file, text: await readText(file) }; } catch (e) { return { file, error: e.message }; }
  }));
  for (const { file, text, error } of results) {
    if (error) { problems.push({ file, message: error }); continue; }
    let json;
    try { json = JSON.parse(text); } catch (e) { problems.push({ file, message: `not valid JSON: ${e.message}` }); continue; }
    const issues = checkLesson(json, topicIDs);
    if (issues.length) { for (const m of issues) problems.push({ file, message: m }); continue; }
    lessons.push(json);
  }
  const seen = new Map();
  for (const l of lessons) {
    if (seen.has(l.id)) problems.push({ file: l.id, message: `duplicate lesson id "${l.id}"` });
    seen.set(l.id, l);
  }
  const topicOrder = new Map(topics.map(t => [t.id, t.order]));
  const unique = [...seen.values()].sort((a, b) => (topicOrder.get(a.topic) - topicOrder.get(b.topic)) || a.order - b.order);
  return new Library(topics, unique, problems);
}

/** Structural checks that would otherwise break rendering. Returns messages with JSON paths. */
export function checkLesson(l, topicIDs) {
  const out = [];
  for (const key of ['id', 'topic', 'title', 'goal', 'minutes', 'sections', 'finalQuiz', 'sources']) {
    if (l[key] === undefined) out.push(`missing required key '${key}'`);
  }
  if (out.length) return out;
  if (!topicIDs.has(l.topic)) out.push(`topic: unknown topic "${l.topic}"`);
  l.sections.forEach((s, i) => {
    const at = `sections[${i}]${s.id ? ` ("${s.id}")` : ''}`;
    if (!s.id) out.push(`${at}: missing 'id'`);
    if (!SECTION_TYPES.includes(s.type)) out.push(`${at}.type: "${s.type}" is not one of ${SECTION_TYPES.join(', ')}`);
    const visual = s.visual;
    if (visual && !VISUAL_KINDS.includes(visual.kind)) out.push(`${at}.visual.kind: "${visual.kind}" is not one of ${VISUAL_KINDS.join(', ')}`);
    if (s.type === 'check') (s.questions ?? []).forEach((q, j) => checkQuestion(q, `${at}.questions[${j}]`, out));
  });
  l.finalQuiz.forEach((q, j) => checkQuestion(q, `finalQuiz[${j}]`, out));
  return out;
}

function checkQuestion(q, at, out) {
  if (q.kind === 'multipleChoice') {
    if (!Array.isArray(q.choices) || typeof q.answer !== 'number' || !q.choices[q.answer]) out.push(`${at}.answer: must be an index into choices`);
  } else if (q.kind === 'trueFalse') {
    if (typeof q.answer !== 'boolean') out.push(`${at}.answer: must be true or false`);
  } else out.push(`${at}.kind: "${q.kind}" is not multipleChoice or trueFalse`);
}

export class Library {
  constructor(topics, lessons, problems) {
    this.topics = topics;
    this.lessons = lessons;
    this.problems = problems;
    this.byID = new Map(lessons.map(l => [l.id, l]));
    this.questions = new Map();
    for (const l of lessons) for (const q of allQuestions(l)) this.questions.set(q.globalID, { ...q, lesson: l });
  }
  topic(id) { return this.topics.find(t => t.id === id); }
  lesson(id) { return this.byID.get(id); }
  lessonsIn(topicID) { return this.lessons.filter(l => l.topic === topicID); }
  question(globalID) { return this.questions.get(globalID); }
  /** The next lesson in the same topic, wrapping to the first. */
  nextInTopic(lesson) {
    const list = this.lessonsIn(lesson.topic);
    const i = list.indexOf(lesson);
    return list.length > 1 ? list[(i + 1) % list.length] : null;
  }
}

// MARK: - Helpers shared by screens

export const globalID = (lessonID, localID) => `${lessonID}.${localID}`;

/** Every question with its review-card ID: inline checks first, then the final quiz. */
export function allQuestions(lesson) {
  const inline = lesson.sections.filter(s => s.type === 'check')
    .flatMap(s => s.questions.map(q => ({ question: q, globalID: globalID(lesson.id, q.id), inline: true })));
  const final = lesson.finalQuiz.map(q => ({ question: q, globalID: globalID(lesson.id, q.id), inline: false }));
  return [...inline, ...final];
}

export function inlineQuestions(lesson) { return allQuestions(lesson).filter(q => q.inline); }

export function displayChoices(q) { return q.kind === 'trueFalse' ? ['True', 'False'] : q.choices; }

export function correctChoice(q) { return q.kind === 'trueFalse' ? (q.answer ? 'True' : 'False') : q.choices[q.answer]; }

/** "Authors, Title (Publisher, Year), Locator." */
export function citation(s) {
  const parts = [];
  if (s.authors) parts.push(s.authors + ',');
  parts.push(s.title);
  const pubYear = [s.publisher, s.year].filter(Boolean).join(', ');
  if (pubYear) parts.push(`(${pubYear})`);
  let line = parts.join(' ');
  if (s.locator) line += `, ${s.locator}`;
  return line + '.';
}

/** How many build steps a visual has (its parts appear in `step` order). */
export function stepCount(v) {
  switch (v.kind) {
    case 'diagram': return Math.max(1, ...v.nodes.map(n => n.step ?? 1), ...(v.edges ?? []).map(e => e.step ?? 1));
    case 'shapes': return Math.max(1, ...v.items.map(i => i.step ?? 1));
    case 'iconArray': return Math.max(1, v.groups.length);
    case 'formula': return Math.max(1, v.parts.length);
    case 'layers': return Math.max(1, v.layers.length);
    default: return 1;
  }
}
