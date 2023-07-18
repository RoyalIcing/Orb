defmodule Orb.Func do
  @moduledoc false

  defstruct [:name, :params, :result, :local_types, :body, :exported?, :source_module]

  defimpl Orb.ToWat do
    alias Orb.ToWat.Instructions

    def to_wat(
          %Orb.Func{
            name: name,
            params: params,
            result: result,
            local_types: local_types,
            body: body,
            exported?: exported?
          },
          indent
        ) do
      [
        [
          indent,
          case exported? do
            false -> ~s[(func $#{name}]
            true -> ~s[(func $#{name} (export "#{name}")]
          end,
          Enum.map(
            for(param <- params, do: Instructions.do_wat(param)) ++
              if(result, do: [Instructions.do_wat(result)], else: []),
            fn s -> [" ", s] end
          ),
          "\n"
        ],
        for {id, type} <- local_types do
          [
            "  ",
            indent,
            "(local $",
            to_string(id),
            " ",
            Instructions.do_type(type),
            ")\n"
          ]
        end,
        Instructions.do_wat(body, "  " <> indent),
        "\n",
        [indent, ")"]
      ]
    end
  end

  defmodule Param do
    @moduledoc false

    defstruct [:name, :type]

    defimpl Orb.ToWat do
      alias Orb.ToWat.Instructions

      def to_wat(%Param{name: nil, type: type}, indent) do
        [
          indent,
          "(param ",
          Instructions.do_type(type),
          ?)
        ]
      end

      def to_wat(%Param{name: name, type: type}, indent) do
        [
          indent,
          "(param $",
          to_string(name),
          " ",
          Instructions.do_type(type),
          ?)
        ]
      end
    end
  end

  defmodule Type do
    @moduledoc false

    defstruct [:name, :param_types, :result_type]

    # TODO: should this be its own struct type?
    def imported_func(name, params, result_type) do
      # param_types = [:i32]
      %__MODULE__{
        name: name,
        param_types: params,
        result_type: result_type
      }
    end

    defimpl Orb.ToWat do
      alias Orb.ToWat.Instructions

      def to_wat(%Type{name: name, param_types: param_types, result_type: result_type}, indent) do
        [
          indent,
          "(func $",
          to_string(name),
          case param_types do
            nil ->
              []

            param_types ->
              [
                " ",
                Orb.ToWat.to_wat(%Param{name: nil, type: param_types}, "")
              ]
          end,
          case result_type do
            nil ->
              []

            result_type ->
              [
                " ",
                Instructions.do_wat({:result, result_type})
              ]
          end,
          ?)
        ]
      end
    end
  end
end
