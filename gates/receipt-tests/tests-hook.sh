#!/usr/bin/env bash
# =============================================================================
#  tests-hook.sh · the battery for block-deploy-without-receipt.sh
# =============================================================================
#    bash gates/receipt-tests/tests-hook.sh
#
#  By default it tests the copy that SHIPS WITH THIS REPOSITORY. To test a
#  candidate before installing it, or the copy you already installed:
#
#    HOOK=/path/to/candidate.sh bash gates/receipt-tests/tests-hook.sh
#
#  It calls the hook by hand with payloads shaped like the ones it would really
#  receive, which is the only way to know whether it works BEFORE turning it on.
#  The house rule is: one positive AND several negatives, because a guard that
#  blocks too much gets switched off, and then nothing is left.
#
#  🔴 THE NEGATIVES ARE NOT DECORATION. Every one of them is a command somebody
#     genuinely types. Most exist because this hook really did block them.
#     And commands that fill several lines are written here the way they travel
#     inside the JSON, as a backslash and an n, not with a real line break.
# =============================================================================
set -u
D="$(cd "$(dirname "$0")" && pwd)"
HOOK="${HOOK:-$D/../hooks/block-deploy-without-receipt.sh}"
[ -f "$HOOK" ] || { echo "cannot find the hook at $HOOK"; exit 2; }
OK=0; BAD=0

# A tools-hosts.conf on this machine must not decide the verdicts below: §5b is
# off here and gets its own section at the end, with a file of its own.
export DEPLOY_HOOK_TOOLS_CONF="$D/no-such-tools-hosts.conf"

# The payload the harness sends: JSON with the command inside. Passed raw on
# purpose — the hook reads it with grep, without parsing JSON.
p() { printf '{"tool_name":"Bash","tool_input":{"command":"%s","description":"%s"}}' "$1" "${2:-}"; }

case_is() { # case_is <BLOCKS|PASSES> <name> <command> [description]
  local want="$1" name="$2" cmd="$3" desc="${4:-}"
  local out; out="$(p "$cmd" "$desc" | bash "$HOOK" 2>&1)"
  local got="PASSES"
  printf '%s' "$out" | grep -q '"permissionDecision":"deny"' && got="BLOCKS"
  if [ "$got" = "$want" ]; then
    OK=$((OK+1)); printf '  OK    %-9s %s\n' "$got" "$name"
  else
    BAD=$((BAD+1)); printf '  BAD   %-9s %s  (expected %s)\n' "$got" "$name" "$want"
    printf '        cmd: %s\n' "$cmd"
  fi
}

echo "==============================================================================="
echo "  HOOK block-deploy-without-receipt"
echo "  $HOOK"
echo "==============================================================================="
echo
echo "-- POSITIVE: what it must block ----------------------------------------------"
case_is BLOCKS "scp of the CSS to production (the real case)" \
     "scp -i ~/.ssh/key -P 65002 styles.css user@203.0.113.10:domains/site-d.example/public_html/styles.css"
case_is BLOCKS "rsync of the whole tree" \
     "rsync -av ./ user@203.0.113.10:domains/site-a.example/public_html/"
case_is BLOCKS "tar | ssh into a shared /var/www" \
     "tar czf - index.html styles.css | ssh example-host \\\"sudo tar -x -C /var/www/site-f\\\""
case_is BLOCKS "scp into a store subpath" \
     "scp -P 65002 js/site.js user@203.0.113.10:domains/site-b.example/public_html/shop/js/"
case_is BLOCKS "vercel --prod" \
     "vercel --prod"
case_is BLOCKS "a deploy script whose inside it cannot see" \
     "bash /path/to/site-d-web/_deploy/upload-css.sh"

echo
echo "-- POSITIVE: the holes that were found and closed -----------------------------"
# 🔴 §0 used to say "a command STARTING with a read verb uploads nothing,
#    whatever it says afterwards". A read verb in front disabled the whole door.
case_is BLOCKS "a read verb in front does not exempt what follows" \
     "echo hi ; scp b.html user@203.0.113.10:domains/site-a.example/public_html/"
