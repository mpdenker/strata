// Strata on the web: startup, routing and the tab screens (Home, Topic, Review, You).
import { loadContent, correctChoice } from './content.js';
import { Progress } from './logic/progress.js';
import { ReviewSession } from './logic/session.js';
import { addDays, formatKey, parts, makeKey, weekday } from './logic/daykey.js';
import { app, esc, md, icon, topicStyle, goalRing, streakChip, lessonCard, statusIcon, tabbar, downloadReminder } from './ui.js';
import { lessonScreen, quizScreen, completeScreen } from './lesson.js';
import { questionCard } from './render/sections.js';
import { plural } from './text.js';

const root = document.getElementById('app');
const STORAGE_KEY = 'strata.progress.v1';
let cleanup = null;

async function boot() {
  try {
    const cfg = await fetch('app-config.json').then(r => r.json());
    app.name = cfg.name ?? app.name;
    app.version = cfg.version ?? app.version;
  } catch { /* defaults */ }
  document.title = app.name;

  app.lib = await loadContent(path => fetch(`content/${path}`).then(r => {
    if (!r.ok) throw new Error(`HTTP ${r.status} for ${path}`);
    return r.text();
  }));
  if (app.lib.problems.length) console.warn('Content problems', app.lib.problems);

  app.progress = new Progress({
    load: () => { try { return JSON.parse(localStorage.getItem(STORAGE_KEY)); } catch { return null; } },
    save: s => { try { localStorage.setItem(STORAGE_KEY, JSON.stringify(s)); } catch (e) { console.error('Could not save progress', e); } },
  });
  app.go = hash => { location.hash = hash; };
  app.rerender = route;

  markLargeText();
  addEventListener('hashchange', route);
  route();
  registerOffline();
}

/** Accessibility text sizes switch side-by-side layouts to stacked ones (SPEC.md §11). */
function markLargeText() {
  const check = () => document.documentElement.classList.toggle('large-text', parseFloat(getComputedStyle(document.documentElement).fontSize) >= 24);
  check();
  addEventListener('resize', check);
}

function route() {
  cleanup?.();
  cleanup = null;
  document.documentElement.classList.remove('no-sda');
  const [, name = '', id = '', sub = ''] = (location.hash || '#/').split('/');
  const exists = qid => !!app.lib.question(qid);
  const due = app.progress.dueCount(exists);
  const withTabs = (html, active) => { root.innerHTML = html + tabbar(active, due); };

  if (name === 'lesson') {
    const lesson = app.lib.lesson(decodeURIComponent(id));
    if (!lesson) return withTabs(notFound('That lesson isn\'t in the library.'), 'home');
    if (sub === 'quiz') cleanup = quizScreen(root, lesson);
    else if (sub === 'done') completeScreen(root, lesson);
    else cleanup = lessonScreen(root, lesson);
    return;
  }
  if (name === 'review' && id === 'session') { cleanup = reviewSessionScreen(); return; }

  app.returnTo = location.hash || '#/';
  scrollTo(0, 0);
  if (name === 'topic') withTabs(topicScreen(decodeURIComponent(id)), 'home');
  else if (name === 'review') withTabs(reviewScreen(exists), 'review');
  else if (name === 'you') { withTabs(youScreen(), 'you'); bindYou(); }
  else if (name === 'problems') withTabs(problemsScreen(), 'home');
  else withTabs(homeScreen(exists, due), 'home');
}

const notFound = msg => `<main class="screen"><div class="empty"><h2>Not found</h2><p>${esc(msg)}</p><p style="margin-top:16px"><a class="btn" href="#/">Home</a></p></div></main>`;

// MARK: - S1 Home

