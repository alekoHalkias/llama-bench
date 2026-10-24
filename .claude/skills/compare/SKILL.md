---
name: compare
description: Analyze one or more model-bench runs in results/ and compare how each model did on each task, from results.csv down to the logs and diffs. Use when the user runs /compare [run...], asks how a run went, which model did best, or why a model failed.
---

# /compare - analyze benchmark runs

Read-only. Never run `model-bench` here; it starts a real run.

## Inputs

Args are run names (`20261022-1756`). With none, use the newest folder in `results/`. With "all", use every run.

Per run, `results/<run>/` holds:
- `results.csv`: `model,project,task,seconds,turns,check,error,files`. Runs before 20261022-1848 used the old worktree design (columns `...,skill_used,check,error[,branch]`, the linked project's CLAUDE.md workflow, a wrong theme check); don't compare them with newer runs. Empty turns/error means the log had no `result` line (the run crashed or was cut off).
- `run.txt`: the linked project's path and version (git ref and commit, or folder copy) for that run.
- `<model>--<task>/`: the files the model wrote (its whole output folder).
- `<model>--<task>.jsonl`: stream-json log. The first line can be a plain-text warning, so skip lines that are not JSON. Tool calls are `tool_use` items in `message.content`; the final `{"type":"result"}` line has `num_turns`, `is_error`, `result`.
- `<model>--<task>.check.log`: `bash -x` trace of the task's `# check:` line, run in the output folder.
- Old runs only: `.diff`, `.notes.md`, and branches `bench/<run>/*` in the linked project.

## Steps

Run `model-stats` (averages across runs) and `model-failures` (writes `results/failures.md` with the evidence for every failure, including llama-server output for load failures in `<model>.load.log`) first, and build on what they show.

1. Print `results.csv` for each run as a table. Across several runs, group by model and task and show the min/max of seconds and turns. Results vary a lot between runs, so call out spread and don't rank on a single run.
2. For each model/task, find out why it ended the way it did:
   - `load-failed`: no log; it is a llama-swap or llama-server problem, not a model result.
   - Check failed: read `.check.log` to see which condition failed, then decide whether the check itself is wrong (the task file's `# check:` line) or the model did the task badly.
   - Look at the tool-call sequence in the `.jsonl`: denied tools or attempts to edit the read-only source, files written outside the output folder, loops re-reading the same files, giving up early.
3. Judge the work itself from the output folder against the task prompt and the real code of the linked project (the path in `run.txt`, or the `project` symlink). Find the code the task is about and check the output against it: is every expected file there, does it follow the project's real conventions and names, and are the model's notes accurate?
4. Report a short table per task (model, pass/fail, time, turns, one-line verdict), then the cross-model patterns and any problem with the task or check that should be fixed before the next run.
