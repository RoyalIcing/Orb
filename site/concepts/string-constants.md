# String Constants

Another feature that is central to C is string constants. You type `"abc"` and you can pass it around, read the characters in it, and even do operations on it.

WebAssembly lets you initialize a region of memory with a string. But it doesn’t let you use the strings directly. Instead you must manually assign memory addresses for each string constant, and then only refer to the addresses.

Orb adds a simple convenience on top, letting you use strings directly. At compile-time these strings are substituted by their addresses.

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

Note: dynamic string concententation is not supported in core Orb as that requires memory allocation. If you wish to build dynamic strings check out `SilverOrb.StringBuilder` from Orb‘s sister standard library.