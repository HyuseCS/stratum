import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("..", import.meta.url));
let projectConfig = null;
const seen = [];

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

function fake(tokens, { window = 1_000_000, threshold = 800_000, auto = true } = {}) {
  return {
    plugin: { root },
    fs: {
      read: async (path) => {
        if (path === ".stratum/powerline.json") {
          if (projectConfig === null) throw new Error("missing");
          return JSON.stringify(projectConfig);
        }
        return readFileSync(path, "utf8");
      },
    },
    session: {
      usage: async (args) => ({
        context: {
          tokens,
          window,
          breakdown: args?.breakdown ? { isAutoCompactEnabled: auto, autoCompactThreshold: threshold } : undefined,
        },
      }),
    },
    ui: {
      invalidate() {},
      resolve: () => ({ Text: (p) => (seen.push(p), p.children), Box: (p) => p.children.join("") }),
    },
  };
}

async function band(seq, opts, columns = 100) {
  await hooks["session.start"](fake(0, opts), {}, async () => {});
  let $;
  for (const t of seq) {
    $ = fake(t, opts);
    await hooks["turn.complete"]($, {}, async () => {});
  }
  return hooks["ui.render"]($, { bodyColumns: columns }, () => "none");
}

const grow = await band([100_000, 200_000, 300_000, 400_000, 500_000, 600_000]);
check("bar fills to the percent", () => assert.match(grow, /━{12}─{8} 60%/));
check("turns left from mean growth to threshold", () => assert.match(grow, /about 2 turns left/));
check("tokens shown", () => assert.match(grow, /600k\/1M/));

const one = await band([100_000]);
check("no growth yet: no turns text", () => assert.doesNotMatch(one, /turn/));

const off = await band([100_000, 200_000], { auto: false });
check("auto-compact off: turns to a full window", () => assert.match(off, /about 8 turns left/));

const over = await band([700_000, 850_000]);
check("past threshold: compact now", () => assert.match(over, /compact now/));

const narrow = await band([100_000, 200_000], {}, 50);
check("narrow: no bar", () => assert.doesNotMatch(narrow, /━|─/));

async function showersColor() {
  seen.length = 0;
  await band([300_000, 600_000]);
  return seen.find((p) => p.bold).color;
}
const themes = JSON.parse(readFileSync(`${root}/statusline/themes.json`, "utf8"));
const def = await showersColor();
check("no project file: rose-pine Showers color", () => assert.equal(def, "#c4a7e7"));
check("rose-pine theme maps to the same colors", () => assert.equal(themes["rose-pine"].directory.fg, "#c4a7e7"));
projectConfig = { theme: "nord" };
const nord = await showersColor();
check("nord theme: band follows it", () => assert.equal(nord, themes.nord.directory.fg));
projectConfig = { theme: "custom", colors: { custom: { directory: { bg: "#000000", fg: "#123456" } } } };
const custom = await showersColor();
check("custom colors: band follows them", () => assert.equal(custom, "#123456"));
projectConfig = null;

process.exit(fails);
