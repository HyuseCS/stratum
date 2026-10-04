// Copyright 2026 Anthropic PBC
// SPDX-License-Identifier: Apache-2.0
//
// Token Weather: a live forecast of the context window, above the prompt.
//
// turn.complete: after each main-loop turn, read the context window's fill
// from $.session.usage() (the same figures the status line shows) and keep
// the last HISTORY readings.
// session.start: take a first reading, so the band shows before any turn.
// Colors follow the statusline theme: "theme" and "colors.custom" in the
// project's .stratum/powerline.json, read on each reading.
// ui.render (AbovePrompt): one line: icon, forecast word, a fill bar,
// percent, tokens used of the window, and the turns left before
// auto-compaction at the recent rate of growth.
//
// The host reads on(...) and $.noun.method(...) from source, so they are
// spelled literally, and helpers that take $ are top-level functions.

const HISTORY = 12;
const BAR_CELLS = 20;
const GROWTH_TURNS = 5;

// Forecast bands, by percent of the window used.
const FORECAST = [
// Single-width text symbols, not emoji: they line up in every terminal font.
  { upTo: 25, icon: "☀", word: "Clear" },
  { upTo: 50, icon: "☁", word: "Cloudy" },
  { upTo: 75, icon: "☂", word: "Showers" },
  { upTo: 90, icon: "☇", word: "Storm" },
  { upTo: Infinity, icon: "↯", word: "Compact soon" },
];

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

  on("ui.render", { component: "AbovePrompt" }, ($, e, next) => {
    if (e.hasSurvey || readings.length === 0) {
      return next(e);
    }
    const { Box, Text } = $.ui.resolve(e);
    return band(Box, Text, e.bodyColumns ?? 80);
  });
}

// One color per forecast band, then text colors; rose-pine until a theme loads.
let colors = {
  bands: ["#f6c177", "#9ccfd8", "#c4a7e7", "#ebbcba", "#eb6f92"],
  text: "#e0def4",
  muted: "#908caa",
  faint: "#524f67",
};

async function loadColors($) {
  try {
    const themes = JSON.parse(await $.fs.read(`${$.plugin.root}/statusline/themes.json`));
    let cfg = {};
    try {
      cfg = JSON.parse(await $.fs.read(".stratum/powerline.json"));
    } catch {
      // No project file; the default theme applies.
    }
    const p = { ...(themes[cfg.theme] ?? themes["rose-pine"]), ...(cfg.colors?.custom ?? {}) };
    colors = {
      bands: [p.contextWarning.bg, p.git.fg, p.directory.fg, p.model.fg, p.contextCritical.bg],
      text: p.metrics.fg,
      muted: p.tmux.fg,
      faint: p.metrics.bg,
    };
  } catch {
    // Keep the last colors.
  }
}

async function takeReading($) {
  await loadColors($);
  try {
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
    $.ui.invalidate("ui.render");
  } catch {
    // No reading this turn; the band keeps the last one.
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

function band(Box, Text, columns) {
  const now = readings[readings.length - 1];
  const f = forecastFor(now.percent);
  const color = colors.bands[FORECAST.indexOf(f)];
  const parts = [Text({ color, bold: true, children: `${f.icon} ${f.word} ` })];
  if (columns >= 60) {
    const filled = Math.min(BAR_CELLS, Math.round((now.percent / 100) * BAR_CELLS));
    parts.push(Text({ color, children: "━".repeat(filled) }));
    parts.push(Text({ color: colors.faint, children: "─".repeat(BAR_CELLS - filled) }));
    parts.push(Text({ children: " " }));
  }
  parts.push(Text({ color: colors.text, children: `${now.percent}%` }));
  parts.push(Text({ color: colors.muted, children: ` ${short(now.tokens)}/${short(now.window)}` }));
  const left = turnsLeft();
  if (left) {
    parts.push(Text({ color: colors.faint, children: " · " }));
    parts.push(Text({ color, children: left }));
  }
  return Box({ flexDirection: "row", paddingX: 1, children: parts });
}

function forecastFor(percent) {
  return FORECAST.find((band) => percent < band.upTo) ?? FORECAST[FORECAST.length - 1];
}

// Mean growth of the recent turns that grew; null until there is one.
function turnsLeft() {
  const recent = readings.slice(-(GROWTH_TURNS + 1));
  const growth = recent.slice(1).map((r, i) => r.tokens - recent[i].tokens).filter((d) => d > 0);
  if (growth.length === 0) {
    return null;
  }
  const now = readings[readings.length - 1];
  const room = now.compactAt - now.tokens;
  if (room <= 0) {
    return "compact now";
  }
  const turns = Math.max(1, Math.round(room / (growth.reduce((a, b) => a + b, 0) / growth.length)));
  return `about ${turns} turn${turns === 1 ? "" : "s"} left`;
}

function short(n) {
  if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(n % 1_000_000 === 0 ? 0 : 1)}M`;
  if (n >= 1_000) return `${(n / 1_000).toFixed(n % 1_000 === 0 ? 0 : 1)}k`;
  return String(n);
}
