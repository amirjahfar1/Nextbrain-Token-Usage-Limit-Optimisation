#!/bin/sh
# make_project.sh <dest>  : build a realistic big project to install the token system into.
# Env switches (all optional):
#   ENTRY=both|separate|agents|claude|none|symlink|crlf|nonl|dotclaude   (default both: AGENTS.md + CLAUDE.md "@AGENTS.md")
#   SETTINGS=rich|overlap|invalid|empty|bom|trailing|nullperm|none       (default rich)
#   OWN_AGENTS_SKILLS="tips handoff"   unmanaged skills with OUR names in .agents/skills
#   OWN_CLAUDE_SKILLS="tips"           real dirs with OUR names in .claude/skills
#   OWN_CLAUDE_LINKS="tips"            .claude/skills/<n> -> ../../shared-skills/<n> (project's own symlinked skill)
#   GIT=1  git init + commit      BIG=1  add a 100 MB file      LITE=1  skip the bulk (fast)
set -eu
D=$1; ENTRY=${ENTRY:-both}; SETTINGS=${SETTINGS:-rich}
rm -rf "$D"; mkdir -p "$D"; cd "$D"
mkdir -p .claude/skills .agents/skills src docs generated dist "docs/my notes" .github/workflows

rules='# Project rules

- Always run `pnpm test` before a commit.
- Never touch `infra/` without the owner.
- Reply in English. Unicode: café ✓

## Skills
See `.claude/skills/`.
'
case "$ENTRY" in
  both)     printf '%s' "$rules" > AGENTS.md; printf '@AGENTS.md\n' > CLAUDE.md ;;
  separate) printf '%s' "$rules" > AGENTS.md; printf '# Claude rules\n\n- Use plan mode for big work.\n' > CLAUDE.md ;;
  agents)   printf '%s' "$rules" > AGENTS.md ;;
  claude)   printf '%s' "$rules" > CLAUDE.md ;;
  symlink)  printf '%s' "$rules" > AGENTS.md; ln -s AGENTS.md CLAUDE.md ;;
  crlf)     printf '# Rules\r\n\r\n- one\r\n- two\r\n' > AGENTS.md; printf '@AGENTS.md\r\n' > CLAUDE.md ;;
  nonl)     printf '# Rules\n\n- one\n- last line without newline' > AGENTS.md; printf '@AGENTS.md' > CLAUDE.md ;;
  dotclaude) printf '%s' "$rules" > .claude/CLAUDE.md ;;
  none) : ;;
esac

rich='{
    "$schema": "https://json.schemastore.org/claude-code-settings.json",
    "env": {"FOO": "bar", "GREETING": "café ✓"},
    "permissions": {
        "allow": ["Bash(pnpm test:*)", "Bash(git status)", "Read(src/**)"],
        "deny": ["Read(.env)", "Read(secrets/**)"OVERLAP],
        "ask": ["Bash(git push:*)"],
        "defaultMode": "acceptEdits"
    },
    "hooks": {
        "PreToolUse": [
            {"matcher": "Bash", "hooks": [{"type": "command", "command": "sh .claude/hooks/pre-bash.sh"}, {"type": "command", "command": "sh .claude/hooks/audit.sh", "timeout": 5}]},
            {"matcher": "Read|Edit|Write", "hooks": [{"type": "command", "command": "python3 .claude/hooks/own_read_guard.py"}]}
        ],
        "PostToolUse": [{"matcher": "Edit|Write", "hooks": [{"type": "command", "command": "pnpm prettier --write"}]}],
        "SessionStart": [{"hooks": [{"type": "command", "command": "cat .claude/context.md"}]}],
        "SessionEnd": [{"hooks": [{"type": "command", "command": "sh .claude/hooks/end.sh"}]}],
        "Stop": [{"hooks": [{"type": "command", "command": "sh .claude/hooks/stop.sh"}]}]
    },
    "enabledPlugins": {"foo@bar": true},
    "statusLine": {"type": "command", "command": "sh .claude/statusline.sh"},
    "x-company-unknown": {"keep": [1, 2, 3], "nested": {"a": null}}
}'
case "$SETTINGS" in
  rich)     printf '%s\n' "$rich" | sed 's/OVERLAP//' > .claude/settings.json ;;
  overlap)  printf '%s\n' "$rich" | sed 's|OVERLAP|, "Read(**/package-lock.json)", "Read(**/*.min.js)"|' > .claude/settings.json ;;
  invalid)  printf '{"permissions": {"deny": ["Read(.env)"]}, "hooks": {\n' > .claude/settings.json ;;
  empty)    : > .claude/settings.json ;;
  bom)      printf '\357\273\277{"permissions": {"deny": ["Read(.env)"]}}\n' > .claude/settings.json ;;
  trailing) printf '{"permissions": {"deny": ["Read(.env)",]},}\n' > .claude/settings.json ;;
  nullperm) printf '{"permissions": null, "hooks": null, "env": {"A": "1"}}\n' > .claude/settings.json ;;
  none) : ;;
