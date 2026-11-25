// The scroll lesson (S3), the final quiz (S4) and Lesson complete (S5).
import { app, esc, md, icon, topicStyle, goalRing, streakChip, weekDots, downloadReminder } from './ui.js';
import { renderSection, questionCard } from './render/sections.js';
import { hydrate, clearRegistry } from './render/visuals.js';
import { setShown, build } from './render/stage.js';
import { citation, correctChoice, inlineQuestions, globalID } from './content.js';
import { plural } from './text.js';

const reduceMotion = () => matchMedia('(prefers-reduced-motion: reduce)').matches;

// MARK: - S3 scroll lesson

export function lessonScreen(root, lesson) {
  const { lib, progress } = app;
  const topic = lib.topic(lesson.topic);
  const p = progress.openLesson(lesson);
  clearRegistry();

  const sources = lesson.sources.map(s => `<li id="src-${esc(s.id)}">${esc(citation(s))}${s.url ? ` <a href="${esc(s.url)}" target="_blank" rel="noopener">Open source</a>` : ''}</li>`).join('');
  root.innerHTML = `<div class="lesson-screen topic-scope" style="${topicStyle(topic)}">
    <header class="topbar">
      <a class="icon-btn" href="${esc(app.returnTo ?? '#/')}" aria-label="Close lesson">${icon('close')}</a>
      <div class="track" role="progressbar" aria-label="Lesson progress" aria-valuemin="0" aria-valuemax="100" aria-valuenow="0"><i></i></div>
      <span class="left" aria-live="off">${lesson.minutes} min</span>
    </header>
    <article class="lesson">
      <header class="lesson-header">
        <div class="eyebrow">${icon(topic.symbol)}${esc(topic.name)} · ${lesson.minutes} min</div>
        <h1>${md(lesson.title)}</h1>
        <p class="goal">${md(lesson.goal)}</p>
        ${topic.note ? `<p class="note">${icon('info')}<span>${esc(topic.note)}</span></p>` : ''}
      </header>
      ${lesson.sections.map(s => renderSection(s, lesson, p.answers)).join('')}
      <section class="sources" aria-labelledby="sources-h">
        <h2 id="sources-h">Sources</h2><ol>${sources}</ol>
        ${lesson.factCheck ? `<p class="factcheck">Fact-checked ${esc(lesson.factCheck.checkedOn)}. ${esc(lesson.factCheck.notes)}</p>` : ''}
      </section>
      <div class="lesson-end">
        <p>Five questions to lock it in. They join your review deck.</p>
        <a class="btn topic block" href="#/lesson/${esc(lesson.id)}/quiz">Take the final quiz ${icon('arrowRight')}</a>
      </div>
    </article>
    <div class="resume-pill hide" role="status"><span>Resumed where you left off</span><button type="button" data-start-over>Start over</button></div>
  </div>`;

  const screen = root.firstElementChild;
  const article = screen.querySelector('.lesson');
  const bar = screen.querySelector('.track');
  const left = screen.querySelector('.left');
  const sections = [...article.querySelectorAll('.layer')];
  const visible = new Set();
  const cancels = [];
  const sda = CSS.supports?.('animation-timeline: view()');
  document.documentElement.classList.toggle('no-sda', !sda);

  hydrate(article);
  if (reduceMotion()) for (const st of article.querySelectorAll('.staged')) setShown(st, Number(st.dataset.total), { instant: true });

  const topH = () => screen.querySelector('.topbar').offsetHeight;

  // Layer B: start each section's builds the first time 35% of it (or of the screen) is visible.
  function checkVisible() {
    const top = topH(), viewport = innerHeight - top;
    for (const el of sections) {
      const r = el.getBoundingClientRect();
      if (!sda && r.top < innerHeight * 0.92) el.classList.add('in');
      if (visible.has(el)) continue;
      const shown = Math.min(r.bottom - top, viewport) - Math.max(r.top - top, 0);
      if (r.height > 0 && shown >= 0.35 * Math.min(r.height, viewport)) {
        visible.add(el);
        if (reduceMotion()) continue;
        for (const st of el.querySelectorAll('.staged')) {
          if (Number(st.dataset.shown ?? 0) > 0) continue;
          cancels.push(build(st, { stagger: Number(st.dataset.stagger ?? 260) }));
        }
      }
    }
  }

  // Progress bar and minutes left.
  function updateProgress() {
    const max = document.documentElement.scrollHeight - innerHeight;
    const f = max > 0 ? Math.min(1, Math.max(0, scrollY / max)) : 0;
    bar.firstElementChild.style.width = `${f * 100}%`;
    bar.setAttribute('aria-valuenow', Math.round(f * 100));
    const mins = Math.max(0, Math.ceil(lesson.minutes * (1 - f)));
    left.textContent = f > 0.98 ? 'Done' : `${mins} min left`;
    return f;
  }

  // Resume point: the top-most visible section, and how far into it.
  function anchor() {
    const top = topH();
    const el = sections.find(s => s.getBoundingClientRect().bottom > top + 1);
    if (!el) return { anchorSectionID: sections.at(-1)?.dataset.sid ?? null, anchorFraction: 1 };
    const r = el.getBoundingClientRect();
    if (el === sections[0] && r.top > top) return { anchorSectionID: null, anchorFraction: 0 };
    return { anchorSectionID: el.dataset.sid, anchorFraction: Math.max(0, (top - r.top) / r.height) };
  }

  let saveTimer = null;
  const save = () => { clearTimeout(saveTimer); progress.saveResume(lesson.id, { ...anchor(), progress: updateProgress() }); };

  let ticking = false;
  const onScroll = () => {
    checkVisible(); // every event, so a fast fling can't skip past a visual
    clearTimeout(saveTimer);
    saveTimer = setTimeout(save, 800);
    if (ticking) return;
    ticking = true;
    requestAnimationFrame(() => { ticking = false; updateProgress(); });
  };
  const onHide = () => { if (document.visibilityState === 'hidden') save(); };

  addEventListener('scroll', onScroll, { passive: true });
  addEventListener('resize', onScroll);
  document.addEventListener('visibilitychange', onHide);
  addEventListener('pagehide', save);

  // Inline checks
  article.addEventListener('click', e => {
    const btn = e.target.closest('.choice');
    const card = btn?.closest('.qcard');
    if (!btn || !card || btn.getAttribute('aria-disabled') === 'true') return;
    const localID = card.dataset.local;
    const q = lesson.sections.flatMap(s => s.questions ?? []).find(x => x.id === localID);
    const choice = btn.dataset.choice;
    progress.answer({ lessonID: lesson.id, questionID: card.dataset.q, localID, choice, correct: choice === correctChoice(q), context: 'inline' });
    card.outerHTML = questionCard(q, card.dataset.q, { picked: choice, context: 'inline', localID });
    article.querySelector(`.qcard[data-q="${CSS.escape(card.dataset.q)}"] .choice[data-choice="${CSS.escape(choice)}"]`)?.focus();
  });

  // Restore the saved position (after layout), then show the "Resumed" pill.
  history.scrollRestoration = 'manual';
  const pill = screen.querySelector('.resume-pill');
  const target = p.anchorSectionID
    ? (article.querySelector(`[data-sid="${CSS.escape(p.anchorSectionID)}"]`) ?? null)
    : null;
  const restore = () => {
    if (!target) { scrollTo(0, 0); return; }
    const y = target.getBoundingClientRect().top + scrollY - topH() + p.anchorFraction * target.offsetHeight;
    scrollTo({ top: y, behavior: 'instant' });
  };
  restore();
  requestAnimationFrame(() => { restore(); updateProgress(); checkVisible(); });
  if (target) {
    pill.classList.remove('hide');
    const hideTimer = setTimeout(() => pill.classList.add('hide'), 4000);
    cancels.push(() => clearTimeout(hideTimer));
  }
  pill.querySelector('[data-start-over]').addEventListener('click', () => {
    progress.startOver(lesson.id);
    pill.classList.add('hide');
    app.rerender();
  });

  return () => {
    save();
    cancels.forEach(c => c());
    removeEventListener('scroll', onScroll);
    removeEventListener('resize', onScroll);
    document.removeEventListener('visibilitychange', onHide);
    removeEventListener('pagehide', save);
  };
}

