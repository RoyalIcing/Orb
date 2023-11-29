defmodule Orb.Func do
  @moduledoc false
  alias Orb.InstructionSequence

  defstruct name: nil,
            exported_names: [],
            params: [],
            result: nil,
            local_types: [],
            body: %InstructionSequence{},
            source_module: nil,
            table_elem_indices: []

  def __add_table_elem(f = %__MODULE__{}, elem_index) do
    update_in(f.table_elem_indices, fn refs -> [elem_index | refs] end)
  end

  def expand(%__MODULE__{} = func) do
    update_in(func.body, &Orb.InstructionSequence.expand/1)
  end

  defimpl Orb.ToWat do
    alias Orb.ToWat.Instructions
    import Orb.ToWat.Helpers

    def to_wat(
          %Orb.Func{
            name: name,
            exported_names: exported_names,
            params: params,
            result: result,
            local_types: local_types,
            body: body,
            table_elem_indices: table_elem_indices
          },
          indent
        ) do
      [
        [
          indent,
          [
            ~s{(func $},
            to_string(name),
            for exported_name <- Enum.reverse(exported_names) do
              [~s{ (export "}, to_string(exported_name), ~s{")}]
            end
          ],
          Enum.map(
            for(param <- params, do: Orb.ToWat.to_wat(param, "")) ++
              if(result, do: [["(result ", do_type(result), ")"]], else: []),
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
            do_type(type),
            ")\n"
          ]
        end,
        Orb.ToWat.to_wat(body, "  " <> indent),
        [indent, ")\n"],
        for elem_index <- table_elem_indices do
          [indent, "(elem (i32.const ", to_string(elem_index), ") $", to_string(name), ")\n"]
        end
      ]
    end
  end

  defmodule Param do
    @moduledoc false

    defstruct [:name, :type]

    defimpl Orb.ToWat do
      import Orb.ToWat.Helpers

      def to_wat(%Param{name: nil, type: type}, indent) do
        [
          indent,
          "(param ",
          do_type(type),
          ?)
        ]
      end

      def to_wat(%Param{name: name, type: type}, indent) do
        [
          indent,
          "(param $",
          to_string(name),
          " ",
          do_type(type),
          ?)
        ]
      end
    end
  end

  defmodule Type do
    @moduledoc false

    defstruct [:name, :params, :result]

    def new(name, params, result) do
      # params = [:i32]
      %__MODULE__{
        name: name,
        params: params,
        result: result
      }
    end

    @doc false
    def params_from_call_args(args, env, line) do
      case args do
        [args] when is_list(args) ->
          for {name, type} <- args do
            %Orb.Func.Param{name: name, type: Macro.expand_literals(type, env)}
          end

        [] ->
          []

        [_ | _] ->
          raise CompileError,
            line: line,
            file: env.file,
            description:
              "Cannot define function with multiple arguments, use keyword list instead."
      end
    end

    defimpl Orb.ToWat do
      import Orb.ToWat.Helpers

      def to_wat(%Type{name: name, params: params, result: result}, indent) do
        [
          indent,
          "(func",
          case name do
            nil -> []
            name -> [" $", to_string(name)]
          end,
          case params do
            nil ->
              []

            params when is_list(params) ->
              for param <- params, do: [" ", Orb.ToWat.to_wat(param, "")]

            params ->
              [
                " ",
                Orb.ToWat.to_wat(%Param{name: nil, type: params}, "")
              ]
          end,
          case result do
            nil ->
              []

            result ->
              [
                " (result ",
                do_type(result),
                ")"
              ]
          end,
          ?)
        ]
      end
    end
  end
end
