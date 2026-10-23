import type { Register } from 'claude-code'

const PANE = 'spike-send'
const sent = { plugin: 'spike-send', key: 'sent' } as const
const reply = { plugin: 'spike-send', key: 'reply' } as const
const origin = { plugin: 'spike-send', key: 'origin' } as const

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await $.command.register({
      name: 'spike-send',
      description: 'Send one spike message to a session and show the reply in a pane',
    })

    return next(e)
  })

  on('command.run', { command: 'spike-send' }, async ($, e) => {
    await $.ui.open({ id: PANE, title: 'spike-send' })
    const arg = e.args.trim()
    const id = arg.startsWith('sid:') ? arg.slice(4).trim() : ''
    if (!arg || (arg.startsWith('sid:') && !id)) {
      return { text: 'Usage: /spike-send <name> | sid:<session id>' }
    }
    const to = id ? { sessionId: id } : arg
    const result = await $.session.send({
      to,
      text: 'spk003 ping: reply to this message with SendMessage, text exactly spk003-pong',
    })
    const line = result.isDelivered ? 'delivered' : `not delivered ${result.reason}`
    await $.state.set(sent, line)

    return { text: `spike-send: ${line}` }
  })

  on('session.receive', async ($, e, next) => {
    if ((e.origin.kind === 'peer' || e.origin.kind === 'peer-send-message') && e.text.includes('spk003')) {
      await $.state.set(reply, e.text)
      await $.state.set(origin, e.origin.kind)
    }

    return next(e)
  })

  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    const { Box, Text } = $.ui.resolve(e)
    const { value: s = '' } = await $.state.get(sent)
    const { value: r = '' } = await $.state.get(reply)
    const { value: o = '' } = await $.state.get(origin)

    return (
      <Box flexDirection="column">
        <Text>{`sent: ${s}`}</Text>
        <Text>{`reply: ${r}`}</Text>
        <Text>{`origin: ${o}`}</Text>
      </Box>
    )
  })
}