function homeScreen(exists, due) {
  const { lib, progress } = app;
  const today = progress.today();
  const streak = progress.streak();
  const inProgress = lib.lessons
    .map(l => ({ l, p: progress.lesson(l.id) }))
    .filter(x => x.p.status === 'inProgress')
    .sort((a, b) => (b.p.lastOpenedAt ?? 0) - (a.p.lastOpenedAt ?? 0))[0];
  const firstNew = lib.lessons.find(l => progress.lesson(l.id).status === 'notStarted');

  let cont = '';
  if (inProgress) {
    const t = lib.topic(inProgress.l.topic), f = inProgress.p.furthestProgress ?? 0;
    const atEnd = f >= 0.97; // read to the end: only the final quiz is left
    cont = `<a class="card continue topic-scope" style="${topicStyle(t)}" href="#/lesson/${esc(inProgress.l.id)}${atEnd ? '/quiz' : ''}">
      <div class="eyebrow">${icon(t.symbol)}Continue · ${esc(t.name)}</div>
      <h2>${md(inProgress.l.title)}</h2>
      <div class="bar" role="img" aria-label="${Math.round(f * 100)} percent through"><i style="width:${f * 100}%"></i></div>
      <div class="row spread" style="margin-top:12px"><span class="muted small">${atEnd ? 'Final quiz left' : `${Math.round(f * 100)}% through · ${Math.max(1, Math.ceil(inProgress.l.minutes * (1 - f)))} min left`}</span>
      <span class="btn topic" style="min-height:40px;padding:0 16px">${atEnd ? 'Take the quiz' : 'Resume'}</span></div></a>`;
  } else if (firstNew) {
    const t = lib.topic(firstNew.topic);
    cont = `<a class="card continue topic-scope" style="${topicStyle(t)}" href="#/lesson/${esc(firstNew.id)}">
      <div class="eyebrow">${icon(t.symbol)}${progress.stats().lessonsCompleted ? 'Up next' : 'Start here'} · ${esc(t.name)}</div>
      <h2>${md(firstNew.title)}</h2><p class="muted">${md(firstNew.goal)}</p>
      <div class="row spread" style="margin-top:12px"><span class="muted small">${firstNew.minutes} min</span>
      <span class="btn topic" style="min-height:40px;padding:0 16px">Start</span></div></a>`;
  }

  const dueCard = due ? `<div class="card due-card section-gap" style="margin-top:14px">
      <div><div class="eyebrow">${icon('cards')}Due for review</div><div class="row" style="margin-top:6px"><span class="count">${due}</span><span class="muted">${due === 1 ? 'card' : 'cards'}</span></div></div>
      <a class="btn" href="#/review/session">Start review</a></div>` : '';

  const shelves = lib.topics.map(t => {
    const lessons = lib.lessonsIn(t.id);
    if (!lessons.length) return '';
    const done = lessons.filter(l => progress.isCompleted(l.id)).length;
    return `<section class="shelf topic-scope" style="${topicStyle(t)}" aria-labelledby="shelf-${t.id}">
      <a class="shelf-head" href="#/topic/${t.id}"><h2 id="shelf-${t.id}">${icon(t.symbol)}${esc(t.name)}</h2>
      <span class="row"><span class="pill" aria-label="${done} of ${lessons.length} complete">${done}/${lessons.length}</span>${icon('chevronRight')}</span></a>
      <div class="shelf-row">${lessons.map(l => lessonCard(l, t, progress)).join('')}</div></section>`;
  }).join('');

  const banner = lib.problems.length
    ? `<a class="problems-banner" href="#/problems">${icon('warning')}${plural(new Set(lib.problems.map(p => p.file)).size, 'file')} failed to load. See what's wrong.</a>` : '';

  return `<main class="screen">${banner}
    <header class="home-head">
      <div><div class="date">${formatKey(today.day, { weekday: 'long', month: 'long', day: 'numeric' })}</div><h1 class="page-title">${esc(app.name)}</h1></div>
      <div class="habit">${goalRing(today.lessonsCompleted, today.goal)}${streakChip(streak)}</div>
    </header>
    ${!streak.todayDone && streak.count ? `<p class="muted small">Do a lesson to keep your ${streak.count}-day streak.</p>` : ''}
    <div style="margin-top:18px">${cont}</div>${dueCard}${shelves}</main>`;
}

// MARK: - S2 Topic page

function topicScreen(id) {
  const { lib, progress } = app;
  const t = lib.topic(id);
  if (!t) return notFound('That topic doesn\'t exist.');
  const lessons = lib.lessonsIn(id);
  const done = lessons.filter(l => progress.isCompleted(l.id)).length;
  return `<main class="screen topic-scope" style="${topicStyle(t)}">
    <a class="back" href="#/">${icon('chevronLeft')}Home</a>
    <header class="topic-hero">${icon(t.symbol, { cls: 'big-ic' })}<h1>${esc(t.name)}</h1>
      <p class="muted">${done} of ${lessons.length} complete</p>
      <div class="progress-line" style="margin-top:10px" role="img" aria-label="${done} of ${lessons.length} lessons complete"><i style="width:${lessons.length ? (done / lessons.length) * 100 : 0}%"></i></div>
      ${t.note ? `<p class="note" style="margin-top:12px">${icon('info')}<span>${esc(t.note)}</span></p>` : ''}</header>
    <ol class="lesson-list">${lessons.map((l, i) => `<li><a href="#/lesson/${esc(l.id)}">
      <span class="num">${i + 1}</span><div><h3>${md(l.title)}</h3><p>${md(l.goal)}</p><p>${l.minutes} min</p></div>${statusIcon(l, progress)}</a></li>`).join('')}</ol>
    <p class="muted small" style="margin-top:16px">Take them in any order.</p></main>`;
}

