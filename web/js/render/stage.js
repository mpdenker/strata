// Staged builds (SPEC.md §5.2, layer B): a visual's parts carry data-step="n" and appear in order
// the first time their section is on screen. A stage is any element with class "staged".

const listeners = new WeakMap();

/** Run code whenever this stage's shown count changes (charts and counters use it). */
export function onStage(stage, fn) {
  const list = listeners.get(stage) ?? [];
  list.push(fn);
  listeners.set(stage, list);
}

export function shownOf(stage) { return Number(stage?.dataset.shown ?? 0); }

/** Show parts 1…n. `instant` skips transitions (Reduce Motion, or a visual already built). */
export function setShown(stage, n, { instant = false } = {}) {
  stage.dataset.shown = n;
  stage.classList.toggle('instant', instant);
  for (const el of stage.querySelectorAll('[data-step]')) {
    if (el.closest('.staged') !== stage) continue;
    el.classList.toggle('on', Number(el.dataset.step) <= n);
  }
  for (const fn of listeners.get(stage) ?? []) fn(n, instant);
}

/** Step through 1…total with a stagger. Returns a cancel function. */
export function build(stage, { stagger = 260, onDone } = {}) {
  const total = Number(stage.dataset.total ?? 1);
  let step = 0, timer = null, cancelled = false;
  const tick = () => {
    if (cancelled) return;
    step += 1;
    setShown(stage, step);
    if (step < total) timer = setTimeout(tick, stagger);
    else onDone?.();
  };
  tick();
  return () => { cancelled = true; clearTimeout(timer); };
}

/** Re-apply the current count to parts drawn after the fact (edges, chart marks). */
export function refresh(stage) {
  if (stage) setShown(stage, shownOf(stage), { instant: true });
}
