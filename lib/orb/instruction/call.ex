defmodule Orb.Instruction.Call do
  @moduledoc false
  defstruct [:push_type, :func_identifier, :args]

  defguardp is_type_compatible(type)
            when is_atom(type) or
                   (is_tuple(type) and tuple_size(type) >= 2)

  def new(result_type, param_types, f, args) when is_list(param_types) do
    param_types =
      case param_types do
        [] -> nil
        [single] -> single
        multiple -> List.to_tuple(multiple)
      end

    new(result_type, param_types, f, args)
  end

  def new(result_type, param_types, func_identifier, args)
      when (is_nil(result_type) or is_type_compatible(result_type)) and
             (is_nil(param_types) or is_type_compatible(param_types)) and
             is_list(args) do
    args =
      case {param_types, args} do
        {nil, []} ->
          []

        {type, [value]} when is_atom(type) ->
          [Orb.Instruction.Const.wrap(type, value)]

        {types, values} when tuple_size(types) === length(values) ->
          for {type, value} <- Enum.zip(Tuple.to_list(types), values) do
            Orb.Instruction.Const.wrap(type, value)
          end
      end

    %__MODULE__{
      push_type: result_type,
      func_identifier: func_identifier,
      args: args
    }
  end

  defimpl Orb.ToWat do
    def to_wat(%Orb.Instruction.Call{func_identifier: func_identifier, args: args}, indent) do
      [
        indent,
        "(call $",
        to_string(func_identifier),
        for(arg <- args, do: [" ", Orb.ToWat.to_wat(arg, "")]),
        ")"
      ]
    end
  end

  defimpl Orb.ToWasm do
    def to_wasm(
          %Orb.Instruction.Call{
            func_identifier: func_identifier,
            args: args
          },
          context
        ) do
      function_index = Orb.ToWasm.Context.fetch_func_index!(context, func_identifier)

      [
        for arg <- args do
          Orb.ToWasm.to_wasm(arg, context)
        end,
        0x10,
        function_index
      ]
    end
  end
end
