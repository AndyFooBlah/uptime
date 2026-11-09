#!/bin/bash
# Deploys the dispatcher: a Cloud Workflow that starts probe.yml, run hourly by
# Cloud Scheduler. Safe to re-run. The GitHub token goes in separately, with
# store-token.sh.
#
# Cost: one Scheduler job ($0.10 a month, since the billing account already
# uses its 3 free jobs); ~720 runs a month, about 2,200 internal and 720
# external Workflows steps, inside the 5,000 / 2,000 monthly free tier; one
# secret version (~$0.06 a month) and ~720 secret reads (free under 10,000).
set -euo pipefail
P=andybrook-uptime
L=us-west1
SA=uptime-dispatch@$P.iam.gserviceaccount.com
cd "$(dirname "$0")"

gcloud services enable workflows.googleapis.com workflowexecutions.googleapis.com \
  cloudscheduler.googleapis.com secretmanager.googleapis.com --project "$P"
# A new project's Workflows service agent isn't created until asked for.
gcloud beta services identity create --service workflows.googleapis.com --project "$P" --format none
gcloud iam service-accounts describe "$SA" --project "$P" >/dev/null 2>&1 ||
  gcloud iam service-accounts create uptime-dispatch --project "$P" --display-name "Runs the uptime probe dispatcher"
gcloud secrets describe github-probe-dispatch --project "$P" >/dev/null 2>&1 ||
  gcloud secrets create github-probe-dispatch --project "$P" --replication-policy automatic
gcloud secrets add-iam-policy-binding github-probe-dispatch --project "$P" \
  --member "serviceAccount:$SA" --role roles/secretmanager.secretAccessor --format none
for role in roles/workflows.invoker roles/logging.logWriter; do
  gcloud projects add-iam-policy-binding "$P" --member "serviceAccount:$SA" --role "$role" --condition None --format none
done

gcloud workflows deploy probe-dispatch --project "$P" --location "$L" \
  --source workflow.yaml --service-account "$SA"

uri="https://workflowexecutions.googleapis.com/v1/projects/$P/locations/$L/workflows/probe-dispatch/executions"
args=(--project "$P" --location "$L" --schedule "41 * * * *" --time-zone UTC --uri "$uri"
  --http-method POST --message-body '{}' --oauth-service-account-email "$SA"
  --attempt-deadline 60s --max-retry-attempts 2)
if gcloud scheduler jobs describe probe-dispatch --project "$P" --location "$L" >/dev/null 2>&1; then
  gcloud scheduler jobs update http probe-dispatch "${args[@]}"
else
  gcloud scheduler jobs create http probe-dispatch "${args[@]}"
fi
