defmodule StringConstantsTest do
  use ExUnit.Case, async: true

  import Orb, only: [to_wat: 1]

  test "assigns data" do
    defmodule HTMLTypes do
      use Orb

      defw doctype(), Str do
        "<!doctype html>"
      end

      defw mime_type(), Str do
        "text/html"
      end
    end

    assert to_wat(HTMLTypes) == """
           (module $HTMLTypes
             (memory (export "memory") 1)
             (; constants 26 bytes ;)
             (data (i32.const 255) "<!doctype html>")
             (data (i32.const 271) "text/html")
             (func $doctype (export "doctype") (result i32 i32)
               (i32.const 255) (i32.const 15)
             )
             (func $mime_type (export "mime_type") (result i32 i32)
               (i32.const 271) (i32.const 9)
             )
           )
           """
  end

  test "works with atoms" do
    defmodule ABCAtom do
      use Orb

      defw alphabet(), I32 do
        :abc
      end

      defw always_be_closing(), I32 do
        :abc
      end

      defw australian_broadcasting_corporation(), Str do
        "abc"
      end
    end

    assert to_wat(ABCAtom) == """
           (module $ABCAtom
             (memory (export "memory") 1)
             (; constants 4 bytes ;)
             (data (i32.const 255) "abc")
             (func $alphabet (export "alphabet") (result i32)
               (i32.const 255)
             )
             (func $always_be_closing (export "always_be_closing") (result i32)
               (i32.const 255)
             )
             (func $australian_broadcasting_corporation (export "australian_broadcasting_corporation") (result i32 i32)
               (i32.const 255) (i32.const 3)
             )
           )
           """
  end

  describe "const/1" do
    test "assigns data" do
      defmodule ConstHTMLTypes do
        use Orb

        defw doctype(), Str do
          const("<!doctype html>")
        end

        defw mime_type(), Str do
          const(Enum.join(["text", "/", "html"]))
        end
      end

      assert to_wat(ConstHTMLTypes) == """
             (module $ConstHTMLTypes
               (memory (export "memory") 1)
               (; constants 26 bytes ;)
               (data (i32.const 255) "<!doctype html>")
               (data (i32.const 271) "text/html")
               (func $doctype (export "doctype") (result i32 i32)
                 (i32.const 255) (i32.const 15)
               )
               (func $mime_type (export "mime_type") (result i32 i32)
                 (i32.const 271) (i32.const 9)
               )
             )
             """
    end

    test "works with multiple wasm blocks" do
      defmodule ConstHTMLTypes2 do
        use Orb

        defw doctype(), Str do
          const(Enum.join(["<!doctype ", "html>"]))
        end

        defw mime_type(), Str do
          const(Enum.join(["text", "/", "html"]))
        end
      end

      assert to_wat(ConstHTMLTypes2) == """
             (module $ConstHTMLTypes2
               (memory (export "memory") 1)
               (; constants 26 bytes ;)
               (data (i32.const 255) "<!doctype html>")
               (data (i32.const 271) "text/html")
               (func $doctype (export "doctype") (result i32 i32)
                 (i32.const 255) (i32.const 15)
               )
               (func $mime_type (export "mime_type") (result i32 i32)
                 (i32.const 271) (i32.const 9)
               )
             )
             """
    end
  end

  describe "allocates enough memory for constants" do
    defmodule BigStrings do
      def string_of_length_1_page, do: String.duplicate("a", 64 * 1024)
      def string_should_fit_into_1_page, do: String.duplicate("a", 64 * 1024 - 0xFF - 1)
      def string_should_just_overflow_2_pages, do: string_should_fit_into_1_page() <> "b"
      def string_should_fit_into_half_page(char), do: String.duplicate(char, 32 * 1024 - 128 - 1)
    end

    test "constant that is exactly one page in size" do
      defmodule ConstantOfOnePage do
        use Orb

        defw doctype(), Str do
          const(BigStrings.string_of_length_1_page())
        end
      end

      wat =
        to_wat(ConstantOfOnePage)
        |> String.replace(BigStrings.string_of_length_1_page(), "BIGSTRING")

      assert 65537 = 64 * 1024 + 1

      assert wat == """
             (module $ConstantOfOnePage
               (memory (export "memory") 2)
               (; constants 65537 bytes ;)
               (data (i32.const 255) "BIGSTRING")
               (func $doctype (export "doctype") (result i32 i32)
                 (i32.const 255) (i32.const 65536)
               )
             )
             """
    end

    test "constant that should allocate a single page" do
      defmodule ExactlySinglePage do
        use Orb

        defw doctype(), Str do
          const(BigStrings.string_should_fit_into_1_page())
        end
      end

      wat =
        to_wat(ExactlySinglePage)
        |> String.replace(BigStrings.string_should_fit_into_1_page(), "BIGSTRING")

      assert wat == """
             (module $ExactlySinglePage
               (memory (export "memory") 1)
               (; constants 65281 bytes ;)
               (data (i32.const 255) "BIGSTRING")
               (func $doctype (export "doctype") (result i32 i32)
                 (i32.const 255) (i32.const 65280)
               )
             )
             """
    end

    test "constant that should just allocate two pages" do
      defmodule TwoPagesJust do
        use Orb

        defw doctype(), Str do
          const(BigStrings.string_should_just_overflow_2_pages())
        end
      end

      wat =
        to_wat(TwoPagesJust)
        |> String.replace(BigStrings.string_should_just_overflow_2_pages(), "BIGSTRING")

      assert wat == """
             (module $TwoPagesJust
               (memory (export "memory") 2)
               (; constants 65282 bytes ;)
               (data (i32.const 255) "BIGSTRING")
               (func $doctype (export "doctype") (result i32 i32)
                 (i32.const 255) (i32.const 65281)
               )
             )
             """
    end

    test "multiple constants that should allocate a single page" do
      defmodule MultipleConstantsExactlySinglePage do
        use Orb

        defw first(), Str do
          const(BigStrings.string_should_fit_into_half_page("a"))
        end

        defw second(), Str do
          const(BigStrings.string_should_fit_into_half_page("b"))
        end
      end

      wat =
        to_wat(MultipleConstantsExactlySinglePage)
        |> String.replace(BigStrings.string_should_fit_into_half_page("a"), "FIRST")
        |> String.replace(BigStrings.string_should_fit_into_half_page("b"), "SECOND")

      assert wat == """
             (module $MultipleConstantsExactlySinglePage
               (memory (export "memory") 1)
               (; constants 65280 bytes ;)
               (data (i32.const 255) "FIRST")
               (data (i32.const 32895) "SECOND")
               (func $first (export "first") (result i32 i32)
                 (i32.const 255) (i32.const 32639)
               )
               (func $second (export "second") (result i32 i32)
                 (i32.const 32895) (i32.const 32639)
               )
             )
             """
    end

    test "multiple constants that should allocate two single pages just" do
      defmodule MultipleConstantsTwoPagesJust do
        use Orb

        defw first(), Str do
          const(BigStrings.string_should_fit_into_half_page("a"))
        end

        defw second(), Str do
          const(BigStrings.string_should_fit_into_half_page("b"))
        end

        defw third(), Str do
          const("c")
        end
      end

      wat =
        to_wat(MultipleConstantsTwoPagesJust)
        |> String.replace(BigStrings.string_should_fit_into_half_page("a"), "FIRST")
        |> String.replace(BigStrings.string_should_fit_into_half_page("b"), "SECOND")

      assert wat == """
             (module $MultipleConstantsTwoPagesJust
               (memory (export "memory") 2)
               (; constants 65282 bytes ;)
               (data (i32.const 255) "FIRST")
               (data (i32.const 32895) "SECOND")
               (data (i32.const 65535) "c")
               (func $first (export "first") (result i32 i32)
                 (i32.const 255) (i32.const 32639)
               )
               (func $second (export "second") (result i32 i32)
                 (i32.const 32895) (i32.const 32639)
               )
               (func $third (export "third") (result i32 i32)
                 (i32.const 65535) (i32.const 1)
               )
             )
             """
    end

    test "multiple constants add with manual requested memory pages" do
      defmodule ContantsAndManualMemoryPages do
        use Orb

        Memory.pages(7)
        Memory.pages(11)

        defw first(), Str do
          const(BigStrings.string_should_just_overflow_2_pages())
        end
      end

      wat =
        to_wat(ContantsAndManualMemoryPages)
        |> String.replace(BigStrings.string_should_just_overflow_2_pages(), "BIGSTRING")

      assert wat == """
             (module $ContantsAndManualMemoryPages
               (memory (export "memory") 20)
               (; constants 65282 bytes ;)
               (data (i32.const 255) "BIGSTRING")
               (func $first (export "first") (result i32 i32)
                 (i32.const 255) (i32.const 65281)
               )
             )
             """
    end
  end
end
