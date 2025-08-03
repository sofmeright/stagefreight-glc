#!/bin/bash
set -euo pipefail

COMPONENT_SPEC_FILE="$1"
OUTPUT_MD_FILE="$2"

mkdir -p "$(dirname "$OUTPUT_MD_FILE")"

echo "📦 Debug: Reading raw inputs block from $COMPONENT_SPEC_FILE"
INPUTS_BLOCK=$(yq eval '.spec.inputs' "$COMPONENT_SPEC_FILE")

# Write to a temporary file for parsing
TMP_INPUTS_FILE=$(mktemp)
echo "$INPUTS_BLOCK" > "$TMP_INPUTS_FILE"

echo "--- RAW INPUT BLOCK ---"
cat "$TMP_INPUTS_FILE"
echo "--- END RAW INPUT BLOCK ---"

# Step 1: Parse metadata and associate group info with each key
echo "🔍 Debug: Parsing group metadata and inputs..."

CURRENT_GROUP=""
CURRENT_DESC=""
PARSED_JSON="["

while IFS= read -r line || [ -n "$line" ]; do
  # Check for group name
  if [[ "$line" =~ ^[[:space:]]*#\ input_section_name-\ (.+) ]]; then
    CURRENT_GROUP="${BASH_REMATCH[1]}"
    continue
  fi

  # Check for group description
  if [[ "$line" =~ ^[[:space:]]*#\ input_section_desc-\ (.+) ]]; then
    CURRENT_DESC="${BASH_REMATCH[1]}"
    continue
  fi

  # Match input keys
  if [[ "$line" =~ ^[[:space:]]*([a-zA-Z0-9_-]+):[[:space:]]*$ ]]; then
    KEY="${BASH_REMATCH[1]}"
    PARSED_JSON+=$'\n'
    PARSED_JSON+="  { \"key\": \"${KEY}\", \"group\": \"${CURRENT_GROUP}\", \"group_desc\": \"${CURRENT_DESC}\" },"
  fi
done < "$TMP_INPUTS_FILE"

# Remove trailing comma and close JSON array
PARSED_JSON="${PARSED_JSON%,}"
PARSED_JSON+="\n]"

echo "📦 Debug: Parsed input group metadata:"
echo "$PARSED_JSON" | jq .

# Step 2: Extract clean input data for values
INPUT_DATA=$(yq eval '.spec.inputs' "$COMPONENT_SPEC_FILE" | yq -o=json)
echo "$INPUT_DATA" > /tmp/input_data.json
echo "📦 Debug: Extracted input value JSON:"
cat /tmp/input_data.json | jq .

# Step 3: Merge metadata and values
FINAL_JSON=$(jq -c --slurpfile metadata <(echo "$PARSED_JSON") '
  reduce $metadata[0][] as $meta ([];
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
echo "$FINAL_JSON" | jq .

# Step 4: Generate grouped Markdown
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

# Step 5: Replace booleans with ✅ and 🚫
sed -i 's/| true |/| ✅ |/g; s/| false |/| 🚫 |/g' "$OUTPUT_MD_FILE"

echo "✅ Success: Markdown written to $OUTPUT_MD_FILE"