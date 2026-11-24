export type Range = 'today' | '7d' | '30d' | 'all'

export type Usage = {
  percent: number | null
  tokens: number | null
  window: number
  cost: number | null
  limits: { kind: string; percent: number; resetsAt: string | null }[]
  model: string
  folder: string
}

export type AgentSummary = {
  id: string
  label: string
  type: string
  status: string
  tokenCount: number
}

export type Metrics = {
  sessions: number
  requests: number
  cost_per_request?: number
  fresh_per_request?: number
  tool_chars_per_request?: number
  cache_hit?: number | null
  avg_peak_context?: number
  compactions_per_session?: number
}

export type Compare = {
  enough: boolean
  before: Metrics
  after: Metrics
  change_pct?: Record<string, number | null>
  est_saved_usd?: number
  est_saved_tokens?: number
}

export type Benefit = {
  verdict: string
  system: Compare & { never: Metrics; projects: number }
  mods: Compare & { since: string | null }
  guard: { flagged: number; denied: number; est_tokens_in_big_reads: number }
}

/** What bin/report.py prints with --json. */
export type Report = {
  range: Range
  from: string
  to: string
  generated: number
  sessions: number
  requests: number
  subagent_requests: number
  tokens: { fresh_input: number; cache_read: number; output: number; total_input: number }
  cache_hit: number | null
  cost_usd: number
  unpriced_requests: number
  days: { date: string; sessions: number; requests: number; fresh: number; cache_read: number; output: number; cost: number }[]
  models: { model: string; requests: number; fresh: number; output: number; cost: number }[]
  projects: { name: string; sessions: number; tokens: number }[]
  tools: { name: string; n: number }[]
  savings: {
    actions: number
    real: number
    estimated: number
    saved_in: number
    saved_out: number
    pct_in: number | null
    pct_out: number | null
    usd_saved: number
    helper_usd: number
    left_out: number
    by_mod: { mod: string; actions: number; saved: number; usd_saved: number }[]
  }
  benefit: Benefit | null
  md_path?: string
}

export type View = { range: Range; busy: boolean; error: string; data: Report | null }

declare module 'claude-code' {
  interface PluginState {
    'token-meter': {
      usage: Shaped<Usage | null>
      tools: Shaped<Record<string, number>>
      today: Shaped<Report | null>
      view: Shaped<View>
      agents: Shaped<AgentSummary[]>
      bandHidden: Shaped<boolean>
    }
  }
}
