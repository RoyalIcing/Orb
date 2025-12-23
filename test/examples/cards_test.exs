defmodule Examples.CardsTest do
  use WasmexCase, async: true

  defmodule EasyScorpionSolitaire do
    defmodule Suit do
      def clubs, do: 0
      def diamonds, do: 1
      def hearts, do: 2
      def spades, do: 3

      # use Orb.CustomType, 0..3
      @behaviour Orb.CustomType
      @impl Orb.CustomType
      def wasm_type, do: :i32
      # def wasm_type, do: 0..3

      # def from_atom(:clubs), do: 0
      # def from_atom(:diamonds), do: 1
      # def from_atom(:hearts), do: 2
      # def from_atom(:spaces), do: 3
      # def from_i32(value), do: value
    end

    defmodule Card do
      @behaviour Orb.CustomType
      @impl Orb.CustomType
      def wasm_type, do: {Suit, I32}
      # def wasm_type, do: {Suit, 1..13}

      def id_to_suit(id), do: id / 4
      def id_to_number(id), do: Integer.mod(id - 1, 13) + 1
      # def number_face(11), :jack
      # def number_face(12), :queen
      # def number_face(13), :king
    end

    defmodule Mode do
      @behaviour Orb.CustomType
      @impl Orb.CustomType
      def wasm_type, do: I32
      # use Orb.CustomType, I32

      def game_over(), do: 0
      def idle(), do: 1
      def moving_card(), do: 2
      def dealing_stock(), do: 3
      def won(), do: 4
    end

    defmodule Cards do
      # use Orb.Region
      use Orb.Component

      # const ColumnCount, 7
      @column_count 7

      # array(ColumnCards, I32, @column_count * 52)
      # array(ColumnFaceDownCount, I32, @column_count)

      # region ColumnFaceDownCount do
      #   array(I32, @column_count)
      # end

      defc deal_cards() do
        # ColumnFaceDownCount.set!(0, 3)
        # ColumnFaceDownCount.set!(1, 3)
        # ColumnFaceDownCount.set!(2, 3)

        # ColumnFaceDownCount.read!()
      end
    end

    # Memory.pages Cards do
    # arena Cards do
    #   @column_count 7

    #   # The cards start as face down.
    #   # Empty columns can have cards moved to them.
    #   array(ColumnFaceDownCount, I32, @column_count)

    #   # defw deal_cards() do
    #   # end
    # end
  end
end
