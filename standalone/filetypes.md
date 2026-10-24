# check: bash "$TASKS_DIR/filetypes_test.sh"
Write a bash script that counts the files in a folder by file type and ranks the types from most to least files.

Save it as exactly this file: [results folder]/rank-[llm model name].sh
Create the file with your file-writing tool. Showing the script in your reply does not count. Create no other files. Don't run the script on a real folder, or delete what it writes if you do.

Rules the script must follow exactly:
- Usage: `bash rank-[llm model name].sh [FOLDER]`. FOLDER defaults to `~/Downloads`.
- Count every regular file under FOLDER, including files in subfolders at any depth and hidden files. Folders themselves are not counted. File and folder names may contain spaces.
- A file's type comes from its file name only, never from the rest of the path. Folder names can contain dots: in `/tmp/tmp.Ab12/README` the type comes from `README`, not from the folder name.
- The type is the text after the last `.` in the file name, lowercased: `a.PDF` is `pdf` and `x.tar.gz` is `gz`. A file whose name has no `.` has the type `none`.
- Output is one line per type: the count, one space, the type, e.g. `4 pdf`. No header, title, date, padding or any other lines.
- Sort by count, highest first. Types with the same count go in alphabetical order (a to z), so `2 gz` comes before `2 jpg`, which comes before `2 zip`. A plain `sort -r` or `sort -rn` reverses that order too. `sort -k1,1nr -k2,2` sorts both ways correctly.
- Write the output to `[llm model name]_YYYY-MM-DD.txt`, with today's date from `date +%F`, in the folder the script itself is in. The script will be run from a different folder, so don't use the current directory. Find the script's own folder with `"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"`. Overwrite the file if it exists.
- Do all the work in bash. Don't hand it to `sh -c`, which lacks bash features like `${x,,}`.

Example. For this folder:

```
docs/report.PDF
docs/old notes.pdf
photos.2024/beach.jpg
photos.2024/sunset.JPG
backup.tar.gz
Makefile
```

the output file contains exactly:

```
2 jpg
2 pdf
1 gz
1 none
```
