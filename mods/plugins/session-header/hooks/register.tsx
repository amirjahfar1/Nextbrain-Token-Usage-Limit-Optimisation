import type { EngineInterface, Register } from 'claude-code'

// Module variables reset on a reload; nothing here needs to survive one.
let home = ''
const fromRoot = ($: EngineInterface) => $.plugin.root.replace(/\\/g, '/').split('/.claude/')[0] ?? ''
function fwd(p: string, windows: boolean) {
  let s = p.trim().replace(/\\/g, '/').replace(/\/+$/, '')
  if (windows) s = s.replace(/^\/([a-zA-Z])\//, (_, d: string) => `${d.toUpperCase()}:/`).replace(/^([a-z]):\//, (_, d: string) => `${d.toUpperCase()}:/`)
  return s
}
async function findHome($: EngineInterface): Promise<string> {
  const windows = (await $.env.get('OS').catch(() => undefined)) === 'Windows_NT'
  const profile = ((await $.env.get('USERPROFILE').catch(() => undefined)) ?? '').trim()
  const unix = ((await $.env.get('HOME').catch(() => undefined)) ?? '').trim()
  const pick = windows ? profile || unix : unix || profile
  return pick ? fwd(pick, windows) : fromRoot($)
}
const tilde = (p: string) => (home && p.startsWith(home) ? `~${p.slice(home.length)}` : p)

// The chat's own first few words, the same way the app titles a session: the
// first real line the person typed, not a system or tool tag.
let title = ''
let titleLoaded = false
async function loadTitle($: EngineInterface) {
  if (titleLoaded) return
  titleLoaded = true
  try {
    const messages = await $.session.messages()
    const first = messages.find(m => m.role === 'user' && m.text.trim() && !m.text.trim().startsWith('<'))
    const text = (first?.text ?? '').trim().replace(/\s+/g, ' ')
    title = text.length > 70 ? `${text.slice(0, 70)}…` : text
  } catch {
    title = ''
  }
}

const ACCENT = '#60a5fa'

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    home = await findHome($)
    void loadTitle($)
    return next(e)
  })

  // A new user turn may be the session's first real line if it started on
  // a tool call or a notification; refresh once the title is still empty.
  on('turn.complete', async ($, e, next) => {
    if (!title) {
      titleLoaded = false
      void loadTitle($)
    }
    return next(e)
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const rest = await next(e)
    const { Box, Text } = $.ui.resolve(e)
    const cwd = await $.session.cwd().catch(() => '')
    const folder = cwd ? (tilde(cwd).split('/').pop() || tilde(cwd)) : ''
    if (!folder && !title) return rest
    return (
      <Box flexDirection="column">
        <Box flexDirection="row" gap={1}>
          <Text color={ACCENT}>📁 {folder || '/'}</Text>
          {title ? <Text dimColor wrap="truncate-end"> · {title}</Text> : null}
        </Box>
        {rest}
      </Box>
    )
  })
}
