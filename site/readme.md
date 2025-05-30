# The raw ingredients of WebAssembly made beautifully composable with Elixir

- [Get Started](/install)
- [Documentation](https://hexdocs.pm/orb)
- [GitHub](https://github.com/RoyalIcing/Orb)

For years I’ve been a JavaScript developer. JavaScript runs everywhere: the browser where it was born, on the server, on your phone, on your laptop. But adopting JavaScript means adopting an increasingly complex and bloated suite of tools.

WebAssembly offers a reset, again born in the browser and again running on the server, your phone and laptop. It takes things down to the studs, at a level even lower than JavaScript, allowing even better performance. But use an existing language and the WebAssembly it outputs is often in the hundreds of kilobytes or more, and targets a single platform instead of running everywhere.

Orb takes the lessons of components from React: give developers the raw ingredients (here WebAssembly instructions instead of JSX’s HTML) and make them easily composable. Make UI components. Make state machine components. Make format decoder/encoder components. And then make those run everywhere.

Orb piggybacks on the existing Elixir ecosystem: it has a module system, it has a [package manager](https://hex.pm), it has a [test runner](https://hexdocs.pm/ex_unit/ExUnit.html), it has a language server, and it has an awesome community.

You can run any Elixir code when compiling your WebAssembly. It’s just like how React lets you run any JavaScript when rendering out HTML. Orb is like JSX but for WebAssembly instructions.

Orb is the full power of Elixir at compile time and the portability of WebAssembly at runtime. It’s [alpha](https://github.com/RoyalIcing/Orb/issues?q=is%3Aopen+is%3Aissue+milestone%3AAlpha) in active development. My aim is to refine the current feature set and complete a `.wasm` compiler (current it compiles to WebAssembly’s `.wat` text format) in order to [get to beta](https://github.com/RoyalIcing/Orb/issues?q=is%3Aopen+is%3Aissue+milestone%3ABeta).

## Features

- Allow access to nearly all WebAssembly 1.0 instructions.
- Produce tiny `.wasm` executables: kilobytes not megabytes.
- Use Elixir modules to organize and reuse code.
- Use Elixir functions and macros to create composable abstractions.
- Run any Elixir code at compile time, including Hex packages.
- Define your own WebAssembly instructions that output to `wat` and `wasm` formats.

## Anti-Features

- Allow executing any Elixir code in WebAssembly runtime. It’s not a goal of Orb to take a piece of everyday Elixir code and have it run in WebAssembly. However, because you can use macros you could decide to build that functionality on top of Orb.
- Allow access to the DOM. I believe the DOM is a poor fit for WebAssembly with its big object graph.
- WASI support. It’s not stabilized yet and for now I’d rather it be a library built on top of Orb.
- Produce the most optimized code possible through deep analysis. I recommend using `wasm-opt` if you really need to squeeze every byte possible.

## Write functions using an Elixir subset

You can write maths using familiar `+ - * /` operators in Orb.

```elixir
defmodule TemperatureConverter do
  use Orb

  defw celsius_to_fahrenheit(celsius: F32), F32 do
    celsius * (9.0 / 5.0) + 32.0
  end

  defw fahrenheit_to_celsius(fahrenheit: F32), F32 do
    (fahrenheit - 32.0) * (5.0 / 9.0)
  end
end

wasm_data = Orb.to_wasm(TemperatureConverter)
```

<form id="form|wasm|temperature_converter">
  <div><em>Try this code out:</em></div>
  <label>Celsius: <input name="celsius" type="number" inputmode="numeric" value="35"></label>
  <label>Fahrenheit: <input name="fahrenheit"  type="number" inputmode="numeric" value="95"></label>
</form>
<script type="module">
  const { instance } = await WebAssembly.instantiateStreaming(fetch("/wasm/temperature_converter"));
  const exports = instance.exports;
  const numberFormat = new Intl.NumberFormat("en", { maximumFractionDigits: 2 });
  const form = document.getElementById("form|wasm|temperature_converter");
  form.addEventListener("input", (event) => {
    const inputEl = event.target;
    const { name, valueAsNumber } = inputEl;
    if (name === "celsius") {
      const fahrenheit = exports.celsius_to_fahrenheit(valueAsNumber);
      form.elements.fahrenheit.value = numberFormat.format(fahrenheit);
    } else {
      const celsius = exports.fahrenheit_to_celsius(valueAsNumber);
      form.elements.celsius.value = numberFormat.format(celsius);
    }
  });
</script>

## Compose reusable modules

You can define a module, say for common ASCII operations, and then reuse it by including it into another module.

```elixir
defmodule ASCIIChecks do
  use Orb

  defw alpha?(char: I32.U8), I32 do
    (char >= ?a and char <= ?z) or (char >= ?A and char <= ?Z)
  end

  defw numeric?(char: I32.U8), I32 do
    char >= ?0 and char <= ?9
  end

  defw alphanumeric?(char: I32.U8), I32 do
    alpha?(char) or numeric?(char)
  end
end

defmodule UsernameValidation do
  use Orb

  import ASCIIChecks
  Orb.include(ASCIIChecks)

  Memory.pages(1)

  defw is_valid_username(char_ptr: I32.U8.UnsafePointer, len: I32), I32 do
    unless len > 0 do
      return(0)
    end

    loop EachChar do
      len = len - 1

      if len === 0 do
        return(alpha?(char_ptr[at!: 0]))
      end

      unless alphanumeric?(char_ptr[at!: len]) do
        return(0)
      end

      EachChar.continue()
    end
    
    1
  end
end

wasm_data = Orb.to_wasm(UsernameValidation)
```

## Dynamic compilation

Orb lets you run any Elixir code at compile-time. You could have dynamically enabled feature flags by reading from the `Process` dictionary. You could call out to any existing Elixir library from Hex (see example below). You could even make HTTP requests or talk to a database. Orb instructions are just data, so it doesn’t matter what process you use to make or inform that data.

### Use existing Elixir libraries at compile-time

Here we use the existing `mime` Elixir package to lookup a MIME type for a given file extension. These values get compiled as constants in the resulting WebAssembly module automatically.

```elixir
Mix.install([
  :orb,
  :mime
])

defmodule MimeType do
  use Orb

  defw(txt, Str, do: MIME.type("txt"))
  defw(json, Str, do: MIME.type("json"))
  defw(html, Str, do: MIME.type("html"))
  defw(css, Str, do: MIME.type("css"))
  defw(wasm, Str, do: MIME.type("wasm"))
  defw(epub, Str, do: MIME.type("epub"))
  defw(rss, Str, do: MIME.type("rss"))
  defw(atom, Str, do: MIME.type("atom"))
  defw(csv, Str, do: MIME.type("csv"))
  defw(woff2, Str, do: MIME.type("woff2"))
  defw(pdf, Str, do: MIME.type("pdf"))
end
```

## Write your own DSL

You can write your own DSLs using Elixir functions that spit out Orb instructions. Go another step and write macros that accept blocks and transform each Elixir expression. For example, this is how SilverOrb’s `StringBuilder` and `XMLBuilder` work under the hood.

```elixir
defmodule Assertions do
  require Orb.Instruction
  
  defmacro must!(do: conditions) do
    quote do
      Orb.Instruction.sequence do
        unquote(case conditions do
          {:__block__, _, multiple} -> multiple
          single -> [single]
        end)
        |> Enum.reduce(&I32.band/2)
        |> unless(do: unreachable!())
      end
    end
  end
end

defmodule Example do
  use Orb

  import Assertions

  defw celsius_to_fahrenheit(celsius: F32), F32 do
    must! do
      celsius > -273.15
      celsius < 500.0
    end

    celsius * (9.0 / 5.0) + 32.0
  end
end
```