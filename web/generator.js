/* Ferrum program generator: a line-for-line port of ProgramGenerator.swift.
 * Parity with the Swift engine is checked by web/parity.test.mjs against
 * Packages/FerrumCore/Tests/FerrumCoreTests/Fixtures/parity.json. */
(function (root) {
  'use strict';

  const MAIN_IDS = ['back-squat', 'barbell-bench-press', 'deadlift'];
  const ALWAYS = new Set(['bodyweight', 'gripper', 'ab wheel']);
  const LOWER_PATTERNS = new Set(['Squat', 'Lunge / Split', 'Hinge', 'Knee Flexion', 'Knee Extension', 'Glute Isolation']);
  const ISOLATION = new Set(['Biceps', 'Triceps', 'Delt Isolation', 'Chest Isolation', 'Knee Flexion', 'Knee Extension',
    'Glute Isolation', 'Other Isolation', 'Accessory', 'Vertical Pull', 'Horizontal Pull', 'Flexion']);

  const EQUIPMENT_OPTIONS = [
    ['barbell', 'Barbell & plates'], ['dumbbell', 'Dumbbells'], ['cable', 'Cable station'], ['machine', 'Machines'],
    ['smith machine', 'Smith machine'], ['kettlebell', 'Kettlebells'], ['landmine', 'Landmine'],
    ['trap bar', 'Trap bar'], ['safety bar', 'Safety squat bar'], ['band', 'Bands'],
  ];

  const GOALS = {
    powerlifting: { title: 'Powerlifting', blurb: 'Peak squat, bench and deadlift through structured strength cycles.' },
    powerbuilding: { title: 'Powerbuilding', blurb: 'Heavy main lifts plus bodybuilding volume for size.' },
    powerCombo: { title: 'PowerCombo', blurb: 'A hypertrophy phase followed by a strength phase.' },
    fullBody: { title: 'Full Body', blurb: 'Every session trains the whole body. Great for 2-4 days a week.' },
  };

  const totalSets = ex => ex.sets.reduce((a, g) => a + g.count, 0);
  const estimatedMinutes = day => {
    const seconds = day.exercises.reduce((a, e) => a + totalSets(e) * (40 + e.rest), 0);
    return 5 + Math.round(seconds / 60);
  };

  // ---------- day catalogue (mirrors the Swift computed properties)
  const acc = (chain, muscle, sets, low, high) => ({ kind: 'accessory', chain, muscle, sets, low, high });
  const main = chain => ({ kind: 'main', chain });
  const secondary = chain => ({ kind: 'secondary', chain });

  const squatDay = () => ({ name: 'Squat', items: [
    main(['back-squat', 'safety-bar-squat', 'front-squat', 'smith-machine-squat', 'hack-squat', 'leg-press', 'goblet-squat', 'sissy-squat']),
    secondary(['front-squat', 'hack-squat', 'leg-press', 'goblet-squat', 'bulgarian-split-squat']),
    acc(['lying-leg-curl', 'seated-leg-curl', 'nordic-curl'], 'hamstrings', 3, 8, 12),
    acc(['leg-press', 'hack-squat', 'leg-extension'], 'quadriceps', 3, 8, 12),
    acc(['hanging-leg-raise', 'cable-crunch', 'plank'], 'core-and-abs', 3, 10, 15),
    acc(['calf-raise'], 'calves', 3, 10, 15)] });

  const benchDay = () => ({ name: 'Bench', items: [
    main(['barbell-bench-press', 'dumbbell-bench-press', 'smith-machine-bench-press', 'machine-chest-press', 'push-up']),
    secondary(['close-grip-bench-press', 'incline-dumbbell-press', 'dips', 'push-up']),
    acc(['chest-supported-dumbbell-row', 'one-arm-dumbbell-row', 'machine-row', 'inverted-row'], 'lats', 3, 8, 12),
    acc(['incline-dumbbell-press', 'machine-press', 'push-up'], 'chest-pectorals', 3, 8, 12),
    acc(['lateral-raise', 'cable-lateral-raise'], 'lateral-delts', 3, 12, 15),
    acc(['tricep-pushdown', 'skull-crusher', 'dips'], 'triceps', 3, 10, 15)] });

  const deadliftDay = () => ({ name: 'Deadlift', items: [
    main(['deadlift', 'trap-bar-deadlift', 'sumo-deadlift', 'romanian-deadlift', 'single-leg-romanian-deadlift', 'back-extension']),
    secondary(['romanian-deadlift', 'single-leg-romanian-deadlift', 'good-morning', 'back-extension']),
    acc(['lat-pulldown', 'pull-up', 'assisted-pull-up', 'inverted-row'], 'lats', 3, 8, 12),
    acc(['seated-cable-row', 'barbell-row', 'one-arm-dumbbell-row', 'inverted-row'], 'rhomboids', 3, 8, 12),
    acc(['back-extension'], 'erectors', 3, 10, 15),
    acc(['dumbbell-curl', 'barbell-curl', 'cable-curl'], 'biceps', 3, 10, 15)] });

  const upperVolumeDay = () => ({ name: 'Upper Volume', items: [
    secondary(['overhead-press', 'dumbbell-shoulder-press', 'machine-shoulder-press', 'landmine-press', 'push-up']),
    acc(['incline-dumbbell-press', 'machine-press', 'push-up'], 'chest-pectorals', 3, 8, 12),
    acc(['chest-supported-t-bar-row', 'machine-row', 'one-arm-dumbbell-row', 'inverted-row'], 'lats', 3, 8, 12),
    acc(['lat-pulldown', 'pull-up', 'assisted-pull-up'], 'lats', 3, 8, 12),
    acc(['lateral-raise', 'cable-lateral-raise'], 'lateral-delts', 3, 12, 15),
    acc(['overhead-cable-triceps-extension', 'tricep-pushdown', 'skull-crusher', 'dips'], 'triceps', 3, 10, 15),
    acc(['hammer-curl', 'dumbbell-curl', 'cable-curl'], 'biceps', 3, 10, 15)] });

  const lowerVolumeDay = () => ({ name: 'Lower Volume', items: [
    secondary(['leg-press', 'hack-squat', 'goblet-squat', 'bulgarian-split-squat', 'sissy-squat']),
    acc(['romanian-deadlift', 'single-leg-romanian-deadlift', 'back-extension'], 'hamstrings', 3, 8, 12),
    acc(['bulgarian-split-squat', 'walking-lunge', 'step-up', 'reverse-lunge'], 'quadriceps', 3, 8, 12),
    acc(['lying-leg-curl', 'seated-leg-curl', 'nordic-curl'], 'hamstrings', 3, 8, 12),
    acc(['leg-extension'], 'quadriceps', 3, 10, 15),
    acc(['calf-raise'], 'calves', 4, 10, 15)] });

  const benchVolumeDay = () => ({ name: 'Bench Volume', items: [
    secondary(['barbell-bench-press', 'dumbbell-bench-press', 'machine-chest-press', 'push-up']),
    acc(['pull-up', 'lat-pulldown', 'assisted-pull-up', 'inverted-row'], 'lats', 3, 6, 10),
    acc(['dumbbell-shoulder-press', 'machine-shoulder-press', 'overhead-press'], 'anterior-delts', 3, 8, 12),
    acc(['cable-fly', 'pec-deck', 'dumbbell-fly'], 'chest-pectorals', 3, 10, 15),
    acc(['face-pull', 'rear-delt-fly', 'reverse-pec-deck'], 'posterior-delts', 3, 12, 20)] });

  function fullBodyDays(count) {
    const a = { name: 'Full Body A', items: [
      main(['back-squat', 'safety-bar-squat', 'smith-machine-squat', 'hack-squat', 'leg-press', 'goblet-squat', 'sissy-squat']),
      secondary(['barbell-bench-press', 'dumbbell-bench-press', 'machine-chest-press', 'push-up']),
      acc(['barbell-row', 'seated-cable-row', 'machine-row', 'one-arm-dumbbell-row', 'inverted-row'], 'lats', 3, 8, 12),
      acc(['lateral-raise', 'cable-lateral-raise'], 'lateral-delts', 3, 12, 15),
      acc(['hanging-leg-raise', 'cable-crunch', 'plank'], 'core-and-abs', 3, 10, 15)] };
    const b = { name: 'Full Body B', items: [
      main(['deadlift', 'trap-bar-deadlift', 'romanian-deadlift', 'single-leg-romanian-deadlift', 'back-extension']),
      secondary(['overhead-press', 'dumbbell-shoulder-press', 'machine-shoulder-press', 'landmine-press', 'push-up']),
      acc(['lat-pulldown', 'pull-up', 'assisted-pull-up', 'inverted-row'], 'lats', 3, 8, 12),
      acc(['leg-extension', 'leg-press', 'bulgarian-split-squat'], 'quadriceps', 3, 10, 15),
      acc(['dumbbell-curl', 'cable-curl', 'barbell-curl'], 'biceps', 2, 10, 15),
      acc(['tricep-pushdown', 'skull-crusher', 'dips'], 'triceps', 2, 10, 15)] };
    const c = { name: 'Full Body C', items: [
      secondary(['front-squat', 'hack-squat', 'leg-press', 'goblet-squat', 'bulgarian-split-squat']),
      secondary(['incline-dumbbell-press', 'machine-press', 'dips', 'push-up']),
      acc(['chest-supported-dumbbell-row', 'machine-row', 'one-arm-dumbbell-row', 'inverted-row'], 'lats', 3, 8, 12),
      acc(['romanian-deadlift', 'single-leg-romanian-deadlift', 'back-extension'], 'hamstrings', 3, 8, 12),
      acc(['face-pull', 'rear-delt-fly', 'reverse-pec-deck'], 'posterior-delts', 3, 12, 20),
      acc(['calf-raise'], 'calves', 3, 10, 15)] };
    const d = { name: 'Full Body D', items: [
      main(['barbell-bench-press', 'dumbbell-bench-press', 'smith-machine-bench-press', 'machine-chest-press', 'push-up']),
      secondary(['trap-bar-deadlift', 'romanian-deadlift', 'single-leg-romanian-deadlift', 'back-extension']),
      acc(['one-arm-cable-row', 'one-arm-dumbbell-row', 'machine-row', 'inverted-row'], 'lats', 3, 8, 12),
      acc(['bulgarian-split-squat', 'walking-lunge', 'step-up', 'reverse-lunge'], 'quadriceps', 3, 8, 12),
      acc(['cable-lateral-raise', 'lateral-raise'], 'lateral-delts', 3, 12, 15),
      acc(['plank', 'ab-wheel'], 'core-and-abs', 3, 30, 60)] };
    const cycle = [a, b, c, d];
    return Array.from({ length: count }, (_, i) => cycle[i % cycle.length]);
  }

  function powerDays(count) {
    if (count === 2) {
      const d1 = squatDay(); d1.name = 'Squat & Bench';
      d1.items = [squatDay().items[0],
        acc(['lying-leg-curl', 'seated-leg-curl', 'nordic-curl'], 'hamstrings', 3, 8, 12),
        secondary(['barbell-bench-press', 'dumbbell-bench-press', 'machine-chest-press', 'push-up']),
        acc(['chest-supported-dumbbell-row', 'one-arm-dumbbell-row', 'machine-row', 'inverted-row'], 'lats', 3, 8, 12)];
      const d2 = deadliftDay(); d2.name = 'Deadlift & Press';
      d2.items = [deadliftDay().items[0],
        acc(['lat-pulldown', 'pull-up', 'assisted-pull-up', 'inverted-row'], 'lats', 3, 8, 12),
        secondary(['overhead-press', 'dumbbell-shoulder-press', 'machine-shoulder-press', 'push-up']),
        acc(['tricep-pushdown', 'skull-crusher', 'dips'], 'triceps', 3, 10, 15)];
      return [d1, d2];
    }
    if (count === 3) return [squatDay(), benchDay(), deadliftDay()];
    if (count === 4) return [squatDay(), benchDay(), deadliftDay(), upperVolumeDay()];
    if (count === 5) return [squatDay(), benchDay(), deadliftDay(), upperVolumeDay(), lowerVolumeDay()];
    return [squatDay(), benchDay(), deadliftDay(), upperVolumeDay(), lowerVolumeDay(), benchVolumeDay()];
  }

  // ---------- generator
  function create(library) {
    const byId = new Map(library.map(e => [e.id, e]));
    const nameOf = id => (byId.get(id) ? byId.get(id).name : id);

    function makeFilter(input) {
      const equipment = new Set(input.equipment || []);
      const dislikes = new Set(input.dislikes || []);
      const avoid = new Set(input.avoidPatterns || []);
      const favorites = new Set(input.favorites || []);
      const allowed = id => {
        const e = byId.get(id);
        if (!e) return false;
        if (dislikes.has(id) || avoid.has(e.pattern)) return false;
        if (equipment.size === 0) return true;
        return equipment.has(e.equipment) || ALWAYS.has(e.equipment);
      };
      const pick = (chain, muscle) => {
        let candidates = chain.filter(allowed);
        if (muscle) {
          const extra = library.filter(e => e.primary[0] === muscle && !MAIN_IDS.includes(e.id) && allowed(e.id)).map(e => e.id);
          const before = candidates.slice();
          candidates = candidates.concat(extra.filter(id => !before.includes(id)));
          const fav = candidates.find(id => favorites.has(id));
          if (fav !== undefined) return fav;
        }
        return candidates[0];
      };
      return { allowed, pick, favorites };
    }

    const rangeSet = (count, low, high, rir) => ({ count, type: 'range', low, high, rir });
    const exercise = (id, sets, rest, note = '') => ({ exercise: id, sets, rest, note, reference: '' });

    function build(spec, scheme, accessoryLimit, extraSets, secondaryRIR, filter, report) {
      const out = []; const core = []; let accCount = 0;
      for (const item of spec.items) {
        if (item.kind === 'main') {
          const id = filter.pick(item.chain);
          if (id === undefined) continue;
          const canonical = MAIN_IDS.includes(id);
          if (id !== item.chain[0]) report.push(`${nameOf(item.chain[0])} swapped for ${nameOf(id)} based on your equipment and exercise choices.`);
          let target; const sets = scheme.sets;
          if (scheme.type === 'percent') target = { type: 'percent', pct: scheme.pct, reps: scheme.reps };
          else if (scheme.type === 'rir') target = { type: 'rir', reps: scheme.reps, rir: scheme.rir };
          else target = { type: 'range', low: scheme.low, high: scheme.high, rir: scheme.rir };
          if (!canonical) {
            if (target.type === 'percent') target = { type: 'range', low: target.reps, high: target.reps + 3, rir: 2 };
            else if (target.type === 'rir') target = { type: 'range', low: target.reps, high: target.reps + 3, rir: target.rir };
          }
          out.push(exercise(id, [{ count: sets, ...target }], 180)); core.push(true);
        } else if (item.kind === 'secondary') {
          const id = filter.pick(item.chain);
          if (id === undefined) continue;
          out.push(exercise(id, [rangeSet(3, 6, 10, secondaryRIR)], 150)); core.push(true);
        } else {
          if (accCount >= accessoryLimit) continue;
          const id = filter.pick(item.chain, item.muscle);
          if (id === undefined || out.some(e => e.exercise === id)) continue;
          accCount += 1;
          out.push(exercise(id, [rangeSet(Math.max(item.sets + extraSets, 2), item.low, item.high, 2)], 90)); core.push(false);
        }
      }
      return { day: { name: spec.name, exercises: out }, core };
    }

    function fit(day, core, minutes) {
      if (!minutes) return day;
      day = { ...day, exercises: day.exercises.slice() }; core = core.slice();
      let guard = 0;
      while (estimatedMinutes(day) > minutes && core.lastIndexOf(false) >= 0 && guard < 50) {
        const idx = core.lastIndexOf(false);
        day.exercises.splice(idx, 1); core.splice(idx, 1); guard += 1;
      }
      while (estimatedMinutes(day) > minutes && guard < 100) {
        guard += 1;
        let best = -1;
        day.exercises.forEach((e, i) => { if (best < 0 || totalSets(e) > totalSets(day.exercises[best])) best = i; });
        if (best < 0 || totalSets(day.exercises[best]) <= 2) break;
        const e = day.exercises[best];
        let g = -1;
        e.sets.forEach((s, i) => { if (s.count > 1) g = i; });
        if (g < 0) break;
        day.exercises[best] = { ...e, sets: e.sets.map((s, i) => i === g ? { ...s, count: s.count - 1 } : s) };
      }
      return day;
    }

    const isLowerDay = d => {
      if (!d.exercises.length) return false;
      const e = byId.get(d.exercises[0].exercise);
      return !!e && LOWER_PATTERNS.has(e.pattern);
    };

    function addFavorites(days, filter) {
      const used = new Set(days.flatMap(d => d.day.exercises.map(e => e.exercise)));
      for (const id of [...filter.favorites].sort()) {
        if (used.has(id) || !filter.allowed(id)) continue;
        const e = byId.get(id); if (!e) continue;
        const lower = LOWER_PATTERNS.has(e.pattern) || (e.pattern === 'Other Isolation' && e.primary[0] === 'calves');
        const matching = days.map((_, i) => i).filter(i => isLowerDay(days[i].day) === lower);
        const pool = matching.length ? matching : days.map((_, i) => i);
        let target = pool[0];
        for (const i of pool) if (days[i].day.exercises.length < days[target].day.exercises.length) target = i;
        days[target].day.exercises.push(exercise(id, [rangeSet(3, 8, 12, 2)], 90, 'Favourite'));
        days[target].core.push(false);
      }
    }

    function applyEmphasis(muscles, blocks, filter, minutes) {
      for (const muscle of muscles) {
        const candidates = library.filter(e => e.primary[0] === muscle && ISOLATION.has(e.pattern) && filter.allowed(e.id));
        const ex = candidates.find(e => filter.favorites.has(e.id)) || candidates[0];
        if (!ex) continue;
        for (const block of blocks) {
          const n = block.days.length; if (!n) continue;
          const targets = new Set(n >= 4 ? [0, Math.floor(n / 2)] : [0, n - 1]);
          for (const di of targets) {
            if (block.days[di].exercises.some(e => e.exercise === ex.id)) continue;
            const day = { ...block.days[di], exercises: block.days[di].exercises.concat([exercise(ex.id, [rangeSet(3, 10, 15, 1)], 75, 'Emphasis')]) };
            if (minutes && estimatedMinutes(day) > minutes) continue;
            block.days[di] = day;
          }
        }
      }
    }

    function generate(raw) {
      const input = { goal: 'powerbuilding', daysPerWeek: 4, experience: 'intermediate', emphasis: [], ...raw };
      input.daysPerWeek = Math.min(Math.max(input.daysPerWeek, 2), 6);
      const specs = input.goal === 'fullBody' ? fullBodyDays(input.daysPerWeek) : powerDays(input.daysPerWeek);
      const extra = input.experience === 'advanced' ? 1 : (input.experience === 'beginner' ? -1 : 0);
      const beginnerOffset = input.experience === 'beginner' ? -0.05 : 0;
      const filter = makeFilter(input);
      const report = [];
      const minutes = input.sessionMinutes || null;

      const block = (name, phase, weeks, scheme, accLimit, o = {}) => {
        const built = specs.map(s => build(s, scheme, accLimit, extra, o.secondaryRIR ?? 2, filter, report));
        addFavorites(built, filter);
        return { name, phase, weeks, deloadLastWeek: !!o.deload, rirShiftStart: o.rirStart || 0, rirShiftEnd: o.rirEnd || 0,
                 percentStep: o.step || 0, days: built.map(b => fit(b.day, b.core, minutes)) };
      };
      const pct = (sets, reps, p) => ({ type: 'percent', sets, reps, pct: p });
      const rir = (sets, reps, r) => ({ type: 'rir', sets, reps, rir: r });
      const range = (sets, low, high, r) => ({ type: 'range', sets, low, high, rir: r });

      let blocks;
      switch (input.goal) {
        case 'powerlifting':
          blocks = [
            block('Accumulation', 'hypertrophy', 4, pct(4, 6, 0.70 + beginnerOffset), 3, { step: 0.025, deload: true }),
            block('Intensification', 'strength', 4, pct(4, 4, 0.80 + beginnerOffset), 2, { step: 0.025, deload: true }),
          ];
          if (input.experience !== 'beginner') blocks.push(block('Peaking', 'peaking', 3, pct(3, 2, 0.88), 1, { step: 0.02 }));
          break;
        case 'powerbuilding':
          blocks = [
            block('Hypertrophy', 'hypertrophy', 4, range(4, 6, 10, 3), 5, { rirStart: 0, rirEnd: -1, deload: true }),
            block('Strength', 'strength', 4, rir(4, 5, 3), 4, { rirStart: 0, rirEnd: -1, deload: true }),
            block('Intensity', 'peaking', 3, rir(3, 3, 2), 3, { rirStart: 0, rirEnd: -1 }),
          ];
          break;
        case 'powerCombo':
          blocks = [
            block('Hypertrophy Phase', 'hypertrophy', 6, range(4, 8, 12, 3), 5, { rirStart: 0, rirEnd: -2, deload: true }),
            block('Strength Phase', 'strength', 6, pct(4, 5, 0.75 + beginnerOffset), 3, { step: 0.02, deload: true }),
          ];
          break;
        default:
          blocks = [
            block('Volume', 'hypertrophy', 6, range(3, 6, 10, 3), 5, { rirStart: 0, rirEnd: -1, deload: true }),
            block('Strength', 'strength', 6, rir(4, 5, 3), 5, { rirStart: 0, rirEnd: -1, deload: true }),
          ];
      }
      applyEmphasis(input.emphasis || [], blocks, filter, minutes);
      const goalTitle = GOALS[input.goal].title;
      const notes = []; for (const n of report) if (!notes.includes(n)) notes.push(n);
      return { name: input.name || `${goalTitle} · ${input.daysPerWeek} days`, blocks, notes };
    }

    return { generate };
  }

  const api = { create, estimatedMinutes, totalSets, EQUIPMENT_OPTIONS, GOALS };
  if (typeof module !== 'undefined' && module.exports) module.exports = api; else root.FerrumGenerator = api;
})(typeof window !== 'undefined' ? window : globalThis);
