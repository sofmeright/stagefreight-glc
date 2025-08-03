#!/bin/bash
set -euo pipefail

COMPONENT_SPEC_FILE="$1"
OUTPUT_MD_FILE="$2"

mkdir -p "$(dirname "$OUTPUT_MD_FILE")"

TMP_INPUTS="/tmp/inputs_with_groups.yaml"
TMP_JSON="/tmp/inputs.json"

echo "🔍 Debug: Parsing group metadata and inputs..."

# Step 1: Annotate inputs with _input_group_name and _input_group_desc
awk '
  BEGIN {
    current_group_name = "Ungrouped"
    current_group_desc = ""
  }
  {
    if ($0 ~ /^# input_section_name-/) {
      sub(/^# input_section_name-/, "", $0)
      gsub(/^[ \t]+|[ \t]+$/, "", $0)
      current_group_name = $0
    } else if ($0 ~ /^# input_section_desc-/) {
      sub(/^# input_section_desc-/, "", $0)
      gsub(/^[ \t]+|[ \t]+$/, "", $0)
      current_group_desc = $0
    } else if ($0 ~ /^[a-zA-Z0-9_]+:/) {
      print "  _input_group_name: \"" current_group_name "\""
      print "  _input_group_desc: \"" current_group_desc "\""
      print $0
    } else {
      print $0
    }
  }
' "$COMPONENT_SPEC_FILE" > "$TMP_INPUTS"

echo "📦 Debug: Annotated inputs written to: $TMP_INPUTS"
cat "$TMP_INPUTS" | sed 's/^/    /'

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