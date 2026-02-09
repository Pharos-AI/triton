#!/bin/bash

# Universal script to replace any prefix with another prefix in the project
# Usage: ./replace-prefix.sh [old_prefix] [new_prefix]
# Example: ./replace-prefix.sh pharos__ ph_dev4__

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Message output functions
info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Get old prefix from first parameter or environment variable
OLD_PREFIX="${1:-${OLD_PREFIX_ENV}}"

# Get new prefix from second parameter or environment variable
NEW_PREFIX="${2:-${NEW_PREFIX_ENV}}"

# If old prefix is not specified, prompt for it
if [ -z "$OLD_PREFIX" ]; then
    echo "Enter old prefix to replace (e.g., pharos__):"
    read -r OLD_PREFIX
fi

# Check that old prefix is specified
if [ -z "$OLD_PREFIX" ]; then
    error "Old prefix cannot be empty!"
    exit 1
fi

# If new prefix is not specified, prompt for it
if [ -z "$NEW_PREFIX" ]; then
    echo "Enter new prefix (e.g., ph_dev4__):"
    read -r NEW_PREFIX
fi

# Check that new prefix is specified
if [ -z "$NEW_PREFIX" ]; then
    error "New prefix cannot be empty!"
    exit 1
fi

# Ensure prefixes end with "__" for the common Salesforce *namespace delimiter* form (e.g., ns__)
# IMPORTANT: do NOT apply this heuristic to non-delimiter patterns like "ns." used for Apex namespaces.
maybe_extend_namespace_delimiter() {
    local p="$1"
    # If the prefix contains a dot, it's not a "__" delimiter pattern (e.g., "pharos.") — leave unchanged.
    if [[ "$p" == *.* ]]; then
        echo "$p"
        return 0
    fi
    # If it already ends with "__", leave unchanged.
    if [[ "$p" == *__ ]]; then
        echo "$p"
        return 0
    fi
    # If it contains underscores, it's likely a namespace token missing the "__" delimiter.
    if [[ "$p" == *"_"* ]]; then
        echo "${p}__"
        return 0
    fi
    echo "$p"
}

OLD_PREFIX_EXTENDED="$(maybe_extend_namespace_delimiter "$OLD_PREFIX")"
if [ "$OLD_PREFIX_EXTENDED" != "$OLD_PREFIX" ]; then
    OLD_PREFIX="$OLD_PREFIX_EXTENDED"
    warn "Old prefix automatically extended to: $OLD_PREFIX"
fi

NEW_PREFIX_EXTENDED="$(maybe_extend_namespace_delimiter "$NEW_PREFIX")"
if [ "$NEW_PREFIX_EXTENDED" != "$NEW_PREFIX" ]; then
    NEW_PREFIX="$NEW_PREFIX_EXTENDED"
    warn "New prefix automatically extended to: $NEW_PREFIX"
fi

# Find project root directory (where force-app exists)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

# Try to find project root by looking for force-app directory
while [ "$PROJECT_ROOT" != "/" ]; do
    if [ -d "$PROJECT_ROOT/force-app" ]; then
        break
    fi
    PROJECT_ROOT="$(dirname "$PROJECT_ROOT")"
done

# Check that we found the project root
if [ ! -d "$PROJECT_ROOT/force-app" ]; then
    error "Could not find project root with force-app directory!"
    exit 1
fi

# Change to project root
cd "$PROJECT_ROOT"
info "Project root: $PROJECT_ROOT"

# Validate that old and new prefixes are different
if [ "$OLD_PREFIX" = "$NEW_PREFIX" ]; then
    error "Old and new prefixes are the same! No replacement needed."
    exit 1
fi

info "Replacing prefix: $OLD_PREFIX -> $NEW_PREFIX"

# Create backup (optional, can be commented out)
BACKUP_DIR=".backup-$(date +%Y%m%d-%H%M%S)"
if [ "${CREATE_BACKUP:-true}" = "true" ]; then
    info "Creating backup in $BACKUP_DIR..."
    mkdir -p "$BACKUP_DIR"
    cp -r force-app "$BACKUP_DIR/" 2>/dev/null || true
    info "Backup created"
fi

# Counters
FILES_CHANGED=0
REPLACEMENTS=0

