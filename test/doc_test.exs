defmodule DocTest do
  use ExUnit.Case, async: true

  doctest Orb.InstructionSequence
  doctest Orb.Memory
end
