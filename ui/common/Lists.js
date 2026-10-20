.pragma library

// Qt 6.12 hands an array passed through a `var` signal argument over as a
// sequence that `Array.isArray` rejects, and every array nested in the
// payload arrives the same way. Upstream still checks `Array.isArray`.
// Anything list-shaped counts, but saved settings and mail reach this too, so
// the length must be a whole number from 0 to MAX_LENGTH or there is no list.
var MAX_LENGTH = 10000

function array(value) {
  var size = value && typeof value === "object" ? value.length : -1
  if (typeof size !== "number" || size % 1 !== 0 || size < 0 || size > MAX_LENGTH) return []
  if (Array.isArray(value)) return value
  var out = []
  for (var i = 0; i < size; i++) out.push(value[i])
  return out
}
