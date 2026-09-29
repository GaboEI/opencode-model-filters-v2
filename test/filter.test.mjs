import test from "node:test"
import assert from "node:assert/strict"
import { applyFilters, parseJsonc } from "../src/index.js"

function editor(records, values) {
  const removed = []
  return {
    removed,
    modelEditor: {
      provider: { list: () => records },
      list: (id) => values[id].map((model) => ({ ...model })),
      remove: (provider, model) => removed.push([provider, model]),
    },
  }
}

test("blacklist hides only configured IDs and keeps new models", () => {
  const state = editor(
    [{ provider: { id: "example" } }],
    { example: [{ id: "blocked" }, { id: "new-model" }] },
  )
  applyFilters(state.modelEditor, { example: { blacklist: ["blocked"] } })
  assert.deepEqual(state.removed, [["example", "blocked"]])
})

test("whitelist hides IDs that are not explicitly allowed", () => {
  const state = editor(
    [{ provider: { id: "example" } }],
    { example: [{ id: "allowed" }, { id: "new-model" }] },
  )
  applyFilters(state.modelEditor, { example: { whitelist: ["allowed"] } })
  assert.deepEqual(state.removed, [["example", "new-model"]])
})

test("JSONC comments and trailing commas are accepted", () => {
  assert.deepEqual(parseJsonc('{ // comment\n "provider": {},\n}'), { provider: {} })
})
