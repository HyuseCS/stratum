export type LogRow = { id: string; t: string; who: string; text: string; done: boolean }

declare module 'claude-code' {
  interface PluginState {
    'st-tree': { log: LogRow[]; models: Record<string, string>; tick: number }
  }
}
