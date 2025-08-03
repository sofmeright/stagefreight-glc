#!/bin/bash
set -euo pipefail

COMPONENT_SPEC_FILE="$1"
OUTPUT_MD_FILE="$2"

mkdir -p "$(dirname "$OUTPUT_MD_FILE")"

# Step 1: Extract .spec.inputs block with comments preserved
yq eval '.spec.inputs' "$COMPONENT_SPEC_FILE" > inputs_with_comments.yaml

# Step 2: Parse input sections and extract metadata using awk
awk '
  /^# input_section_name-/ {
    section_name = substr($0, index($0,$3))
  }
  /^# input_section_desc-/ {
    section_desc = substr($0, index($0,$3))
  }
  /^[^#[:space:]]/ {
    key = $1
    gsub(":", "", key)
    keys[++i] = key
    group[key] = section_name
    group_desc[key] = section_desc
  }
' inputs_with_comments.yaml > /tmp/input_keys.meta

# Step 3: Convert input YAML to JSON
yq eval -o=json '.spec.inputs' "$COMPONENT_SPEC_FILE" > /tmp/input_data.json

# Step 4: Use jq + bash to build the grouped markdown
{
  echo "" > "$OUTPUT_MD_FILE"
  for group_name in $(awk -F'=' '/^group\[/ { print $2 }' /tmp/input_keys.meta | sort -u); do
    desc=$(awk -v g="$group_name" -F'= ' '$0 ~ "group_desc\\[" g "\\]" {print $2}' /tmp/input_keys.meta | head -n1)
    echo "### ${group_name:-Ungrouped}" >> "$OUTPUT_MD_FILE"
    echo "" >> "$OUTPUT_MD_FILE"
    echo "${desc}" >> "$OUTPUT_MD_FILE"
    echo "" >> "$OUTPUT_MD_FILE"
    echo "| Name | Required | Default | Description |" >> "$OUTPUT_MD_FILE"
    echo "|------|----------|---------|-------------|" >> "$OUTPUT_MD_FILE"

    for key in $(awk -v g="$group_name" -F'= ' '$0 ~ "group\\[" g "\\]" {print $1}' /tmp/input_keys.meta | sed 's/group\[//;s/\]//'); do
      jq -r --arg key "$key" '
        .[$key] as $val |
        "\($key) \($val.default // "") \($val.description // "") \((($val | has("default") | not) | tostring))"
      ' /tmp/input_data.json | while read -r name def desc req; do
        [[ "$req" == "true" ]] && req="✅" || req="🚫"
        echo "| $name | $req | $def | $desc |" >> "$OUTPUT_MD_FILE"
      done
    done
    echo "" >> "$OUTPUT_MD_FILE"
  done
} || {
  echo "❌ Failed to parse and group inputs."
  exit 1
}