#!/usr/bin/env bash
# Split a multi-document YAML file into individual files for xpkg packaging
# Usage: split-xpkg.sh <input-file> <output-dir>

set -euo pipefail

INPUT_FILE="${1:?Input file required}"
OUTPUT_DIR="${2:?Output directory required}"

if [[ ! -f "$INPUT_FILE" ]]; then
    echo "Error: Input file not found: $INPUT_FILE" >&2
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

# Split YAML documents using yq or csplit
if command -v yq &> /dev/null; then
    # Use yq to split documents (preferred method)
    echo "Splitting $INPUT_FILE using yq..."

    # Read each document and save to appropriate file based on kind
    yq eval-all --no-doc '.' "$INPUT_FILE" | {
        doc_count=0
        while IFS= read -r line; do
            if [[ "$line" == "---" ]]; then
                doc_count=$((doc_count + 1))
                continue
            fi

            # Detect document kind and save to appropriate file
            if [[ "$line" =~ ^kind:[[:space:]]*(.+)$ ]]; then
                kind="${BASH_REMATCH[1]}"
                output_file="$OUTPUT_DIR/${kind,,}.yaml"
                echo "---" > "$output_file"
                echo "$line" >> "$output_file"

                # Continue reading this document
                while IFS= read -r doc_line; do
                    if [[ "$doc_line" == "---" ]]; then
                        break
                    fi
                    echo "$doc_line" >> "$output_file"
                done
            fi
        done < <(cat "$INPUT_FILE")
    }
else
    # Fallback: Use csplit to split by document separator
    echo "Warning: yq not found, using csplit fallback..." >&2
    echo "Installing yq is recommended: https://github.com/mikefarah/yq" >&2

    cd "$OUTPUT_DIR"
    csplit -s -f doc- "$INPUT_FILE" '/^---$/' '{*}' || true

    # Rename files based on kind
    for file in doc-*; do
        [[ -f "$file" ]] || continue
        kind=$(grep -m 1 '^kind:' "$file" | awk '{print tolower($2)}')
        if [[ -n "$kind" ]]; then
            mv "$file" "${kind}.yaml"
        fi
    done
fi

echo "Split complete: $(ls -1 "$OUTPUT_DIR" | wc -l) files generated"
ls -lh "$OUTPUT_DIR"
