///|
/// Whether two values agree to within `tolerance`.
fn close(actual : Double, expected : Double, tolerance : Double) -> Bool {
  (actual - expected).abs() <= tolerance
}

///|
test "knots convert to metres per second and back" {
  assert_true(
    close(knots_to_meters_per_second(100.0), 51.44444444444444, 1.0e-9),
  )
  assert_true(
    close(
      meters_per_second_to_knots(knots_to_meters_per_second(87.0)),
      87.0,
      1.0e-9,
    ),
  )
}

///|
test "knots convert to kilometres per hour and back" {
  assert_true(close(knots_to_kilometers_per_hour(100.0), 185.2, 1.0e-9))
  assert_true(
    close(
      kilometers_per_hour_to_knots(knots_to_kilometers_per_hour(87.0)),
      87.0,
      1.0e-9,
    ),
  )
}

///|
test "knots convert to miles per hour and back" {
  assert_true(close(knots_to_miles_per_hour(100.0), 115.0779, 1.0e-9))
  assert_true(
    close(miles_per_hour_to_knots(knots_to_miles_per_hour(87.0)), 87.0, 1.0e-9),
  )
}

///|
test "feet convert to metres and back" {
  assert_true(close(feet_to_meters(10000.0), 3048.0, 1.0e-9))
  assert_true(close(meters_to_feet(feet_to_meters(39000.0)), 39000.0, 1.0e-6))
}

///|
test "celsius converts to fahrenheit and back" {
  assert_true(close(celsius_to_fahrenheit(15.0), 59.0, 1.0e-9))
  assert_true(close(celsius_to_fahrenheit(-40.0), -40.0, 1.0e-9))
  assert_true(close(fahrenheit_to_celsius(212.0), 100.0, 1.0e-9))
  assert_true(
    close(fahrenheit_to_celsius(celsius_to_fahrenheit(-56.5)), -56.5, 1.0e-9),
  )
}

///|
test "the standard atmosphere cools to the tropopause and stops there" {
  assert_true(close(isa_temperature(0.0), 15.0, 1.0e-9))
  assert_true(close(isa_temperature(10000.0), -4.812, 1.0e-9))
  assert_true(close(isa_temperature(20000.0), -24.624, 1.0e-9))
  assert_true(close(isa_temperature(36089.0), -56.5, 1.0e-9))
  assert_true(close(isa_temperature(40000.0), -56.5, 1.0e-9))
}

///|
/// The winter jet is far colder than the standard atmosphere at the same
/// altitude, which is what the deviation is for: the forecast at `ABR` is
/// −25 °C at 24,000 ft, where the standard atmosphere is −32.55 °C.
test "a temperature is quoted against the standard atmosphere" {
  assert_true(close(isa_deviation(-25.0, 24000.0), 7.5488, 1.0e-9))
  assert_true(close(isa_deviation(15.0, 0.0), 0.0, 1.0e-9))
  assert_true(close(isa_deviation(-60.0, 39000.0), -3.5, 1.0e-9))
}
