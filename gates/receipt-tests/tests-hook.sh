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
#     genuinely types. Three exist because this hook really did block them.
# =============================================================================
set -u
D="$(cd "$(dirname "$0")" && pwd)"
HOOK="${HOOK:-$D/../hooks/block-deploy-without-receipt.sh}"
[ -f "$HOOK" ] || { echo "cannot find the hook at $HOOK"; exit 2; }
OK=0; BAD=0

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
KNOWN=0
known_fp() { # known_fp <verdict it gives TODAY> <name> <command>
  local pinned="$1" name="$2" cmd="$3"
  local out; out="$(p "$cmd" "" | bash "$HOOK" 2>&1)"
  local got="PASSES"
  printf '%s' "$out" | grep -q '"permissionDecision":"deny"' && got="BLOCKS"
  if [ "$got" = "$pinned" ]; then
    KNOWN=$((KNOWN+1)); printf '  KNOWN %-9s %s\n' "$got" "$name"
  else
    BAD=$((BAD+1))
    printf '  BAD   %-9s %s  (pinned as %s — if you fixed it, update this note)\n' \
           "$got" "$name" "$pinned"
  fi
}

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

echo
echo "-- LIVE FALSE POSITIVES: known, measured, and pinned --------------------------
   These are wrong and they are not fixed. They are recorded rather than hidden,
   because a battery that stays red gets ignored and a case quietly deleted takes
   the defect out of sight with it. Each one pins the verdict the guard gives
   TODAY: if somebody fixes the guard, the pin goes red and forces this note to
   be updated. That is the point.

   The cause of both: the \`sh\` alternative in §2 matches INSIDE a filename, so
   any command naming two deploy-ish files in one segment reads as executing one.
   The damage is bounded — it blocks work that is safe, never allows a deploy —
   which is the cheap direction, and it is why this is a note and not a stop."
known_fp BLOCKS "backing up a deploy script to a .bak of itself" \
     "cd /path/to/site-d-web && cp _deploy/upload-css.sh _deploy/upload-css.sh.bak"
known_fp BLOCKS "renaming one reads as executing it" \
     "cd /path/to/site-d-web && mv _deploy/upload-css.sh _deploy/upload-css.sh.old"

echo
echo "==============================================================================="
printf "  %d OK · %d BAD · %d known false positives, pinned\n" "$OK" "$BAD" "$KNOWN"
echo "==============================================================================="
[ "$BAD" = 0 ] || exit 1
