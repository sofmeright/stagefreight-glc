#!/bin/bash
set -euo pipefail

COMPONENT_SPEC_FILE="$1"
OUTPUT_MD_FILE="$2"

mkdir -p "$(dirname "$OUTPUT_MD_FILE")"

# Step 1: Extract inputs as clean JSON
yq eval -o=json '.' artifacts/_inputs_raw.yaml > inputs.json

# Step 2: Use jq to group by _input_group_name and generate markdown
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
' inputs.json > "$OUTPUT_MD_FILE"

# Replace true/false with ✅/🚫 in the output Markdown
sed -i 's/| true |/| ✅ |/g; s/| false |/| 🚫 |/g' "$OUTPUT_MD_FILE"