const assert = require("assert")
const { load, deepEqual } = require("./load")

const lists = load("common/Lists.js")

const real = [{ id: "a" }, { id: "b" }]
assert.strictEqual(lists.array(real), real, "a real array comes back as itself")

const sequence = { length: 2, 0: { id: "a" }, 1: { id: "b" } }
const copied = lists.array(sequence)
assert.ok(Array.isArray(copied), "a list-shaped value becomes a real array")
assert.strictEqual(copied[0], sequence[0], "holding the same items")
assert.strictEqual(copied.length, 2)

for (const [what, value] of [["undefined", undefined], ["null", null], ["a number", 3],
  ["a string", "ab"], ["a function", function(a, b) {}], ["an object with no length", { 0: "a" }]]) {
  deepEqual(lists.array(value), [], `${what} is no list`)
}

for (const [what, size] of [["infinite", Infinity], ["negative", -1], ["fractional", 1.5],
  ["NaN", NaN], ["a string", "1"], ["too long", lists.MAX_LENGTH + 1]]) {
  deepEqual(lists.array({ length: size, 0: "a" }), [], `a ${what} length is refused`)
}
deepEqual(lists.array(new Array(lists.MAX_LENGTH + 1).fill("a")), [],
  "a real array past the bound is refused the same way")
assert.strictEqual(lists.array({ length: lists.MAX_LENGTH }).length, lists.MAX_LENGTH,
  "while the bound itself is a list")
deepEqual(lists.array({ length: 0 }), [])

console.log("test_lists.js ok")
