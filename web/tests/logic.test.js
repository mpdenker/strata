import { test, eq, ok } from './harness.js';
import { addDays, daysBetween, weekday, weekStart, dayKeyOf } from '../js/logic/daykey.js';
import { schedule, dueQueue, nextReview } from '../js/logic/leitner.js';
import { computeStreak } from '../js/logic/streak.js';
import { Progress } from '../js/logic/progress.js';
import { ReviewSession } from '../js/logic/session.js';

// MARK: - Day keys

test('day math across month, year and leap-day ends', () => {
  eq(addDays(20261231, 3), 20270103, 'Dec 31 + 3');
  eq(addDays(20280228, 1), 20280229, 'leap year');
  eq(addDays(20270228, 1), 20270301, 'non-leap year');
  eq(addDays(20261101, -1), 20261031);
  eq(daysBetween(20261124, 20261201), 7);
});

test('day math across daylight-saving nights stays one day per day', () => {
  eq(addDays(20260307, 1), 20260308, 'US spring forward is Mar 8 2026');
  eq(addDays(20260308, 1), 20260309);
  eq(addDays(20261031, 1), 20261101, 'US fall back is Nov 1 2026');
  eq(addDays(20261101, 1), 20261102);
  eq(daysBetween(20260307, 20260309), 2);
});

test('weekdays and week starts (Monday-start and Sunday-start regions)', () => {
  eq(weekday(20261124), 2, 'Tue');
  eq(weekday(20261122), 7, 'Sun');
  eq(weekStart(20261124, 1), 20261123);
  eq(weekStart(20261124, 7), 20261122);
  eq(weekStart(20261122, 1), 20261116, 'Sunday belongs to the week before when weeks start Monday');
  eq(weekStart(20261122, 7), 20261122);
});

test('the date depends on where you are (date line and DST instants)', () => {
  const instant = new Date(Date.UTC(2026, 10, 25, 4, 0)); // 04:00 UTC Nov 25
  eq(dayKeyOf(instant, 'America/Los_Angeles'), 20261124);
  eq(dayKeyOf(instant, 'Asia/Tokyo'), 20261125);
  // 1:59 and 3:01 on the New York spring-forward night are the same date.
  eq(dayKeyOf(new Date(Date.UTC(2026, 2, 8, 6, 59)), 'America/New_York'), 20260308);
  eq(dayKeyOf(new Date(Date.UTC(2026, 2, 8, 7, 1)), 'America/New_York'), 20260308);
});

// MARK: - Leitner

const T = 20261124;

test('first answer: right → box 2 in 3 days; wrong → box 1 tomorrow', () => {
  eq(schedule(null, { correct: true, context: 'inline', today: T }), { box: 2, dueDay: 20261127 });
  eq(schedule(null, { correct: false, context: 'final', today: T }), { box: 1, dueDay: 20261125 });
});

test('skipped inline question becomes box 1 tomorrow', () => {
  eq(schedule(null, { correct: false, context: 'unseen', today: T }), { box: 1, dueDay: 20261125 });
});

test('review right moves up one box with the longer interval', () => {
  const expected = { 1: [2, 20261127], 2: [3, 20261201], 3: [4, 20261208], 4: [5, 20261224] };
  for (const [box, [nb, due]] of Object.entries(expected)) {
    eq(schedule({ box: +box, dueDay: T }, { correct: true, context: 'review', today: T }), { box: nb, dueDay: due }, `box ${box}`);
  }
});

test('box 5 is the ceiling: right stays 5 for 30 days, wrong drops to 1', () => {
  eq(schedule({ box: 5, dueDay: T }, { correct: true, context: 'review', today: T }), { box: 5, dueDay: 20261224 });
  eq(schedule({ box: 5, dueDay: T }, { correct: false, context: 'review', today: T }), { box: 1, dueDay: 20261125 });
});

test('review wrong goes back to box 1 tomorrow', () => {
  eq(schedule({ box: 4, dueDay: T }, { correct: false, context: 'review', today: T }), { box: 1, dueDay: 20261125 });
});

test('retaking a lesson: right changes nothing, wrong resets to box 1', () => {
  const card = { box: 3, dueDay: 20261130 };
  eq(schedule(card, { correct: true, context: 'final', today: T }), card);
  eq(schedule(card, { correct: false, context: 'inline', today: T }), { box: 1, dueDay: 20261125 });
});

