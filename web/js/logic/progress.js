// Everything you've done, as one plain object saved on this device (SPEC.md §7, adapted for the web:
// localStorage instead of SwiftData). Lesson content is never stored here, only your state, keyed
// by stable IDs, so editing a lesson never needs a migration. No DOM in this file, so tests can run it.
import { schedule, dueQueue, dueCount, nextReview } from './leitner.js';
import { computeStreak } from './streak.js';
import { dayKeyOf, utcOffsetOf, regionFirstDay } from './daykey.js';

export const DEFAULT_SETTINGS = { dailyGoal: 1, reviewCap: 20, reminderHour: 19, reminderMinute: 0 };
const MAX_EVENTS = 5000;

export const systemClock = {
  now: () => Date.now(),
  today: () => dayKeyOf(new Date()),
  offset: () => utcOffsetOf(new Date()),
  firstDay: () => regionFirstDay(),
};

export function emptyState() {
  return { version: 1, settings: { ...DEFAULT_SETTINGS }, lessons: {}, cards: {}, events: [], activity: {}, flags: {} };
}

export class Progress {
  constructor({ load = () => null, save = () => {}, clock = systemClock } = {}) {
    this.saveFn = save;
    this.clock = clock;
    const loaded = load();
    this.state = { ...emptyState(), ...(loaded ?? {}) };
    this.state.settings = { ...DEFAULT_SETTINGS, ...this.state.settings };
    this.listeners = new Set();
  }

  // MARK: persistence

  commit() {
    if (this.state.events.length > MAX_EVENTS) this.state.events.splice(0, this.state.events.length - MAX_EVENTS);
    this.saveFn(this.state);
    for (const f of this.listeners) f();
  }
  onChange(f) { this.listeners.add(f); return () => this.listeners.delete(f); }

  get settings() { return this.state.settings; }
  setSetting(key, value) { this.state.settings[key] = value; this.commit(); }
  flag(name) { return !!this.state.flags[name]; }
  setFlag(name) { this.state.flags[name] = true; this.commit(); }

  reset() {
    const settings = this.state.settings;
    this.state = { ...emptyState(), settings };
    this.commit();
  }

  // MARK: lessons

  lesson(id) {
    return this.state.lessons[id] ?? {
      status: 'notStarted', anchorSectionID: null, anchorFraction: 0, furthestProgress: 0,
      completionCount: 0, bestFinalScore: null, answers: {},
    };
  }

  isCompleted(id) { return (this.state.lessons[id]?.completionCount ?? 0) > 0; }

  /** Opening a lesson. A finished lesson reopens at the top as a fresh pass (a retake). */
  openLesson(lesson) {
    const now = this.clock.now();
    const p = this.lesson(lesson.id);
    if (p.status === 'notStarted') {
      Object.assign(p, { status: 'inProgress', startedAt: now, passStartedAt: now });
    } else if (p.status === 'completed' && p.finishedPass) {
      Object.assign(p, { anchorSectionID: null, anchorFraction: 0, answers: {}, passStartedAt: now, finishedPass: false });
    }
    p.lastOpenedAt = now;
    p.contentVersionSeen = lesson.contentVersion;
    this.state.lessons[lesson.id] = p;
    this.commit();
    return p;
  }

  saveResume(id, { anchorSectionID, anchorFraction, progress }) {
    const p = this.lesson(id);
    p.anchorSectionID = anchorSectionID;
    p.anchorFraction = Math.max(0, Math.min(1, anchorFraction));
    p.lastProgress = progress;
    if (p.status !== 'completed') p.furthestProgress = Math.max(p.furthestProgress ?? 0, progress);
    this.state.lessons[id] = p;
    this.commit();
  }

  /** "Start over": back to the top with fresh inline checks. Review history is kept. */
  startOver(id) {
    const p = this.lesson(id);
    Object.assign(p, { anchorSectionID: null, anchorFraction: 0, answers: {}, passStartedAt: this.clock.now() });
    this.state.lessons[id] = p;
    this.commit();
  }

  // MARK: answers → review cards

  card(questionID) { return this.state.cards[questionID] ?? null; }
  get cards() { return Object.values(this.state.cards); }

