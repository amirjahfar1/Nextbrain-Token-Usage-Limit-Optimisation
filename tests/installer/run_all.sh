#!/bin/bash
# Regression suite for the token-optimisation installer. Each scenario asserts the SAFE behaviour.
# Usage: bash run_all.sh [scenario-id ...]     REPO=<path to the repo> overrides the source (default: the real repo).
# Works in its own scratch folder outside the repo (WORK=<dir> to choose it; default $TMPDIR/tokopt-suite); HOME / CLAUDE_CONFIG_DIR / TMPDIR are redirected there; mods always off
# (the one mods scenario uses a fake `claude` binary).
S=$(cd "$(dirname "$0")" && pwd)
REPO=${REPO:-$(cd "$S/../.." && pwd)}
K=${WORK:-${TMPDIR:-/tmp}/tokopt-suite}; W=$K/w; L=$K/logs; LIB=$S/lib
REALPATH=$PATH
rm -rf "$W" "$L" "$K/home" "$K/cfg" "$K/tmp"; mkdir -p "$W" "$L" "$K/home" "$K/cfg" "$K/tmp"
export HOME="$K/home" CLAUDE_CONFIG_DIR="$K/cfg" TMPDIR="$K/tmp" NEXTBRAIN_NO_MODS=1
R="$W/repo copy"                      # path with a space on purpose
rsync -a --exclude token-saving-mods --exclude __pycache__ "$REPO/" "$R/"
pass=0; fail=0; failed=""

fresh() { n=$1; shift; env "$@" sh "$S/make_project.sh" "$W/$n" >/dev/null || echo "GENERATOR FAILED"; rm -rf "$W/$n.orig"; cp -RP "$W/$n" "$W/$n.orig"; P="$W/$n"; O="$W/$n.orig"; }
inst() { sh "$R/install.sh" --no-mods "$@"; }
tdiff() { python3 "$LIB/treediff.py" "$@"; }
hook() { # hook <project> <script> : run the installed hook command exactly as Claude Code would (stdin = hook JSON)
  c=$(python3 "$LIB/hookcmd.py" "$1/.claude/settings.json" "$2") || { echo "no hook command for $2"; return 99; }
  ( cd "$1" && CLAUDE_PROJECT_DIR="$1" sh -c "$c" ); }
rd() { # rd <cwd> <file_path> [extra json fields for tool_input]
  python3 -c 'import json,sys; ti={"file_path":sys.argv[2]}; ti.update(json.loads(sys.argv[3] if len(sys.argv)>3 else "{}")); print(json.dumps({"session_id":"s","transcript_path":"/x","cwd":sys.argv[1],"hook_event_name":"PreToolUse","tool_name":"Read","tool_input":ti}))' "$@"; }
ok() { echo "    ok: $*"; }
no() { echo "    FAIL: $*"; rc=1; }
run() { id=$1; shift; desc=$*
  if [ -n "$ONLY" ] && ! printf ' %s ' "$ONLY" | grep -q " $id "; then return; fi
  rc=0; "t_$id" > "$L/$id.log" 2>&1
  if [ "$rc" = 0 ]; then pass=$((pass + 1)); echo "PASS  $id  $desc"; else fail=$((fail + 1)); failed="$failed $id"; echo "FAIL  $id  $desc"; grep 'FAIL:' "$L/$id.log" | head -4; fi; }
ONLY="$*"

# ---------- 1/2/3: big project, settings merge, modes ----------
t_A01() { fresh a01; inst --dry-run "$P" > "$W/a01.out"; tdiff "$O" "$P" && ok "dry-run wrote nothing" || no "dry-run changed the tree"
  n=$(wc -c < "$W/a01.out"); [ "$n" -le 4000 ] && ok "dry-run output $n bytes" || no "dry-run output is $n bytes (~$((n / 4)) tokens) for a token-saving tool"
  for w in .gitignore token-optimisation.conf backups; do grep -q "$w" "$W/a01.out" || no "dry-run does not disclose the write to $w"; done; }
t_A02() { fresh a02; inst "$P" || no "install exit $?"
  python3 "$LIB/settings_check.py" "$O/.claude/settings.json" "$P/.claude/settings.json" || no "settings merge lost or changed something"
  tdiff "$O" "$P" .claude/token-optimisation .agents/skills/token-optimisation .agents/skills/tips .agents/skills/token-audit .agents/skills/handoff | grep -v -e 'ADDED   .claude/skills/\(token-optimisation\|tips\|token-audit\|handoff\)$' -e 'ADDED   .agents/token-optimisation.conf' -e 'CHANGED AGENTS.md' -e 'CHANGED .gitignore' -e 'CHANGED .claude/settings.json' > "$W/a02.d"
  [ -s "$W/a02.d" ] && { cat "$W/a02.d"; no "install touched unexpected paths"; } || ok "only documented paths touched"
  head -c "$(wc -c < "$O/AGENTS.md")" "$P/AGENTS.md" | cmp -s - "$O/AGENTS.md" && ok "AGENTS.md original text intact, block appended" || no "AGENTS.md original text altered"
  cmp -s "$O/CLAUDE.md" "$P/CLAUDE.md" && ok "CLAUDE.md untouched" || no "CLAUDE.md changed"
  inst --check "$P" >/dev/null || no "--check fails right after install"; }
t_A03() { fresh a03 LITE=1; inst "$P" >/dev/null; cp "$P/AGENTS.md" "$W/a03.A1"; cp "$P/.claude/settings.json" "$W/a03.S1"
  inst --update "$P" >/dev/null; inst --update "$P" >/dev/null
  cmp -s "$W/a03.A1" "$P/AGENTS.md" && ok "AGENTS.md stable over 2 updates" || no "AGENTS.md changes on every --update (grows $(($(wc -l < "$P/AGENTS.md") - $(wc -l < "$W/a03.A1"))) lines in 2 updates)"
  cmp -s "$W/a03.S1" "$P/.claude/settings.json" && ok "settings stable" || no "settings changed on update"
  [ "$(grep -c 'TOKEN-OPTIMISATION:BEGIN' "$P/AGENTS.md")" = 1 ] || no "block duplicated"
  [ "$(grep -c 'token-optimisation' "$P/.gitignore")" = 2 ] || no ".gitignore lines duplicated"
  python3 "$LIB/settings_check.py" "$O/.claude/settings.json" "$P/.claude/settings.json" || no "duplicates after updates"; }
t_A04() { fresh a04; inst "$P" >/dev/null; inst --update "$P" >/dev/null; inst --uninstall "$P" >/dev/null || no "uninstall exit $?"
  tdiff "$O" "$P" .claude/token-optimisation .gitignore > "$W/a04.d"; [ -s "$W/a04.d" ] && { cat "$W/a04.d"; no "tree not identical to the original after uninstall ($(wc -l < "$W/a04.d" | tr -d ' ') paths differ)"; } || ok "tree identical after uninstall"; }
