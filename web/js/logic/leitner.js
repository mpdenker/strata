// Leitner review boxes (SPEC.md §8). Pure functions: they decide, the store saves.
import { addDays } from './daykey.js';

/** Days until the next review, by box. */
export const INTERVALS = { 1: 1, 2: 3, 3: 7, 4: 14, 5: 30 };

/**
 * The card's next state after an answer.
 *   card:    the existing card ({ box, dueDay }) or null if this question has never been answered
 *   context: 'inline' | 'final' (in a lesson), 'review' (review session), 'unseen' (skipped inline check)
 * Returns { box, dueDay }.
 */
export function schedule(card, { correct, context, today }) {
  if (!card) {
    // First time: right → box 2 (due in 3 days), wrong or skipped → box 1 (due tomorrow).
    const box = correct && context !== 'unseen' ? 2 : 1;
    return { box, dueDay: addDays(today, INTERVALS[box]) };
  }
  if (!correct) return { box: 1, dueDay: addDays(today, 1) };
  if (context === 'review') {
    const box = Math.min(5, card.box + 1);
    return { box, dueDay: addDays(today, INTERVALS[box]) };
  }
  // Right again while retaking a lesson: no change, so retakes can't inflate boxes.
  return { box: card.box, dueDay: card.dueDay };
}

/**
 * Today's review queue: due or overdue cards whose question still exists, most overdue first,
 * then lower boxes first, then a stable shuffle. At most `cap` cards; the rest come first tomorrow.
 */
export function dueQueue(cards, { today, exists = () => true, cap = 20, seed = String(today) }) {
  return cards
    .filter(c => c.dueDay <= today && exists(c.questionID))
    .map(c => ({ c, tie: hash(seed + c.questionID) }))
    .sort((a, b) => a.c.dueDay - b.c.dueDay || a.c.box - b.c.box || a.tie - b.tie)
    .slice(0, cap)
    .map(x => x.c);
}

/** Cards due today or earlier (no cap), for counts. */
export function dueCount(cards, { today, exists = () => true }) {
  return cards.filter(c => c.dueDay <= today && exists(c.questionID)).length;
}

/** The next day with cards due after today, and how many: for "Next review: Thu (3 cards)". */
export function nextReview(cards, { today, exists = () => true }) {
  const later = cards.filter(c => c.dueDay > today && exists(c.questionID));
  if (!later.length) return null;
  const day = Math.min(...later.map(c => c.dueDay));
  return { day, count: later.filter(c => c.dueDay === day).length };
}

function hash(s) {
  let h = 0x811c9dc5;
  for (let i = 0; i < s.length; i++) h = Math.imul(h ^ s.charCodeAt(i), 0x01000193);
  return h >>> 0;
}
