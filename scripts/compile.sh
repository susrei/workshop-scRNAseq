#!/bin/sh

## COMPILE QMD FILES
##
## Description
## Evaluates and replaces meta variable shortcuts
## .qmd files are converted to .qmd files
## .qmd files with jupyter engine is converted to .ipynb
## The following directories are exprected:
## labs/seurat, labs/bioc, labs/scanpy
##
## Usage
## Run this script in the root of repo. It takes about 1 min to run.
## bash ./scripts/compile.sh

docker_site="ghcr.io/nbisweden/workshop-scrnaseq:2024-site-r4.3.0"

# set output directory for compiled output
output_dir="compiled"
# set input directories with qmd files to compile
input_dirs=("docs/labs/seurat" "docs/labs/bioc" "docs/labs/scanpy")

# fail on error
set -e

# check if in the root of the repo
# if [ ! -f "_quarto.yml" ]; then
#     echo "Error: Are you in the root of the repo? _quarto.yml is missing."
#     exit 1
# fi

# check if these directories exist
error=false
for dir in "${input_dirs[@]}"; do
    if [ ! -d "$dir" ]; then
        echo "Error: Directory '$dir' does not exist."
		exit 1
        # error=true
    fi
done

# if [ "$error" = true ]; then
#     exit 1  # Exit with an error code
# fi

# if output directory exists, remove it
if [ -d "$output_dir" ]; then
    echo "Directory '$output_dir' exists. Removing it ..."
    rm -r "$output_dir"
fi

# create compiled versions of qmd to using profile "compiled"
echo "Compiling seurat labs ..."
docker run --rm --platform=linux/amd64 -u 1000:1000 -v ${PWD}:/work $docker_site quarto render --profile compile /work/docs/labs/seurat/*.qmd --to markdown-header_attributes --metadata engine:markdown --log-level info,warning,error
echo "Compiling bioc labs ..."
docker run --rm --platform=linux/amd64 -u 1000:1000 -v ${PWD}:/work $docker_site quarto render --profile compile /work/docs/labs/bioc/*.qmd --to markdown-header_attributes --metadata engine:markdown --log-level warning,error
echo "Compiling scanpy labs ..."
docker run --rm --platform=linux/amd64 -u 1000:1000 -v ${PWD}:/work $docker_site quarto render --profile compile /work/docs/labs/scanpy/*.qmd --to markdown-header_attributes --metadata engine:markdown --log-level warning,error

# Read an md/qmd, remove unnecessary lines from yaml, and write to the original file
echo "Slimming yaml across all .md files ..."
slim_yaml() {
    awk '
        /^---$/ && !in_yaml {in_yaml=1; print; next} 
        /^---$/ && in_yaml {in_yaml=0; print; next} 
        !in_yaml {print} 
        in_yaml {
            if (/^(title:|subtitle:|description:)/) {
                print;
                continue_capture=1;
            } else if (continue_capture && !(/^[a-zA-Z0-9_-]+:/)) {
                print;
            } else {
                continue_capture=0;
            }
        }
    ' "$1" > "temp.md"

    mv "temp.md" "$1"
}

find "${output_dir}" -type f -name "*.md" -print0 | while IFS= read -r -d '' file; do
    ## echo "Slimming yaml: $file ..."
    slim_yaml "$file"
done

# converting md files to qmd
echo "Converting seurat .md files to .qmd ..."
for file in "${output_dir}"/labs/seurat/*.md; do
    mv "$file" "${file%.md}.qmd"
    rm -rf "$file"
done

echo "Converting bioc .md files to .qmd ..."
for file in "${output_dir}"/labs/bioc/*.md; do
    mv "$file" "${file%.md}.qmd"
    rm -rf "$file"
done

echo "Converting scanpy .md files to .qmd ..."
for file in "${output_dir}"/labs/scanpy/*.md; do
    mv "$file" "${file%.md}.qmd"
    rm -rf "$file"
done

# converting scanpy qmd files to ipynb
echo "Converting scanpy .qmd files to .ipynb ..."
for file in "${output_dir}"/labs/scanpy/*.qmd; do
    fname=$(basename "$file")
    docker run --rm --platform=linux/amd64 -u 1000:1000 -v ${PWD}:/work $docker_site quarto convert "/work/${file}"
    rm -rf "$file"
done

echo "All files compiled successfully."
exit 0
