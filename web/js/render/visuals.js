// The seven visual kinds (SPEC.md §6.4), drawn from lesson JSON. Each returns HTML; hydrate() then
// draws the parts that need measuring (diagram arrows, shapes, charts) and redraws them on resize.
import { md, esc, plain } from '../text.js';
import { icon } from '../icons.js';
import { stepCount } from '../content.js';
import { onStage, refresh, shownOf } from './stage.js';
import { drawChart } from './chart.js';

const registry = new Map();
let seq = 0;
export function keep(obj) { const k = `k${++seq}`; registry.set(k, obj); return k; }
export function lookup(k) { return registry.get(k); }
export function clearRegistry() { registry.clear(); }

export const color = token => ({
  topic: 'var(--topic)', topicSoft: 'var(--topic-soft)', ink: 'var(--ink)', muted: 'var(--ink-muted)',
  paper: 'var(--paper)', correct: 'var(--correct)', wrong: 'var(--wrong)', none: 'transparent',
}[token] ?? 'var(--ink)');

/** A visual inside its stage. VoiceOver reads the required accessibilityLabel as one image. */
export function renderVisual(v, id) {
  const label = esc(v.accessibilityLabel);
  const inner = {
    diagram: () => canvas(diagram(v)),
    shapes: () => canvas(shapes(v)),
    iconArray: () => canvas(iconArray(v)),
    formula: () => canvas(formula(v)),
    layers: () => canvas(layers(v)),
    bigNumber: () => bigNumber(v),
    symbol: () => symbolHero(v),
  }[v.kind]?.() ?? '';
  return `<figure class="visual v-${v.kind}" role="img" aria-label="${label}">
    <div class="staged" data-stage="${esc(id)}" data-total="${stepCount(v)}" aria-hidden="true">${inner}</div>
  </figure>`;
}

const canvas = html => `<div class="canvas">${html}</div>`;

// MARK: - Diagram

export function diagram(d) {
  const layout = d.layout ?? 'row';
  const n = d.nodes.length;
  const slots = d.nodes.map((node, i) => {
    let style = '';
    if (layout === 'cycle') {
      const a = -Math.PI / 2 + (2 * Math.PI * i) / Math.max(1, n);
      style = `left:${50 + 36 * Math.cos(a)}%;top:${50 + 36 * Math.sin(a)}%`;
    } else if (layout === 'free') {
      style = `left:${(node.x ?? 0.5) * 100}%;top:${(node.y ?? 0.5) * 100}%`;
    }
    return `<div class="slot" data-node="${esc(node.id)}" style="${style}">${diagramNode(node)}</div>`;
  }).join('');
  const aspect = layout === 'cycle' ? 'aspect-ratio:1' : layout === 'free' ? `aspect-ratio:${d.aspectRatio ?? 1.4}` : '';
  return `<div class="diagram d-${layout}" data-diagram="${keep(d)}" style="${aspect}">
    <svg class="edges"></svg><div class="edge-labels"></div>${slots}</div>`;
}

function diagramNode(node) {
  const style = node.style ?? 'filled';
  return `<div class="node n-${style}" data-step="${node.step ?? 1}">
    ${node.symbol ? icon(node.symbol, { cls: 'node-ic' }) : ''}
    <div class="node-label">${md(node.label)}</div>
    ${node.detail ? `<div class="node-detail">${md(node.detail)}</div>` : ''}
  </div>`;
}

/** Where a line from the rect's center toward (px, py) leaves the rect, plus a gap. */
export function exitPoint(r, px, py, gap) {
  const cx = r.x + r.w / 2, cy = r.y + r.h / 2;
  const dx = px - cx, dy = py - cy;
  if (!dx && !dy) return [cx, cy];
  const sx = dx === 0 ? Infinity : (r.w / 2 + gap) / Math.abs(dx);
  const sy = dy === 0 ? Infinity : (r.h / 2 + gap) / Math.abs(dy);
  const s = Math.min(sx, sy, 1);
  return [cx + dx * s, cy + dy * s];
}

