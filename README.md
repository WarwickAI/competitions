# competitions
GitHub Action used to manage Warwick AI's competition leaderboards.

## Final testing

CI scores each submission with the team's own copy of the scoring code, so leaderboard scores can be faked. `results/` re-scores every team with the official template's scoring code instead, each in its own container with no network or secrets.

1. Download each team's best submission from before the deadline, from the website repo:
   ```sh
   PROJECT_ID=snake BLOB_READ_WRITE_TOKEN=... npx astro db execute db/download-snapshots.ts --remote
   ```
2. Clear those credentials from your shell (the next step runs students' code), then run:
   ```sh
   STUDENT_FILES="myAI.py myEnv.py model.zip" \
   EXTRA_PACKAGES="gymnasium>=1.0 stable-baselines3>=2.4" \
     ./results/run.sh ../website/snapshots/snake ../snake-comp
   ```

- `STUDENT_FILES` are the template files teams are meant to edit. Every other template file comes from the template's last commit, and any files a team added are kept.
- `EXTRA_PACKAGES` are dependencies the template leaves commented out. Everything is installed into the image up front, since containers have no network.
- `TIMEOUT` (seconds per team, default 3600), `MEMORY` (default `4g`) and `CPUS` (default `2`) set the per-team limits.

Results go to `results.csv` in the snapshots folder, with each team's CI score, final score, and any template files they edited (these were replaced with the official ones, so check why). Each team's output is in `logs/`.

Team code still runs in the same Python process as the game, so a determined team could patch the engine at runtime. Read through the top entries before announcing results.
