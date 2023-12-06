defmodule Examples.HexFormatter do
  use Orb

  Memory.pages(1)

  wasm_mode(U32)

  defw u32_to_hex_lower(value: I32, write_ptr: I32.U8.UnsafePointer),
    i: I32,
    digit: I32 do
    i = 8

    # for i <- 8..1//-1 do
    loop Digits do
      i = i - 1

      digit = I32.rem_u(value, 16)
      value = value / 16

      if digit > 9 do
        write_ptr[at!: i] = ?a + digit - 10
      else
        write_ptr[at!: i] = ?0 + digit
      end

      Digits.continue(if: i > 0)
    end
  end
end