esac
if [ "$SETTINGS" != none ]; then
  printf '{"permissions": {"allow": ["Bash(ls:*)"]}, "hooks": {"Stop": [{"hooks": [{"type": "command", "command": "say done"}]}]}}\n' > .claude/settings.local.json
  printf '{"mcpServers": {"db": {"command": "npx", "args": ["-y", "some-mcp"]}}}\n' > .mcp.json
  mkdir -p .claude/hooks .claude/commands
  for h in pre-bash audit end stop; do printf '#!/bin/sh\nexit 0\n' > ".claude/hooks/$h.sh"; done
  printf 'import sys\nsys.exit(0)\n' > .claude/hooks/own_read_guard.py
  printf 'Deploy the app.\n' > .claude/commands/deploy.md
fi
printf 'node_modules\n.env\ndist/\n*.log' > .gitignore   # no trailing newline on purpose

if [ -z "${LITE:-}" ]; then
  i=1
  while [ $i -le 45 ]; do
    n=$(printf 'skill-%02d' $i); base=.claude/skills
    [ $i -gt 40 ] && base=.agents/skills
    mkdir -p "$base/$n/scripts"
    printf -- '---\nname: %s\ndescription: Project skill number %s. Use when asked for %s.\n---\n\nBody of %s.\n' "$n" "$i" "$n" "$n" > "$base/$n/SKILL.md"
    printf '#!/bin/sh\necho %s\n' "$n" > "$base/$n/scripts/run.sh"
    printf 'def main():\n    return %s\n' "$i" > "$base/$n/scripts/helper.py"
    [ $i -gt 40 ] && ln -s "../../.agents/skills/$n" ".claude/skills/$n"
    i=$((i + 1))
  done
  ln -s skill-01 .claude/skills/skill-alias
  i=1
  while [ $i -le 320 ]; do
    d=src/mod$((i % 12)); mkdir -p "$d"
    printf 'export const v%s = %s;\n// line two\n' "$i" "$i" > "$d/file$i.ts"
    i=$((i + 1))
  done
  i=1; while [ $i -le 40 ]; do printf '# Doc %s\n\ntext\n' $i > "docs/doc$i.md"; i=$((i + 1)); done
  printf 'note with spaces\n' > "docs/my notes/a file with spaces.md"
  printf 'unicode name\n' > "docs/café ✓ résumé.md"
  printf 'line1\r\nline2\r\n' > src/windows-crlf.txt
  printf 'no newline at end' > src/no-newline.txt
  # 5 MB lockfile, minified bundle, generated folder, big doc, big source
  yes '    "resolved": "https://registry.npmjs.org/some-package/-/some-package-1.2.3.tgz",' | head -c 5242880 > package-lock.json
  yes 'lockfileVersion: 9' | head -c 300000 > pnpm-lock.yaml
  yes 'var a=function(b){return b+1};' | tr -d '\n' | head -c 400000 > src/bundle.min.js
  yes '{"id": 1, "generated": true}' | head -c 250000 > generated/catalog.json
  yes 'export const built = 1;' | head -c 90000 > dist/app.js
  yes 'const x = 1; // a big hand-written source line' | head -c 120000 > src/big-source.ts
  { printf '# Big doc\n\nintro\n'; i=1; while [ $i -le 30 ]; do printf '\n## Section %s\n' $i; yes 'some long documentation line here' | head -40; i=$((i + 1)); done; } > docs/big-doc.md
  mkdir -p src/dist; printf 'export const handler = 1;\n' > src/dist/handler.ts   # real source in a folder named dist
  yes 'steps: big workflow' | head -c 70000 > .github/workflows/big.yml
fi
[ -n "${BIG:-}" ] && { mkdir -p data; dd if=/dev/zero bs=1048576 count=100 2>/dev/null | tr '\0' 'x' > data/huge-100mb.jsonl; }

body() { printf -- '---\nname: %s\ndescription: The PROJECT own %s skill (not the token system).\n---\n\nProject-owned content for %s.\n' "$1" "$1" "$1"; }
for n in ${OWN_AGENTS_SKILLS:-}; do mkdir -p ".agents/skills/$n/scripts"; body "$n" > ".agents/skills/$n/SKILL.md"; printf 'echo own\n' > ".agents/skills/$n/scripts/own.sh"; done
for n in ${OWN_CLAUDE_SKILLS:-}; do mkdir -p ".claude/skills/$n"; body "$n" > ".claude/skills/$n/SKILL.md"; done
for n in ${OWN_CLAUDE_LINKS:-}; do mkdir -p "shared-skills/$n"; body "$n" > "shared-skills/$n/SKILL.md"; ln -s "../../shared-skills/$n" ".claude/skills/$n"; done

if [ -n "${GIT:-}" ]; then
  git init -q . && git add -A && git -c user.name=t -c user.email=t@example.com commit -q -m init
fi
echo "project: $D"
