// One review session (SPEC.md §8): due cards in order; a card you miss comes back once at the end
// as practice. Only the first answer to each card is recorded and moves its box.

export class ReviewSession {
  /** cards: the queue from Progress.reviewQueue; record(card, correct) saves a first answer. */
  constructor(cards, record) {
    this.queue = cards.map(card => ({ card, practice: false }));
    this.index = 0;
    this.record = record;
    this.results = []; // { card, correct, before, after }
  }

  get current() { return this.queue[this.index] ?? null; }
  get done() { return this.index >= this.queue.length; }
  get total() { return this.queue.length; }

  answer(correct) {
    const item = this.current;
    if (!item) return null;
    if (!item.practice) {
      const moved = this.record(item.card, correct);
      this.results.push({ card: item.card, correct, ...moved });
      if (!correct) this.queue.push({ card: item.card, practice: true });
    }
    return item;
  }

  next() { this.index += 1; }

  summary() {
    const right = this.results.filter(r => r.correct).length;
    return {
      reviewed: this.results.length,
      right,
      movedUp: this.results.filter(r => r.after > r.before).length,
      backToOne: this.results.filter(r => !r.correct).length,
    };
  }
}
