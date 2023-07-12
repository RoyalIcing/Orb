defmodule Orb.Global do
  defstruct [:name, :type, :initial_value, :mutability, :exported]

  def new(:i32 = type, name, mutability, exported, value)
      when is_atom(name) and
             mutability in ~w[readonly mutable]a and
             exported in ~w[internal exported]a do
    %__MODULE__{
      name: name,
      type: type,
      initial_value: value,
      mutability: :mutable,
      exported: exported == :exported
    }
  end

  defimpl Orb.ToWat do
    def to_wat(
          %Orb.Global{
            name: name,
            type: type,
            initial_value: initial_value,
            mutability: mutability,
            exported: exported
          },
          indent
        ) do
      [
        indent,
        "(global ",
        case exported do
          false -> [?$, to_string(name)]
          true -> [?$, to_string(name), ~S{ (export "}, to_string(name), ~S{")}]
        end,
        " ",
        case mutability do
          :readonly -> to_string(type)
          :mutable -> ["(mut ", to_string(type), ?)]
        end,
        " ",
        Orb.ToWat.to_wat(initial_value, indent),
        ")\n"
      ]
    end
  end
end
