defmodule DefcTest do
  use ExUnit.Case, async: true

  test "function to calculate area of a circle" do
    defmodule Geometry do
      use Orb.Component

      # const PI, f32(3.141592653589793)

      # const do
      #   @pi f32(3.141592653589793)
      # end

      # const(PI: f32(3.141592653589793))
      const pi: f32(3.141592653589793)
      # const(PI: F32 = 3.141592653589793, HELLO: F32 = 5.0)

      # defc pi() :: F32, do: 3.141592653589793
      # defc(pi :: F32 = 3.141592653589793)
      # defc(PI = f32(3.141592653589793))

      # define component
      defc area_of_circle(radius: F32) :: F32 do
        pi() * radius * radius
        # @PI * radius * radius
        # PI * radius * radius
        # ~C[PI] * radius * radius
        # %PI{} * radius * radius
      end

      fact do
        assert!(area_of_circle(0.0) === 0.0)
      end
    end

    assert Geometry.area_of_circle(1.0) == %Orb.Instruction{
             operands: [
               %Orb.Instruction{
                 operands: [
                   %Orb.Component.GlobalConst{identifier: :pi, type: :f32},
                   %Orb.Instruction.Const{push_type: :f32, value: 1.0}
                 ],
                 operation: :mul,
                 pop_type: nil,
                 push_type: :f32
               },
               %Orb.Instruction.Const{push_type: :f32, value: 1.0}
             ],
             push_type: :f32,
             operation: :mul,
             pop_type: nil
           }

    assert Geometry.area_of_circle(Orb.VariableReference.local(:foo, :f32)) == %Orb.Instruction{
             operands: [
               %Orb.Instruction{
                 operands: [
                   %Orb.Component.GlobalConst{identifier: :pi, type: :f32},
                   %Orb.VariableReference{
                     push_type: :f32,
                     entries: [%Orb.VariableReference.Local{identifier: :foo, type: :f32}],
                     pop_type: nil
                   }
                 ],
                 operation: :mul,
                 pop_type: nil,
                 push_type: :f32
               },
               %Orb.VariableReference{
                 push_type: :f32,
                 entries: [%Orb.VariableReference.Local{identifier: :foo, type: :f32}],
                 pop_type: nil
               }
             ],
             push_type: :f32,
             operation: :mul,
             pop_type: nil
           }

    # WebGL2 fragment shader
    assert Orb.glsl(Geometry) === ~S"""
           const float PI = 3.141592653589793;

           float area_of_circle(float radius) {
             return PI * radius * radius;
           }
           """
  end

  test "css units" do
    defmodule CSSUnits do
      use Orb.Component

      @default_font_size 16.0

      # input()
      # params()
      # runtime()
      uniform(
        root_font_size: f32(@default_font_size),
        line_height: f32(1.2),
        viewport_width: f32(320.0),
        viewport_height: f32(568.0)
      )

      defc rem(value: F32) :: F32 do
        value * @root_font_size
      end

      defc lh(value: F32) :: F32 do
        value * @line_height
      end

      defc vw(value: F32) :: F32 do
        value * @viewport_width / 100.0
      end

      defc vh(value: F32) :: F32 do
        value * @viewport_height / 100.0
      end

      # test_wasm do
      # end
    end

    assert CSSUnits.rem(1.0) == %Orb.Instruction{
             operands: [
               %Orb.Instruction.Const{push_type: :f32, value: 1.0},
               %Orb.Instruction.Const{push_type: :f32, value: 16.0}
             ],
             push_type: :f32,
             operation: :mul,
             pop_type: nil
           }
  end

  test "escape HTML" do
    defmodule HTMLEscape do
      use Orb.Component

      # Do we declare memory regions up-front,
      # or are they passed as parameters?
      # Components produce instructions that are copied
      # so they can have their parameters replaced when
      # copying the instructions out.
      region(Input, pages: 1) do
        global Size :: I32

        export(Size, as: "input_size")
      end

      region(Output, pages: 1) do
        global Size :: I32

        defc write!(string) :: nil do
          Size.set!(Size.get!() + string[:size])
        end
      end

      # defc escape_html(Input: Memory.Slice, Output: Memory.Slice), I32 do
      defc escape_html() :: I32 do
        Output.clear!()

        # loop char <- Input.Bytes do
        #   if do
        #     char === ?< ->
        #       Output.write!("&lt;")

        #     char === ?> ->
        #       Output.write!("&gt;")

        #     char === ?& ->
        #       Output.write!("&amp;")

        #     true ->
        #       Output.write!(char)
        #   end
        # end

        # loop Input.Bytes do
        #   ?< ->
        #     Output.write!("&lt;")

        #   ?> ->
        #     Output.write!("&gt;")

        #   ?& ->
        #     Output.write!("&amp;")

        #   char ->
        #     Output.write!(char)
        # end

        # Output.map! Input.Bytes do
        #   ?< ->
        #     "&lt;"

        #   ?> ->
        #     "&gt;"

        #   ?& ->
        #     "&amp;"

        #   true ->
        #     char
        # end

        Output.size!()
      end

      # defc_u8(escape_html_char(?<), do: "&lt;")
      # defc_u8(escape_html_char(?>), do: "&gt;")
      # defc_u8(escape_html_char(?&), do: "&amp;")
      # defc_u8(escape_html_char(char), do: char)
    end

    # defw example() do
    #   use Orb

    #   # use HTMLEscape, Input: Todo
    # end
  end
end
