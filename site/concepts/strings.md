# Strings

A feature central to C is string constants: you type `"abc"` and you can pass it around, read the characters in it, and even do operations on it. Underneath it's really a pointer to a sequence of bytes initialized in memory for you, yet C makes it feel natural.

WebAssembly also gives you the ability to initialize a region of its memory with a string. But it doesn’t let you use the strings directly like C. Instead you must manually allocate memory addresses for each string constant, and then in functions hard-code the addresses, remembering what at what memory offset each string had.

Orb adds a simple string constant system like C’s by letting you use strings directly. At compile-time these strings are substituted by a tuple of their `i32` memory address and `i32` byte length, represented as the custom type `Orb.Str`.

```elixir
defmodule StaticHTMLPage do
  use Orb

  defw get_mime_type, Str do
    "text/html"
  end

  defw get_body, Str do
    """
    <!doctype html>
    <meta charset="utf-8">
    <h1>Hello world</h1>
    """
  end
end
```

## Building dynamic strings

Dynamic string concatentation is not supported in vanilla Orb as that requires a memory allocator which core WebAssembly doesn’t have. This is one of the batteries that comes with Orb‘s sister standard library **SilverOrb**.

Here’s an example rendering a dynamic HTML page:

```elixir
defmodule DynamicHTMLPage do
  use Orb
  use SilverOrb.StringBuilder

  global do
    @hour_of_day 8
  end

  defw set_hour_of_day(hour) do
    @hour_of_day = hour
  end

  defwp daytime?() do
    @hour_of_day >= 6 and @hour_of_day <= 19
  end

  defw text_html, StringBuilder do
    StringBuilder.build! do
      """
      <!doctype html>
      <meta charset="utf-8">
      """

      if daytime?() do
        "<h1>Hello 🌞 sunny world</h1>"
      else
        "<h1>Hello 🌛 moonlit world</h1>"
      end
    end
  end
end
```

In modern web development we have components, and we can create simple components with `SilverOrb.StringBuilder` too. Let’s extract the `<h1>` rendering into its own component module:

```elixir
defmodule HelloWorldComponent do
  use Orb
  use SilverOrb.StringBuilder

  defwp daytime?(hour_of_day: I32), I32 do
    hour_of_day >= 6 &&& hour_of_day <= 19
  end

  defw render(hour_of_day: I32), StringBuilder do
    StringBuilder.build! do
      "<h1>"

      if daytime?(hour_of_day) do
        "Hello 🌞 sunny world"
      else
        "Hello 🌛 moonlit world"
      end

      "</h1>\n"
    end
  end
end

defmodule DynamicHTMLPage do
  use Orb
  use SilverOrb.StringBuilder

  Orb.include(HelloWorldComponent)

  global do
    @hour_of_day 8
  end

  defw set_hour_of_day(hour: I32) do
    @hour_of_day = hour
  end

  defw text_html(), StringBuilder do
    StringBuilder.build! do
      """
      <!doctype html>
      <meta charset="utf-8">
      """

      HelloWorldComponent.render(@hour_of_day)
    end
  end
end
```