/** A line with an optional open arrowhead, as one path so it can draw itself in. */
export function arrowPath([x1, y1], [x2, y2], head) {
  let p = `M${x1.toFixed(1)} ${y1.toFixed(1)}L${x2.toFixed(1)} ${y2.toFixed(1)}`;
  if (head) {
    const a = Math.atan2(y2 - y1, x2 - x1), len = 10, spread = Math.PI / 7;
    p += `M${(x2 - len * Math.cos(a - spread)).toFixed(1)} ${(y2 - len * Math.sin(a - spread)).toFixed(1)}L${x2.toFixed(1)} ${y2.toFixed(1)}L${(x2 - len * Math.cos(a + spread)).toFixed(1)} ${(y2 - len * Math.sin(a + spread)).toFixed(1)}`;
  }
  return p;
}

function drawEdges(el) {
  const d = lookup(el.dataset.diagram);
  if (el.matches('.d-row, .d-grid')) {
    el.classList.remove('as-column');
    const tight = [...el.querySelectorAll('.node-label, .node-detail')].some(l => l.scrollWidth > l.clientWidth + 1);
    el.classList.toggle('as-column', tight);
  }
  const box = el.getBoundingClientRect();
  if (!box.width) return;
  const scale = box.width / el.offsetWidth || 1; // the section may be mid-entrance (scaled)
  const rects = {};
  for (const slot of el.querySelectorAll('.slot')) {
    const r = slot.getBoundingClientRect();
    rects[slot.dataset.node] = { x: (r.left - box.left) / scale, y: (r.top - box.top) / scale, w: r.width / scale, h: r.height / scale };
  }
  const svg = el.querySelector('.edges');
  svg.setAttribute('viewBox', `0 0 ${el.offsetWidth} ${el.offsetHeight}`);
  let paths = '', labels = '';
  for (const e of d.edges ?? []) {
    const a = rects[e.from], b = rects[e.to];
    if (!a || !b) continue;
    const start = exitPoint(a, b.x + b.w / 2, b.y + b.h / 2, 4);
    const end = exitPoint(b, a.x + a.w / 2, a.y + a.h / 2, 6);
    const style = e.style ?? 'arrow';
    paths += `<path class="edge e-${style}" data-step="${e.step ?? 1}" pathLength="1" d="${arrowPath(start, end, style === 'arrow')}"/>`;
    if (e.label) {
      labels += `<span class="edge-label" data-step="${e.step ?? 1}" style="left:${(start[0] + end[0]) / 2}px;top:${(start[1] + end[1]) / 2}px">${md(e.label)}</span>`;
    }
  }
  svg.innerHTML = paths;
  el.querySelector('.edge-labels').innerHTML = labels;
  refresh(el.closest('.staged'));
}

// MARK: - Shapes (free drawing on a 0…1 canvas)

function shapes(s) {
  const overlays = s.items.map(item => {
    const step = item.step ?? 1;
    const pos = `left:${(item.x ?? 0.5) * 100}%;top:${(item.y ?? 0.5) * 100}%`;
    if (item.shape === 'text') {
      const size = item.textSize ?? 'caption';
      return `<div class="sh-text sz-${size}" data-step="${step}" style="${pos};color:${item.fill ? color(item.fill) : 'var(--ink)'}">${md(item.text ?? '')}</div>`;
    }
    if (item.shape === 'symbol') {
      return `<div class="sh-symbol" data-step="${step}" style="${pos};color:${item.fill ? color(item.fill) : 'var(--topic)'};--size:${item.size ?? 0.1}">${icon(item.name)}</div>`;
    }
    return '';
  }).join('');
  return `<div class="shapes" data-shapes="${keep(s)}" style="aspect-ratio:${s.aspectRatio}"><svg class="shapes-svg"></svg>${overlays}</div>`;
}

