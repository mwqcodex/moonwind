///|
/// A route of three waypoints over the plains, about 105 nm a hop.
fn plains() -> Route {
  Route::new([coord(45.0, -98.0), coord(44.0, -96.0), coord(43.0, -94.0)])
}

///|
/// A route is the hops between its waypoints, in order, each with its own
/// distance and course; a route with one waypoint has no hops at all.
test "a route is the hops between its waypoints" {
  let route = plains()
  let segments = route.segments()
  assert_eq(segments.length(), 2)
  assert_true(geo_close(segments[0].distance(), 104.591137317, 1.0e-6))
  assert_true(geo_close(segments[1].distance(), 105.786672481, 1.0e-6))
  assert_true(geo_close(route.distance(), 210.377809797, 1.0e-6))
  assert_true(geo_close(segments[0].true_course(), 124.327022955, 1.0e-6))
  assert_true(geo_close(segments[1].true_course(), 123.886990013, 1.0e-6))
  assert_true(
    geo_close(segments[0].midpoint().latitude(), 44.504362565, 1.0e-6),
  )
  assert_true(
    geo_close(segments[0].midpoint().longitude(), -96.991423260, 1.0e-6),
  )

  // The first hop starts where the route does and ends where the next begins.
  assert_true(geo_close(segments[0].from().latitude(), 45.0, 1.0e-12))
  assert_true(geo_close(segments[1].from().longitude(), -96.0, 1.0e-12))
  assert_true(geo_close(segments[1].to().latitude(), 43.0, 1.0e-12))

  let single = Route::new([coord(45.0, -98.0)])
  assert_eq(single.segments().length(), 0)
  assert_true(geo_close(single.distance(), 0.0, 1.0e-12))
}

///|
/// Dividing a route into shorter hops keeps the route: the same line over the
/// ground, the same length, the same ends.
test "dividing a route keeps the route" {
  let route = plains()
  let cut = route.subdivided(2)
  assert_eq(cut.points().length(), 5)
  assert_true(geo_close(cut.distance(), route.distance(), 1.0e-6))
  assert_true(geo_close(cut.points()[0].latitude(), 45.0, 1.0e-12))
  assert_true(geo_close(cut.points()[4].latitude(), 43.0, 1.0e-12))

  // A count below one leaves it as it is, and one waypoint stays one.
  assert_eq(route.subdivided(1).points().length(), 3)
  assert_eq(route.subdivided(0).points().length(), 3)
  assert_eq(Route::new([coord(45.0, -98.0)]).subdivided(4).points().length(), 1)
}

///|
/// A leg is timed against the station's forecast: at 12,000 ft `ABR` reports
/// 150 degrees at 14 kt, which is 6.07 kt across the first hop from the right
/// and 12.62 kt behind it, so the leg is flown on 127 at 107.23 kt of ground
/// speed, in 0.98 hours. The two hops add up to 210.38 nm in 1.96 hours.
test "a leg is timed against the station's forecast" {
  let plan = plains().plan(station("ABR"), 12000, 120.0)
  assert_eq(plan.source(), Some("ABR"))
  assert_eq(plan.altitude(), 12000)
  assert_true(geo_close(plan.airspeed(), 120.0, 1.0e-12))
  let legs = plan.legs()
  assert_eq(legs.length(), 2)

  let first = legs[0]
  assert_true(geo_close(first.wind().speed(), 14.0, 1.0e-9))
  assert_true(geo_close(first.true_course(), 124.327022955, 1.0e-6))
  assert_true(geo_close(first.heading(), 127.224213745, 1.0e-6))
  assert_true(geo_close(first.ground_speed(), 107.228680060, 1.0e-6))
  assert_true(geo_close(first.headwind(), 12.617940326, 1.0e-6))
  assert_true(geo_close(first.crosswind(), 6.065276739, 1.0e-6))
  assert_true(geo_close(first.time_hours(), 0.975402637, 1.0e-6))
  assert_true(
    geo_close(
      first.distance() / first.ground_speed(),
      first.time_hours(),
      1.0e-12,
    ),
  )

  assert_true(geo_close(legs[1].ground_speed(), 107.270698869, 1.0e-6))
  assert_true(geo_close(legs[1].time_hours(), 0.986165594, 1.0e-6))
  assert_true(geo_close(plan.total_distance(), 210.377809797, 1.0e-6))
  assert_true(geo_close(plan.total_time_hours(), 1.961568231, 1.0e-6))
}

