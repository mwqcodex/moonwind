///|
/// Whether two values agree to within `tolerance`.
fn triangle_close(
  actual : Double,
  expected : Double,
  tolerance : Double,
) -> Bool {
  (actual - expected).abs() <= tolerance
}

///|
/// The wind as a vector, from its reported direction and speed.
fn vector(direction : Int, speed : Int) -> WindVector {
  WindVector::from_wind({ direction: Some(direction), speed, })
}

///|
/// A tailwind adds itself to the airspeed and nothing else moves: 100 kt
/// through a 20 kt tailwind is 120 kt over the ground, straight down the
/// course.
test "a tailwind adds itself to the ground speed" {
  let triangle = WindTriangle::solve(90.0, 100.0, vector(270, 20))
  assert_true(triangle_close(triangle.wind_correction_angle(), 0.0, 1.0e-9))
  assert_true(triangle_close(triangle.heading(), 90.0, 1.0e-9))
  assert_true(triangle_close(triangle.ground_speed(), 120.0, 1.0e-9))
  assert_true(triangle_close(triangle.headwind(), -20.0, 1.0e-9))
  assert_true(triangle_close(triangle.crosswind(), 0.0, 1.0e-9))
}

///|
/// A pure crosswind costs airspeed without giving anything back: 100 kt
/// against a 20 kt left crosswind steers 11.5 degrees left of course and
/// makes 97.98 kt over the ground, all of it the remaining along-track
/// airspeed.
test "a crosswind is corrected by a wind correction angle" {
  let triangle = WindTriangle::solve(90.0, 100.0, vector(0, 20))
  assert_true(
    triangle_close(triangle.wind_correction_angle(), -11.536959033, 1.0e-6),
  )
  assert_true(triangle_close(triangle.heading(), 78.463040967, 1.0e-6))
  assert_true(triangle_close(triangle.ground_speed(), 97.979589711, 1.0e-6))
  assert_true(triangle_close(triangle.headwind(), 0.0, 1.0e-9))
  assert_true(triangle_close(triangle.crosswind(), -20.0, 1.0e-9))
}

///|
/// The correction angle grows with the crosswind and shrinks with the
/// airspeed: 30 kt across a 90 kt aircraft is 19.47 degrees.
test "the correction angle follows the sine of the crosswind" {
  let triangle = WindTriangle::solve(0.0, 90.0, vector(270, 30))
  assert_true(
    triangle_close(triangle.wind_correction_angle(), -19.471220634, 1.0e-6),
  )
  assert_true(triangle_close(triangle.heading(), 340.528779366, 1.0e-6))
  assert_true(triangle_close(triangle.ground_speed(), 84.852813742, 1.0e-6))
  assert_true(triangle_close(triangle.crosswind(), -30.0, 1.0e-9))
}

///|
/// A diagonal wind resolves into its two components: on a course of 045 a
/// 315-degree wind has 10 kt across the track from the left and nothing
/// along it.
test "a diagonal wind resolves into its components" {
  let triangle = WindTriangle::solve(45.0, 100.0, vector(315, 10))
  assert_true(
    triangle_close(triangle.wind_correction_angle(), -5.739170477, 1.0e-6),
  )
  assert_true(triangle_close(triangle.heading(), 39.260829523, 1.0e-6))
  assert_true(triangle_close(triangle.ground_speed(), 99.498743711, 1.0e-6))
  assert_true(triangle_close(triangle.headwind(), 0.0, 1.0e-9))
  assert_true(triangle_close(triangle.crosswind(), -10.0, 1.0e-9))

  // The same wind over the tail of the same course pushes straight ahead.
  let tail = WindTriangle::solve(45.0, 100.0, vector(225, 10))
  assert_true(triangle_close(tail.wind_correction_angle(), 0.0, 1.0e-9))
  assert_true(triangle_close(tail.ground_speed(), 110.0, 1.0e-9))
  assert_true(triangle_close(tail.headwind(), -10.0, 1.0e-9))
}

