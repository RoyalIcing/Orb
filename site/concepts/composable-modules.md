# Composable Modules

Orb builds upon Elixir’s module system. Modules let you break a larger problem into smaller pieces, giving those pieces meaningful names. It also opens you to reusing and recombining those pieces again for solving other problems.

The key that lets you glue Orb modules together is `Orb.include/1`.

First, define you a module you wish to reuse. Here we write a module for formatting numbers as hex.

```elixir
defmodule Hex do
  use Orb

  # Converts 3 to 3, 10 to A, 15 to F
  defw digit_to_hex_upper(digit: I32), I32 do
    I32.add(digit, if(digit <= 9, do: i32(?0), else: i32(?A - 10)))
  end

  # Writes out the byte as hex.
  defw write_u8_hex_upper(write_ptr: I32.U8.UnsafePointer, u8: I32.U8), I32 do
    write_ptr[at!: 0] = Hex.digit_to_hex_upper(u8 >>> 4)
    write_ptr[at!: 1] = Hex.digit_to_hex_upper(u8 &&& 4)
  end
end
```

And then define the module to consume it:

```elixir
defmodule RGB do
  use Orb

  # We want our module to be able to work with memory.
  Memory.pages(1)

  # We copy all the WebAssembly functions from Hex into this module.
  Orb.include(Hex)

  defw rgb_to_hex(write_ptr: I32.U8.UnsafePointer, red: I32, green: I32, blue: I32), I32 do
    Hex.write_u8_hex_upper(write_ptr, red)
    Hex.write_u8_hex_upper(write_ptr + 2, green)
    Hex.write_u8_hex_upper(write_ptr + 4, blue)
  end
end
```
