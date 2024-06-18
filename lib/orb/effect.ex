defmodule Orb.Effect do
  @moduledoc false
  defstruct stack_pop: nil, stack_push: nil, memory: nil, global: nil, extern: nil

  defmodule StackPop do
    @moduledoc false
  end

  defmodule StackPush do
    @moduledoc false
  end

  defmodule MemoryWrite do
    @moduledoc false
  end

  defmodule GlobalWrite do
    @moduledoc false
  end

  defmodule ExternUnknown do
    @moduledoc false
  end
end
