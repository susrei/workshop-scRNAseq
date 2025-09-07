#!/bin/sh

# fail on error
set -e

## COMPILE QMD FILES
##
## Description
## Evaluates and replaces meta variable shortcuts
## .qmd files are converted to .qmd files
## .qmd files with jupyter engine are converted to .ipynb
## The following directories are exprected:
## labs/seurat, labs/bioc, labs/scanpy
##
## Usage
## Run this script in the root of repo. It takes about 1 min to run.
## bash ./scripts/compile.sh option

## input argument can  be either of:
## all - run all the steps
## seurat - render all seurat labs
## bioc - render all bioc labs
## scanpy - render all scanpy labs

DOCKER_SITE="ghcr.io/nbisweden/workshop-scrnaseq:2024-site-r4.3.0"
OUTPUT_DIR="compiled"
TOOLKIT=$1

## FUNCTIONS

# check if these directories exist
check_input_dir() {
	if [ ! -d "docs/labs/$1" ]; then
		echo "Error: Directory docs/labs/$1 does not exist."
		exit 1
	fi
}

# if output directory exists, remove it
check_output_dir() {
	if [ -d "${OUTPUT_DIR}/labs/$1" ]; then
		echo "Directory ${OUTPUT_DIR}/labs/$1 exists. Removing it"
		rm -r "${OUTPUT_DIR}/labs/$1"
	fi
}

# create compiled versions of qmd to using profile "compiled"
quarto_compile() {
	echo "Compiling $1 labs ..."
	docker run --rm --platform=linux/amd64 -u 1000:1000 -v ${PWD}:/work $DOCKER_SITE quarto render --profile compile /work/docs/labs/$1/*.qmd --to markdown-header_attributes --metadata engine:markdown --log-level warning,error
}

# Read an md/qmd, remove unnecessary lines from yaml, and write to the original file
_slim_md_frontmatter() {
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

slim_md_frontmatter() {
	echo "Slimming frontmatter yaml across all $1 .md files"
	find "${OUTPUT_DIR}/labs/$1" -type f -name "*.md" -print0 | while IFS= read -r -d '' file; do
		_slim_md_frontmatter "$file"
	done
}

md_to_qmd() {
	echo "Converting $1 .md files to .qmd"
	for file in "${OUTPUT_DIR}"/labs/$1/*.md; do
		mv "$file" "${file%.md}.qmd"
		rm -rf "$file"
	done
}

qmd_to_ipynb() {
	echo "Converting $1 .qmd files to .ipynb"
	for file in "${OUTPUT_DIR}"/labs/$1/*.qmd; do
		fname=$(basename "$file")
		docker run --rm --platform=linux/amd64 -u 1000:1000 -v ${PWD}:/work $DOCKER_SITE quarto convert "/work/${file}"
		rm -rf "$file"
	done
}

# Run all the steps to compile the labs
compile_labs() {
	check_input_dir $1
	check_output_dir $1
	quarto_compile $1
	slim_md_frontmatter $1
	md_to_qmd $1
	if [ "$1" = "scanpy" ]; then
		qmd_to_ipynb $1
	fi
}

## PARSE ARGS AND COMPILE LABS

main() {
	case "${TOOLKIT}" in
		seurat)
			compile_labs "seurat"
			;;
		bioc)
			compile_labs "bioc"
			;;
		scanpy)
			compile_labs "scanpy"
			;;
		all)
			compile_labs "seurat"
			compile_labs "bioc"
			compile_labs "scanpy"
			;;
		*)
			echo "Unknown option ${TOOLKIT}. Choose one of [seurat,bioc,scanpy,all]."
			;;
	esac
}

main

