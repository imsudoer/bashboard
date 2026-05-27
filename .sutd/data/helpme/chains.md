# Command Chains (chain)

Save sequences of commands as named pipelines.

## Create
    chain new deploy
    chain add deploy "git pull"
    chain add deploy "npm install"
    chain add deploy "pm2 restart api"

## Run
    chain run deploy                # all in sequence
    chain run deploy -c             # confirm each step

## Manage
- `chain ls` — list chains
- `chain show deploy` — show steps
- `chain rm deploy` — delete
- `chain edit deploy` — edit in $EDITOR
