import type { EngineInterface, Register } from 'claude-code'

// Efficient Browser Use keeps browser work cheap in two ways:
// 1. It fills in smaller defaults for the built-in browser's tools, only when the
//    call did not set the value itself, so an explicit choice always wins.
// 2. It adds a short rule to the system prompt: read pages as text, not pictures.
// It makes no model call.

const NAME = 'efficient-browser-use'
const PREFIX = 'mcp__Claude_Browser__'

const RULE = [
  'Browser work, keep it cheap:',
  '- Read a page as text (get_page_text, read_page, find) before taking a screenshot.',
  '- When a screenshot is needed, use scale 0.5; zoom into a region instead of a full-size shot.',
  '- Group predictable steps in one browser_batch call. Do not re-read a page that did not change.',
  '- If a text read was cut short, call it again with a larger max_chars or a ref_id.',
].join('\n')

let dir = ''

async function configDir($: EngineInterface): Promise<string> {
  if (dir) return dir
  const set = ((await $.env.get('CLAUDE_CONFIG_DIR').catch(() => undefined)) ?? '').trim()
  const home = ((await $.env.get('HOME').catch(() => undefined)) ?? '').trim()
  dir = (set || `${home}/.claude`).replace(/\/+$/, '')
  return dir
}

async function isOff($: EngineInterface): Promise<boolean> {
  try {
    const path = `${await configDir($)}/mods/switches.json`
    if (!(await $.fs.exists(path))) return false
    const json = JSON.parse(String(await $.fs.read(path))) as Record<string, unknown>
    return json[NAME] === false
  } catch {
    return false
  }
}

/** The defaults to add for one tool call, or null when nothing is missing. Pure. */
export function defaultsFor(tool: string, input: Record<string, unknown>): Record<string, unknown> | null {
  if (!tool.startsWith(PREFIX)) return null
  const name = tool.slice(PREFIX.length)
  const add: Record<string, unknown> = {}
  const missing = (k: string) => input[k] === undefined
  if (name === 'get_page_text' && missing('max_chars')) add.max_chars = 15000
  if (name === 'read_page' && missing('max_chars') && missing('ref_id')) add.max_chars = 20000
  if (name === 'read_console_messages' && missing('limit')) add.limit = 20
  if (name === 'read_network_requests' && missing('limit') && missing('requestId')) add.limit = 20
  if (name === 'computer' && (input.action === 'screenshot' || input.action === 'zoom') && missing('scale')) add.scale = 0.5
  return Object.keys(add).length ? add : null
}

export const register: Register = on => {
  on('tool.call', async ($, e, next) => {
    const tool = String((e as { tool: string }).tool)
    if (!tool.startsWith(PREFIX) || (await isOff($))) return next(e)
    const add = defaultsFor(tool, e as unknown as Record<string, unknown>)
    return add ? next({ ...e, ...add } as typeof e) : next(e)
  }).catch(($, e, next) => next(e))

  on('prompt.compose', async ($, e, next) => {
    const out = await next(e)
    if (await isOff($)) return out
    return { sections: [...out.sections, { id: `${NAME}:rule`, text: RULE, scope: 'session' as const }] }
  }).catch(($, e, next) => next(e))
}
