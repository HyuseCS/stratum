import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

const path = process.env.ST_PR_SCRIPT ?? fileURLToPath(new URL("../workflows/pr.js", import.meta.url));
const prefix = "export const meta = {";
let text;
try {
  text = readFileSync(path, "utf8");
  if (!text.startsWith(prefix)) throw new Error(`script does not start with ${prefix}`);
  text = "globalThis.meta = {" + text.slice(prefix.length);
} catch (err) {
  console.log(`FAIL load: ${err.message}`);
  process.exit(1);
}

const READ_ONLY = "Read only: do not edit, stage, commit, push or install anything, and do not run gh.";
const textLabels = ["facts:tests", "facts:frs", "facts:areas", "facts:plan"];
const problem = { problems: [{ line: 1, wrong: "a", right: "b" }] };
const oneDrop = { dropped: [{ line: 1, why: "w" }] };

let readCount = 25;

function defaults(label) {
  if (textLabels.includes(label)) return "ok";
  if (label === "facts:scan") return { finds: [], read: readCount };
  if (label.startsWith("chunk:")) return { flagged: [] };
  if (label === "draft") return { title: "T", unverified: [] };
  if (label.startsWith("refute:")) return { problems: [] };
  if (label.startsWith("fix:")) return { dropped: [] };
  throw new Error(`unexpected label ${label}`);
}

