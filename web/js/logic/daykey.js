// A DayKey is a calendar date with no time and no time zone, stored as the number yyyymmdd
// (20261124). "Today" is the date where you are right now. Day arithmetic happens on plain UTC
// dates, so daylight-saving nights (23 or 25 hours long) can't shift a date by one.

const DAY_MS = 86_400_000;

export function makeKey(y, m, d) {
  return y * 10000 + m * 100 + d;
}

export function parts(key) {
  return { y: Math.floor(key / 10000), m: Math.floor(key / 100) % 100, d: key % 100 };
}

/** The DayKey of an instant, in the device's time zone or in a named IANA zone. */
export function dayKeyOf(date, timeZone) {
  if (!timeZone) return makeKey(date.getFullYear(), date.getMonth() + 1, date.getDate());
  const f = new Intl.DateTimeFormat('en-CA', { timeZone, year: 'numeric', month: '2-digit', day: '2-digit' });
  const [y, m, d] = f.format(date).split('-').map(Number);
  return makeKey(y, m, d);
}

/** Seconds east of UTC at that instant on this device (e.g. Tokyo +32400, Los Angeles -28800). */
export function utcOffsetOf(date) {
  return -date.getTimezoneOffset() * 60;
}

function toUTC(key) {
  const { y, m, d } = parts(key);
  return Date.UTC(y, m - 1, d);
}

function fromUTC(ms) {
  const t = new Date(ms);
  return makeKey(t.getUTCFullYear(), t.getUTCMonth() + 1, t.getUTCDate());
}

export function addDays(key, n) {
  return fromUTC(toUTC(key) + n * DAY_MS);
}

/** Whole days from a to b (positive when b is later). */
export function daysBetween(a, b) {
  return Math.round((toUTC(b) - toUTC(a)) / DAY_MS);
}

/** 1 = Monday … 7 = Sunday (the numbering Intl's weekInfo uses). */
export function weekday(key) {
  const js = new Date(toUTC(key)).getUTCDay(); // 0 = Sunday
  return js === 0 ? 7 : js;
}

/** The first day of the week containing `key`. `firstDay` is 1 (Monday) … 7 (Sunday). */
export function weekStart(key, firstDay) {
  const back = (weekday(key) - firstDay + 7) % 7;
  return addDays(key, -back);
}

/** The week start the person's region uses: Monday in most places, Sunday in the US. */
export function regionFirstDay() {
  try {
    const loc = new Intl.Locale(globalThis.navigator?.language ?? 'en-US');
    const info = loc.getWeekInfo?.() ?? loc.weekInfo;
    if (info?.firstDay) return info.firstDay;
  } catch { /* older browsers */ }
  return 7;
}

export function dateOf(key) {
  const { y, m, d } = parts(key);
  return new Date(y, m - 1, d);
}

export function formatKey(key, options = { weekday: 'short', month: 'short', day: 'numeric' }) {
  const { y, m, d } = parts(key);
  return new Intl.DateTimeFormat(undefined, { ...options, timeZone: 'UTC' }).format(new Date(Date.UTC(y, m - 1, d)));
}
