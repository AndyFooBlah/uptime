# uptime

Probes and post-deploy smoke tests for AndyFooBlah's live apps.

- **`probe.yml`** checks every target over HTTP each hour, and loads each UI in headless Chromium once a day at 15:41 UTC. A failing check opens an issue titled `Down: <target> (<check>)`, assigned to the owner, and closes it when the check passes again. Each check gets 3 tries, 20 s apart, so a scale-to-zero cold start doesn't count as an outage.
- **`smoke/`** is a composite action that app repos run at the end of a deploy:

  ```yaml
  - uses: AndyFooBlah/uptime/smoke@main
    with:
      url: https://example.web.app
      ui-text: Continue with Google
  ```

  It fails the deploy job if the page doesn't load with the expected status, or doesn't render the expected text, or throws an uncaught error.

GitHub's own cron runs hours late on this account, so the hourly run is started by **`dispatcher/`**: a Cloud Scheduler job (`41 * * * *` UTC) runs a small Cloud Workflow that calls the `workflow_dispatch` API. Its token, a fine-grained PAT that can only touch this repo's Actions, lives in Secret Manager (`dispatcher/store-token.sh`). The GitHub cron stays on as a watchdog: when it fires and no dispatched run has happened for three hours, it opens `Down: dispatcher (schedule)` and probes in its place. The dispatcher costs about $0.16 a month (see `dispatcher/setup.sh`).

Targets live in the `PROBE_TARGETS` repository secret, a JSON array documented at the top of `probe.mjs`, so private apps' URLs stay out of this public repo. Private apps appear in logs and issues only under neutral aliases. Errors are scrubbed of URLs before they're printed.

The probes only touch static pages, health routes and auth gates. They never sign in, and never call anything that costs money.

License: Apache-2.0.
