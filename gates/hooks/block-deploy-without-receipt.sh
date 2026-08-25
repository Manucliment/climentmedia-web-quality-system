#!/usr/bin/env bash
# =============================================================================
#  block-deploy-without-receipt.sh — the door cannot be walked around
# =============================================================================
#  WHY THIS EXISTS
#
#  `deploy.sh` is the door: it refuses to reach the upload line without a valid
#  QA receipt. But a door only works if there is no way past it, and there is
#  always a way past it — one `scp`, typed by hand, at the end of a long day.
#
#  The measured case: a contrast fix sat in the repository for hours with every
#  gate green while production kept serving the old CSS. Nobody checks AFTER
#  uploading, and "I ran the QA" is a claim nobody verifies.
#
#  So this is a PreToolUse hook. It inspects the command about to run and denies
#  anything that looks like writing into a document root, telling the caller to
#  go through the door instead.
#
#  ---------------------------------------------------------------------------
#  INSTALLING IT (optional, and it is not on by default)
#
#  Copy it somewhere stable and register it in your agent's settings as a
#  PreToolUse hook matching your shell tools. For Claude Code, in
#  `~/.claude/settings.json`:
#
#    "hooks": {
#      "PreToolUse": [{
#        "matcher": "Bash|PowerShell",
#        "hooks": [{ "type": "command",
#                    "command": "bash /ABSOLUTE/PATH/TO/block-deploy-without-receipt.sh" }]
#      }]
#    }
#
#  Then run its test battery — see BEFORE YOU TURN IT ON, below.
#
#  ---------------------------------------------------------------------------
#  BEFORE YOU TURN IT ON — this is not optional
#
#      bash gates/receipt-tests/tests-hook.sh
#
#  A guard that blocks too much gets switched off, and then there is no guard at
#  all. The battery is one positive case per thing it must catch and SIXTEEN
#  negatives — every one of them a command somebody genuinely types. Three of
#  the negatives are there because this hook really did block them: downloading
#  a file from production, uploading a measuring script to a tools server, and
#  reading its own source.
#
#  ---------------------------------------------------------------------------
#  ZERO DEPENDENCIES, ON PURPOSE
#
#  It reads stdin raw with `grep`. It does NOT use `jq`, node or python. A hook
#  that depends on a tool the machine does not have does not fail loudly — it
#  never fires at all, which is worse than not having it.
#
#  ---------------------------------------------------------------------------
#  THE COLLATERAL DAMAGE, AND YOU MUST KNOW ABOUT IT
#
#  Denying kills the WHOLE command. If local work came first in the same line —
#  a heredoc writing a file, a `mkdir` — THAT WORK DID NOT HAPPEN, and the next
#  command's "No such file or directory" is a consequence of this block, not a
#  new fault. Split the command and leave the uploading part out.
# =============================================================================
payload=$(cat)

