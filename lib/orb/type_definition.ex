defmodule Orb.TypeDefinition do
  defstruct name: nil, inner_type: nil

  defimpl Orb.ToWat do
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
        Orb.ToWat.to_wat(inner_type, ""),
        ")"
      ]
    end
  end
end
