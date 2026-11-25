// The ten section types (SPEC.md §6.3). Each section is one "layer" of a scroll lesson, followed by
// its worked-example note, Contested note and source footnote.
import { md, esc, plain, seededShuffle } from '../text.js';
import { icon } from '../icons.js';
import { displayChoices, correctChoice, globalID } from '../content.js';
import { renderVisual, diagram, keep } from './visuals.js';
import { formatValue } from './chart.js';

export function renderSection(s, lesson, answers = {}) {
  const body = {
    hook: () => hook(s),
    textVisual: () => textVisual(s),
    keyIdea: () => keyIdea(s),
    comparison: () => comparison(s),
    timeline: () => timeline(s),
    steps: () => steps(s),
    chart: () => chartSection(s),
    quote: () => quote(s),
    check: () => check(s, lesson, answers),
    recap: () => recap(s),
  }[s.type]();
  const computed = s.computed ? `<p class="note">${icon('function')}<span>Worked example: ${esc(s.computed)}</span></p>` : '';
  const contested = s.contested ? `<aside class="contested">${icon('contested')}<div><div class="eyebrow">Contested</div><p>${md(s.contested.note)}</p></div></aside>` : '';
  return `<section class="layer t-${s.type}" id="sec-${esc(s.id)}" data-sid="${esc(s.id)}">
    ${body}${computed}${contested}${footnote(s.sourceRefs, lesson)}</section>`;
}

function footnote(refs, lesson) {
  if (!refs?.length) return '';
  const titles = [...new Set(refs.map(r => lesson.sources.find(x => x.id === r)?.title).filter(Boolean))];
  if (!titles.length) return '';
  return `<p class="note source-note">${icon('book')}<span>${titles.length === 1 ? 'Source' : 'Sources'}: ${titles.map(esc).join('; ')}</span></p>`;
}

const heading = text => (text ? `<h2 class="sec-heading">${md(text)}</h2>` : '');
const bodyText = text => `<p class="body">${md(text)}</p>`;
const stage = (id, total, inner, extra = '') =>
  `<div class="staged" data-stage="${esc(id)}" data-total="${total}" ${extra}>${inner}</div>`;

function hook(s) {
  return `<h2 class="hook-headline">${md(s.headline)}</h2>
    ${s.visual ? renderVisual(s.visual, `${s.id}.visual`) : ''}
    <p class="hook-body">${md(s.body)}</p>`;
}

function textVisual(s) {
  const v = renderVisual(s.visual, `${s.id}.visual`);
  return heading(s.heading) + (s.layout === 'textFirst' ? bodyText(s.body) + v : v + bodyText(s.body));
}

function keyIdea(s) {
  return `<div class="key-idea">
    <div class="eyebrow">${icon(s.symbol ?? 'key')}Key idea</div>
    <p class="key-statement">${md(s.statement)}</p>
    ${s.body ? bodyText(s.body) : ''}</div>`;
}

function comparison(s) {
  const cols = s.columns;
  const header = `<div class="cmp-corner"></div>` + cols.map((c, i) =>
    `<div class="cmp-head${i === 0 ? ' first' : ''}" role="columnheader">${c.symbol ? icon(c.symbol) : ''}${md(c.title)}</div>`).join('');
  const rows = s.rows.map((r, ri) =>
    `<div class="cmp-row appear" data-step="${ri + 2}" role="row"><div class="cmp-label" role="rowheader">${md(r.label)}</div>${r.values.map(v => `<div class="cmp-cell" role="cell">${md(v)}</div>`).join('')}</div>`).join('');
  const grid = `<div class="cmp-grid" role="table" style="--cols:${cols.length}"><div class="cmp-row header appear" data-step="1" role="row">${header}</div>${rows}</div>`;
  const stacked = `<div class="cmp-stacked">${s.rows.map((r, ri) => `<div class="cmp-card appear" data-step="${ri + 2}">
      <h3>${md(r.label)}</h3>${r.values.map((v, i) => `<p><strong>${md(cols[i]?.title ?? '')}:</strong> ${md(v)}</p>`).join('')}</div>`).join('')}</div>`;
  return heading(s.heading) + stage(`${s.id}.rows`, s.rows.length + 1, `<div class="comparison">${grid}${stacked}</div>`) +
    (s.takeaway ? `<p class="takeaway">${icon('turn')}<span>${md(s.takeaway)}</span></p>` : '');
}