case_is BLOCKS "and the same with ls" \
     "ls -la . && scp b.html user@203.0.113.10:domains/site-a.example/public_html/"
# 🔴 §5's /tmp exemption used to apply BY MENTION: the `:/tmp/` in the first half
#    exempted the second half, which is a deploy.
case_is BLOCKS "the /tmp exemption lapses when a docroot is named" \
     "scp srv:/tmp/x.html . && scp index.html user@203.0.113.10:~/domains/site-a.example/public_html/"
# 🔴 §1: `cat >` is the verb the upload script itself uses. A guard that does not
#    cover the verb the door uses guards nothing.
case_is BLOCKS "ssh with cat > into a document root" \
     "ssh example-host \\\"cd ~/domains/site-a.example/public_html && cat > x.php\\\""
# 🔴 The payload can carry metacharacters escaped as backslash-u-XXXX, and every
#    chaining guard asks for a LITERAL one. Normalised once, at the top.
case_is BLOCKS "a chained deploy hidden behind an escaped ampersand" \
     "echo hi u0026u0026 scp b.html user@203.0.113.10:domains/site-a.example/public_html/"
# 🔴 Inside the JSON a line break is a backslash and an n, so no separator was
#    found and §0 exempted the whole command. These cases write it the way it
#    travels. Every other case here fits on one line, which is why nobody saw it.
case_is BLOCKS "a line break in front does not exempt what follows" \
     "echo hi\nscp b.html user@203.0.113.10:domains/site-a.example/public_html/"
case_is BLOCKS "and the same with ls and rsync" \
     "ls -l\nrsync -a ./ user@203.0.113.10:domains/site-a.example/public_html/"
case_is BLOCKS "and a carriage return is a line break too" \
     "cat notes.txt\rscp b.html user@203.0.113.10:domains/site-a.example/public_html/"
# 🔴 §4 used to apply by mention: naming the door exempted the command.
case_is BLOCKS "a file called deploy.sh uploaded to a document root" \
     "scp gates/deploy.sh user@203.0.113.10:domains/site-a.example/public_html/"
case_is BLOCKS "an upload chained behind the door" \
     "bash gates/deploy.sh /path/to/site-d-web ; scp b.html user@203.0.113.10:domains/site-a.example/public_html/"
case_is BLOCKS "an upload with the door named in an echo" \
     "echo gates/deploy.sh ; rsync -a ./ user@203.0.113.10:domains/site-a.example/public_html/"
case_is BLOCKS "the door packed by tar is not the door running" \
     "tar czf - gates/deploy.sh | ssh example-host \\\"tar -x -C /var/www/site-f\\\""
case_is BLOCKS "a write over ssh chained behind the door" \
     "bash gates/deploy.sh /path/to/site-d-web ; ssh example-host \\\"cat > ~/domains/site-a.example/public_html/x\\\""
case_is BLOCKS "another deploy script chained behind the door" \
     "bash gates/deploy.sh /path/to/site-d-web ; bash _deploy/upload-css.sh"
case_is BLOCKS "and in front of it" \
     "bash _deploy/upload-css.sh ; bash gates/deploy.sh /path/to/site-d-web"
case_is BLOCKS "git add does not cover what is chained to it" \
     "git add x.sh ; bash _deploy/upload-css.sh"
case_is BLOCKS "and neither does a line break after it" \
     "git add x.sh\nbash _deploy/upload-css.sh"
case_is BLOCKS "git add followed by an upload" \
     "git add x.html && rsync -a ./ user@203.0.113.10:domains/site-a.example/public_html/"
case_is BLOCKS "git commit followed by an upload" \
     "git commit -F m.txt && scp b.html user@203.0.113.10:domains/site-a.example/public_html/"
# 🔴 §2c reads segment by segment: naming a script in a harmless segment does not
#    exempt the segment that runs it.
case_is BLOCKS "reading a script into a shell" \
     "sed -n '1,5p' _deploy/upload-css.sh | bash"
case_is BLOCKS "and with cat into sh" \
     "cat _deploy/upload-css.sh | sh"