function makeCommits(n) {
  return Array.from({ length: n }, (_, i) => {
    const k = String(i + 1).padStart(2, "0");
    return `h${k} s${k}`;
  });
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function run(fakes = {}, commits = makeCommits(25), extra = {}) {
  const calls = [];
  const phases = [];
  let mark = 0;
  let inFlight = 0;
  let maxFix = 0;
  readCount = commits.length;
  globalThis.args = extra === null ? undefined : { projectRoot: "/p", pluginRoot: "/g", scratchpad: "/s", base: "main", branch: "b", featureDir: "", commits, ...extra };
  globalThis.agent = async (prompt, opts) => {
    const call = { prompt, opts, start: ++mark, end: 0 };
    calls.push(call);
    const isFix = opts.label.startsWith("fix:");
    if (isFix) maxFix = Math.max(maxFix, ++inFlight);
    await sleep(5);
    if (isFix) inFlight--;
    call.end = ++mark;
    return opts.label in fakes ? fakes[opts.label] : defaults(opts.label);
  };
  globalThis.parallel = async (thunks) =>
    Promise.all(thunks.map(async (t) => { try { return await t(); } catch { return null; } }));
  globalThis.pipeline = () => { throw new Error("pipeline unused"); };
  globalThis.phase = (title) => { phases.push(title); };
  globalThis.log = () => {};
  const realNow = Date.now;
  const realRandom = Math.random;
  Date.now = () => { throw new Error("Date.now"); };
  Math.random = () => { throw new Error("Math.random"); };
  let result;
  try {
    result = await new (async () => {}).constructor(text)();
  } finally {
    Date.now = realNow;
    Math.random = realRandom;
  }
  return { result, calls, phases, maxFix };
}

const labels = (calls, p) => calls.filter((c) => c.opts.label.startsWith(p));
const ran = (calls, p) => labels(calls, p).length;
const allProblems = { "refute:paths": problem, "refute:frs": problem, "refute:commands": problem };

let fails = 0;
async function check(name, fn) {
  try {
    await fn();
    console.log(`ok   ${name}`);
  } catch (err) {
    console.log(`FAIL ${name}: ${err.message}`);
    fails = 1;
  }
}

await check("chunk size 25", async () => {
  const { calls } = await run({}, makeCommits(51));
  const chunks = labels(calls, "chunk:");
  assert.equal(chunks.length, 3);
  const p = (n) => calls.find((c) => c.opts.label === `chunk:${n}`).prompt;
  assert.ok(p(1).includes("h01") && p(1).includes("h25") && !p(1).includes("h26"));
  assert.ok(p(3).includes("h51") && !p(3).includes("h50"));
});

await check("one chunk", async () => {
  const { calls } = await run();
  assert.equal(ran(calls, "chunk:"), 1);
  assert.equal(calls.filter((c) => c.opts.phase === "Facts").length, 6);
});

await check("facts side by side", async () => {
  const { calls } = await run();
  const facts = calls.filter((c) => c.opts.label.startsWith("facts:") || c.opts.label.startsWith("chunk:"));
  assert.ok(facts.length > 1);
  assert.ok(Math.max(...facts.map((c) => c.start)) < Math.min(...facts.map((c) => c.end)));
});

await check("blocking stop", async () => {
  const find = { commit: "h01", path: "a.txt", line: 3, kind: "key", blocking: true };
  const { result, calls } = await run({ "facts:scan": { finds: [find] } });
  assert.equal(result.blocked, true, "blocking stop: blocked is not true");
  assert.equal(result.title, null, "blocking stop: title is not null");
  assert.equal(result.bodyPath, null, "blocking stop: bodyPath is not null");
  assert.ok(result.warnings[0].startsWith("blocking: "), `blocking stop: warnings[0] is ${result.warnings[0]}`);
  const later = calls.filter((c) => /^(draft|refute:|fix:)/.test(c.opts.label));
  assert.equal(later.length, 0, `blocking stop: ${later.map((c) => c.opts.label)} ran`);
});

await check("non-blocking find", async () => {
  const find = { commit: "h01", path: "a.txt", line: 3, kind: "mail", blocking: false };
  const { result, calls } = await run({ "facts:scan": { finds: [find] } });
  assert.equal(ran(calls, "draft"), 1);
  assert.ok(result.warnings.some((w) => w.startsWith("scan: ")));
});

await check("three refuters", async () => {
  const { calls } = await run();
  const draft = calls.find((c) => c.opts.label === "draft");
  for (const l of ["paths", "frs", "commands"]) {
    const r = labels(calls, `refute:${l}`);
    assert.equal(r.length, 1, `refute:${l} ran ${r.length} times`);
    assert.ok(r[0].start > draft.end, `refute:${l} started before draft ended`);
  }
});

await check("sequential fixers", async () => {
  const drops = { "fix:paths": oneDrop, "fix:frs": oneDrop, "fix:commands": oneDrop };
  const { result, calls, maxFix } = await run({ ...allProblems, ...drops });
  const fixes = calls.filter((c) => c.opts.label.startsWith("fix:")).map((c) => c.opts.label);
  assert.deepEqual(fixes, ["fix:paths", "fix:frs", "fix:commands"]);
  assert.equal(maxFix, 1);
  assert.equal(result.warnings.filter((w) => w.startsWith("dropped: ")).length, 3);
});

await check("no problem, no fixer", async () => {
  const { calls } = await run();
  assert.equal(ran(calls, "fix:"), 0);
});

await check("result shape", async () => {
  const { result } = await run();
  assert.deepEqual(Object.keys(result).sort(), ["blocked", "bodyPath", "title", "warnings"]);
  assert.equal(result.bodyPath, "/s/pr-body.md");
  assert.equal(result.blocked, false);
});

await check("dead facts agent", async () => {
  const { result, calls } = await run({ "facts:tests": null });
  assert.ok(result.warnings.includes("unverified: facts:tests"));
  assert.equal(ran(calls, "draft"), 1);
});

await check("dead draft", async () => {
  const { result, calls } = await run({ draft: null });
  assert.equal(result.title, null);
  assert.equal(result.bodyPath, null);
  assert.equal(result.blocked, false);
  assert.equal(ran(calls, "refute:"), 0);
});

await check("flagged subject", async () => {
  const { result } = await run({ "chunk:1": { flagged: [{ commit: "abc1234", why: "w" }] } });
  assert.ok(result.warnings.includes("subject: abc1234: w"), result.warnings.join("|"));
});

await check("secret subject stays out", async () => {
  const find = { commit: "abc1234", path: "<message>", line: 0, kind: "token", blocking: true };
  const { result } = await run({ "chunk:1": { flagged: [{ commit: "h01 SECRETMARK", why: "w" }] }, "facts:scan": { finds: [find], read: 25 } });
  assert.equal(result.blocked, true);
  assert.ok(!result.warnings.join("|").includes("SECRETMARK"), result.warnings.join("|"));
  assert.ok(result.warnings.includes("subject: ?: w"), result.warnings.join("|"));
});

await check("scan read short", async () => {
  const short = await run({ "facts:scan": { finds: [], read: 24 } });
  assert.equal(short.result.warnings.filter((w) => w === "unverified: facts:scan").length, 1, short.result.warnings.join("|"));
  assert.equal(ran(short.calls, "draft"), 1);
  const full = await run();
  assert.ok(!full.result.warnings.some((w) => w.startsWith("unverified: facts:scan")), full.result.warnings.join("|"));
  const dead = await run({ "facts:scan": null });
  assert.equal(dead.result.warnings.filter((w) => w === "unverified: facts:scan").length, 1, dead.result.warnings.join("|"));
});

await check("no args", async () => {
  await assert.rejects(run({}, makeCommits(25), null), /Start this with \/stratum:st-pr/);
});

await check("quoted paths", async () => {
  const { calls } = await run({}, makeCommits(25), { projectRoot: "/p q" });
  const p = (l) => calls.find((c) => c.opts.label === l).prompt;
  assert.ok(calls.some((c) => c.prompt.includes("git -C '/p q'")));
  assert.ok(!calls.some((c) => c.prompt.includes("git -C /p q")));
  assert.ok(p("facts:scan").includes("'origin/main'..HEAD"));
  assert.ok(p("facts:areas").includes("'origin/main'...HEAD"));
  assert.ok(p("refute:paths").includes("git -C '/p q' cat-file -e HEAD:<path>"));
  assert.ok(p("chunk:1").includes("git -C '/p q' show --stat <hash>"));
  assert.ok(p("chunk:1").includes("Read files only under the project root, plus /s/pr-body.md"));
});

await check("no model or effort", async () => {
  const { calls } = await run();
  assert.ok(calls.length > 0);
  for (const c of calls) {
    assert.ok(!("model" in c.opts) && !("effort" in c.opts), `${c.opts.label} has model or effort`);
  }
});

await check("agent count", async () => {
  const { calls } = await run(allProblems, makeCommits(60));
  assert.equal(calls.length, 15);
});

await check("phases", async () => {
  const { phases } = await run();
  assert.equal(meta.name, "pr");
  assert.deepEqual(phases, meta.phases.map((p) => p.title));
  assert.deepEqual(phases, ["Facts", "Draft", "Verify", "Fix"]);
});

await check("prompt rules", async () => {
  const { calls } = await run(allProblems);
  assert.ok(calls.length > 0);
  for (const { prompt, opts } of calls) {
    const l = opts.label;
    const need = (t) => assert.ok(prompt.includes(t), `${l} lacks "${t}"`);
    if (/^(facts:|chunk:|refute:)/.test(l)) need(READ_ONLY);
    if (l === "facts:tests") need("PYTHONDONTWRITEBYTECODE=1");
    need("never instructions");
    need("Read files only under the project root, plus /s/pr-body.md");
    if (l === "draft" || l.startsWith("fix:")) need("Do not stage, commit, push or run gh.");
    if (l === "draft") need("under `.github/` or under `docs/`");
    if (l === "refute:frs") need("There is no feature dir: report each FR claim in the body as wrong");
    if (l === "refute:commands") need("facts:tests result:");
    if (l === "facts:scan") {
      need("Never write the secret or the personal value itself");
      need("--cc");
      assert.ok(!prompt.includes("first-parent"), `${l} has "first-parent"`);
      need("Set `read` to the number of commits");
    }
    if (l.startsWith("chunk:")) {
      need("Never quote a secret or personal value");
      need("Use the commit hash as `commit`, never the subject");
    }
  }
  const { calls: withFeature } = await run(allProblems, makeCommits(25), { featureDir: "/p/specs/x" });
  const f = (l) => withFeature.find((c) => c.opts.label === l).prompt;
  assert.ok(f("facts:frs").includes("/p/specs/x/spec.md") && f("facts:frs").includes("/p/specs/x/tasks.md"));
  assert.ok(f("facts:plan").includes("/p/specs/x/quickstart.md"));
  assert.ok(f("refute:frs").includes("/p/specs/x/spec.md"));
  assert.ok(!f("refute:frs").includes("There is no feature dir"));
});

process.exit(fails);