# --- the command, extracted from the JSON payload without a JSON parser -------
#  🔴 The command's quotes travel ESCAPED inside the JSON, and `[^"]*` cuts the
#     command at the first one: of `ssh srv "cat > ~/domains/x/public_html/y"`
#     only `ssh srv ` survived, so everything that inspects the DESTINATION had
#     no command left to inspect. A deploy slipped through on a reading failure,
#     not on a judgement failure. Strip them before extracting. The backslash is
#     built with printf in octal: written by hand it gets eaten in transit.
BSQ=$(printf '\134"')
plano=${payload//"$BSQ"/}
first=$(printf '%s' "$plano" | grep -oE '"command"[[:space:]]*:[[:space:]]*"[^"]*' | head -1 | sed 's/.*"//')
[ -z "$first" ] && first="$plano"

#  🔴 The payload can carry metacharacters escaped as backslash-u-XXXX (`&` as
#     u0026, `;` as u003b). Every guard below asks for a LITERAL `&`, and the
#     escaped form does NOT match — so the read-verb exemption would apply to a
#     command with a deploy chained behind it. Normalise once, here, so every
#     check below looks at the same thing. (A stray backslash is left in front
#     of the `&`; it does not matter: `first` is only ever analysed, never run.)
first=$(printf '%s' "$first" | sed 's/u0026/\&/g; s/u003b/;/g; s/u007c/|/g; s/u003e/>/g; s/u003c/</g; s/u0060/`/g')

# --- optional configuration ---------------------------------------------------
#  Extra production markers, one extended-regex fragment per line, `#` comments
#  ignored. Use it to name your own document roots and hostnames. Everything
#  works without it; this only makes the hook stricter, never looser.
MARKERS='public_html|/var/www|domains/|vercel --prod|--prod'
CONF="${DEPLOY_HOOK_CONF:-$(cd "$(dirname "$0")" && pwd)/../config/production-markers.conf}"
if [ -f "$CONF" ]; then
  extra=$(grep -v '^[[:space:]]*#' "$CONF" | grep -v '^[[:space:]]*$' | paste -sd '|' -)
  [ -n "$extra" ] && MARKERS="$MARKERS|$extra"
fi

# ── 0 · READ-ONLY VERBS ──────────────────────────────────────────────────────
#    Without this the hook blocks itself: `ls -l block-deploy-without-receipt.sh`
#    names a deploy script, so it looked like one. It caught its own installation
#    and then caught the attempt to debug it.
#    ⚠️ Do NOT add anything that writes (tee, dd, install, cp, mv). This list is
#       read-only verbs, and widening it carelessly opens the whole door.
#    🔴 AND ONLY IF NOTHING IS CHAINED BEHIND IT. This used to say "a command
#       STARTING with ls/cat/grep uploads nothing, whatever it says afterwards",
#       and that is not a caution, it is a hole: a read verb in front disabled
#       the entire door. Measured — `echo hi ; scp b.html u49@host:…/public_html/`
#       PASSED. Four variants (echo, ls, cat, grep) walked a deploy through.
#       The rule was already written 130 lines below for the sibling case
#       (§2, `bash -n`). Copy the pattern that was already tested.
case "$first" in
  ls\ *|ll\ *|cat\ *|bat\ *|grep\ *|rg\ *|head\ *|tail\ *|wc\ *|stat\ *|file\ *|find\ *|\
  diff\ *|md5sum\ *|sha1sum\ *|sha256sum\ *|awk\ *|sed\ -n*|echo\ *|printf\ *|\
  git\ status*|git\ diff*|git\ log*|git\ show*|which\ *|type\ *|realpath\ *|readlink\ *)
    case "$first" in
      *\;*|*\&*|*\|*|*\`*|*'$('*) : ;;   # something else follows: NOT exempt
      *) exit 0 ;;
    esac ;;
esac

# ── 0b · DOWNLOADING IS NOT UPLOADING ────────────────────────────────────────
#    🔴 A download came out BLOCKED. `scp -P 65002 user@host:~/domains/site/…/
#       leads.jsonl ./file` moves bytes TOWARDS HERE — it is how you read a
#       client's leads — and the hook treated it like an upload: it saw `scp ` in
#       §1 and `domains/` in §3 and never looked at the DIRECTION. Fetching a
#       file from production cannot break production.
#    Decided by the LAST argument: in scp/rsync/sftp the destination comes last.
#    If the destination is NOT remote and there is a remote source before it,
#    this is a download.
#    ⚠️ `remote` means `something:` with two or more characters before the colon,
#       so `C:/Users/…` (a Windows drive) counts as LOCAL and downloading to an
#       absolute Windows path is not blocked either.
#    🔴 IT IS READ SEGMENT BY SEGMENT, and exempt only if EVERY transfer in the
#       command is a download. The first version gave up at any `;`, `&` or `|`
#       and exempted nothing — and that was caught by running it LIVE, not by
#       the battery: the real command had a `; echo "code: $?"` behind it and
#       came out BLOCKED with the battery green. A control must run the EXACT
#       order, not one that looks like it.
#    ⚠️ A segment with a redirection, `$` or backticks is NOT exempt: `scp x
#       host:public_html/ 2>/dev/null` would end in a token that does not look
#       remote and would read as a download. There, position stops meaning
#       anything.
if printf '%s' "$first" | grep -qE '(^|[;&|] *)[^;&|]*(scp|rsync|sftp) '; then
  any_transfer=0; all_download=1
  while IFS= read -r seg; do
    case "$seg" in *scp\ *|*rsync\ *|*sftp\ *) : ;; *) continue ;; esac
    any_transfer=1
    case "$seg" in *'>'*|*'<'*|*'$'*|*'`'*) all_download=0; continue ;; esac
    set -f; set -- $seg; set +f
    last=""; for t in "$@"; do last=$t; done
    any_remote=0
    for t in "$@"; do
      printf '%s' "$t" | grep -qE '^[A-Za-z0-9._@-]{2,}:' && any_remote=1
    done
    if [ "$any_remote" = 1 ] && ! printf '%s' "$last" | grep -qE '^[A-Za-z0-9._@-]{2,}:'; then
      : # this segment is a download
    else
      all_download=0
    fi
  done <<FINSEG
