# ScoreBook Cloud Functions

## What runs here

`purgeOldMatches` — a scheduled function that runs **daily at 03:30 IST**
and deletes any data in Realtime Database older than 14 days:

- `/matches/{matchCode}`
- `/user_matches/{phone}/{matchCode}`
- `/tournaments/{tournamentId}`

The cutoff is computed against the `updatedAt` server timestamp that the
client writes alongside every push. If a node has no `updatedAt`, it is
left alone (defensive — better to keep an extra week of data than to
delete something we shouldn't).

## First-time deploy

```bash
cd functions
npm install
firebase deploy --only functions
```

You need:
- Node 20 locally
- `firebase-tools` installed (`npm i -g firebase-tools`)
- The Firebase project on the **Blaze (pay-as-you-go) plan** — scheduled
  functions require Cloud Scheduler, which is not available on Spark.

The Blaze plan is required only for the daily scheduler — daily ingest
runs costs typically pennies per month for a single-app workload.

## Disable / re-enable

To stop the cleanup (e.g. during testing):

```bash
firebase functions:delete purgeOldMatches --region us-central1
```

To resume, re-run `firebase deploy --only functions`.

## Manual one-off purge

If you need to wipe old data without waiting for the schedule:

```bash
firebase functions:shell
> purgeOldMatches({})
```

Or trigger via Cloud Scheduler in the GCP console → "Run now".

## Client-side fallback

`lib/services/firebase_purge_service.dart` contains a best-effort
client-side sweep that runs whenever the user opens the app. It only
deletes matches *the user themselves owns* (entries under
`/user_matches/{their phone}/`) and the corresponding `/matches/{code}`
node. This way new installs don't have to wait up to 24 hours for the
cron to catch up after the user's last session.

The cloud function remains the authoritative cleaner — the client is a
convenience layer.