///|
/// Headings stay in `[0, 360)`: a course near north with a right crosswind
/// wraps past 360, and one with a left crosswind wraps below 0.
test "the heading wraps around north" {
  let right = WindTriangle::solve(350.0, 100.0, vector(100, 30))
  assert_true(
    triangle_close(right.wind_correction_angle(), 16.374100405, 1.0e-6),
  )
  assert_true(triangle_close(right.heading(), 6.374100405, 1.0e-6))

  let left = WindTriangle::solve(10.0, 100.0, vector(280, 30))
  assert_true(
    triangle_close(left.wind_correction_angle(), -17.457603124, 1.0e-6),
  )
  assert_true(triangle_close(left.heading(), 352.542396876, 1.0e-6))
  assert_true(triangle_close(left.ground_speed(), 95.393920142, 1.0e-6))
}

///|
/// A light and variable wind is no wind at all: the triangle solves to the
/// course and airspeed themselves.
test "no wind is an exact pass-through" {
  let triangle = WindTriangle::solve(
    123.0,
    87.0,
    WindVector::from_components(0.0, 0.0),
  )
  assert_true(triangle_close(triangle.wind_correction_angle(), 0.0, 1.0e-9))
  assert_true(triangle_close(triangle.heading(), 123.0, 1.0e-9))
  assert_true(triangle_close(triangle.ground_speed(), 87.0, 1.0e-9))
  assert_true(triangle_close(triangle.headwind(), 0.0, 1.0e-9))
  assert_true(triangle_close(triangle.crosswind(), 0.0, 1.0e-9))
}

///|
/// An interpolated station wind plugs straight into the triangle: `ABR` at
/// 4,500 ft has 16.68 kt from the right of a course of 090, which costs a
/// 7.99 degree correction to the right and leaves 111.01 kt of ground speed.
test "an interpolated station wind feeds the triangle" {
  let bulletin = parse_bulletin(fixture_fd1us1)
  let abr = match bulletin.station("ABR") {
    Some(station) => station
    None => abort("no ABR in the sample")
  }
  let wind = match abr.vector_at(4500) {
    Some(found) => found
    None => abort("no wind at 4,500 ft for ABR")
  }
  let triangle = WindTriangle::solve(90.0, 120.0, wind)
  assert_true(
    triangle_close(triangle.wind_correction_angle(), 7.992142268, 1.0e-6),
  )
  assert_true(triangle_close(triangle.heading(), 97.992142268, 1.0e-6))
  assert_true(triangle_close(triangle.ground_speed(), 111.006276240, 1.0e-6))
  assert_true(triangle_close(triangle.headwind(), 7.828181290, 1.0e-6))
  assert_true(triangle_close(triangle.crosswind(), 16.684474923, 1.0e-6))
}

///|
/// A crosswind as strong as the airspeed is the limit: the aircraft flies
/// sideways at 90 degrees to its course, making no ground speed along it.
test "a crosswind equal to the airspeed is flyable, at a 90-degree angle" {
  let triangle = WindTriangle::solve(90.0, 50.0, vector(0, 50))
  assert_true(triangle_close(triangle.wind_correction_angle(), -90.0, 1.0e-6))
  assert_true(triangle_close(triangle.heading(), 0.0, 1.0e-6))
  assert_true(triangle_close(triangle.ground_speed(), 0.0, 1.0e-9))
}

///|
/// A crosswind stronger than the airspeed cannot be corrected, a non-positive
/// airspeed is not an airspeed, and both are reported rather than answered.
test "an unflyable triangle is refused" {
  let failed = try {
    let _ = WindTriangle::solve(90.0, 50.0, vector(0, 60))
    false
  } catch {
    FlightError::CrosswindExceedsAirspeed(crosswind, airspeed) => {
      assert_true(triangle_close(crosswind, -60.0, 1.0e-9))
      assert_true(triangle_close(airspeed, 50.0, 1.0e-9))
      true
    }
    _ => false
  }
  assert_true(failed)

  let failed_airspeed = try {
    let _ = WindTriangle::solve(90.0, 0.0, vector(0, 20))
    false
  } catch {
    FlightError::BadAirspeed(0.0) => true
    _ => false
  }
  assert_true(failed_airspeed)
}
