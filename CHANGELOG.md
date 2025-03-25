# Changelog

All notable changes to this project will be documented in this file.

## v0.2.1 (2025-03-25)

### Added
- Support for `Str` as local variables
- Allow assigning one `Str` variable to another `Str` variable
    - `Str` are two `name.ptr` and `name.size` local variables under the hood, so this is equivalent to `first.ptr = second.ptr; first.size = second.size`
- Allow assigning call returning `Str` to `Str` variable

## v0.2.0 (2025-03-01)

### Added
- Support for accepting `Str` as function parameter
- Allow passing `Str` type when calling functions
- Added `:ptr` and `:size` access for `Str` variables
- Support for matching (destructuring) tuples e.g. `{x, y, z} = some_function()`
- Support for `cond/2` expression e.g. `cond result: I32 do …`
- Support for passing params to functions in tables (`call_indirect`)
- Allow importing memory (Closes #42)
- Added `Memory.export/1` for renaming what export
- Added features and anti-features to project readme

### Changed
- Updated to Elixir 1.18