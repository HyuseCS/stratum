import type { On } from 'claude-code'
import { expect, mock, test, type Engine } from 'claude-code/testing'

const ARGV = [
  'timeout', '300', 'claude', '-p', '--model', 'haiku', '--max-turns', '3', '--tools', '',
  '--strict-mcp-config', '--no-session-persistence', '-n', 'spk003-t2a',
  'spk003-t2a: reply with exactly the text spk003-t2a-ok and nothing else.',
]

const start = ($: Engine, on: On) => {
  on('session.start', () => ({ cwd: '.' }))
  on('command.register', (_, e) => ({ value: { command: e.name } }))
  on('ui.open', () => ({ value: { isPlaced: true as const } }))
  return $.session.start({ cwd: '.', surface: 'terminal', isInteractive: true })
}

const run = ($: Engine) =>
  $.command.run({
    command: 'spike-start',
    args: '',
    origin: { kind: 'composer' },
    presentation: { isFullscreen: false, columns: 80 },
  })

const mountPane = ($: Engine) =>
  $.ui.mount({
    plugin: 'spike-start',
    surface: 'terminal',
    component: 'Pane',
    requestId: 'spike-start',
    props: {
      title: 'spike-start',
      isFocused: true,
      bodyColumns: 80,
      placement: 'inline',
      scroll: { offset: 0, bodyRows: 20 },
      view: {},
    },
  })

test('(a) /spike-start runs the started-session argv and shows done with the reply', async ($, on) => {
  const clock = mock.clock(on)
  const spawned: (readonly string[])[] = []
  on('process.spawn', async function* (_, e) {
    spawned.push(e.argv)
    yield { stream: 'stdout', text: 'spk003-t2a-ok\n' }
    return { value: { code: 0, signal: null } }
  })
  await start($, on)
  await run($)
  await clock.settle()
  expect(spawned).toHaveLength(1)
  expect(spawned[0]).toEqual(ARGV)
  const drawn = await mountPane($)
  expect(await drawn.find({ text: 'done' })).toBeDefined()
  expect(await drawn.find({ text: 'spk003-t2a-ok' })).toBeDefined()
})

test('(b) a child that exits 124 shows failed and the code, not done', async ($, on) => {
  const clock = mock.clock(on)
  on('process.spawn', async function* () {
    return { value: { code: 124, signal: null } }
  })
  await start($, on)
  await run($)
  await clock.settle()
  const drawn = await mountPane($)
  expect(await drawn.find({ text: 'failed' })).toBeDefined()
  expect(await drawn.find({ text: '124' })).toBeDefined()
  expect(await drawn.find({ text: 'done' })).toBeUndefined()
})

test('(c) before the child writes anything the pane shows running and the name', async ($, on) => {
  const clock = mock.clock(on)
  let release = () => {}
  const gate = new Promise<void>((resolve) => {
    release = resolve
  })
  on('process.spawn', async function* () {
    await gate
    yield { stream: 'stdout', text: 'spk003-t2a-ok\n' }
    return { value: { code: 0, signal: null } }
  })
  await start($, on)
  await run($)
  await clock.settle()
  const drawn = await mountPane($)
  expect(await drawn.find({ text: 'running' })).toBeDefined()
  expect(await drawn.find({ text: 'spk003-t2a' })).toBeDefined()
  release()
  await clock.settle()
})
