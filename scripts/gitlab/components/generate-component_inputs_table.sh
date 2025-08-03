#!/bin/bash
set -euo pipefail

COMPONENT_SPEC_FILE="$1"
OUTPUT_MD_FILE="$2"

mkdir -p "$(dirname "$OUTPUT_MD_FILE")"

TMP_INPUTS="/tmp/inputs_with_groups.yaml"
TMP_JSON="/tmp/inputs.json"

echo "🔍 Debug: Parsing group metadata and inputs..."

awk '
  BEGIN {
    group_name = "Ungrouped"
    group_desc = ""
    current_key = ""
    in_input = 0
    printed_group = 0
  }

  /^[[:space:]]*# input_section_name-/ {
    sub(/^.*# input_section_name-/, "", $0)
    gsub(/^[ \t]+|[ \t]+$/, "", $0)
    group_name = $0
    next
  }

  /^[[:space:]]*# input_section_desc-/ {
    sub(/^.*# input_section_desc-/, "", $0)
    gsub(/^[ \t]+|[ \t]+$/, "", $0)
    group_desc = $0
    next
  }

  /^[^[:space:]#][^:]*:/ {
    if (in_input && current_key != "") {
      # Insert group tags for the previous input block
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