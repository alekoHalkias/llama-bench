#!/usr/bin/env bash
# Validator for filetypes.md. Run from the model's output folder, with MODEL set to the model id.
# Runs rank-<model>.sh on a fixed folder and diffs <model>_<date>.txt against the known answer.
set -u
s=rank-$MODEL.sh
[[ -f $s ]] || { echo "FAIL: no $s, found: $(ls)"; exit 1; }
others=$(find . -type f ! -name "$s" ! -name '*.txt')
[[ -z $others ]] || { echo "FAIL: files besides the script and its .txt:"; echo "$others"; exit 1; }

t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
d=$t/Downloads
mkdir -p "$d/sub/deeper" "$d/folder.d" "$t/run" "$t/cwd"
touch "$d/a.PDF" "$d/b.pdf" "$d/my file.pdf" "$d/sub/deeper/c.pdf" \
      "$d/x.JPG" "$d/sub/y.jpg" "$d/z.zip" "$d/old backup.zip" "$d/x.tar.gz" "$d/sub/y.tar.GZ" "$d/README"
expected='4 pdf
2 gz
2 jpg
2 zip
1 none'

# Run a copy from a different cwd, so a script that writes to its cwd instead of its own folder fails.
cp "$s" "$t/run/"
( cd "$t/cwd" && bash "$t/run/$s" "$d" ) || { echo "FAIL: script exited $?"; exit 1; }
txt=$t/run/${MODEL}_$(date +%F).txt
[[ -f $txt ]] || { echo "FAIL: no $(basename "$txt") next to the script, found: $(ls "$t/run" "$t/cwd")"; exit 1; }
echo "--- $(basename "$txt")"; cat "$txt"
# ponytail: whitespace is collapsed, so "uniq -c" padding or tabs still pass
diff <(echo "$expected") <(awk 'NF { $1 = $1; print }' "$txt") || { echo "FAIL: output differs from expected (< expected, > got)"; exit 1; }
echo PASS
