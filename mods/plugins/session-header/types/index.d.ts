export type LimitInfo = {
  kind: string
  percent: number
  resetsAt: string | null
}

declare module 'claude-code' {
  interface PluginState {
    'session-header': {
      limits: Shaped<LimitInfo[]>
    }
  }
}
