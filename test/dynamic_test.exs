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

  defmodule Dynamic do
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

    assert """
           (module $Dynamic
             (func $can_edit? (export "can_edit?") (param $post_id i32) (param $author_id i32) (result i32)
               (i32.eq (local.get $author_id) (i32.const 123))
             )
           )
           """ = Orb.to_wat(Dynamic)
  end

  test "admin user" do
    Process.put(:user_id, 123)
    Process.put(:user_type, :admin)

    assert """
           (module $Dynamic
             (func $can_edit? (export "can_edit?") (param $post_id i32) (param $author_id i32) (result i32)
               (i32.const 1)
             )
           )
           """ = Orb.to_wat(Dynamic)
  end
end
