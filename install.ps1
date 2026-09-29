$ErrorActionPreference = "Stop"

$repoZip = "https://github.com/GaboEI/opencode-model-filters-v2/archive/refs/heads/main.zip"
$configPath = if ($env:OPENCODE_CONFIG) {
  $env:OPENCODE_CONFIG
} else {
  $candidate = Join-Path $HOME ".config/opencode/opencode.json"
  $appDataCandidate = Join-Path $env:APPDATA "opencode/opencode.json"
  if ((Test-Path $candidate) -or !(Test-Path $appDataCandidate)) { $candidate } else { $appDataCandidate }
}
$opencodeDir = Split-Path -Parent $configPath
$installDir = if ($env:OPENCODE_MODEL_FILTERS_DIR) {
  $env:OPENCODE_MODEL_FILTERS_DIR
} else {
  Join-Path $opencodeDir "plugins/opencode-model-filters-v2"
}

$version = opencode -v
$isNewVersion = $version -like "v2*"

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("opencode-model-filters-" + [guid]::NewGuid().ToString("N"))
$zipPath = Join-Path $tempRoot "plugin.zip"
$extractRoot = Join-Path $tempRoot "extract"
New-Item -ItemType Directory -Path $tempRoot, $extractRoot -Force | Out-Null

try {
  Invoke-WebRequest -Uri $repoZip -OutFile $zipPath -UseBasicParsing
  Expand-Archive -Path $zipPath -DestinationPath $extractRoot -Force
  $sourceDir = Join-Path $extractRoot "opencode-model-filters-v2-main"
  if (!(Test-Path $sourceDir)) { throw "The downloaded archive has an unexpected layout." }

  New-Item -ItemType Directory -Path (Split-Path -Parent $installDir) -Force | Out-Null
  if (Test-Path $installDir) {
    $backupDir = "$installDir.backup.$(Get-Date -Format yyyyMMddHHmmss)"
    Move-Item -Path $installDir -Destination $backupDir
    Write-Host "Previous installation preserved at $backupDir"
  }
  Move-Item -Path $sourceDir -Destination $installDir

  if (Test-Path $configPath) {
    $nodeScript = @'
import fs from "node:fs";
const configPath = process.argv[2];
const installDir = process.argv[3];
const isNewVersion = process.argv[4];
const entry = isNewVersion ? JSON.stringify(`${installDir.replaceAll("\\", "/")}`) : JSON.stringify(`${installDir.replaceAll("\\", "/")}/src/index.js`);
let text = fs.readFileSync(configPath, "utf8");
if (!text.includes(entry)) {
  const match = /["']plugin["']\s*:\s*\[/.exec(text);
  if (!match) throw new Error(`Could not find a plugin array in ${configPath}`);
  const open = text.indexOf("[", match.index);
  let close = -1, depth = 0, quote = null, escaped = false;
  for (let i = open; i < text.length; i += 1) {
    const ch = text[i];
    if (quote) { if (escaped) escaped = false; else if (ch === "\\") escaped = true; else if (ch === quote) quote = null; continue; }
    if (ch === '"' || ch === "'") { quote = ch; continue; }
    if (ch === "[") depth += 1;
    if (ch === "]" && --depth === 0) { close = i; break; }
  }
  if (close < 0) throw new Error(`Could not parse the plugin array in ${configPath}`);
  const existing = text.slice(open + 1, close);
  const trimmed = existing.replace(/\s+$/, "");
  const trailing = existing.slice(trimmed.length);
  const comma = trimmed.length > 0 && !trimmed.endsWith(",") ? "," : "";
  const itemIndent = /\n([ \t]*)[^\s]/.exec(existing)?.[1] ?? "  ";
  const updated = `${trimmed}${comma}\n${itemIndent}${entry}${trailing || "\n"}`;
  text = `${text.slice(0, open + 1)}${updated}${text.slice(close)}`;
  fs.copyFileSync(configPath, `${configPath}.backup.${Date.now()}`);
  fs.writeFileSync(configPath, text);
  console.log(`Added plugin entry to ${configPath}`);
} else console.log(`Plugin already configured: ${entry}`);
'@
    $nodeScript | & node --input-type=module - $configPath $installDir $isNewVersion
    if ($LASTEXITCODE -ne 0) { throw "Could not update the OpenCode configuration." }
  } else {
    Write-Host "Configuration file not found: $configPath"
    Write-Host "Add $installDir/src/index.js to the plugin array, then restart OpenCode."
  }
  Write-Host "Installed OpenCode Model Filters V2 at $installDir"
  Write-Host "Restart OpenCode to load the plugin."
} finally {
  Remove-Item -Path $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