$(printf '%s' "$first" | sed 's/[;&|]/\n/g')
FINSEG
  [ "$any_transfer" = 1 ] && [ "$all_download" = 1 ] && exit 0
fi

# ── 1 · IS THIS AN UPLOAD? ───────────────────────────────────────────────────
#    Verbs that move bytes outwards. Plain `ssh` is NOT here: reading the server
#    is the most common thing anybody does and blocking it would be unbearable.
#    🔴 `ssh … "cat > …"` and `ssh … "dd of=…"` were added later. The hook did
#       not recognise them, and `cat >` is exactly the verb the upload script
#       uses to write lead receivers. A guard that does not cover the verb the
#       door itself uses guards nothing: something wrote into a live document
#       root at 13:41 while every instruction said DO NOT DEPLOY, and no hook
#       saw it.
printf '%s' "$payload" | grep -qE 'scp |rsync |sftp |lftp |curl -T|vercel |netlify |tar .*\| *ssh' \
  && upload=1 || upload=0

#    🔴 `ssh` WRITES NOW REQUIRE A DOCUMENT ROOT IN THE REMOTE ORDER. They used
#       to be in the list above unconditionally, and that blocked
#       `ssh host "cat > ~/webtools/measure.cjs" < measure.cjs`: uploading a
#       MEASURING script to a tools server that serves no website at all. It was
#       enough for a client domain to appear anywhere in the command — the one
#       about to be measured, written inside the script itself — for §3 to call
#       it production. The DESTINATION decides, not what gets named.
#       Only from the first `ssh ` onwards is inspected: the LOCAL part of the
#       command (a heredoc with the script inside) stops counting. That was the
#       expensive failure mode: `cat > x.cjs <<EOF … EOF && ssh …` came out
#       blocked ENTIRELY, the local file was never created, and the next command
#       failed with "No such file or directory" for an unrelated-looking reason.
#    ⚠️ Still covered: a `cat >` whose remote order names public_html, /var/www
#       or domains/ is an upload, even if the `cd` into the document root comes
#       before the `cat` — the whole remote order is searched, not just the path.
if [ "$upload" = 0 ]; then
  if printf '%s' "$payload" | grep -qE 'ssh .*(tar -x|tee |cat *>|dd +of=|install -)'; then
    remote=${first#*ssh }
    printf '%s' "$remote" | grep -qE 'public_html|/var/www|domains/' && upload=1
  fi
fi

# ── 2 · OR IS IT A DEPLOY SCRIPT, WHOSE INSIDE I CANNOT SEE? ─────────────────
#    🔴 ONLY IF IT IS EXECUTED. Naming it used to be enough, and that blocked
#       `ls -l block-deploy-without-receipt.sh`: the hook blocked itself, and with
#       it any command mentioning a file with "deploy" in the name — reading it,
#       searching it, documenting it. Caught by the first live test.
#       Requiring an execution context (bash/sh/./ /source) closes the false
#       positive without opening the hole: `bash _deploy/upload-css.sh`, which is
#       THE command from the real case, still matches.
#    🔴 POWERSHELL'S `& ` MATCHED THE SHELL'S `&&`. `& ` is in the list because
#       in PowerShell it is the call operator. But as a loose alternative it also
#       matched the SECOND `&` of an `&&` followed by a space, so READING a file
#       with "deploy"/"upload" in its name behind an `&&` read as executing it:
#           cd X && sed -n '1,5p' block-deploy-without-receipt.sh   -> BLOCKED
#           cd X && cp block-deploy-without-receipt.sh copy.txt     -> BLOCKED
#       The second one blocked the backup of the hook ITSELF, and it is exactly
#       the false positive §2 claims above to have closed: it came back in
#       through the side door. `sed`/`cp` are not in §0 (they are not read-only),
#       so nothing else saved them.
#       That `&` is now required NOT to be preceded by another `&`. PowerShell's
#       form still matches: at the start of the command (`^`) or after `;`, `(`
#       or `|`.
printf '%s' "$payload" | grep -qE '((bash|sh|zsh|\./|source|\. |powershell|pwsh)|(^|[^&])& )[^|;&]*(_deploy/[^ "]*\.sh|upload[^ "]*\.(sh|ps1)|deploy[^ "]*\.(sh|ps1)|publish[^ "]*\.(sh|ps1))' \
  && script=1 || script=0

# ⚠️ _deploy/ also holds scripts that only LOOK (qa-final.sh, audit.sh, checks).
#    Blocking verification would block precisely what we want done most.
printf '%s' "$payload" | grep -qE 'qa-[^ "]*\.sh|check-[^ "]*\.sh|_audit\.sh|_check\.sh|audit[^ "]*\.sh' \
  && script=0

# 🔴 `bash -n` DOES NOT EXECUTE: it checks syntax and exits. Measured false
#    positive: `bash -n …/_deploy/install-caddy-redirect.sh` came out BLOCKED.
#    Checking the syntax of a deploy script BEFORE handing it to anybody is what
#    we want done most — same family as the exemption just above.
#    ⚠️ It does NOT go in §0's read-only verb list: there the comparison is
#       against the START of the command, and `bash -n x.sh && bash upload.sh`
#       would be exempt ENTIRELY. That is opening the door with the verb next to
#       it. Here only a clean `bash -n`, with nothing chained behind, is exempt.
case "$first" in
  bash\ -n\ *|sh\ -n\ *|zsh\ -n\ *)
    case "$first" in
      *\;*|*\&*|*\|*|*\`*|*'$('*) : ;;   # something else follows: NOT exempt
      *) script=0 ;;
    esac ;;
esac

[ "$upload" = 1 ] || [ "$script" = 1 ] || exit 0

# ── 2b · TOOLING IS NOT A WEBSITE ────────────────────────────────────────────
#    Nothing inside an agent's own tool directories deploys a site: that is where
#    hooks, skills and their test batteries live. Without this exemption the hook
#    blocks its own battery (which is named after the thing it tests) and any
#    work on itself. Caught twice in a row while trying to test it.
#    ⚠️ This is an exemption by TOOL PATH, not by name: an scp to production is
#       still blocked even when a tool directory launches it.
printf '%s' "$payload" | grep -qE '\.claude/(hooks|skills)/|gates/(hooks|[a-z-]*-tests)/' \
  && ! printf '%s' "$payload" | grep -qE 'public_html|/var/www|domains/' \
  && exit 0

# ── 3 · DOES IT POINT AT PRODUCTION? ─────────────────────────────────────────
#    Without this, any scp to the server's /tmp — the documented way to run a
#    script remotely — would be blocked.
#    🔴 Only VERBS are asked for this. A deploy script is not: the whole reason
#       for recognising it by name is that its destination cannot be seen.
#       Requiring it let `bash _deploy/upload-css.sh` through, which is THE
#       command from the real case. The tests caught that.
if [ "$script" != 1 ]; then
  printf '%s' "$payload" | grep -qE "$MARKERS" || exit 0
fi

# ── 4 · IS IT ALREADY GOING THROUGH THE DOOR? ────────────────────────────────
#    🔴 THIS LINE IS COUPLED TO THE DOOR'S FILENAME, and that coupling is the
#       whole point of the exemption — so it is also the thing that breaks
#       silently when somebody renames the door. It happened: the door was
#       renamed and this hook, still exempting the old name, started denying the
#       door itself. It failed towards BLOCKING, which is the cheap direction,
#       but a rename must change both files.
#       Caught by: `gates/receipt-tests/tests-hook.sh`, which asserts both that
#       the current door name is exempt AND that an arbitrary other name is not.
printf '%s' "$payload" | grep -qE '(^|[^a-zA-Z0-9._-])deploy\.sh([^a-zA-Z0-9]|$)' && exit 0

# ── 5 · DESTINATIONS THAT ARE NOT PRODUCTION, EVEN ON THE SERVER ─────────────
#    /tmp and ~/backups are normal work: copying a script to run it, or taking a
#    backup BEFORE uploading. Blocking the backup would block the one thing that
#    makes going back possible.
#    🔴 THIS EXEMPTION USED TO APPLY BY MENTION, AND IT WAS A DOOR. Caught by a
#       new case in the battery: `scp srv:/tmp/x.html . && scp index.html
#       user@host:~/domains/site/public_html/` came out FREE — the `:/tmp/` in
#       the first half exempted the second half, which is a deploy. Now the
#       exemption lapses the moment the command names a document root.
if printf '%s' "$payload" | grep -qE ':/tmp/|:~/tmp/|~/backups|_backups|/scrape/|:~/webtools'; then
  printf '%s' "$payload" | grep -qE 'public_html|/var/www|domains/' || exit 0
