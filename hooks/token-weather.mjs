// Copyright 2026 Anthropic PBC
// SPDX-License-Identifier: Apache-2.0
//
// Token Weather: a live forecast of the context window, drawn by the
// statusline as its third line (statusline/st-statusline.sh).
//
// turn.complete: after each main-loop turn, read the context window's fill
// from $.session.usage() (the same figures the status line shows) and keep
// the last HISTORY readings.
// session.start: take a first reading, so the line shows before any turn.
// Each reading writes .stratum/weather.json: the auto-compaction threshold
// and the mean growth of the recent growing turns. The statusline takes the
// fill from its own input; it cannot ask for the threshold or keep a history.
//
// The host reads on(...) and $.noun.method(...) from source, so they are
// spelled literally, and helpers that take $ are top-level functions.

const HISTORY = 12;
const GROWTH_TURNS = 5;
const STATE_FILE = ".stratum/weather.json";

// Readings: { tokens, window, percent, compactAt }, oldest first.
let readings = [];

export function register(on) {
  on("session.start", async ($, e, next) => {
    const result = await next(e);
    readings = [];
    await takeReading($);
    return result;
  });

  on("turn.complete", async ($, e, next) => {
    const result = await next(e);
    if (e.agentId) {
      return result;
    }
    await takeReading($);
    return result;
  });
}

async function takeReading($) {
  try {
    if (!(await $.fs.exists(".stratum"))) {
      return;
    }
    const { context } = await $.session.usage();
    if (!context || !context.window) {
      return;
    }
    const tokens = context.tokens ?? 0;
    const percent = Math.round(context.percent ?? (tokens / context.window) * 100);
    const compactAt = await compactThreshold($, context.window);
    // The session.start reading is 0 before any response; drop it once real readings arrive.
    readings = readings.filter((r) => r.tokens > 0);
    readings.push({ tokens, window: context.window, percent, compactAt });
    if (readings.length > HISTORY) {
      readings = readings.slice(-HISTORY);
    }
    await $.fs.write(STATE_FILE, JSON.stringify({ compactAt, growth: growth() }) + "\n");
  } catch {
    // No reading this turn; the file keeps the last one.
  }
}

async function compactThreshold($, window) {
  try {
    const { context } = await $.session.usage({ breakdown: "summary" });
    const b = context.breakdown;
    if (b?.isAutoCompactEnabled && b.autoCompactThreshold) {
      return b.autoCompactThreshold;
    }
  } catch {
    // No breakdown; count turns to a full window instead.
  }
  return window;
}

// Mean growth of the recent turns that grew; null until there is one.
function growth() {
  const recent = readings.slice(-(GROWTH_TURNS + 1));
  const grew = recent.slice(1).map((r, i) => r.tokens - recent[i].tokens).filter((d) => d > 0);
  return grew.length ? Math.round(grew.reduce((a, b) => a + b, 0) / grew.length) : null;
}
