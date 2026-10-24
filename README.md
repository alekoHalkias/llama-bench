# llama-bench

A small bash benchmark that gives the same [Claude Code](https://claude.com/claude-code) task (`claude -p`) to each
local model served by [llama-swap](https://github.com/mostlygeek/llama-swap), then records how each one did: time,
turns, a pass/fail check, files written, and token speeds.

It answers one question: *which of my local models can drive a coding agent well enough to finish real tasks, and how
fast?*

- Every model runs the **same prompt** with Claude Code's full default tool set, in its own empty folder.
- A task's `# check:` line decides pass or fail, so results don't depend on reading the model's output by eye.
- Several passes per model (`-l 3`) show how much a result varies from run to run.
- Tasks can run **standalone** (just the prompt) or against a read-only snapshot of a **linked project**.

The commands are named `model-bench`, `swap`, `model-stats` and so on. (llama.cpp ships its own, unrelated
`llama-bench`; this repo doesn't replace it.) This repo is a personal tool shared as-is. The model list in `llama-swap/config.yaml` is tuned for one machine
(16 GB GPU, 32 GB RAM); see [INSTALL.md](INSTALL.md) to adapt it and [REQUIREMENTS.md](REQUIREMENTS.md) for what you need.

## Quick start

```bash
git clone https://github.com/alekoHalkias/llama-bench && cd llama-bench
./install.sh                                  # links bin/* into ~/.local/bin and the config into ~/.config/llama-swap
# edit llama-swap/config.yaml: model paths and llama-server path (see INSTALL.md)

swap                                          # terminal 1: llama-swap on http://localhost:8001
model-bench                                   # terminal 2: tick the models to run, then Enter
```

`model-bench` loads each model in turn, which takes minutes per model, and writes `results/<run>/`.
Then:

```bash
model-stats                                   # per-model averages over every run -> results/stats.csv
model-failures                                # every failed result, with its evidence -> results/failures.md
```

Run it more than once before comparing models. Results vary from pass to pass, so use `-l 3` or more:

```bash
model-bench -l 5                              # 5 passes per model on one load, into results/<run>-p1 .. p5
MODELS="gemma4-26b qwen3.6-mtp" model-bench   # skip the checklist
```

## How a run works

1. **Warm-up.** Per model, `model-bench` writes `settings-<model>.json`, which points every Claude Code model tier
   (Opus, Sonnet, Haiku, the subagent model) at llama-swap, and sends a one-token request. If nothing comes back, the
   model is recorded as `load-failed` with llama-swap's log tail saved.
2. **Snapshot** (linked-project runs only). The project is copied once into a temp folder outside any repo, so no
   parent `CLAUDE.md` or project settings load. Agent-instruction files (`CLAUDE.md`, `.claude`, ...) are removed and
   everything is made read-only. It is deleted when the run ends.
3. **Task.** `claude -p` runs in an empty output folder with `--add-dir` for the snapshot, a deny rule on editing it,
   and `bypassPermissions`. The task file is the prompt.
4. **Result.** The folder is copied to `results/<run>/<model>--<task>/`, turns and errors are read from the stream-json
   log, and the task's `# check:` line runs inside the copy.

> **Warning:** runs use `bypassPermissions`, so a model can run **any command on your machine**. Run this on a machine
> and in an account where that is acceptable.

## Tasks

A task is one `.md` file in `TASKS_DIR`; the whole file is the prompt. An optional first line `# check: <command>` is
removed from the prompt and run afterwards in the output folder (exit code 0 means pass).

```markdown
# check: bash "$TASKS_DIR/filetypes_test.sh"
Write a bash script that counts the files in a folder by file type and ranks the types ...
Save it as exactly this file: [results folder]/rank-[llm model name].sh
```

- `$TASKS_DIR` (absolute) and `$MODEL` are available to the check, so a validator can sit next to its task, outside the
  model's reach.
- `[llm model name]` in the prompt is replaced with the model id, and `[results folder]` with the output folder.
- Because the check runs in the output folder, ask for a fixed output layout the check can find.

`standalone/` holds the included task, `filetypes`, with its validator, and is the default `TASKS_DIR`. Point
`TASKS_DIR` at your own folder to run other tasks.

To run against a project, pass its path: `TASKS_DIR=~/my-tasks model-bench ~/code/my-project`. The project is read,
never changed. Tasks are written for a particular project, so keep each project's tasks in their own folder.

## Settings (environment variables)

| Variable | Default |
|---|---|
| `PROJECT` | The path argument, else this variable, else a `project` symlink in the repo. With none, tasks run standalone (project `none`). |
| `TASKS_DIR` | `standalone/` in the repo |
| `MODELS` | Unset: an inline checklist of the llama-swap models in a terminal. `all`: every model, no checklist. Or a space-separated list of ids. Without a terminal, every model. |
| `REF` | `HEAD` (git projects only; the snapshot is `git archive $REF`) |
| `STRIP` | `CLAUDE.md CLAUDE.local.md AGENTS.md .claude` (removed from the snapshot) |
| `RUN` | `YYYYMMDD-HHMM` |
| `OUT` | `results/$RUN` |
| `BASE_URL` | `http://localhost:8001` |

Checklist keys: up/down or `k`/`j` to move, space to toggle, `a` to tick all or none, Enter to start, `q` to cancel.
Model ids named `local` or `local-*` are llama-swap profile pins and are skipped. Ids starting with `claude-` go to
Anthropic's API with your own login (they cost quota), are unticked by default and are left out of `MODELS=all`.

`model-stats`, `model-failures`, `model-recheck` and `model-purge` take `RESULTS=<folder>` to work on another folder;
`model-purge` also takes `BACKUPS=<folder>`.

## Results

`results/<run>/` contains `results.csv`, `run.txt` (project and version), `settings-<model>.json`, and per model and
task the files the model wrote, a `.jsonl` log and a `.check.log`.

`results.csv` columns: `model, project, task, seconds, turns, check, error, files`, then token stats read from
llama-server's `/metrics` counters before and after each task: `prompt_tokens, cached_tokens, prompt_s, prompt_tps,
prompt_ms_tok, gen_tokens, gen_s, gen_tps, gen_ms_tok`. This needs `--metrics` on the llama-server command, which the
`server` macro in `llama-swap/config.yaml` already has. Models that don't expose these counters show `-`.

## Tools

| Command | What it does |
|---|---|
| `model-bench` | The benchmark. |
| `swap` | Starts llama-swap with this repo's config (`LISTEN=0.0.0.0:8001 swap` to open it to your network). |
| `model-stats` | Averages per model, project and task over all runs: runs, passes, pass rate, load failures, seconds, turns, files, token speeds. |
| `model-failures` | Every failed result (load failure, session error, failed check) with its evidence, for finding root causes. |
| `model-recheck` | Re-runs each task's *current* check on every saved result. Use it after fixing a check. |
| `model-purge` | Deletes `results/`, after offering a zip backup to `backups/`. |

`.claude/skills/compare/` is a Claude Code skill (`/compare [run...]`) that reads `results/` and explains how each
model did. It never starts a run.

## Layout

```
bin/                    model-bench, swap, model-stats, model-failures, model-recheck, model-purge
llama-swap/config.yaml  model definitions (one llama-server command per model)
standalone/             the included task and its validator
results/                empty on install; one folder per run (and per pass with -l), not tracked by git
install.sh              links bin/* and the config into place
CLAUDE.md               notes for Claude Code when it works in this repo
.claude/                project settings and the compare skill
```

## Known issues

- **Results vary between runs.** The same model can take very different turn counts and times on the same task. Use
  several passes before comparing.
- **Allowed tools are not a hard limit.** Models have run shell commands even where Bash wasn't expected.
- **The config is machine-specific.** `llama-swap/config.yaml` finds llama-server and the GGUF files under `$HOME`
  (`~/Github/llama.cpp`, `~/models`), and its `--n-cpu-moe` values are chosen for a 16 GB GPU. Edit both for yours.
- **Strata entry.** The `strata-coder-iq1_m` model needs [Strata](https://github.com/Niko1221/Strata) installed at
  `~/Github/Strata`. Delete that block from the config if you don't use it.
- **Thinking levels differ by model.** Each model runs at its own default (gpt-oss at medium, Qwen3.6 with thinking
  on, Gemma with it off, and so on). The benchmark doesn't normalise this.

## License

GNU General Public License v3.0 or later. See [LICENSE](LICENSE).

Copyright (C) 2026 Aleko
