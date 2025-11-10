# Utility helpers for test-lpjmlkit-clean
# Centralise small helpers used across R scripts to avoid duplication.

# Null-coalescing operator: returns 'a' if not NULL, otherwise 'b'
`%||%` <- function(a, b) {
  if (!is.null(a)) a else b
}