test('due queue: overdue included, most overdue first, then lower box, capped', () => {
  const cards = [
    { questionID: 'a', box: 3, dueDay: T },
    { questionID: 'b', box: 1, dueDay: T },
    { questionID: 'c', box: 2, dueDay: 20261120 },
    { questionID: 'd', box: 1, dueDay: 20261125 },
    { questionID: 'gone', box: 1, dueDay: 20261101 },
  ];
  const q = dueQueue(cards, { today: T, exists: id => id !== 'gone', cap: 20 });
  eq(q.map(c => c.questionID), ['c', 'b', 'a']);
  eq(dueQueue(cards, { today: T, exists: id => id !== 'gone', cap: 2 }).length, 2);
  eq(nextReview(cards, { today: T }), { day: 20261125, count: 1 });
});

test('wrong answer comes back in a later review; right one is pushed further out', () => {
  let today = T;
  const p = new Progress({ clock: clockAt(() => today) });
  p.answer({ lessonID: 'l', questionID: 'l.q1', localID: 'q1', choice: 'x', correct: false, context: 'inline' });
  p.answer({ lessonID: 'l', questionID: 'l.q2', localID: 'q2', choice: 'y', correct: true, context: 'inline' });
  eq(p.reviewQueue().length, 0, 'nothing due today');
  today = 20261125;
  eq(p.reviewQueue().map(c => c.questionID), ['l.q1'], 'the wrong one is back tomorrow');
  eq(p.answer({ lessonID: 'l', questionID: 'l.q1', choice: 'x', correct: true, context: 'review' }), { created: false, before: 1, after: 2 });
  eq(p.state.events.at(-1).boxBefore, 1, 'the log records the box before the answer');
  eq(p.card('l.q1').box, 2);
  eq(p.card('l.q1').dueDay, 20261128, 'pushed out 3 days');
  today = 20261127;
  eq(p.reviewQueue().map(c => c.questionID), ['l.q2'], 'the right one comes back after 3 days');
  p.answer({ lessonID: 'l', questionID: 'l.q2', choice: 'y', correct: true, context: 'review' });
  eq(p.card('l.q2').dueDay, 20261204, 'then 7 days');
});

test('review session: a missed card comes back once as practice and doesn\'t move its box again', () => {
  const recorded = [];
  const s = new ReviewSession([{ questionID: 'a', box: 2 }, { questionID: 'b', box: 1 }], (card, correct) => {
    recorded.push([card.questionID, correct]);
    return { before: card.box, after: correct ? card.box + 1 : 1 };
  });
  s.answer(false); s.next();      // a wrong → requeued
  s.answer(true); s.next();       // b right
  eq(s.total, 3);
  eq(s.current.card.questionID, 'a');
  ok(s.current.practice);
  s.answer(true); s.next();       // practice: not recorded
  ok(s.done);
  eq(recorded, [['a', false], ['b', true]]);
  eq(s.summary(), { reviewed: 2, right: 1, movedUp: 1, backToOne: 1 });
});

// MARK: - Streak

const H = 3_600_000;
/** A goal-met day: activity at `hour` local time where the UTC offset is `offset` hours. */
function met(day, { hour = 12, offset = 0, until } = {}) {
  const y = Math.floor(day / 10000), m = Math.floor(day / 100) % 100, d = day % 100;
  const at = Date.UTC(y, m - 1, d, hour) - offset * H;
  const end = until === undefined ? at : Date.UTC(y, m - 1, d, until) - offset * H;
  return { day, goalMet: true, firstActivityAt: at, lastActivityAt: end, firstUTCOffset: offset * 3600, lastUTCOffset: offset * 3600 };
}
function streakAt(days, today, { hour = 12, offset = 0, firstDay = 1 } = {}) {
  const y = Math.floor(today / 10000), m = Math.floor(today / 100) % 100, d = today % 100;
  return computeStreak({ days, today, now: Date.UTC(y, m - 1, d, hour) - offset * H, currentOffset: offset * 3600, firstDay });
}

test('five days in a row', () => {
  const s = streakAt([20261120, 20261121, 20261122, 20261123, 20261124].map(d => met(d)), T);
  eq(s.count, 5); ok(s.todayDone);
});

test('today not done yet does not break the streak', () => {
  const s = streakAt([20261121, 20261122, 20261123].map(d => met(d)), T);
  eq(s.count, 3); ok(!s.todayDone); eq(s.missed, []);
});

test('one missed day uses the weekly freeze', () => {
  // Mon 16, (Tue 17 missed), Wed 18, Thu 19
  const s = streakAt([20261116, 20261118, 20261119].map(d => met(d)), 20261119);
  eq(s.count, 3); eq(s.frozen, [20261117]); ok(!s.freezeAvailableThisWeek);
});

