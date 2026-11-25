// Development helper for checking layouts: jump to a lesson section with every visual fully built.
//   const { show } = await import('/tests/dev-show.js'); await show('phi-stoicism', 'porch');
import { setShown } from '../js/render/stage.js';

export async function show(lessonID, sectionID, offset = 70) {
  if (!location.hash.endsWith('/' + lessonID)) {
    location.hash = '#/lesson/' + lessonID;
    await new Promise(r => setTimeout(r, 900));
  }
  document.querySelectorAll('.staged').forEach(s => setShown(s, +s.dataset.total, { instant: true }));
  document.querySelector('.resume-pill')?.classList.add('hide');
  const el = document.querySelector(`[data-sid="${sectionID}"]`);
  scrollTo(0, el.getBoundingClientRect().top + scrollY - offset);
  await new Promise(r => setTimeout(r, 600));
  return el.getBoundingClientRect().height;
}