// MARK: - S4 final quiz

export function quizScreen(root, lesson) {
  const { lib, progress } = app;
  const topic = lib.topic(lesson.topic);
  const qs = lesson.finalQuiz;
  let index = 0, score = 0, picked = null;

  const draw = () => {
    const q = qs[index];
    const gid = globalID(lesson.id, q.id);
    root.innerHTML = `<div class="topic-scope" style="${topicStyle(topic)}">
      <header class="topbar">
        <a class="icon-btn" href="#/lesson/${esc(lesson.id)}" aria-label="Back to the lesson">${icon('chevronLeft')}</a>
        <div class="dots" style="flex:1" role="img" aria-label="Question ${index + 1} of ${qs.length}">${qs.map((_, i) => `<i class="${i < index ? 'done' : i === index ? 'now' : ''}"></i>`).join('')}</div>
        <span class="left">${index + 1} / ${qs.length}</span>
      </header>
      <main class="quiz">
        <div class="eyebrow">Final quiz · ${md(lesson.title)}</div>
        <div style="margin-top:14px">${questionCard(q, gid, { picked, context: 'final', headingLevel: 1 })}</div>
        <div class="quiz-foot">${picked !== null
          ? `<button class="btn topic block" type="button" data-next>${index + 1 < qs.length ? 'Next question' : 'See results'} ${icon('arrowRight')}</button>` : ''}</div>
      </main></div>`;
    scrollTo(0, 0);
    root.querySelector(picked !== null ? '[data-next]' : 'h1')?.focus?.({ preventScroll: true });
  };

  root.addEventListener('click', onClick);
  function onClick(e) {
    const q = qs[index];
    const btn = e.target.closest('.choice');
    if (btn && picked === null) {
      picked = btn.dataset.choice;
      const correct = picked === correctChoice(q);
      if (correct) score += 1;
      progress.answer({ lessonID: lesson.id, questionID: globalID(lesson.id, q.id), localID: q.id, choice: picked, correct, context: 'final' });
      draw();
      return;
    }
    if (e.target.closest('[data-next]')) {
      if (index + 1 < qs.length) { index += 1; picked = null; draw(); return; }
      const result = progress.completeLesson(lesson, { score, inlineQuestionIDs: inlineQuestions(lesson) });
      app.lastResult = { lessonID: lesson.id, score, total: qs.length, ...result };
      app.go(`#/lesson/${lesson.id}/done`);
    }
  }
  draw();
  return () => root.removeEventListener('click', onClick);
}