test('two misses in one week: the second breaks the streak (Monday freezes, Thursday breaks)', () => {
  // Mon 16 met, Tue 17 missed (freeze), Wed 18 met, Thu 19 missed (break), Fri 20 met
  const s = streakAt([20261116, 20261118, 20261120].map(d => met(d)), 20261120);
  eq(s.frozen, [20261117]); eq(s.missed, [20261119]); eq(s.count, 1);
});

test('misses in two different weeks are both frozen', () => {
  const days = [20261116, 20261118, 20261119, 20261120, 20261121, 20261122, 20261123, 20261125].map(d => met(d));
  const s = streakAt(days, 20261125);
  eq(s.frozen, [20261117, 20261124]); eq(s.count, 8);
});

test('no freeze is spent when there is no streak to protect', () => {
  // Mon 16 met, Tue 17 frozen, Wed 18 breaks; next week has no streak, so its freeze stays.
  const s = streakAt([met(20261116)], 20261125);
  eq(s.frozen, [20261117]); eq(s.missed, [20261118]); eq(s.count, 0); ok(s.freezeAvailableThisWeek);
});

test('Sunday-start vs Monday-start weeks change which misses a freeze covers', () => {
  // Sat 21 met, Sun 22 missed, Mon 23 missed, Tue 24 met
  const days = [20261120, 20261121, 20261124].map(d => met(d));
  const monday = streakAt(days, T, { firstDay: 1 });
  eq(monday.frozen, [20261122, 20261123], 'Sun and Mon are in different weeks'); eq(monday.count, 3);
  const sunday = streakAt(days, T, { firstDay: 7 });
  eq(sunday.frozen, [20261122]); eq(sunday.missed, [20261123], 'same week: second miss breaks'); eq(sunday.count, 1);
});

test('raising the goal does not rewrite past days', () => {
  let today = 20261123;
  const p = new Progress({ clock: clockAt(() => today) });
  const lesson = { id: 'l', contentVersion: 1 };
  p.openLesson(lesson);
  p.completeLesson(lesson, { score: 5, inlineQuestionIDs: [] });
  p.setSetting('dailyGoal', 2);
  today = T;
  p.openLesson(lesson);
  p.completeLesson(lesson, { score: 5, inlineQuestionIDs: [] });
  eq(p.state.activity[20261123].goalMet, true, 'yesterday stays met');
  eq(p.today().goalMet, false, 'today needs 2 now');
  eq(p.streak().count, 1);
  p.openLesson(lesson);
  p.completeLesson(lesson, { score: 4, inlineQuestionIDs: [] });
  eq(p.today().goalMet, true, 'retakes count toward the goal');
  eq(p.streak().count, 2);
});

test('daylight-saving nights: consecutive days stay consecutive, a real miss is not forgiven', () => {
  // New York: EST (-5) on Mar 7, EDT (-4) from Mar 8.
  const s = streakAt([met(20260307, { hour: 23, offset: -5 }), met(20260308, { hour: 1, offset: -4 }), met(20260309, { offset: -4 })],
    20260309, { offset: -4 });
  eq(s.count, 3); eq(s.forgiven, []);
  const miss = streakAt([met(20260307, { hour: 20, offset: -5 }), met(20260309, { hour: 8, offset: -4 })], 20260309, { hour: 9, offset: -4 });
  eq(miss.forgiven, [], 'offset changed but 35 hours passed'); eq(miss.frozen, [20260308]);
});

test('flying east over the date line: the skipped calendar day is forgiven', () => {
  // Lesson 8 pm Nov 24 in Los Angeles; next lesson noon Nov 26 in Tokyo, 23 hours later.
  const s = streakAt([met(20261124, { hour: 20, offset: -8 }), met(20261126, { hour: 12, offset: 9 })], 20261126, { hour: 13, offset: 9 });
  eq(s.forgiven, [20261125]); eq(s.frozen, []); eq(s.count, 2); ok(s.freezeAvailableThisWeek);
});

test('just landed east, nothing done yet today: yesterday is not marked missed', () => {
  const s = streakAt([met(20261124, { hour: 20, offset: -8 })], 20261126, { hour: 9, offset: 9 });
  eq(s.forgiven, [20261125]); eq(s.count, 1); ok(!s.todayDone);
});

