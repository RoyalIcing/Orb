defmodule Orb.ToWat.Instructions do
  @moduledoc false

  def do_wat(instruction), do: do_wat(instruction, "")

  def do_wat(list, indent) when is_list(list) do
    Enum.map(list, &do_wat(&1, indent)) |> Enum.intersperse("\n")
    # Enum.map(list, &do_wat(&1, indent))
  end

  # TODO: change default to i64
  def do_wat(value, indent) when is_integer(value), do: "#{indent}(i32.const #{value})"
  # TODO: how do we support 64-bit floats?
  # Note that Rust defaults to 64-bit floats: https://doc.rust-lang.org/book/ch03-02-data-types.html
  # “The default type is f64 because on modern CPUs, it’s roughly the same speed as f32 but is capable of more precision.”
  # So should our default be 64-bit too?
  def do_wat(value, indent) when is_float(value), do: "#{indent}(f32.const #{value})"

  def do_wat(%_struct{} = value, indent) do
    # Protocol.assert_impl!(struct, Orb.ToWat)

    Orb.ToWat.to_wat(value, indent)
  end
end
