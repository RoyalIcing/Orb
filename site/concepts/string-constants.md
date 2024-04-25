# String Constants

A feature central to C is string constants. You type `"abc"` and you can pass it around, read the characters in it, and even do operations on it. Underneath it's a pointer to a sequence of bytes, yet C makes it feel natural.

WebAssembly give you the ability to initialize a region of its memory with a string. But it doesn’t let you use the strings directly like C. Instead you must manually allocate memory addresses for each string constant, and then in functions only refer to the addresses, remembering what each are.

Orb adds a string constant system on top, like C by letting you use strings directly. At compile-time these strings are substituted by their addresses.

```elixir
defmodule HTMLPage do
  use Orb

  Memory.pages(1)

  defw get_mime_type(), Memory.Slice do
    "text/html"
  end

  defw get_body(), Memory.Slice do
    """
    <!doctype html>
    <meta charset="utf-8">
    <h1>Hello world</h1>
    """
  end
end
```

Note: dynamic string concatentation is not supported in core Orb as that requires a memory allocation system. If you wish to build dynamic strings check out `SilverOrb.StringBuilder` from Orb‘s sister standard library.