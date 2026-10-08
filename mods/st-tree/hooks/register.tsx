import { atom, read, update } from 'claude-code'
import type { Register } from 'claude-code'

import type { LogRow } from '../types'

const PANE = 'st-tree'
const log = atom({ plugin: 'st-tree', key: 'log' } as const, [] as LogRow[])
const models = atom({ plugin: 'st-tree', key: 'models' } as const, {} as Record<string, string>)
const tick = atom({ plugin: 'st-tree', key: 'tick' } as const, 0)

const cut = (s: string, n: number) => (s.length > n ? s.slice(0, Math.max(0, n - 1)) + '…' : s)
const time = () => new Date().toTimeString().slice(0, 8)
const shortModel = (m: string) => m.replace(/^claude-/, '').replace(/-\d{8}$/, '').replace(/-(\d)-(\d)$/, ' $1.$2')

function brief(e: Record<string, unknown>): string {
  if (e.tool === 'Bash') return String(e.command ?? '')
  if (e.file_path) return String(e.file_path).split('/').pop() ?? ''
  if (e.tool === 'Agent') return String(e.description ?? '')
  if (e.pattern) return String(e.pattern)
  return ''
}

const STATUS: Record<string, [string, string]> = {
  running: ['●', 'yellow'],
  completed: ['✓', 'green'],
}
const status = (s: string) => STATUS[s] ?? ['✗', 'red']

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await $.command.register({ name: 'st-tree', description: 'Open the Stratum agent tree pane' })
    return next(e)
  })

  on('command.run', { command: 'st-tree' }, async $ => {
    await $.ui.open({ id: PANE, title: 'Stratum tree', rows: 30 })
    return { text: 'Stratum tree pane opened.' }
  })

  on('agent.spawn', async ($, e, next) => {
    const r = await next(e)
    const id = r.agentId
    if (id) await update($, models, m => ({ ...m, [id]: r.model }))
    return r
  })

  on('tool.call', async ($, e, next) => {
    const id = e.tool_use_id ?? `${Date.now()}`
    const who = e.agentId ? e.agentId.slice(0, 6) : 'main'
    const row: LogRow = { id, t: time(), who, text: `${e.tool} ${brief(e as Record<string, unknown>)}`.trim(), done: false }
    await update($, log, l => [...l, row].slice(-60))
    const r = await next(e)
    await update($, log, l => l.map(x => (x.id === id ? { ...x, done: true } : x)))
    await update($, tick, n => (n ?? 0) + 1)
    return r
  })

  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    const { Box, Text } = $.ui.resolve(e)
    await read($, tick)
    const rows = await read($, log)
    const named = await read($, models)
    const agents = await $.agent.list()
    const main = shortModel(await $.session.model())
    const root = await $.session.root()
    let state: { phase?: string; lane?: string; feature_directory?: string } = {}
    let tasks = ''
    try {
      state = JSON.parse(await $.fs.read(`${root}/.stratum/state.json`))
      if (state.feature_directory) {
        const dir = state.feature_directory.startsWith('/') ? state.feature_directory : `${root}/${state.feature_directory}`
        const md = await $.fs.read(`${dir}/tasks.md`)
        const all = md.match(/^- \[[ xX]\]/gm)?.length ?? 0
        const done = md.match(/^- \[[xX]\]/gm)?.length ?? 0
        tasks = `${done}/${all}`
      }
    } catch {}

    const cols = e.props.bodyColumns
    const live = agents.filter(a => a.status === 'running').length
    const shown = agents.slice(-6)
    const per = Math.max(16, Math.floor((cols - (shown.length - 1)) / Math.max(1, shown.length)))
    const inner = per - 4
    const used = 1 + 4 + 2 + (shown.length ? 6 : 3) + 1
    const room = Math.min(6, Math.max(3, (e.viewport?.rows ?? 30) - used))
    const feature = state.feature_directory?.split('/').pop() ?? 'no feature'
    const center = (s: string) => ' '.repeat(Math.max(0, Math.floor((cols - s.length) / 2))) + s

    return (
      <Box flexDirection="column">
        <Box justifyContent="space-between">
          <Text bold color="cyan">STRATUM · AGENT TREE</Text>
          <Text dimColor>{main} main · {live} running</Text>
        </Box>
        <Box flexDirection="column" borderStyle="round" borderColor="cyan" paddingX={1}>
          <Text bold color="cyan">orchestrator · {main}</Text>
          <Text dimColor>plans + decides · routes and verifies · never writes code</Text>
          <Text>
            <Text color="magenta">{feature}</Text> · phase <Text bold>{state.phase ?? '-'}</Text> · lane <Text bold>{state.lane ?? '-'}</Text>{tasks ? ` · tasks ${tasks}` : ''}
          </Text>
        </Box>
        <Text dimColor>{center('│')}</Text>
        <Text dimColor>{center('▼')}</Text>
        {shown.length === 0 ? (
          <Box borderStyle="single" borderDimColor paddingX={1}>
            <Text dimColor>no subagents · they appear here as the orchestrator spawns them</Text>
          </Box>
        ) : (
          <Box gap={1}>
            {shown.map(a => {
              const [glyph, color] = status(a.status)
              return (
                <Box flexDirection="column" width={per} borderStyle="single" borderColor={color} paddingX={1}>
                  <Text bold color={color}>{cut(a.type, inner)}</Text>
                  <Text dimColor>{cut(shortModel(named[a.id] ?? '?'), inner)}</Text>
                  <Text wrap="truncate">{cut(a.description, inner)}</Text>
                  <Text color={color}>[{glyph} {a.status}]</Text>
                </Box>
              )
            })}
          </Box>
        )}
        <Text dimColor>── session log {'─'.repeat(Math.max(0, cols - 15))}</Text>
        {rows.slice(-room).map(r => (
          <Box justifyContent="space-between">
            <Text wrap="truncate" dimColor={r.done}>
              <Text dimColor>{r.t}</Text> <Text color={r.who === 'main' ? 'cyan' : 'green'}>{r.who.padEnd(6)}</Text> {cut(r.text, cols - 30)}
            </Text>
            <Text color={r.done ? undefined : 'yellow'} dimColor={r.done}>{r.done ? '[done]' : '[running]'}</Text>
          </Box>
        ))}
      </Box>
    )
  })
}
