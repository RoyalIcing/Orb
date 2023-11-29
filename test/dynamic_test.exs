defmodule DynamicTest do
  use ExUnit.Case, async: true

  defmodule CurrentUser do
    def get_id() do
      Process.get(:user_id) || raise "User ID must be set."
    end

    def get_type() do
      Process.get(:user_type, :viewer)
    end

    def get() do
      %{
        type: get_type(),
        id: get_id()
      }
    end
  end

  defmodule DynamicA do
    use Orb

    wasm do
      case CurrentUser.get_type() do
        :admin ->
          func can_edit?(post_id: I32, author_id: I32), I32 do
            1
          end

        :viewer ->
          func can_edit?(post_id: I32, author_id: I32), I32 do
            author_id === inline(do: CurrentUser.get_id())
          end
      end
    end
  end

  defmodule DynamicB do
    use Orb

    defw can_edit?(post_id: I32, author_id: I32), I32 do
      inline do
        case CurrentUser.get() do
          %{type: :viewer, id: user_id} ->
            wasm do
              author_id === user_id
            end

          %{type: :admin} ->
            1
        end
      end
    end
  end

  test "default user" do
    Process.put(:user_id, 123)

    expected = """
      (func $can_edit? (export "can_edit?") (param $post_id i32) (param $author_id i32) (result i32)
        (i32.eq (local.get $author_id) (i32.const 123))
      )
    )
    """

    assert Orb.to_wat(DynamicA) =~ expected
    assert Orb.to_wat(DynamicB) =~ expected
  end

  test "admin user" do
    Process.put(:user_id, 123)
    Process.put(:user_type, :admin)

    expected = """
      (func $can_edit? (export "can_edit?") (param $post_id i32) (param $author_id i32) (result i32)
        (i32.const 1)
      )
    )
    """

    assert Orb.to_wat(DynamicA) =~ expected
    assert Orb.to_wat(DynamicB) =~ expected
  end
end
