defmodule Orb.Instruction do
  @moduledoc "Generic struct for many type of WebAssembly instructions"
  defstruct [:pop_type, :push_type, :operation, :operands]

  require Orb.Ops, as: Ops
  alias Orb.Constants

  @doc """
  Macro to quote a sequence of Orb instructions as a snippet.
  """
  defmacro sequence(do: block) do
    block_items =
      case block do
        {:__block__, _meta, items} -> items
        single -> [single]
      end

    quote do
      # We want our imports to not pollute. so we use `with` as a finite scope.
      with do
        import Kernel,
          except: [
            if: 2,
            unless: 2,
            @: 1,
            +: 2,
            -: 2,
            *: 2,
            /: 2,
            <: 2,
            >: 2,
            <=: 2,
            >=: 2,
            ===: 2,
            !==: 2,
            not: 1,
            or: 2
          ]

        import Orb.DSL
        import Orb.IfElse.DSL
        import Orb.Numeric.DSL
        import Orb.Global.DSL
        require Orb.Control, as: Control

        unquote(Orb.DSL.do_snippet([], block_items))
        |> Orb.InstructionSequence.new()
      end
    end
  end

  # def new(type, operation, operands \\ [])
  def new(type, operation), do: new(type, operation, [])

  def new(type, operation, operands)

  def new(Elixir.Integer, _, _) do
    raise "Can’t create an instruction for Elixir.Integer, need concrete type like Orb.I64."
  end

  def new(Elixir.Float, _, _) do
    raise "Can’t create an instruction for Elixir.Float, need concrete type like Orb.F64."
  end

  def new(type, {:call, param_types, name} = operation, params),
    do: %__MODULE__{
      push_type: type,
      operation: operation,
      operands: type_check_call!(param_types, name, params)
    }

  def new(type, operation, operands) do
    %__MODULE__{
      push_type: type,
      operation: operation,
      operands: type_check_operands!(type, operation, operands)
    }
  end

  def wrap_constant!(type, value)

  def wrap_constant!(Elixir.Integer, value) when is_number(value),
    do: raise("Need concrete type not Elixir.Integer for constants.")

  def wrap_constant!(Elixir.Float, value) when is_number(value),
    do: raise("Need concrete type not Elixir.Float for constants.")

  # TODO: replace with Orb.Instruction.Const
  def wrap_constant!(type, value) when is_number(value),
    do: %__MODULE__{
      push_type: type,
      operation: :const,
      operands: [value]
    }

  def wrap_constant!(type, %{push_type: type} = value), do: value

  # TODO: remove
  def wrap_constant!(type_a, %{push_type: type_b} = value) do
    case Ops.types_compatible?(type_a, type_b) do
      true ->
        value

      false ->
        raise Orb.TypeCheckError,
          expected_type: type_a,
          received_type: type_b,
          instruction_identifier: "#{type_a}.const"
    end
  end

  def i32(operation), do: new(:i32, operation)
  def i32(operation, a) when is_list(a), do: new(:i32, operation, a)
  def i32(operation, a), do: new(:i32, operation, [a])

  def i32(operation, a, b) when operation in ~w(eq ne lt_u lt_s gt_u gt_s le_u le_s ge_u ge_s)a,
    do: Orb.Instruction.Relative.new(:i32, operation, a, b)

  def i32(operation, a, b), do: new(:i32, operation, [a, b])

  def i64(operation), do: new(:i64, operation)
  def i64(operation, a) when is_list(a), do: new(:i64, operation, a)
  def i64(operation, a), do: new(:i64, operation, [a])

  def i64(operation, a, b) when operation in ~w(eq ne lt_u lt_s gt_u gt_s le_u le_s ge_u ge_s)a,
    do: Orb.Instruction.Relative.new(:i64, operation, a, b)

  def i64(operation, a, b), do: new(:i64, operation, [a, b])

  def f32(operation), do: new(:f32, operation)
  def f32(operation, a) when is_list(a), do: new(:f32, operation, a)
  def f32(operation, a), do: new(:f32, operation, [a])

  def f32(operation, a, b) when operation in ~w(eq ne lt gt le ge)a,
    do: Orb.Instruction.Relative.new(:f32, operation, a, b)

  def f32(operation, a, b), do: new(:f32, operation, [a, b])

  def f64(operation), do: new(:f64, operation)
  def f64(operation, a) when is_list(a), do: new(:f64, operation, a)
  def f64(operation, a), do: new(:f64, operation, [a])

  def f64(operation, a, b) when operation in ~w(eq ne lt gt le ge)a,
    do: Orb.Instruction.Relative.new(:f64, operation, a, b)

  def f64(operation, a, b), do: new(:f64, operation, [a, b])

  # TODO: remove call()
  def call(f), do: new(:unknown_effect, {:call, f})
  def call(f, args) when is_list(args), do: new(:unknown_effect, {:call, f}, args)

  def typed_call(result_type, param_types, f, args) when is_list(args),
    do: new(result_type, {:call, param_types, f}, args)

  # def typed_call(output_type, f, args) when is_list(args), do: new(output_type, {:call, f}, args)

  def local_get(type, local_name), do: new(type, {:local_get, local_name})
  def local_tee(type, local_name, value), do: new(type, {:local_tee, local_name}, [value])

  def local_set(type, local_name) do
    %__MODULE__{
      pop_type: type,
      operation: {:local_set, local_name, type},
      operands: []
    }
  end

  # When passing Orb.Stack.Pop
  def local_set(type, local_name, %{pop_type: type}) when not is_nil(type) do
    %__MODULE__{
      pop_type: type,
      operation: {:local_set, local_name, type},
      operands: []
    }
  end

  def local_set(type, local_name, value) do
    new(nil, {:local_set, local_name, type}, [
      Orb.Instruction.Const.wrap(type, value, "local.set $#{local_name}")
    ])
  end

  # TODO: remove
  def global_set(type, global_name, value) do
    new(nil, {:global_set, global_name, type}, [value])
  end

  @types_to_stores %{
    i32: %{store: true, store8: true, store16: true},
    i64: %{store: true, store8: true, store16: true, store32: true},
    f32: %{store: true},
    f64: %{store: true}
  }

  def memory_store(type, store, opts)
      when is_map_key(@types_to_stores, type) and
             is_map_key(:erlang.map_get(type, @types_to_stores), store) do
    offset = Keyword.fetch!(opts, :offset)
    value = Keyword.fetch!(opts, :value)
    align = Keyword.get(opts, :align)

    new(nil, {type, store, align}, [offset, value])
  end

  def memory_size(), do: new(:i32, {:memory, :size}, [])
  # This is really a memory_effect but we don’t have a way to have
  # both a function returning i32 and performing a memory effect.
  # Which we should because any function can do both!
  # TODO: add effects map. See InstructionSequence for a sketch.
  def memory_grow(value), do: new(:i32, {:memory, :grow}, [value])

  def memory_copy(dest_index, src_index, length) do
    new(nil, {:memory, :copy}, [
      Orb.Instruction.Const.wrap(:i32, dest_index),
      Orb.Instruction.Const.wrap(:i32, src_index),
      Orb.Instruction.Const.wrap(:i32, length)
    ])
  end

  defp type_check_call!(param_types, name, params) do
    params
    |> Enum.with_index(fn param, index ->
      param = Constants.expand_if_needed(param)

      expected_type = Enum.at(param_types, index)

      received_type =
        cond do
          is_integer(param) -> Elixir.Integer
          # FIXME: Change to Elixir.Float
          is_float(param) -> :f32
          %{push_type: type} = param -> type
        end

      types_must_match!(expected_type, received_type, "call #{name} param #{index}")

      wrap_constant!(expected_type, param)
    end)
  end

  defp type_check_operands!(type, operation, operands) do
    operands
    |> Enum.with_index(fn operand, index ->
      operand = Constants.expand_if_needed(operand)

      case type_check_operand!(type, operation, operand, index) do
        # TODO: might be able to remove this?
        nil ->
          operand

        value ->
          value
      end
    end)
  end

  defp type_check_operand!(type, op, number, param_index)
       when type in [:i64, :i32, :f64, :f32] and is_atom(op) and is_number(number) do
    expected_type = Ops.param_type!(type, op, param_index)

    received_type =
      cond do
        # is_integer(number) -> :i32
        is_integer(number) -> Elixir.Integer
        # TODO: F64
        is_float(number) -> Elixir.Float
      end

    types_must_match!(expected_type, received_type, "#{type}.#{op}")

    case expected_type do
      Elixir.Integer ->
        number

      Elixir.Float ->
        number

      expected_type ->
        wrap_constant!(expected_type, number)
    end
  end

  defp type_check_operand!(:i32, op, %{push_type: received_type} = operand, param_index)
       when is_atom(op) do
    expected_type = Ops.i32_param_type!(op, param_index)

    types_must_match!(expected_type, received_type, "i32.#{op}")

    wrap_constant!(expected_type, operand)
  end

  # TODO: can this be removed? I believe it is handled by clause above.
  defp type_check_operand!(:i32, op, operand, param_index) when is_atom(op) do
    expected_type = Ops.i32_param_type!(op, param_index)

    wrap_constant!(expected_type, operand)
  end

  defp type_check_operand!(:i64, op, %{push_type: received_type} = operand, param_index)
       when is_atom(op) do
    expected_type = Ops.i64_param_type!(op, param_index)

    types_must_match!(expected_type, received_type, "i64.#{op}")

    wrap_constant!(expected_type, operand)
  end

  # TODO: can this be removed?
  defp type_check_operand!(:i64, op, operand, param_index) when is_atom(op) do
    expected_type = Ops.i64_param_type!(op, param_index)

    wrap_constant!(expected_type, operand)
  end

  defp type_check_operand!(
         nil,
         {:local_set, local_name, expected_type},
         operand,
         0
       ) do
    received_type = get_operand_type(operand)

    types_must_match!(expected_type, received_type, "local.set $#{local_name}")

    operand
  end

  # TODO: remove
  defp type_check_operand!(
         nil,
         {:global_set, global_name, expected_type},
         operand,
         0
       ) do
    received_type = get_operand_type(operand)

    types_must_match!(expected_type, received_type, "global.set $#{global_name}")

    operand
  end

  defp type_check_operand!(
         nil,
         {:i32, :store, _},
         operand,
         1
       ) do
    received_type = get_operand_type(operand)

    types_must_match!(:i32, received_type, "i32.store")

    operand
  end

  defp type_check_operand!(_type, _operation, operand, _index) do
    operand
  end

  defp get_operand_type(%{push_type: received_type}), do: received_type
  defp get_operand_type(n) when is_integer(n), do: Elixir.Integer
  defp get_operand_type(n) when is_float(n), do: Elixir.Float

  defp types_must_match!(same, same, _instruction_identifier), do: nil

  defp types_must_match!(expected_type, received_type, instruction_identifier) do
    case received_type do
      :unknown ->
        # Ignore
        nil

      type ->
        Ops.types_compatible?(type, expected_type) or
          raise Orb.TypeCheckError,
            expected_type: expected_type,
            received_type: type,
            instruction_identifier: instruction_identifier

        # nil
    end
  end

  defimpl Orb.ToWat do
    alias Orb.ToWat.Instructions

    defguardp is_likely_simple(value)
              when is_struct(value, Orb.Instruction) or
                     is_struct(value, Orb.Instruction.Const) or
                     is_struct(value, Orb.Instruction.Global.Get) or
                     is_struct(value, Orb.VariableReference) or
                     is_struct(value, Orb.VariableReference.Global) or
                     is_struct(value, Orb.VariableReference.Local)

    # TODO: remove
    def to_wat(
          %Orb.Instruction{
            operation: {:call, _param_types, f},
            operands: operands
          },
          indent
        ) do
      [
        indent,
        "(call $",
        to_string(f),
        for(operand <- operands, do: [" ", Instructions.do_wat(operand)]),
        ")"
      ]
    end

    # TODO: remove
    def to_wat(
          %Orb.Instruction{
            operation: {:call, f},
            operands: operands
          },
          indent
        ) do
      [
        indent,
        "(call $",
        to_string(f),
        for(operand <- operands, do: [" ", Instructions.do_wat(operand)]),
        ")"
      ]
    end

    def to_wat(
          %Orb.Instruction{
            operation: {:local_get, local_name},
            operands: []
          },
          indent
        ) do
      [indent, "(local.get $", to_string(local_name), ")"]
    end

    def to_wat(
          %Orb.Instruction{
            operation: {:local_tee, local_name},
            operands: operands
          },
          indent
        ) do
      [
        for(operand <- operands, do: [indent, Instructions.do_wat(operand), "\n"]),
        indent,
        "(local.tee $",
        to_string(local_name),
        ")"
      ]
    end

    def to_wat(
          %Orb.Instruction{
            operation: {:local_set, local_name, _},
            operands: operands
          },
          indent
        ) do
      [
        for(operand <- operands, do: [Instructions.do_wat(operand, indent), "\n"]),
        indent,
        "(local.set $",
        to_string(local_name),
        ")"
      ]
    end

    # TODO: remove
    def to_wat(
          %Orb.Instruction{
            operation: {:global_set, global_name, _},
            operands: operands
          },
          indent
        ) do
      [
        for(operand <- operands, do: [indent, Instructions.do_wat(operand), "\n"]),
        indent,
        "(global.set $",
        to_string(global_name),
        ")"
      ]
    end

    def to_wat(
          %Orb.Instruction{
            push_type: nil,
            operation: {type, store, align},
            operands: operands
          },
          indent
        ) do
      [
        indent,
        "(",
        to_string(type),
        ".",
        to_string(store),
        case align do
          nil -> []
          align -> [" align=", to_string(align)]
        end,
        for(operand <- operands, do: [" ", Instructions.do_wat(operand)]),
        ")"
      ]
    end

    def to_wat(
          %Orb.Instruction{
            push_type: :i32,
            operation: {:memory, memory_op},
            operands: operands
          },
          indent
        ) do
      [
        indent,
        "(memory.",
        to_string(memory_op),
        for(operand <- operands, do: [" ", Instructions.do_wat(operand)]),
        ")"
      ]
    end

    def to_wat(
          %Orb.Instruction{
            push_type: nil,
            operation: {:memory, memory_op},
            operands: operands
          },
          indent
        ) do
      [
        indent,
        "(memory.",
        to_string(memory_op),
        for(operand <- operands, do: [" ", Instructions.do_wat(operand)]),
        ")"
      ]
    end

    def to_wat(
          %Orb.Instruction{
            push_type: type,
            operation: :const,
            operands: [number]
          },
          indent
        ) do
      [
        indent,
        "(",
        to_string(Ops.to_primitive_type(type)),
        ".const ",
        to_string(number),
        ")"
      ]
    end

    def to_wat(
          %Orb.Instruction{
            push_type: type,
            operation: operation,
            operands: operands
          },
          indent
        )
        when operation in [:and] do
      [
        indent,
        "(",
        to_string(type),
        ".",
        to_string(operation),
        for(
          operand <- operands,
          do: ["\n", Instructions.do_wat(operand, "  " <> indent)]
        ),
        ?\n,
        indent,
        ")"
      ]
    end

    def to_wat(
          %Orb.Instruction{
            push_type: type,
            operation: operation,
            operands: [a]
          },
          indent
        )
        when is_likely_simple(a) do
      [
        indent,
        "(",
        to_string(type),
        ".",
        to_string(operation),
        " ",
        Instructions.do_wat(a),
        ")"
      ]
    end

    def to_wat(
          %Orb.Instruction{
            push_type: type,
            operation: operation,
            operands: [a, b]
          },
          indent
        )
        when is_likely_simple(a) and is_likely_simple(b) do
      [
        indent,
        "(",
        to_string(type),
        ".",
        to_string(operation),
        " ",
        Instructions.do_wat(a),
        " ",
        Instructions.do_wat(b),
        ")"
      ]
    end

    def to_wat(
          %Orb.Instruction{
            push_type: type,
            operation: operation,
            operands: operands
          },
          indent
        ) do
      [
        indent,
        "(",
        to_string(type),
        ".",
        to_string(operation),
        for(operand <- operands, do: ["\n", Instructions.do_wat(operand, "  " <> indent)]),
        ?\n,
        indent,
        ")"
      ]
    end
  end

  defimpl Orb.ToWasm do
    import Orb.Leb

    defp type_const(:i32), do: 0x41
    defp type_const(:i64), do: 0x42
    defp type_const(:f32), do: 0x43
    defp type_const(:f64), do: 0x44

    # TODO: remove, replace with Orb.Instruction.Const
    def to_wasm(
          %Orb.Instruction{
            push_type: type,
            operation: :const,
            operands: [number]
          },
          _
        ) do
      [type_const(type), leb128_s(number)]
    end

    def to_wasm(
          %Orb.Instruction{
            push_type: :i32,
            operation: operation,
            operands: operands
          },
          context
        ) do
      [
        for(operand <- operands, do: Orb.ToWasm.to_wasm(operand, context)),
        i32_operation(operation)
      ]
    end

    def to_wasm(
          %Orb.Instruction{
            push_type: :i64,
            operation: operation,
            operands: operands
          },
          context
        ) do
      [
        for(operand <- operands, do: Orb.ToWasm.to_wasm(operand, context)),
        i64_operation(operation)
      ]
    end

    def to_wasm(
          %Orb.Instruction{
            push_type: nil,
            operation: {:local_set, identifier, _},
            operands: operands
          },
          context
        ) do
      [
        for(operand <- operands, do: Orb.ToWasm.to_wasm(operand, context)),
        0x21,
        leb128_u(Orb.ToWasm.Context.fetch_local_index!(context, identifier))
      ]
    end

    def to_wasm(
          %Orb.Instruction{
            push_type: :i32,
            operation: {:memory, :size},
            operands: []
          },
          _context
        ) do
      [0x3F]
    end

    def to_wasm(
          %Orb.Instruction{
            push_type: :i32,
            operation: {:memory, :grow},
            operands: [delta]
          },
          context
        ) do
      [
        Orb.ToWasm.to_wasm(delta, context),
        0x40
      ]
    end

    def to_wasm(
          %Orb.Instruction{
            push_type: nil,
            operation: {:memory, :copy},
            operands: [dest_index, src_index, length]
          },
          context
        ) do
      [
        Orb.ToWasm.to_wasm(dest_index, context),
        Orb.ToWasm.to_wasm(src_index, context),
        Orb.ToWasm.to_wasm(length, context),
        # memory.copy opcode + destination memory index + source memory index
        0xFC,
        0x0A,
        0x00,
        0x00
      ]
    end

    defp i32_operation(:eqz), do: 0x45
    defp i32_operation(:add), do: 0x6A
    defp i32_operation(:sub), do: 0x6B
    defp i32_operation(:mul), do: 0x6C
    defp i32_operation(:div_s), do: 0x6D
    defp i32_operation(:div_u), do: 0x6E
    defp i32_operation(:rem_s), do: 0x6F
    defp i32_operation(:rem_u), do: 0x70
    defp i32_operation(:and), do: 0x71
    defp i32_operation(:or), do: 0x72
    defp i32_operation(:xor), do: 0x73
    defp i32_operation(:shl), do: 0x74
    defp i32_operation(:shr_s), do: 0x75
    defp i32_operation(:shr_u), do: 0x76
    defp i32_operation(:rotl), do: 0x77
    defp i32_operation(:rotr), do: 0x78

    defp i64_operation(:eqz), do: 0x50
    defp i64_operation(:add), do: 0x7C
    defp i64_operation(:sub), do: 0x7D
    defp i64_operation(:mul), do: 0x7E
    defp i64_operation(:div_s), do: 0x7F
    defp i64_operation(:div_u), do: 0x80
    defp i64_operation(:rem_s), do: 0x81
    defp i64_operation(:rem_u), do: 0x82
    defp i64_operation(:and), do: 0x83
    defp i64_operation(:or), do: 0x84
    defp i64_operation(:xor), do: 0x85
    defp i64_operation(:shl), do: 0x86
    defp i64_operation(:shr_s), do: 0x87
    defp i64_operation(:shr_u), do: 0x88
    defp i64_operation(:rotl), do: 0x89
    defp i64_operation(:rotr), do: 0x8A

    # def to_wasm(
    #       %Orb.Instruction{
    #         operation: {:local_get, local_name},
    #         operands: []
    #       },
    #       _
    #     ) do
    #   [0x20, Orb.ToWasm.Context.local_index(local_name)]
    # end

    # def to_wasm(
    #       %Orb.Instruction{
    #         operation: {:local_set, local_name, _},
    #         operands: []
    #       },
    #       _
    #     ) do
    #   [0x21, Orb.ToWasm.Context.local_index(local_name)]
    # end

    # def to_wasm(
    #       %Orb.Instruction{
    #         operation: {:local_tee, local_name},
    #         operands: []
    #       },
    #       _
    #     ) do
    #   [0x22, Orb.ToWasm.Context.local_index(local_name)]
    # end
  end
end