// MARK: - S6 Review tab

function reviewScreen(exists) {
  const { lib, progress } = app;
  const today = progress.clock.today();
  const cards = progress.cards.filter(c => exists(c.questionID));
  const due = cards.filter(c => c.dueDay <= today);
  const byLesson = new Map();
  for (const c of due) byLesson.set(c.lessonID, (byLesson.get(c.lessonID) ?? 0) + 1);
  const boxes = [1, 2, 3, 4, 5].map(b => cards.filter(c => c.box === b).length);
  const maxBox = Math.max(1, ...boxes);
  const next = progress.nextReview(exists);
  const cap = progress.settings.reviewCap;

  const top = due.length
    ? `<div class="card"><div class="row spread"><div><span class="count" style="font-family:var(--serif);font-size:2.4rem;font-weight:700">${due.length}</span>
        <span class="muted"> due today</span></div><a class="btn" href="#/review/session">Start</a></div>
        ${due.length > cap ? `<p class="muted small" style="margin-top:8px">Sessions take up to ${cap}. The rest come first tomorrow.</p>` : ''}</div>
       <h2 class="section-gap" style="font-size:1.2rem">By lesson</h2>
       <ul class="due-list">${[...byLesson].map(([id, n]) => `<li><span>${md(lib.lesson(id)?.title ?? id)}</span><span class="muted">${n}</span></li>`).join('')}</ul>`
    : `<div class="empty"><h2>All caught up.</h2><p>${next ? `Next review: ${formatKey(next.day, { weekday: 'long' })} (${plural(next.count, 'card')}).`
        : cards.length ? '' : 'Answer questions in a lesson and they\'ll come back here, spaced out over days.'}</p></div>`;

  return `<main class="screen"><h1 class="page-title">Review</h1>
    <p class="muted" style="margin-bottom:18px">Missed questions come back tomorrow. Ones you get right come back later each time: 1, 3, 7, 14, then 30 days.</p>
    ${top}
    ${cards.length ? `<h2 class="section-gap" style="font-size:1.2rem">Your boxes</h2>
    <div class="card"><div class="hist" role="img" aria-label="Cards per box: ${boxes.map((n, i) => `box ${i + 1}, ${n}`).join('; ')}">
      ${boxes.map((n, i) => `<div><span>${n}</span><i style="height:${(n / maxBox) * 80}%"></i><span>Box ${i + 1}</span></div>`).join('')}</div>
      <p class="muted small" style="margin-top:10px">Box 1 = due tomorrow, box 5 = every 30 days.</p></div>` : ''}</main>`;
}

// MARK: - S7/S8 Review session

