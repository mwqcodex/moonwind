///|
/// The knots table is closed at the bottom: force 1 begins at 1 kt, force 2 at
/// 4, force 4 at 11, and a hurricane at 64, which is where everything above it
/// stays.
test "the knots table reads the scale's own bounds" {
  let cases : Array[(Double, Int)] = [
    (0.0, 0),
    (0.5, 0),
    (1.0, 1),
    (3.9, 1),
    (4.0, 2),
    (11.0, 4),
    (16.9, 4),
    (17.0, 5),
    (63.9, 11),
    (64.0, 12),
    (150.0, 12),
  ]
  for case in cases {
    let (knots, force) = case
    assert_eq(Beaufort::from_knots(knots).force(), force)
  }
}

///|
/// The metres-per-second table: 0.3 m/s is force 1, 1.6 force 2, 3.4 force 3,
/// and 32.7 a hurricane. Below 0.3 it is calm.
test "the metres-per-second table reads its own bounds" {
  let cases : Array[(Double, Int)] = [
    (0.0, 0),
    (0.2, 0),
    (0.3, 1),
    (1.5, 1),
    (1.6, 2),
    (3.3, 2),
    (3.4, 3),
    (32.6, 11),
    (32.7, 12),
    (40.0, 12),
  ]
  for case in cases {
    let (meters_per_second, force) = case
    assert_eq(
      Beaufort::from_meters_per_second(meters_per_second).force(),
      force,
    )
  }
}

///|
/// The kilometres-per-hour table: 1 km/h is force 1, 6 force 2, 12 force 3, and
/// 118 a hurricane.
test "the kilometres-per-hour table reads its own bounds" {
  let cases : Array[(Double, Int)] = [
    (0.0, 0),
    (0.9, 0),
    (1.0, 1),
    (5.9, 1),
    (6.0, 2),
    (11.9, 2),
    (12.0, 3),
    (117.9, 11),
    (118.0, 12),
  ]
  for case in cases {
    let (kilometers_per_hour, force) = case
    assert_eq(
      Beaufort::from_kilometers_per_hour(kilometers_per_hour).force(),
      force,
    )
  }
}

///|
/// The tables were rounded independently and disagree at their edges: 3.4 m/s
/// is 6.61 kt, which the metres-per-second table calls force 3 and the knots
/// table force 2. Each constructor answers in its own table's numbers.
test "the tables disagree at their edges" {
  assert_eq(Beaufort::from_meters_per_second(3.4).force(), 3)
  assert_eq(Beaufort::from_knots(meters_per_second_to_knots(3.4)).force(), 2)
  assert_true(meters_per_second_to_knots(3.4) > 4.0)
  assert_true(meters_per_second_to_knots(3.4) < 7.0)
}

///|
/// Every force from 0 to 12 has its own name and its own band, and the band a
/// force begins at is the one the table has for it: force 4 begins at 11 kt and
/// ends where force 5 begins, at 17. A hurricane has no force above it and no
/// upper bound.
test "every force has a description and a band" {
  let bounds : Array[Double] = [
    0.0, 1.0, 4.0, 7.0, 11.0, 17.0, 22.0, 28.0, 34.0, 41.0, 48.0, 56.0, 64.0,
  ]
  let descriptions : Array[String] = [
    "Calm", "Light air", "Light breeze", "Gentle breeze", "Moderate breeze", "Fresh breeze",
    "Strong breeze", "Near gale", "Gale", "Strong gale", "Storm", "Violent storm",
    "Hurricane",
  ]
  for index = 0; index < bounds.length(); index = index + 1 {
    let beaufort = Beaufort::from_knots(bounds[index])
    assert_eq(beaufort.force(), index)
    assert_eq(beaufort.description(), descriptions[index])
    assert_true(beaufort.lower_bound_knots() == bounds[index])
    let upper = if index + 1 < bounds.length() {
      Some(bounds[index + 1])
    } else {
      None
    }
    assert_true(beaufort.upper_bound_knots() == upper)
  }
  assert_eq(Beaufort::from_knots(11.0).description(), "Moderate breeze")
  assert_true(Beaufort::from_knots(64.0).upper_bound_knots() is None)
}

///|
/// A reported wind is read on the scale in the knots it is kept in: 150° at
/// 14 kt is a moderate breeze from 11 kt up to 17, and a light and variable
/// wind is calm.
test "a reported wind is read on the scale" {
  let breeze = Beaufort::from_wind(Wind::new(Some(150), 14))
  assert_eq(breeze.force(), 4)
  assert_eq(breeze.description(), "Moderate breeze")
  assert_true(breeze.lower_bound_knots() == 11.0)
  assert_true(breeze.upper_bound_knots() == Some(17.0))
  let calm = Beaufort::from_wind(Wind::new(None, 0))
  assert_eq(calm.force(), 0)
  assert_eq(calm.description(), "Calm")
  assert_eq(Beaufort::from_wind(Wind::new(Some(270), 120)).force(), 12)
}

///|
/// A wind does not blow backwards: a negative speed is refused by every
/// constructor, and the error carries the offending speed.
test "a negative wind speed is refused" {
  let speeds : Array[Double] = [-1.0, -0.5]
  for speed in speeds {
    let from_knots_failed = try {
      let _ = Beaufort::from_knots(speed)
      false
    } catch {
      BeaufortError::BadWindSpeed(refused) => refused == speed
    }
    assert_true(from_knots_failed)
    let from_metric_failed = try {
      let _ = Beaufort::from_meters_per_second(speed)
      false
    } catch {
      BeaufortError::BadWindSpeed(refused) => refused == speed
    }
    assert_true(from_metric_failed)
    let from_hourly_failed = try {
      let _ = Beaufort::from_kilometers_per_hour(speed)
      false
    } catch {
      BeaufortError::BadWindSpeed(refused) => refused == speed
    }
    assert_true(from_hourly_failed)
  }
  let from_wind_failed = try {
    let _ = Beaufort::from_wind(Wind::new(Some(270), -5))
    false
  } catch {
    BeaufortError::BadWindSpeed(refused) => refused == -5.0
  }
  assert_true(from_wind_failed)
}
