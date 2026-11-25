// Small pieces shared by several screens.
import { esc, md, plural } from './text.js';
import { icon } from './icons.js';
import { topicStyle } from './palette.js';
import { addDays, weekStart, formatKey } from './logic/daykey.js';

export const app = {
  name: 'Strata',
  version: '0.2-web',
  /** Filled in by app.js: { lib, progress, go(hash) } */
};

/** Goal ring: lessons done today out of the daily goal. */
export function goalRing(done, goal, { size = 52 } = {}) {
  const r = 22, c = 2 * Math.PI * r, f = Math.min(1, done / Math.max(1, goal));
  return `<div class="ring" style="width:${size}px;height:${size}px" role="img" aria-label="Daily goal: ${done} of ${goal} ${goal === 1 ? 'lesson' : 'lessons'} today">
    <svg viewBox="0 0 52 52"><circle class="track" cx="26" cy="26" r="${r}" fill="none" stroke-width="5"/>
    <circle class="fill" cx="26" cy="26" r="${r}" fill="none" stroke-width="5" stroke-linecap="round"
      stroke-dasharray="${c}" stroke-dashoffset="${c * (1 - f)}"/></svg>
    <span class="ring-label" aria-hidden="true">${Math.min(done, goal)}/${goal}</span></div>`;
}

export function streakChip(streak) {
  const label = streak.todayDone || !streak.count
    ? `${plural(streak.count, 'day')} streak`
    : `${plural(streak.count, 'day')} streak. Do a lesson today to keep it.`;
  return `<div class="streak-chip" role="img" aria-label="${label}">${icon('stack')}<span aria-hidden="true">${streak.count}</span></div>`;
}

/** Mon–Sun (or Sun–Sat) dots: done / frozen / forgiven / missed / today. */
export function weekDots(streak, today, firstDay) {
  const start = weekStart(today, firstDay);
  const days = Array.from({ length: 7 }, (_, i) => addDays(start, i));
  const names = { done: 'done', frozen: 'freeze used', forgiven: 'skipped by time-zone change', missed: 'missed', none: '' };
  return `<div class="week" role="list" aria-label="This week">${days.map(d => {
    let s = d > today ? 'future' : streak.status(d);
    if (d === today && s === 'none') s = 'today';
    const text = formatKey(d, { weekday: 'narrow' });
    const label = `${formatKey(d, { weekday: 'long' })}${names[s] ? `: ${names[s]}` : d === today ? ': today' : ''}`;
    return `<div class="s-${s}" role="listitem" aria-label="${label}"><span aria-hidden="true">${s === 'done' ? '✓' : s === 'frozen' ? '✱' : ''}</span><b aria-hidden="true">${text}</b></div>`;
  }).join('')}</div>`;
}

export function lessonCard(lesson, topic, progress) {
  const p = progress.lesson(lesson.id);
  const done = progress.isCompleted(lesson.id);
  const status = done ? icon('checkFill', { cls: 'status-ic done', label: 'Completed' })
    : p.status === 'inProgress' ? `<span class="pill">${Math.round((p.furthestProgress ?? 0) * 100)}%</span>` : '';
  return `<a class="lesson-card topic-scope" style="${topicStyle(topic)}" href="#/lesson/${esc(lesson.id)}">
    <div><div class="eyebrow">${icon(topic.symbol)}${esc(topic.name)}</div><h3>${md(lesson.title)}</h3></div>
    <div class="meta"><span>${lesson.minutes} min</span>${status}</div></a>`;
}

export function statusIcon(lesson, progress) {
  if (progress.isCompleted(lesson.id)) return icon('checkFill', { cls: 'status-ic done', label: 'Completed' });
  const p = progress.lesson(lesson.id);
  if (p.status === 'inProgress') {
    const f = p.furthestProgress ?? 0, r = 10, c = 2 * Math.PI * r;
    return `<svg class="status-ic" viewBox="0 0 26 26" role="img" aria-label="In progress, ${Math.round(f * 100)} percent">
      <circle cx="13" cy="13" r="${r}" fill="none" stroke="var(--rule)" stroke-width="3"/>
      <circle cx="13" cy="13" r="${r}" fill="none" stroke="var(--topic)" stroke-width="3" stroke-dasharray="${c}" stroke-dashoffset="${c * (1 - f)}" transform="rotate(-90 13 13)" stroke-linecap="round"/></svg>`;
  }
  return `<svg class="status-ic" viewBox="0 0 26 26" role="img" aria-label="Not started"><circle cx="13" cy="13" r="10" fill="none" stroke="var(--rule)" stroke-width="2"/></svg>`;
}

export function tabbar(active, dueCount) {
  const tab = (id, href, label, ic, extra = '') =>
    `<a href="${href}" ${active === id ? 'aria-current="page"' : ''}>${icon(ic)}${label}${extra}</a>`;
  return `<nav class="tabbar" aria-label="Main">${tab('home', '#/', 'Home', 'home')}${tab('review', '#/review', 'Review', 'cards',
    dueCount ? `<span class="badge" aria-label="${dueCount} due">${dueCount > 99 ? '99+' : dueCount}</span>` : '')}${tab('you', '#/you', 'You', 'person')}</nav>`;
}

/** A calendar file with a daily repeating reminder. The web can't schedule notifications without a server. */
export function reminderICS(hour, minute, name) {
  const pad = n => String(n).padStart(2, '0');
  const t = new Date();
  t.setDate(t.getDate() + 1);
  const start = `${t.getFullYear()}${pad(t.getMonth() + 1)}${pad(t.getDate())}T${pad(hour)}${pad(minute)}00`;
  const stamp = new Date().toISOString().replace(/[-:]/g, '').replace(/\.\d+/, '');
  return [
    'BEGIN:VCALENDAR', 'VERSION:2.0', `PRODID:-//${name}//Daily reminder//EN`, 'BEGIN:VEVENT',
    `UID:${name.toLowerCase()}-daily-reminder@localhost`, `DTSTAMP:${stamp}`, `DTSTART:${start}`, 'DURATION:PT15M',
    'RRULE:FREQ=DAILY', `SUMMARY:${name}: your next layer is ready`, 'DESCRIPTION:One lesson keeps your streak going.',
    'BEGIN:VALARM', 'ACTION:DISPLAY', 'TRIGGER:PT0M', `DESCRIPTION:${name} reminder`, 'END:VALARM',
    'END:VEVENT', 'END:VCALENDAR', '',
  ].join('\r\n');
}

export function downloadReminder(settings) {
  const blob = new Blob([reminderICS(settings.reminderHour, settings.reminderMinute, app.name)], { type: 'text/calendar' });
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = `${app.name}-reminder.ics`;
  document.body.append(a);
  a.click();
  setTimeout(() => { URL.revokeObjectURL(a.href); a.remove(); }, 1000);
}

export { md, esc, icon, topicStyle };
