#!/bin/bash
set -euo pipefail

COMPONENT_SPEC_FILE="$1"
OUTPUT_MD_FILE="$2"

mkdir -p "$(dirname "$OUTPUT_MD_FILE")"

TMP_INPUTS="/tmp/inputs_with_groups_$(basename "$COMPONENT_SPEC_FILE" | tr '/' '_' | sed 's/[^a-zA-Z0-9]/_/g').yaml"
TMP_JSON="/tmp/inputs_$(basename "$COMPONENT_SPEC_FILE" | tr '/' '_' | sed 's/[^a-zA-Z0-9]/_/g').json"

echo "🔍 Debug: Parsing group metadata and inputs from original file..."

# Create a temporary Python script
cat > /tmp/parse_inputs.py << 'EOF'
import yaml
import sys
import re
import json

def parse_file_with_groups(filename):
    with open(filename, "r") as f:
        lines = f.readlines()
    
    # Find the inputs section
    in_spec = False
    in_inputs = False
    inputs_data = {}
    current_group = "Ungrouped"
    current_group_desc = ""
    pending_group = None
    pending_group_desc = None
    
    i = 0
    while i < len(lines):
        line = lines[i].rstrip()
        
        # Track spec section
        if re.match(r"^spec:\s*$", line):
            in_spec = True
            i += 1
            continue
            
        # Track inputs section within spec
        if in_spec and re.match(r"^\s+inputs:\s*$", line):
            in_inputs = True
            i += 1
            continue
            
        # Exit inputs section if we hit another top-level key in spec
        if in_spec and in_inputs and re.match(r"^\s+[a-zA-Z][^:]*:\s*$", line):
            # Check indentation - if it is at the same level as inputs, we are done
            input_indent = len(line) - len(line.lstrip())
            if input_indent <= 2:  # Same level as inputs
                break
            
        # Exit spec section entirely
        if in_spec and re.match(r"^[a-zA-Z]", line):
            break
            
        if not in_inputs:
            i += 1
            continue
            
        # Look for group comments
        if "# input_section_name-" in line:
            pending_group = line.split("# input_section_name-")[1].strip()
            i += 1
            continue
            
        if "# input_section_desc-" in line:
            pending_group_desc = line.split("# input_section_desc-")[1].strip()
            i += 1
            continue
            
        # Skip other comments
        if re.match(r"^\s*#", line):
            i += 1
            continue
            
        # Look for input keys (indented under inputs)
        match = re.match(r"^\s+([a-zA-Z0-9_-]+):\s*(.*)$", line)
        if match:
            key = match.group(1)
            
            # Apply pending group if we have one
            if pending_group:
                current_group = pending_group
                pending_group = None
            if pending_group_desc:
                current_group_desc = pending_group_desc
                pending_group_desc = None
                
            # Parse the input definition
            input_def = {}
            inline_value = match.group(2)
            
            # Handle inline value if present
            if inline_value and inline_value.strip():
                if inline_value.strip().startswith("[") or inline_value.strip().startswith("{"):
                    try:
                        parsed = yaml.safe_load(key + ": " + inline_value)
                        input_def = parsed[key] if isinstance(parsed[key], dict) else {"default": parsed[key]}
                    except:
                        input_def = {"default": inline_value.strip()}
                else:
                    input_def = {"default": inline_value.strip().strip('"').strip("'")}
            
            # Move to next line to parse properties
            i += 1
            
            # Parse multi-line properties
            while i < len(lines):
                prop_line = lines[i].rstrip()
                
                # Empty line - continue but do not break
                if not prop_line.strip():
                    i += 1
                    continue
                
                # Check if this is a property of the current input (more indented than the key)
                key_indent = len(line) - len(line.lstrip())
                prop_indent = len(prop_line) - len(prop_line.lstrip())
                
                if prop_indent > key_indent and re.match(r"^\s+([a-zA-Z0-9_-]+):\s*(.*)$", prop_line):
                    prop_match = re.match(r"^\s+([a-zA-Z0-9_-]+):\s*(.*)$", prop_line)
                    prop_key = prop_match.group(1)
                    prop_value = prop_match.group(2).strip()
                    
                    if not prop_value:
                        # Multi-line value or array
                        prop_array = []
                        j = i + 1
                        while j < len(lines):
                            array_line = lines[j].rstrip()
                            if not array_line.strip():
                                j += 1
                                continue
                            array_indent = len(array_line) - len(array_line.lstrip())
                            if array_indent > prop_indent and array_line.strip().startswith("- "):
                                item = array_line.strip()[2:].strip('"').strip("'").strip()
                                prop_array.append(item)
                                j += 1
                            else:
                                break
                        if prop_array:
                            input_def[prop_key] = prop_array
                            i = j - 1
                        else:
                            input_def[prop_key] = ""
                    else:
                        # Single line value
                        if prop_value.startswith('"') or prop_value.startswith("'"):
                            input_def[prop_key] = prop_value.strip('"').strip("'")
                        elif prop_value in ["true", "false"]:
                            input_def[prop_key] = prop_value == "true"
                        else:
                            try:
                                input_def[prop_key] = yaml.safe_load(prop_value)
                            except:
                                input_def[prop_key] = prop_value
                    i += 1
                else:
                    # End of this input properties
                    break
            
            # Add group metadata
            input_def["_input_group_name"] = current_group
            input_def["_input_group_desc"] = current_group_desc
            inputs_data[key] = input_def
            
            # Continue with the outer loop (do not increment i again)
            continue
        
        i += 1
    
    return inputs_data

if __name__ == "__main__":
    try:
        result = parse_file_with_groups(sys.argv[1])
        with open(sys.argv[2], "w") as f:
            json.dump(result, f, indent=2)
        print(f"📦 Debug: Parsed {len(result)} inputs successfully")
        for key, value in result.items():
            group = value.get("_input_group_name", "Ungrouped")
            desc = value.get("description", "No description")[:50]
            print(f"  {key} -> {group} | {desc}...")
    except Exception as e:
        print(f"❌ Error parsing file: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
EOF

# Run the Python script
python3 /tmp/parse_inputs.py "$COMPONENT_SPEC_FILE" "$TMP_JSON"

if [ $? -ne 0 ]; then
    echo "❌ Failed to parse inputs"
    exit 1
fi

echo "📦 Debug: JSON output written to: $TMP_JSON"

# Step 2: Generate grouped Markdown using jq
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

# Step 3: Emoji replacements
sed -i 's/| true |/| ✅ |/g; s/| false |/| 🚫 |/g' "$OUTPUT_MD_FILE"

echo "✅ Markdown output generated at: $OUTPUT_MD_FILE"