// MARK: - S5 lesson complete

export function completeScreen(root, lesson) {
  const { lib, progress } = app;
  const topic = lib.topic(lesson.topic);
  const r = app.lastResult?.lessonID === lesson.id ? app.lastResult : null;
  const pl = progress.lesson(lesson.id);
  const score = r?.score ?? pl.lastScore ?? 0;
  const today = progress.today();
  const streak = progress.streak();
  const next = lib.nextInTopic(lesson);
  const offerReminder = !progress.flag('reminderOffered');

  root.innerHTML = `<main class="complete topic-scope" style="${topicStyle(topic)}">
    <svg class="big-check" viewBox="0 0 96 96" fill="none" stroke="currentColor" stroke-width="5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
      <circle cx="48" cy="48" r="42" pathLength="1"/><path d="M30 50l12 12 24-26" pathLength="1"/></svg>
    <div><div class="eyebrow" style="justify-content:center">${icon(topic.symbol)}${esc(topic.name)}</div>
      <h1 tabindex="-1">${md(lesson.title)}</h1></div>
    <div><div class="score">${score}/${lesson.finalQuiz.length}</div><p class="muted">on the final quiz</p></div>
    ${r ? `<p><strong>+${plural(r.added, 'card')}</strong> added to your review deck</p>` : ''}
    <div class="card" style="width:100%">
      <div class="row spread">
        <div class="row">${goalRing(today.lessonsCompleted, today.goal)}<div style="text-align:left">
          <strong>${today.goalMet ? 'Daily goal met' : `${today.lessonsCompleted} of ${today.goal} today`}</strong>
          <div class="muted small">${today.goalMet ? 'See you tomorrow.' : `${today.goal - today.lessonsCompleted} more to meet today's goal.`}</div></div></div>
        ${streakChip(streak)}
      </div>
      <div style="margin-top:16px">${weekDots(streak, today.day, progress.clock.firstDay())}</div>
      <p class="muted small" style="margin-top:10px">${streak.freezeAvailableThisWeek ? 'Your weekly freeze is ready: one missed day this week won\'t break your streak.' : 'This week\'s freeze is used.'}</p>
    </div>
    ${offerReminder ? `<div class="card" style="width:100%;text-align:left" data-reminder-offer>
      <div class="row" style="align-items:flex-start">${icon('bell')}<div><strong>Want a daily reminder?</strong>
      <p class="muted small" style="margin-top:4px">Adds a repeating event at ${String(progress.settings.reminderHour).padStart(2, '0')}:${String(progress.settings.reminderMinute).padStart(2, '0')} to your calendar. You can change the time in You.</p></div></div>
      <div class="row" style="margin-top:12px"><button class="btn" type="button" data-add-reminder>Add to calendar</button><button class="btn quiet" type="button" data-no-reminder>Not now</button></div></div>` : ''}
    <div class="full-actions">
      ${next ? `<a class="btn topic block" href="#/lesson/${esc(next.id)}">Next: ${md(next.title)}</a>` : ''}
      <a class="btn quiet block" href="${esc(app.returnTo ?? '#/')}">Done</a>
    </div></main>`;
  root.querySelector('h1')?.focus({ preventScroll: true });
  scrollTo(0, 0);
  const offer = root.querySelector('[data-reminder-offer]');
  offer?.addEventListener('click', e => {
    if (e.target.closest('[data-add-reminder]')) downloadReminder(progress.settings);
    if (e.target.closest('[data-add-reminder],[data-no-reminder]')) { progress.setFlag('reminderOffered'); offer.remove(); }
  });
}
