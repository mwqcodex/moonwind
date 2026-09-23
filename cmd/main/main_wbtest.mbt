///|
/// Whether two values agree to within `tolerance`.
fn cli_close(actual : Double, expected : Double, tolerance : Double) -> Bool {
  (actual - expected).abs() <= tolerance
}

///|
/// A wind from its reported direction and speed.
fn wind(direction : Int, speed : Int) -> @moonwind.WindVector {
  @moonwind.WindVector::from_wind(@moonwind.Wind::new(Some(direction), speed))
}

///|
/// A command the arguments describe, which is expected to be a plan.
fn planned(arguments : Array[String]) -> Request {
  match command(arguments) {
    Plan(request) => request
    Bad(message) => abort("expected a plan, not \{message}")
    Help => abort("expected a plan, not help")
    ListStations(_) => abort("expected a plan, not a list")
  }
}

///|
/// A number written for a report keeps the digits it is read to, and holds
/// its place when it has fewer.
test "a number is written with the digits a report needs" {
  assert_eq(fixed(104.591137317, 1), "104.6")
  assert_eq(fixed(379.441729175, 2), "379.44")
  assert_eq(fixed(1.0, 2), "1.00")
  assert_eq(fixed(120.0, 0), "120")
  assert_eq(fixed(-30.002756664, 1), "-30.0")
  assert_eq(fixed(0.0, 1), "0.0")
  assert_eq(hours_text(1.961568231), "1 h 58 min")
  assert_eq(hours_text(0.5), "30 min")
  assert_eq(hours_text(2.0), "2 h 0 min")
}

///|
/// A position reads the way a chart has it: degrees north or south, east or
/// west.
test "a position is written the way a chart has it" {
  assert_eq(
    position_text(@moonwind.Coordinate::new(45.0, -98.0)),
    "45.00N 98.00W",
  )
  assert_eq(
    position_text(@moonwind.Coordinate::new(-33.94, 151.18)),
    "33.94S 151.18E",
  )
  assert_eq(position_text(@moonwind.Coordinate::new(0.0, 0.0)), "0.00N 0.00E")
}

///|
/// A wind is written as it is reported, with the direction in three digits.
test "a wind is written as it is reported" {
  assert_eq(wind_text(wind(150, 14)), "150 at 14 kt")
  assert_eq(wind_text(wind(5, 4)), "005 at 4 kt")
  assert_eq(wind_text(wind(90, 200)), "090 at 200 kt")
  assert_eq(
    wind_text(@moonwind.WindVector::from_components(0.0, 0.0)),
    "light and variable",
  )
}

///|
/// Waypoints are latitudes and longitudes in degrees, and anything else is
/// not a waypoint: not one number, not three, not a number outside the globe,
/// not a word.
test "a waypoint is a latitude and a longitude" {
  match waypoint("45,-98") {
    Some(position) => {
      assert_true(cli_close(position.latitude(), 45.0, 1.0e-12))
      assert_true(cli_close(position.longitude(), -98.0, 1.0e-12))
    }
    None => abort("45,-98 is a waypoint")
  }
  match waypoint("45.25,-98.5") {
    Some(position) =>
      assert_true(cli_close(position.longitude(), -98.5, 1.0e-12))
    None => abort("45.25,-98.5 is a waypoint")
  }
  for bad in ["", "45", "45,-98,3", "north,98", "45,west", "45,181", "181,-98"] {
    assert_true(waypoint(bad) is None)
  }
}

///|
/// The command line is read into a plan: the options take the values that
/// follow them, and everything else is a waypoint.
test "the command line is read into a plan" {
  let by_default = planned([])
  assert_eq(by_default.product, "fd1us1")
  assert_eq(by_default.station, "ABR")
  assert_eq(by_default.altitude, 12000)
  assert_true(cli_close(by_default.airspeed, 120.0, 1.0e-12))
  assert_eq(by_default.legs, 1)
  assert_eq(by_default.waypoints.length(), 0)

  let asked_for = planned([
    "--product", "fd8us7", "--station", "ABQ", "--altitude", "45000", "--airspeed",
    "450", "--legs", "4", "45,-98", "44,-96", "43,-94",
  ])
  assert_eq(asked_for.product, "fd8us7")
  assert_eq(asked_for.station, "ABQ")
  assert_eq(asked_for.altitude, 45000)
  assert_true(cli_close(asked_for.airspeed, 450.0, 1.0e-12))
  assert_eq(asked_for.legs, 4)
  assert_eq(asked_for.waypoints.length(), 3)
  assert_true(cli_close(asked_for.waypoints[2].latitude(), 43.0, 1.0e-12))
}

///|
/// Asking for help or for the stations is not planning, and a command line
/// that makes no sense is reported rather than planned.
test "help, lists and mistakes are not plans" {
  assert_true(command(["--help"]) is Help)
  assert_true(command(["-h"]) is Help)
  match command(["--list"]) {
    ListStations(product) => assert_eq(product, "fd1us1")
    _ => abort("--list lists the stations")
  }
  match command(["--list", "--product", "fd8us7"]) {
    ListStations(product) => assert_eq(product, "fd8us7")
    _ => abort("--list lists the stations of the product it was given")
  }
  let bad_commands : Array[Array[String]] = [
    ["--station"],
    ["--altitude", "high"],
    ["--airspeed", "fast"],
    ["--legs", "many"],
    ["45,-98"],
    ["45,-98", "44"],
    ["--altitude", "-1000"],
    ["--airspeed", "0"],
    ["--legs", "0"],
  ]
  for bad in bad_commands {
    assert_true(command(bad) is Bad(_))
  }
}

///|
/// The products the demo carries are the real ones, and a product it does not
/// carry is refused.
test "the demo carries the real products" {
  assert_true(product_text("fd1us1") is Some(_))
  assert_true(product_text("fd2us1") is Some(_))
  assert_true(product_text("fd8us7") is Some(_))
  assert_true(product_text("fd3us1") is None)
}

///|
/// The report of a product says what it is and when it is valid, and the
/// levels a station reports read as a range.
test "a product is reported by its designator and its validity" {
  let bulletin = @moonwind.parse_bulletin(sample_fd1us1)
  assert_eq(validity_text(bulletin), "  FD1US1  valid 221800Z")
  let abr = match bulletin.station("ABR") {
    Some(station) => station
    None => abort("the sample has ABR")
  }
  assert_eq(level_range_text(abr), "3000 to 39000 ft")
}
