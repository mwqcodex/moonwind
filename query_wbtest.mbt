///|
/// Whether two values agree to within `tolerance`.
fn near(actual : Double, expected : Double, tolerance : Double) -> Bool {
  (actual - expected).abs() <= tolerance
}

///|
/// The forecast for one station of the low-level sample.
fn station(id : String) -> StationWinds raise FdError {
  match parse_bulletin(fixture_fd1us1).station(id) {
    Some(found) => found
    None => abort("no \{id} in the low-level sample")
  }
}

///|
/// The forecast for one station of the high-level sample.
fn high_station(id : String) -> StationWinds raise FdError {
  match parse_bulletin(fixture_fd8us7).station(id) {
    Some(found) => found
    None => abort("no \{id} in the high-level sample")
  }
}

///|
/// A station reports the levels the bulletin fills in for it: `LOU` has all
/// nine columns, `ABI` has no 3,000 ft column, and `DEN`, high in the
/// Rockies, starts at 9,000 ft because the levels below it are under the
/// ground.
test "a station reports the levels the bulletin lists for it" {
  assert_eq(station("LOU").altitudes(), [
    3000, 6000, 9000, 12000, 18000, 24000, 30000, 34000, 39000,
  ])
  assert_eq(station("ABI").altitudes(), [
    6000, 9000, 12000, 18000, 24000, 30000, 34000, 39000,
  ])
  assert_eq(station("DEN").altitudes(), [
    9000, 12000, 18000, 24000, 30000, 34000, 39000,
  ])
  assert_eq(station("ABI").lowest_altitude(), Some(6000))
  assert_eq(station("DEN").lowest_altitude(), Some(9000))
  assert_eq(station("DEN").highest_altitude(), Some(39000))
  assert_eq(station("ABR").lowest_altitude(), Some(3000))
  assert_eq(station("ABR").highest_altitude(), Some(39000))
}

///|
/// A level the station does report is handed back as it was reported, with no
/// interpolation involved.
test "a reported level comes back as reported" {
  let ack = station("ACK")
  let wind = ack.vector_at(30000).unwrap()
  assert_true(near(wind.direction(), 260.0, 1.0e-9))
  assert_true(near(wind.speed(), 65.0, 1.0e-9))
  assert_true(near(ack.temperature_at(30000).unwrap(), -35.0, 1.0e-9))
}

///|
/// Between two levels the wind is interpolated as a vector, which is not the
/// average of the two winds: `LOU` turns from 70° at 13 kt at 3,000 ft to
/// 260° at 9 kt at 6,000 ft, nearly the opposite direction. Half way between
/// them the two almost cancel, leaving 2.2 kt from 49°, where averaging the
/// numbers alone would claim a wind that is not there at all.
test "the wind between two levels is interpolated as a vector" {
  let wind = station("LOU").vector_at(4500).unwrap()
  assert_true(near(wind.direction(), 49.303714784, 1.0e-6))
  assert_true(near(wind.speed(), 2.211050983, 1.0e-6))

  // The same two levels, half way, without going through the components:
  // a direction and a speed that the forecasts do not support.
  assert_eq((70 + 260) / 2, 165)
  assert_eq((13 + 9) / 2, 11)
}

///|
/// `ABR` reports 150° at 19 kt at 3,000 ft and 160° at 18 kt at 6,000 ft, so
/// 4,500 ft is 154.9° at 18.4 kt.
test "interpolating between neighbouring levels" {
  let wind = station("ABR").vector_at(4500).unwrap()
  assert_true(near(wind.direction(), 154.864521032, 1.0e-6))
  assert_true(near(wind.speed(), 18.429653436, 1.0e-6))
}

///|
/// A light and variable level carries no usable wind, so it contributes
/// nothing to an interpolated one: `ABI` reports light and variable at
/// 24,000 ft and 260° at 22 kt at 30,000 ft, so half way between them is half
/// of that wind, and `TVC` reports light and variable at 34,000 ft and 270° at
/// 20 kt at 39,000 ft, so 36,000 ft — four tenths of the way — is 8 kt.
test "a light and variable level contributes no wind" {
  let abi = station("ABI")
  let wind = abi.vector_at(27000).unwrap()
  assert_true(near(wind.direction(), 260.0, 1.0e-9))
  assert_true(near(wind.speed(), 11.0, 1.0e-9))
  assert_true(near(abi.temperature_at(27000).unwrap(), -24.5, 1.0e-9))
  // A reported light and variable level is still a level with no wind.
  assert_true(near(abi.vector_at(24000).unwrap().speed(), 0.0, 1.0e-12))
  assert_true(abi.vector_at(24000).unwrap().to_wind().is_light_and_variable())

  let tvc = station("TVC")
  let wind = tvc.vector_at(36000).unwrap()
  assert_true(near(wind.direction(), 270.0, 1.0e-9))
  assert_true(near(wind.speed(), 8.0, 1.0e-9))
  assert_true(near(tvc.temperature_at(36000).unwrap(), -51.6, 1.0e-9))
}

