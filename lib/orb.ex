defmodule Orb do
  @moduledoc """
  Write WebAssembly modules with Elixir.

  WebAssembly is a low-level language. You work with integers and floats, can perform operations on them like adding or multiplication, and then read and write those values to a block of memory. There’s no concept of a “string” or an “array”, let alone a “hash map” or “HTTP request”.

  That’s where a library like Orb can help out. It takes full advantage of Elixir’s language features by becoming a compiler for WebAssembly. You can define WebAssembly modules in Elixir for “string” or “hash map”, and compose them together into a final module.

  That WebAssembly module can then run in every major application environment: browsers, servers, the edge, and mobile devices like phones, tablets & laptops. This story is still being developed, but I believe like other web standards like JSON, HTML, and HTTP, that WebAssembly will become a first-class citizen on any platform. It’s Turing-complete, designed to be backwards compatible, fast, and works almost everywhere.

  ## Example

  Let’s create a module that calculates the average of a set of numbers.

  WebAssembly modules can have state. Here will have two pieces of state: a total `count` and a running `tally`. These are stored as **globals**. (If you are familiar with object-oriented programming, you can think of them as instance variables).

  Our module will export two functions: `insert` and `calculate_mean`. These two functions will work with the `count` and `tally` globals.

  ```elixir
  defmodule CalculateMean do
    use Orb

    global do
      @count 0
      @tally 0
    end

    defw insert(element: I32) do
      @count = @count + 1
      @tally = @tally + element
    end

    defw calculate_mean(), I32 do
      @tally / @count
    end
  end
  ```

  One thing you’ll notice is that we must specify the type of function parameters and return values. Our `insert` function accepts a 32-bit integer, denoted using `I32`. It returns no value, while `calculate_mean` is annotated to return a 32-bit integer.

  We get to write math with the intuitive `+` and `/` operators. Let’s see the same module without the magic: no math operators and without `@` conveniences for working with globals:

  ```elixir
  defmodule CalculateMean do
    use Orb

    I32.global(count: 0, tally: 0)

    defw insert(element: I32) do
      Orb.Instruction.Global.Set.new(Orb.I32, :count, I32.add(Orb.Instruction.Global.Get.new(Orb.I32, :count), 1))
      Orb.Instruction.Global.Set.new(Orb.I32, :tally, I32.add(Orb.Instruction.Global.Get.new(Orb.I32, :tally), element))
    end

    defw calculate_mean(), I32 do
      I32.div_s(Orb.Instruction.Global.Get.new(Orb.I32, :tally), Orb.Instruction.Global.Get.new(Orb.I32, :count))
    end
  end
  ```

  This is the exact same logic as before. In fact, this is what the first version expands to. Orb adds “sugar syntax” to make authoring WebAssembly nicer, to make it feel like writing Elixir or Ruby.

  ## Functions

  In Elixir you define functions publicly available outside the module with `def/1`, and functions private to the module with `defp/1`. Orb follows the same suffix convention with `defw/2` and `defwp/2`.

  Consumers of your WebAssembly module will only be able to call exported functions defined using `defw/2`. Making a function public in WebAssembly is known as “exporting”.

  ## Stack based

  While it looks like Elixir, there are some key differences between it and programs written in Orb. The first is that state is mutable. While immutability is one of the best features of Elixir, in WebAssembly variables are mutable because raw computer memory is mutable.

  The second key difference is that WebAssembly is stack based. Every function has an implicit stack of values that you can push and pop from. This paradigm allows WebAssembly runtimes to efficiently optimize for raw CPU registers whilst not being platform specific.

  In Elixir when you write:

  ```elixir
  def example() do
    1
    2
    3
  end
  ```

  The first two lines with `1` and `2` are inert — they have no effect — and the result from the function is the last line `3`.

  In WebAssembly / Orb when you write the same sort of thing:

  ```elixir
  defw example() do
    1
    2
    3
  end
  ```

  Then what’s happening is that we are pushing `1` onto the stack, then `2`, and then `3`. Now the stack has three items on it. Which will become our return value: a tuple of 3 integers. (Our function has no return type specified, so this will be an error if you attempted to compile the resulting module).

  So the correct return type from this function would be a tuple of three integers:

  ```elixir
  defw example(), {I32, I32, I32} do
    1
    2
    3
  end
  ```

  If you prefer, Orb allows you to be explicit with your stack pushes with `Orb.Stack.push/1`:

  ```elixir
  defw example(), {I32, I32, I32} do
    Orb.Stack.push(1)
    Orb.Stack.push(2)
    Orb.Stack.push(3)
  end
  ```

  You can use the stack to unlock novel patterns, but for the most part Orb avoids the need to interact with it. It’s just something to keep in mind if you are used to lines of code with simple values not having any side effects.

  ## Locals

  Locals are variables that live for the lifetime of a function. They must be specified upfront with their type alongside the function’s definition, and are initialized to zero.

  Here we have two locals: `under?` and `over?`, both 32-bit integers. We can set their value and then read them again at the bottom of the function.

  ```elixir
  defmodule WithinRange do
    use Orb

    defw validate(num: I32), I32, under?: I32, over?: I32 do
      under? = num < 1
      over? = num > 255

      not (under? or over?)
    end
  end
  ```

  ## Globals

  Globals are like locals, but live for the duration of the entire running module’s life. Their initial type and value are specified upfront.

  Globals by default are internal: nothing outside the module can see them. They can be exported to expose them to the outside world.

  ```elixir
  defmodule GlobalExample do
    use Orb

    global do # :mutable by default
      @some_internal_global 99
    end

    global :readonly do
      @some_internal_constant 99
    end

    global :export_readonly do
      @some_public_constant 1001
    end

    global :export_mutable do
      @some_public_variable 42
    end

    # You can define multiple globals at once:
    global do
      @magic_number_a 99
      @magic_number_b 12
      @magic_number_c -5
    end
  end
  ```

  You can read or write to a global within `defw` using the `@` prefix:

  ```elixir
  defmodule Counter do
    use Orb

    global do
      @counter 0
    end

    defw increment() do
      @counter = @counter + 1
    end
  end
  ```

  When you use `Orb.global/1` an Elixir module attribute with the same name and initial value is also defined for you:application

  ```elixir
  defmodule DeepThought do
    use Orb

    global do
      @meaning_of_life 42
    end

    def get_meaning_of_life_elixir() do
      @meaning_of_life
    end

    defw get_meaning_of_life_wasm(), I32 do
      @meaning_of_life
    end
  end
  ```

  ## Memory

  WebAssembly provides a buffer of memory when you need more than a handful global integers or floats. This is a contiguous array of random-access memory which you can freely read and write to.

  ### Pages

  WebAssembly Memory comes in 64 KiB segments called pages. You use some multiple of these 64 KiB (64 * 1024 = 65,536 bytes) pages.

  By default your module will have **no** memory, so you must specify how much memory you want upfront.

  Here’s an example with 16 pages (1 MiB) of memory:

  ```elixir
  defmodule Example do
    use Orb

    Memory.pages(16)
  end
  ```

  ### Reading & writing memory

  To read from memory, you can use the `Memory.load/2` function. This loads a value at the given memory address. Addresses are themselves 32-bit integers. This mean you can perform pointer arithmetic to calculate whatever address you need to access.

  However, this can prove unsafe as it’s easy to calculate the wrong address and corrupt your memory. For this reason, Orb provides higher level constructs for making working with memory pointers more pleasant, which are detailed later on.

  ```elixir
  defmodule Example do
    use Orb

    Memory.pages(1)

    defw get_int32(), I32 do
      Memory.load!(I32, 0x100)
    end

    defw set_int32(value: I32) do
      Memory.store!(I32, 0x100, value)
    end
  end
  ```

  ### Initializing memory with data

  You can populate the initial memory of your module using `Orb.Memory.initial_data!/2`. This accepts an memory offset and the string to write there.

  ```elixir
  defmodule MimeTypeDataExample do
    use Orb

    Memory.pages(1)

    Memory.initial_data!(0x100, "text/html")
    Memory.initial_data!(0x200, \"""
      <!doctype html>
      <meta charset=utf-8>
      <h1>Hello world</h1>
      \""")

    defw get_mime_type(), I32 do
      0x100
    end

    defw get_body(), I32 do
      0x200
    end
  end
  ```

  Having to manually allocate and remember each memory offset is a pain, so Orb provides conveniences which are detailed in the next section.

  ## Strings constants

  You can use constant strings directly. These will be extracted as initial data definitions at the start of the WebAssembly module, and their memory offsets substituted in their place.

  Each string is packed together for maximum efficiency of memory space. Strings are deduplicated, so you can use the same string constant multiple times and a single allocation will be made.

  String constants in Orb are nul-terminated.

  ```elixir
  defmodule MimeTypeStringExample do
    use Orb

    Memory.pages(1)

    defw get_mime_type(), Str do
      "text/html"
    end

    defw get_body(), Str do
      \"\"\"
      <!doctype html>
      <meta charset=utf-8>
      <h1>Hello world</h1>
      \"\"\"
    end
  end
  ```

  ## Control flow

  Orb supports control flow with `if`, `block`, and `loop` statements.

  ### If statements

  If you want to run logic conditionally, use an `if` statement.

  ```elixir
  if @party_mode? do
    music_volume = 100
  end
  ```

  You can add an `else` clause:

  ```elixir
  if @party_mode? do
    music_volume = 100
  else
    music_volume = 30
  end
  ```

  If you want a ternary operator (e.g. to map from one value to another), you can use `if` when both clauses push the same type:

  ```elixir
  music_volume = if @party_mode? do
    i32(100)
  else
    i32(30)
  end
  ```

  These can be written on single line too:

  ```elixir
  music_volume = I32.if(@party_mode?, do: i32(100), else: i32(30))
  ```

  ### Loops

  Loops look like the familiar construct in other languages like JavaScript, with two key differences: each loop has a name, and loops by default stop unless you explicitly tell them to continue.

  ```elixir
  i = 0
  loop CountUp do
    i = i + 1

    CountUp.continue(if: i < 10)
  end
  ```

  Each loop is named, so if you nest them you can specify which particular one to continue.

  ```elixir
  total_weeks = 10
  weekday_count = 7
  week = 0
  weekday = 0
  loop Weeks do
    loop Weekdays do
      # Do something here with week and weekday

      weekday = weekday + 1
      Weekdays.continue(if: weekday < weekday_count)
    end

    week = week + 1
    Weeks.continue(if: week < total_weeks)
  end
  ```

  #### Iterators

  Iterators are an upcoming feature, currently part of SilverOrb that will hopefully become part of Orb itself.

  ### Blocks

  Blocks provide a structured way to skip code.

  ```elixir
  Control.block Validate do
    Validate.break(if: i < 0)

    # Do something with i
  end
  ```

  Blocks can have a type.

  ```elixir
  Control.block Double, I32 do
    if i < 0 do
      push(0)
      Double.break()
    end

    push(i * 2)
  end
  ```

  ## Calling other functions

  When you use `defw`, a corresponding Elixir function is defined for you using `def`.

  ```elixir
  defw magic_number(), I32 do
    42
  end
  ```

  ```elixir
  defw some_example(), n: I32 do
    n = magic_number()
  end
  ```

  ## Composing modules with `Orb.include/1`

  The WebAssembly functions from one module reused in another using `Orb.include/1`.

  Here’s an example of module A’s square function being included by module B:

  ```elixir
  defmodule A do
    use Orb

    defw square(n: I32), I32 do
      n * n
    end
  end

  defmodule B do
    use Orb

    # Copies all WebAssembly functions defined in A into this module.
    Orb.include(A)

    defw example(n: I32), I32 do
      # Now we can call functions on A.
      A.square(42)
    end
  end
  ```
  """

  alias Orb.CustomType
  alias Orb.Ops
  alias Orb.Memory
  require Ops

  defmacro __using__(_opts) do
    def_quoted =
      cond do
        __CALLER__.function === nil ->
          quote do
            # Public, used to register a func within a WebAssembly table via elem:
            # e.g. `(elem (i32.const 0) $my_func)`
            Module.register_attribute(__MODULE__, :table, accumulate: true)

            # IO.inspect(__ENV__.function)
            @before_compile unquote(__MODULE__).BeforeCompile

            @orb_experimental %{}

            def __wasm_body__(_), do: []
            defoverridable __wasm_body__: 1

            # TODO: rename these to orb_ prefix instead of wasm_ ?
            Module.put_attribute(
              __MODULE__,
              :wasm_name,
              __MODULE__ |> Module.split() |> List.last()
            )

            Module.register_attribute(__MODULE__, :wasm_func_prefix, accumulate: false)
            Module.register_attribute(__MODULE__, :wasm_memory, accumulate: true)
            Module.register_attribute(__MODULE__, :wasm_section_data, accumulate: true)

            Module.register_attribute(__MODULE__, :wasm_globals, accumulate: true)

            Module.register_attribute(__MODULE__, :wasm_types, accumulate: true)
            Module.register_attribute(__MODULE__, :wasm_table_allocations, accumulate: true)
            Module.register_attribute(__MODULE__, :wasm_table_elems, accumulate: true)
            Module.register_attribute(__MODULE__, :wasm_imports, accumulate: true)

            # Module.register_attribute(__MODULE__, :orb_experimental, accumulate: false)
          end

        true ->
          nil
      end

    quote do
      # TODO: don’t import types/1
      import Orb, only: [export: 1, global: 1, global: 2, global: 3, types: 1]
      import Orb.DSL.Defw
      alias Orb.{I32, I64, S32, U32, F32, F64, Memory, Table, Str}
      require Orb.{I32, I64, Stack, Table, Memory, Import}

      unquote(def_quoted)
    end
  end

  # TODO: extract?
  defmodule VariableReference do
    @moduledoc false

    defstruct [:global_or_local, :identifier, :push_type]

    alias Orb.Instruction

    def global(identifier, type) do
      %__MODULE__{global_or_local: :global, identifier: identifier, push_type: type}
    end

    def local(identifier, type) do
      %__MODULE__{global_or_local: :local, identifier: identifier, push_type: type}
    end

    def set(
          %__MODULE__{global_or_local: :local, identifier: identifier, push_type: type},
          new_value
        ) do
      Instruction.local_set(type, identifier, new_value)
    end

    def as_set(%__MODULE__{global_or_local: :local, identifier: identifier, push_type: type}) do
      Instruction.local_set(type, identifier)
    end

    @behaviour Access

    @impl Access
    # TODO: I think this should only live on custom types like UnsafePointer
    def fetch(
          %__MODULE__{global_or_local: :local, identifier: _identifier, push_type: :i32} = ref,
          at: offset
        ) do
      ast = Instruction.i32(:load, Instruction.i32(:add, ref, offset))
      {:ok, ast}
    end

    def fetch(
          %__MODULE__{global_or_local: :local, identifier: _identifier, push_type: mod} = ref,
          key
        ) do
      mod.fetch(ref, key)
    end

    @impl Access
    def get_and_update(_data, _key, _function) do
      raise UndefinedFunctionError, module: __MODULE__, function: :get_and_update, arity: 3
    end

    @impl Access
    def pop(_data, _key) do
      raise UndefinedFunctionError, module: __MODULE__, function: :pop, arity: 2
    end

    defimpl Orb.ToWat do
      def to_wat(%VariableReference{global_or_local: :global, identifier: identifier}, indent) do
        [indent, "(global.get $", to_string(identifier), ?)]
      end

      def to_wat(%VariableReference{global_or_local: :local, identifier: identifier}, indent) do
        [indent, "(local.get $", to_string(identifier), ?)]
      end
    end

    defimpl Orb.ToWasm do
      import Orb.Leb

      def to_wasm(
            %VariableReference{global_or_local: :local, identifier: identifier},
            context
          ) do
        [0x20, leb128_u(Orb.ToWasm.Context.fetch_local_index!(context, identifier))]
      end
    end
  end

  defmodule BeforeCompile do
    @moduledoc false

    defmacro __before_compile__(%{module: module}) do
      table_elems =
        module
        |> Module.get_attribute(:wasm_table_elems)
        |> List.flatten()

      quote do
        def __wasm_table_allocations__ do
          Orb.Table.Allocations.from_attribute(@wasm_table_allocations)
        end

        def __wasm_table_elems__(func_name) do
          case unquote(table_elems) |> List.keyfind(func_name, 0) do
            {_key, value} ->
              value

            nil ->
              []
          end
        end

        def __wasm_module__() do
          %{body: body, constants: constants, global_definitions: global_definitions} =
            Orb.Compiler.run(__MODULE__, @wasm_globals)

          memory = Memory.new(@wasm_memory, constants)

          Orb.ModuleDefinition.new(
            name: @wasm_name,
            types: @wasm_types |> Enum.reverse() |> List.flatten(),
            table_size: @wasm_table_allocations |> List.flatten() |> length(),
            imports: @wasm_imports |> Enum.reverse() |> List.flatten(),
            globals: global_definitions,
            memory: memory,
            constants: constants,
            body: body,
            data: @wasm_section_data |> Enum.reverse()
          )
        end

        @doc "Convert this module’s Orb definition to WebAssembly text (Wat) format."
        # def to_wat(), do: Orb.to_wat(__wasm_module__())
        def to_wat() do
          fn ->
            Orb.to_wat(__wasm_module__())
          end
          |> Task.async()
          |> Task.await()
        end
      end
    end
  end

  def __mode_pre(mode) do
    dsl =
      case mode do
        Orb.Numeric ->
          quote do
            import Orb.Numeric.DSL
            import Orb.Global.DSL
          end

        Orb.S32 ->
          quote do
            import Orb.I32.DSL
            import Orb.S32.DSL
            import Orb.Global.DSL
          end

        Orb.U32 ->
          quote do
            import Orb.I32.DSL
            import Orb.U32.DSL
            import Orb.Global.DSL
          end

        Orb.S64 ->
          quote do
            import Orb.I64.DSL
            import Orb.I64.Signed.DSL
            import Orb.Global.DSL
          end

        :no_magic ->
          []
      end

    quote do
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
      require Orb.Control, as: Control
      # TODO: should this be omitted if :no_magic is passed?
      import Orb.IfElse.DSL
      unquote(dsl)
    end
  end

  @doc """
  Declare a snippet of Orb AST for reuse. Enables DSL, with additions from `mode`.
  """
  # TODO: rename to Orb.instructions or Orb.quote ?
  defmacro snippet(mode \\ Orb.Numeric, locals \\ [], do: block) do
    mode = Macro.expand_literals(mode, __CALLER__)
    pre = __mode_pre(mode)

    block_items =
      case block do
        {:__block__, _meta, items} -> items
        single -> [single]
      end

    locals =
      for {key, type} <- locals, into: %{} do
        {key, Macro.expand_literals(type, __CALLER__)}
      end

    quote do
      # We want our imports to not pollute. so we use `with` as a finite scope.
      with do
        unquote(pre)

        unquote(Orb.DSL.do_snippet(locals, block_items))
        |> Orb.InstructionSequence.new()
      end
    end
  end

  # TODO: rename to something more specific and unlikely to clash with future Elixir.
  defmacro types(modules) do
    quote bind_quoted: [modules: modules] do
      @wasm_types (for mod <- modules do
                     %Orb.TypeDefinition{
                       name: mod.type_name(),
                       inner_type: CustomType.resolve!(mod)
                     }
                   end)
    end
  end

  defmacro functype(call, result) do
    env = __ENV__

    call = Macro.expand_once(call, env)

    {name, args} =
      case Macro.decompose_call(call) do
        :error -> {Orb.DSL.__expand_identifier(call, env), []}
        {name, []} -> {name, []}
        {name, [keywords]} when is_list(keywords) -> {name, keywords}
      end

    param_type =
      case for {_, type} <- args, do: Macro.expand_literals(type, env) do
        [] -> nil
        list -> List.to_tuple(list)
      end

    quote do
      @wasm_types %Orb.Type{
        name: unquote(name),
        inner_type: %Orb.Func.Type{
          params: unquote(Macro.escape(param_type)),
          result: unquote(result)
        }
      }
    end
  end

  @doc """
  Copy WebAssembly functions from one module into the current module.

  ## Examples

  ```elixir
  defmodule Math do
    use Orb

    defw square(n: I32), I32 do
      n * n
    end
  end

  defmodule SomeOtherModule do
    use Orb

    Orb.include(Math)

    defw magic(), I32 do
      Math.square(3)
    end
  end
  ```
  """
  defmacro include(mod) do
    quote do
      def __wasm_body__(context) do
        previous = super(context)

        funcs = List.wrap(Orb.ModuleDefinition.funcp_ref_all!(unquote(mod)))

        previous ++ funcs
      end

      defoverridable __wasm_body__: 1
    end
  end

  @doc """
  Adds a prefix to all functions within this module. This namespacing helps avoid names from clashing.
  """
  defmacro set_func_prefix(func_prefix) do
    quote do
      @wasm_func_prefix unquote(func_prefix)
    end
  end

  @doc """
  Makes the globals inside exported.
  """
  defmacro export(do: block) do
    quote do
      Module.put_attribute(__MODULE__, :wasm_export_members, true)
      unquote(block)
      Module.delete_attribute(__MODULE__, :wasm_export_members)
    end
  end

  @doc """
  Declare WebAssembly globals.

  `mode` can be :readonly, :mutable, :export_readonly, or :export_mutable. The default is :mutable.

  ## Examples

  ```elixir
  defmodule GlobalExample do
    use Orb

    global do # :mutable by default
      @some_internal_global 99
    end

    global :readonly do
      @some_internal_constant 99
    end

    global :export_readonly do
      @some_public_constant 1001
    end

    global :export_mutable do
      @some_public_variable 42
    end

    # You can define multiple globals at once:
    global do
      @magic_number_a 99
      @magic_number_b 12
      @magic_number_c -5
    end
  end
  ```
  """
  defmacro global(mode \\ :mutable, do: block) do
    quote generated: true do
      unquote(__global_block(:elixir, block))

      with do
        import Kernel, except: [@: 1]

        with do
          require Orb.Global.Declare

          Orb.Global.Declare.__import_dsl(
            unquote(__MODULE__).__global_mode_mutable(unquote(mode)),
            unquote(__MODULE__).__global_mode_exported(unquote(mode))
          )

          unquote(__global_block(:orb, block))
        end
      end
    end
  end

  @doc """
  Declare WebAssembly globals.

  `mode` can be :readonly, :mutable, :export_readonly, or :export_mutable. The default is :mutable.

  ## Examples

  ```elixir
  defmodule GlobalExample do
    use Orb

    global do # :mutable by default
      @some_internal_global 99
    end

    global :readonly do
      @some_internal_constant 99
    end

    global :export_readonly do
      @some_public_constant 1001
    end

    global :export_mutable do
      @some_public_variable 42
    end

    # You can define multiple globals at once:
    global do
      @magic_number_a 99
      @magic_number_b 12
      @magic_number_c -5
    end
  end
  ```
  """
  defmacro global(type, mode, do: block) do
    quote generated: true do
      unquote(__global_block(:elixir, block))

      with do
        import Kernel, except: [@: 1]
        require Orb.Global.Declare

        Module.put_attribute(__MODULE__, :wasm_global_preferred_type, unquote(type))

        Orb.Global.Declare.__import_dsl(
          unquote(__MODULE__).__global_mode_mutable(unquote(mode)),
          if(Module.get_last_attribute(__MODULE__, :wasm_export_members, false),
            do: :exported,
            else: :internal
          )
        )

        require Orb.Global
        unquote(block)

        Module.delete_attribute(__MODULE__, :wasm_global_preferred_type)
      end
    end
  end

  def __global_mode_mutable(:readonly), do: :readonly
  def __global_mode_mutable(:mutable), do: :mutable
  def __global_mode_mutable(:export_readonly), do: :readonly
  def __global_mode_mutable(:export_mutable), do: :mutable
  def __global_mode_exported(:readonly), do: :internal
  def __global_mode_exported(:mutable), do: :internal
  def __global_mode_exported(:export_readonly), do: :exported
  def __global_mode_exported(:export_mutable), do: :exported

  def __global_block(:elixir, items) when is_list(items) do
  end

  def __global_block(:orb, items) when is_list(items) do
    quote do
      with do
        require Orb.Global

        for {global_name, value} <- unquote(items) do
          Orb.Global.register32(
            Module.get_last_attribute(__MODULE__, :wasm_global_mutability),
            Module.get_last_attribute(__MODULE__, :wasm_global_exported),
            [
              {global_name, value}
            ]
          )
        end
      end
    end
  end

  def __global_block(_, block) do
    quote([generated: true], do: unquote(block))
  end

  @doc """
  Replaced by `Orb.Import.register/1`.
  """
  @deprecated "Use `Orb.Import.register/1` instead"
  defmacro importw(mod, namespace) when is_atom(namespace) do
    quote do
      @wasm_imports (for imp <- unquote(mod).__wasm_imports__(nil) do
                       %{imp | module: unquote(namespace)}
                     end)
    end
  end

  @doc """
  Convert Orb AST into WebAssembly text format.
  """
  def to_wat(term)

  def to_wat(term) when is_atom(term) do
    term.__wasm_module__() |> to_wat()
  end

  def to_wat(term) when is_struct(term) do
    # TODO: should we leave this as iodata? Or allow an option to be passed in?
    Orb.ToWat.to_wat(term, "") |> IO.chardata_to_string()
  end

  @doc """
  Convert Orb AST into WebAssembly binary format.
  """
  def to_wasm(term)

  def to_wasm(term) when is_atom(term) do
    term.__wasm_module__() |> to_wasm()
  end

  def to_wasm(term) when is_struct(term) do
    # <<"\0asm", 0x01000000::32>> <>
    #   <<0x01, 0x05, 0x01, 0x60, 0x00, 0x01, 0x7F>> <>
    #   <<0x03, 0x02, 0x01, 0x00>> <>
    #   <<0x07, 0x0A, 0x01, 0x06, 0x61, 0x6E, 0x73, 0x77, 0x65, 0x72, 0x00, 0x00>> <>
    #   <<0x0A, 0x06, 0x01, 0x04, 0x00, 0x41, 0x2A, 0x0B>>

    context = Orb.ToWasm.Context.new()
    # TODO: should we leave this as iodata? Or allow an option to be passed in?
    Orb.ToWasm.to_wasm(term, context) |> IO.iodata_to_binary()
  end

  def __get_block_items(block) do
    case block do
      nil -> nil
      {:__block__, _meta, block_items} -> block_items
      single -> [single]
    end
  end

  # TODO: move to Orb.Compiler
  def __lookup_global_type!(global_identifier) do
    Process.get({Orb, :global_types}) |> Map.fetch!(global_identifier)
  end
end
