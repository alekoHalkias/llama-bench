# Install guide

This sets up model-bench on a Linux machine with an NVIDIA GPU. It is written from the author's setup (Arch Linux,
RTX 4080 16 GB, 32 GB RAM). Other platforms and GPUs should work if llama.cpp builds there, but they haven't been tried.
The tools are bash and Python scripts, so macOS may work too; that is untested.

See [REQUIREMENTS.md](REQUIREMENTS.md) for the full list with versions.

## 1. Install the prerequisites

| Need | Check | Get it |
|---|---|---|
| bash 4+, curl, git, tar, awk, `column`, coreutils | `bash --version; column --version` | your package manager (`column` is in util-linux, or `bsdextrautils` on Debian/Ubuntu) |
| Python 3 (standard library only) | `python3 --version` | your package manager |
| Claude Code CLI | `claude --version` | https://claude.com/claude-code |
| llama.cpp's `llama-server` | `llama-server --version` | step 2 |
| llama-swap | `llama-swap --version` | step 3 |

Make sure `~/.local/bin` is on your `PATH`; `install.sh` puts the commands there.

## 2. Build llama.cpp

The config expects `llama-server` at `~/Github/llama.cpp/build/bin/llama-server`. Use a recent build: the config uses
`--load-mode`, `--metrics`, `--n-cpu-moe`, `--spec-type draft-mtp` and `--reasoning-budget`, and older builds don't
all have them. The author's build is `0.7.0-dev (build 11824)`.

```bash
git clone https://github.com/ggml-org/llama.cpp ~/Github/llama.cpp
cd ~/Github/llama.cpp
cmake -B build -DGGML_CUDA=ON          # drop -DGGML_CUDA=ON for a CPU-only build
cmake --build build --config Release -j
```

Keep `--metrics` on the command: model-bench reads its counters for the token-speed columns.

## 3. Install llama-swap

Download a release binary from https://github.com/mostlygeek/llama-swap/releases and put it on your `PATH`:

```bash
install -m 755 llama-swap ~/.local/bin/llama-swap
```

The author uses `v265`.

## 4. Get this repo and link it

```bash
git clone https://github.com/alekoHalkias/llama-bench ~/Documents/llama-bench     # anywhere you like
cd ~/Documents/llama-bench
./install.sh
```

`install.sh` symlinks the six commands into `~/.local/bin` and `llama-swap/config.yaml` into
`~/.config/llama-swap/config.yaml`. Existing files there are kept as `*.bak`. It also tells you if `llama-swap`,
`llama-server` or `claude` is missing. The scripts find the repo through their own symlinks, so you can move the
folder later by running `./install.sh` again.

## 5. Download models and edit the config

`llama-swap/config.yaml` defines the models. Each entry points at a GGUF file under `~/models/` (the config writes
`${env.HOME}/models/...`; llama-swap fills in your home folder):

| Model id | Expected file |
|---|---|
| `qwen3.6-mtp` | `~/models/qwen3.6-35b-mtp/Qwen3.6-35B-A3B-UD-Q4_K_M.gguf` |
| `gpt-oss-20b` | `~/models/gpt-oss-20b/gpt-oss-20b-MXFP4.gguf` |
| `qwen3-coder-30b` | `~/models/qwen3-coder-30b/Qwen3-Coder-30B-A3B-Instruct-UD-Q4_K_XL.gguf` |
| `gemma4-26b` | `~/models/gemma4-26b/gemma-4-26B-A4B-it-UD-Q4_K_XL.gguf` |
| `strata-coder-iq1_m` | optional, see step 6 |

About 70 GB in total for the four GGUFs. For `qwen3.6-mtp` you need the MTP variant, because the regular Unsloth
GGUF has no MTP layers:

```bash
pip install -U "huggingface_hub[cli]"
hf download unsloth/Qwen3.6-35B-A3B-MTP-GGUF Qwen3.6-35B-A3B-UD-Q4_K_M.gguf --local-dir ~/models/qwen3.6-35b-mtp
```

Find the others on Hugging Face under the file names above. Then edit the config:

1. **Move or re-point paths if yours differ.** Everything is under `${env.HOME}` (`~/models`, `~/Github/llama.cpp`), so nothing
   needs editing if you used those folders. Check with `llama-swap -config llama-swap/config.yaml -validate`.
2. **Delete models you don't want** (a whole entry, plus any profile that pins it). Only list models you have.
3. **Retune `--n-cpu-moe` and `-c` for your GPU.** `--n-cpu-moe N` keeps the experts of N layers on the CPU. The values
   in the file fit a 16 GB card at 64k context. A smaller card needs a higher N; a bigger one can use a lower N.

The `hooks.on_startup` block loads the `qwen` profile when llama-swap starts. Remove it if you don't want a model
loaded at startup.

## 6. Optional: Strata

`strata-coder-iq1_m` runs [Strata](https://github.com/Niko1221/Strata)'s own engine instead of llama-server. Install
it by following Strata's own instructions, with its Coder model, then check that
`~/Github/Strata/strata-coder-iq1_m.json` exists. If you don't use Strata, delete that block from the config.

## 7. Check it works

```bash
swap                                        # terminal 1; leave running
curl -s localhost:8001/v1/models            # terminal 2: lists the model ids
MODELS="gemma4-26b" model-bench
```

The last command loads the model (it can take minutes the first time), runs one task, then prints the run's
`results.csv` as a table (model, project, task, seconds, turns, check, ...) and the folder it saved to under
`results/`. A `pass` in the `check` column means the task's check succeeded. Then `model-stats` summarises it.

You can also open llama-swap's web page at http://localhost:8001/ui/ to see models load and unload.

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| `llama-swap not reachable at http://localhost:8001` | `swap` isn't running, or you set `BASE_URL`/`LISTEN` differently. |
| `No task files in ...` | `TASKS_DIR` points at a folder with no `.md` files. Unset it to use `standalone/`. |
| `claude not found on PATH` | Install the Claude Code CLI and log in once with `claude`. |
| A model shows `load-failed` | Read `results/<run>/<model>.load.log`: usually a wrong path in the config, not enough VRAM or RAM (raise `--n-cpu-moe`), or a llama.cpp build too old for a flag. |
| Token columns are `-` | The model's server doesn't expose llama-server's `/metrics` counters, or `--metrics` was removed from the `server` macro. |
| `llama-swap` rejects the config | A model id or profile points at something you deleted. Remove both sides. |
| The run stops when the laptop sleeps | `model-bench` uses `systemd-inhibit` when it is available; without systemd, disable sleep yourself. |

## Uninstall

Remove the symlinks `install.sh` made:

```bash
rm ~/.local/bin/{model-bench,swap,model-stats,model-failures,model-purge,model-recheck}
rm ~/.config/llama-swap/config.yaml          # and restore config.yaml.bak if install.sh made one
```
