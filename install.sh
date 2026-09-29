#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${OPENCODE_MODEL_FILTERS_REPO:-https://github.com/GaboEI/opencode-model-filters-v2.git}"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
CONFIG_PATH="${OPENCODE_CONFIG:-$CONFIG_HOME/opencode/opencode.json}"
INSTALL_DIR="${OPENCODE_MODEL_FILTERS_DIR:-$CONFIG_HOME/opencode/plugins/opencode-model-filters-v2}"

command -v git >/dev/null 2>&1 || {
  printf '%s\n' 'Error: git is required to install this plugin.' >&2
  exit 1
}
command -v node >/dev/null 2>&1 || {
  printf '%s\n' 'Error: Node.js is required to update opencode.json.' >&2
  exit 1
}

version="$(opencode -v | sed -n 's/.*\(v[0-9][0-9.]*\).*/\1/p')"

printf 'opencode version: %s\n' "$version"

if [[ "$version" == v2* ]]; then
    IS_NEW_VERSION=true
    else
    IS_NEW_VERSION=false
fi

tmp_dir="$(mktemp -d)"
backup_path=""
cleanup() { rm -rf "$tmp_dir"; }
trap cleanup EXIT

git clone --depth 1 "$REPO_URL" "$tmp_dir/repo" >/dev/null
mkdir -p "$(dirname "$INSTALL_DIR")"

if [ -e "$INSTALL_DIR" ]; then
  backup_path="${INSTALL_DIR}.backup.$(date +%Y%m%d%H%M%S)"
  mv "$INSTALL_DIR" "$backup_path"
fi
mv "$tmp_dir/repo" "$INSTALL_DIR"

if [ ! -f "$CONFIG_PATH" ]; then
  printf 'Installed plugin at %s\n' "$INSTALL_DIR"
  printf 'Configuration file not found: %s\n' "$CONFIG_PATH"
  printf '%s\n' 'Add the plugin path to the plugin array, then restart OpenCode.'
  exit 0
fi

CONFIG_PATH="$CONFIG_PATH" INSTALL_DIR="$INSTALL_DIR" IS_NEW_VERSION="$IS_NEW_VERSION" node --input-type=module <<'NODE'
import fs from "node:fs";

const configPath = process.env.CONFIG_PATH;
const installDir = process.env.INSTALL_DIR;
const isNewVersion = process.env.IS_NEW_VERSION;

console.log("isNewVersion", isNewVersion)

const pluginEntry = isNewVersion ? JSON.stringify(`${installDir}`) : JSON.stringify(`${installDir}/src/index.js`);
let text = fs.readFileSync(configPath, "utf8");

if (text.includes(pluginEntry)) {
  console.log(`Plugin already configured: ${pluginEntry}`);
  process.exit(0);
}

const match = /["']plugin["']\s*:\s*\[/.exec(text);
if (!match) {
  throw new Error(`Could not find a plugin array in ${configPath}. Insert it manualy`);
}

const open = text.indexOf("[", match.index);
let close = -1;
let depth = 0;
let quote = null;
let escaped = false;
for (let i = open; i < text.length; i += 1) {
  const ch = text[i];
  if (quote) {
    if (escaped) escaped = false;
    else if (ch === "\\") escaped = true;
    else if (ch === quote) quote = null;
    continue;
  }
  if (ch === '"' || ch === "'") { quote = ch; continue; }
  if (ch === "[") depth += 1;
  if (ch === "]" && --depth === 0) { close = i; break; }
}
if (close < 0) throw new Error(`Could not parse the plugin array in ${configPath}`);

const existing = text.slice(open + 1, close);
const trimmed = existing.replace(/\s+$/, "");
const trailingWhitespace = existing.slice(trimmed.length);
const needsComma = trimmed.length > 0 && !trimmed.endsWith(",");
const itemIndent = /\n([ \t]*)[^\s]/.exec(existing)?.[1] ?? "  ";
const closeIndent = /^([ \t]*)/.exec(trailingWhitespace.split("\n").pop() ?? "")?.[1] ?? "";
const updated = `${trimmed}${needsComma ? "," : ""}\n${itemIndent}${pluginEntry}${trailingWhitespace || `\n${closeIndent}`}`;
text = `${text.slice(0, open + 1)}${updated}${text.slice(close)}`;
fs.copyFileSync(configPath, `${configPath}.backup.${Date.now()}`);
fs.writeFileSync(configPath, text);
console.log(`Added plugin entry to ${configPath}`);
NODE

printf 'Installed OpenCode Model Filters V2 at %s\n' "$INSTALL_DIR"
if [ -n "$backup_path" ]; then
  printf 'Previous installation preserved at %s\n' "$backup_path"
fi
printf '%s\n' 'Restart OpenCode to load the plugin.'
