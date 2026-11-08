# uptime journal

Append-only. Each entry starts with a UTC timestamp and a tag.

- 2026-11-08T18:49Z [decision] Created as part of the dependency security program (AndyFooBlah/andy-private-docs#57). Owner chose a public repo with an hourly HTTP probe and a daily headless UI check, because public repos get free Actions minutes; private repos share 2,000 a month. Targets are kept in a secret, and private apps get aliases.
- 2026-11-08T18:49Z [step] First local run: all 23 targets pass (32 checks, including 9 UI). The failure path prints ENOTFOUND and timeouts with URLs scrubbed.
- 2026-11-08T21:04Z [step] Turned on Dependabot alerts and security updates, and added the standard dependabot.yml (npm + github-actions). Dependabot PRs here are merged by hand: the repo has no CI apart from the probe itself.
- 2026-11-08T21:31Z [friction] No scheduled run fired in the first ~2.5 h (cron "7 * * * *"; account Actions heavily congested by the rollout). Moved to "41 * * * *".
