---
name: node-installer
description: "Install and manage Node.js versions using nvm or fnm"
user-invocable: true
allowed-tools:
  - Bash
  - Read
  - Write
---

# Node Installer

Install and manage Node.js versions for your project.

## Purpose

Detect required Node.js version from project files and install it using the appropriate version manager (nvm, fnm, or direct install).

## Procedure

### 1. Detect Required Version

Check for Node.js version specification in order of precedence:

1. `.nvmrc` file
2. `.node-version` file
3. `package.json` engines.node field
4. `volta.node` in package.json

```bash
# Check .nvmrc
cat .nvmrc 2>/dev/null

# Check .node-version
cat .node-version 2>/dev/null

# Check package.json engines
jq -r '.engines.node // empty' package.json 2>/dev/null

# Check volta
jq -r '.volta.node // empty' package.json 2>/dev/null
```

### 2. Detect Version Manager

Check which version manager is available:

```bash
# Check for fnm (preferred - faster)
command -v fnm

# Check for nvm
command -v nvm || [ -s "$NVM_DIR/nvm.sh" ]
```

### 3. Install Node.js

Using detected version manager:

**fnm:**
```bash
fnm install <version>
fnm use <version>
```

**nvm:**
```bash
nvm install <version>
nvm use <version>
```

### 4. Verify Installation

```bash
node --version
npm --version
```

## Patterns

### Auto-detect and Install
```bash
# If .nvmrc exists
fnm install && fnm use
# or
nvm install && nvm use
```

### Install Specific Version
```bash
fnm install 20.11.0
fnm use 20.11.0
```

## Anti-patterns

- **Installing globally without version manager**: Avoid `brew install node` as it doesn't support multiple versions
- **Ignoring .nvmrc**: Always respect project's version requirements
- **Using sudo**: Never use `sudo npm install -g`, fix permissions instead
