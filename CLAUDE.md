# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A bash benchmark that runs the same Claude Code prompt (`claude -p`) against each local model behind llama-swap. The models read a separate **linked project** (the path argument to `model-bench`, else `PROJECT`, else the `project` symlink) and write new files; they never change it. With no project at all, tasks run **standalone** (project `none`): no snapshot, no `--add-dir`, just the prompt. This repo is not the linked project, and the tools must not name or assume a specific one. README.md has the layout, settings table and known issues.

## Commands

```bash
./install.sh                                   # symlink bin/* and llama-swap/config.yaml into ~/.local/bin and ~/.config/llama-swap
swap                                           # start llama-swap on localhost:8001 (needed before any run)
MODELS="qwen3.6-mtp" model-bench               # quick single-model run, no project
model-bench                                    # every model x every task in standalone/, no project
model-bench -l 3                               # 3 passes per model on one load, into results/<run>-p1..p3
TASKS_DIR=<tasks> model-bench /path/to/project # tasks written for that project
model-stats                                    # per-model/project/task averages over all runs -> results/stats.csv
model-failures                                 # every failed result with evidence -> results/failures.md
model-recheck                                  # re-run each task's current check on all saved results, update results.csv
model-purge                                    # interactive: optional zip backup to backups/, then delete results/
RESULTS=/some/dir model-failures               # RESULTS (and BACKUPS for model-purge) point the tools at other folders, e.g. a test copy
bash -n bin/model-bench                        # syntax check; there are no tests or linters
```

Running `model-bench` while llama-swap is up starts a real run, which loads models (minutes) and writes `results/<run>/`. Don't run it yourself: give the user the launch command. With `MODELS` unset in a terminal, it shows an inline checklist of the llama-swap models (all ticked; the `pick` function, plain bash). Set `MODELS`, or run without a terminal, to skip it. To test the checklist, run the script under `script -qec` and pipe keys in, holding stdin open afterwards (`( sleep 1; printf '\e[B \r'; sleep 2 ) | script ...`). Up/down or k/j move, space toggles, `a` ticks all/none, Enter starts, `q` cancels; a lone Esc does nothing. Always end the keys with Enter or `q`, or the test hangs. To test script changes, run it with a fake `claude` on `PATH`, a tiny fake HTTP server as `BASE_URL` (`/health`, `/v1/models`, and `/v1/messages` returning `{"content": [...]}`), and `OUT`, `PROJECT` and `TASKS_DIR` set to scratch folders.

## How it fits together

- Every script in `bin/` finds this folder from its own resolved path (`readlink -f`). They're used through the `~/.local/bin` symlinks, so keep that pattern: never hardcode this folder's path.
- Per model: the script writes `results/<run>/settings-<model>.json`, which points every Claude Code tier (`ANTHROPIC_*_MODEL`, the subagent model) at llama-swap. It then sends a one-token warm-up request. If no content comes back, it records `load-failed` and saves the response and llama-swap's upstream log tail to `<model>.load.log`.
- Once per run: a snapshot of `PROJECT` goes into a `mktemp -d` folder (`$SRC`). For a git repo top level it is `git archive $REF`; for any other folder it is a tar copy without `.git` and `node_modules`. Then `STRIP` (agent-instruction files) is deleted and everything is made read-only. The temp folder is outside any repo on purpose, so no parent `CLAUDE.md` or project settings load. It is removed on exit. `run.txt` records the project and version.
- Per task: an empty folder under the same temp dir is the cwd. `claude -p` runs there with `--add-dir $SRC`, a deny rule on editing `$SRC`, Claude Code's full default tool set and `bypassPermissions` (models can run any command on this machine). With a project, the script puts a preamble before the task prompt that names `$SRC` as read-only and the cwd as the output folder. Standalone, the prompt is the task file alone (minus its `# check:` line). Afterwards the folder is copied to `results/<run>/<model>--<task>/`, turns and `is_error` are parsed from the stream-json log, and the task's `# check:` line runs in the copy with `bash -xc`.
- Task file format: the whole `.md` file is the prompt. An optional first line `# check: <cmd>` is stripped from the prompt. Because the check runs in the output folder, tasks must ask for a fixed output layout the check can find. `TASKS_DIR` is made absolute and exported to the check along with `MODEL` (also by `model-recheck`), and `[llm model name]` in the prompt is replaced with the model id, so validators live next to their task as `<name>_test.py`, outside the model's reach.
- `standalone/filetypes_test.sh` runs the model's `rank-<model>.sh` from a different cwd on a fixed fixture folder and diffs its `.txt` against the known answer. When changing a validator, test it against a known-good solution and a broken one, not just a model's output. `TASKS_DIR` defaults to `standalone/`.
- `results.csv` columns: `model,project,task,seconds,turns,check,error,files`, then token stats from llama-server's `/metrics` counters (before/after each task, so `--metrics` must stay in the config macro; `metrics()` falls back to `/metrics/prometheus` for Strata, whose `/metrics` is JSON): `prompt_tokens,cached_tokens,prompt_s,prompt_tps,prompt_ms_tok,gen_tokens,gen_s,gen_tps,gen_ms_tok`. `model-stats` and `model-failures` only read runs whose CSV has a `files` column (the current design), and group by model, project and task.
- Results are handed off by hand: the user copies a model's output folder into the linked project to try it.
- Model ids come from `llama-swap/config.yaml` via `/v1/models`. Ids named `local`/`local-*` are profile pins and are skipped. Ids starting with `claude-` (Haiku, Sonnet and Opus 5.5 are listed unticked in the checklist, never in `MODELS=all`) go to Anthropic's API with the user's own login, with no warm-up and `-` token stats. `strata-*` entries run Strata's own server (`sh -c "cd ~/Github/Strata && ..."`), not llama-server, and need that install. The config finds llama-server and the GGUF weights, which live outside this repo, through `${env.HOME}` (llama-swap expands it and rejects an unset variable); check edits with `llama-swap -config llama-swap/config.yaml -validate`.

## Gotchas

- Runs use `--setting-sources project,local`, so the user's `~/.claude/settings.json` (plugins, hooks) doesn't load; the `--settings` file still does. Don't use `--bare`: it limits the tool set to Bash, Edit and Read. Check the `init` line of a `.jsonl` log to see the tools a model actually had.
- `results/` ships empty (only `results/.gitkeep` is tracked), so runs are local data and never committed. `backups/`, the `project` symlink, `*.bak` and `.claude/settings.local.json` are git-ignored because they are local to this machine.
- Thinking levels are not normalised: each model runs at its own default (set by its chat template or llama-swap flags), and Strata at high. A `reasoning_effort` in a Strata config changes results, so keep those runs apart.
