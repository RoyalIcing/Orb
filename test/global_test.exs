defmodule GlobalTest do
  use ExUnit.Case, async: true

  import Orb, only: [to_wat: 1]
  import TestHelper

  test "I32" do
    defmodule GlobalsI32 do
      use Orb

      I32.global(abc: 42)
      I32.global(:readonly, CONST: 99)
      I32.export_global(:mutable, public1: 11)
      I32.export_global(:readonly, public2: 22)
    end

    assert to_wat(GlobalsI32) == """
           (module $GlobalsI32
             (global $abc (mut i32) (i32.const 42))
             (global $CONST i32 (i32.const 99))
             (global $public1 (export "public1") (mut i32) (i32.const 11))
             (global $public2 (export "public2") i32 (i32.const 22))
           )
           """
  end

  test "global do" do
    defmodule GlobalDo do
      use Orb

      global do
        @abc 42
      end

      global I32, :readonly do
        @const32 99
      end

      global I64, :readonly do
        @const64 99
      end

      export do
        global I32, :mutable do
          @public1 11
        end

        global I32, :readonly do
          @public2 22
        end

        global I64, :mutable do
          @public3 33
        end

        global F32, :mutable do
          @public4 44.0
        end

        # global F64, :mutable do
        #   @public5 33.0
        # end
      end

      global :readonly do
        @five_quarters 1.25
      end

      global :mutable do
        @language "en"
        @mime_type "text/html"
        @empty ""
      end

      defw mime_type_constant, I32.UnsafePointer do
        "text/html"
      end

      defw mime_type_global, I32.UnsafePointer do
        @mime_type
      end

      def all_attributes do
        [@abc, @const32, @const64, @public1, @public2, @public3, @public4, @five_quarters]
      end
    end

    assert ~S"""
           (module $GlobalDo
             (global $abc (mut i32) (i32.const 42))
             (global $const32 i32 (i32.const 99))
             (global $const64 i64 (i64.const 99))
             (global $public1 (export "public1") (mut i32) (i32.const 11))
             (global $public2 (export "public2") i32 (i32.const 22))
             (global $public3 (export "public3") (mut i64) (i64.const 33))
             (global $public4 (export "public4") (mut f32) (f32.const 44.0))
             (global $five_quarters f32 (f32.const 1.25))
             (global $language (mut i32) (i32.const 255))
             (global $mime_type (mut i32) (i32.const 258))
             (global $empty (mut i32) (i32.const 0))
             (data (i32.const 258) "text/html")
             (data (i32.const 255) "en")
             (func $mime_type_constant (export "mime_type_constant") (result i32)
               (i32.const 258)
             )
             (func $mime_type_global (export "mime_type_global") (result i32)
               (global.get $mime_type)
             )
           )
           """ = to_wat(GlobalDo)

    assert [42, 99, 99, 11, 22, 33, 44.0, 1.25] = GlobalDo.all_attributes()
  end

  test "I32 enum" do
    defmodule GlobalsI32Enum do
      use Orb

      I32.enum([:first, :second])
      I32.enum([:restarts, :from, :zero])
      I32.enum([:third, :fourth], 2)
      I32.export_enum([:apples, :pears])
      I32.export_enum([:ok, :created, :accepted], 200)
    end

    assert ~S"""
           (module $GlobalsI32Enum
             (global $first i32 (i32.const 0))
             (global $second i32 (i32.const 1))
             (global $restarts i32 (i32.const 0))
             (global $from i32 (i32.const 1))
             (global $zero i32 (i32.const 2))
             (global $third i32 (i32.const 2))
             (global $fourth i32 (i32.const 3))
             (global $apples (export "apples") i32 (i32.const 0))
             (global $pears (export "pears") i32 (i32.const 1))
             (global $ok (export "ok") i32 (i32.const 200))
             (global $created (export "created") i32 (i32.const 201))
             (global $accepted (export "accepted") i32 (i32.const 202))
           )
           """ = to_wat(GlobalsI32Enum)
  end
end
