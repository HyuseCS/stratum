import type { Register } from 'claude-code'

const PANE = 'spike-start'
const NAME = 'spk003-t2a'
const ARGV = [
  'timeout', '300', 'claude', '-p', '--model', 'haiku', '--max-turns', '3', '--tools', '',
  '--strict-mcp-config', '--no-session-persistence', '-n', NAME,
  `${NAME}: reply with exactly the text ${NAME}-ok and nothing else.`,
]
const status = { plugin: 'spike-start', key: 'status' } as const
const name = { plugin: 'spike-start', key: 'name' } as const
const reply = { plugin: 'spike-start', key: 'reply' } as const
const detail = { plugin: 'spike-start', key: 'detail' } as const

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await $.command.register({
      name: 'spike-start',
      description: 'Start one headless spike session and show its status in a pane',
    })

    return next(e)
  })

  on('command.run', { command: 'spike-start' }, async $ => {
    await $.ui.open({ id: PANE, title: 'spike-start' })
    await $.state.set(status, 'running')
    await $.state.set(name, NAME)

    void (async () => {
      try {
        const child = $.process.spawn({ argv: ARGV })
        let out = ''
        let err = ''
        for await (const { stream, text } of child) {
          if (stream === 'stdout') out += text
          else err = text
        }
        const { code, signal } = await child.result
        if (code === 0 && signal === null) {
          await $.state.set(reply, out.trim())
          await $.state.set(status, 'done')
        } else {
          await $.state.set(detail, `${signal ?? `exit ${code}`} ${err.trim()}`.trim())
          await $.state.set(status, 'failed')
        }
      } catch (error) {
        await $.state.set(detail, String(error))
        await $.state.set(status, 'failed')
      }
    })()

    return { text: `spike-start: running ${NAME}` }
  })

  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    const { Box, Text } = $.ui.resolve(e)
    const { value: s = '' } = await $.state.get(status)
    const { value: n = '' } = await $.state.get(name)
    const { value: r = '' } = await $.state.get(reply)
    const { value: d = '' } = await $.state.get(detail)

    return (
      <Box flexDirection="column">
        <Text>{`status: ${s}`}</Text>
        <Text>{`name: ${n}`}</Text>
        <Text>{`reply: ${r}`}</Text>
        <Text>{`detail: ${d}`}</Text>
      </Box>
    )
  })
}
