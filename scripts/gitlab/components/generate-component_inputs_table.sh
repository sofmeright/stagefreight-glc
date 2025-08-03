#!/bin/bash
set -euo pipefail

COMPONENT_SPEC_FILE="$1"
OUTPUT_MD_FILE="$2"

mkdir -p "$(dirname "$OUTPUT_MD_FILE")"

# Extract only the inputs block, preserving comments
INPUTS_BLOCK=$(yq eval '.spec.inputs' "$COMPONENT_SPEC_FILE")

# Save to a temp file for awk parsing
TMP_INPUTS_FILE=$(mktemp)
echo "$INPUTS_BLOCK" > "$TMP_INPUTS_FILE"

echo "📦 Debug: Raw inputs block extracted to: $TMP_INPUTS_FILE"
cat "$TMP_INPUTS_FILE"

# Step 1: Parse input keys and grouping metadata
echo "🔍 Debug: Parsing group metadata and inputs..."

# JSON structure: [{ key, group, group_desc, default, description, required }]
PARSED_INPUTS_JSON=$(awk '
BEGIN {
  group_name = "Ungrouped";
  group_desc = "";
  print "["
}
/^# input_section_name-/ {
  group_name = substr($0, index($0,$3))
  next
}
/^# input_section_desc-/ {
  group_desc = substr($0, index($0,$3))
  next
}
/^[[:space:]]*[a-zA-Z0-9_-]+:/ {
  gsub(":", "", $1)
  input_key = $1
  input_data[input_key]["group"] = group_name
  input_data[input_key]["group_desc"] = group_desc
  input_keys[length(input_keys)] = input_key
  print "{ \"key\": \"" input_key "\", \"group\": \"" group_name "\", \"group_desc\": \"" group_desc "\" },"
}
END {
  print "{}]"  # Empty object to close trailing comma
}' "$TMP_INPUTS_FILE")

# Clean the JSON (remove last trailing empty object)
INPUT_GROUPS=$(echo "$PARSED_INPUTS_JSON" | jq 'del(.[-1])')

echo "📦 Debug: Parsed input metadata:"
echo "$INPUT_GROUPS" | jq '.'

# Step 2: Get clean input data values from the file (as JSON)
INPUT_DATA=$(yq eval '.spec.inputs' "$COMPONENT_SPEC_FILE" | yq -o=json)
echo "$INPUT_DATA" > /tmp/input_data.json

# Step 3: Merge group metadata with values
FINAL_JSON=$(jq -c --slurpfile metadata <(echo "$INPUT_GROUPS") '
  reduce $metadata[] as $meta ([];
    . + [{
      key: $meta.key,
      group: $meta.group,
      group_desc: $meta.group_desc,
      val: (input[$meta.key] // {}),
      required: ((input[$meta.key] | has("default") | not)),
      default: (input[$meta.key].default // ""),
      description: (input[$meta.key].description // "")
    }]
  )
' --argfile input /tmp/input_data.json)

echo "📘 Debug: Final merged input values:"
echo "$FINAL_JSON" | jq '.'

# Step 4: Generate Markdown
MARKDOWN=$(echo "$FINAL_JSON" | jq -r '
  group_by(.group)
  | map(
      "### " + (.[0].group // "Ungrouped") + "\n\n" +
      (.[0].group_desc // "") + "\n\n" +
      "| Name | Required | Default | Description |\n" +
      "|------|----------|---------|-------------|\n" +
      (
        map("| \(.key) | \(.required) | \(.default | @json) | \(.description) |") | join("\n")
      ) + "\n"
    )
  | join("\n")
')

echo "$MARKDOWN" > "$OUTPUT_MD_FILE"

# Step 5: Replace booleans with icons
sed -i 's/| true |/| ✅ |/g; s/| false |/| 🚫 |/g' "$OUTPUT_MD_FILE"

echo "✅ Done! Markdown written to: $OUTPUT_MD_FILE"