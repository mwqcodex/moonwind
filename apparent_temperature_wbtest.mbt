///|
/// Whether two values agree to within `tolerance`.
fn app_close(actual : Double, expected : Double, tolerance : Double) -> Bool {
  (actual - expected).abs() <= tolerance
}

///|
/// The National Weather Service chart: 0 °F in a 15 mph wind feels like
/// −19 °F, 30 °F in a 10 mph wind feels like 21, −20 °F in a 20 mph wind feels
/// like −48, and 0 °F in 5 mph feels like −11.
test "the wind chill follows the national weather service chart" {
  assert_true(
    app_close(
      wind_chill_fahrenheit(0.0, 15.0).unwrap(),
      -19.397954107996384,
      1.0e-6,
    ),
  )
  assert_true(
    app_close(
      wind_chill_fahrenheit(30.0, 10.0).unwrap(),
      21.248293255649617,
      1.0e-6,
    ),
  )
  assert_true(
    app_close(
      wind_chill_fahrenheit(-20.0, 20.0).unwrap(),
      -48.233227026763004,
      1.0e-6,
    ),
  )
  assert_true(
    app_close(
      wind_chill_fahrenheit(0.0, 5.0).unwrap(),
      -10.509947791689996,
      1.0e-6,
    ),
  )
}

///|
/// Environment Canada's chart: 0 °C in a 20 km/h wind feels like −5, −10 °C in
/// a 10 km/h wind feels like −15, and −20 °C in a 20 km/h wind feels like −30.
test "the metric wind chill follows the environment canada chart" {
  assert_true(
    app_close(
      wind_chill_celsius(0.0, 20.0).unwrap(),
      -5.242223279780932,
      1.0e-6,
    ),
  )
  assert_true(
    app_close(
      wind_chill_celsius(-10.0, 10.0).unwrap(),
      -15.2608188843888,
      1.0e-6,
    ),
  )
  assert_true(
    app_close(
      wind_chill_celsius(-20.0, 20.0).unwrap(),
      -30.478945408950928,
      1.0e-6,
    ),
  )
}

///|
/// The index stands behind a wind above 3 mph at or below 50 °F, and above
/// 4.8 km/h at or below 10 °C; outside that it answers `None` rather than
/// extrapolating.
test "a wind chill outside its range is not one" {
  let outside_fahrenheit : Array[(Double, Double)] = [
    (55.0, 15.0),
    (50.1, 15.0),
    (0.0, 3.0),
    (0.0, 2.0),
  ]
  for pair in outside_fahrenheit {
    let (fahrenheit, miles_per_hour) = pair
    assert_true(wind_chill_fahrenheit(fahrenheit, miles_per_hour) is None)
  }
  let outside_celsius : Array[(Double, Double)] = [
    (12.0, 20.0),
    (10.1, 20.0),
    (0.0, 4.8),
    (0.0, 4.0),
  ]
  for pair in outside_celsius {
    let (celsius, kilometers_per_hour) = pair
    assert_true(wind_chill_celsius(celsius, kilometers_per_hour) is None)
  }
}

///|
/// A wind out of the data model is in knots and the metric index is written in
/// kilometres per hour, so 270° at 10 kt is 18.52 km/h: at −5 °C that reads
/// −11.29 °C. A light and variable wind has no direction, and no chill.
test "a reported wind feeds the metric wind chill" {
  assert_true(
    app_close(
      wind_chill_from_wind(Wind::new(Some(270), 10), -5.0).unwrap(),
      -11.287771729907819,
      1.0e-6,
    ),
  )
  assert_true(
    app_close(
      wind_chill_from_wind(Wind::new(Some(270), 20), -10.0).unwrap(),
      -20.42698267731624,
      1.0e-6,
    ),
  )
  assert_true(wind_chill_from_wind(Wind::new(None, 0), -10.0) is None)
  assert_true(wind_chill_from_wind(Wind::new(Some(270), 2), 0.0) is None)
  assert_true(wind_chill_from_wind(Wind::new(Some(270), 10), 15.0) is None)
}

///|
/// The National Weather Service chart: 90 °F at 50 % humidity feels like 95,
/// 100 °F at 60 % feels like 129, and 96 °F at 65 % feels like 121. The two
/// corrections are read as well: 90 °F at 10 % is 85.28 after the dry-air
/// subtraction, and 85 °F at 95 % is 104.61 after the damp-air addition.
test "the heat index follows the rothfusz regression" {
  assert_true(
    app_close(
      heat_index_fahrenheit(90.0, 50.0).unwrap(),
      94.59694120000007,
      1.0e-6,
    ),
  )
  assert_true(
    app_close(
      heat_index_fahrenheit(100.0, 60.0).unwrap(),
      129.4890272000003,
      1.0e-6,
    ),
  )
  assert_true(
    app_close(
      heat_index_fahrenheit(96.0, 65.0).unwrap(),
      121.03162930000015,
      1.0e-6,
    ),
  )
  assert_true(
    app_close(
      heat_index_fahrenheit(90.0, 10.0).unwrap(),
      85.27896836218746,
      1.0e-6,
    ),
  )
  assert_true(
    app_close(
      heat_index_fahrenheit(85.0, 95.0).unwrap(),
      104.61231470000021,
      1.0e-6,
    ),
  )
}

