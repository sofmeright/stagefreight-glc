
#!/bin/bash
set -euo pipefail

COMPONENT_SPEC_FILE="$1"
OUTPUT_MD_FILE="$2"

mkdir -p "$(dirname "$OUTPUT_MD_FILE")"

TMP_INPUTS="/tmp/inputs_with_groups_$(basename "$COMPONENT_SPEC_FILE" | tr '/' '_' | sed 's/[^a-zA-Z0-9]/_/g').yaml"
TMP_JSON="/tmp/inputs_$(basename "$COMPONENT_SPEC_FILE" | tr '/' '_' | sed 's/[^a-zA-Z0-9]/_/g').json"

echo "🔍 Debug: Parsing group metadata and inputs from original file..."

# Step 1: Extract inputs section with comments preserved and create a mapping
python3 -c "
import yaml
import sys
import re
import json

def parse_file_with_groups(filename):
    with open(filename, 'r') as f:
        lines = f.readlines()
    
    # Find the inputs section
    in_spec = False
    in_inputs = False
    inputs_data = {}
    current_group = 'Ungrouped'
    current_group_desc = ''
    pending_group = None
    pending_group_desc = None
    
    i = 0
    while i < len(lines):
        line = lines[i].rstrip()
        
        # Track spec section
        if re.match(r'^spec:\s*$', line):
            in_spec = True
            i += 1
            continue
            
        # Track inputs section within spec
        if in_spec and re.match(r'^\s+inputs:\s*$', line):
            in_inputs = True
            i += 1
            continue
            
        # Exit inputs section if we hit another top-level key in spec
        if in_spec and in_inputs and re.match(r'^\s+[a-zA-Z][^:]*:\s*$', line) and not re.match(r'^\s+\s+', line):
            # This is a sibling to inputs, so we're done
            break
            
        # Exit spec section entirely
        if in_spec and re.match(r'^[a-zA-Z]', line):
            break
            
        if not in_inputs:
            i += 1
            continue
            
        # Look for group comments
        if '# input_section_name-' in line:
            pending_group = line.split('# input_section_name-')[1].strip()
            i += 1
            continue
            
        if '# input_section_desc-' in line:
            pending_group_desc = line.split('# input_section_desc-')[1].strip()
            i += 1
            continue
            
        # Skip other comments
        if re.match(r'^\s*#', line):
            i += 1
            continue
            
        # Look for input keys (indented under inputs)
        match = re.match(r'^\s+([a-zA-Z0-9_-]+):\s*(.*)
            
            # Handle inline value if present
            inline_value = match.group(2)
            if inline_value and inline_value != '':
                if inline_value.startswith('[') or inline_value.startswith('{'):
                    try:
                        input_def = yaml.safe_load(f'{key}: {inline_value}')[key]
                    except:
                        input_def['value'] = inline_value
                else:
                    input_def['value'] = inline_value.strip('\"\'')
            
            # Parse multi-line properties
            while i < len(lines):
                line = lines[i].rstrip()
                
                # Check if this is a property of the current input (more indented)
                if re.match(r'^\s+\s+([a-zA-Z0-9_-]+):\s*(.*)$', line):
                    prop_match = re.match(r'^\s+\s+([a-zA-Z0-9_-]+):\s*(.*)$', line)
                    prop_key = prop_match.group(1)
                    prop_value = prop_match.group(2)
                    
                    if prop_value.startswith('[') or prop_value.startswith('{'):
                        try:
                            input_def[prop_key] = yaml.safe_load(prop_value)
                        except:
                            input_def[prop_key] = prop_value
                    elif prop_value.startswith('\"') or prop_value.startswith(\"'\"):
                        input_def[prop_key] = prop_value.strip('\"\'')
                    elif prop_value == '':
                        # Multi-line or array, continue reading
                        input_def[prop_key] = []
                        i += 1
                        while i < len(lines):
                            line = lines[i].rstrip()
                            if re.match(r'^\s+\s+\s+- ', line):
                                item = line.strip('- ').strip('\"\'')
                                input_def[prop_key].append(item)
                                i += 1
                            else:
                                i -= 1  # Back up one line
                                break
                    else:
                        try:
                            input_def[prop_key] = yaml.safe_load(prop_value)
                        except:
                            input_def[prop_key] = prop_value
                    i += 1
                elif re.match(r'^\s+\s+\s+', line):
                    # Array item or continuation, handle specially
                    i += 1
                else:
                    # End of this input's properties
                    break
            
            # Add group metadata
            input_def['_input_group_name'] = current_group
            input_def['_input_group_desc'] = current_group_desc
            inputs_data[key] = input_def
            
            # Don't increment i here - let the main loop handle it
            continue
        
        i += 1
    
    return inputs_data

try:
    result = parse_file_with_groups('$COMPONENT_SPEC_FILE')
    with open('$TMP_JSON', 'w') as f:
        json.dump(result, f, indent=2)
    print(f'📦 Debug: Parsed {len(result)} inputs successfully')
    for key, value in result.items():
        group = value.get('_input_group_name', 'Ungrouped')
        print(f'  {key} -> {group}')
except Exception as e:
    print(f'❌ Error parsing file: {e}')
    sys.exit(1)
"

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

echo "✅ Markdown output generated at: $OUTPUT_MD_FILE", line)
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
            i += 1
            
            # Handle inline value if present
            inline_value = match.group(2)
            if inline_value and inline_value != '':
                if inline_value.startswith('[') or inline_value.startswith('{'):
                    try:
                        input_def = yaml.safe_load(f'{key}: {inline_value}')[key]
                    except:
                        input_def['value'] = inline_value
                else:
                    input_def['value'] = inline_value.strip('\"\'')
            
            # Parse multi-line properties
            while i < len(lines):
                line = lines[i].rstrip()
                
                # Check if this is a property of the current input (more indented)
                if re.match(r'^\s+\s+([a-zA-Z0-9_-]+):\s*(.*)$', line):
                    prop_match = re.match(r'^\s+\s+([a-zA-Z0-9_-]+):\s*(.*)$', line)
                    prop_key = prop_match.group(1)
                    prop_value = prop_match.group(2)
                    
                    if prop_value.startswith('[') or prop_value.startswith('{'):
                        try:
                            input_def[prop_key] = yaml.safe_load(prop_value)
                        except:
                            input_def[prop_key] = prop_value
                    elif prop_value.startswith('\"') or prop_value.startswith(\"'\"):
                        input_def[prop_key] = prop_value.strip('\"\'')
                    elif prop_value == '':
                        # Multi-line or array, continue reading
                        input_def[prop_key] = []
                        i += 1
                        while i < len(lines):
                            line = lines[i].rstrip()
                            if re.match(r'^\s+\s+\s+- ', line):
                                item = line.strip('- ').strip('\"\'')
                                input_def[prop_key].append(item)
                                i += 1
                            else:
                                i -= 1  # Back up one line
                                break
                    else:
                        try:
                            input_def[prop_key] = yaml.safe_load(prop_value)
                        except:
                            input_def[prop_key] = prop_value
                    i += 1
                elif re.match(r'^\s+\s+\s+', line):
                    # Array item or continuation, handle specially
                    i += 1
                else:
                    # End of this input's properties
                    break
            
            # Add group metadata
            input_def['_input_group_name'] = current_group
            input_def['_input_group_desc'] = current_group_desc
            inputs_data[key] = input_def
            continue
        
        i += 1
    
    return inputs_data

try:
    result = parse_file_with_groups('$COMPONENT_SPEC_FILE')
    with open('$TMP_JSON', 'w') as f:
        json.dump(result, f, indent=2)
    print(f'📦 Debug: Parsed {len(result)} inputs successfully')
    for key, value in result.items():
        group = value.get('_input_group_name', 'Ungrouped')
        print(f'  {key} -> {group}')
except Exception as e:
    print(f'❌ Error parsing file: {e}')
    sys.exit(1)
"

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