function drawShapes(el) {
  const s = lookup(el.dataset.shapes);
  const W = el.offsetWidth, H = el.offsetHeight;
  if (!W) return;
  const svg = el.querySelector('.shapes-svg');
  svg.setAttribute('viewBox', `0 0 ${W} ${H}`);
  const pt = p => `${(p[0] * W).toFixed(1)} ${(p[1] * H).toFixed(1)}`;
  svg.innerHTML = s.items.map(item => {
    const fill = color(item.fill ?? (item.shape === 'line' ? 'none' : 'topicSoft'));
    const stroke = color(item.stroke ?? (['rect', 'circle', 'polygon'].includes(item.shape) ? 'topic' : 'ink'));
    const common = `data-step="${item.step ?? 1}" fill="${fill}" stroke="${stroke}" class="sh sh-${item.shape}${item.dashed ? ' dashed' : ''}"`;
    switch (item.shape) {
      case 'rect': {
        const w = (item.w ?? 0.2) * W, h = (item.h ?? 0.2) * H, r = (item.corner ?? 0.03) * W;
        return `<rect ${common} x="${(item.x ?? 0) * W}" y="${(item.y ?? 0) * H}" width="${w}" height="${h}" rx="${r}"/>`;
      }
      case 'circle':
        return `<circle ${common} cx="${(item.x ?? 0.5) * W}" cy="${(item.y ?? 0.5) * H}" r="${(item.r ?? 0.05) * W}"/>`;
      case 'polygon':
        return `<path ${common} d="M${(item.points ?? []).map(pt).join('L')}Z"/>`;
      case 'line': {
        const pts = (item.points ?? []).map(p => [p[0] * W, p[1] * H]);
        if (pts.length < 2) return '';
        let d = `M${pts.map(p => `${p[0].toFixed(1)} ${p[1].toFixed(1)}`).join('L')}`;
        if (item.arrow) d = d + arrowPath(pts.at(-2), pts.at(-1), true).replace(/^M[^L]+L[^M]+/, '');
        return `<path ${common} fill="none" pathLength="1" d="${d}"/>`;
      }
      default: return '';
    }
  }).join('');
  refresh(el.closest('.staged'));
}

// MARK: - Icon array ("37 out of 100")

function iconArray(a) {
  let cells = '', g = 0, start = 0;
  for (let i = 0; i < a.total; i++) {
    while (g < a.groups.length && i >= start + a.groups[g].count) { start += a.groups[g].count; g += 1; }
    const group = g < a.groups.length ? a.groups[g] : null;
    cells += group
      ? `<span class="ia-cell" data-step="${g + 1}" style="--c:${color(group.color)}">${icon(a.symbol)}</span>`
      : `<span class="ia-cell">${icon(a.symbol)}</span>`;
  }
  const legend = a.groups.map((grp, i) => `<li class="appear" data-step="${i + 1}">
      <span style="color:${color(grp.color)}">${icon(a.symbol)}</span><strong>${grp.count}</strong><span class="muted">${md(grp.label)}</span></li>`).join('');
  return `<div class="iconarray" style="grid-template-columns:repeat(${Math.max(1, a.columns)},1fr)">${cells}</div><ul class="ia-legend">${legend}</ul>`;
}

// MARK: - Formula with labeled parts

function formula(f) {
  const partColor = p => (p.color ? color(p.color) : p.label ? 'var(--topic-ink)' : 'var(--ink)');
  const row = f.parts.map((p, i) => `<div class="f-part appear" data-step="${i + 1}">
      <span class="f-text" style="color:${partColor(p)}">${esc(p.text)}</span>
      ${p.label ? `<span class="f-tick"></span><span class="f-label">${esc(p.label)}</span>` : ''}</div>`).join('');
  const stacked = `<div class="f-whole">${esc(f.parts.map(p => p.text).join(''))}</div>` +
    f.parts.map((p, i) => (p.label ? `<div class="f-def appear" data-step="${i + 1}"><code style="color:${partColor(p)}">${esc(p.text.trim())}</code> = ${esc(p.label)}</div>` : '')).join('');
  return `<div class="formula" data-formula="1"><div class="f-row">${row}</div><div class="f-stack">${stacked}</div></div>`;
}

