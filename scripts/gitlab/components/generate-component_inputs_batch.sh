#!/bin/bash
set -euo pipefail

raw_files="$1"
OUTPUT_MD_FILE="$2"

mkdir -p "$(dirname "$OUTPUT_MD_FILE")"

echo "🔍 Debug: Parsing raw input file list string..."
echo "Raw input: $raw_files"

# Strip brackets and quotes, remove spaces around commas, split into array
files=$(echo "$raw_files" | sed -e 's/^\[\(.*\)\]$/\1/' -e 's/"//g' -e 's/, */,/g')
IFS=',' read -r -a file_array <<< "$files"

echo "Files to process:"
for f in "${file_array[@]}"; do
  echo " - [$f]"
done

# Reset output file
> "$OUTPUT_MD_FILE"

for f in "${file_array[@]}"; do
  name=$(basename "$f")
  name="${name%.*}"  # Strip extension

  tmp_md="/tmp/${name}_inputs.md"
  echo "⚙️  Generating Markdown for $f -> $tmp_md"

  ./generate-component_inputs_table.sh "$f" "$tmp_md"

  echo "📌 Appending to output file with header..."
  {
    echo "## \`$name\`"
    echo ""
    cat "$tmp_md"
    echo ""
    echo "---"
    echo ""
  } >> "$OUTPUT_MD_FILE"
done

echo "✅ Final output written to: $OUTPUT_MD_FILE"