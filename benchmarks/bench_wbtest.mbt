///|
/// Benchmarks for the work a flight plan is made of, run against a real
/// winds and temperatures aloft product:
///
///     moon bench --release benchmarks
///
/// Each benchmark is named for one thing the library does, so a number reads
/// as what that one thing costs — and so that a change to the parsing or the
/// great-circle arithmetic can be seen in the numbers rather than argued
/// about.
///
/// The timed closures do not raise: a product that parses is assumed, as the
/// tests already assert it, and a failure inside a timed closure would only
/// measure how fast the benchmark fails.

///|
/// The product the benchmarks run against, parsed once.
fn product() -> @moonwind.Bulletin {
  @moonwind.parse_bulletin(bench_fd1us1) catch {
    _ => abort("the fd1us1 sample parses")
  }
}

///|
/// One station of the sample product.
fn station() -> @moonwind.StationWinds {
  match product().station("ABR") {
    Some(station) => station
    None => abort("the fd1us1 sample forecasts ABR")
  }
}

///|
/// A route across the sample product's stations, the sort of hop a flight
/// plan is made of.
fn route() -> @moonwind.Route {
  @moonwind.Route::new([
    @moonwind.Coordinate::new(45.0, -98.0),
    @moonwind.Coordinate::new(44.0, -96.0),
    @moonwind.Coordinate::new(43.0, -94.0),
    @moonwind.Coordinate::new(42.0, -92.0),
  ])
}

///|
/// A wind triangle that solves, to fall back on in a timed closure.
fn triangle() -> @moonwind.WindTriangle {
  @moonwind.WindTriangle::solve(
    90.0,
    120.0,
    @moonwind.WindVector::from_components(0.0, -14.0),
  ) catch {
    _ => abort("the wind triangle solves")
  }
}

///|
/// A route plan that plans, to fall back on in a timed closure.
fn plan() -> @moonwind.RoutePlan {
  route().plan(station(), 12000, 120.0) catch {
    _ => abort("the route plans")
  }
}

///|
/// Reading a real product: the header, the levels, and every station line.
test "parse a real product" (it : @bench.T) {
  let text = bench_fd1us1
  let fallback = product()
  it.bench(fn() {
    it.keep(@moonwind.parse_bulletin(text) catch { _ => fallback })
  })
}

///|
/// Writing a parsed product back out, column by column.
test "write a product back" (it : @bench.T) {
  let bulletin = product()
  it.bench(fn() {
    it.keep(@moonwind.format_bulletin(bulletin) catch { _ => "" })
  })
}

///|
/// The wind at an altitude between two forecast levels, which is what a leg
/// of a plan asks a station for.
test "the wind at a flight level" (it : @bench.T) {
  let station = station()
  it.bench(fn() { it.keep(station.vector_at(24000)) })
}

///|
/// The wind triangle of one leg.
test "a wind triangle" (it : @bench.T) {
  let wind = @moonwind.WindVector::from_components(0.0, -14.0)
  let fallback = triangle()
  it.bench(fn() {
    it.keep(
      @moonwind.WindTriangle::solve(90.0, 120.0, wind) catch {
        _ => fallback
      },
    )
  })
}

///|
/// A great-circle hop: its distance and the course to fly it on.
test "a great-circle hop" (it : @bench.T) {
  let from = @moonwind.Coordinate::new(45.0, -98.0)
  let to = @moonwind.Coordinate::new(43.0, -94.0)
  it.bench(fn() {
    it.keep(from.distance_to(to))
    it.keep(from.initial_course_to(to))
  })
}

///|
/// A position part of the way along a great circle, which is what cutting a
/// route into shorter legs is made of.
test "a position along a great circle" (it : @bench.T) {
  let from = @moonwind.Coordinate::new(45.0, -98.0)
  let to = @moonwind.Coordinate::new(43.0, -94.0)
  it.bench(fn() { it.keep(from.interpolate(to, 0.25)) })
}

///|
/// Cutting a route into shorter legs, each of which stays on its own course.
test "cut a route into shorter legs" (it : @bench.T) {
  let route = route()
  it.bench(fn() { it.keep(route.subdivided(8)) })
}

///|
/// Planning a whole route against a forecast: 24 legs, each with its own
/// wind, heading, ground speed and time. This is the number that matters for
/// a flight plan, and it moves with every one of the benchmarks above.
test "plan a 24-leg route" (it : @bench.T) {
  let route = route().subdivided(8)
  let station = station()
  let fallback = plan()
  it.bench(fn() {
    it.keep(route.plan(station, 12000, 120.0) catch { _ => fallback })
  })
}

///|
/// A dew point from a temperature and a humidity, which is a Magnus inversion
/// and one logarithm.
test "a dew point" (it : @bench.T) {
  it.bench(fn() { it.keep(@moonwind.dew_point(20.0, 60.0) catch { _ => 0.0 }) })
}

///|
/// A wet-bulb temperature, the heaviest of the humidity calculations: four
/// arc tangents, a square root and a power.
test "a wet-bulb temperature" (it : @bench.T) {
  it.bench(fn() {
    it.keep(
      match @moonwind.wet_bulb_temperature(25.0, 50.0) {
        Some(temperature) => temperature
        None => 0.0
      },
    )
  })
}

///|
/// A heat index, which is the nine-term regression and whichever of its two
/// corrections the humidity calls for.
test "a heat index" (it : @bench.T) {
  let index = @moonwind.heat_index_celsius(30.0, 50.0) catch { _ => None }
  it.bench(fn() {
    it.keep(
      match index {
        Some(value) => value
        None => 0.0
      },
    )
  })
}

///|
/// A wind chill, which is one power and four multiplications.
test "a wind chill" (it : @bench.T) {
  let chill = @moonwind.wind_chill_celsius(0.0, 20.0) catch { _ => None }
  it.bench(fn() {
    it.keep(
      match chill {
        Some(value) => value
        None => 0.0
      },
    )
  })
}
