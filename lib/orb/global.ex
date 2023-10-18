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

  def new32(name, mutability, exported, value)
      when is_atom(name) and
             mutability in ~w[readonly mutable]a and
             exported in ~w[internal exported]a and is_integer(value) do
    %__MODULE__{
      name: name,
      type: :i32,
      initial_value: {:i32_const, value},
      mutability: mutability,
      exported: exported == :exported
    }
  end

  def new32(name, mutability, exported, value)
      when is_atom(name) and
             mutability in ~w[readonly mutable]a and
             exported in ~w[internal exported]a and is_float(value) do
    %__MODULE__{
      name: name,
      type: :f32,
      initial_value: {:f32_const, value},
      mutability: mutability,
      exported: exported == :exported
    }
  end

  def new32(name, mutability, exported, value)
      when is_atom(name) and
             mutability in ~w[readonly mutable]a and
             exported in ~w[internal exported]a and is_binary(value) do
    require Orb

    %__MODULE__{
      name: name,
      type: :i32_string,
      initial_value: value,
      mutability: mutability,
      exported: exported == :exported
    }
  end

  defmacro register32(mutability, exported, list)
           when mutability in ~w{readonly mutable}a and
                  exported in ~w[internal exported]a do
    quote do
      @wasm_globals (for {key, value} <- unquote(list) do
                       Orb.Global.new32(
                         key,
                         unquote(mutability),
                         unquote(exported),
                         value
                       )
                     end)
    end
  end

  def expand!(%Orb.Global{type: :i32_string, initial_value: string} = global) do
    %Orb.Global{global | type: :i32, initial_value: Orb.__lookup_constant!(string)}
  end

  def expand!(%Orb.Global{} = global) do
    global
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

  defmodule Declare do
    defmodule ReadonlyDSL do
      import Kernel, except: [@: 1]

      defmacro @{name, _meta, [arg]} do
        quote do
          with do
            require Orb.Global
            Orb.Global.register32(:readonly, :internal, [{unquote(name), unquote(arg)}])
          end
        end
      end
    end

    defmodule MutableDSL do
      import Kernel, except: [@: 1]

      defmacro @{name, _meta, [arg]} do
        quote do
          with do
            require Orb.Global
            Orb.Global.register32(:mutable, :internal, [{unquote(name), unquote(arg)}])
          end
        end
      end
    end

    defmodule ExportReadonlyDSL do
      import Kernel, except: [@: 1]

      defmacro @{name, _meta, [arg]} do
        quote do
          with do
            require Orb.Global
            Orb.Global.register32(:readonly, :exported, [{unquote(name), unquote(arg)}])
          end
        end
      end
    end

    defmodule ExportMutableDSL do
      import Kernel, except: [@: 1]

      defmacro @{name, _meta, [arg]} do
        quote do
          with do
            require Orb.Global
            Orb.Global.register32(:mutable, :exported, [{unquote(name), unquote(arg)}])
          end
        end
      end
    end

    defmacro __import_mode(:readonly), do: quote(do: import(ReadonlyDSL))
    defmacro __import_mode(:mutable), do: quote(do: import(MutableDSL))
    defmacro __import_mode(:export_readonly), do: quote(do: import(ExportReadonlyDSL))
    defmacro __import_mode(:export_mutable), do: quote(do: import(ExportMutableDSL))
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

    defmacro @{name, _meta, _args} do
      quote do
        Orb.Instruction.global_get(Orb.__lookup_global_type!(unquote(name)), unquote(name))
      end
    end
  end
end
