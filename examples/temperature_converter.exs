Mix.install([
  {:orb, "~> 0.0.44"}
])

defmodule TemperatureConverter do
  use Orb

  defw celsius_to_fahrenheit(celsius: F32), F32 do
    celsius * (9.0 / 5.0) + 32.0
  end

  defw fahrenheit_to_celsius(fahrenheit: F32), F32 do
    (fahrenheit - 32.0) * (5.0 / 9.0)
  end
end

TemperatureConverter
|> Orb.to_wat()
|> IO.puts()
