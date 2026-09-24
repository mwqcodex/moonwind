///|
/// Whether two values agree to within `tolerance`.
fn hum_close(actual : Double, expected : Double, tolerance : Double) -> Bool {
  (actual - expected).abs() <= tolerance
}

///|
/// The Magnus curve over water passes through 6.1094 hPa at 0 °C and takes the
/// values the tables give at 10, 20 and 30 °C.
test "the saturation vapour pressure follows the Magnus curve" {
  assert_true(hum_close(saturation_vapor_pressure(0.0), 6.1094, 1.0e-9))
  assert_true(
    hum_close(saturation_vapor_pressure(10.0), 12.260206350234858, 1.0e-6),
  )
  assert_true(
    hum_close(saturation_vapor_pressure(20.0), 23.334406230993576, 1.0e-6),
  )
  assert_true(
    hum_close(saturation_vapor_pressure(30.0), 42.366502512954746, 1.0e-6),
  )
}

///|
/// Over ice the curve passes through 6.1121 hPa at 0 °C and stays below the
/// one over water: 2.597 hPa against 2.868 hPa at −10 °C.
test "the vapour pressure over ice sits below the one over water" {
  assert_true(
    hum_close(
      saturation_vapor_pressure_over_ice(-10.0),
      2.5967178444149264,
      1.0e-6,
    ),
  )
  assert_true(
    hum_close(
      saturation_vapor_pressure_over_ice(-30.0),
      0.3796847111670685,
      1.0e-6,
    ),
  )
  assert_true(
    saturation_vapor_pressure_over_ice(-10.0) < saturation_vapor_pressure(-10.0),
  )
}

///|
/// The classic Magnus example: air at 20 °C holding half the water it could
/// has a dew point of 9.26 °C, and reading a humidity back off that dew point
/// returns the 50 % it came from. Saturated air has a dew point of its own
/// temperature.
test "a dew point is the temperature the air saturates at" {
  assert_true(hum_close(dew_point(20.0, 50.0), 9.261106630534234, 1.0e-6))
  assert_true(hum_close(dew_point(30.0, 60.0), 21.390006900020516, 1.0e-6))
  assert_true(hum_close(dew_point(20.0, 100.0), 20.0, 1.0e-9))
  assert_true(
    hum_close(relative_humidity(20.0, 9.261106630534234), 50.0, 1.0e-6),
  )
  assert_true(hum_close(relative_humidity(20.0, 20.0), 100.0, 1.0e-9))
}

///|
/// Below freezing the vapour pressure over ice is the lower one, so the frost
/// point sits above the dew point: −10 °C air at 50 % humidity has a frost
/// point of −16.52 °C and a dew point of −18.47 °C.
test "a frost point sits above the dew point below freezing" {
  assert_true(hum_close(frost_point(-10.0, 50.0), -16.51913642576871, 1.0e-6))
  assert_true(hum_close(dew_point(-10.0, 50.0), -18.46844735651321, 1.0e-6))
  assert_true(frost_point(-10.0, 50.0) > dew_point(-10.0, 50.0))
}

///|
/// Stull's own worked example is 20 °C at 50 %, which his formula puts at
/// 13.7 °C, and the 18.8 °C of his table is what 20 °C at 90 % reads.
test "a wet-bulb temperature reads Stull's published values" {
  assert_true(
    hum_close(
      wet_bulb_temperature(20.0, 50.0).unwrap(),
      13.699341968988136,
      1.0e-6,
    ),
  )
  assert_true(
    hum_close(
      wet_bulb_temperature(20.0, 90.0).unwrap(),
      18.769743305036926,
      1.0e-6,
    ),
  )
  assert_true(
    hum_close(
      wet_bulb_temperature(30.0, 50.0).unwrap(),
      22.296833962680253,
      1.0e-6,
    ),
  )
}

///|
/// The fit is defined over 5 % to 99 % humidity and −20 °C to 50 °C, edges
/// included, and answers `None` in the extrapolation beyond them, saturated
/// air among it.
test "a wet-bulb temperature stops at the edge of the fit" {
  assert_true(
    hum_close(
      wet_bulb_temperature(-20.0, 50.0).unwrap(),
      -20.702520684799026,
      1.0e-6,
    ),
  )
  assert_true(
    hum_close(
      wet_bulb_temperature(50.0, 50.0).unwrap(),
      39.490746845261114,
      1.0e-6,
    ),
  )
  assert_true(
    hum_close(
      wet_bulb_temperature(20.0, 5.0).unwrap(),
      5.697600692207468,
      1.0e-6,
    ),
  )
  assert_true(
    hum_close(
      wet_bulb_temperature(20.0, 99.0).unwrap(),
      19.88596051900174,
      1.0e-6,
    ),
  )
  let outside : Array[(Double, Double)] = [
    (-20.1, 50.0),
    (50.1, 50.0),
    (20.0, 4.9),
    (20.0, 99.1),
    (20.0, 100.0),
  ]
  for pair in outside {
    let (celsius, relative_humidity) = pair
    assert_true(wet_bulb_temperature(celsius, relative_humidity) is None)
  }
}

///|
/// Saturated air at 20 °C holds 17.25 grams of water per cubic metre, half of
/// that at 50 % humidity and 18.17 at 30 °C and 60 %.
test "absolute humidity reads grams per cubic metre" {
  assert_true(
    hum_close(
      absolute_humidity(saturation_vapor_pressure(20.0), 20.0),
      17.247004916584626,
      1.0e-6,
    ),
  )
  assert_true(
    hum_close(
      absolute_humidity(0.5 * saturation_vapor_pressure(20.0), 20.0),
      8.623502458292313,
      1.0e-6,
    ),
  )
  assert_true(
    hum_close(
      absolute_humidity(0.6 * saturation_vapor_pressure(30.0), 30.0),
      18.16866939363141,
      1.0e-6,
    ),
  )
}

///|
/// A relative humidity is a percentage above zero and at most 100, so a
/// humidity of −1, of 0 or above 100 is refused rather than answered with a
/// dew point that does not exist.
test "a humidity that is not a percentage is refused" {
  let bad : Array[Double] = [-1.0, 0.0, 101.0]
  for relative_humidity in bad {
    let dew_failed = try {
      let _ = dew_point(20.0, relative_humidity)
      false
    } catch {
      HumidityError::BadRelativeHumidity(_) => true
      _ => false
    }
    assert_true(dew_failed)
    let frost_failed = try {
      let _ = frost_point(-10.0, relative_humidity)
      false
    } catch {
      HumidityError::BadRelativeHumidity(_) => true
      _ => false
    }
    assert_true(frost_failed)
  }
}

///|
/// A parcel whose dew point is above its own temperature is supersaturated,
/// and the error carries both temperatures.
test "a supersaturated parcel is refused" {
  let failed = try {
    let _ = relative_humidity(20.0, 25.0)
    false
  } catch {
    HumidityError::DewPointAboveTemperature(dew_point_celsius, celsius) => {
      assert_true(hum_close(dew_point_celsius, 25.0, 1.0e-9))
      assert_true(hum_close(celsius, 20.0, 1.0e-9))
      true
    }
    _ => false
  }
  assert_true(failed)
}