function fitFormula(el) {
  el.classList.remove('stacked');
  const row = el.querySelector('.f-row');
  if (row.scrollWidth > el.clientWidth + 1) el.classList.add('stacked');
}

// MARK: - Big number (counts up)

export function formatNumber(n, b) {
  const text = n.toLocaleString(undefined, { minimumFractionDigits: b.decimals ?? 0, maximumFractionDigits: b.decimals ?? 0 });
  return (b.prefix ?? '') + text + (b.suffix ?? '');
}

function bigNumber(b) {
  const note = b.dataNote && (b.dataKind === 'computed' || b.dataKind === 'illustrative')
    ? `<p class="note">${icon('function')}<span>${esc(b.dataNote)}</span></p>` : '';
  return `<div class="bignumber appear" data-step="1">
      <div class="bn-value" data-count="${keep(b)}">${esc(formatNumber(b.value, b))}</div>
      <div class="bn-label">${md(b.label)}</div>${note}</div>`;
}

function setupCounter(el) {
  const b = lookup(el.dataset.count);
  const stage = el.closest('.staged');
  const reduce = matchMedia('(prefers-reduced-motion: reduce)').matches;
  if (!b.countUp || reduce) return;
  if (shownOf(stage) < 1) el.textContent = formatNumber(0, b);
  let ran = false;
  onStage(stage, (n, instant) => {
    if (n < 1 || ran) return;
    ran = true;
    if (instant) { el.textContent = formatNumber(b.value, b); return; }
    const t0 = performance.now(), dur = 1400;
    const frame = t => {
      const k = Math.min(1, (t - t0) / dur), eased = 1 - (1 - k) ** 3;
      el.textContent = formatNumber(b.value * eased, b);
      if (k < 1) requestAnimationFrame(frame);
    };
    requestAnimationFrame(frame);
  });
}

// MARK: - Layers and symbol

function layers(l) {
  const up = (l.direction ?? 'up') === 'up';
  const items = l.layers.map((layer, i) => `<li class="layer-band ${i % 2 ? '' : 'soft'} ${up ? 'from-up' : 'from-down'}" data-step="${i + 1}">
      ${layer.symbol ? icon(layer.symbol, { cls: 'lb-ic' }) : ''}
      <span class="lb-label">${md(layer.label)}</span>
      ${layer.detail ? `<span class="lb-detail">${md(layer.detail)}</span>` : ''}</li>`);
  return `<ol class="layers">${(up ? items.reverse() : items).join('')}</ol>`;
}

function symbolHero(s) {
  return `<div class="symbol-hero appear" data-step="1">${icon(s.name, { cls: 'hero-ic' })}
    ${s.caption ? `<div class="hero-caption">${md(s.caption)}</div>` : ''}</div>`;
}

// MARK: - Hydrate

const observer = typeof ResizeObserver !== 'undefined' ? new ResizeObserver(entries => {
  for (const { target } of entries) redraw(target);
}) : null;

function redraw(el) {
  if (el.dataset.diagram) drawEdges(el);
  else if (el.dataset.shapes) drawShapes(el);
  else if (el.dataset.chart) drawChart(el, lookup(el.dataset.chart));
  else if (el.dataset.formula) fitFormula(el);
}

/** Draw everything inside root that needs layout, and keep it drawn as sizes change. */
export function hydrate(root) {
  for (const el of root.querySelectorAll('[data-diagram],[data-shapes],[data-chart],[data-formula]')) {
    redraw(el);
    observer?.observe(el);
  }
  for (const el of root.querySelectorAll('[data-count]')) setupCounter(el);
  document.fonts?.ready.then(() => {
    for (const el of root.querySelectorAll('[data-diagram],[data-formula]')) redraw(el);
  });
}

export { plain };
