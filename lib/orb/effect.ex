defmodule Orb.Effect do
  defstruct stack_pop: nil, stack_push: nil, memory: nil, global: nil, extern: nil

  defmodule StackPop do
  end

  defmodule StackPush do
  end

  defmodule MemoryWrite do
  end

  defmodule GlobalWrite do
  end

  defmodule ExternUnknown do
  end
end