case_is BLOCKS "xargs runs what it is handed" \
     "ls _deploy/upload-css.sh | xargs bash"
case_is BLOCKS "command substitution runs it" \
     "echo \$(bash _deploy/upload-css.sh)"
case_is BLOCKS "and so do backticks" \
     "echo \`bash _deploy/upload-css.sh\`"
case_is BLOCKS "sourcing it behind a read" \
     "head -1 x.txt ; . _deploy/upload-css.sh"
case_is BLOCKS "running it after a cd" \
     "cd /path/to/site-d-web && ./_deploy/upload-css.sh"
case_is BLOCKS "a read chained to an scp is still an upload" \
     "grep x _deploy/upload-css.sh ; scp b.html user@203.0.113.10:domains/site-a.example/public_html/"

echo
echo "-- THE DOOR, AND ITS COUPLING TO A FILENAME -----------------------------------"
# 🔴 §4 is coupled to the door's filename. That coupling is the point of the
#    exemption, so it is also what breaks silently when the door is renamed.
#    It happened here: the door was renamed from its old name to `deploy.sh` and
#    the hook, still exempting the old one, started denying the door itself. It
#    failed towards BLOCKING — the cheap direction — but both files must move.
#    These two cases are what makes a future rename go red instead of silent.
case_is PASSES "the door is recognised, rehearsing" \
     "bash /path/to/web-quality-system/gates/deploy.sh /path/to/site-d-web"
case_is PASSES "the door is recognised, uploading for real" \
     "bash /path/to/web-quality-system/gates/deploy.sh /path/to/site-d-web --upload"
case_is PASSES "the relative form the documentation gives" \
     "bash gates/deploy.sh /path/to/site-d-web --upload"
case_is PASSES "after a cd, with its output cut" \
     "cd /path/to/repo && bash gates/deploy.sh /path/to/site-d-web 2>&1 | tail -5"
case_is PASSES "and after a line break" \
     "cd /path/to/repo\nbash /path/to/web-quality-system/gates/deploy.sh /path/to/site-d-web"
# On Windows, PowerShell has no bash on its PATH: the door is called through the
# full path to bash.exe, and that has to read as executing it.
case_is PASSES "from PowerShell, through the full path to bash.exe" \
     "& C:/Program Files/Git/bin/bash.exe C:/path/to/repo/gates/deploy.sh C:/path/to/site-d-web --upload"
# ⚠️ The name here must be one §2 DOES recognise as a deploy script, or the case
#    proves nothing: my first attempt used `ship-it.sh`, which §2 never matches,
#    so it left through a different exit and passed for a reason that had nothing
#    to do with the door exemption. A case that goes green by accident is worse
#    than no case.
case_is BLOCKS "a door by any other name is NOT recognised" \
     "bash /path/to/web-quality-system/gates/deploy-now.sh /path/to/site-d-web --upload"

echo
echo "-- NO EXEMPTIONS SHIP, AND THAT IS A DECISION ---------------------------------
   Two existed upstream, both for scripts publishing assets no page ever serves.
   They named one particular estate, so they were removed rather than shipped
   half-true. If you add one, follow the three rules in section 6 of the hook and
   add a positive AND a negative case here in the same commit. An exemption
   without a negative case is a hole with a comment on top."
case_is BLOCKS "a publisher script is blocked like any other" \
     "bash _deploy/publish-assets.sh"
case_is BLOCKS "and a namesake from another repository too" \
     "bash /path/to/other-repo/_deploy/publish-assets.sh"

echo
echo "-- NEGATIVE: normal work that must not be blocked -----------------------------"
case_is PASSES "reading the server" \
     "ssh example-host 'ls -la /var/www/site-f | head'"
case_is PASSES "scp of a script to /tmp, to run it there" \
     "scp /tmp/mine.cjs example-host:/tmp/mine.cjs"
case_is PASSES "a backup taken BEFORE uploading" \
     "ssh example-host 'cp -p /var/www/site-f/index.html ~/backups/index.html.bak'"
case_is PASSES "measuring the site on the server" \
     "ssh example-host 'cd ~/webtools && node measure.js https://site-d.example 390 844 ~/shots/x.png'"