test('an east trip with a real missed day (more than 24 hours) is not forgiven', () => {
  const s = streakAt([met(20261124, { hour: 20, offset: -8 }), met(20261126, { hour: 20, offset: 9 })], 20261126, { hour: 21, offset: 9 });
  eq(s.forgiven, []); eq(s.frozen, [20261125]);
});

test('flying west: a "future" date counts as today, once', () => {
  // Nov 23 in LA, then Nov 25 10 am in Tokyo, then back in LA where it is Nov 24 8 pm.
  const s = streakAt([met(20261123, { offset: -8 }), met(20261125, { hour: 10, offset: 9 })], T, { hour: 20, offset: -8 });
  ok(s.todayDone); eq(s.count, 2); eq(s.frozen, []);
});

test('midnight boundary: 11:59 pm and 12:01 am are two different days', () => {
  const p = new Progress({ clock: {
    now: () => now, today: () => dayKeyOf(new Date(now), 'UTC'), offset: () => 0, firstDay: () => 1 } });
  let now = Date.UTC(2026, 10, 23, 23, 59);
  const lesson = { id: 'l', contentVersion: 1 };
  p.openLesson(lesson); p.completeLesson(lesson, { score: 5, inlineQuestionIDs: [] });
  now = Date.UTC(2026, 10, 24, 0, 1);
  p.openLesson(lesson); p.completeLesson(lesson, { score: 5, inlineQuestionIDs: [] });
  eq(Object.keys(p.state.activity).sort(), ['20261123', '20261124']);
  eq(p.streak().count, 2);
});

// MARK: - Progress

test('resume point is saved and survives a reload', () => {
  let saved = null;
  const make = () => new Progress({ load: () => saved && JSON.parse(saved), save: s => { saved = JSON.stringify(s); }, clock: clockAt(() => T) });
  const lesson = { id: 'l', contentVersion: 1 };
  const a = make();
  a.openLesson(lesson);
  a.saveResume('l', { anchorSectionID: 'timeline', anchorFraction: 0.4, progress: 0.55 });
  const b = make(); // a "force-quit and relaunch"
  eq(b.lesson('l').anchorSectionID, 'timeline');
  eq(b.lesson('l').anchorFraction, 0.4);
  eq(b.lesson('l').status, 'inProgress');
  eq(b.lesson('l').furthestProgress, 0.55);
});

test('completing a lesson adds skipped inline questions to review and counts new cards', () => {
  const p = new Progress({ clock: clockAt(() => T) });
  const lesson = { id: 'l', contentVersion: 1 };
  p.openLesson(lesson);
  p.answer({ lessonID: 'l', questionID: 'l.c1', localID: 'c1', choice: 'a', correct: true, context: 'inline' });
  for (const f of ['f1', 'f2']) p.answer({ lessonID: 'l', questionID: `l.${f}`, localID: f, choice: 'a', correct: true, context: 'final' });
  const r = p.completeLesson(lesson, { score: 2, inlineQuestionIDs: [{ globalID: 'l.c1' }, { globalID: 'l.c2' }] });
  eq(r.added, 4); ok(r.goalMetNow);
  eq(p.card('l.c2').box, 1); eq(p.card('l.c2').dueDay, 20261125);
  eq(p.card('l.c1').box, 2, 'answered inline question keeps its box');
  ok(p.isCompleted('l'));
});

test('reopening a finished lesson starts a fresh pass at the top', () => {
  const p = new Progress({ clock: clockAt(() => T) });
  const lesson = { id: 'l', contentVersion: 1 };
  p.openLesson(lesson);
  p.saveResume('l', { anchorSectionID: 'recap', anchorFraction: 0, progress: 1 });
  p.completeLesson(lesson, { score: 5, inlineQuestionIDs: [] });
  p.openLesson(lesson);
  eq(p.lesson('l').anchorSectionID, null);
  p.saveResume('l', { anchorSectionID: 'mid', anchorFraction: 0, progress: 0.5 });
  p.openLesson(lesson);
  eq(p.lesson('l').anchorSectionID, 'mid', 'a retake in progress resumes');
});

test('reset clears progress but keeps settings', () => {
  const p = new Progress({ clock: clockAt(() => T) });
  p.setSetting('dailyGoal', 3);
  p.answer({ lessonID: 'l', questionID: 'l.q', localID: 'q', choice: 'a', correct: true, context: 'final' });
  p.reset();
  eq(p.cards.length, 0); eq(p.settings.dailyGoal, 3);
});

function clockAt(today) {
  return { now: () => Date.UTC(2026, 10, 24, 12), today, offset: () => 0, firstDay: () => 1 };
}
