defmodule Orb.S32 do
  def apply_to_ast(nodes) do
    Macro.prewalk(nodes, fn
      # Allow values known at compile time to be executed at compile-time by Elixir
      node = {:+, _, [a, b]} when is_integer(a) and is_integer(b) ->
        node

      {:+, meta, [a, b]} ->
        {:{}, meta, [:i32, :add, {a, b}]}

      node = {:-, _, [a, b]} when is_integer(a) and is_integer(b) ->
        node

      {:-, meta, [a, b]} ->
        {:{}, meta, [:i32, :sub, {a, b}]}

      {:*, _meta, [a, b]} ->
        quote do: Orb.I32.Multiply.neutralize(unquote(a), unquote(b))

      node = {:/, _, [a, b]} when is_integer(a) and is_integer(b) ->
        node

      {:/, meta, [a, b]} ->
        {:{}, meta, [:i32, :div_s, {a, b}]}

      {:<=, meta, [a, b]} ->
        {:{}, meta, [:i32, :le_s, {a, b}]}

      {:>=, meta, [a, b]} ->
        {:{}, meta, [:i32, :ge_s, {a, b}]}

      {:<, meta, [a, b]} ->
        {:{}, meta, [:i32, :lt_s, {a, b}]}

      {:>, meta, [a, b]} ->
        {:{}, meta, [:i32, :gt_s, {a, b}]}

      {:>>>, meta, [a, b]} ->
        {:{}, meta, [:i32, :shr_s, {a, b}]}

      {:<<<, meta, [a, b]} ->
        {:{}, meta, [:i32, :shl, {a, b}]}

      {:&&&, meta, [a, b]} ->
        {:{}, meta, [:i32, :and, {a, b}]}

      {:|||, meta, [a, b]} ->
        {:{}, meta, [:i32, :or, {a, b}]}

      # FIXME: I don’t like this, as it’s not really a proper “call” e.g. it breaks |> piping
      {:rem, meta, [a, b]} ->
        {:{}, meta, [:i32, :rem_s, {a, b}]}

      other ->
        other
    end)
  end
end