function timeline(s) {
  const events = s.events.slice().sort((a, b) => a.sortKey - b.sortKey);
  let gaps = events.map(() => 20);
  if ((s.scale ?? 'even') === 'linear' && events.length > 1) {
    const deltas = events.slice(1).map((e, i) => e.sortKey - events[i].sortKey);
    const max = Math.max(1, ...deltas);
    gaps = [...deltas.map(d => 14 + 56 * Math.sqrt(d / max)), 0];
  }
  const items = events.map((e, i) => `<li class="tl-event appear" data-step="${i + 1}" style="--gap:${i === events.length - 1 ? 0 : gaps[i]}px">
      <span class="tl-dot" aria-hidden="true"></span>${i < events.length - 1 ? '<span class="tl-spine" aria-hidden="true"></span>' : ''}
      <div class="tl-date">${esc(e.date)}${e.approx ? ' (approx.)' : ''}</div>
      <div class="tl-title">${md(e.title)}</div>
      ${e.detail ? `<div class="tl-detail">${md(e.detail)}</div>` : ''}</li>`).join('');
  return heading(s.heading) + stage(`${s.id}.events`, events.length, `<ol class="timeline">${items}</ol>`, 'data-stagger="180"');
}

function steps(s) {
  const list = s.steps;
  if (s.style === 'cycle') {
    const d = {
      layout: 'cycle',
      nodes: list.map((st, i) => ({ id: `s${i}`, label: st.title, symbol: st.symbol, style: 'filled', step: i + 1 })),
      edges: list.map((_, i) => ({ from: `s${i}`, to: `s${(i + 1) % list.length}`, style: 'arrow', step: i + 2 })),
    };
    const summary = list.map(st => plain(st.title)).join(', then ') + ', and back to the start.';
    const notes = list.map((st, i) => (st.body ? `<li><span class="num">${i + 1}.</span><span><strong>${md(st.title)}</strong> — ${md(st.body)}</span></li>` : '')).join('');
    return heading(s.heading) + `<figure class="visual" role="img" aria-label="${esc('A repeating cycle: ' + summary)}">` +
      stage(`${s.id}.cycle`, list.length + 1, `<div class="canvas">${diagram(d)}</div>`, 'aria-hidden="true"') +
      `</figure><ol class="cycle-notes">${notes}</ol>`;
  }
  if (s.style === 'flow') {
    const items = list.map((st, i) => `${i ? `<li class="flow-arrow appear" data-step="${i + 1}" aria-hidden="true">${icon('arrowDown')}</li>` : ''}
      <li class="flow-step appear" data-step="${i + 1}">${st.symbol ? icon(st.symbol, { cls: 'flow-ic' }) : ''}<div>${stepText(st)}</div></li>`).join('');
    return heading(s.heading) + stage(`${s.id}.steps`, list.length, `<ol class="flow">${items}</ol>`);
  }
  const items = list.map((st, i) => `<li class="num-step appear" data-step="${i + 1}">
      <span class="num-badge" aria-hidden="true">${i + 1}</span>${i < list.length - 1 ? '<span class="num-spine" aria-hidden="true"></span>' : ''}
      <div>${stepText(st)}</div></li>`).join('');
  return heading(s.heading) + stage(`${s.id}.steps`, list.length, `<ol class="numbered">${items}</ol>`);
}

const stepText = st => `<div class="step-title">${md(st.title)}</div>${st.body ? `<div class="step-body">${md(st.body)}</div>` : ''}`;

