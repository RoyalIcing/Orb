defmodule Orb.Func do
  @moduledoc false

  defstruct name: nil,
            params: [],
            result: nil,
            local_types: [],
            body: [],
            exported?: false,
            source_module: nil,
            table_elem_indices: []

  def __add_table_elem(f = %__MODULE__{}, elem_index) do
    update_in(f.table_elem_indices, fn refs -> [elem_index | refs] end)
  end

  defimpl Orb.ToWat do
    alias Orb.ToWat.Instructions

    def to_wat(
          %Orb.Func{
            name: name,
            params: params,
            result: result,
            local_types: local_types,
            body: body,
            exported?: exported?,
            table_elem_indices: table_elem_indices,
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
        Enum.map(body, &[Instructions.do_wat(&1, "  " <> indent), "\n"]),
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

    defstruct [:name, :params, :result]

    # TODO: should this be its own struct type?
    def imported_func(name, params, result) do
      # params = [:i32]
      %__MODULE__{
        name: name,
        params: params,
        result: result
      }
    end

    defimpl Orb.ToWat do
      alias Orb.ToWat.Instructions

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
                " ",
                Instructions.do_wat({:result, result})
              ]
          end,
          ?)
        ]
      end
    end
  end
end