function reviewSessionScreen() {
  const { lib, progress } = app;
  const exists = qid => !!lib.question(qid);
  const session = new ReviewSession(progress.reviewQueue(exists), (card, correct) => {
    const q = lib.question(card.questionID);
    return progress.answer({ lessonID: card.lessonID, questionID: card.questionID, localID: q.question.id, choice: null, correct, context: 'review' });
  });
  let picked = null;

  const draw = () => {
    if (session.done) return summary();
    const item = session.current;
    const q = lib.question(item.card.questionID);
    const t = lib.topic(q.lesson.topic);
    root.innerHTML = `<div class="topic-scope" style="${topicStyle(t)}">
      <header class="topbar"><a class="icon-btn" href="#/review" aria-label="End review">${icon('close')}</a>
        <div class="track" role="progressbar" aria-label="Review progress" aria-valuenow="${Math.round((session.index / session.total) * 100)}"><i style="width:${(session.index / session.total) * 100}%"></i></div>
        <span class="left">${session.index + 1} / ${session.total}</span></header>
      <main class="quiz">
        <div class="eyebrow">${icon(t.symbol)}${md(q.lesson.title)} · Box ${item.card.box}</div>
        ${item.practice ? '<p style="margin-top:8px"><span class="practice-tag">Second try · practice only</span></p>' : ''}
        <div style="margin-top:14px">${questionCard(q.question, q.globalID, { picked, context: 'review', headingLevel: 1 })}</div>
        <div class="quiz-foot">${picked !== null ? `<button class="btn topic block" type="button" data-next>${session.index + 1 < session.total || (!item.practice && picked !== correctChoice(q.question)) ? 'Next' : 'Finish'} ${icon('arrowRight')}</button>` : ''}</div>
      </main></div>`;
    scrollTo(0, 0);
    root.querySelector('[data-next]')?.focus({ preventScroll: true });
  };

  const summary = () => {
    const s = session.summary();
    root.innerHTML = `<main class="complete">
      <svg class="big-check" viewBox="0 0 96 96" fill="none" stroke="currentColor" stroke-width="5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" style="color:var(--ink)">
        <circle cx="48" cy="48" r="42" pathLength="1"/><path d="M30 50l12 12 24-26" pathLength="1"/></svg>
      <h1 tabindex="-1">${s.reviewed ? 'Review done' : 'Nothing due'}</h1>
      ${s.reviewed ? `<div class="score">${s.right}/${s.reviewed}</div><p class="muted">right on the first try</p>
      <div class="card" style="width:100%"><p><strong>${s.movedUp}</strong> moved up a box · <strong>${s.backToOne}</strong> back to box 1</p>
      <p class="muted small" style="margin-top:6px">Reviews don't count toward the daily goal; lessons do.</p></div>` : '<p class="muted">Come back when cards are due.</p>'}
      <div class="full-actions"><a class="btn block" href="#/review">Done</a></div></main>`;
    root.querySelector('h1')?.focus({ preventScroll: true });
  };

  function onClick(e) {
    const btn = e.target.closest('.choice');
    if (btn && picked === null && !session.done) {
      picked = btn.dataset.choice;
      const q = lib.question(session.current.card.questionID);
      session.answer(picked === correctChoice(q.question));
      draw();
      return;
    }
    if (e.target.closest('[data-next]')) { session.next(); picked = null; draw(); }
  }
  root.addEventListener('click', onClick);
  draw();
  return () => root.removeEventListener('click', onClick);
}

// MARK: - S9 You

function youScreen() {
  const { progress } = app;
  const streak = progress.streak();
  const today = progress.clock.today();
  const firstDay = progress.clock.firstDay();
  const { y, m } = parts(today);
  const first = makeKey(y, m, 1);
  const lead = (weekday(first) - firstDay + 7) % 7;
  const cells = [];
  for (let i = 0; i < 7; i++) cells.push(`<div class="dow" aria-hidden="true">${formatKey(addDays(first, i - lead), { weekday: 'narrow' })}</div>`);
  for (let i = 0; i < lead; i++) cells.push('<div></div>');
  for (let d = first; parts(d).m === m; d = addDays(d, 1)) {
    const s = d <= today ? streak.status(d) : 'future';
    const label = `${formatKey(d, { month: 'long', day: 'numeric' })}${{ done: ', goal met', frozen: ', freeze used', forgiven: ', skipped by time-zone change', missed: ', missed' }[s] ?? ''}`;
    cells.push(`<div class="d s-${s}${d === today ? ' today' : ''}" role="img" aria-label="${label}">${parts(d).d}</div>`);
  }
  const st = progress.stats();
  const set = progress.settings;
  const time = `${String(set.reminderHour).padStart(2, '0')}:${String(set.reminderMinute).padStart(2, '0')}`;

  return `<main class="screen"><h1 class="page-title">You</h1>
    <div class="card" style="margin-top:12px">
      <div class="big-streak">${icon('stack')}<div><span class="n">${streak.count}</span> <span class="muted">${streak.count === 1 ? 'day' : 'days'} streak</span>
      <div class="muted small">${streak.todayDone ? 'Today is done.' : streak.count ? 'Do a lesson today to keep it going.' : 'Finish a lesson to start one.'} ${streak.freezeAvailableThisWeek ? 'Weekly freeze ready.' : 'Freeze used this week.'}</div></div></div>
      <h2 style="font-size:1.05rem;margin-top:18px">${formatKey(first, { month: 'long', year: 'numeric' })}</h2>
      <div class="cal">${cells.join('')}</div>
      <div class="legend-line" style="margin-top:10px" aria-hidden="true"><span><i class="s-done"></i>goal met</span><span><i class="s-frozen"></i>freeze used</span><span><i class="s-missed"></i>missed</span></div>
    </div>
    <div class="card stats section-gap" style="margin-top:14px">
      <div><b>${st.lessonsCompleted}</b><span>lessons done</span></div>
      <div><b>${st.cards}</b><span>review cards</span></div>
      <div><b>${st.accuracy === null ? '–' : Math.round(st.accuracy * 100) + '%'}</b><span>answers right</span></div>
    </div>
    <h2 class="section-gap" style="font-size:1.2rem;margin-bottom:8px">Settings</h2>
    <div class="card" style="padding-top:4px;padding-bottom:4px">
      <div class="setting"><div><div class="label" id="goal-l">Daily goal</div><div class="help">Lessons per day. Changing it never rewrites past days.</div></div>
        <div class="seg" role="group" aria-labelledby="goal-l">${[1, 2, 3].map(n => `<button type="button" data-goal="${n}" aria-pressed="${set.dailyGoal === n}">${n}</button>`).join('')}</div></div>
      <div class="setting"><div><label for="cap">Review limit</label><div class="help">Most cards in one session.</div></div>
        <select id="cap">${[10, 20, 30, 50].map(n => `<option ${set.reviewCap === n ? 'selected' : ''}>${n}</option>`).join('')}</select></div>
      <div class="setting"><div><label for="rtime">Daily reminder</label><div class="help">The web can't send reminders on its own, so this adds a repeating event to your calendar.</div></div>
        <div style="display:flex;flex-direction:column;gap:8px;align-items:flex-end"><input id="rtime" type="time" value="${time}"><button class="btn quiet" type="button" data-reminder style="min-height:40px">Add to calendar</button></div></div>
      <div class="setting"><div><div class="label">Motion</div><div class="help">Scroll animations follow your device's Reduce Motion setting${matchMedia('(prefers-reduced-motion: reduce)').matches ? ' (on: animations are off)' : ''}.</div></div></div>
      <div class="setting"><div><div class="label">Reset progress</div><div class="help">Deletes lessons, review cards and streak on this device.</div></div>
        <button class="btn quiet danger" type="button" data-reset style="min-height:40px">Reset</button></div>
    </div>
    <h2 class="section-gap" style="font-size:1.2rem;margin-bottom:8px">About</h2>
    <div class="card stack small">
      <p><strong>${esc(app.name)}</strong> · version ${esc(app.version)}</p>
      <p><strong>How content is sourced.</strong> Every lesson lists 2–4 sources at the end. Numbers, dates and quotes are checked against them; worked math is labeled "Worked example", made-up chart data is labeled "Illustrative", and claims scholars dispute are marked "Contested".</p>
      <p><strong>Privacy.</strong> No accounts, analytics or trackers. Your progress stays in this browser on this device. Source links open only when you tap them.</p>
    </div></main>`;
}

function bindYou() {
  const { progress } = app;
  root.querySelector('main').addEventListener('click', e => {
    const goal = e.target.closest('[data-goal]');
    if (goal) { progress.setSetting('dailyGoal', Number(goal.dataset.goal)); route(); }
    if (e.target.closest('[data-reminder]')) downloadReminder(progress.settings);
    if (e.target.closest('[data-reset]') && confirm('Reset all progress? Lessons, review cards and your streak on this device will be deleted. This can\'t be undone.')) {
      progress.reset();
      route();
    }
  });
  root.querySelector('#cap').addEventListener('change', e => progress.setSetting('reviewCap', Number(e.target.value)));
  root.querySelector('#rtime').addEventListener('change', e => {
    const [h, m] = e.target.value.split(':').map(Number);
    if (!Number.isNaN(h)) { progress.setSetting('reminderHour', h); progress.setSetting('reminderMinute', m); }
  });
}

// MARK: - S10 Content problems

function problemsScreen() {
  return `<main class="screen"><a class="back" href="#/">${icon('chevronLeft')}Home</a><h1 class="page-title">Content problems</h1>
    <p class="muted">These files were skipped. For the full check, run <code>swift run --package-path Packages/LessonKit validate-lessons Content</code>.</p>
    <ul class="problem-list">${app.lib.problems.map(p => `<li><strong>${esc(p.file)}</strong><br>${esc(p.message)}</li>`).join('')}</ul></main>`;
}

// MARK: - Offline

function registerOffline() {
  if (!('serviceWorker' in navigator)) return;
  navigator.serviceWorker.register('sw.js').then(() => navigator.serviceWorker.ready).then(reg => {
    // Cache everything this visit loaded (app files and every lesson), so the next visit works offline.
    const urls = new Set(['./', 'app-config.json', 'manifest.webmanifest', 'content/index.json', 'content/topics.json']);
    for (const e of performance.getEntriesByType('resource')) if (e.name.startsWith(location.origin)) urls.add(e.name);
    reg.active?.postMessage({ type: 'cache', urls: [...urls] });
  }).catch(e => console.warn('Offline mode unavailable', e));
}

boot().catch(e => {
  root.innerHTML = `<main class="screen"><div class="empty"><h2>Couldn't start</h2><p>${esc(e.message)}</p></div></main>`;
  console.error(e);
});
