(module $TemperatureConverter
  (func $celsius_to_fahrenheit (export "celsius_to_fahrenheit") (param $celsius f32) (result f32)
    (f32.add (f32.mul (local.get $celsius) (f32.const 1.8)) (f32.const 32.0))
  )
  (func $fahrenheit_to_celsius (export "fahrenheit_to_celsius") (param $fahrenheit f32) (result f32)
    (f32.mul (f32.sub (local.get $fahrenheit) (f32.const 32.0)) (f32.const 0.5555555555555556))
  )
)