function chartSection(s) {
  const tag = { sourced: ['Sourced data', 'check'], computed: ['Computed', 'function'], illustrative: ['Illustrative, not real data', 'pencil'] }[s.dataKind];
  const table = `<table class="sr-only"><caption>${esc(s.heading ?? s.yLabel)}</caption>
    <thead><tr><th>${esc(s.xLabel)}</th>${s.series.map(se => `<th>${esc(se.name)}</th>`).join('')}</tr></thead>
    <tbody>${[...new Set(s.series.flatMap(se => se.points.map(p => p.x)))].map(x => `<tr><th>${esc(x)}</th>${s.series.map(se => {
      const p = se.points.find(q => q.x === x);
      return `<td>${p ? esc(formatValue(p.y, s.unit)) : '–'}</td>`;
    }).join('')}</tr>`).join('')}</tbody></table>`;
  return heading(s.heading) +
    `<span class="data-tag">${icon(tag[1])}${tag[0]}</span>` +
    `<figure class="visual chart-figure">${table}` +
    stage(`${s.id}.chart`, 1, `<div class="canvas"><div class="chart" data-chart="${keep(s)}"></div></div>`, 'aria-hidden="true"') +
    `</figure>${bodyText(s.caption)}<p class="note">${icon(s.dataKind === 'computed' ? 'function' : 'info')}<span>${esc(s.dataNote)}</span></p>`;
}

function quote(s) {
  const attribution = `${esc(s.work)}, ${esc(s.year)}${s.translator ? ` · trans. ${esc(s.translator)}` : ''}`;
  return `<figure class="quote"><span class="quote-mark" aria-hidden="true">“</span>
    <blockquote>${md(s.text)}</blockquote>
    <figcaption><div class="speaker">— ${esc(s.speaker)}</div><div class="muted small">${attribution}</div></figcaption></figure>`;
}

function check(s, lesson, answers) {
  const cards = s.questions.map(q => questionCard(q, globalID(lesson.id, q.id), { picked: answers[q.id], context: 'inline', localID: q.id })).join('');
  return `<div class="check"><div class="eyebrow">${icon('check')}Quick check</div>${cards}</div>`;
}

function recap(s) {
  return `<div class="recap"><div class="eyebrow">${icon('list')}Recap</div>
    <ol>${s.bullets.map((b, i) => `<li><span class="num-badge" aria-hidden="true">${i + 1}</span><span>${md(b)}</span></li>`).join('')}</ol></div>`;
}

// MARK: - Question card (inline checks, final quiz, review)

/** One question. Choices keep a stable shuffled order per question; true/false stays in order. */
export function questionCard(q, gid, { picked, context, localID, headingLevel = 3 } = {}) {
  const options = q.kind === 'trueFalse' ? displayChoices(q) : seededShuffle(displayChoices(q), gid);
  const right = correctChoice(q);
  const answered = picked !== undefined && picked !== null;
  const buttons = options.map(opt => {
    let state = 'idle', value = '';
    if (answered) {
      if (opt === picked) { state = opt === right ? 'right' : 'wrong'; value = opt === right ? 'Your answer. Correct.' : 'Your answer. Incorrect.'; }
      else if (opt === right) { state = 'reveal'; value = 'Correct answer.'; }
      else state = 'dim';
    }
    const mark = state === 'right' || state === 'reveal' ? icon('checkFill', { cls: 'mark ok' }) : state === 'wrong' ? icon('wrongFill', { cls: 'mark no' }) : '';
    return `<button class="choice c-${state}" type="button" data-choice="${esc(opt)}" ${answered ? 'aria-disabled="true"' : ''}>
      <span>${md(opt)}</span>${mark}${value ? `<span class="sr-only">${value}</span>` : ''}</button>`;
  }).join('');
  const feedback = answered ? feedbackHTML(picked === right, q.explanation) : '';
  return `<div class="qcard" data-q="${esc(gid)}" data-context="${context}" data-local="${esc(localID ?? q.id)}">
    <h${headingLevel} class="prompt">${md(q.prompt)}</h${headingLevel}>
    <div class="choices" role="group" aria-label="Answers">${buttons}</div>
    <div class="feedback-slot" aria-live="polite">${feedback}</div></div>`;
}

function feedbackHTML(correct, explanation) {
  return `<div class="feedback ${correct ? 'ok' : 'no'}">
    <div class="fb-title">${icon(correct ? 'checkFill' : 'wrongFill')}${correct ? 'Correct' : 'Not quite'}</div>
    <p>${md(explanation)}</p></div>`;
}
