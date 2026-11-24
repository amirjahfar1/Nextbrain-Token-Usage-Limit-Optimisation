import type { EngineInterface, Register } from 'claude-code'

// The /mods switchboard. One file, switches.json, read by every Nextbrain mod:
// a mod set to false there passes every event through untouched, in every chat.
// This mod only writes that file; it makes no model call.

const NAME = 'mods'
const KNOWN: Record<string, string> = {
  handoff: 'offers a handoff at 500k tokens',
  'model-router': 'picks each subagent model',
  'cache-clock': 'countdown to a cold prompt cache',
  'research-router': 'keeps web research out of the chat',
  'savings-proof': '/savings pane',
  'token-meter': 'context, limits and cost pane',
  'input-router': 'trims prompt noise',
  'effort-optimizer': 'low effort for trivial prompts',
  'efficient-browser-use': 'smaller browser reads',
  'session-header': 'folder + chat title row above the prompt',
}

let dir = ''

async function configDir($: EngineInterface): Promise<string> {
  if (dir) return dir
  const set = ((await $.env.get('CLAUDE_CONFIG_DIR').catch(() => undefined)) ?? '').trim()
  const home = ((await $.env.get('HOME').catch(() => undefined)) ?? '').trim()
  dir = (set || `${home}/.claude`).replace(/\/+$/, '')
  return dir
}

async function readSwitches($: EngineInterface): Promise<Record<string, unknown>> {
  const path = `${await configDir($)}/mods/switches.json`
  if (!(await $.fs.exists(path))) return {}
  const json = JSON.parse(String(await $.fs.read(path))) as unknown
  return json && typeof json === 'object' && !Array.isArray(json) ? (json as Record<string, unknown>) : {}
}

function table(sw: Record<string, unknown>): string {
  const rows = Object.entries(KNOWN).map(([name, what]) => `${sw[name] === false ? 'off' : 'on '}  ${name} - ${what}`)
  return [...rows, '', 'Change: /mods off <name>, /mods on <name>, /mods on all, /mods off all'].join('\n')
}

/** Pure: applies one "on|off <name|all>" request to the switches. Returns null on a bad request. */
export function apply(sw: Record<string, unknown>, args: string): Record<string, unknown> | null {
  const [verb, target, ...rest] = args.trim().split(/\s+/)
  if ((verb !== 'on' && verb !== 'off') || !target || rest.length) return null
  const names = target === 'all' ? Object.keys(KNOWN) : target in KNOWN ? [target] : []
  if (names.length === 0) return null
  const next = { ...sw }
  for (const n of names) {
    if (verb === 'off') next[n] = false
    else delete next[n]
  }
  return next
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await $.command.register({
      name: 'mods',
      description: 'Show the Nextbrain mods and turn each on or off',
      argumentHint: '[on|off] [name|all]',
    })
    return next(e)
  }).catch(($, e, next) => next(e))

  on('command.run', { command: 'mods' }, async ($, e) => {
    try {
      const sw = await readSwitches($)
      if (e.args.trim() === '' || e.args.trim() === 'status') return { text: table(sw) }
      const changed = apply(sw, e.args)
      if (!changed) return { text: `Not understood: "${e.args.trim()}".\n\n${table(sw)}` }
      await $.fs.write(`${await configDir($)}/mods/switches.json`, `${JSON.stringify(changed, null, 2)}\n`)
      return { text: `Saved. A mod reads this at its next check; a chat may need /reload-plugins.\n\n${table(changed)}` }
    } catch (err) {
      return { text: `/mods could not read or write switches.json: ${err instanceof Error ? err.message : String(err)}` }
    }
  })
}
