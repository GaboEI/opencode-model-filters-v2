import { homedir } from "node:os"
import { join } from "node:path"
import { readFile } from "node:fs/promises"

export function configPath(env = process.env) {
  return env.OPENCODE_CONFIG || join(env.XDG_CONFIG_HOME || join(homedir(), ".config"), "opencode", "opencode.json")
}

export function parseJsonc(text) {
  try {
    return JSON.parse(text)
  } catch {
    const withoutComments = text
      .replace(/\/\*[\s\S]*?\*\//g, "")
      .replace(/(^|[^:])\/\/.*$/gm, "$1")
      .replace(/,\s*([}\]])/g, "$1")
    return JSON.parse(withoutComments)
  }
}

export async function loadProviderRules(path = configPath()) {
  try {
    const config = parseJsonc(await readFile(path, "utf8"))
    return config && typeof config.provider === "object" ? config.provider : {}
  } catch {
    return {}
  }
}

function strings(value) {
  return Array.isArray(value) ? value.filter((item) => typeof item === "string") : []
}

export function applyFilters(models, providers) {
  for (const provider of models.provider.list()) {
    const rule = providers[provider.provider.id]
    if (!rule || typeof rule !== "object") continue
    const whitelist = new Set(strings(rule.whitelist))
    const blacklist = new Set(strings(rule.blacklist))
    if (whitelist.size === 0 && blacklist.size === 0) continue
    for (const model of models.list(provider.provider.id)) {
      const id = model.id ?? model.modelID
      if (typeof id !== "string") continue
      if ((whitelist.size > 0 && !whitelist.has(id)) || blacklist.has(id)) {
        models.remove(provider.provider.id, id)
      }
    }
  }
}

export default {
  id: "opencode-model-filters-v2",
  setup: async (context) => {
    const providers = await loadProviderRules()
    const registration = await context.model.transform((models) => applyFilters(models, providers))
    return async () => registration.dispose()
  },
}
