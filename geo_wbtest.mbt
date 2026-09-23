///|
/// Whether two values agree to within `tolerance`.
fn geo_close(actual : Double, expected : Double, tolerance : Double) -> Bool {
  (actual - expected).abs() <= tolerance
}

///|
/// A position from its latitude and longitude.
fn coord(latitude : Double, longitude : Double) -> Coordinate {
  Coordinate::new(latitude, longitude)
}

///|
/// The distance between two positions is the great-circle distance, and the
/// two positions are the ends of a path a quarter of the way round the world
/// at 5,403 nm apart: the equator is 21,614 nm round.
test "the distance between two positions is a great circle" {
  let new_york = coord(40.0, -74.0)
  let london = coord(51.5, -0.1)
  assert_true(geo_close(new_york.distance_to(london), 3035.533833400, 1.0e-6))
  assert_true(
    geo_close(
      coord(0.0, 0.0).distance_to(coord(0.0, 90.0)),
      5403.641465936,
      1.0e-6,
    ),
  )
  assert_true(
    geo_close(
      coord(0.0, 0.0).distance_to(coord(90.0, 0.0)),
      5403.641465936,
      1.0e-6,
    ),
  )

  // The date line is not a wall: the short way across it is 20 degrees.
  assert_true(
    geo_close(
      coord(0.0, -170.0).distance_to(coord(0.0, 170.0)),
      1200.809214652,
      1.0e-6,
    ),
  )

  // A position is no distance from itself.
  assert_true(geo_close(london.distance_to(london), 0.0, 1.0e-12))
}

///|
/// The course is the direction the path leaves in, clockwise from north.
test "the initial course is the way the path leaves" {
  assert_true(
    geo_close(
      coord(40.0, -74.0).initial_course_to(coord(51.5, -0.1)),
      50.756940807,
      1.0e-6,
    ),
  )

  // Down the Pacific coast, a little west of south.
  assert_true(
    geo_close(
      coord(47.45, -122.31).initial_course_to(coord(37.62, -122.38)),
      180.324760614,
      1.0e-6,
    ),
  )

  // East along the equator, and north from it to the pole.
  assert_true(
    geo_close(coord(0.0, 0.0).initial_course_to(coord(0.0, 90.0)), 90.0, 1.0e-9),
  )
  assert_true(
    geo_close(coord(0.0, 0.0).initial_course_to(coord(90.0, 0.0)), 0.0, 1.0e-9),
  )
  assert_true(
    geo_close(
      coord(-33.94, 151.18).initial_course_to(coord(51.5, -0.1)),
      319.028417317,
      1.0e-6,
    ),
  )

  // Across the date line: the short way is west, so the course is 270 rather
  // than 90.
  assert_true(
    geo_close(
      coord(0.0, -170.0).initial_course_to(coord(0.0, 170.0)),
      270.0,
      1.0e-9,
    ),
  )
}

///|
/// A great circle is not a straight line: cut into eight equal legs, the
/// course changes from 051 to 100 as it is flown, each leg is 379.44 nm, and
/// the eight legs add up to the 3,035.53 nm of the whole path — the same
/// distance the direct calculation gives.
test "a great circle drifts off any single heading" {
  let new_york = coord(40.0, -74.0)
  let london = coord(51.5, -0.1)
  let route = Route::new([new_york, london])
  let legs = route.subdivided(8).segments()
  assert_eq(legs.length(), 8)
  let mut total = 0.0
  for leg in legs {
    assert_true(geo_close(leg.distance(), 379.441729175, 1.0e-6))
    total += leg.distance()
  }
  assert_true(geo_close(total, new_york.distance_to(london), 1.0e-6))
  assert_true(geo_close(legs[0].true_course(), 50.756940807, 1.0e-6))
  assert_true(geo_close(legs[3].true_course(), 67.192789937, 1.0e-6))
  assert_true(geo_close(legs[7].true_course(), 99.684242383, 1.0e-6))

  // The far end of the last leg is London, where the path arrives on the
  // reciprocal bearing of the course that would leave it: 108 degrees.
  assert_true(
    geo_close(
      normalize_degrees(london.initial_course_to(legs[7].from()) + 180.0),
      107.629578330,
      1.0e-6,
    ),
  )
}

///|
/// Interpolation walks the great circle: a quarter of the way from New York
/// to London is over the Atlantic at 47.16 north, half way is the path's own
/// middle, and the ends of the path are the positions themselves.
test "interpolation walks the path" {
  let new_york = coord(40.0, -74.0)
  let london = coord(51.5, -0.1)
  let quarter = new_york.interpolate(london, 0.25)
  assert_true(geo_close(quarter.latitude(), 47.159606879, 1.0e-6))
  assert_true(geo_close(quarter.longitude(), -59.567988484, 1.0e-6))

  let middle = new_york.midpoint(london)
  assert_true(geo_close(middle.latitude(), 52.015248259, 1.0e-6))
  assert_true(geo_close(middle.longitude(), -41.495833620, 1.0e-6))
  assert_true(
    geo_close(new_york.distance_to(middle), middle.distance_to(london), 1.0e-9),
  )

  // Half way along the equator to 90 east is 45 east; half way from the
  // equator to the pole is 45 north.
  let east = coord(0.0, 0.0).midpoint(coord(0.0, 90.0))
  assert_true(geo_close(east.latitude(), 0.0, 1.0e-9))
  assert_true(geo_close(east.longitude(), 45.0, 1.0e-9))
  assert_true(
    geo_close(
      coord(0.0, 0.0).midpoint(coord(90.0, 0.0)).latitude(),
      45.0,
      1.0e-9,
    ),
  )

  assert_true(
    geo_close(new_york.interpolate(london, 0.0).latitude(), 40.0, 1.0e-9),
  )
  assert_true(
    geo_close(new_york.interpolate(london, 1.0).longitude(), -0.1, 1.0e-9),
  )
  assert_true(
    geo_close(new_york.interpolate(london, 1.0).latitude(), 51.5, 1.0e-9),
  )

  // A position is its own path, and half way along it is where it started.
  let stayed = new_york.interpolate(new_york, 0.5)
  assert_true(geo_close(stayed.latitude(), 40.0, 1.0e-12))
  assert_true(geo_close(stayed.longitude(), -74.0, 1.0e-12))
}
