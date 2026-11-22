import { expect, test } from 'claude-code/testing'

const REPORT = {
  range: '7d', from: '2026-11-16', to: '2026-11-23', generated: Math.floor(Date.now() / 1000),
  sessions: 5, requests: 163, subagent_requests: 2,
  tokens: { fresh_input: 486600, cache_read: 33400000, output: 158200, total_input: 33886600 },
  cache_hit: 99, cost_usd: 10.22, unpriced_requests: 0,
  days: [{ date: '2026-11-23', sessions: 5, requests: 163, fresh: 486600, cache_read: 33400000, output: 158200, cost: 10.22 }],
  models: [{ model: 'claude-sonnet-5-5', requests: 163, fresh: 486600, output: 158200, cost: 10.22 }],
  projects: [{ name: 'demo', sessions: 3, tokens: 34100000 }],
  tools: [{ name: 'Bash', n: 107 }],
  savings: {
    actions: 2, real: 1, estimated: 1, saved_in: 12000, saved_out: 0, pct_in: 2.4, pct_out: 0,
    usd_saved: 0.12, helper_usd: 0.01, left_out: 0,
    by_mod: [{ mod: 'research-router', actions: 2, saved: 12000, usd_saved: 0 }],
  },
  benefit: {
    verdict: 'With the system a request costs -55% (indicative); about $0.51 saved over 30 requests.',
    system: {
      enough: true, projects: 1, never: { sessions: 0, requests: 0 },
      before: { sessions: 3, requests: 30, cost_per_request: 0.031, fresh_per_request: 8000, tool_chars_per_request: 20000, cache_hit: 71, avg_peak_context: 28000, compactions_per_session: 0 },
      after: { sessions: 3, requests: 30, cost_per_request: 0.014, fresh_per_request: 1500, tool_chars_per_request: 5000, cache_hit: 95, avg_peak_context: 31500, compactions_per_session: 0 },
      change_pct: { cost_per_request: -55, fresh_per_request: -81, tool_chars_per_request: -75, avg_peak_context: 12 },
      est_saved_usd: 0.51, est_saved_tokens: 195000,
    },
    mods: { enough: false, since: '2026-11-22', before: { sessions: 1, requests: 3 }, after: { sessions: 4, requests: 100 } },
    guard: { flagged: 2, denied: 1, est_tokens_in_big_reads: 40000 },
  },
  md_path: '/tmp/report-7d.md',
}

const pane = (id: string, title: string) =>
  ({
    plugin: 'token-meter', component: 'Pane', requestId: id,
    props: { title, isFocused: false, bodyColumns: 44, placement: 'dock', scroll: { offset: 0, bodyRows: 30 }, view: {} },
  }) as const

test('the meter pane and the full report, on every surface', async ($, on) => {
  on('command.register', () => ({ value: { command: 'x' } }))
  on('ui.open', () => ({ value: { isPlaced: true } }))
  on('clock.every', () => ({ value: undefined }))
  on('session.cwd', () => ({ value: '/work/demo' }))
  on('session.model', () => ({ value: 'claude-sonnet-5-5' }))
  on('session.usage', () => ({
    value: {
      startedAt: 0,
      context: { percent: 17, tokens: 170000, window: 1000000 },
      rateLimits: [{ kind: 'five_hour', percentUsed: 4 }, { kind: 'seven_day', percentUsed: 4 }],
      cost: { usd: 1.49 },
    },
  }))
  on('process.run', () => ({
    value: { exitCode: 0, stdout: JSON.stringify(REPORT), stderr: '', isStdoutTruncated: false, isStderrTruncated: false },
  }))
  on('session.start', (_, e) => ({ cwd: e.cwd }))

  await $.session.start({ cwd: '/work/demo', surface: 'desktop', isInteractive: true })

  for (const surface of ['terminal', 'desktop'] as const) {
    const meter = await $.ui.mount({ ...pane('token-meter', 'Token Meter'), surface })
    expect(await meter.find({ type: 'Text', text: /17%/ })).toBeDefined()
    expect(await meter.find({ type: 'Text', text: /1\.49/ })).toBeDefined()
    expect(await meter.find({ type: 'Text', text: /saved 12\.0k tokens/ })).toBeDefined()
    expect(await meter.find({ type: 'Text', text: /costs -55%/ })).toBeDefined()
    await meter.press({ key: 'report' })
    await meter.unmount()

    const rep = await $.ui.mount({ ...pane('token-meter-report', 'Token Report'), surface })
    expect(await rep.find({ type: 'Text', text: /5 sessions/ })).toBeDefined()
    expect(await rep.find({ type: 'Text', text: /cache hit 99%/ })).toBeDefined()
    expect(await rep.find({ type: 'Text', text: /input kept out: 12\.0k \(2\.4%\)/ })).toBeDefined()
    expect(await rep.find({ type: 'Text', text: /Is the system paying off/ })).toBeDefined()
    expect(await rep.find({ type: 'Text', text: /cost \$0\.031 → \$0\.014 \(-55%\)/ })).toBeDefined()
    expect(await rep.find({ type: 'Text', text: /guard: 2 big reads flagged \(1 blocked\)/ })).toBeDefined()
    await rep.unmount()
  }
})

test('a report script that fails shows its error and no data', async ($, on) => {
  on('command.register', () => ({ value: { command: 'x' } }))
  on('ui.open', () => ({ value: { isPlaced: true } }))
  on('clock.every', () => ({ value: undefined }))
  on('session.cwd', () => ({ value: '/work/demo' }))
  on('session.model', () => ({ value: 'claude-sonnet-5-5' }))
  on('session.usage', () => ({ value: { startedAt: 0, context: { percent: null, tokens: null, window: 1000000 }, rateLimits: [] } }))
  on('process.run', () => ({
    value: { exitCode: 1, stdout: '', stderr: 'boom', isStdoutTruncated: false, isStderrTruncated: false },
  }))
  on('session.start', (_, e) => ({ cwd: e.cwd }))

  await $.session.start({ cwd: '/work/demo', surface: 'desktop', isInteractive: true })
  const meter = await $.ui.mount({ ...pane('token-meter', 'Token Meter'), surface: 'desktop' })
  await meter.press({ key: 'report' })
  await meter.unmount()
  const rep = await $.ui.mount({ ...pane('token-meter-report', 'Token Report'), surface: 'desktop' })
  expect(await rep.find({ type: 'Text', text: /boom/ })).toBeDefined()
  await rep.unmount()
})