t_A05() { fresh a05 LITE=1 SETTINGS=overlap; inst "$P" >/dev/null; inst --uninstall "$P" >/dev/null
  for r in 'Read(**/package-lock.json)' 'Read(**/*.min.js)'; do grep -qF "$r" "$P/.claude/settings.json" && ok "kept the project's own deny $r" || no "uninstall deleted the project's OWN pre-existing deny rule $r"; done; }
t_A06() { fresh a06 LITE=1; inst "$P" >/dev/null   # owner later merges our guard into their own Read group
  python3 - "$P/.claude/settings.json" <<'PY'
import json, sys
p = sys.argv[1]; s = json.load(open(p)); pre = s["hooks"]["PreToolUse"]
ours = [g for g in pre if "token-optimisation" in json.dumps(g)][0]; pre.remove(ours)
pre[1]["hooks"].append(ours["hooks"][0]); json.dump(s, open(p, "w"), indent=2)
PY
  inst --uninstall "$P" >/dev/null
  grep -q own_read_guard.py "$P/.claude/settings.json" && ok "own hook kept" || no "uninstall deleted the project's own hook own_read_guard.py (whole matcher group removed)"; }
t_A07() { for v in invalid empty bom trailing nullperm; do fresh "a07$v" LITE=1 SETTINGS=$v; inst "$P" >/dev/null 2>&1; e=$?
    cmp -s "$O/.claude/settings.json" "$P/.claude/settings.json" && ok "$v: settings.json untouched" || { [ $v = nullperm ] || no "$v: settings.json modified"; }
    if [ $e != 0 ]; then tdiff "$O" "$P" >/dev/null && ok "$v: aborted cleanly, nothing written" || no "$v settings.json: install aborts (exit $e) AFTER writing $(tdiff "$O" "$P" | wc -l | tr -d ' ') paths (half install, block in AGENTS.md, no hooks)"; fi
  done; }
t_A08() { fresh a08 LITE=1 SETTINGS=none; inst --uninstall "$P" >/dev/null 2>&1
  [ -e "$P/.claude/settings.json" ] && no "uninstall on a project without settings.json CREATED one: $(tr -d '\n' < "$P/.claude/settings.json")" || ok "no settings.json created"
  fresh a08b LITE=1 SETTINGS=none ENTRY=none; inst "$P" >/dev/null; inst --uninstall "$P" >/dev/null
  tdiff "$O" "$P" .claude/token-optimisation .gitignore > "$W/a08.d" && ok "install+uninstall leaves nothing" || { cat "$W/a08.d"; no "install+uninstall on an empty project leaves $(wc -l < "$W/a08.d" | tr -d ' ') stray paths"; }; }
t_A09() { fresh a09 LITE=1; inst --hooks=none "$P" >/dev/null; inst --update "$P" >/dev/null
  grep -q 'token-optimisation/hooks' "$P/.claude/settings.json" && no "--update silently added hooks the owner declined with --hooks=none" || ok "hook choice remembered"
  fresh a09b LITE=1; inst --hooks=bogus "$P" >/dev/null 2>&1; tdiff "$O" "$P" >/dev/null && ok "bad --hooks rejected before writing" || no "bad --hooks value rejected only after files and block were written"; }
t_A10() { fresh a10 LITE=1; inst --check "$P" >/dev/null 2>&1; [ $? = 1 ] && ok "check: not installed -> 1" || no "check exit on not-installed"
  tdiff "$O" "$P" >/dev/null || no "--check wrote into a not-installed project"
  inst "$P" >/dev/null; inst --check "$P" >/dev/null 2>&1 && ok "check ok -> 0" || no "check after install"
  python3 -B "$R/installer/block.py" "$P" remove >/dev/null; inst --check "$P" >/dev/null 2>&1; [ $? = 1 ] && ok "check: block missing -> 1" || no "check does not flag a missing block"
  inst --update "$P" >/dev/null; rm "$P/.agents/skills/token-optimisation/rules/core.md"; inst --check "$P" >/dev/null 2>&1; [ $? = 1 ] && ok "check: missing file -> 1" || no "missing file not flagged"
  inst --update "$P" >/dev/null; [ -f "$P/.agents/skills/token-optimisation/rules/core.md" ] && ok "update restores a deleted managed file" || no "deleted file not restored"; }
t_A11() { fresh a11 LITE=1; inst "$P" >/dev/null; f="$P/.agents/skills/token-optimisation/rules/core.md"; echo "- PROJECT LOCAL EDIT" >> "$f"
  inst --update "$P" | grep -q 'kept locally edited: token-optimisation/rules/core.md' && ok "1st update keeps the edit" || no "1st update did not keep the edit"
  inst --update "$P" >/dev/null; grep -q 'PROJECT LOCAL EDIT' "$f" && ok "2nd update keeps the edit" || no "2nd --update silently overwrote the locally edited file (manifest was re-hashed)"; }
