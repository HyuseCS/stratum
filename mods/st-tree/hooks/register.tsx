import { atom, read, update } from 'claude-code'
import type { Register } from 'claude-code'

import type { LogRow } from '../types'

const PANE = 'st-tree'
const log = atom({ plugin: 'st-tree', key: 'log' } as const, [] as LogRow[])
const models = atom({ plugin: 'st-tree', key: 'models' } as const, {} as Record<string, string>)
const tick = atom({ plugin: 'st-tree', key: 'tick' } as const, 0)

const short = (s: string, n: number) => (s.length > n ? s.slice(0, n - 1) + '…' : s)
const time = () => new Date().toTimeString().slice(0, 8)

function brief(e: Record<string, unknown>): string {
  if (e.tool === 'Bash') return short(String(e.command ?? ''), 48)
  if (e.file_path) return String(e.file_path).split('/').pop() ?? ''
  if (e.tool === 'Agent') return short(String(e.description ?? ''), 48)
  if (e.pattern) return String(e.pattern)
  return ''
}

const glyph = (s: string) => (s === 'running' ? '●' : s === 'completed' ? '✓' : '✗')
const color = (s: string) => (s === 'running' ? 'yellow' : s === 'completed' ? 'green' : 'red')

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await $.command.register({ name: 'st-tree', description: 'Open the Stratum agent tree pane' })
    return next(e)
  })

  on('command.run', { command: 'st-tree' }, async $ => {
    await $.ui.open({ id: PANE, title: 'Stratum tree' })
    return { text: 'Stratum tree pane opened.' }
  })

  on('agent.spawn', async ($, e, next) => {
    const r = await next(e)
    const id = r.agentId
    if (id) await update($, models, m => ({ ...m, [id]: r.model }))
    return r
  })

  on('tool.call', async ($, e, next) => {
    const who = e.agentId ? e.agentId.slice(0, 6) : 'main'
    const row: LogRow = { t: time(), who, text: `${e.tool} ${brief(e as Record<string, unknown>)}`.trim() }
    await update($, log, l => [...l, row].slice(-40))
    const r = await next(e)
    await update($, tick, n => (n ?? 0) + 1)
    return r
  })

  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    const { Box, Text } = $.ui.resolve(e)
    await read($, tick)
    const rows = await read($, log)
    const named = await read($, models)
    const agents = await $.agent.list()
    const main = await $.session.model()
    let state: { phase?: string; lane?: string; feature_directory?: string } = {}
    try {
      state = JSON.parse(await $.fs.read(`${await $.session.root()}/.stratum/state.json`))
    } catch {}
    const room = Math.max(3, (e.viewport?.rows ?? 30) - agents.length - 8)

    return (
      <Box flexDirection="column">
        <Text bold>Stratum · {state.phase ?? 'no phase'} · {state.lane ?? 'no lane'}</Text>
        <Text dimColor>{state.feature_directory ?? 'no feature'}</Text>
        <Text> </Text>
        <Text>
          <Text color="cyan">◆</Text> orchestrator · {main}
        </Text>
        {agents.length === 0 && <Text dimColor>  no subagents</Text>}
        {agents.map(a => (
          <Text wrap="truncate">
            {a.parentId ? '      ' : '  '}
            <Text color={color(a.status)}>{glyph(a.status)}</Text> {a.type} · {named[a.id] ?? '?'} · {a.description}
          </Text>
        ))}
        <Text> </Text>
        <Text dimColor>── log</Text>
        {rows.slice(-room).map(r => (
          <Text wrap="truncate" dimColor={r.who === 'main'}>
            {r.t} {r.who.padEnd(6)} {r.text}
          </Text>
        ))}
      </Box>
    )
  })
}
