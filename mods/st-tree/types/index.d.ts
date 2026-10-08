export type LogRow = { t: string; who: string; text: string }

declare module 'claude-code' {
  interface PluginState {
    'st-tree': { log: LogRow[]; models: Record<string, string>; tick: number }
  }
}