t_A12() { fresh a12 LITE=1; echo "my own notes" > "$W/a12.keep"; inst "$P" >/dev/null; mkdir -p "$P/.agents/skills/token-optimisation/rules"; cp "$W/a12.keep" "$P/.agents/skills/token-optimisation/rules/project-own.md"
  inst --uninstall "$P" >/dev/null; ls "$P/.claude/token-optimisation/backups"/*/ 2>/dev/null | grep -q project-own.md && ok "project-added file backed up" || { [ -f "$P/.agents/skills/token-optimisation/rules/project-own.md" ] && ok kept || no "uninstall rm -rf'd a file the project added inside the skill folder, no backup"; }; }
# ---------- block handling ----------
t_B01() { fresh b01 LITE=1; printf '\n## Docs\nOur installer marker is `<!-- TOKEN-OPTIMISATION:BEGIN -->` (see wiki).\n\n## Deploy rules\n- NEVER deploy on Friday.\n- Rotate keys monthly.\n' >> "$P/AGENTS.md"; cp "$P/AGENTS.md" "$W/b01.before"
  inst "$P" >/dev/null; grep -q 'NEVER deploy on Friday' "$P/AGENTS.md" && ok "rules kept" || no "AGENTS.md merely QUOTES the BEGIN marker: install DELETED every project rule after that line ($(grep -c . "$W/b01.before") non-empty lines before, $(sed '/TOKEN-OPTIMISATION:BEGIN -->$/,$d' "$P/AGENTS.md" | grep -c .) left)"; }
t_B02() { fresh b02 LITE=1; inst "$P" >/dev/null; printf '\n## Added later by the owner\n- keep me\n' >> "$P/AGENTS.md"
  sed -i.bak '/TOKEN-OPTIMISATION:END/d' "$P/AGENTS.md"; rm -f "$P/AGENTS.md.bak"       # END marker lost in a hand edit / merge conflict
  inst --update "$P" >/dev/null; grep -q 'keep me' "$P/AGENTS.md" && ok "kept" || no "END marker missing: --update deleted the owner's later rules"
  fresh b02b LITE=1; inst "$P" >/dev/null; printf '\n## Added later by the owner\n- keep me\n' >> "$P/AGENTS.md"; sed -i.bak '/TOKEN-OPTIMISATION:END/d' "$P/AGENTS.md"; rm -f "$P/AGENTS.md.bak"
  inst --uninstall "$P" >/dev/null; grep -q 'keep me' "$P/AGENTS.md" && ok "kept" || no "END marker missing: --uninstall deleted the owner's later rules"; }
t_B03() { for v in crlf nonl; do fresh "b03$v" LITE=1 ENTRY=$v; inst "$P" >/dev/null; inst --uninstall "$P" >/dev/null
    cmp -s "$O/AGENTS.md" "$P/AGENTS.md" && ok "$v AGENTS.md byte-identical after uninstall" || no "$v AGENTS.md not byte-identical after install+uninstall"; done
  fresh b03c LITE=1 ENTRY=crlf; inst "$P" >/dev/null; n=$(grep -c "$(printf '\r')" "$P/AGENTS.md"); t=$(wc -l < "$P/AGENTS.md" | tr -d ' ')
  [ "$n" = "$t" ] || [ "$n" = 0 ] && ok "consistent line endings" || no "CRLF file gets LF block: mixed line endings ($n of $t lines CRLF)"; }
t_B04() { fresh b04 LITE=1; inst "$P" >/dev/null; python3 - "$P/AGENTS.md" <<'PY'
import sys, re
p = sys.argv[1]; t = open(p).read(); m = re.search(r"<!-- TOKEN-OPTIMISATION:BEGIN -->.*<!-- TOKEN-OPTIMISATION:END -->\n", t, re.S)
open(p, "w").write(m.group(0) + t.replace(m.group(0), ""))     # owner moved the block to the top
PY
  cp "$P/AGENTS.md" "$W/b04.A"; inst --update "$P" >/dev/null; cmp -s "$W/b04.A" "$P/AGENTS.md" && ok "position kept" || no "--update moved the block the owner had repositioned (reorders AGENTS.md)"; }
t_B05() { fresh b05 LITE=1; inst "$P" >/dev/null; sed -i.bak 's/^- No recaps.*/- No recaps. OWNER EDIT inside block/' "$P/AGENTS.md"; rm -f "$P/AGENTS.md.bak"
  inst --update "$P" > "$W/b05.out"; grep -q 'OWNER EDIT' "$P/AGENTS.md" || grep -qi 'block.*edited' "$W/b05.out" || ls "$P/.claude/token-optimisation/backups"/*/AGENTS.md >/dev/null 2>&1 && ok "edited block overwritten but a backup exists" || no "edited block overwritten without notice or backup"
  fresh b05b LITE=1; inst "$P" >/dev/null; rm "$P/AGENTS.md"; inst --uninstall "$P" >/dev/null 2>&1 && ok "uninstall with AGENTS.md deleted: exit 0" || no "uninstall fails when AGENTS.md was deleted"
  [ -e "$P/AGENTS.md" ] && no "uninstall re-created AGENTS.md" || ok "AGENTS.md not re-created"
  grep -q TOKEN-OPTIMISATION "$P/CLAUDE.md" && no "touched CLAUDE.md" || ok "CLAUDE.md clean"; }
# ---------- skills / collisions ----------
t_C01() { fresh c01 LITE=1 OWN_AGENTS_SKILLS="token-optimisation"; inst "$P" > "$W/c01.out" 2>&1
  tdiff "$O/.agents/skills/token-optimisation" "$P/.agents/skills/token-optimisation" > "$W/c01.d" && ok "own skill folder untouched" || no "wrote $(tr '\n' ' ' < "$W/c01.d") into the project's OWN unmanaged token-optimisation skill"
  if grep -q 'token-optimisation/hooks/guard_read.py' "$P/.claude/settings.json" 2>/dev/null; then rd "$P" "$P/AGENTS.md" | hook "$P" guard_read.py >/dev/null 2>&1; e=$?
    [ $e = 2 ] && no "hooks installed that point at a script that was never copied: hook exits 2 = Claude Code BLOCKS EVERY Read in this project" || ok "hook exit $e"; fi; }
t_C02() { fresh c02 LITE=1 OWN_AGENTS_SKILLS="handoff"; inst "$P" > "$W/c02.out" 2>&1; e=$?
  [ $e = 0 ] && ok "exit 0" || no "project has its own 'handoff' skill: install dies silently with exit $e (no error text)"
  grep -q TOKEN-OPTIMISATION:BEGIN "$P/AGENTS.md" && grep -q guard_read "$P/.claude/settings.json" && ok "complete" || no "half install left behind: skills + manifest written, but no block, no hooks, no conf"
  tdiff "$O/.agents/skills/handoff" "$P/.agents/skills/handoff" >/dev/null && ok "own handoff untouched" || no "own handoff skill modified"
  sh "$R/installer/auto.sh" "$R" "$P" 2>&1 | grep -q 'already current' && { grep -q TOKEN-OPTIMISATION:BEGIN "$P/AGENTS.md" && ok "auto says current only because the install is complete" || no "auto reports a half install as current"; } || ok "auto not fooled"; }
t_C03() { fresh c03 LITE=1 OWN_CLAUDE_LINKS="tips handoff" OWN_AGENTS_SKILLS="token-audit" OWN_CLAUDE_SKILLS="token-audit"; inst "$P" >/dev/null 2>&1; inst --uninstall "$P" > "$W/c03.out" 2>&1 || no "uninstall exit $?"
  for n in tips handoff; do [ -L "$P/.claude/skills/$n" ] && ok "own symlink $n kept" || no "uninstall DELETED the project's own skill symlink .claude/skills/$n"; done
  tdiff "$O/shared-skills" "$P/shared-skills" >/dev/null || no "shared-skills changed"; tdiff "$O/.agents/skills/token-audit" "$P/.agents/skills/token-audit" >/dev/null && ok "unmanaged token-audit untouched" || no "unmanaged token-audit modified"; }
t_C04() { fresh c04 LITE=1 OWN_CLAUDE_SKILLS="tips"; inst "$P" >/dev/null 2>&1; inst --uninstall "$P" > "$W/c04.out" 2>&1; e=$?
  [ $e = 0 ] && ok "uninstall exit 0" || no "project has its own .claude/skills/tips folder: uninstall aborts half-way (exit $e: $(tail -1 "$W/c04.out"))"
  ls -d "$P/.agents/skills/handoff" "$P/.agents/skills/token-audit" >/dev/null 2>&1 && no "our token-audit and handoff skills left installed after the aborted uninstall" || ok "all ours removed"
  tdiff "$O/.claude/skills/tips" "$P/.claude/skills/tips" >/dev/null && ok "own tips kept" || no "own tips changed"; }
t_C05() { fresh c05 LITE=1; rmdir "$P/.agents/skills" 2>/dev/null; rm -rf "$P/.agents"; rm -rf "$P/.claude/skills"; mkdir -p "$P/.agents/skills/mine"; echo x > "$P/.agents/skills/mine/SKILL.md"; ln -s ../.agents/skills "$P/.claude/skills"; rm -rf "$O"; cp -RP "$P" "$O"
  inst "$P" >/dev/null 2>&1 || no "install exit $?"; [ -L "$P/.claude/skills" ] && ok ".claude/skills symlink kept" || no ".claude/skills symlink replaced"
  inst --uninstall "$P" >/dev/null 2>&1; [ -f "$P/.agents/skills/mine/SKILL.md" ] && [ -L "$P/.claude/skills" ] && ok "own skill + symlink survive" || no "symlinked skills dir damaged"; }
t_C06() { fresh c06 LITE=1 GIT=1; inst "$P" >/dev/null; (cd "$P" && git add -A && git -c user.name=t -c user.email=t@e.com commit -qm tok); H="$P/.agents/skills/token-optimisation/hooks"
  # Apple's python3 redirects bytecode to ~/Library/Caches; Homebrew/Linux python3 write hooks/__pycache__/_common.*.pyc on the first hook run. Simulate that:
  (cd "$H" && python3 -c 'import py_compile; py_compile.compile("_common.py", cfile="__pycache__/_common.cpython-312.pyc")')
  if grep -q -e 'python3 -B' "$P/.claude/settings.json" || grep -q dont_write_bytecode "$H/guard_read.py" || (cd "$P" && git check-ignore -q "$H/__pycache__/_common.cpython-312.pyc"); then ok "bytecode suppressed or ignored"
  else no "hooks import _common without -B: on Homebrew/Linux python every project gets untracked .agents/skills/token-optimisation/hooks/__pycache__/ (not in the .gitignore the installer writes)"; fi
  inst --update "$P" >/dev/null; grep -q __pycache__ "$P/.agents/skills/token-optimisation/.manifest" && no "manifest then tracks __pycache__/*.pyc as a managed file"
  find "$P/.agents" -name __pycache__ -exec rm -rf {} + ; inst --check "$P" > "$W/c06.out" 2>&1 && ok "check ok after pycache cleanup" || no "--check exits 1 after 'git clean' removed the .pyc: $(grep missing "$W/c06.out" | head -1)"; }
# ---------- entry file ----------
t_D01() { fresh d01 LITE=1 ENTRY=symlink; inst "$P" >/dev/null; [ -L "$P/CLAUDE.md" ] && [ "$(grep -c BEGIN "$P/AGENTS.md")" = 1 ] && ok "symlinked CLAUDE.md kept, one block" || no "symlink entry broken"
  inst --uninstall "$P" >/dev/null; [ -L "$P/CLAUDE.md" ] || no "symlink lost on uninstall"
  fresh d01b LITE=1 ENTRY=claude; inst "$P" >/dev/null; grep -q BEGIN "$P/CLAUDE.md" && [ ! -e "$P/AGENTS.md" ] && ok "CLAUDE.md-only project: block in CLAUDE.md, no AGENTS.md created" || no "CLAUDE.md-only project mishandled"; }
t_D02() { fresh d02 LITE=1 ENTRY=separate; inst "$P" >/dev/null   # both files, CLAUDE.md does NOT import AGENTS.md
  grep -q -e TOKEN-OPTIMISATION -e '@AGENTS.md' "$P/CLAUDE.md" && ok "Claude Code can see the block" || no "block only in AGENTS.md; CLAUDE.md does not import it, so Claude Code never loads the block (install reports success)"
  fresh d02b LITE=1 ENTRY=none SETTINGS=none; inst "$P" >/dev/null; [ -f "$P/CLAUDE.md" ] && ok "CLAUDE.md present" || no "no entry file: only AGENTS.md is created, Claude Code does not read it"; }
t_D03() { fresh d03 LITE=1 ENTRY=claude; inst "$P" >/dev/null; printf '# Codex rules added later\n' > "$P/AGENTS.md"; inst --update "$P" >/dev/null
  n=$(cat "$P/AGENTS.md" "$P/CLAUDE.md" | grep -c TOKEN-OPTIMISATION:BEGIN); [ "$n" = 1 ] && ok "one block" || no "AGENTS.md appeared after install: --update put a 2nd block there ($n blocks now, always-on text duplicated)"
  inst --uninstall "$P" >/dev/null; grep -q TOKEN-OPTIMISATION "$P/CLAUDE.md" && no "--uninstall left the block in CLAUDE.md" || ok "all blocks removed"; }
t_D04() { fresh d04 LITE=1 GIT=1; mkdir -p "$P/packages/web"; echo 'export {}' > "$P/packages/web/index.ts"; rm -rf "$O"; cp -RP "$P" "$O"
  (cd "$P/packages/web" && sh "$R/install.sh" --no-mods --auto . ) > "$W/d04.out" 2>&1
  tdiff "$O" "$P" > "$W/d04.d" && ok "auto from a subfolder did not install" || no "--auto run from a subfolder of a project WITH its own rules installed without approval ($(wc -l < "$W/d04.d" | tr -d ' ') paths written under packages/web; has_own only looks at the given folder)"; }
t_D05() { fresh "d05 with space" LITE=1; (cd "$W" && sh "$R/install.sh" --no-mods "./d05 with space") > "$W/d05.out" 2>&1 || no "relative path with spaces: install failed"
  inst --check "$P" >/dev/null 2>&1 || no "check failed"; rd "$P" "$P/AGENTS.md" | hook "$P" guard_read.py; [ $? = 0 ] && ok "hook runs from a path with spaces" || no "hook broken in a path with spaces"
  nx=$(grep -o 'Next: .*' "$W/d05.out" | sed 's/^Next: //'); ( eval "$nx" ) >/dev/null 2>&1 && ok "'Next:' command is runnable" || no "the printed 'Next:' command is unquoted and fails when a path has spaces (the repo path itself has spaces)"; }
t_D06() { rm -rf "$W/repo2" "$W/repo2link"; cp -R "$R" "$W/repo2"; ln -s repo2 "$W/repo2link"
  sh "$W/repo2/install.sh" --no-mods "$W/repo2" >/dev/null 2>&1; [ $? = 2 ] && ok "repo==project refused" || no "repo guard broken"
  sh "$W/repo2/install.sh" --no-mods "$W/repo2link" >/dev/null 2>&1; [ $? = 2 ] && ok "refused via symlink" || no "project==repo guard bypassed through a symlinked path: installed into the source repo itself"; }
t_D07() { rm -rf "$W/fakehome"; mkdir -p "$W/fakehome/.claude"; (HOME="$W/fakehome"; export HOME; cd "$HOME" && sh "$R/install.sh" --no-mods --auto . ) > "$W/d07.out" 2>&1
  if grep -q guard_read "$W/fakehome/.claude/settings.json" 2>/dev/null; then no "--auto run from \$HOME installed project hooks into the USER-GLOBAL ~/.claude/settings.json"
    fresh d07p LITE=1 SETTINGS=none; c=$(python3 "$LIB/hookcmd.py" "$W/fakehome/.claude/settings.json" guard_read.py); rd "$P" "$P/AGENTS.md" | (CLAUDE_PROJECT_DIR="$P" sh -c "$c") >/dev/null 2>&1
    [ $? = 2 ] && no "...and that global hook exits 2 in every other project = all Reads blocked machine-wide"; else ok "home refused"; fi; }
# ---------- hooks at runtime ----------
t_E01() { fresh e01; inst "$P" >/dev/null; mkdir -p "$W/outside"; echo small > "$W/outside/small.txt"; bad=0
  for mode in off log deny; do printf 'guard_mode=%s\nranged=\n' $mode > "$P/.agents/token-optimisation.conf"
    chk() { # chk <label> <want: allow|deny|any> ; stdin = hook json
      out=$(hook "$P" guard_read.py 2>"$W/e01.err"); e=$?; [ $e = 0 ] || { no "$mode/$1: exit $e"; return; }
      [ -s "$W/e01.err" ] && no "$mode/$1: stderr noise: $(head -1 "$W/e01.err")"
      [ -z "$out" ] || printf '%s' "$out" | python3 -c 'import json,sys; json.load(sys.stdin)' 2>/dev/null || { no "$mode/$1: stdout is not JSON"; return; }
      got=allow; printf '%s' "$out" | grep -q '"deny"' && got=deny
      [ "$2" = any ] || [ "$2" = "$got" ] || no "$mode/$1: wanted $2 got $got"; }
    d=allow; [ $mode = deny ] && d=deny
    rd "$P" "$P/src/mod1/file1.ts" | chk small-full allow
    rd "$P" "$P/src/mod1/file1.ts" '{"offset":1,"limit":20}' | chk small-ranged allow
    rd "$P" "$P/src/big-source.ts" | chk big-full $d
    rd "$P" "$P/src/big-source.ts" '{"offset":1,"limit":100}' | chk big-ranged allow
    rd "$P" "$P/package-lock.json" | chk lock-full $d
    rd "$P" "$P/docs/café ✓ résumé.md" | chk unicode allow
    rd "$P" "$P/docs/my notes/a file with spaces.md" | chk spaces allow
    rd "$P" "$W/outside/small.txt" | chk outside-small allow
    rd "$P" "$P/does/not/exist.ts" | chk missing allow
    rd "$P" "src/mod1/file1.ts" | chk relative allow
    printf '{"tool_input": "oops"' | chk malformed allow
    printf '' | chk empty allow
    printf '[]' | chk array allow
    printf 'null' | chk null allow
    printf '{"tool_input":"str","cwd":5}' | chk wrongtypes allow
    printf '\377\376\000' | chk binary allow
    printf '{"tool_name":"Edit","cwd":"%s","tool_input":{"file_path":"%s/src/big-source.ts","old_string":"a","new_string":"b"}}' "$P" "$P" | chk edit-payload any
  done; [ $rc = 0 ] && ok "guard never crashed in off/log/deny over 17 payloads"; }
t_E02() { fresh e02 LITE=1; inst "$P" >/dev/null; printf 'guard_mode=deny\n' > "$P/.agents/token-optimisation.conf"; mkdir -p "$P/src/dist"; echo 'export const h = 1;' > "$P/src/dist/handler.ts"
  rd "$P" "$P/src/dist/handler.ts" '{"offset":1,"limit":50}' | hook "$P" guard_read.py | grep -q '"deny"' && no "deny mode: a 20-byte source file under any folder named dist/ is denied even WITH a range; Edit needs a prior Read, so the agent cannot edit it with the Edit tool" || ok "small dist source readable"
  mkdir -p "$W/other/dist"; echo x > "$W/other/dist/readme.txt"
  rd "$P" "$W/other/dist/readme.txt" | hook "$P" guard_read.py | grep -q '"deny"' && no "deny mode also blocks files OUTSIDE the project that sit under a dist/ folder" || ok "outside dist ok"; }
t_E03() { fresh e03 LITE=1; inst "$P" >/dev/null; printf 'guard_mode=off\n' > "$P/.agents/token-optimisation.conf"; mkdir -p "$P/packages/web"; yes x | head -c 90000 > "$P/packages/web/big.ts"
  rd "$P/packages/web" "$P/packages/web/big.ts" | hook "$P" guard_read.py >/dev/null
  [ -e "$P/packages/web/.claude" ] && no "session cwd is a subfolder: guard ignores the project's guard_mode=off (conf looked up in cwd, not \$CLAUDE_PROJECT_DIR) and creates packages/web/.claude/token-optimisation/guard.log" || ok "project conf honoured from a subfolder"
  printf 'guard_mode=deny\n' > "$P/.agents/token-optimisation.conf"
  rd "$P/packages/web" "$P/packages/web/big.ts" | hook "$P" guard_read.py | grep -q '"deny"' && ok "deny honoured from a subfolder" || no "guard_mode=deny is NOT enforced once the session cwd is a subfolder"; }
t_E04() { fresh e04 LITE=1; inst "$P" >/dev/null; rm -rf "$P/.agents/skills/token-optimisation"     # skill folder gone (branch switch, sparse checkout, .agents git-ignored, manual delete) but settings.json still lists the hooks
  rd "$P" "$P/AGENTS.md" | hook "$P" guard_read.py >/dev/null 2>&1; e=$?; [ $e = 2 ] && no "hook script missing -> python3 exits 2 -> Claude Code treats it as a BLOCKING error: every Read is refused" || ok "missing script fails open (exit $e)"
  echo '{}' | hook "$P" session_start.py >/dev/null 2>&1; e=$?; [ $e = 0 ] && ok "session_start fails open" || no "SessionStart hook errors (exit $e) on every session when the script is missing"; }
t_E05() { fresh e05 LITE=1; inst "$P" >/dev/null; sd="$P/.claude/token-optimisation"
  for i in '' '{}' 'garbage' '{"source":"resume","prompt_cache_likely_expired":true,"cwd":"'"$P"'"}'; do printf '%s' "$i" | hook "$P" session_start.py >/dev/null 2>"$W/e05.err"; [ $? = 0 ] && [ ! -s "$W/e05.err" ] || no "session_start crashed on [$i]"; done
  mkdir -p "$sd"; echo flagged > "$sd/pending-review"; printf '{"cwd":"%s"}' "$P" | hook "$P" session_start.py | grep -q 'flagged expensive' && ok "pending review announced" || no "pending review not announced"
  n=0; while [ $n -lt 3 ]; do printf '{"cwd":"%s"}' "$P" | hook "$P" session_start.py >/dev/null; n=$((n + 1)); done; [ -e "$sd/pending-review" ] && no "pending-review is never cleared: the same 'flagged expensive' line is injected into EVERY later session" || ok "pending cleared"
  python3 - "$W/e05.jsonl" <<'PY'
import json, sys
with open(sys.argv[1], "w") as f:
    f.write("not json\n"); f.write(json.dumps({"type": "user", "message": {"role": "user", "content": "hi"}}) + "\n")
    for i in range(3):
        f.write(json.dumps({"type": "assistant", "uuid": "u%d" % i, "message": {"id": "m%d" % i, "model": "claude-x", "usage": {"input_tokens": 10, "cache_read_input_tokens": 5000, "output_tokens": 50}, "content": [{"type": "tool_use", "id": "t%d" % i, "name": "Read", "input": {"file_path": "/a/b.ts"}}]}}) + "\n")
        f.write(json.dumps({"type": "user", "message": {"role": "user", "content": [{"type": "tool_result", "tool_use_id": "t%d" % i, "content": "x" * 5000}]}}) + "\n")
PY
  for tp in "$W/e05.jsonl" /nonexistent/t.jsonl ''; do printf '{"cwd":"%s","transcript_path":"%s"}' "$P" "$tp" | hook "$P" session_end.py > "$W/e05.out" 2>&1; [ $? = 0 ] && [ ! -s "$W/e05.out" ] || no "session_end noisy/crashed for transcript [$tp]"; done
  [ -s "$sd/sessions.tsv" ] && ok "session recorded" || no "session not recorded"
  for i in '' 'garbage' '[]'; do printf '%s' "$i" | hook "$P" session_end.py >/dev/null 2>&1 || no "session_end crashed on [$i]"; done; }
# ---------- auto.sh ----------
t_F01() { fresh f01 LITE=1; sh "$R/install.sh" --no-mods --auto "$P" > "$W/f01.out" 2>&1; tdiff "$O" "$P" >/dev/null && grep -q 'NOT installing' "$W/f01.out" && ok "auto: project with own rules -> dry run only" || no "auto wrote into a project with its own rules"
  fresh f01b LITE=1 ENTRY=none SETTINGS=none; rm -rf "$P/.agents" "$P/.claude"; sh "$R/install.sh" --no-mods --auto "$P" > "$W/f01b.out" 2>&1; grep -q 'check: all ok' "$W/f01b.out" && ok "auto: empty project -> install + check" || no "auto failed on a brand-new project"
  sh "$R/install.sh" --no-mods --auto "$P" 2>&1 | grep -q 'already current' && ok "auto: second run = check only" || no "auto second run not idempotent"; }
t_F02() { for v in dotclaude localonly mcponly cursor emptyagents; do fresh "f02$v" LITE=1 ENTRY=none SETTINGS=none; rm -rf "$P/.agents" "$P/.claude"; mkdir -p "$P/.claude" "$P/src"; echo 'x' > "$P/src/a.ts"
    case $v in dotclaude) printf '# Project rules\n- never deploy on Friday\n' > "$P/.claude/CLAUDE.md"; mkdir -p "$P/.claude/commands" "$P/.claude/agents"; echo d > "$P/.claude/commands/deploy.md" ;;
      localonly) printf '{"permissions":{"deny":["Read(.env)"]},"hooks":{"Stop":[{"hooks":[{"type":"command","command":"x"}]}]}}\n' > "$P/.claude/settings.local.json"; echo '# mine' > "$P/CLAUDE.local.md" ;;
      mcponly) echo '{"mcpServers":{}}' > "$P/.mcp.json"; mkdir -p "$P/.codex"; echo 'model="x"' > "$P/.codex/config.toml" ;;
      cursor) mkdir -p "$P/.cursor/rules" "$P/.github"; echo r > "$P/.cursor/rules/a.mdc"; echo c > "$P/.github/copilot-instructions.md"; echo g > "$P/GEMINI.md" ;;
      emptyagents) : > "$P/AGENTS.md"; : > "$P/.claude/settings.json" ;; esac
    rm -rf "$O"; cp -RP "$P" "$O"; sh "$R/install.sh" --no-mods --auto "$P" > "$W/f02$v.out" 2>&1
    tdiff "$O" "$P" >/dev/null && ok "$v: not auto-installed" || no "has_own() misses '$v': auto treats the project as brand-new and installs without the owner's approval"; done; }
t_F03() { rm -rf "$W/repo-old"; cp -R "$R" "$W/repo-old"; echo 0.9.0 > "$W/repo-old/VERSION"
  fresh f03u LITE=1 ENTRY=none SETTINGS=none; sh "$W/repo-old/install.sh" --no-mods "$P" >/dev/null; sh "$R/install.sh" --no-mods --auto "$P" > "$W/f03u.out" 2>&1
  [ "$(cat "$P/.agents/skills/token-optimisation/VERSION")" = "$(cat "$R/VERSION")" ] && grep -q 'check: all ok' "$W/f03u.out" && ok "auto updates an older install and checks" || no "auto did not update an older install"
  fresh f03 LITE=1 ENTRY=none SETTINGS=none; inst "$P" >/dev/null
  sh "$W/repo-old/install.sh" --no-mods --auto "$P" 2>&1 | grep -q 'not downgrading' && ok "auto refuses to downgrade" || no "auto downgraded"
  sh "$W/repo-old/install.sh" --no-mods --update "$P" >/dev/null 2>&1; [ "$(cat "$P/.agents/skills/token-optimisation/VERSION")" = 0.9.0 ] && no "--update from an older checkout silently DOWNGRADES 0.10.0 -> 0.9.0 (guard exists only in --auto)" || ok "--update refuses to downgrade"; }
t_F04() { fresh f04 LITE=1; rm -rf "$W/fakebin"; mkdir -p "$W/fakebin"; printf '#!/bin/sh\necho "$@" >> "%s/claude.calls"\ncase "$*" in *"marketplace list"*) echo "nextbrain-mods  Folder (/some/other/checkout/mods)";; *"marketplace add"*) exit 1;; esac\nexit 0\n' "$W" > "$W/fakebin/claude"; chmod +x "$W/fakebin/claude"; : > "$W/claude.calls"
  (unset NEXTBRAIN_NO_MODS; PATH="$W/fakebin:$PATH" sh "$R/install.sh" --auto "$P") > "$W/f04.out" 2>&1
  grep -q 'NOT installing' "$W/f04.out" || no "expected the dry-run branch"
  grep -q -e 'marketplace remove' -e 'plugin install' -e 'marketplace add' "$W/claude.calls" && no "auto's 'dry run only' branch still changes the user's GLOBAL Claude Code plugins: $(grep -c . "$W/claude.calls") claude CLI calls incl. '$(grep -m1 -e remove -e add "$W/claude.calls")'" || ok "no global change in dry-run branch"
  grep -q 'marketplace remove' "$W/claude.calls" && grep -q 'could not add' "$W/f04.out" && no "mods.sh removes the existing marketplace first, then add fails: user is left with NO marketplace (not atomic, no rollback)"; }
# ---------- environment ----------
mkbin() { rm -rf "$W/$1"; mkdir -p "$W/$1"; for c in sh cat date mkdir cp find grep cut sed awk mktemp rm ln touch dirname basename sort tail head wc tr tee ls env cmp xargs perl git printf pwd rmdir expr uname "$@"; do p=$(PATH=$REALPATH command -v "$c" 2>/dev/null) && [ -x "$p" ] && ln -sf "$p" "$W/$1/$c"; done; rm -f "$W/$1/$1"; }
t_G01() { fresh g01 LITE=1; mkbin bin-nopy shasum; rm -f "$W/bin-nopy/python3"
  env -i PATH="$W/bin-nopy" HOME="$HOME" TMPDIR="$TMPDIR" NEXTBRAIN_NO_MODS=1 sh "$R/install.sh" "$P" > "$W/g01.out" 2>&1; e=$?
  [ $e != 0 ] && ok "install fails without python3 (exit $e)" || no "install claims success without python3"
  tdiff "$O" "$P" >/dev/null && ok "nothing written" || no "no python3: install aborts AFTER writing skills + block ($(tdiff "$O" "$P" | wc -l | tr -d ' ') paths); no preflight check"
  ls "$TMPDIR" | grep -q . && no "temp files left behind in TMPDIR: $(ls "$TMPDIR" | head -3 | tr '\n' ' ')" || ok "no temp files left"; }
t_G02() { fresh g02 LITE=1; mkbin bin-nosha python3
  env -i PATH="$W/bin-nosha" HOME="$HOME" TMPDIR="$TMPDIR" NEXTBRAIN_NO_MODS=1 sh "$R/install.sh" "$P" > "$W/g02.out" 2>&1; e=$?
  if [ $e = 0 ]; then h=$(head -1 "$P/.agents/skills/token-optimisation/.manifest" | cut -d' ' -f1); [ ${#h} = 64 ] && ok "manifest has hashes" || no "no shasum (Linux ships sha256sum): install 'succeeds' with an EMPTY-hash manifest; then --check reports every file missing and --update can no longer detect local edits"
  else tdiff "$O" "$P" >/dev/null && ok "refused cleanly" || no "no shasum: half install"; fi; }
t_G03() { fresh g03 LITE=1 ENTRY=none SETTINGS=none; rm -rf "$P/.agents" "$P/.claude"
  if [ -x /bin/dash ]; then cp -R "$R" "$W/repo-dash"; for f in "$W/repo-dash/install.sh"; do sed -i.bak 's/sh "\$R/dash "$R/g' "$f"; done
    dash "$W/repo-dash/install.sh" --no-mods "$P" >/dev/null 2>&1 && dash "$W/repo-dash/install.sh" --no-mods --check "$P" >/dev/null 2>&1 && dash "$W/repo-dash/install.sh" --no-mods --uninstall "$P" >/dev/null 2>&1 && ok "works under dash" || no "fails under dash"
    for f in "$R"/install.sh "$R"/installer/*.sh "$R"/skill/scripts/*.sh "$R"/scripts/*.sh; do dash -n "$f" 2>/dev/null || no "dash syntax error in $f"; done; else ok "dash not available, skipped"; fi
  for f in "$R"/installer/*.py "$R"/skill/hooks/*.py "$R"/skill/scripts/*.py; do grep -nE ':=|^\s*match .*:$|removeprefix|removesuffix' "$f" >/dev/null && no "py>=3.8 syntax in $f"; done; ok "no walrus/match in python"; }
# ---------- performance ----------
t_H01() { fresh h01 BIG=1 GIT=1; s=$(python3 -c 'import time;print(time.time())')
  (cd "$P" && python3 "$R/skill/scripts/bigfile.py" scan) > "$W/h01.scan" 2>&1; t1=$(python3 -c "import time;print(round(time.time()-$s,2))")
  echo "scan: ${t1}s, $(wc -l < "$W/h01.scan" | tr -d ' ') rows"; python3 -c "import sys; sys.exit(0 if $t1 < 5 else 1)" && ok "scan under 5s" || no "scan took ${t1}s"
  grep -q 'huge-100mb' "$W/h01.scan" && ok "100 MB file listed" || no "100 MB file not listed"
  for f in 'café' '.github/workflows/big.yml'; do grep -q "$f" "$W/h01.scan" || { [ "$f" = café ] && true || no "scan silently skips $f (substring SKIP: any path containing '.git', 'dist' or '.claude', e.g. .github/, src/distributed/)"; }; done
  yes 'a long line for a big unicode doc' | head -c 90000 > "$P/docs/größe ✓.md"; (cd "$P" && git add -A && git -c user.name=t -c user.email=t@e.com commit -qm u && python3 "$R/skill/scripts/bigfile.py" scan) | grep -q 'größe' && ok "unicode file names scanned" || no "scan misses big files with non-ASCII names in a git repo (git ls-files quotes them; needs -z)"
  yes 'x' | head -c 90000 > "$P/untracked-generated.json"; (cd "$P" && python3 "$R/skill/scripts/bigfile.py" scan) | grep -q untracked-generated && ok "untracked big file seen" || no "scan only sees git-tracked files: big untracked/generated output is invisible"
  s=$(python3 -c 'import time;print(time.time())'); (cd "$P" && sh "$R/skill/scripts/check-size.sh" . ) > "$W/h01.size" 2>&1; t2=$(python3 -c "import time;print(round(time.time()-$s,2))"); echo "check-size .: ${t2}s"
  python3 -c "import sys; sys.exit(0 if $t2 < 10 else 1)" && ok "check-size under 10s on $(find "$P" -type f | wc -l | tr -d ' ') files" || no "check-size took ${t2}s"
  s=$(python3 -c 'import time;print(time.time())'); (cd "$P" && python3 "$R/skill/scripts/bigfile.py" index data/huge-100mb.jsonl >/dev/null 2>&1; python3 "$R/skill/scripts/bigfile.py" index generated/catalog.json; python3 "$R/skill/scripts/bigfile.py" get generated/catalog.json 3 | head -2); echo "index 100MB(1 line)+catalog, get: $(python3 -c "import time;print(round(time.time()-$s,2))")s"
  python3 -c "
import json
with open('$W/h01.jsonl','w') as f:
    for i in range(12000):
        f.write(json.dumps({'type':'user','message':{'role':'user','content':[{'type':'tool_result','tool_use_id':'t','content':'x'*4000}]}})+'\\n')"
  mkdir -p "$W/h01state"; s=$(python3 -c 'import time;print(time.time())'); python3 "$R/skill/scripts/cost_report.py" "$W/h01.jsonl" --record "$W/h01state" >/dev/null 2>&1; t3=$(python3 -c "import time;print(round(time.time()-$s,2))"); echo "cost_report on $(du -h "$W/h01.jsonl" | cut -f1) transcript: ${t3}s"
  python3 -c "import sys; sys.exit(0 if $t3 < 10 else 1)" && ok "session_end work fits its 12s budget on a 48 MB transcript" || no "cost_report needs ${t3}s on a 48 MB transcript; session_end kills it at 12s and the session is silently not recorded"
  s=$(python3 -c 'import time;print(time.time())'); inst --dry-run "$P" >/dev/null 2>&1; inst "$P" >/dev/null 2>&1; inst --check "$P" >/dev/null 2>&1; echo "dry+install+check: $(python3 -c "import time;print(round(time.time()-$s,2))")s"; }
t_H02() { fresh h02 LITE=1 ENTRY=none SETTINGS=none; inst "$P" >/dev/null
  b=$(awk '/TOKEN-OPTIMISATION:BEGIN/,/TOKEN-OPTIMISATION:END/' "$P/AGENTS.md" | wc -c | tr -d ' '); d=0
  for n in token-optimisation tips token-audit handoff; do x=$(awk '/^name:|^description:/' "$P/.agents/skills/$n/SKILL.md" | wc -c | tr -d ' '); d=$((d + x)); done
  echo "always-on: block $b chars (~$((b / 4)) tok) + 4 skill frontmatters $d chars (~$((d / 4)) tok) = ~$(((b + d) / 4)) tokens per session"
  [ $(((b + d) / 4)) -le 450 ] && ok "token tax within 450 tokens" || no "always-on tax ~$(((b + d) / 4)) tokens"
  for n in token-optimisation tips token-audit handoff; do python3 -c 'import re,sys; t=open(sys.argv[1]).read(); d=re.search(r"^description: (.*)$",t,re.M).group(1); sys.exit(0 if d.startswith(chr(34)) or ": " not in d else 1)' "$P/.agents/skills/$n/SKILL.md" && ok "skill $n frontmatter is valid YAML" || no "skill '$n' frontmatter: unquoted description contains ': ' (invalid YAML for strict parsers)"; done
  grep -rq '\.\./token-optimisation' "$P/.agents/skills"/*/SKILL.md && no "a SKILL.md uses ../token-optimisation paths that do not exist from the project root" || ok "skill paths resolve from the project root"; }

