defmodule DynamicTest do
  use ExUnit.Case, async: true

  defmodule UserInfo do
    def user_id() do
      Process.get(:user_id)
    end

    def user_type() do
      Process.get(:user_type, :viewer)
    end
  end

  # SLIDE
  defmodule DynamicA do
    use Orb

    wasm do
      case UserInfo.user_type() do
        :admin ->
          func can_edit?(post_id: I32, author_id: I32), I32 do
            1
          end

        _ ->
          func can_edit?(post_id: I32, author_id: I32), I32 do
            author_id === UserInfo.user_id()
          end
      end
    end
  end

  test "default user" do
    Process.put(:user_id, 123)

    assert DynamicA.to_wat() == """
           (module $DynamicA
             (func $can_edit? (export "can_edit?") (param $post_id i32) (param $author_id i32) (result i32)
               (i32.eq (local.get $author_id) (i32.const 123))
             )
           )
           """
  end

  test "admin user" do
    Process.put(:user_id, 123)
    Process.put(:user_type, :admin)

    assert DynamicA.to_wat() == """
           (module $DynamicA
             (func $can_edit? (export "can_edit?") (param $post_id i32) (param $author_id i32) (result i32)
               (i32.const 1)
             )
           )
           """
  end
end
