defmodule Orb.Select do
  defstruct [:push_type, :condition, :when_true, :when_false]

  def new(type, condition, when_true, when_false) do
    %__MODULE__{
      push_type: type,
      condition: condition,
      when_true: when_true,
      when_false: when_false
    }
  end

  defimpl Orb.ToWat do
    def to_wat(
          %Orb.Select{
            condition: condition,
            when_true: when_true,
            when_false: when_false
          },
          indent
        ) do
      [
        indent,
        "(select\n",
        Orb.ToWat.to_wat(when_true, indent <> "  "),
        ?\n,
        Orb.ToWat.to_wat(when_false, indent <> "  "),
        ?\n,
        Orb.ToWat.to_wat(condition, indent <> "  "),
        ?\n,
        indent,
        ")\n"
      ]
    end
  end

  defimpl Orb.ToWasm do
    def to_wasm(
          %Orb.Select{
            condition: condition,
            when_true: when_true,
            when_false: when_false
          },
          context
        ) do
      [
        Orb.ToWasm.to_wasm(when_true, context),
        Orb.ToWasm.to_wasm(when_false, context),
        Orb.ToWasm.to_wasm(condition, context),
        [0x1B]
      ]
    end
  end
end
