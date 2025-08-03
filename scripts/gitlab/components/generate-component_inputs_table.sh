#!/bin/bash
set -euo pipefail

COMPONENT_SPEC_FILE="$1"
OUTPUT_MD_FILE="$2"

mkdir -p "$(dirname "$OUTPUT_MD_FILE")"

TMP_INPUTS="/tmp/inputs_with_groups_$(basename "$COMPONENT_SPEC_FILE" | tr '/' '_' | sed 's/[^a-zA-Z0-9]/_/g').yaml"
TMP_JSON="/tmp/inputs_$(basename "$COMPONENT_SPEC_FILE" | tr '/' '_' | sed 's/[^a-zA-Z0-9]/_/g').json"

echo "🔍 Debug: Parsing group metadata and inputs from original file..."

# Process the original file, but only output content within the spec.inputs section
awk '
  BEGIN {
    in_inputs_section = 0
    current_key = ""
    in_input = 0
    group_name = "Ungrouped"
    group_desc = ""
    next_group_name = ""
    next_group_desc = ""
    indent_level = 0
  }

  # Detect when we enter the spec.inputs section
  /^[[:space:]]*inputs:[[:space:]]*$/ {
    if (in_spec_section) {
      in_inputs_section = 1
      next
    }
  }
  
  # Detect spec section
  /^[[:space:]]*spec:[[:space:]]*$/ {
    in_spec_section = 1
    next
  }

  # If we are not in inputs section, check for section markers
  !in_inputs_section {
    # Reset if we hit another top-level section after spec
    if (/^[a-zA-Z]/ && in_spec_section) {
      in_spec_section = 0
    }
    next
  }

  # Now we are in the inputs section - process normally
  
  # Capture group name from comment
  /^[[:space:]]*# input_section_name-/ {
    sub(/^.*# input_section_name-/, "", $0)
    gsub(/^[ \t]+|[ \t]+$/, "", $0)
    next_group_name = $0
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

  # Check if we are leaving the inputs section (next major section at same level as inputs)
  /^[[:space:]]*[a-zA-Z][^:]*:[[:space:]]*$/ && in_inputs_section {
    # This might be the end of inputs section
    # Close any pending input
    if (in_input && current_key != "") {
      print "  _input_group_name: \"" group_name "\""
      print "  _input_group_desc: \"" group_desc "\""
    }
    in_inputs_section = 0
    next
  }

  # Input key (should be indented within inputs section)
  /^[[:space:]]+[^[:space:]#][^:]*:[[:space:]]*/ {
    # Apply pending group change
    if (next_group_name != "") {
      group_name = next_group_name
      next_group_name = ""
    }
    if (next_group_desc != "") {
      group_desc = next_group_desc  
      next_group_desc = ""
    }

    # Close previous input
    if (in_input && current_key != "") {
      print "  _input_group_name: \"" group_name "\""
      print "  _input_group_desc: \"" group_desc "\""
    }

    # Start new input - remove the leading spaces to make it top-level
    current_key = $0
    sub(/^[[:space:]]+/, "", current_key)
    gsub(/:.*$/, "", current_key)
    print current_key ":"
    in_input = 1
    next
  }

  # Properties of inputs (description, default, type, etc.)
  /^[[:space:]]+[[:space:]]+[a-zA-Z0-9_-]+:/ {
    # Remove one level of indentation and print
    sub(/^[[:space:]]+/, "", $0)
    print $0
    next
  }

  # Array items and other content
  /^[[:space:]]+[[:space:]]+/ {
    # Remove one level of indentation and print  
    sub(/^[[:space:]]+/, "", $0)
    print $0
    next
  }

  # Empty lines
  /^[[:space:]]*$/ {
    if (in_input) {
      print ""
    }
    next
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