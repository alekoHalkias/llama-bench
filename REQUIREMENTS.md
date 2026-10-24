# Requirements

There are no packages to install for the scripts themselves: they are bash, plus Python scripts that use only the
standard library. What you need is the surrounding software, the models and enough hardware.

## Software

| Requirement | Used for | Tested with |
|---|---|---|
| Linux (x86-64) | everything; `systemd-inhibit` is used when present | Arch Linux |
| bash 4+ | `model-bench`, `swap`, `install.sh` (`mapfile`, arrays) | 5.3 |
| Python 3 | `model-stats`, `model-failures`, `model-recheck`, `model-purge` (standard library only) | 3.14 |
| curl | health checks, warm-up, metrics | 8.23 |
| git, tar | project snapshots (`git archive`, tar copy) | git 2.56 |
| `column` (util-linux; `bsdextrautils` on Debian/Ubuntu) | prints the results table at the end of a run | |
| awk, readlink, mktemp, timeout | coreutils / standard tools | |
| [Claude Code](https://claude.com/claude-code) CLI (`claude`) | runs each task | 2.1.304 |
| [llama.cpp](https://github.com/ggml-org/llama.cpp) `llama-server` | serves the models; needs `--load-mode`, `--metrics`, `--n-cpu-moe`, `--spec-type draft-mtp`, `--reasoning-budget` | 0.7.0-dev, build 11824 |
| [llama-swap](https://github.com/mostlygeek/llama-swap) | one endpoint that loads models on demand | v265 |
| `systemd-inhibit` (optional) | keeps the machine awake during a run | systemd |
| `nvidia-smi` (optional) | llama-swap's GPU monitoring | |

A Claude Code login is required even for local-only runs, because the CLI must start. `claude-*` model ids also use it
for real API calls, which cost quota.

## Hardware

The shipped config is tuned for:

- **GPU:** NVIDIA, 16 GB VRAM (RTX 4080)
- **RAM:** 32 GB. Mixture-of-experts models keep some layers' experts in system RAM (`--n-cpu-moe`).
- **Disk:** about 70 GB for the four default GGUF files, plus about 32 MB per 50 saved runs in `results/`.

Smaller cards should work with a higher `--n-cpu-moe` and a smaller `-c` (context), but slower; this is untested. The
models are large (12 to 22 GB files), so plan for enough RAM to hold what the GPU doesn't. A CPU-only llama.cpp build
should work too, much more slowly.

## Models

Defined in `llama-swap/config.yaml`; you can use any GGUF that llama-server can load.

| Model id | File | Notes |
|---|---|---|
| `qwen3.6-mtp` | `Qwen3.6-35B-A3B-UD-Q4_K_M.gguf` | From `unsloth/Qwen3.6-35B-A3B-MTP-GGUF`. Needs the MTP variant; one slot (`-np 1`). |
| `gpt-oss-20b` | `gpt-oss-20b-MXFP4.gguf` | |
| `qwen3-coder-30b` | `Qwen3-Coder-30B-A3B-Instruct-UD-Q4_K_XL.gguf` | |
| `gemma4-26b` | `gemma-4-26B-A4B-it-UD-Q4_K_XL.gguf` | Thinking is off (`--reasoning-budget 0`). |
| `strata-coder-iq1_m` | installed by [Strata](https://github.com/Niko1221/Strata) | Optional. Needs a 32 GB-RAM machine and Strata's own setup. |

## Network and accounts

- Hugging Face (to download models) and GitHub (llama.cpp, llama-swap).
- A Claude Code login.
- llama-swap listens on `localhost:8001` by default. Opening it to your network with `LISTEN=0.0.0.0:8001 swap`
  lets anyone on that network use your models; don't do that on an untrusted network.

## Safety

Runs use Claude Code's `bypassPermissions` mode, so a model can run any command as your user. Use a machine and an
account where that is acceptable.