  /**
   * Records one answer. context: 'inline' | 'final' | 'review'.
   * Returns { created, before, after } (box numbers) so screens can show what moved.
   */
  answer({ lessonID, questionID, localID, choice, correct, context }) {
    const now = this.clock.now(), today = this.clock.today();
    const existing = this.card(questionID);
    const before = existing?.box ?? null; // read before the card is updated in place
    const next = schedule(existing, { correct, context, today });
    const card = existing ?? { questionID, lessonID, createdAt: now, correctCount: 0, wrongCount: 0 };
    Object.assign(card, next, { lastAnsweredAt: now });
    if (correct) card.correctCount += 1; else card.wrongCount += 1;
    this.state.cards[questionID] = card;
    this.state.events.push({ questionID, lessonID, answeredAt: now, day: today, context, correct,
                             boxBefore: before, boxAfter: card.box });
    if (context === 'inline') {
      const p = this.lesson(lessonID);
      p.answers = { ...p.answers, [localID]: choice };
      this.state.lessons[lessonID] = p;
    }
    if (context === 'review') this.touchActivity(a => { a.reviewsAnswered += 1; });
    this.commit();
    return { created: !existing, before, after: card.box };
  }

  /**
   * Finishing the final quiz (at any score). Inline questions you skipped become box-1 cards due
   * tomorrow, since unseen counts as not yet known. Counts toward today's goal, retakes included.
   */
  completeLesson(lesson, { score, inlineQuestionIDs }) {
    const now = this.clock.now(), today = this.clock.today();
    for (const { globalID } of inlineQuestionIDs) {
      if (!this.state.cards[globalID]) {
        this.state.cards[globalID] = { questionID: globalID, lessonID: lesson.id, createdAt: now,
          correctCount: 0, wrongCount: 0, lastAnsweredAt: null,
          ...schedule(null, { correct: false, context: 'unseen', today }) };
      }
    }
    const p = this.lesson(lesson.id);
    const passStart = p.passStartedAt ?? p.startedAt ?? 0;
    const added = this.cards.filter(c => c.lessonID === lesson.id && c.createdAt >= passStart).length;
    Object.assign(p, {
      status: 'completed', finishedPass: true, furthestProgress: 1,
      firstCompletedAt: p.firstCompletedAt ?? now,
      completionCount: (p.completionCount ?? 0) + 1,
      bestFinalScore: Math.max(p.bestFinalScore ?? 0, score),
      lastScore: score,
    });
    this.state.lessons[lesson.id] = p;
    let goalMetNow = false;
    this.touchActivity(a => {
      a.lessonsCompleted += 1;
      if (!a.goalMet && a.lessonsCompleted >= a.goalAtTime) { a.goalMet = true; goalMetNow = true; }
    });
    this.commit();
    return { added, goalMetNow };
  }

  // MARK: activity, goal, streak

  /** Today's activity row, created on first use with the goal as it is now (never rewritten later). */
  touchActivity(update) {
    const now = this.clock.now(), day = this.clock.today(), offset = this.clock.offset();
    const a = this.state.activity[day] ?? {
      day, lessonsCompleted: 0, reviewsAnswered: 0, goalAtTime: this.settings.dailyGoal, goalMet: false,
      firstActivityAt: now, firstUTCOffset: offset,
    };
    a.lastActivityAt = now;
    a.lastUTCOffset = offset;
    update(a);
    this.state.activity[day] = a;
  }

  today() {
    const day = this.clock.today();
    const a = this.state.activity[day];
    const goal = a?.goalAtTime ?? this.settings.dailyGoal;
    return { day, lessonsCompleted: a?.lessonsCompleted ?? 0, goal, goalMet: !!a?.goalMet };
  }

  streak() {
    return computeStreak({
      days: Object.values(this.state.activity),
      today: this.clock.today(), now: this.clock.now(), currentOffset: this.clock.offset(),
      firstDay: this.clock.firstDay(),
    });
  }

  // MARK: review

  reviewQueue(exists) {
    return dueQueue(this.cards, { today: this.clock.today(), exists, cap: this.settings.reviewCap });
  }
  dueCount(exists) { return dueCount(this.cards, { today: this.clock.today(), exists }); }
  nextReview(exists) { return nextReview(this.cards, { today: this.clock.today(), exists }); }

  stats() {
    const reviewish = this.state.events;
    const right = reviewish.filter(e => e.correct).length;
    return {
      lessonsCompleted: Object.values(this.state.lessons).filter(l => l.completionCount > 0).length,
      cards: this.cards.length,
      answers: reviewish.length,
      accuracy: reviewish.length ? right / reviewish.length : null,
    };
  }
}