///|
/// A plan can be made against any wind the caller can answer for: each leg
/// reads the wind over its own middle, so a forecast that changes over the
/// route is used where the leg actually is. Here everything north of 44
/// degrees has a wind from the east and everything south of it a wind from
/// the south, and the two legs are flown on headings eight degrees apart.
test "each leg is planned with the wind over its own middle" {
  let plan = plains().plan_with(
    fn(position, _altitude) {
      if position.latitude() > 44.0 {
        Some(vector(90, 20))
      } else {
        Some(vector(180, 20))
      }
    },
    12000,
    120.0,
  )
  assert_eq(plan.source(), None)
  let legs = plan.legs()
  assert_true(
    geo_close(legs[0].segment().midpoint().latitude(), 44.504362565, 1.0e-6),
  )
  assert_true(
    geo_close(legs[1].segment().midpoint().latitude(), 43.504357283, 1.0e-6),
  )
  assert_true(geo_close(legs[0].wind().speed(), 20.0, 1.0e-9))
  assert_true(geo_close(legs[0].heading(), 118.934065963, 1.0e-6))
  assert_true(geo_close(legs[0].ground_speed(), 102.952174597, 1.0e-6))
  assert_true(geo_close(legs[0].time_hours(), 1.015919651, 1.0e-6))
  assert_true(geo_close(legs[1].heading(), 131.839744272, 1.0e-6))
  assert_true(geo_close(legs[1].ground_speed(), 107.694766677, 1.0e-6))
  assert_true(geo_close(plan.total_time_hours(), 1.998202038, 1.0e-6))
}

///|
/// The course of a long hop drifts, so a long hop planned as one leg and as
/// eight legs gives the same distance but not the same time: with a 40 kt
/// westerly behind it, New York to London is planned four minutes faster when
/// each leg is flown on its own course, which is the one it will actually
/// hold.
test "a long hop is planned in shorter legs" {
  let new_york = coord(40.0, -74.0)
  let london = coord(51.5, -0.1)
  let course = Route::new([new_york, london])
  let westerly = fn(_position, _altitude) { Some(vector(270, 40)) }
  let direct = course.plan_with(westerly, 35000, 480.0)
  let legs = course.subdivided(8).plan_with(westerly, 35000, 480.0)
  assert_eq(legs.legs().length(), 8)
  assert_true(geo_close(direct.total_distance(), 3035.533833400, 1.0e-6))
  assert_true(geo_close(legs.total_distance(), direct.total_distance(), 1.0e-6))
  assert_true(geo_close(direct.legs()[0].true_course(), 50.756940807, 1.0e-6))
  assert_true(geo_close(legs.legs()[7].true_course(), 99.684242383, 1.0e-6))
  assert_true(geo_close(direct.total_time_hours(), 5.948396133, 1.0e-6))
  assert_true(geo_close(legs.total_time_hours(), 5.878460490, 1.0e-6))
  assert_true(direct.total_time_hours() > legs.total_time_hours())
}

///|
/// A leg with no forecast is not planned: `ABR` reports levels up to 39,000
/// ft, so 45,000 ft is refused, and so is a wind the caller cannot answer for
/// at all.
test "a missing forecast is reported" {
  let route = Route::new([coord(45.0, -98.0), coord(44.0, -96.0)])
  let above_the_top = try {
    let _ = route.plan(station("ABR"), 45000, 120.0)
    false
  } catch {
    FlightError::NoForecast(45000) => true
    _ => false
  }
  assert_true(above_the_top)

  let no_forecast_at_all = try {
    let _ = route.plan_with(fn(_position, _altitude) { None }, 12000, 120.0)
    false
  } catch {
    FlightError::NoForecast(12000) => true
    _ => false
  }
  assert_true(no_forecast_at_all)
}

///|
/// A wind from ahead that beats the aeroplane leaves no ground speed to time
/// the leg with: a 120 kt aircraft with a 150 kt wind straight down the leg
/// makes 30 kt of headway — backwards — and the plan says so rather than
/// giving the leg a negative time.
test "a leg the wind beats is refused" {
  let route = Route::new([coord(44.0, -98.0), coord(44.0, -96.0)])
  let beaten = try {
    let _ = route.plan_with(
      fn(_position, _altitude) { Some(vector(90, 150)) },
      12000,
      120.0,
    )
    false
  } catch {
    FlightError::NoGroundSpeed(ground_speed) => {
      assert_true(geo_close(ground_speed, -30.002756664, 1.0e-6))
      true
    }
    _ => false
  }
  assert_true(beaten)
}
