// Bar and line charts drawn as SVG at the container's real pixel width (no charting library).
// Bars rise and lines draw in when the section's build reaches step 1.
import { esc } from '../text.js';
import { refresh } from './stage.js';

const SERIES_COLORS = ['var(--topic)', 'var(--ink)', 'var(--ink-muted)'];

export function formatValue(v, unit) {
  const text = v.toLocaleString(undefined, { maximumFractionDigits: 2 });
  return unit ? (unit === '%' ? `${text}%` : `${text} ${unit}`) : text;
}

function tickLabel(v) {
  if (Math.abs(v) >= 10000) return new Intl.NumberFormat(undefined, { notation: 'compact', maximumFractionDigits: 1 }).format(v);
  return v.toLocaleString(undefined, { maximumFractionDigits: 2 });
}

/** About `count` round-numbered ticks covering [lo, hi]. */
export function niceTicks(lo, hi, count = 5) {
  if (hi === lo) hi = lo + 1;
  const raw = (hi - lo) / count;
  const mag = 10 ** Math.floor(Math.log10(raw));
  const step = [1, 2, 2.5, 5, 10].map(m => m * mag).find(s => s >= raw);
  const start = Math.floor(lo / step) * step, end = Math.ceil(hi / step) * step;
  const ticks = [];
  for (let v = start; v <= end + step / 2; v += step) ticks.push(Number(v.toPrecision(12)));
  return ticks;
}

export function drawChart(el, chart) {
  const W = el.clientWidth;
  if (!W) return;
  const H = Math.round(Math.min(320, Math.max(210, W * 0.62)));
  const labelX = chart.series.some(s => s.points.some(p => typeof p.x === 'string'));
  const all = chart.series.flatMap(s => s.points);
  const yTicks = niceTicks(Math.min(0, ...all.map(p => p.y)), Math.max(0, ...all.map(p => p.y)));
  const y0 = yTicks[0], y1 = yTicks.at(-1);

  const left = Math.max(...yTicks.map(t => tickLabel(t).length)) * 7 + 12;
  const top = 26, right = 10, bottom = labelX ? 44 : 40;
  const pw = W - left - right, ph = H - top - bottom;
  const Y = v => top + ph - ((v - y0) / (y1 - y0)) * ph;

  let X, band = 0, categories = [];
  if (labelX) {
    categories = [...new Set(all.map(p => String(p.x)))];
    band = pw / categories.length;
    X = x => left + band * (categories.indexOf(String(x)) + 0.5);
  } else {
    const xs = all.map(p => p.x);
    const xt = niceTicks(Math.min(...xs), Math.max(...xs), Math.min(6, Math.max(2, Math.floor(pw / 70))));
    const lo = chart.chartKind === 'bar' ? Math.min(...xs) - 0.5 : Math.min(...xs);
    const hi = chart.chartKind === 'bar' ? Math.max(...xs) + 0.5 : Math.max(...xs);
    X = x => left + ((x - lo) / (hi - lo || 1)) * pw;
    categories = xt.filter(t => t >= lo && t <= hi);
  }

  let svg = '';
  // Grid and y axis
  for (const t of yTicks) {
    svg += `<line class="grid${t === 0 ? ' zero' : ''}" x1="${left}" x2="${W - right}" y1="${Y(t)}" y2="${Y(t)}"/>`;
    svg += `<text class="tick" x="${left - 6}" y="${Y(t) + 4}" text-anchor="end">${esc(tickLabel(t))}</text>`;
  }
  svg += `<text class="axis-title" x="${left}" y="13">${esc(chart.yLabel + (chart.unit ? ` (${chart.unit})` : ''))}</text>`;
  // X axis labels
  for (const c of categories) {
    const words = String(c).split(' ');
    const lines = labelX && String(c).length * 6.4 > band && words.length > 1
      ? [words.slice(0, Math.ceil(words.length / 2)).join(' '), words.slice(Math.ceil(words.length / 2)).join(' ')]
      : [labelX ? String(c) : tickLabel(Number(c))];
    svg += `<text class="tick" x="${X(c)}" y="${top + ph + 15}" text-anchor="middle">${lines.map((l, i) => `<tspan x="${X(c)}" dy="${i ? 12 : 0}">${esc(l)}</tspan>`).join('')}</text>`;
  }
  svg += `<text class="axis-title" x="${left + pw / 2}" y="${H - 3}" text-anchor="middle">${esc(chart.xLabel)}</text>`;

  // Marks
  const n = chart.series.length;
  chart.series.forEach((s, si) => {
    const c = SERIES_COLORS[si % SERIES_COLORS.length];
    if (chart.chartKind === 'bar') {
      const groupW = labelX ? band * 0.72 : (pw / Math.max(1, s.points.length)) * 0.62;
      const bw = groupW / n;
      for (const p of s.points) {
        const x = X(p.x) - groupW / 2 + si * bw;
        const yTop = Math.min(Y(p.y), Y(0)), h = Math.abs(Y(p.y) - Y(0));
        svg += `<rect class="bar${p.y < 0 ? ' neg' : ''}" data-step="1" x="${x + 1}" y="${yTop}" width="${Math.max(1, bw - 2)}" height="${h}" rx="2" fill="${c}"/>`;
        if (labelX) svg += `<text class="ann" data-step="1" x="${x + bw / 2}" y="${yTop - 5}" text-anchor="middle">${esc(formatValue(p.y, chart.unit))}</text>`;
      }
    } else {
      const pts = s.points.map(p => `${X(p.x).toFixed(1)} ${Y(p.y).toFixed(1)}`);
      svg += `<path class="line" data-step="1" pathLength="1" d="M${pts.join('L')}" stroke="${c}"/>`;
      if (labelX) for (const p of s.points) svg += `<circle class="pt" data-step="1" cx="${X(p.x)}" cy="${Y(p.y)}" r="3.5" fill="${c}"/>`;
    }
  });

  const legend = n > 1
    ? `<div class="legend">${chart.series.map((s, i) => `<span><i style="background:${SERIES_COLORS[i % 3]}"></i>${esc(s.name)}</span>`).join('')}</div>`
    : '';
  el.innerHTML = `${legend}<svg width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">${svg}</svg>`;
  refresh(el.closest('.staged'));
}