# 🔴 A DOWNLOAD came out blocked: it saw `scp ` and `domains/` and never looked
#    at the DIRECTION. Fetching a file from production cannot break production.
case_is PASSES "downloading a file from production" \
     "scp -P 65002 user@203.0.113.10:~/domains/site-a.example/_leads/leads.jsonl ./leads.jsonl"
# 🔴 And the exact live form: the real command had a `; echo` behind it and came
#    out BLOCKED with the battery green. A control must run the EXACT order.
case_is PASSES "the same download with an echo chained behind it" \
     "scp -P 65002 user@203.0.113.10:~/domains/site-a.example/_leads/leads.jsonl ./leads.jsonl ; echo \\\"code: 0\\\""
case_is PASSES "downloading production to compare it" \
     "curl -sS -L https://site-d.example/styles.css -o /tmp/live.css"
# 🔴 Uploading a MEASURING script to a tools server that serves no website. It
#    was enough for a client domain to appear anywhere in the command — the one
#    about to be measured, written inside the script itself.
case_is PASSES "uploading a measuring script to a tools server" \
     "ssh example-host \\\"cat > ~/webtools/measure.cjs\\\" < measure.cjs"
case_is PASSES "running the QA" \
     "perl gates/qa-master.pl https://site-d.example --repo /path/to/site-d-web"
case_is PASSES "git locally, with the word deploy in the message" \
     "git commit -m 'prepare deploy of site-d.example'"
case_is PASSES "a description that mentions production" \
     "ls -la ./assets" "check the assets before uploading to public_html"
case_is PASSES "editing a file in the repository" \
     "perl -i -pe 's/old/new/' /path/to/site-d-web/styles.css"
case_is PASSES "scp of a scrape dump" \
     "scp _migrate/extract-wordpress.py example-host:~/scrape/site-e/"
# _deploy/ also holds scripts that only LOOK. Blocking verification would block
# exactly what we want done most.
case_is PASSES "qa-final.sh, which lives in _deploy/ and uploads nothing" \
     "bash /path/to/site-e-web/_deploy/qa-final.sh"
case_is PASSES "the site auditor" \
     "bash _audit.sh --live"
case_is PASSES "the destructive-edit canary" \
     "bash _check.sh"
# 🔴 `bash -n` does not execute. Checking a deploy script's syntax before handing
#    it to anybody is what we want done most.
case_is PASSES "bash -n on a deploy script" \
     "bash -n /path/to/site-d-web/_deploy/upload-css.sh"
# 🔴 And the false positive that came back through the side door: PowerShell's
#    call operator `& ` also matched the second `&` of an `&&`, so READING a file
#    with deploy in its name read as executing it. It blocked the backup of the
#    hook itself.
case_is PASSES "reading a deploy script behind an &&" \
     "cd /path/to/site-d-web && sed -n '1,5p' _deploy/upload-css.sh"
case_is PASSES "and copying one to a neutral name, which is how you back it up" \
     "cd /path/to/site-d-web && cp _deploy/upload-css.sh copy.txt"
# 🔴 These two were pinned here as live false positives: the `sh` in §2 matches
#    inside a filename, so two deploy-ish names in one segment read as executing
#    one. §2c reads the verbs instead.
case_is PASSES "backing up a deploy script to a .bak of itself" \
     "cd /path/to/site-d-web && cp _deploy/upload-css.sh _deploy/upload-css.sh.bak"
case_is PASSES "renaming one does not execute it" \
     "cd /path/to/site-d-web && mv _deploy/upload-css.sh _deploy/upload-css.sh.old"
case_is PASSES "reading one through a pipe" \
     "sed -n '1,5p' _deploy/upload-css.sh | head -2"
case_is PASSES "reading one on a second line" \
     "cd /path/to/site-d-web\nsed -n '1,5p' _deploy/upload-css.sh"
case_is PASSES "cd, copy and grep" \
     "cd /path/to/site-d-web && cp _deploy/upload-css.sh copy.txt && grep -n x copy.txt"
