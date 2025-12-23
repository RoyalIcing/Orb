defmodule DefcTest do
  use ExUnit.Case, async: true

  test "function to calculate area of a circle" do
    defmodule Geometry do
      use Orb.Component

      # const PI, f32(3.141592653589793)

      # global do
      @pi 3.141592653589793
      # end

      # def component
      defc area_of_circle(radius: F32), F32 do
        @pi * radius * radius
      end
    end

    # WebGL2 fragment shader
    # assert Orb.webgl2(Geometry) === ~S"""
    #        const float PI = 3.141592653589793;

    #        float area_of_circle(float radius) {
    #          return PI * radius * radius;
    #        }
    #        """
  end

  test "css units" do
    defmodule CSSUnits do
      use Orb.Component

      @default_font_size 16.0

      uniform(
        root_font_size: f32(@default_font_size),
        line_height: f32(1.2),
        viewport_width: f32(320.0),
        viewport_height: f32(568.0)
      )

      defc rem(input: F32), F32 do
        input * @root_font_size
      end

      defc lh(input: F32), F32 do
        input * @line_height
      end

      defc vw(input: F32), F32 do
        input * @viewport_width / 100.0
      end

      defc vh(input: F32), F32 do
        input * @viewport_height / 100.0
      end
    end
  end

  test "escape HTML" do
    defmodule HTMLEscape do
      use Orb.Component

      region(Input, pages: 1) do
        global Size :: I32

        export(Size, as: "input_size")
      end

      region(Output, pages: 1) do
        global Size :: I32

        defc write!(string) do
          Size.set!(Size.get!() + string[:size])
        end
      end

      # defc escape_html(Input: Memory.Slice, Output: Memory.Slice), I32 do
      defc escape_html(), I32 do
        Output.clear!()

        loop char <- Input.Bytes do
          if do
            char === ?< ->
              Output.write!("&lt;")

            char === ?> ->
              Output.write!("&gt;")

            char === ?& ->
              Output.write!("&amp;")

            true ->
              Output.write!(char)
          end
        end

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
