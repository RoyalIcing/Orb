defmodule Orb do
  @moduledoc """
  Write WebAssembly modules with Elixir.

  WebAssembly is a low-level language — the primitives provided are essentially just integers and floats. However, it has a unique benefit: it can run in every major application environment: browsers, servers, the edge, and mobile devices like phones, tablets & laptops.

  Orb exposes the semantics of WebAssembly with a friendly Elixir DSL.

  ## Example

  Let’s create a module that calculates the average of a set of numbers.

  WebAssembly modules can have state. Here will have two pieces of state: a total `count` and a running `tally`. These are stored as **globals**. (If you are familiar with object-oriented programming, you can think of them as instance variables).

  Our module will export two functions: `insert` and `calculate_mean`. These two functions will work with the `count` and `tally` globals.

  ```elixir
  defmodule CalculateMean do
    use Orb

    I32.global(
      count: 0,
      tally: 0
    )

    wasm do
      func insert(element: I32) do
        @count = @count + 1
        @tally = @tally + element
      end

      func calculate_mean(), I32 do
        @tally / @count
      end
    end
  end
  ```

  One thing you’ll notice is that we must specify the type of function parameters and return values. Our `insert` function accepts a 32-bit integer, denoted using `I32`. It returns no value, while `calculate_mean` is annotated to return a 32-bit integer.

  We get to write math with the intuitive `+` and `/` operators. Let’s see the same module without the magic: no math operators and without `@` conveniences for working with globals:

  ```elixir
  defmodule CalculateMean do
    use Orb

    I32.global(
      count: 0,
      tally: 0
    )

    wasm do
      func insert(element: I32) do
        I32.add(global_get(:count), 1)
        global_set(:count)
        I32.add(global_get(:tally), element)
        global_set(:tally)
      end

      func calculate_mean(), I32 do
        I32.div_u(global_get(:tally), global_get(:count))
      end
    end
  end
  ```

  This is the exact same logic as before. In fact, this is what the first version expands to. Orb adds “sugar syntax” to make authoring WebAssembly nicer, to make it feel like writing Elixir or Ruby.

  ## Functions

  In Elixir you define functions publicly available outside the module with `def/1`, and functions private to the module with `defp/1`. Orb follows the same suffix convention with `func/2` and `funcp/2`.

  Consumers of your WebAssembly module will only be able to call exported functions defined using `func/2`. Making a function public in WebAssembly is known as “exporting”.

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
  wasm do
    func example() do
      1
      2
      3
    end
  end
  ```

  Then what’s happening is that we are pushing `1` onto the stack, then `2`, and then `3`. Now the stack has three items on it. Which will become our return value: a tuple of 3 integers. (Our function has no return type specified, so this will be an error if you attempted to compile the resulting module).

  So the correct return type from this function would be a tuple of three integers:

  ```elixir
  wasm do
    func example(), {I32, I32, I32} do
      1
      2
      3
    end
  end
  ```

  If you prefer, Orb allows you to be explicit with your stack pushes with `Orb.push/1`:

  ```elixir
  wasm do
    func example(), {I32, I32, I32} do
      push(1)
      push(2)
      push(3)
    end
  end
  ```

  You can use the stack to unlock novel patterns, but for the most part Orb avoids the need to interact with it. It’s just something to keep in mind if you are used to lines of code with simple values not having any side effects.

  ## Locals

  Locals are variables that live for the lifetime of a function. They must be specified upfront with their type alongside the function’s definition, and are initialized to zero.

  Here we have two locals: `under?` and `over?`, both 32-bit integers. We can set their value and then read them again at the bottom of the function.

  ```elixir
  defmodule WithinRange do
    use Orb

    wasm do
      func validate(num: I32), I32, under?: I32, over?: I32 do
        under? = num < 1
        over? = num > 255

        not (under? or over?)
      end
    end
  end
  ```

  ## Globals

  Globals are like locals, but live for the duration of the entire running module’s life. Their initial type and value are specified upfront.

  Globals by default are internal: nothing outside the module can see them. They can be exported to expose them to the outside world.

  When exporting a global you decide if it is `:readonly` or `:mutable`. Internal globals are mutable by default.

  ```elixir
  I32.global(some_internal_global: 99)

  I32.global(:readonly, some_internal_global: 99)

  I32.export_global(:readonly, some_public_constant: 1001)

  I32.export_global(:mutable, some_public_variable: 42)

  # You can define multiple globals at once:
  I32.global(magic_number_a: 99, magic_number_b: 12, magic_number_c: -5)
  ```

  You can read or write to a global using the `@` prefix:

  ```elixir
  defmodule Counter do
    use Orb

    I32.global(counter: 0)

    wasm do
      func increment() do
        @counter = @counter + 1
      end
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

    wasm do
      func get_int32(), I32 do
        Memory.load!(I32, 0x100)
      end

      func set_int32(value: I32) do
        Memory.store!(I32, 0x100, value)
      end
    end
  end
  ```

  ### Initializing memory with data

  You can populate the initial memory of your module using `Orb.Memory.initial_data/1`. This accepts an memory offset and the string to write there.

  ```elixir
  defmodule MimeTypeDataExample do
    use Orb

    Memory.pages(1)

    wasm do
      Memory.initial_data(offset: 0x100, string: "text/html")
      Memory.initial_data(offset: 0x200, string: \"""
        <!doctype html>
        <meta charset=utf-8>
        <h1>Hello world</h1>
        \""")

      func get_mime_type(), I32 do
        0x100
      end

      func get_body(), I32 do
        0x200
      end
    end
  end
  ```

  Having to manually allocate and remember each memory offset is a pain, so Orb provides conveniences which are detailed in the next section.

  ## Strings constants

  You can use constant strings with the `~S` sigil. These will be extracted as initial data definitions at the start of the WebAssembly module, and their memory offsets substituted in their place.

  Each string is packed together for maximum efficiency of memory space. Strings are deduplicated, so you can use the same string constant multiple times and a single allocation will be made.

  String constants in Orb are nul-terminated.

  ```elixir
  defmodule MimeTypeStringExample do
    use Orb

    Memory.pages(1)

    wasm do
      func get_mime_type(), I32 do
        ~S"text/html"
      end

      func get_body(), I32 do
        ~S\"""
        <!doctype html>
        <meta charset=utf-8>
        <h1>Hello world</h1>
        \"""
      end
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

  If you want a ternary operator (e.g. to map from one value to another), you can use `Orb.I32.when?/2` instead:

  ```elixir
  music_volume = I32.when? @party_mode? do
    100
  else
    30
  end
  ```

  These can be written on single line too:

  ```elixir
  music_volume = I32.when?(@party_mode?, do: 100, else: 30)
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
  defblock Validate do
    break(Validate, if: i < 0)

    # Do something with i
  end
  ```

  Blocks can have a type.

  ```elixir
  defblock Double, I32 do
    if i < 0 do
      push(0)
      break(Double)
    end

    push(i * 2)
  end
  ```

  ## Calling other functions

  You can `Orb.call/1` other functions defined within your module. Currently, the parameters and return type are not checked, so you must ensure you are calling with the correct arity and types.

  ```elixir
  char = call(:encode_html_char, char)
  ```

  ## Composing modules together

  Any functions from one module can be included into another to allow code reuse.

  When you `use Orb`, `funcp` and `func` functions are defined on your Elixir module for you. Calling these from another module will copy any functions across.

  ```elixir
  defmodule A do
    use Orb

    wasm do
      func square(n: I32), I32 do
        n * n
      end
    end
  end
  ```

  ```elixir
  defmodule B do
    use Orb

    # Copies all functions defined in A as private functions into this module.
    A.funcp()

    wasm do
      func example(n: I32), I32 do
        call(:square, 42)
      end
    end
  end
  ```

  You can pass a name to `YourSourceModule.funcp(name)` to only copy that particular function across.

  ```elixir
  defmodule A do
    use Orb

    wasm do
      func square(n: I32), I32 do
        n * n
      end

      func double(n: I32), I32 do
        2 * n
      end
    end
  end
  ```

  ```elixir
  defmodule B do
    use Orb

    A.funcp(:square)

    wasm do
      func example(n: I32), I32 do
        call(:square, 42)
      end
    end
  end
  ```

  ## Importing

  Your running WebAssembly module can interact with the outside world by importing globals and functions.

  ## Use Elixir features

  - Piping
  - Module attributes
  - Inline for

  ### Custom types with `Access`

  TODO: extract this into its own section.

  ## Define your own functions and macros

  ## Hex packages

  - GoldenOrb
      - String builder
  - SilverOrb

  ## Running your module
  """

  alias Orb.Ops
  alias Orb.Memory
  require Ops

  defmacro __using__(opts) do
    inline? = Keyword.get(opts, :inline, false)

    attrs =
      case inline? do
        true ->
          nil

        false ->
          quote do
            @before_compile unquote(__MODULE__).BeforeCompile
          end
      end

    quote do
      import Orb
      alias Orb.{I32, I64, S32, U32, F32, Memory}
      require Orb.{I32, Memory}

      # @wasm_name __MODULE__ |> Module.split() |> List.last()
      # @before_compile {unquote(__MODULE__), :register_attributes}

      # unless unquote(inline?) do
      #   @before_compile unquote(__MODULE__).BeforeCompile
      # end

      unquote(attrs)

      if Module.open?(__MODULE__) do
        # @before_compile unquote(__MODULE__).BeforeCompile
        # Module.put_attribute(__MODULE__, :before_compile, unquote(__MODULE__).BeforeCompile)

        Module.put_attribute(__MODULE__, :wasm_name, __MODULE__ |> Module.split() |> List.last())

        Module.register_attribute(__MODULE__, :wasm_memory, accumulate: true)

        Module.register_attribute(__MODULE__, :wasm_globals, accumulate: true)

        Module.register_attribute(__MODULE__, :wasm_imports, accumulate: true)
        Module.register_attribute(__MODULE__, :wasm_body, accumulate: true)
        # @wasm_memory 0
      end
    end
  end

  # TODO: extract this out
  defmodule ModuleDefinition do
    @moduledoc false

    defstruct name: nil,
              imports: [],
              memory: nil,
              globals: [],
              body: []

    def new(options) do
      {body, options} = Keyword.pop(options, :body)

      {func_refs, other} = Enum.split_with(body, &match?({:mod_func_ref, _, _}, &1))

      func_refs =
        func_refs
        |> Enum.uniq()
        |> Enum.map(&resolve_func_ref/1)
        |> List.flatten()
        |> Enum.uniq_by(fn func -> {func.source_module, func.name} end)

      body = func_refs ++ other

      fields = Keyword.put(options, :body, body)
      struct!(__MODULE__, fields)
    end

    defp resolve_func_ref({:mod_func_ref, visiblity, {mod, name}}) do
      fetch_func!(mod.__wasm_module__(), visiblity, mod, name)
    end

    defp resolve_func_ref({:mod_func_ref, visiblity, mod}) when is_atom(mod) do
      fetch_func!(mod.__wasm_module__(), visiblity, mod)
    end

    defmodule FetchFuncError do
      defexception [:func_name, :module_definition]

      @impl true
      def message(%{func_name: func_name, module_definition: module_definition}) do
        "funcp #{func_name} not found in #{module_definition.name} #{inspect(module_definition.body)}"
      end
    end

    def fetch_func!(%__MODULE__{body: body} = module_definition, visibility, source_module) do
      body = List.flatten(body)
      exported? = visibility == :exported

      funcs =
        Enum.flat_map(body, fn
          %Orb.Func{} = func ->
            [%{func | exported?: exported?, source_module: func.source_module || source_module}]

          _ ->
            []
        end)

      funcs
    end

    def fetch_func!(%__MODULE__{body: body} = module_definition, visibility, source_module, name) do
      body = List.flatten(body)
      exported? = visibility == :exported

      # func = Enum.find(body, &match?(%Orb.Func{name: ^name}, &1))
      func =
        Enum.find_value(body, fn
          %Orb.Func{name: ^name} = func ->
            %{func | exported?: exported?, source_module: func.source_module || source_module}

          _ ->
            false
        end)

      func || raise FetchFuncError, func_name: name, module_definition: module_definition
    end

    def func_ref!(mod, name) when is_atom(mod) do
      {:mod_func_ref, :exported, {mod, name}}
    end

    def func_ref_all!(mod) when is_atom(mod) do
      {:mod_func_ref, :exported, mod}
    end

    def funcp_ref!(mod, name) when is_atom(mod) do
      {:mod_func_ref, :internal, {mod, name}}
    end

    def funcp_ref_all!(mod) when is_atom(mod) do
      {:mod_func_ref, :internal, mod}
    end
  end

  # TODO: extract this out
  defmodule Import do
    @moduledoc false

    defstruct [:module, :name, :type]
  end

  # TODO: break up into multiple modules. Perhaps add/2 etc can be put on Orb.I32.DSL?
  defmodule I32 do
    @moduledoc """
    Type for 32-bit integer.
    """

    import Kernel, except: [and: 2, or: 2]

    require Ops

    def wasm_type(), do: :i32

    def add(a, b)
    def sub(a, b)
    def mul(a, b)
    def div_u(a, divisor)
    def div_s(a, divisor)
    def rem_u(a, divisor)
    def rem_s(a, divisor)
    def unquote(:or)(a, b)
    def xor(a, b)
    def shl(a, b)
    def shr_u(a, b)
    def shr_s(a, b)
    def rotl(a, b)
    def rotr(a, b)

    # def store(offset, i32)
    # def store8(offset, i8)

    for op <- Ops.i32(1) do
      def unquote(op)(a) do
        {:i32, unquote(op), a}
      end
    end

    for op <- Ops.i32(2) do
      case op do
        :eq ->
          def eq(0, n), do: {:i32, :eqz, n}
          def eq(n, 0), do: {:i32, :eqz, n}
          def eq(a, b), do: {:i32, :eq, {a, b}}

        :and ->
          def band(a, b) do
            {:i32, :and, {a, b}}
          end

        _ ->
          def unquote(op)(a, b) do
            {:i32, unquote(op), {a, b}}
          end
      end
    end

    # for op <- Ops.i32(:load) do
    #   def unquote(op)(offset) do
    #     {:i32, unquote(op), offset}
    #   end
    # end

    # for op <- Ops.i32(:store) do
    #   def unquote(op)(offset, value) do
    #     {:i32, unquote(op), offset, value}
    #   end
    # end

    def memory8!(offset) do
      %{
        unsigned: {:i32, :load8_u, offset},
        signed: {:i32, :load8_s, offset}
      }
    end

    # Replaced by |||
    # defp _or(a, b), do: {:i32, :or, {a, b}}

    def sum!(items) when is_list(items) do
      Enum.reduce(items, &add/2)
    end

    def in_inclusive_range?(value, lower, upper) do
      {:i32, :and, {I32.ge_u(value, lower), I32.le_u(value, upper)}}
    end

    def in?(value, list) when is_list(list) do
      for {item, index} <- Enum.with_index(list) do
        case index do
          0 ->
            eq(value, item)

          _ ->
            [eq(value, item), {:i32, :or}]
        end
      end
    end

    defmacro when?(condition, do: when_true, else: when_false) do
      quote do
        Orb.IfElse.new(
          :i32,
          unquote(condition),
          unquote(__get_block_items(when_true)),
          unquote(__get_block_items(when_false))
        )
      end
    end

    # This only works with WebAssembly 1.1
    # Sadly wat2wasm doesn’t like it
    def select(condition, do: when_true, else: when_false) do
      [
        when_true,
        when_false,
        condition,
        :select
      ]
    end

    # TODO: remove?
    def eqz?(value, do: when_true, else: when_false) do
      Orb.IfElse.new(:i32, eqz(value), when_true, when_false)
    end

    def calculate_enum(cases) do
      Map.new(Enum.with_index(cases), fn {key, index} -> {key, {:i32_const, index}} end)
    end

    def from_4_byte_ascii(<<int::little-size(32)>>), do: int

    defmacro match(value, do: transform) do
      statements =
        for {:->, _, [input, result]} <- transform do
          case input do
            # _ ->
            # like an else clause
            [{:_, _, _}] ->
              __get_block_items(result)

            [match] ->
              quote do
                %Orb.IfElse{
                  condition: I32.eq(unquote(value), unquote(match)),
                  when_true: [unquote(__get_block_items(result)), break(:i32_match)]
                }
              end

            matches ->
              quote do
                %Orb.IfElse{
                  condition: I32.in?(unquote(value), unquote(matches)),
                  when_true: [unquote(__get_block_items(result)), break(:i32_match)]
                }
              end
          end
        end

      # catchall = for {:->, _, [[{:_, _, _}], _]} <- transform, do: true
      has_catchall? = Enum.any?(transform, &match?({:->, _, [[{:_, _, _}], _]}, &1))

      final_instruction =
        case has_catchall? do
          false -> :unreachable
          true -> []
        end

      quote do
        defblock :i32_match, result: I32 do
          unquote(statements)
          unquote(final_instruction)
        end
      end
    end

    defmacro cond(do: transform) do
      statements =
        for {:->, _, [input, target]} <- transform do
          case input do
            # true ->
            # like an else clause
            [true] ->
              target

            [match] ->
              quote do
                %Orb.IfElse{
                  condition: unquote(match),
                  when_true: [unquote(__get_block_items(target)), break(:i32_map)]
                }
              end
          end
        end

      catchall = for {:->, _, [[true], _]} <- transform, do: true

      final_instruction =
        case catchall do
          [] -> :unreachable
          [true] -> []
        end

      quote do
        defblock :i32_map, result: I32 do
          unquote(statements)
          unquote(final_instruction)
        end
      end
    end

    defmacro attr_writer(global_name) when is_atom(global_name) do
      quote do
        func unquote(String.to_atom("#{global_name}="))(new_value: I32) do
          local_get(:new_value)
          global_set(unquote(global_name))
        end
      end
    end

    defmacro attr_writer(global_name, as: func_name)
             when is_atom(global_name) |> Kernel.and(is_atom(func_name)) do
      quote do
        func unquote(func_name)(new_value: I32) do
          local_get(:new_value)
          global_set(unquote(global_name))
        end
      end
    end

    defp __get_block_items(block) do
      case block do
        nil -> nil
        {:__block__, _meta, block_items} -> block_items
        single -> [single]
      end
    end

    def __global_value(value) when is_integer(value), do: Orb.i32(value)
    def __global_value(false), do: Orb.i32(false)
    def __global_value(true), do: Orb.i32(true)
    # TODO: stash away which module so we can do smart stuff like with local types
    def __global_value(mod) when is_atom(mod), do: mod.initial_i32() |> Orb.i32()

    defmacro global(mutability \\ :mutable, list)
             when mutability in ~w{readonly mutable}a do
      quote do
        @wasm_globals (for {key, value} <- unquote(list) do
                         Orb.Global.new(
                           :i32,
                           key,
                           unquote(mutability),
                           :internal,
                           Orb.I32.__global_value(value)
                         )
                       end)
      end
    end

    defmacro export_global(mutability, list)
             when mutability in ~w{readonly mutable}a do
      quote do
        @wasm_globals (for {key, value} <- unquote(list) do
                         Orb.Global.new(
                           :i32,
                           key,
                           unquote(mutability),
                           :exported,
                           Orb.I32.__global_value(value)
                         )
                       end)
      end
    end

    defmacro export_enum(keys, offset \\ 0) do
      quote do
        unquote(__MODULE__).export_global(
          :readonly,
          Enum.with_index(unquote(keys), unquote(offset))
        )
      end
    end

    defmacro enum(keys, offset \\ 0) do
      quote do
        unquote(__MODULE__).global(:readonly, Enum.with_index(unquote(keys), unquote(offset)))
      end
    end
  end

  # TODO: extract
  defmodule F32 do
    @moduledoc """
    Type for 32-bit floating point number.
    """

    require Ops

    def wasm_type(), do: :f32

    for op <- Ops.f32(1) do
      def unquote(op)(a) do
        {:f32, unquote(op), a}
      end
    end

    for op <- Ops.f32(2) do
      def unquote(op)(a, b) do
        {:f32, unquote(op), {a, b}}
      end
    end
  end

  def module(name, do: body) do
    %ModuleDefinition{name: name, body: body}
  end

  def module(name, body) do
    %ModuleDefinition{name: name, body: body}
  end

  defmodule Constants do
    @moduledoc false

    defstruct offset: 0xFF, items: []

    def new(items) do
      items = Enum.uniq(items)
      %__MODULE__{items: items}
    end

    def to_keylist(%__MODULE__{offset: offset, items: items}) do
      {lookup_table, _} =
        items
        |> Enum.map_reduce(offset, fn string, offset ->
          {{string, offset}, offset + byte_size(string) + 1}
        end)

      lookup_table
    end

    def to_map(%__MODULE__{} = receiver) do
      receiver |> to_keylist() |> Map.new()
    end

    def resolve(_constants, {:i32_const_string, _strptr, _string} = value) do
      value
    end

    def resolve(constants, value) do
      {:i32_const_string, Map.fetch!(constants, value), value}
    end
  end

  # TODO: extract?
  defmodule VariableReference do
    @moduledoc false

    defstruct [:global_or_local, :identifier, :type]

    def global(identifier, type) do
      %__MODULE__{global_or_local: :global, identifier: identifier, type: type}
    end

    def local(identifier, type) do
      %__MODULE__{global_or_local: :local, identifier: identifier, type: type}
    end

    def as_set(%__MODULE__{global_or_local: :local, identifier: identifier}) do
      {:local_set, identifier}
    end

    @behaviour Access

    @impl Access
    def fetch(%__MODULE__{global_or_local: :local, identifier: identifier, type: :i32} = ref,
          at: offset
        ) do
      ast = {:i32, :load, {:i32, :add, {ref, offset}}}
      {:ok, ast}
    end

    def fetch(
          %__MODULE__{global_or_local: :local, identifier: identifier, type: mod} = ref,
          key
        ) do
      mod.fetch(ref, key)
    end

    defimpl Orb.ToWat do
      def to_wat(%VariableReference{global_or_local: :global, identifier: identifier}, indent) do
        [indent, "(global.get $", to_string(identifier), ?)]
      end

      def to_wat(%VariableReference{global_or_local: :local, identifier: identifier}, indent) do
        [indent, "(local.get $", to_string(identifier), ?)]
      end
    end
  end

  defp interpolate_external_values(ast, env) do
    Macro.postwalk(ast, fn
      {:^, _, [term]} ->
        Macro.postwalk(term, &Macro.expand_once(&1, env))

      {:^, _, _other} ->
        raise "Invalid ^. Expected single argument."

      other ->
        other
    end)
  end

  def do_module_body(block, options, env, env_module) do
    # TODO split into readonly_globals and mutable_globals?
    internal_global_types = Keyword.get(options, :globals, [])
    # TODO rename to export_readonly_globals?
    exported_global_types = Keyword.get(options, :exported_globals, [])
    exported_mutable_global_types = Keyword.get(options, :exported_mutable_globals, [])

    internal_global_types =
      internal_global_types ++
        List.flatten(List.wrap(Module.get_attribute(env_module, :wasm_global)))

    # dbg(env_module)
    # dbg(Module.get_attribute(env_module, :wasm_global))

    globals =
      (internal_global_types ++ exported_global_types ++ exported_mutable_global_types)
      |> Keyword.new(fn {key, _} -> {key, nil} end)
      |> Map.new()

    block = interpolate_external_values(block, env)

    block_items =
      case block do
        {:__block__, _meta, block_items} -> block_items
        single -> List.wrap(single)
      end

    # block_items = Macro.expand(block_items, env)
    # block_items = block_items

    {block_items, constants} =
      Macro.prewalk(block_items, [], fn
        # TODO: remove, replaced by @global_name =
        {:=, _meta1, [{global, _meta2, nil}, input]}, constants
        when is_atom(global) and is_map_key(globals, global) ->
          {[input, global_set(global)], constants}

        {atom, meta, nil}, constants when is_atom(atom) and is_map_key(globals, atom) ->
          {quote(do: Orb.VariableReference.global(unquote(atom), unquote(globals[atom]))),
           constants}

        {:const, _, [str]}, constants when is_binary(str) ->
          {quote(do: data_for_constant(unquote(str))), [str | constants]}

        {:sigil_S, _, [{:<<>>, _, [str]}, _]}, constants ->
          {
            quote(do: data_for_constant(unquote(str))),
            [str | constants]
          }

        # FIXME: have to decide whether supporting ~s and interpolation is too hard.
        {:sigil_s, _, [{:<<>>, _, [str]}, _]}, constants ->
          {
            quote(do: data_for_constant(unquote(str))),
            [str | constants]
          }

        # {quote(do: data_for_constant(unquote(str))), [str | constants]}

        other, constants ->
          {other, constants}
      end)

    constants = Enum.reverse(constants)

    block_items =
      case constants do
        [] -> block_items
        _ -> [quote(do: Constants.new(unquote(constants))) | block_items]
      end

    %{
      body: block_items,
      constants: constants
    }
  end

  defmodule BeforeCompile do
    @moduledoc false

    defmacro __before_compile__(_env) do
      quote do
        def __wasm_module__() do
          ModuleDefinition.new(
            name: @wasm_name,
            imports: @wasm_imports |> Enum.reverse() |> List.flatten(),
            globals: @wasm_globals |> Enum.reverse() |> List.flatten(),
            memory: Memory.from(@wasm_memory),
            body: @wasm_body |> Enum.reverse() |> List.flatten()
          )
        end

        # def func(),
        #   do: Orb.ModuleDefinition.func_ref_all!(__MODULE__)

        def _func(name),
          do: Orb.ModuleDefinition.func_ref!(__MODULE__, name)

        @doc "Import all WebAssembly functions from this module’s Orb definition."
        def funcp(),
          do: Orb.ModuleDefinition.funcp_ref_all!(__MODULE__)

        @doc "Import a specific WebAssembly function from this module’s Orb definition."
        def funcp(name),
          do: Orb.ModuleDefinition.funcp_ref!(__MODULE__, name)

        @doc "Convert this module’s Orb definition to WebAssembly text (Wat) format."
        def to_wat(), do: Orb.to_wat(__wasm_module__())
      end
    end
  end

  defmacro data_for_constant(value) do
    quote do
      Constants.new(@wasm_constants)
      |> Constants.to_map()
      |> Constants.resolve(unquote(value))
    end
  end

  defp mode_pre(mode) do
    dsl =
      case mode do
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

        :no_magic ->
          []
      end

    quote do
      import Kernel,
        except: [
          if: 2,
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

      # TODO: should this be omitted if :no_magic is passed?
      import Orb.IfElse.DSL
      unquote(dsl)
    end
  end

  defp mode_post(mode) do
    dsl =
      case mode do
        Orb.S32 ->
          quote do
            import Orb.I32.DSL, only: []
            import Orb.S32.DSL, only: []
            import Orb.Global.DSL, only: []
          end

        Orb.U32 ->
          quote do
            import Orb.I32.DSL, only: []
            import Orb.U32.DSL, only: []
            import Orb.Global.DSL, only: []
          end

        :no_magic ->
          []
      end

    quote do
      import Kernel
      import Orb.IfElse.DSL, only: []
      unquote(dsl)
    end
  end

  defmacro wasm(mode \\ Orb.S32, do: block) do
    # block = interpolate_external_values(block, __ENV__)

    mode = Macro.expand_literals(mode, __CALLER__)
    pre = mode_pre(mode)
    post = mode_post(mode)

    %{body: body, constants: constants} = do_module_body(block, [], __CALLER__, __CALLER__.module)
    Module.put_attribute(__CALLER__.module, :wasm_constants, constants)

    quote do
      unquote(pre)

      @wasm_body unquote(body)

      unquote(post)
    end
  end

  defmacro wasm_import(mod, entries) when is_atom(mod) and is_list(entries) do
    quote do
      @wasm_imports (for {name, type} <-
                           unquote(entries) do
                       %Import{module: unquote(mod), name: name, type: type}
                     end)
    end
  end

  def expand_type(type, env \\ __ENV__) do
    Orb.ToWat.Instructions.expand_type(type, env)
  end

  defmacro func(call, do: block) do
    define_func(call, :public, [], block, __CALLER__)
  end

  defmacro func(call, locals, do: block) when is_list(locals) do
    define_func(call, :public, [locals: locals], block, __CALLER__)
  end

  defmacro func(call, result_type, do: block) do
    define_func(call, :public, [result: result_type], block, __CALLER__)
  end

  defmacro func(call, result_type, locals, do: block) when is_list(locals) do
    define_func(call, :public, [result: result_type, locals: locals], block, __CALLER__)
  end

  def funcp(options) do
    name = Keyword.fetch!(options, :name)
    Orb.Func.Type.imported_func(name, options[:params], options[:result])
  end

  # TODO: require `globals` option be passed to explicitly list global used.
  # Would be useful for sharing funcp between wasm modules too.
  # Also incentivises making funcp pure by having all inputs be parameters.
  defmacro funcp(call, do: block) do
    define_func(call, :private, [], block, __CALLER__)
  end

  defmacro funcp(call, locals, do: block) when is_list(locals) do
    define_func(call, :private, [locals: locals], block, __CALLER__)
  end

  defmacro funcp(call, result_type, do: block) do
    define_func(call, :private, [result: result_type], block, __CALLER__)
  end

  defmacro funcp(call, result_type, locals, do: block) when is_list(locals) do
    define_func(call, :private, [result: result_type, locals: locals], block, __CALLER__)
  end

  defp define_func(call, visibility, options, block, env) do
    call = Macro.expand_once(call, __ENV__)

    {name, args} =
      case Macro.decompose_call(call) do
        :error -> {expand_identifier(call, __ENV__), []}
        other -> other
      end

    name = name

    exported? =
      case visibility do
        :public -> true
        :private -> false
      end

    params =
      case args do
        [args] when is_list(args) ->
          for {name, type} <- args do
            Macro.escape(param(name, expand_type(type, env)))
          end

        args ->
          for {name, _meta, [type]} <- args do
            Macro.escape(param(name, expand_type(type, env)))
          end
      end

    arg_types =
      case args do
        [args] when is_list(args) ->
          for {name, type} <- args do
            {name, expand_type(type, env)}
          end

        args ->
          for {name, _meta, [type]} <- args do
            {name, expand_type(type, env)}
          end
      end

    result_type = Keyword.get(options, :result, nil) |> expand_type(env)

    local_types =
      for {key, type} <- Keyword.get(options, :locals, []) do
        {key, expand_type(type, env)}
      end

    locals = Map.new(arg_types ++ local_types)

    # block = Macro.expand_once(block, __ENV__)

    block_items =
      case block do
        {:__block__, _meta, block_items} -> block_items
        single -> [single]
      end

    block_items = Macro.expand(block_items, env)
    block_items = do_snippet(locals, block_items)

    quote do
      # List.flatten([
      #   unquote(Macro.escape(data_els)),
      %Orb.Func{
        name: unquote(name),
        params: unquote(params),
        result: result(unquote(result_type)),
        local_types: unquote(local_types),
        body: unquote(block_items),
        exported?: unquote(exported?)
      }

      # ])
    end
  end

  def do_snippet(locals, block_items) do
    Macro.prewalk(block_items, fn
      # TODO: remove, replace with I32.store8
      {:=, _, [{{:., _, [Access, :get]}, _, [{:memory32_8!, _, nil}, offset]}, value]} ->
        quote do: {:i32, :store8, unquote(offset), unquote(value)}

      {{:., _, [{{:., _, [Access, :get]}, _, [{:memory32_8!, _, nil}, offset]}, :unsigned]}, _, _} ->
        quote do: {:i32, :load8_u, unquote(offset)}

      # TODO: remove, replace with I32.store
      {:=, _, [{{:., _, [Access, :get]}, _, [{:memory32!, _, nil}, offset]}, value]} ->
        quote do: {:i32, :store, unquote(offset), unquote(value)}

      {{:., _, [Access, :get]}, _, [{:memory32!, _, nil}, offset]} ->
        quote do: {:i32, :load, unquote(offset)}

      # local[at!: offset] = value
      {:=, _meta,
       [
         {{:., _, [Access, :get]}, _,
          [
            {local, _, nil},
            [
              at!: offset
            ]
          ]},
         value
       ]}
      when is_atom(local) and is_map_key(locals, local) ->
        # FIXME: add error message
        bytes_factor = locals[local].byte_count()

        store_instruction =
          case bytes_factor do
            1 -> :store8
            4 -> :store
          end

        computed_offset =
          case {offset, bytes_factor} do
            {0, _} ->
              quote do: local_get(unquote(local))

            {offset, 1} ->
              quote do: I32.add(local_get(unquote(local)), unquote(offset))

            # We can compute at compile-time
            {offset, factor} when is_integer(offset) ->
              quote do:
                      I32.add(
                        local_get(unquote(local)),
                        unquote(offset * factor)
                      )

            # We can only compute at runtime
            {offset, factor} ->
              quote do:
                      I32.add(
                        local_get(unquote(local)),
                        I32.mul(unquote(offset), unquote(factor))
                      )
          end

        quote do: {:i32, unquote(store_instruction), unquote(computed_offset), unquote(value)}

      {:=, _, [{local, _, nil}, input]}
      when is_atom(local) and is_map_key(locals, local) and
             is_struct(:erlang.map_get(local, locals), Orb.VariableReference) ->
        [input, quote(do: {:local_set, unquote(local)})]

      {:=, _, [{local, _, nil}, input]}
      when is_atom(local) and is_map_key(locals, local) ->
        [input, quote(do: {:local_set, unquote(local)})]

      {atom, meta, nil} when is_atom(atom) and is_map_key(locals, atom) ->
        # {:local_get, meta, [atom]}
        quote do: Orb.VariableReference.local(unquote(atom), unquote(locals[atom]))

      # @some_global = input
      {:=, _, [{:@, _, [{global, _, nil}]}, input]} when is_atom(global) ->
        [input, global_set(global)]

      # @some_global
      #       node = {:@, meta, [{global, _, nil}]} when is_atom(global) ->
      #         if global == :weekdays_i32 do
      #           dbg(meta)
      #           dbg(node)
      #         end
      #
      #         {:global_get, meta, [global]}

      {:=, _, [{:_, _, nil}, value]} ->
        quote do: [unquote(value), :drop]

      other ->
        other
    end)
  end

  defmacro snippet(mode \\ Orb.S32, locals \\ [], do: block) do
    block = interpolate_external_values(block, __CALLER__)

    mode = Macro.expand_literals(mode, __CALLER__)
    pre = mode_pre(mode)
    post = mode_post(mode)

    block_items =
      case block do
        {:__block__, _meta, items} -> items
        single -> [single]
      end

    locals =
      for {key, type} <- locals, into: %{} do
        {key, expand_type(type, __CALLER__)}
      end

    quote do
      unquote(pre)

      unquote(do_snippet(locals, block_items))

      unquote(post)
    end
  end

  def pack_strings_nul_terminated(start_offset, strings_record) do
    {lookup_table, _} =
      Enum.map_reduce(strings_record, start_offset, fn {key, string}, offset ->
        {{key, %{offset: offset, string: string}}, offset + byte_size(string) + 1}
      end)

    Map.new(lookup_table)
  end

  # TODO: merge with existing code?
  @primitive_types [:i32, :f32, :i32_u8]

  def param(name, type) when type in @primitive_types do
    %Orb.Func.Param{name: name, type: type}
  end

  def param(name, type) when is_atom(type) do
    # unless function_exported?(type, :wasm_type, 0) do
    #   raise "Param of type #{type} must implement wasm_type/0."
    # end

    %Orb.Func.Param{name: name, type: type}
  end

  def export(name) do
    {:export, name}
  end

  def result(nil), do: nil
  def result(type) when type in @primitive_types, do: {:result, type}

  def result(type) when is_atom(type) do
    # unless function_exported?(type, :wasm_type, 0) do
    #   raise "Param of type #{type} must implement wasm_type/0."
    # end

    {:result, type}
  end

  def result({a, b}) when is_atom(a) and is_atom(b), do: {:result, {a, b}}

  # TODO: unused
  def i32_const(value), do: {:i32_const, value}
  def i32_boolean(0), do: {:i32_const, 0}
  def i32_boolean(1), do: {:i32_const, 1}
  def i32(n) when is_integer(n), do: {:i32_const, n}
  def i32(false), do: {:i32_const, 0}
  def i32(true), do: {:i32_const, 1}
  def i32(op) when op in Ops.i32(:all), do: {:i32, op}

  def push(tuple)
      when is_tuple(tuple) and elem(tuple, 0) in [:i32, :i32_const, :local_get, :global_get],
      do: tuple

  def push(n) when is_integer(n), do: {:i32_const, n}
  def push(%VariableReference{} = ref), do: ref

  def push(do: [value, {:local_set, local}]), do: [value, {:local_tee, local}]

  def push(value, do: block) do
    [
      value,
      __get_block_items(block),
      :pop
    ]
  end

  def global_get(identifier), do: {:global_get, identifier}
  def global_set(identifier), do: {:global_set, identifier}

  def local(identifier, type), do: {:local, identifier, type}
  def local_get(identifier), do: {:local_get, identifier}
  def local_set(identifier), do: {:local_set, identifier}
  # TODO: use local_tee when using push(local = …)
  def local_tee(identifier), do: {:local_tee, identifier}
  def local_tee(identifier, value), do: [value, {:local_tee, identifier}]

  def __get_block_items(block) do
    case block do
      nil -> nil
      {:__block__, _meta, block_items} -> block_items
      single -> [single]
    end
  end

  @doc """
  Call local function `f`.
  """
  def call(f), do: {:call, f, []}

  @doc """
  Call local function `f`, passing single argument `a`.
  """
  def call(f, a), do: {:call, f, [a]}
  @doc """
  Call local function `f`, passing arguments `a` & `b`.
  """
  def call(f, a, b), do: {:call, f, [a, b]}
  @doc """
  Call local function `f`, passing argument `a`, `b` & `c`.
  """
  def call(f, a, b, c), do: {:call, f, [a, b, c]}

  defp expand_identifier(identifier, env) do
    identifier = Macro.expand_once(identifier, env) |> Kernel.to_string()

    case identifier do
      "Elixir." <> _rest = string ->
        string |> Module.split() |> Enum.join(".")

      other ->
        other
    end
  end

  @doc """
  Declare a loop that iterates through a source.
  """
  defmacro loop({:<-, _, [item, source]}, do: block) do
    result_type = nil

    {set_item, identifier} =
      case item do
        {:_, _, _} ->
          {[], "_"}

        _ ->
          {quote(
             do: [
               unquote(source)[:value],
               Orb.VariableReference.as_set(unquote(item))
             ]
           ), quote(do: unquote(item).identifier)}
      end

    block_items =
      quote(
        do:
          Orb.IfElse.new(
            # unquote(source),
            unquote(source)[:valid?],
            [
              unquote(set_item),
              unquote(__get_block_items(block)),
              unquote(source)[:next],
              Orb.VariableReference.as_set(unquote(source)),
              {:br, unquote(identifier)}
            ]
          )
      )

    quote do
      %Orb.Loop{
        identifier: unquote(identifier),
        result: unquote(result_type),
        body: unquote(block_items)
      }
    end
  end

  @doc """
  Declare a loop.
  """
  defmacro loop(identifier, options \\ [], do: block) do
    identifier = expand_identifier(identifier, __CALLER__)
    result_type = Keyword.get(options, :result, nil) |> expand_type()
    while = Keyword.get(options, :while, nil)

    block_items = __get_block_items(block)

    block_items =
      Macro.prewalk(block_items, fn
        {{:., _, [{:__aliases__, _, [identifier]}, :continue]}, _, []} ->
          # quote do: br(unquote(identifier))
          quote do: {:br, unquote(identifier)}

        {{:., _, [{:__aliases__, _, [identifier]}, :continue]}, _, [[if: condition]]} ->
          # quote do: br(unquote(identifier))
          quote do: {:br_if, unquote(identifier), unquote(condition)}

        other ->
          other
      end)

    block_items =
      case while do
        nil ->
          block_items

        condition ->
          quote do:
                  Orb.IfElse.new(
                    unquote(condition),
                    [unquote(block_items), {:br, unquote(identifier)}]
                  )
      end

    # quote bind_quoted: [identifier: identifier] do
    quote do
      %Orb.Loop{
        identifier: unquote(identifier),
        result: unquote(result_type),
        body: unquote(block_items)
      }
    end
  end

  @doc """
  Declare a block, useful for structured control flow.
  """
  defmacro defblock(identifier, options \\ [], do: block) do
    identifier = expand_identifier(identifier, __CALLER__)
    result_type = Keyword.get(options, :result, nil) |> expand_type()

    block_items = __get_block_items(block)

    quote do
      %Orb.Block{
        identifier: unquote(identifier),
        result: unquote(result_type),
        body: unquote(block_items)
      }
    end
  end

  # import Kernel

  @doc """
  Run code at compile-time.
  """
  defmacro inline(do: block) do
    block |> __get_block_items()
  end

  @doc """
  Run Elixir for-comprehension at compile-time.
  """
  defmacro inline({:for, meta, [for_arg]}, do: block) do
    # for_arg = interpolate_external_values(for_arg, __CALLER__)
    block = block |> __get_block_items()
    # import Kernel
    {:for, meta, [for_arg, [do: block]]}
    # {:for, meta, [for_arg, [do: quote do: inline(do: unquote(block))]]}
  end

  @doc """
  Declare a constant string, which will be extracted to the top of the module, and its address substituted in place.
  """
  def const(value) do
    {:const_string, value}
  end

  # TODO: decide if this idea is dead.
  @doc false
  def const_set_insert(set_name, string) when is_atom(set_name) and is_binary(string) do
    :todo
  end

  # TODO: add a comptime keyword like Zig: https://kristoff.it/blog/what-is-zig-comptime/

  @doc """
  Break from a block.
  """
  def break(identifier), do: {:br, expand_identifier(identifier, __ENV__)}

  @doc """
  Break from a block if a condition is true.
  """
  def break(identifier, if: condition),
    do: {:br_if, expand_identifier(identifier, __ENV__), condition}

  @doc """
  Return from a function. You may wish to `push/1` values before returning.
  """
  def return(), do: :return
  @doc """
  Return from a function if a condition is true.
  """
  def return(if: condition), do: Orb.IfElse.new(condition, :return)
  @doc """
  Return from a function with the provided value.
  """
  def return(value), do: {:return, value}
  @doc """
  Return from a function with the provided value only if a condition is true.
  """
  def return(value, if: condition), do: Orb.IfElse.new(condition, {:return, value})

  @doc """
  A no-op instruction.

  See https://en.wikipedia.org/wiki/NOP_(code)
  """
  def nop(), do: :nop

  @doc """
  Drop the last pushed value from the stack.
  """
  def drop(), do: :drop
  @doc """
  Execute the passed expression, but ignore its result by immediately dropping its value.
  """
  def drop(expression), do: [expression, :drop]

  @doc """
  Denote a point in code that should not be reachable. Traps.

  Useful for exhaustive conditionals or code you know will not execute.
  """
  def unreachable!(), do: :unreachable

  @doc """
  Asserts a condition that _must_ be true, otherwise traps.
  """
  def assert!(condition) do
    Orb.IfElse.new(
      condition,
      nop(),
      unreachable!()
    )
  end

  # TODO: extract this out
  defmodule MutRef do
    @moduledoc """
    Use `Orb.mut!/1` to get a mutable reference to a global or local.
    """

    defstruct [:read, :write, :type]

    def from(%VariableReference{} = read) do
      %__MODULE__{read: read, write: VariableReference.as_set(read), type: read.type}
    end

    def from({:global_get, name} = read) do
      %__MODULE__{read: read, write: {:global_set, name}}
    end

    def from({:local_get, name} = read) do
      %__MODULE__{read: read, write: {:local_set, name}}
    end

    def store(%__MODULE__{write: write}, value) do
      [value, write]
    end
  end

  def mut!(term), do: MutRef.from(term)

  @doc """
  For when there’s a language feature of WebAssembly that Orb doesn’t provide. Please file an issue if there’s something you wish existed. https://github.com/RoyalIcing/Orb/issues
  """
  def raw_wat(source), do: {:raw_wat, String.trim(source)}
  def sigil_A(source, _modifiers), do: {:raw_wat, String.trim(source)}

  ####

  def to_wat(term) when is_atom(term),
    do: do_wat(term.__wasm_module__(), "") |> IO.chardata_to_string()

  def to_wat(term), do: do_wat(term, "") |> IO.chardata_to_string()

  defp do_type(type) do
    case type do
      type when type in [:i32, :i32_u8] ->
        "i32"

      :f32 ->
        "f32"

      tuple when is_tuple(tuple) ->
        tuple |> Tuple.to_list() |> Enum.map(&do_type/1) |> Enum.join(" ")

      type ->
        #         Code.ensure_loaded!(type)
        #
        #         unless function_exported?(type, :wasm_type, 0) do
        #           raise "Type #{type} must implement wasm_type/0."
        #         end

        type.wasm_type() |> to_string()
    end
  end

  def do_wat(term), do: do_wat(term, "")

  def do_wat(term, indent)

  def do_wat(list, indent) when is_list(list) do
    Enum.map(list, &do_wat(&1, indent)) |> Enum.intersperse("\n")
  end

  def do_wat(
        %ModuleDefinition{
          name: name,
          imports: imports,
          globals: globals,
          memory: memory,
          body: body
        },
        indent
      ) do
    [
      [indent, "(module $#{name}", "\n"],
      [for(import_def <- imports, do: [do_wat(import_def, "  " <> indent), "\n"])],
      case memory do
        nil ->
          []

        %Memory{} ->
          Orb.ToWat.to_wat(memory, "  " <> indent)
      end,
      for global = %Orb.Global{} <- globals do
        Orb.ToWat.to_wat(global, "  " <> indent)
      end,
      case body do
        [] ->
          ""

        body ->
          [indent, do_wat(body, "  " <> indent), "\n"]
      end,
      [indent, ")", "\n"]
    ]
  end

  def do_wat(%Import{module: nil, name: name, type: type}, indent) do
    ~s[#{indent}(import "#{name}" #{do_wat(type)})]
  end

  def do_wat(%Import{module: module, name: name, type: type}, indent) do
    ~s[#{indent}(import "#{module}" "#{name}" #{do_wat(type)})]
  end

  def do_wat(%Memory{name: nil, min: min}, indent) do
    ~s[#{indent}(memory #{min})]
  end

  def do_wat(%Memory{name: name, min: min}, indent) do
    ~s"#{indent}(memory #{do_wat(name)} #{min})"
  end

  def do_wat(%Constants{} = constants, indent) do
    # dbg(Constants.to_keylist(constants))
    for {string, offset} <- Constants.to_keylist(constants) do
      [
        indent,
        "(data (i32.const ",
        to_string(offset),
        ") ",
        ?",
        string |> String.replace(~S["], ~S[\"]) |> String.replace("\n", ~S"\n"),
        ?",
        ")"
      ]
    end
    |> Enum.intersperse("\n")
  end

  def do_wat(value, indent) when is_atom(value) do
    Orb.ToWat.Instructions.do_wat(value, indent)
  end

  def do_wat(value, indent) when is_number(value) do
    Orb.ToWat.Instructions.do_wat(value, indent)
  end

  def do_wat(value, indent) when is_tuple(value) do
    Orb.ToWat.Instructions.do_wat(value, indent)
    # Orb.ToWat.to_wat(value, indent)
  end

  def do_wat(%struct{} = value, indent) do
    # Protocol.assert_impl!(struct, Orb.ToWat)

    Orb.ToWat.to_wat(value, indent)
  end
end
