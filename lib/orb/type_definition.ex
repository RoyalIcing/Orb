defmodule Orb.TypeDefinition do
  defstruct name: nil, inner_type: nil

  defimpl Orb.ToWat do
    import Orb.ToWat.Helpers

    def to_wat(
          %Orb.TypeDefinition{
            name: name,
            inner_type: inner_type
          },
          indent
        ) do
      [
        indent,
        "(type $",
        to_string(name),
        " ",
        case inner_type do
          %Orb.Func.Type{} = func_type ->
            Orb.ToWat.to_wat(func_type, "")

          other_type ->
            %Orb.Func.Type{result: other_type} |> Orb.ToWat.to_wat("")
        end,
        ")"
      ]
    end
  end
end
