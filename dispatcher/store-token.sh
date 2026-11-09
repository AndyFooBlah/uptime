#!/bin/bash
# Owner-run: stores the GitHub token the dispatcher uses, then runs the
# dispatcher once to prove it works.
#
# Token: a fine-grained PAT, resource owner AndyFooBlah, "Only select
# repositories" -> uptime, Repository permissions -> Actions: Read and write.
# Nothing else.
#
# The value is read from the macOS clipboard (pbpaste), stripped of whitespace,
# and piped to gcloud. It never touches disk or argv, and the clipboard is
# cleared afterwards.
set -euo pipefail
P=andybrook-uptime

read -rsp "Copy the GitHub token (starts github_pat_) to the clipboard, then press Enter. " _; echo
T=$(pbpaste | tr -d '[:space:]')
printf '    got %s… (%d characters)\n' "${T:0:11}" "${#T}"
case "$T" in github_pat_*) ;; *) echo "That doesn't look like a fine-grained GitHub token (github_pat_...). Nothing was stored." >&2; exit 1 ;; esac

code=$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $T" \
  "https://api.github.com/repos/AndyFooBlah/uptime/actions/workflows/probe.yml")
[ "$code" = 200 ] || { echo "GitHub rejected the token for the uptime repo's Actions (HTTP $code). Check: repository uptime, Actions: Read and write. Nothing was stored." >&2; exit 1; }

printf %s "$T" | gcloud secrets versions add github-probe-dispatch --project "$P" --data-file=- --format 'value(name)'
unset T
printf '' | pbcopy
echo "Stored (clipboard cleared). Running the dispatcher once…"
gcloud workflows run probe-dispatch --project "$P" --location us-west1 --format 'value(state,result)'