# 🔴 §0c. Naming two scripts in one `git add` killed it: the `.sh` of the first
#    acts as the execution context of the second.
case_is PASSES "git add of two deploy scripts" \
     "git add _deploy/upload-css.sh _deploy/upload-js.sh"
case_is PASSES "git add and commit" \
     "git add _deploy/upload-css.sh _deploy/upload-js.sh && git commit -F m.txt"
case_is PASSES "and pushing after it, which reaches no document root" \
     "git add _deploy/upload-css.sh _deploy/upload-js.sh && git commit -F m.txt && git push origin main"
case_is PASSES "a commit message that talks about an upload" \
     "git commit -m 'rsync the --prod build'"

echo
echo "-- 5b · A TOOLS SERVER, ONLY IF YOU NAME IT ------------------------------------
   Off by default: without config/tools-hosts.conf these stay blocked. With it,
   only an scp or rsync whose LAST argument literally points at a listed host, and
   whose path matches no production marker, is exempt."
TOOLS_FILE="$(mktemp)"
MARKERS_FILE="$(mktemp)"
trap 'rm -f "$TOOLS_FILE" "$MARKERS_FILE"' EXIT
export DEPLOY_HOOK_TOOLS_CONF="$TOOLS_FILE"
export DEPLOY_HOOK_CONF="$MARKERS_FILE"
printf '# a comment\nexample-tools\r\n' > "$TOOLS_FILE"
# The domain as a marker is what makes these reach §5b at all: without it §3 lets
# them through and every PASSES below would be green by accident.
printf 'site-d\\.example\n' > "$MARKERS_FILE"
case_is PASSES "a probe copied to the tools server and run against a site" \
     "scp probe.mjs example-tools:~/probes/ && ssh example-tools 'node ~/probes/probe.mjs https://site-d.example'"
case_is PASSES "a tree copied to a folder of the tools server" \
     "scp -r _candidate example-tools:~/candidates/"
case_is PASSES "rsync with a user, for a site about to be measured" \
     "rsync -a _candidate/ user@example-tools:~/candidates/x/ && ssh example-tools 'node m.js https://site-d.example'"
case_is BLOCKS "a destination whose path is a marker" \
     "scp -r _candidate example-tools:~/site-d.example/"
case_is BLOCKS "a document root on the tools server" \
     "scp b.html example-tools:domains/site-a.example/public_html/"
case_is BLOCKS "one destination listed and one not" \
     "scp a.txt example-tools:~/x/ && scp a.txt other-host:~/site-d.example/"
case_is BLOCKS "a destination in a variable" \
     "scp a.txt example-tools:\$D ; curl https://site-d.example/"
case_is BLOCKS "a part of a listed name is not that name" \
     "scp a.txt example:~/x/ ; curl https://site-d.example/"
case_is BLOCKS "a host that is not listed" \
     "scp a.txt other-host:~/site-d.example/"
case_is BLOCKS "a listed name as a prefix of another host" \
     "scp a.txt example-tools-2:~/site-d.example/"
case_is BLOCKS "a redirection behind the destination" \
     "scp a.txt other-host:~/site-d.example/ 2>/dev/null"
case_is BLOCKS "curl -T chained to a copy" \
     "scp a.txt example-tools:~/x/ && curl -T a.txt ftp://site-d.example/"
case_is BLOCKS "a deploy script chained to a copy" \
     "scp a.txt example-tools:~/x/ && bash _deploy/upload-css.sh"
case_is BLOCKS "ssh writing into a document root" \
     "scp a.txt example-tools:~/x/ && ssh example-host \\\"cat > ~/domains/site-a.example/public_html/x\\\""
export DEPLOY_HOOK_TOOLS_CONF="$D/no-such-tools-hosts.conf"
case_is BLOCKS "and without the file, the same probe stays blocked" \
     "scp probe.mjs example-tools:~/probes/ && ssh example-tools 'node ~/probes/probe.mjs https://site-d.example'"
unset DEPLOY_HOOK_CONF

echo
echo "==============================================================================="
printf "  %d OK · %d BAD\n" "$OK" "$BAD"
echo "==============================================================================="
[ "$BAD" = 0 ] || exit 1
