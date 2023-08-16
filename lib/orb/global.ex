defmodule Orb.Global do
  @moduledoc false

  defstruct [:name, :type, :initial_value, :mutability, :exported]

  def new(type, name, mutability, exported, value)
      when type in [:i32, :f32] and
             is_atom(name) and
             mutability in ~w[readonly mutable]a and
             exported in ~w[internal exported]a do
    %__MODULE__{
      name: name,
      type: type,
      initial_value: value,
      mutability: mutability,
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
        Orb.ToWat.to_wat(initial_value, ""),
        ")\n"
      ]
    end
  end

  defmodule DSL do
    @moduledoc """
    Adds @global_name support
    """

    import Kernel, except: [@: 1]

    defmacro @{:@, _meta, [arg]} do
      quote do
        Kernel.@(unquote(arg))
      end
    end

    # defmacro @{name, meta, _args} do
    #   if Module.has_attribute?(__CALLER__.module, name) do
    #     quote do
    #       Kernel.@(unquote(Macro.var(name, nil)))
    #     end
    #   else
    #     {:global_get, meta, [name]}
    #   end
    # end

    defmacro @{name, meta, _args} do
      {:global_get, meta, [name]}
    end
  end
end