t_E06() { fresh e06 LITE=1; inst "$P" >/dev/null; m="$P/.claude/token-optimisation/ROUTES.md"
  o=$(printf '{"cwd":"%s"}' "$P" | hook "$P" session_start.py); [ -s "$m" ] && ok "routing map created at session start" || no "ROUTES.md not created"
  printf '%s' "$o" | grep -q 'routing map' && ok "one line announces it" || no "agent is not told the map exists"
  o=$(printf '{"cwd":"%s"}' "$P" | hook "$P" session_start.py); [ -z "$o" ] && ok "unchanged files: silent, no rewrite" || no "same line injected into every session: $o"
  mkdir -p "$P/newarea"; echo x > "$P/newarea/a.py"; printf '{"cwd":"%s"}' "$P" | hook "$P" session_start.py >/dev/null; grep -q 'newarea/' "$m" && ok "new folder appears in the map" || no "map not refreshed after a new folder"
  mkdir -p "$P/docs"; printf '# Big manual\n\n' > "$P/docs/big.md"; n=1; while [ $n -le 8 ]; do { printf '## Part %s\n' $n; yes line | head -n 30; } >> "$P/docs/big.md"; n=$((n + 1)); done
  ( cd "$P" && python3 "$R/skill/scripts/bigfile.py" split-md docs/big.md --apply >/dev/null ); printf '{"cwd":"%s"}' "$P" | hook "$P" session_start.py >/dev/null
  grep -q 'docs/big.md.*split' "$m" && grep -q 'docs/big/01-' "$m" && ! grep -q '^- `docs/big/01-' "$m" && ok "split doc listed once with its shard and sections" || no "split doc/shards not mapped correctly"
  mkdir -p "$P/.claude/skills/mine"; printf -- '---\nname: mine\ndescription: "My own skill"\n---\n' > "$P/.claude/skills/mine/SKILL.md"; printf '{"cwd":"%s"}' "$P" | hook "$P" session_start.py >/dev/null
  grep -q 'skills/mine/SKILL.md.*My own skill' "$m" && ! grep -q 'skills/token-optimisation' "$m" && ok "owner skills mapped, this system's own skills not" || no "skills section wrong"
  mkdir -p "$P/sub"; printf '{"cwd":"%s/sub"}' "$P" | hook "$P" session_start.py >/dev/null; [ -e "$P/sub/.claude" ] && no "map written under the session subfolder instead of the project root" || ok "subfolder session uses the project root"
  rm -f "$m"; printf 'routes=0\n' > "$P/.agents/token-optimisation.conf"; printf '{"cwd":"%s"}' "$P" | hook "$P" session_start.py >/dev/null; [ -e "$m" ] && no "routes=0 ignored" || ok "routes=0 turns it off"; }