///|
/// The regression is fitted from 80 °F to 112 °F. At 80 °F and 40 % it comes
/// out below 80 and the service's fallback is used, which reads 79.58 — the
/// chart prints that cell as 80. Below 80 °F the index would only repeat the
/// air temperature, and above 112 °F it is outside the fit, so both answer
/// `None`.
test "a heat index outside its range is not one" {
  assert_true(
    app_close(heat_index_fahrenheit(80.0, 40.0).unwrap(), 79.58, 1.0e-6),
  )
  let outside : Array[(Double, Double)] = [
    (70.0, 70.0),
    (79.9, 50.0),
    (113.0, 50.0),
  ]
  for pair in outside {
    let (fahrenheit, relative_humidity) = pair
    assert_true(heat_index_fahrenheit(fahrenheit, relative_humidity) is None)
  }
}

///|
/// 30 °C is 86 °F, which at 50 % humidity reads 87.89 °F, or 31.05 °C. The
/// range is the regression's, quoted in Fahrenheit, so 25 °C — 77 °F — is
/// outside it.
test "a heat index converts through fahrenheit" {
  assert_true(
    app_close(
      heat_index_celsius(30.0, 50.0).unwrap(),
      31.04908144444437,
      1.0e-6,
    ),
  )
  assert_true(heat_index_celsius(25.0, 50.0) is None)
}

///|
/// Environment Canada's own example: 30 °C with a dew point of 15 °C is a
/// humidex of 34. The vapour pressure comes from the humidity module, and a
/// dew point above the air temperature is refused there and here alike.
test "the humidex reads environment canada's example" {
  assert_true(app_close(humidex(30.0, 15.0), 33.8999045261977, 1.0e-6))
  assert_true(app_close(humidex(35.0, 20.0), 42.4080034616631, 1.0e-6))
}

///|
/// The Bureau of Meteorology's example: 30 °C at 80 % humidity in a 10 km/h
/// wind — 10/3.6 m/s — feels like 35.2 °C. The wind is what this index counts
/// as well as the humidity, so a windless 20 °C at 30 % reads 18.31.
test "the apparent temperature reads the bureau's example" {
  assert_true(
    app_close(
      apparent_temperature(30.0, 80.0, 10.0 / 3.6),
      35.24031221897561,
      1.0e-6,
    ),
  )
  assert_true(
    app_close(apparent_temperature(25.0, 50.0, 2.0), 24.81686445889954, 1.0e-6),
  )
  assert_true(
    app_close(apparent_temperature(20.0, 30.0, 0.0), 18.310106216868363, 1.0e-6),
  )
}

///|
/// A relative humidity outside 0 to 100 is refused wherever it is read, a
/// negative wind speed is refused wherever one is, and both errors carry the
/// offending value.
test "a percentage that is not one and a backward wind are refused" {
  let bad_humidity : Array[Double] = [-1.0, 101.0]
  for relative_humidity in bad_humidity {
    let heat_failed = try {
      let _ = heat_index_fahrenheit(90.0, relative_humidity)
      false
    } catch {
      ApparentTemperatureError::BadRelativeHumidity(_) => true
      _ => false
    }
    assert_true(heat_failed)
    let apparent_failed = try {
      let _ = apparent_temperature(30.0, relative_humidity, 1.0)
      false
    } catch {
      ApparentTemperatureError::BadRelativeHumidity(_) => true
      _ => false
    }
    assert_true(apparent_failed)
  }
  let wind_failed = try {
    let _ = apparent_temperature(30.0, 50.0, -1.0)
    false
  } catch {
    ApparentTemperatureError::BadWindSpeed(speed) =>
      app_close(speed, -1.0, 1.0e-9)
    _ => false
  }
  assert_true(wind_failed)
  let chill_failed = try {
    let _ = wind_chill_celsius(0.0, -1.0)
    false
  } catch {
    ApparentTemperatureError::BadWindSpeed(speed) =>
      app_close(speed, -1.0, 1.0e-9)
    _ => false
  }
  assert_true(chill_failed)
  let humidex_failed = try {
    let _ = humidex(20.0, 25.0)
    false
  } catch {
    HumidityError::DewPointAboveTemperature(dew_point, celsius) => {
      assert_true(app_close(dew_point, 25.0, 1.0e-9))
      assert_true(app_close(celsius, 20.0, 1.0e-9))
      true
    }
    _ => false
  }
  assert_true(humidex_failed)
}
