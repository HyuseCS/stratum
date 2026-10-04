import assert from "node:assert/strict";
import { fileURLToPath } from "node:url";

const tw = await import(fileURLToPath(new URL("../hooks/token-weather.mjs", import.meta.url)));
const hooks = {};
tw.register((event, a, b) => (hooks[event] = b ?? a));

let fails = 0;
function check(name, fn) {
  try {
    fn();
    console.log(`ok   ${name}`);
  } catch (err) {
    console.log(`FAIL ${name}: ${err.message}`);
    fails = 1;
  }
}

let written = null;
let hasStratum = true;
function fake(tokens, { window = 1_000_000, threshold = 800_000, auto = true } = {}) {
  return {
    fs: {
      exists: async (path) => path === ".stratum" && hasStratum,
      write: async (path, text) => (written = { path, state: JSON.parse(text) }),
    },
    session: {
      id: async () => "S1",
      usage: async (args) => ({
        context: {
          tokens,
          window,
          breakdown: args?.breakdown ? { isAutoCompactEnabled: auto, autoCompactThreshold: threshold } : undefined,
        },
      }),
    },
  };
}

async function run(seq, opts) {
  written = null;
  await hooks["session.start"](fake(0, opts), {}, async () => {});
  for (const t of seq) {
    await hooks["turn.complete"](fake(t, opts), {}, async () => {});
  }
  return written;
}

check("no drawing hook", () => assert.equal(hooks["ui.render"], undefined));

const grow = await run([100_000, 200_000, 400_000]);
check("writes .stratum/weather.json", () => assert.equal(grow.path, ".stratum/weather.json"));
check("state has session, fill and threshold", () =>
  assert.deepEqual(
    { session: grow.state.session, tokens: grow.state.tokens, window: grow.state.window, percent: grow.state.percent, compactAt: grow.state.compactAt },
    { session: "S1", tokens: 400_000, window: 1_000_000, percent: 40, compactAt: 800_000 },
  ));
check("growth is the mean of growing turns", () => assert.equal(grow.state.growth, 150_000));

const one = await run([100_000]);
check("one turn: no growth yet", () => assert.equal(one.state.growth, null));

const off = await run([100_000, 200_000], { auto: false });
check("auto-compact off: threshold is the window", () => assert.equal(off.state.compactAt, 1_000_000));

const shrink = await run([300_000, 100_000, 200_000]);
check("shrinking turns are left out of growth", () => assert.equal(shrink.state.growth, 100_000));

hasStratum = false;
const none = await run([100_000, 200_000]);
check("no .stratum folder: nothing written", () => assert.equal(none, null));

process.exit(fails);
