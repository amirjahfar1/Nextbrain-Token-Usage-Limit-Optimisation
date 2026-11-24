import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import type { AgentSummary, Range, Report, Usage, View } from '../types'

const NAME = 'token-meter'
const PANE = 'token-meter'
const REPORT_PANE = 'token-meter-report'
const RANGES: Range[] = ['today', '7d', '30d', 'all']
const LABEL: Record<Range, string> = { today: 'Today', '7d': '7 days', '30d': '30 days', all: 'All time' }
const FRESH_MS = 60_000
const LIMIT_LABEL: Record<string, string> = { five_hour: '5 hour limit', seven_day: 'Weekly limit', spend_limit: 'Spend limit' }

// Change a tag when the stored fields change: it declines what an earlier version stored.
const usage = atom({ plugin: 'token-meter', key: 'usage' } as const, null, { shape: 'usage-2' })
const tools = atom({ plugin: 'token-meter', key: 'tools' } as const, {}, { shape: 'tools-1' })
const today = atom({ plugin: 'token-meter', key: 'today' } as const, null, { shape: 'today-2' })
const view = atom({ plugin: 'token-meter', key: 'view' } as const, { range: '7d', busy: false, error: '', data: null } as View, {
  shape: 'view-2',
})
const agents = atom({ plugin: 'token-meter', key: 'agents' } as const, [] as AgentSummary[], { shape: 'agents-1' })
const bandHidden = atom({ plugin: 'token-meter', key: 'bandHidden' } as const, false, { shape: 'bandHidden-1' })

// How long until an ISO timestamp, as "2h 14m" / "38m" / "now".
function untilLabel(resetsAt: string | null, nowMs: number): string {
  if (!resetsAt) return ''
  const ms = new Date(resetsAt).getTime() - nowMs
  if (!Number.isFinite(ms) || ms <= 0) return 'resets now'
  const mins = Math.round(ms / 60_000)
  if (mins < 1) return 'resets <1m'
  const h = Math.floor(mins / 60)
  const m = mins % 60
  return `resets in ${h > 0 ? `${h}h ${m}m` : `${m}m`}`
}

const C = { title: '#c4b5fd', accent: '#a78bfa', blue: '#60a5fa', good: '#4ade80', warn: '#fbbf24', bad: '#f87171', border: '#6d5bd0' }
const tone = (pct: number) => (pct < 60 ? C.good : pct < 85 ? C.warn : C.bad)
const fmt = (n: number) => (n >= 1e6 ? `${(n / 1e6).toFixed(1)}M` : n >= 1e3 ? `${(n / 1e3).toFixed(1)}k` : `${Math.round(n)}`)
const pct = (v: number | null) => (v === null ? 'n/a' : `${v}%`)
const usd = (v: number) => `$${v.toFixed(2)}`
const usd3 = (v: number) => `$${v.toFixed(3)}`
const noop = () => undefined
const chg = (v: number | null | undefined) => (v === null || v === undefined ? 'n/a' : `${v > 0 ? '+' : ''}${v}%`)

/** Runs bin/report.py and parses its JSON. Tries python3 on the PATH, then /usr/bin/python3. */
async function runReport($: EngineInterface, range: Range, save: boolean, quick = false): Promise<{ data: Report | null; error: string }> {
  const args = [`${$.plugin.root}/bin/report.py`, range, '--json', ...(quick ? ['--quick'] : []), ...(save ? ['--md-out', 'auto'] : [])]
  let error = 'python3 not found'
  for (const py of ['python3', '/usr/bin/python3']) {
    try {
      const r = await $.process.run([py, ...args], { timeoutMs: 60_000 })
      if (r.exitCode === 0) return { data: JSON.parse(r.stdout) as Report, error: '' }
      error = r.stderr.trim().slice(0, 160) || `report.py exited ${r.exitCode}`
      if (!/not found|No such file/i.test(error)) break
    } catch (err) {
      error = String(err).slice(0, 160)
    }
  }
  return { data: null, error }
}

