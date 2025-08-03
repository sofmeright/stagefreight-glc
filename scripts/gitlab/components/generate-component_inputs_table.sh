#!/bin/bash
set -euo pipefail

COMPONENT_SPEC_FILE="$1"
OUTPUT_MD_FILE="$2"

mkdir -p "$(dirname "$OUTPUT_MD_FILE")"

TMP_INPUTS="/tmp/inputs_with_groups_$(basename "$COMPONENT_SPEC_FILE" | tr '/' '_' | sed 's/[^a-zA-Z0-9]/_/g').yaml"
TMP_JSON="/tmp/inputs_$(basename "$COMPONENT_SPEC_FILE" | tr '/' '_' | sed 's/[^a-zA-Z0-9]/_/g').json"

echo "🔍 Debug: Parsing group metadata and inputs..."

awk '
  BEGIN {
    current_key = ""
    in_input = 0
    group_name = "Ungrouped"
    group_desc = ""
    next_group_name = ""
    next_group_desc = ""
    pending_group_change = 0
  }

  # Capture group name from comment
  /^[[:space:]]*# input_section_name-/ {
    sub(/^.*# input_section_name-/, "", $0)
    gsub(/^[ \t]+|[ \t]+$/, "", $0)
    next_group_name = $0
    pending_group_change = 1
    next
  }

  # Capture group description from comment
  /^[[:space:]]*# input_section_desc-/ {
    sub(/^.*# input_section_desc-/, "", $0)
    gsub(/^[ \t]+|[ \t]+$/, "", $0)
    next_group_desc = $0
    next
  }

  # Skip other comments
  /^[[:space:]]*#/ {
    next
  }

  # Main input key (top level, not indented)
  /^[^[:space:]#][^:]*:/ {
    # If we have a pending group change, apply it now
    if (pending_group_change && next_group_name != "") {
      group_name = next_group_name
      next_group_name = ""
      pending_group_change = 0
    }
    if (next_group_desc != "") {
      group_desc = next_group_desc
      next_group_desc = ""
    }

    # Close previous input if we were in one
    if (in_input && current_key != "") {
      print "  _input_group_name: \"" group_name "\""
      print "  _input_group_desc: \"" group_desc "\""
    }

    # Start new input
    current_key = $1
    gsub(":", "", current_key)
    print $0
    in_input = 1
    next
  }

  # Indented properties (description, default, type, etc.)
  /^[[:space:]]+[a-zA-Z0-9_-]+:/ {
    print $0
    next
  }

  # Empty lines - close current input if we were in one
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

  # Everything else (array items, continuation lines, etc.)
  {
    print $0
  }

  # Handle final input at end of file
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

# Step 3: Generate grouped Markdown using jq with improved required field detection
jq -r '
  to_entries
  | map({
      key: .key,
      group: (.value._input_group_name // "Ungrouped"),
      group_desc: (.value._input_group_desc // ""),
      required: (
        (.value | type == "object") and 
        ((.value.default // null) == null or (.value.default // null) == "")
      ),
      default: (.value.default // ""),
      description: (.value.description // "")
    })
  | group_by(.group)
  | map(
      "### " + (.[0].group // "Ungrouped") + "\n" +
      (if (.[0].group_desc // "") != "" then (.[0].group_desc) + "\n" else "" end) +
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