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

# Create merged inputs file
TMP_MERGED_INPUTS="/tmp/merged_inputs.yaml"
> "$TMP_MERGED_INPUTS"

last_file=""

for f in "${file_array[@]}"; do
  if [[ -f "$f" ]]; then
    COMPONENT_NAME=$(basename "$f" | sed 's/\.[^.]*$//')
    echo "### Processing component: $COMPONENT_NAME"

    # Extract inputs cleanly
    yq eval '.spec.inputs' "$f" > /tmp/inputs_tmp.yaml

    # Append title and inputs (no trailing ---)
    echo "# --- $COMPONENT_NAME ---" >> "$TMP_MERGED_INPUTS"
    cat /tmp/inputs_tmp.yaml >> "$TMP_MERGED_INPUTS"
    echo "" >> "$TMP_MERGED_INPUTS"  # blank line separator

  else
    echo "WARNING: File not found: $f" >&2
  fi
done

echo "🔍 Debug: Merged inputs YAML content:"
cat "$TMP_MERGED_INPUTS"

# Continue with the rest of your script unchanged, setting:
COMPONENT_SPEC_FILE="$TMP_MERGED_INPUTS"

# (The rest of your original script below, unchanged:)

TMP_INPUTS="/tmp/inputs_with_groups.yaml"
TMP_JSON="/tmp/inputs.json"

echo "🔍 Debug: Parsing group metadata and inputs..."

awk '
  BEGIN {
    current_key = ""
    in_input = 0
    group_name = "Ungrouped"
    group_desc = ""
    next_group_name = ""
    next_group_desc = ""
  }

  /^[[:space:]]*# input_section_name-/ {
    sub(/^.*# input_section_name-/, "", $0)
    gsub(/^[ \t]+|[ \t]+$/, "", $0)
    next_group_name = $0
    next
  }

  /^[[:space:]]*# input_section_desc-/ {
    sub(/^.*# input_section_desc-/, "", $0)
    gsub(/^[ \t]+|[ \t]+$/, "", $0)
    next_group_desc = $0
    next
  }

  /^[^[:space:]#][^:]*:/ {
    if (next_group_name != "") {
      group_name = next_group_name
      next_group_name = ""
    }
    if (next_group_desc != "") {
      group_desc = next_group_desc
      next_group_desc = ""
    }

    if (in_input && current_key != "") {
      print "  _input_group_name: \"" group_name "\""
      print "  _input_group_desc: \"" group_desc "\""
    }

    current_key = $1
    gsub(":", "", current_key)
    print $0
    in_input = 1
    next
  }

  /^[[:space:]]+[a-zA-Z0-9_-]+:/ {
    print $0
    next
  }

  /^[[:space:]]*$/ {
    if (in_input && current_key != "") {
      print "  _input_group_name: \"" group_name "\""
      print "  _input_group_desc: \"" group_desc "\""
      in_input = 0
      current_key = ""
    }
    print ""
    next
  }

  {
    print $0
  }

  END {
    if (in_input && current_key != "") {
      print "  _input_group_name: \"" group_name "\""
      print "  _input_group_desc: \"" group_desc "\""
    }
  }
' "$COMPONENT_SPEC_FILE" > "$TMP_INPUTS"

echo "📦 Debug: Annotated inputs written to: $TMP_INPUTS"
sed 's/^/    /' "$TMP_INPUTS"

# Step 2: Convert to JSON
yq eval -o=json "$TMP_INPUTS" > "$TMP_JSON"

echo "📦 Debug: JSON output written to: $TMP_JSON"

# Step 3: Generate grouped Markdown using jq
jq -r '
  to_entries
  | map({
      key: .key,
      group: .value._input_group_name,
      group_desc: (.value._input_group_desc // ""),
      required: ((.value | type == "object") and (.value | has("default")) | not),
      default: (.value.default // ""),
      description: (.value.description // "")
    })
  | group_by(.group)
  | map(
      "### " + (.[0].group // "Ungrouped") + "\n\n" +
      (.[0].group_desc) + "\n\n" +
      "| Name | Required | Default | Description |\n" +
      "|------|----------|---------|-------------|\n" +
      (
        map("| \(.key) | \(.required) | \(.default | @json) | \(.description) |") | join("\n")
      ) + "\n"
    )
  | join("\n")
' "$TMP_JSON" > "$OUTPUT_MD_FILE"

# Step 4: Emoji replacements
sed -i 's/| true |/| ✅ |/g; s/| false |/| 🚫 |/g' "$OUTPUT_MD_FILE"

echo "✅ Markdown output generated at: $OUTPUT_MD_FILE"