///|
/// Temperatures interpolate linearly between the levels that carry one, which
/// is a lapse rate. The 3,000 ft column never carries one, so an altitude
/// below the lowest temperature is not answered.
test "temperatures interpolate between the levels that carry one" {
  assert_true(near(station("ABR").temperature_at(7500).unwrap(), 4.5, 1.0e-9))
  assert_true(
    near(station("ABR").temperature_at(24000).unwrap(), -25.0, 1.0e-9),
  )
  assert_true(
    near(station("BGR").temperature_at(32000).unwrap(), -43.5, 1.0e-9),
  )
  assert_true(station("ABR").temperature_at(4500) is None)
  assert_true(station("ABR").temperature_at(3000) is None)
}

///|
/// Nothing is extrapolated past the levels the station reports.
test "the forecast stops at the levels that were forecast" {
  assert_true(station("ABR").vector_at(2000) is None)
  assert_true(station("ABR").vector_at(45000) is None)
  assert_true(station("ABR").temperature_at(40000) is None)
  // `ABI` does not report 3,000 ft at all, and 6,000 ft is its lowest level.
  assert_true(station("ABI").vector_at(3000) is None)
  // `DEN` reports nothing below 9,000 ft, so a low altitude is not answered
  // from the levels above it.
  assert_true(station("DEN").vector_at(6000) is None)
  assert_true(station("DEN").temperature_at(6000) is None)
}

///|
/// The high-level product forecasts two levels, 45,000 and 53,000 ft, and
/// interpolates between them the same way: `ABI` turns from 260° at 28 kt to
/// 250° at 17 kt, so 49,000 ft is 256.2° at 22.4 kt, at −68 °C.
test "the high level product interpolates between its two levels" {
  let abi = high_station("ABI")
  assert_eq(abi.altitudes(), [45000, 53000])
  let wind = abi.vector_at(49000).unwrap()
  assert_true(near(wind.direction(), 256.225147530, 1.0e-6))
  assert_true(near(wind.speed(), 22.419505909, 1.0e-6))
  assert_true(near(abi.temperature_at(49000).unwrap(), -68.0, 1.0e-9))
  assert_true(near(abi.temperature_at(45000).unwrap(), -63.0, 1.0e-9))
}

///|
/// A vector and a reported wind describe the same wind: a wind taken through
/// the components and back is the wind it started as, rounded to the nearest
/// degree and knot.
test "a reported wind survives a trip through its components" {
  let winds : Array[Wind] = [
    { direction: Some(70), speed: 13, },
    { direction: Some(150), speed: 19, },
    { direction: Some(260), speed: 65, },
    { direction: Some(340), speed: 115, },
    { direction: None, speed: 0, },
  ]
  for wind in winds {
    let round_tripped = WindVector::from_wind(wind).to_wind()
    assert_eq(round_tripped.direction, wind.direction)
    assert_eq(round_tripped.speed, wind.speed)
  }
  // A direction of 360° is the same wind as 0°.
  assert_eq(
    WindVector::from_wind({ direction: Some(360), speed: 100, }).to_wind().direction,
    Some(0),
  )
}

///|
/// An interpolated wind is rounded to the nearest degree and knot, and a wind
/// too weak to have a direction is reported as light and variable.
test "an interpolated wind is rounded to what a report can carry" {
  let wind = station("ABR").vector_at(4500).unwrap().to_wind()
  assert_eq(wind.direction, Some(155))
  assert_eq(wind.speed, 18)

  let calm = WindVector::from_components(0.1, 0.1).to_wind()
  assert_true(calm.is_light_and_variable())

  let light = WindVector::from_components(3.0, 4.0).to_wind()
  assert_eq(light.direction, Some(217))
  assert_eq(light.speed, 5)
}