# Optional behavior: rename files/directories that contain OLD_PREFIX
# This is important for Salesforce source format where the "fullName" of a component
# is derived from its path (e.g., objects/<ObjectName>/fields/<FieldName>.field-meta.xml).
#
# Enable by default to match "universal" expectation; can be disabled via env var:
#   RENAME_PATHS=false ./scripts/replace-prefix.sh old__ new__
RENAME_PATHS="${RENAME_PATHS:-true}"
PATHS_RENAMED=0

# Function to replace in file
replace_in_file() {
    local file="$1"
    local temp_file="${file}.tmp"
    
    # Escape special characters for sed
    local old_escaped=$(printf '%s\n' "$OLD_PREFIX" | sed 's/[[\.*^$()+?{|]/\\&/g')
    local new_escaped=$(printf '%s\n' "$NEW_PREFIX" | sed 's/[[\.*^$()+?{|]/\\&/g')
    
    # Replace prefix in file
    if sed "s/${old_escaped}/${new_escaped}/g" "$file" > "$temp_file" 2>/dev/null; then
        # Check if there were any changes
        if ! cmp -s "$file" "$temp_file"; then
            mv "$temp_file" "$file"
            local count=$(grep -o "${NEW_PREFIX}" "$file" | wc -l | tr -d ' ')
            REPLACEMENTS=$((REPLACEMENTS + count))
            return 0
        else
            rm -f "$temp_file"
            return 1
        fi
    else
        rm -f "$temp_file"
        return 1
    fi
}

# Find all files containing the old prefix
info "Searching for files with prefix $OLD_PREFIX..."

# Search for files with extensions that may contain code
FILES=$(grep -r -l "$OLD_PREFIX" force-app --include="*.cls" --include="*.js" --include="*.xml" --include="*.html" 2>/dev/null || true)

if [ -z "$FILES" ]; then
    warn "No files with prefix $OLD_PREFIX found"
else
    # Process each file
    while IFS= read -r file; do
        if [ -f "$file" ]; then
            if replace_in_file "$file"; then
                FILES_CHANGED=$((FILES_CHANGED + 1))
                info "Updated: $file"
            fi
        fi
    done <<< "$FILES"
fi

# Rename paths (directories/files) that include the old prefix.
# We do this after content replacement so metadata remains consistent.
if [ "$RENAME_PATHS" = "true" ]; then
    info "Renaming paths containing $OLD_PREFIX..."
    # Use Python for reliable bottom-up renames (portable, avoids 'find' differences).
    PATHS_RENAMED=$(python3 - "$OLD_PREFIX" "$NEW_PREFIX" <<'PY'
import os
import sys

old = sys.argv[1]
new = sys.argv[2]
root = "force-app"

renamed = 0
for dirpath, dirnames, filenames in os.walk(root, topdown=False):
    # Rename files first
    for name in filenames:
        if old in name:
            src = os.path.join(dirpath, name)
            dst = os.path.join(dirpath, name.replace(old, new))
            if src != dst and not os.path.exists(dst):
                os.rename(src, dst)
                renamed += 1
    # Then rename directories
    for name in dirnames:
        if old in name:
            src = os.path.join(dirpath, name)
            dst = os.path.join(dirpath, name.replace(old, new))
            if src != dst and not os.path.exists(dst):
                os.rename(src, dst)
                renamed += 1

print(renamed)
PY
)
    info "Paths renamed: $PATHS_RENAMED"
else
    warn "Path renaming disabled (RENAME_PATHS=false)"
fi

# Final statistics
echo ""
info "Replacement completed!"
info "Files changed: $FILES_CHANGED"
info "Total replacements: $REPLACEMENTS"
info "Paths renamed: $PATHS_RENAMED"

if [ "${CREATE_BACKUP:-true}" = "true" ]; then
    info "Backup saved in: $BACKUP_DIR"
    info "To restore: cp -r $BACKUP_DIR/force-app/* force-app/"
fi

# Show examples of changes
if [ $REPLACEMENTS -gt 0 ]; then
    echo ""
    info "Examples of changes:"
    grep -h "${NEW_PREFIX}" force-app --include="*.cls" --include="*.js" | head -3 | sed 's/^/  /' || true
fi