fi

# ── 6 · HOW TO ADD AN EXEMPTION, IF YOU EVER NEED ONE ────────────────────────
#    This copy ships with none. Two existed upstream, both for scripts that
#    publish assets no page ever serves, and both were removed here because they
#    named one particular estate. If you add one, these are the three rules that
#    made them safe — every one of them written after the exemption leaked:
#
#    1. THE EXEMPTION IS NOT THE SCRIPT'S NAME, IT IS WHAT THE SCRIPT DOES, and
#       that is read from disk. A namesake in another repository, whose contents
#       nobody has read, otherwise walks straight through. The entry condition
#       used to be the name and the comment right above it claimed the opposite.
#    2. THE COMMAND MUST BE EXACTLY THAT INVOCATION and nothing else, so nothing
#       can be chained behind it.
#    3. PIN THE DESTINATION ROOT LITERALLY, and refuse if the script names any
#       other document root. If somebody later widens the script, the exemption
#       stops applying on its own and this goes back to blocking.
#
#    Add a positive AND a negative case to the battery in the same commit. An
#    exemption without a negative case is a hole with a comment on top.

# ── DENY ─────────────────────────────────────────────────────────────────────
#  ⚠️ The heredoc is not decoration. Emitted as a bare line, the shell reads the
#     JSON as a command word, brace-expands it on its commas and tries to RUN it
#     — the hook then exits 127 with a mangled message and denies nothing. It
#     fails silently open, which is the expensive direction. Quoted delimiter so
#     nothing inside is expanded.
cat <<'JSON'
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"BLOCKED: this uploads to production without passing the QA receipt gate. A contrast fix once sat in the repository for hours with every gate green while production kept serving the old CSS: nobody checks AFTER uploading, and 'I ran the QA' is a claim nobody verifies. DO IT LIKE THIS: 1) perl gates/qa-master.pl <URL> --repo <REPO> --candidate   (writes <REPO>/.qa-receipt with the md5 of the deployable tree); 2) bash gates/deploy.sh <REPO>   to rehearse without uploading; 3) add --upload once it is green: it checks the receipt, uploads, and then verifies that what is served is what was measured (G11). The receipt expires after 12 h and is valid ONLY for the exact tree that was measured: touch one file and it must be measured again. WATCH THE COLLATERAL DAMAGE: this block kills the WHOLE command. If local work came first (a heredoc writing a file, a mkdir), THAT WORK DID NOT HAPPEN, and the next command's 'No such file or directory' is a consequence of this block, not a new fault: split the command and leave the uploading part out. If this genuinely is not a deploy - a copy to /tmp, a backup, a DOWNLOAD from production (remote -> local), or writing to a tools server that serves no site - reword the command, or add an exemption following the three rules in section 6 of the hook."}}
JSON
