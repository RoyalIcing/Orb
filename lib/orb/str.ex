defmodule Orb.Str do
  @moduledoc """
  A string slice. Represented under the hood as a `{:i32, :i32}` tuple, the first element being the base address, and the second element the string length.
  """

  defstruct push_type: __MODULE__, memory_offset: nil, string: nil

  with @behaviour Orb.CustomType do
    @impl Orb.CustomType
    def wasm_type, do: {:i32, :i32}
  end

  @doc """
  An empty string, represented by a string slice from offset zero and of zero length.

  The ol’ billion-dollar mistake: null.
  """
  def empty() do
    %__MODULE__{
      memory_offset: 0x0,
      string: ""
    }
  end

  def to_slice(%__MODULE__{} = str) do
    len = byte_size(str.string)

    if is_integer(str.memory_offset) do
      Orb.Memory.Slice.from(str.memory_offset, len)
    else
      Orb.Memory.Slice.from(str.memory_offset, Orb.Instruction.Const.new(:i32, len))
    end
  end

  def to_slice(string) when is_binary(string) do
    string |> Orb.Constants.expand_if_needed() |> to_slice()
  end

  def get_base_address(string) when is_binary(string) do
    str = string |> Orb.Constants.expand_if_needed()
    str.memory_offset
  end

  # with @behaviour Access do
  #   @impl Access
  #   def fetch(%VariableReference{} = var_ref, :ptr) do
  #     ast = %Orb.VariableReference.Local{
  #       identifier: 
  #     }
  #     {:ok, ast}
  #   end
  # 
  #   @impl Access
  #   def get_and_update(_data, _key, _function) do
  #     raise UndefinedFunctionError, module: __MODULE__, function: :get_and_update, arity: 3
  #   end
  # 
  #   @impl Access
  #   def pop(_data, _key) do
  #     raise UndefinedFunctionError, module: __MODULE__, function: :pop, arity: 2
  #   end
  # end

  defimpl Orb.ToWat do
    def to_wat(
          %Orb.Str{memory_offset: memory_offset, string: string},
          indent
        ) do
      [
        indent,
        Orb.Instruction.Const.new(:i32, memory_offset)
        |> Orb.ToWat.to_wat(""),
        " ",
        Orb.Instruction.Const.new(:i32, byte_size(string))
        |> Orb.ToWat.to_wat("")
      ]
    end
  end

  defimpl Orb.ToWasm do
    def to_wasm(
          %Orb.Str{memory_offset: memory_offset, string: string},
          context
        ) do
      [
        Orb.Instruction.Const.new(:i32, memory_offset)
        |> Orb.ToWasm.to_wasm(context),
        Orb.Instruction.Const.new(:i32, byte_size(string))
        |> Orb.ToWasm.to_wasm(context)
      ]
    end
  end

  defmodule Slice do
    @moduledoc """
    A string slice represented as a i64, a compromise for when storing strings as globals (Globals cannot be `(i32 i32)`, only single primitives like `i32` or `i64`).
    """
    defstruct push_type: __MODULE__, slice64: nil

    def to_str(str_slice) do
      {
        Orb.I32.wrap_i64(str_slice),
        str_slice |> Orb.I64.shr_u(32) |> Orb.I32.wrap_i64()
      }
    end

    with @behaviour Orb.CustomType do
      @impl Orb.CustomType
      def wasm_type, do: :i64
    end

    defimpl Orb.ToWat do
      def to_wat(%Orb.Str.Slice{slice64: slice64}, indent) do
        Orb.Instruction.Const.new(:i64, slice64)
        |> Orb.ToWat.to_wat(indent)
      end
    end
  end
end