run A01 "dry-run writes nothing, output small, discloses all writes"
run A02 "install into big project: only documented paths, settings merged additively"
run A03 "idempotent: install + 2x update gives identical files, no duplicates"
run A04 "uninstall restores the original tree (except backups dir + .gitignore)"
run A05 "uninstall keeps deny rules the project already had"
run A06 "uninstall keeps the project's hook when our hook was merged into its group"
run A07 "invalid/empty/BOM/trailing-comma/null settings.json: no half install"
run A08 "uninstall never creates settings.json; empty project round-trips clean"
run A09 "--hooks choice survives --update; bad --hooks rejected before writing"
run A10 "--check exit codes; update restores a deleted managed file"
run A11 "locally edited managed file survives repeated --update"
run A12 "uninstall does not destroy files the project added inside the skill"
run B01 "AGENTS.md that only QUOTES the BEGIN marker loses nothing"
run B02 "block with missing END marker: update/uninstall lose nothing"
run B03 "CRLF / no-trailing-newline AGENTS.md byte-identical after round trip"
run B04 "update keeps the block where the owner moved it"
run B05 "edited block, deleted AGENTS.md handled"
run C01 "own unmanaged 'token-optimisation' skill: untouched, no dead hooks"
run C02 "own unmanaged 'handoff' skill: install completes"
run C03 "own symlinked skills named tips/handoff survive uninstall"
run C04 "own .claude/skills/tips folder: uninstall completes"
run C05 ".claude/skills symlinked to .agents/skills survives"
run C06 "hooks leave git clean; manifest ignores __pycache__"
run D01 "entry: CLAUDE.md symlink / CLAUDE.md only"
run D02 "entry: Claude Code can actually see the block"
run D03 "entry file appears later: still one block, uninstall removes it"
run D04 "auto from a subfolder of a project with rules does not install"
run D05 "relative path with spaces; printed Next command runnable"
run D06 "project == repo guard, also via symlink"
run D07 "refuses to install into \$HOME (user-global settings)"
run E01 "guard_read: 17 payloads x off/log/deny never crash, small reads never blocked"
run E02 "deny mode cannot deadlock edits of small files under dist/"
run E03 "guard honours project conf when session cwd is a subfolder"
run E04 "missing hook script fails open (not exit 2)"
run E05 "session_start / session_end robust; pending review cleared"
run E06 "routing map: created, refreshed on change, silent otherwise, routes=0 off"
run F01 "auto: own rules -> dry run; new -> install; rerun -> check"
run F02 "auto has_own() recognises other rule/config locations"
run F03 "no downgrade via --auto or --update"
run F04 "auto dry-run branch makes no global plugin changes (fake claude CLI)"
run G01 "no python3: clean refusal, no temp files"
run G02 "no shasum: clean refusal or working fallback"
run G03 "dash compatible; no new-python syntax"
run H01 "performance: scan / check-size on 500+ files and a 100 MB file"
run H02 "always-on token tax; skill frontmatter and paths valid"
echo; echo "passed $pass, failed $fail"; [ -n "$failed" ] && echo "failed:$failed"; echo "logs: $L"
[ "$fail" = 0 ]