async function refreshToday($: EngineInterface) {
  const { data } = await runReport($, 'today', false, true)
  if (data) await update($, today, () => data)
}

async function loadView($: EngineInterface, range: Range, quick = false) {
  await update($, view, v => ({ ...v, range, busy: true, error: '' }))
  const { data, error } = await runReport($, range, true, quick)
  await update($, view, v => ({ ...v, busy: false, error, data: data ?? v.data }))
}

async function openReport($: EngineInterface) {
  await $.ui.open({ id: REPORT_PANE, title: 'Token Report' })
  const v = await read($, view)
  const stale = !v.data || v.data.range !== v.range || Date.now() / 1000 - v.data.generated > FRESH_MS / 1000
  if (!v.busy && stale) await loadView($, v.range)
}

export const register: Register = on => {
  let running = false

  on('session.start', async ($, e, next) => {
    await $.command.register({ name: 'token-meter', description: 'Open the Token Meter pane' })
    await $.command.register({ name: 'token-report', description: 'Open the full token report: sessions, input, output, savings' })
    void $.ui.open({ id: PANE, title: 'Token Meter' })

    const tick = async () => {
      try {
        const u = await $.session.usage()
        const parts = (await $.session.cwd()).split('/').filter(Boolean)
        const value: Usage = {
          percent: u.context.percent ?? null,
          tokens: u.context.tokens ?? null,
          window: u.context.window,
          cost: u.cost?.usd ?? null,
          limits: u.rateLimits.map(r => ({ kind: r.kind, percent: Math.round(r.percentUsed), resetsAt: r.resetsAt ?? null })),
          model: await $.session.model(),
          folder: parts[parts.length - 1] ?? '/',
        }
        await update($, usage, () => value)
      } catch {
        // keep the last good reading
      }
      try {
        const list = await $.agent.list()
        const live = list
          .filter(a => a.status === 'running' || a.status === 'pending' || a.taskStatus === 'running' || a.taskStatus === 'pending')
          .map(a => ({ id: a.id, label: a.label || a.description, type: a.type, status: a.status, tokenCount: a.tokenCount }))
        await update($, agents, () => live)
      } catch {
        // keep the last good reading
      }
    }
    await tick()
    void loadView($, '7d', true).catch(() => undefined)
    void refreshToday($).catch(() => undefined)
    if (!running) {
      running = true
      $.clock.every(5000, () => void tick())
      $.clock.every(300_000, () => void refreshToday($).catch(() => undefined))
    }
    return next(e)
  })

  on('command.run', { command: 'token-meter' }, async $ => {
    await $.ui.open({ id: PANE, title: 'Token Meter' })
    return { text: 'Token Meter opened. Press Full report for sessions, tokens and savings.' }
  })

  on('command.run', { command: 'token-report' }, async $ => {
    await openReport($)
    return { text: 'Token report opened.' }
  })

  on('tool.call', async ($, e, next) => {
    await update($, tools, t => ({ ...t, [e.tool]: (t[e.tool] ?? 0) + 1 }))
    return next(e)
  })

  on('ui.press', { plugin: NAME, element: 'report' }, async ($, e) => {
    await openReport($)
    return { element: e.element }
  })
  on('ui.press', { plugin: NAME, element: 'refresh' }, async ($, e) => {
    await refreshToday($).catch(() => undefined)
    if ((await read($, view)).data) await loadView($, (await read($, view)).range)
    return { element: e.element }
  })
  for (const r of RANGES) {
    on('ui.press', { plugin: NAME, element: `range:${r}` }, async ($, e) => {
      await loadView($, r)
      return { element: e.element }
    })
  }
  on('ui.press', { plugin: NAME, element: 'file' }, async ($, e) => {
    const p = (await read($, view)).data?.md_path
    if (p) await $.process.run(['open', '-t', p]).catch(() => undefined)
    return { element: e.element }
  })
  on('ui.press', { plugin: NAME, element: 'band-hide' }, async ($, e) => {
    await update($, bandHidden, () => true)
    return { element: e.element }
  })
  on('ui.press', { plugin: NAME, element: 'band-show' }, async ($, e) => {
    await update($, bandHidden, () => false)
    return { element: e.element }
  })

  // ---- the floating limits widget, above the prompt ----
  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const rest = await next(e)
    const hidden = await read($, bandHidden)
    if (hidden) return rest
    const u = await read($, usage)
    if (!u || u.limits.length === 0) return rest
    const { Box, Text, Button } = $.ui.resolve(e)
    const now = await $.clock.now()
    const noop = () => undefined
    return (
      <Box flexDirection="column">
        {rest}
        <Box flexDirection="row" alignItems="center" justifyContent="space-between" gap={1}>
          <Text>
            {u.limits.map((l, i) => (
              <Text key={l.kind}>
                {i > 0 ? <Text dimColor>  ·  </Text> : null}
                <Text dimColor>{(LIMIT_LABEL[l.kind] ?? l.kind).replace(' limit', '')} </Text>
                <Text bold color={tone(l.percent)}>{l.percent}%</Text>
                {l.resetsAt ? <Text dimColor> ({untilLabel(l.resetsAt, now)})</Text> : null}
              </Text>
            ))}
          </Text>
          <Button key="band-hide" label="Hide" role="dismiss" onPress={noop} />
        </Box>
      </Box>
    )
  })

  // ---- the meter pane ----
  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    const { Box, Text, Button } = $.ui.resolve(e)
    const u = await read($, usage)
    const used = await read($, tools)
    const t = await read($, today)
    const live = await read($, agents)
    const now = await $.clock.now()
    const hidden = await read($, bandHidden)
    const width = Math.max(12, Math.min(36, (e.props.bodyColumns ?? 40) - 10))
    const bar = (p: number) => {
      const filled = Math.round((Math.min(100, Math.max(0, p)) / 100) * width)
      return (
        <Text>
          <Text color={tone(p)}>{'█'.repeat(filled)}</Text>
          <Text dimColor>{'░'.repeat(width - filled)}</Text>
        </Text>
      )
    }
    const top = Object.entries(used).sort((a, b) => b[1] - a[1]).slice(0, 5)
    const maxCalls = top[0]?.[1] ?? 1
    const card = { flexDirection: 'column', borderStyle: 'round', borderColor: C.border, paddingX: 1 } as const

    return (
      <Box flexDirection="column" gap={1}>
        <Box {...card}>
          <Text bold color={C.title}>Token Meter</Text>
          {u === null || u.percent === null ? (
            <Text dimColor>Waiting for the first reply…</Text>
          ) : (
            <Box flexDirection="column">
              <Text>{bar(u.percent)} <Text bold>{Math.round(u.percent)}%</Text></Text>
              <Text dimColor>{fmt(u.tokens ?? 0)} of {fmt(u.window)} tokens in context</Text>
            </Box>
          )}
          {u?.limits.map(l => (
            <Box flexDirection="column">
              <Text dimColor>{LIMIT_LABEL[l.kind] ?? `${l.kind.replace(/_/g, ' ')} limit`}</Text>
              <Text>{bar(l.percent)} <Text bold>{l.percent}%</Text></Text>
              {l.resetsAt && <Text dimColor>{untilLabel(l.resetsAt, now)}</Text>}
            </Box>
          ))}
          {u?.cost != null && <Text dimColor>≈ ${u.cost.toFixed(2)} spent (estimate)</Text>}
          {hidden && <Button key="band-show" label="Show limits above prompt" variant="secondary" onPress={() => undefined} />}
        </Box>

        <Box {...card}>
          <Text bold color={C.title}>Active Agents {live.length > 0 ? `(${live.length})` : ''}</Text>
          {live.length === 0 ? (
            <Text dimColor>No subagents running right now.</Text>
          ) : (
            live.map(a => (
              <Box key={a.id} flexDirection="column">
                <Text>
                  <Text color={C.accent}>●</Text> <Text bold>{a.type}</Text> <Text dimColor>({a.status})</Text>
                </Text>
                <Text dimColor wrap="truncate-end">{a.label}</Text>
              </Box>
            ))
          )}
        </Box>

        <Box {...card}>
          <Text bold color={C.title}>Today</Text>
          {t === null ? (
            <Text dimColor>Reading the transcripts…</Text>
          ) : (
            <Box flexDirection="column">
              <Text>{t.sessions} sessions · cache hit {pct(t.cache_hit)}</Text>
              <Text dimColor>in {fmt(t.tokens.total_input)} · out {fmt(t.tokens.output)} · ≈ {usd(t.cost_usd)}</Text>
              <Text color={C.good}>saved {fmt(t.savings.saved_in + t.savings.saved_out)} tokens ({pct(t.savings.pct_in)})</Text>
              {t.benefit && <Text dimColor>{t.benefit.verdict}</Text>}
            </Box>
          )}
          <Box flexDirection="row" gap={1}>
            <Button key="report" label="Full report" onPress={noop} />
            <Button key="refresh" label="Refresh" variant="secondary" onPress={noop} />
          </Box>
        </Box>

        <Box {...card}>
          <Text bold color={C.title}>Top Tools</Text>
          {top.length === 0 && <Text dimColor>No tool calls yet.</Text>}
          {top.map(([name, n]) => (
            <Text>
              <Text color={C.accent}>{'▇'.repeat(Math.max(1, Math.round((n / maxCalls) * 10)))}</Text>
              <Text> {name} </Text>
              <Text dimColor>×{n}</Text>
            </Text>
          ))}
        </Box>
      </Box>
    )
  })

  // ---- the full report pane ----
  on('ui.render', { component: 'Pane', requestId: REPORT_PANE }, async ($, e) => {
    const { Box, Text, Button } = $.ui.resolve(e)
    const v = await read($, view)
    const r = v.data
    const card = { flexDirection: 'column', borderStyle: 'round', borderColor: C.border, paddingX: 1 } as const
    const row = (cells: string[], widths: number[]) => cells.map((c, i) => c.padEnd(widths[i] ?? 0)).join(' ')

    return (
      <Box flexDirection="column" gap={1}>
        <Box {...card}>
          <Text bold color={C.title}>Token Report</Text>
          <Box flexDirection="row" gap={1}>
            {RANGES.map(x => (
              <Button key={`range:${x}`} label={LABEL[x]} variant={x === v.range ? 'primary' : 'secondary'} onPress={noop} />
            ))}
          </Box>
          {v.busy && <Text dimColor>Reading the transcripts…</Text>}
          {v.error !== '' && <Text color={C.bad}>{v.error}</Text>}
          {r && <Text dimColor>{r.from} to {r.to}</Text>}
        </Box>

        {r && (
          <Box flexDirection="column" gap={1}>
            <Box {...card}>
              <Text bold color={C.title}>Usage</Text>
              <Text>{r.sessions} sessions · {r.requests} requests ({r.subagent_requests} by subagents)</Text>
              <Text>input {fmt(r.tokens.total_input)} <Text dimColor>({fmt(r.tokens.fresh_input)} fresh, {fmt(r.tokens.cache_read)} cached)</Text></Text>
              <Text>output {fmt(r.tokens.output)} · cache hit {pct(r.cache_hit)}</Text>
              <Text>cost ≈ {usd(r.cost_usd)} <Text dimColor>(list-price estimate)</Text></Text>
            </Box>

            {r.benefit && (
              <Box {...card}>
                <Text bold color={C.title}>Is the system paying off?</Text>
                <Text bold>{r.benefit.verdict}</Text>
                {r.benefit.system.enough && r.benefit.system.change_pct && (
                  <Box flexDirection="column">
                    <Text dimColor>per request: before → with the system</Text>
                    <Text>cost {usd3(r.benefit.system.before.cost_per_request ?? 0)} → {usd3(r.benefit.system.after.cost_per_request ?? 0)} ({chg(r.benefit.system.change_pct.cost_per_request)})</Text>
                    <Text>fresh input {fmt(r.benefit.system.before.fresh_per_request ?? 0)} → {fmt(r.benefit.system.after.fresh_per_request ?? 0)} ({chg(r.benefit.system.change_pct.fresh_per_request)})</Text>
                    <Text>tool output {fmt(r.benefit.system.before.tool_chars_per_request ?? 0)} → {fmt(r.benefit.system.after.tool_chars_per_request ?? 0)} chars ({chg(r.benefit.system.change_pct.tool_chars_per_request)})</Text>
                    <Text>cache hit {pct(r.benefit.system.before.cache_hit ?? null)} → {pct(r.benefit.system.after.cache_hit ?? null)}</Text>
                    <Text color={C.good}>≈ {usd(r.benefit.system.est_saved_usd ?? 0)} and {fmt(r.benefit.system.est_saved_tokens ?? 0)} tokens saved</Text>
                  </Box>
                )}
                {r.benefit.mods.since && (
                  <Text dimColor>
                    mods since {r.benefit.mods.since}: {r.benefit.mods.enough && r.benefit.mods.change_pct ? `cost per request ${chg(r.benefit.mods.change_pct.cost_per_request)}` : 'collecting data'}
                  </Text>
                )}
                {r.benefit.guard.flagged > 0 && (
                  <Text dimColor>guard: {r.benefit.guard.flagged} big reads flagged ({r.benefit.guard.denied} blocked), ≈ {fmt(r.benefit.guard.est_tokens_in_big_reads)} tokens</Text>
                )}
                <Text dimColor>Indicative, not proof: it firms up with more sessions.</Text>
              </Box>
            )}

            <Box {...card}>
              <Text bold color={C.title}>Savings (measured)</Text>
              <Text color={C.good}>input kept out: {fmt(r.savings.saved_in)} ({pct(r.savings.pct_in)})</Text>
              <Text color={C.good}>output kept out: {fmt(r.savings.saved_out)} ({pct(r.savings.pct_out)})</Text>
              <Text>routing saved {usd(r.savings.usd_saved)} · helpers cost {usd(r.savings.helper_usd)}</Text>
              <Text dimColor>{r.savings.actions} actions ({r.savings.real} real, {r.savings.estimated} estimated)</Text>
              {r.savings.by_mod.map(m => (
                <Text dimColor>{m.mod}: {fmt(m.saved)} tokens · {m.actions} actions</Text>
              ))}
              <Text dimColor>Rule savings (reading discipline, guards) are not measured.</Text>
            </Box>

            <Box {...card}>
              <Text bold color={C.title}>By day</Text>
              <Text dimColor>{row(['day', 'ses', 'fresh', 'cached', 'out', '$'], [5, 3, 6, 6, 6, 6])}</Text>
              {r.days.slice(-7).map(d => (
                <Text>{row([d.date.slice(5), String(d.sessions), fmt(d.fresh), fmt(d.cache_read), fmt(d.output), d.cost.toFixed(2)], [5, 3, 6, 6, 6, 6])}</Text>
              ))}
            </Box>

            <Box {...card}>
              <Text bold color={C.title}>By model</Text>
              {r.models.map(m => (
                <Text>{m.model} <Text dimColor>{m.requests} req · out {fmt(m.output)} · {usd(m.cost)}</Text></Text>
              ))}
            </Box>

            <Box {...card}>
              <Text bold color={C.title}>By project</Text>
              {r.projects.map(p => (
                <Text>{p.name} <Text dimColor>{p.sessions} ses · {fmt(p.tokens)}</Text></Text>
              ))}
            </Box>

            <Box {...card}>
              <Text bold color={C.title}>Top tools</Text>
              {r.tools.map(x => (
                <Text>{x.name} <Text dimColor>×{x.n}</Text></Text>
              ))}
            </Box>

            <Box flexDirection="row" gap={1}>
              <Button key="file" label="Open report file" onPress={noop} />
              <Button key={`range:${v.range}`} label="Refresh" variant="secondary" onPress={noop} />
            </Box>
          </Box>
        )}
      </Box>
    )
  })
}
