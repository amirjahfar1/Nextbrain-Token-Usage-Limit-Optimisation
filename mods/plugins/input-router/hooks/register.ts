import type { EngineInterface, Register } from 'claude-code'

// Input Router trims a prompt before the model reads it. It only removes
// whitespace noise and long runs of identical lines; it never rewrites words,
// and it never touches a fenced code block. No model call, so no helper cost.

const NAME = 'input-router'
const MIN_SAVED_CHARS = 40
const RUN_MIN = 4

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

async function append($: EngineInterface, path: string, line: string) {
  const text = line.endsWith('\n') ? line : `${line}\n`
  await $.process
    .run(['/bin/sh', '-c', 'mkdir -p "$(dirname "$1")" && cat >> "$1"', 'sh', path], { stdin: text, timeoutMs: 5000 })
    .catch(() => undefined)
}

/** Collapses a run of identical lines (RUN_MIN or more) into one line plus a count. */
function collapseRuns(lines: string[]): string[] {
  const out: string[] = []
  let i = 0
  while (i < lines.length) {
    let j = i
    while (j + 1 < lines.length && lines[j + 1] === lines[i]) j++
    const n = j - i + 1
    if (n >= RUN_MIN && lines[i]!.trim() !== '') out.push(`${lines[i]} [repeated ${n} times]`)
    else for (let k = i; k <= j; k++) out.push(lines[k]!)
    i = j + 1
  }
  return out
}

/** Cleans prose outside fenced code. Pure: same input, same output. */
export function tidy(text: string): string {
  // Even parts are prose, odd parts are fenced code kept exactly as typed.
  const parts = text.split(/(```[\s\S]*?```)/g)
  const cleaned = parts.map((part, i) => {
    if (i % 2 === 1) return part
    const lines = part.split('\n').map(l => l.replace(/[ \t]+$/, '').replace(/(\S)[ \t]{2,}(?=\S)/g, '$1 '))
    return collapseRuns(lines).join('\n').replace(/\n{3,}/g, '\n\n')
  })
  return cleaned.join('').replace(/^\n+/, '').replace(/\n+$/, '')
}

export const register: Register = on => {
  on('prompt.submit', async ($, e, next) => {
    // Slash commands, system-made prompts and prompts with attachments pass untouched.
    if (e.command || e.isMeta || e.attachments?.length || (await isOff($))) return next(e)
    const text = tidy(e.text)
    const saved = e.text.length - text.length
    if (saved < MIN_SAVED_CHARS || text.length === 0) return next(e)
    const tokens = Math.round(saved / 4)
    const session = await $.session.id().catch(() => '')
    await append(
      $,
      `${await configDir($)}/mods-logs/savings.jsonl`,
      JSON.stringify({
        ts: new Date(await $.clock.now()).toISOString(),
        session,
        mod: NAME,
        action: `prompt trimmed by ${saved} characters (~${tokens} tokens)`,
        before: Math.round(e.text.length / 4),
        after: Math.round(text.length / 4),
        measured: 'estimated',
      }),
    )
    return next({ ...e, text })
  }).catch(($, e, next) => next(e))
}
