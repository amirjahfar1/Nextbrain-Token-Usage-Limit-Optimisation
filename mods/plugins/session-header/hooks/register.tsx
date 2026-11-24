import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import type { LimitInfo } from '../types'

const LIMIT_LABEL: Record<string, string> = { five_hour: '5h limit', seven_day: 'Weekly limit', spend_limit: 'Spend' }

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

// Change a tag when the stored fields change: it declines what an earlier version stored.
const limits = atom({ plugin: 'session-header', key: 'limits' } as const, [] as LimitInfo[], { shape: 'limits-1' })

// How long until an ISO timestamp: "5d 3h 30m" past a day, else "2h 14m" / "38m" / "now".
function untilLabel(resetsAt: string | null, nowMs: number): string {
  if (!resetsAt) return ''
  const ms = new Date(resetsAt).getTime() - nowMs
  if (!Number.isFinite(ms) || ms <= 0) return 'resets now'
  const mins = Math.round(ms / 60_000)
  if (mins < 1) return '<1m left'
  const totalHours = Math.floor(mins / 60)
  const m = mins % 60
  if (totalHours >= 24) {
    const d = Math.floor(totalHours / 24)
    const h = totalHours % 24
    return `${d}d ${h}h ${m}m left`
  }
  return totalHours > 0 ? `${totalHours}h ${m}m left` : `${m}m left`
}

const GOOD = '#4ade80'
const WARN = '#fbbf24'
const BAD = '#f87171'
const ACCENT = '#60a5fa'
const tone = (pct: number) => (pct < 60 ? GOOD : pct < 85 ? WARN : BAD)

export const register: Register = on => {
  let running = false

  on('session.start', async ($, e, next) => {
    home = await findHome($)
    // Rates come from the API's own response, empty until this session's first
    // reading. Seed from the plugin's cross-session store so a brand new chat
    // shows the last known numbers right away, not a blank row.
    try {
      const last = (await $.store.get('limits')) as LimitInfo[] | undefined
      if (Array.isArray(last) && last.length > 0) await update($, limits, () => last)
    } catch {
      // No earlier reading saved yet.
    }
    const tick = async () => {
      try {
        const u = await $.session.usage()
        if (u.rateLimits.length === 0) return
        const value: LimitInfo[] = u.rateLimits.map(r => ({ kind: r.kind, percent: Math.round(r.percentUsed), resetsAt: r.resetsAt ?? null }))
        await update($, limits, () => value)
        await $.store.set('limits', value)
      } catch {
        // keep the last good reading
      }
    }
    await tick()
    if (!running) {
      running = true
      $.clock.every(5000, () => void tick())
    }
    return next(e)
  })

  // Always on: a thin, un-hideable row with the folder and, once read, the
  // account's 5 hour and weekly limits and when each resets.
  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const rest = await next(e)
    const { Box, Text } = $.ui.resolve(e)
    const cwd = await $.session.cwd().catch(() => '')
    const folder = cwd ? tilde(cwd).split('/').pop() || tilde(cwd) : '/'
    const ls = await read($, limits)
    const now = await $.clock.now()

    return (
      <Box flexDirection="column">
        <Box flexDirection="row" alignItems="center" gap={1}>
          <Text color={ACCENT}>📁 {folder}</Text>
          {ls.map(l => (
            <Text key={l.kind}>
              <Text dimColor> │ </Text>
              <Text dimColor>{LIMIT_LABEL[l.kind] ?? l.kind} </Text>
              <Text bold color={tone(l.percent)}>{l.percent}%</Text>
              {l.resetsAt ? <Text dimColor> · {untilLabel(l.resetsAt, now)}</Text> : null}
            </Text>
          ))}
        </Box>
        {rest}
      </Box>
    )
  })
}
