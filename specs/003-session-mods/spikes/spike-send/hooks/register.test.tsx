import type { On } from 'claude-code'
import { expect, test, type Engine } from 'claude-code/testing'

const SID = '6f1d2c3b-4a5e-4f70-8b9c-0d1e2f3a4b5c'

const start = ($: Engine, on: On) => {
  on('session.start', () => ({ cwd: '.' }))
  on('command.register', (_, e) => ({ value: { command: e.name } }))
  on('ui.open', () => ({ value: { isPlaced: true as const } }))
  on('session.receive', (_, e) => ({ text: e.text }))
  return $.session.start({ cwd: '.', surface: 'terminal', isInteractive: true })
}

const run = ($: Engine, args: string) =>
  $.command.run({
    command: 'spike-send',
    args,
    origin: { kind: 'composer' },
    presentation: { isFullscreen: false, columns: 80 },
  })

const mountPane = ($: Engine) =>
  $.ui.mount({
    plugin: 'spike-send',
    surface: 'terminal',
    component: 'Pane',
    requestId: 'spike-send',
    props: {
      title: 'spike-send',
      isFocused: true,
      bodyColumns: 80,
      placement: 'inline',
      scroll: { offset: 0, bodyRows: 20 },
      view: {},
    },
  })

test('(a) /spike-send <name> sends one message with spk003 text to that session', async ($, on) => {
  const sent: { to: unknown; text: string }[] = []
  on('session.send', (_, e) => {
    sent.push({ to: e.to, text: e.text })
    return { isDelivered: true as const }
  })
  await start($, on)
  await run($, 'spike-peer')
  expect(sent).toHaveLength(1)
  expect(sent[0].to).toBe('spike-peer')
  expect(sent[0].text).toContain('spk003')
})

test('(b) /spike-send sid:<uuid> resolves and addresses the session by id, not by the literal text', async ($, on) => {
  const to: unknown[] = []
  on('session.send', (_, e) => {
    to.push(e.to)
    return { isDelivered: true as const }
  })
  await start($, on)
  await run($, `sid:${SID}`)
  expect(to).toHaveLength(1)
  expect(JSON.stringify(to[0])).not.toContain('sid:')
  expect(JSON.stringify(to[0])).toContain(SID)
})

test('(c) a peer reply shows in the pane with its origin', async ($, on) => {
  await start($, on)
  await $.session.receive({ origin: { kind: 'peer' }, text: 'spk003-pong' })
  const drawn = await mountPane($)
  expect(await drawn.find({ text: 'spk003-pong' })).toBeDefined()
  expect(await drawn.find({ text: 'peer' })).toBeDefined()
})

test('(d) a received text without spk003 is not shown', async ($, on) => {
  await start($, on)
  await $.session.receive({ origin: { kind: 'peer' }, text: 'unrelated note' })
  const drawn = await mountPane($)
  expect(await drawn.find({ text: 'unrelated note' })).toBeUndefined()
})
