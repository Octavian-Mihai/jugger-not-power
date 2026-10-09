// Checks that web/generator.js matches the Swift ProgramGenerator on the shared cases.
// Run: node web/parity.test.mjs
import fs from 'node:fs';
import vm from 'node:vm';
import { createRequire } from 'node:module';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const require = createRequire(import.meta.url);
const ctx = { window: {} }; vm.createContext(ctx);
vm.runInContext(fs.readFileSync(path.join(here, 'exercises-data.js'), 'utf8'), ctx);
const G = require('./generator.js');
const gen = G.create(ctx.window.FERRUM_EXERCISES);
const fixture = JSON.parse(fs.readFileSync(path.join(here, '../Packages/FerrumCore/Tests/FerrumCoreTests/Fixtures/parity.json'), 'utf8'));

const near = (a, b) => Math.abs((a ?? 0) - (b ?? 0)) < 1e-9;
function setKey(s) {
  const f = x => (x == null ? '' : Number(x).toFixed(6));
  if (s.type === 'percent') return `${s.count} percent ${f(s.pct)} ${s.reps}`;
  if (s.type === 'rir') return `${s.count} rir ${s.reps} ${f(s.rir)}`;
  return `${s.count} range ${s.low} ${s.high} ${f(s.rir)}`;
}
function norm(p, jsShape) {
  return p.blocks.map(b => ({
    head: [b.name, b.phase, b.weeks, !!b.deloadLastWeek, Number(b.rirShiftStart || 0).toFixed(6), Number(b.rirShiftEnd || 0).toFixed(6), Number(b.percentStep || 0).toFixed(6)].join('|'),
    days: b.days.map(d => ({
      name: d.name,
      ex: d.exercises.map(e => [e.exercise, e.rest, e.note || '', ...e.sets.map(setKey)].join(' ; ')),
    })),
  }));
}

let failures = 0;
fixture.forEach((fx, i) => {
  const out = gen.generate(fx.input);
  const a = JSON.stringify(norm(fx.program)), b = JSON.stringify(norm(out));
  const notesOk = JSON.stringify(fx.notes) === JSON.stringify(out.notes);
  const nameOk = fx.program.name === out.name;
  if (a !== b || !notesOk || !nameOk) {
    failures += 1;
    if (failures <= 3) {
      console.error(`case ${i} differs: ${JSON.stringify(fx.input)}`);
      if (!nameOk) console.error(' name', fx.program.name, '!=', out.name);
      if (!notesOk) console.error(' notes', fx.notes, out.notes);
      const A = norm(fx.program), B = norm(out);
      for (let bi = 0; bi < Math.max(A.length, B.length); bi++) {
        if (JSON.stringify(A[bi]) !== JSON.stringify(B[bi])) { console.error(' block', bi, '\n swift:', JSON.stringify(A[bi], null, 1).slice(0, 1500), '\n js:   ', JSON.stringify(B[bi], null, 1).slice(0, 1500)); break; }
      }
    }
  }
});
console.log(failures ? `${failures}/${fixture.length} cases differ` : `all ${fixture.length} cases match the Swift generator`);
process.exit(failures ? 1 : 0);
