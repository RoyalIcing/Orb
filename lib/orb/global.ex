defmodule Orb.Global do
  @moduledoc false

  defstruct [:name, :type, :initial_value, :mutability, :exported, :comment]

  def new(nil, name, mutability, exported, value) when is_binary(value) do
    new(Orb.Constants.NulTerminatedString.Slice, name, mutability, exported, value)
    # new(Orb.Memory.Slice, name, mutability, exported, value)
  end

  def new(nil, name, mutability, exported, value) when is_integer(value) do
    new(Orb.I32, name, mutability, exported, value)
  end

  def new(nil, name, mutability, exported, value) when is_float(value) do
    new(Orb.F32, name, mutability, exported, value)
  end

  def new(type, name, mutability, exported, value)
      when is_atom(type) and is_atom(name) and
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
      initial_value: value,
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
      initial_value: value,
      mutability: mutability,
      exported: exported == :exported
    }
  end

  # TODO: remove?
  def new32(name, mutability, exported, value)
      when is_atom(name) and
             mutability in ~w[readonly mutable]a and
             exported in ~w[internal exported]a and is_binary(value) do
    require Orb

    %__MODULE__{
      name: name,
      type: Orb.Constants.NulTerminatedString.Slice,
      initial_value: value,
      mutability: mutability,
      exported: exported == :exported
    }
  end

  defmacro register(type, name, mutability, exported, value) do
    #  when mutability in ~w{readonly mutable}a and
    #         exported in ~w[internal exported]a do
    quote bind_quoted: [
            type: type,
            name: name,
            mutability: mutability,
            exported: exported,
            value: value
          ] do
      @wasm_globals Orb.Global.new(type, name, mutability, exported, value)
    end
  end

  defmacro register32(mutability, exported, list) do
    #  when mutability in ~w{readonly mutable}a and
    #         exported in ~w[internal exported]a do
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

  def expand!(
        %Orb.Global{type: Orb.Constants.NulTerminatedString.Slice, initial_value: ""} = global
      ) do
    %Orb.Global{
      global
      | initial_value:
          Orb.Constants.NulTerminatedString.empty()
          |> Orb.Constants.NulTerminatedString.to_slice(),
        comment: "empty string constant"
    }
  end

  def expand!(
        %Orb.Global{type: Orb.Constants.NulTerminatedString.Slice, initial_value: string} = global
      ) do
    %Orb.Global{
      global
      | initial_value:
          string
          |> Orb.Constants.expand_if_needed()
          |> Orb.Constants.NulTerminatedString.to_slice(),
        comment: "string constant"
    }
  end

  def expand!(%Orb.Global{} = global), do: global

  defimpl Orb.ToWat do
    import Orb.ToWat.Helpers

    def to_wat(
          %Orb.Global{
            name: name,
            type: type,
            initial_value: initial_value,
            mutability: mutability,
            exported: exported,
            comment: comment
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
        if comment do
          ["(; ", comment, " ;) "]
        end || [],
        case mutability do
          :readonly -> do_type(type)
          :mutable -> ["(mut ", do_type(type), ?)]
        end,
        " ",
        cond do
          is_number(initial_value) ->
            ["(", do_type(type), ".const ", to_string(initial_value), ")"]

          true ->
            Orb.ToWat.to_wat(initial_value, "")
        end,
        ")\n"
      ]
    end
  end

  defmodule Declare do
    @moduledoc false

    defmodule DeclareDSL do
      @moduledoc false
      import Kernel, except: [@: 1]

      defmacro register_global(name, value) do
        quote do
          with do
            require Orb.Global

            # Ignore unused module attribute
            _ = Module.get_attribute(__MODULE__, unquote(name))

            preferred_type =
              Module.get_last_attribute(__MODULE__, :wasm_global_preferred_type, nil)

            Orb.Global.register(
              preferred_type,
              unquote(name),
              Module.get_last_attribute(__MODULE__, :wasm_global_mutability),
              Module.get_last_attribute(__MODULE__, :wasm_global_exported),
              unquote(value)
            )
          end
        end
      end

      defmacro @{name, _meta, [arg]} do
        quote do
          unquote(__MODULE__).register_global(unquote(name), unquote(arg))
        end
      end
    end

    defmacro __import_dsl(mutability, exported) do
      quote do
        import DeclareDSL
        Module.put_attribute(__MODULE__, :wasm_global_mutability, unquote(mutability))
        Module.put_attribute(__MODULE__, :wasm_global_exported, unquote(exported))
        # @wasm_global_mutability unquote(mutability)
        # @wasm_global_exported unquote(exported)
      end
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

    defmacro @{name, _meta, _args} do
      quote do
        Orb.Instruction.Global.Get.new(Orb.__lookup_global_type!(unquote(name)), unquote(name))
      end
    end
  end
end
