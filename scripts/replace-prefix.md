# Prefix Replacement Script

## Description

The `replace-prefix.sh` script is a universal tool for replacing any namespace prefix with another prefix in a Salesforce DX project. This is useful when deploying projects to different Salesforce orgs where different namespace prefixes may be used.

## Location

The script is located in the `scripts/` folder of the project.

## Usage

### Basic Usage

From project root:
```bash
./scripts/replace-prefix.sh pharos__ ph_dev4__
```

Or from scripts folder:
```bash
cd scripts
./replace-prefix.sh pharos__ ph_dev4__
```

### Arguments

1. **Old prefix** (first argument): The prefix to be replaced
2. **New prefix** (second argument): The replacement prefix

### Interactive Mode

If arguments are not provided, the script will prompt for them interactively:

```bash
./scripts/replace-prefix.sh
# Enter old prefix to replace (e.g., pharos__):
# Enter new prefix (e.g., ph_dev4__):
```

### Using Environment Variables

You can use environment variables `OLD_PREFIX_ENV` and `NEW_PREFIX_ENV`:

```bash
export OLD_PREFIX_ENV=pharos__
export NEW_PREFIX_ENV=ph_dev4__
./scripts/replace-prefix.sh
```

## Features

1. **Automatic Prefix Extension (namespace delimiter)**: For the common Salesforce *namespace delimiter* form `ns__`, if a provided prefix contains underscores but doesn't end with `__`, the script will automatically extend it by adding `__` (e.g., `ph_dev4` becomes `ph_dev4__`).

   - This heuristic **does not apply** to Apex namespace references like `ns.` (for example `pharos.`).

2. **Backup Creation**: By default, the script creates a backup of all files to be modified in the `.backup-YYYYMMDD-HHMMSS` directory. To disable backup creation, set the environment variable:
   ```bash
   CREATE_BACKUP=false ./scripts/replace-prefix.sh pharos__ ph_dev4__
   ```

3. **Safety**: The script automatically finds the project root by looking for the `force-app` directory, so it can be run from anywhere.

4. **Content Replacement**: The script searches for and replaces prefixes in the contents of the following file types:
   - `*.cls` - Apex classes
   - `*.js` - JavaScript files
   - `*.xml` - XML metadata files
   - `*.html` - HTML templates

5. **Path Renaming (important for Salesforce source format)**: By default, the script also renames files and folders under `force-app/` whose **names** contain the old prefix. This matters because many Salesforce component `fullName`s are derived from the path (for example, `objects/<ObjectName>/fields/<Field>.field-meta.xml`).

   - Disable if needed:

   ```bash
   RENAME_PATHS=false ./scripts/replace-prefix.sh pharos__ ph_dev4__
   ```

6. **Validation**: The script validates that old and new prefixes are different before proceeding.

## Examples

### Replace pharos__ with ph_dev4__

```bash
./scripts/replace-prefix.sh pharos__ ph_dev4__
```

Result:
- `pharos__Log__c` → `ph_dev4__Log__c`
- `pharos__Category__c` → `ph_dev4__Category__c`

### Replace Apex namespace prefix (pharos. → ph_dev_patch_1.)

Use this when your org namespace is `ph_dev_patch_1` and the code references namespaced Apex classes (e.g., `pharos.Logger`).

```bash
./scripts/replace-prefix.sh "pharos." "ph_dev_patch_1."
```

Result:
- `pharos.Logger` → `ph_dev_patch_1.Logger`
- `pharos.LogBuilder` → `ph_dev_patch_1.LogBuilder`

### Replace ph_dev4__ with custom__

```bash
./scripts/replace-prefix.sh ph_dev4__ custom__
```

Result:
- `ph_dev4__Log__c` → `custom__Log__c`
- `ph_dev4__Category__c` → `custom__Category__c`

### Replace any prefix

```bash
./scripts/replace-prefix.sh old_prefix__ new_prefix__
```

## Restoring from Backup

If you need to rollback changes:

```bash
cp -r .backup-YYYYMMDD-HHMMSS/force-app/* force-app/
```

Where `YYYYMMDD-HHMMSS` is the date and time when the backup was created.

## Exit Codes

- `0` - Success
- `1` - Error (empty prefix, same prefixes, wrong directory, etc.)

## Statistics

After execution, the script outputs:
- Number of files changed
- Total number of replacements
- Examples of changes

## Notes

- The script uses `sed` for replacement, ensuring exact prefix replacement
- All changes are made only in the `force-app` directory
- The script does not modify files that don't contain the old prefix
- Special characters in prefixes are automatically escaped for safe replacement
