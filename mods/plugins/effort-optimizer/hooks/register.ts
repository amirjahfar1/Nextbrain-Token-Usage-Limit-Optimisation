import type { EngineInterface, Register } from 'claude-code'

// Effort Optimizer lowers thinking effort to "low" for a trivial prompt only.
// It never raises effort, never touches a hard, long or code-heavy prompt, and
// makes no model call. One decision per turn; later steps of the turn reuse it.

const NAME = 'effort-optimizer'
const LOW_OR_BELOW = new Set(['low'])

// Short confirmations, thanks and one-word git chores. Roman Urdu included.
const TRIVIAL = /^(y|yes|yep|yeah|ok|okay|k|thanks|thank you|thx|ty|shukriya|haan|han|theek hai|thik hai|sahi|acha|achha|great|nice|cool|done|commit|push|commit and push|git status|status|undo that|nevermind|never mind|no|nope|nahi)[\s.!?,]*$/i
// Anything that smells like real thinking is left alone.
const HARD = /(debug|root cause|architect|design|security|refactor|investigate|migrat|optimi[sz]e|review|plan|why|analy[sz]e|compare|fix|bug|error|test)/i

let dir = ''
let decided: { turnId: string; low: boolean } | null = null
let lastPrompt = ''

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

async function log($: EngineInterface, line: string) {
  const text = `${new Date(await $.clock.now()).toISOString()} ${line}\n`
  await $.process
    .run(['/bin/sh', '-c', 'mkdir -p "$(dirname "$1")" && cat >> "$1"', 'sh', `${await configDir($)}/mods-logs/${NAME}.log`], { stdin: text, timeoutMs: 5000 })
    .catch(() => undefined)
}

/** True only for a short, plain, clearly trivial prompt. */
export function isTrivial(text: string): boolean {
  const t = text.trim()
  if (t.length === 0 || t.length > 40 || t.includes('\n') || t.includes('```')) return false
  if (HARD.test(t)) return false
  return TRIVIAL.test(t)
}

export const register: Register = on => {
  on('prompt.submit', async ($, e, next) => {
    lastPrompt = e.command || e.isMeta ? '' : e.text
    return next(e)
  }).catch(($, e, next) => next(e))

  on('turn.step', async function* ($, e, next) {
    // Subagents and an off switch pass untouched.
    if (e.agentId || (await isOff($))) return yield* next(e)
    if (!decided || decided.turnId !== e.turnId) {
      decided = { turnId: e.turnId, low: e.index === 0 && isTrivial(lastPrompt) }
      lastPrompt = ''
    }
    const current = e.effort
    // Only lower: skip when the model has no effort, or it is low already.
    if (!decided.low || typeof current !== 'string' || LOW_OR_BELOW.has(current)) return yield* next(e)
    if (e.index === 0) await log($, `effort ${current} -> low: trivial prompt`)
    return yield* next({ ...e, effort: 'low' })
  })
}
