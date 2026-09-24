///|
/// Whether two values agree to within `tolerance`.
fn pres_close(actual : Double, expected : Double, tolerance : Double) -> Bool {
  (actual - expected).abs() <= tolerance
}

///|
/// The standard sea level pressure is 1013.25 hPa, which is 29.92126 inches of
/// mercury and 760.00 millimetres — the millimetre being the unit the 760 is
/// defined from, so it comes back a ten-thousandth of a millimetre short.
test "a pressure converts between its units" {
  assert_true(
    pres_close(
      hectopascals_to_inches_of_mercury(1013.25),
      29.921255579748475,
      1.0e-6,
    ),
  )
  assert_true(
    pres_close(
      inches_of_mercury_to_hectopascals(29.92),
      1013.2074811900272,
      1.0e-6,
    ),
  )
  assert_true(
    pres_close(
      hectopascals_to_millimeters_of_mercury(1013.25),
      759.9998917256113,
      1.0e-6,
    ),
  )
  assert_true(
    pres_close(
      millimeters_of_mercury_to_hectopascals(760.0),
      1013.250144354,
      1.0e-6,
    ),
  )
}

///|
/// A station at sea level reduces to itself, and one at 500 m reporting
/// 955 hPa in 20 °C air reduces to 1011.98, the classic reduction of a station
/// a few hundred metres up. Its inverse takes that back to 955.02, and the two
/// together are a round trip.
test "a station is reduced to sea level" {
  assert_true(
    pres_close(mean_sea_level_pressure(1013.25, 0.0, 20.0), 1013.25, 1.0e-9),
  )
  assert_true(
    pres_close(
      mean_sea_level_pressure(955.0, 500.0, 20.0),
      1011.9757408856466,
      1.0e-6,
    ),
  )
  assert_true(
    pres_close(station_pressure(1012.0, 500.0, 20.0), 955.0228932900973, 1.0e-6),
  )
  assert_true(
    pres_close(
      mean_sea_level_pressure(
        station_pressure(1012.0, 500.0, 20.0),
        500.0,
        20.0,
      ),
      1012.0,
      1.0e-9,
    ),
  )
}

///|
/// A station standing in the standard atmosphere has the standard sea level
/// pressure as its altimeter setting: at 500 m that is 954.61 hPa, and the
/// reduction gives back 1013.25 hPa, or 29.92126 inHg. At sea level the
/// setting is the pressure itself.
test "a station in the standard atmosphere reduces to itself" {
  assert_true(
    pres_close(
      altimeter_setting_hpa(954.6083513373975, 500.0),
      1013.2499999999997,
      1.0e-6,
    ),
  )
  assert_true(pres_close(altimeter_setting_hpa(1013.25, 0.0), 1013.25, 1.0e-9))
  assert_true(
    pres_close(
      altimeter_setting_inhg(954.6083513373975, 500.0),
      29.921255579748465,
      1.0e-6,
    ),
  )
}

///|
/// The reduction is written for the troposphere, which would reach absolute
/// zero at 44330.77 m. An elevation there or above is refused, and the error
/// carries it.
test "an elevation above the standard atmosphere is refused" {
  let too_high : Array[Double] = [44330.77, 50000.0]
  for elevation_meters in too_high {
    let failed = try {
      let _ = altimeter_setting_hpa(1013.25, elevation_meters)
      false
    } catch {
      PressureError::ElevationTooHigh(elevation) =>
        pres_close(elevation, elevation_meters, 1.0e-9)
    }
    assert_true(failed)
  }
  let failed = try {
    let _ = altimeter_setting_inhg(1013.25, 44330.77)
    false
  } catch {
    PressureError::ElevationTooHigh(_) => true
  }
  assert_true(failed)
}

///|
/// The standard sea level pressure reads as sea level, and the levels a
/// forecast is written at read as the altitudes they are quoted at: 1000 hPa
/// at 364 ft, 850 hPa at 4,781, 700 hPa at 9,882.
test "a pressure reads as an altitude" {
  assert_true(pres_close(pressure_altitude(1013.25), 0.0, 1.0e-9))
  assert_true(pres_close(pressure_altitude(1000.0), 363.7940525527356, 1.0e-6))
  assert_true(pres_close(pressure_altitude(850.0), 4781.166134593796, 1.0e-6))
  assert_true(pres_close(pressure_altitude(700.0), 9882.4818912625, 1.0e-6))
}

///|
/// The 120 ft per degree rule: standard air at sea level reads 0 ft, a 25 °C
/// day at sea level reads 1,200, and a 30 °C day under 1000 hPa reads 2,250.
/// At 850 hPa on a 20 °C day it reads 6,518 ft.
test "a density altitude counts the heat" {
  assert_true(pres_close(density_altitude(1013.25, 15.0), 0.0, 1.0e-9))
  assert_true(pres_close(density_altitude(1013.25, 25.0), 1200.0, 1.0e-9))
  assert_true(
    pres_close(density_altitude(1000.0, 30.0), 2250.2839057828332, 1.0e-6),
  )
  assert_true(
    pres_close(density_altitude(850.0, 20.0), 6517.859696096664, 1.0e-6),
  )
}

///|
/// The water in the air raises the density altitude above what the rule of
/// thumb gives: 218 ft on a saturated 15 °C day at sea level, 109 ft at 50 %
/// humidity, where the dew point is 4.66 °C and the answer is the rule's own
/// 0 ft plus the vapour. A damp 30 °C day under 1000 hPa, with a dew point of
/// 21.39 °C, reads 2,492 ft.
test "the water in the air raises the density altitude" {
  assert_true(
    pres_close(
      density_altitude_with_dew_point(1013.25, 15.0, 15.0),
      217.51477051018503,
      1.0e-6,
    ),
  )
  assert_true(
    pres_close(
      density_altitude_with_dew_point(1013.25, 15.0, dew_point(15.0, 50.0)),
      108.62489318640728,
      1.0e-6,
    ),
  )
  assert_true(
    pres_close(
      density_altitude_with_dew_point(1000.0, 30.0, dew_point(30.0, 60.0)),
      2492.427209575927,
      1.0e-6,
    ),
  )
  // Dry air is where the exact form and the rule of thumb meet: with the
  // vapour taken out of that 25 °C day at sea level, the rule says 1,200 ft
  // and the density says 1,162.
  assert_true(
    pres_close(
      density_altitude_with_dew_point(1013.25, 25.0, -50.0),
      1162.0219666091155,
      1.0e-6,
    ),
  )
  assert_true(
    density_altitude_with_dew_point(1013.25, 25.0, -50.0) <
    density_altitude(1013.25, 25.0),
  )
}

///|
/// A dew point above the air temperature would make the air supersaturated and
/// is refused, as it is by `relative_humidity`, and the error carries both
/// temperatures.
test "a supersaturated pair is refused" {
  let failed = try {
    let _ = density_altitude_with_dew_point(1013.25, 20.0, 25.0)
    false
  } catch {
    HumidityError::DewPointAboveTemperature(dew_point_celsius, celsius) => {
      assert_true(pres_close(dew_point_celsius, 25.0, 1.0e-9))
      assert_true(pres_close(celsius, 20.0, 1.0e-9))
      true
    }
    _ => false
  }
  assert_true(failed)
}
