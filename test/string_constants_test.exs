defmodule StringConstantsTest do
  use ExUnit.Case, async: true

  import Orb, only: [to_wat: 1]

  test "assigns data" do
    defmodule HTMLTypes do
      use Orb

      defw doctype(), I32 do
        "<!doctype html>"
      end

      defw mime_type(), I32 do
        "text/html"
      end
    end

    assert to_wat(HTMLTypes) == """
           (module $HTMLTypes
             (; constants 26 bytes ;)
             (data (i32.const 255) "<!doctype html>")
             (data (i32.const 271) "text/html")
             (func $doctype (export "doctype") (result i32)
               (i32.const 255)
             )
             (func $mime_type (export "mime_type") (result i32)
               (i32.const 271)
             )
           )
           """
  end
end
