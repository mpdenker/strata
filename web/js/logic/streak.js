// Streak, weekly freeze and time-zone forgiveness (SPEC.md §9). The streak is never stored;
// it's recomputed from activity days every time, so it can't drift out of sync.
import { addDays, weekStart } from './daykey.js';

const DAY_MS = 86_400_000;

/**
 * days: activity rows { day, goalMet, firstActivityAt, lastActivityAt, firstUTCOffset, lastUTCOffset }
 *       (times in ms since 1970, offsets in seconds east of UTC)
 * today: today's DayKey where you are now; now: current time (ms); currentOffset: seconds east of UTC now
 * firstDay: first day of the week, 1 = Monday … 7 = Sunday
 *
 * Returns { count, todayDone, frozen[], forgiven[], missed[], freezeAvailableThisWeek, status(day) }.
 */
export function computeStreak({ days, today, now, currentOffset, firstDay = 1 }) {
  // Flying west can record a date later than today; treat those as today.
  const metRows = days.filter(d => d.goalMet).map(d => ({ ...d, day: Math.min(d.day, today) }));
  const met = new Map();
  for (const r of metRows) {
    const prev = met.get(r.day);
    met.set(r.day, prev
      ? { ...prev, firstActivityAt: Math.min(prev.firstActivityAt, r.firstActivityAt),
          lastActivityAt: Math.max(prev.lastActivityAt, r.lastActivityAt) }
      : r);
  }
  const metDays = [...met.keys()].sort((a, b) => a - b);

  let count = 0;
  const frozen = [], forgiven = [], missed = [];
  const freezeUsed = new Set();

  if (metDays.length) {
    for (let d = metDays[0]; d < today; d = addDays(d, 1)) {
      if (met.has(d)) {
        count += 1;
      } else if (travelForgives(d)) {
        forgiven.push(d);
      } else if (count > 0 && !freezeUsed.has(weekStart(d, firstDay))) {
        freezeUsed.add(weekStart(d, firstDay));
        frozen.push(d);
      } else {
        if (count > 0) missed.push(d);
        count = 0;
      }
    }
  }
  const todayDone = met.has(today);
  if (todayDone) count += 1;

  // A skipped calendar day is forgiven when the met days around it were recorded at different
  // UTC offsets and less than 24 real hours apart (flying east over the date line). If there's no
  // met day after it yet, "now" stands in, so yesterday isn't marked missed right after landing.
  function travelForgives(d) {
    const before = metDays.filter(x => x < d).at(-1);
    if (before === undefined) return false;
    const after = metDays.find(x => x > d);
    const a = met.get(before);
    const b = after !== undefined
      ? { at: met.get(after).firstActivityAt, offset: met.get(after).firstUTCOffset }
      : { at: now, offset: currentOffset };
    return a.lastUTCOffset !== b.offset && b.at - a.lastActivityAt < DAY_MS;
  }

  const sets = { frozen: new Set(frozen), forgiven: new Set(forgiven), missed: new Set(missed) };
  return {
    count,
    todayDone,
    frozen,
    forgiven,
    missed,
    freezeAvailableThisWeek: !freezeUsed.has(weekStart(today, firstDay)),
    /** 'done' | 'frozen' | 'forgiven' | 'missed' | 'none' for any day up to today. */
    status(day) {
      if (met.has(day)) return 'done';
      if (sets.frozen.has(day)) return 'frozen';
      if (sets.forgiven.has(day)) return 'forgiven';
      if (sets.missed.has(day)) return 'missed';
      return 'none';
    },
  };
}
