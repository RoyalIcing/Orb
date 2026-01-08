# Used by "mix format"

locals_without_parens = [
  i32: 1,
  let: 1,
  return: 1,
  local: 1,
  global: 1,
  const: 1,
  defc: 2
]

[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  locals_without_parens: locals_without_parens,
  export: [
    locals_without_parens: locals_without_parens
  ]
]
