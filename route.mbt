///|
/// Routes: the path a flight follows, the hops it is made of, and the time it
/// takes against a winds-aloft forecast.
///
/// A route is a list of waypoints, and between two of them the path is a
/// great circle. The course of a great circle drifts as it is flown — a
/// north Atlantic crossing leaves New York on 051 and reaches London on 108 —
/// so a long hop is better flown as several short legs, each steered by its
/// own course. `Route::subdivided` cuts the hops into those legs, and
/// `Route::plan` times each one against the forecast wind.

///|
/// One hop of a route: the two positions, the great-circle distance between
/// them and the course it is flown on.
pub struct RouteSegment {
  from : Coordinate
  to : Coordinate
  distance : Double
  true_course : Double
}

///|
/// The hop from one position to another, with its distance and course.
pub fn RouteSegment::new(from : Coordinate, to : Coordinate) -> RouteSegment {
  {
    from,
    to,
    distance: from.distance_to(to),
    true_course: from.initial_course_to(to),
  }
}

///|
/// Where the hop starts.
pub fn RouteSegment::from(self : RouteSegment) -> Coordinate {
  self.from
}

///|
/// Where the hop ends.
pub fn RouteSegment::to(self : RouteSegment) -> Coordinate {
  self.to
}

///|
/// The great-circle distance of the hop, in nautical miles.
pub fn RouteSegment::distance(self : RouteSegment) -> Double {
  self.distance
}

///|
/// The true course at the start of the hop, in degrees. The course drifts as
/// the hop is flown, so a long hop is not flown on one heading: cut it into
/// shorter legs to keep the course of each one nearly constant.
pub fn RouteSegment::true_course(self : RouteSegment) -> Double {
  self.true_course
}

///|
/// Half way along the hop, where a leg reads its wind from the forecast.
pub fn RouteSegment::midpoint(self : RouteSegment) -> Coordinate {
  self.from.midpoint(self.to)
}

///|
/// A route: the waypoints in the order they are flown.
pub struct Route {
  points : Array[Coordinate]
}

///|
/// A route from its waypoints, in order. A route needs two waypoints to have
/// any length; one with fewer is simply empty of hops.
pub fn Route::new(points : Array[Coordinate]) -> Route {
  { points, }
}

///|
/// The waypoints, in order.
pub fn Route::points(self : Route) -> Array[Coordinate] {
  self.points
}

///|
/// The hops between consecutive waypoints, in order, with their distances and
/// courses.
pub fn Route::segments(self : Route) -> Array[RouteSegment] {
  let segments : Array[RouteSegment] = []
  for i = 0; i + 1 < self.points.length(); i = i + 1 {
    segments.push(RouteSegment::new(self.points[i], self.points[i + 1]))
  }
  segments
}

///|
/// The length of the route along its waypoints, in nautical miles.
///
/// Only the hops are measured, so a route's length costs nothing it does not
/// use: the courses along the way are left to `segments`.
pub fn Route::distance(self : Route) -> Double {
  let mut total = 0.0
  for i = 0; i + 1 < self.points.length(); i = i + 1 {
    total += self.points[i].distance_to(self.points[i + 1])
  }
  total
}

///|
/// The same route flown in shorter hops: every hop divided into `count` equal
/// parts, so that the course of each part stays close to the course at its
/// start. A `count` below one leaves the route as it is.
///
/// The hop is walked from its two ends, which are read once for the whole
/// hop: cutting a route into many legs costs the same trigonometry whether a
/// hop is cut in two or in twenty.
pub fn Route::subdivided(self : Route, count : Int) -> Route {
  let points : Array[Coordinate] = []
  if count < 1 {
    for point in self.points {
      points.push(point)
    }
  } else {
    for i = 0; i + 1 < self.points.length(); i = i + 1 {
      let from = self.points[i]
      let to = self.points[i + 1]
      points.push(from)
      let start = unit_vector(from)
      let end = unit_vector(to)
      let angle = angle_between(start, end)
      let walkable = angle > 1.0e-12 && angle < @math.PI - 1.0e-12
      for part = 1; part < count; part = part + 1 {
        let fraction = part.to_double() / count.to_double()
        points.push(
          if walkable {
            position_along(start, end, angle, fraction)
          } else {
            // The hop is too short to have parts, or runs between opposite
            // positions, where there is no path to walk: it stays where it is.
            from
          },
        )
      }
    }
    if self.points.length() > 0 {
      points.push(self.points[self.points.length() - 1])
    }
  }
  { points, }
}

///|
/// One leg of a planned route: the hop, the forecast wind that was used for
/// it, and the wind triangle that comes out of the two.
pub struct RouteLeg {
  segment : RouteSegment
  wind : WindVector
  triangle : WindTriangle
}

///|
/// The hop this leg flies.
pub fn RouteLeg::segment(self : RouteLeg) -> RouteSegment {
  self.segment
}

///|
/// The forecast wind the leg was planned with, as a vector.
pub fn RouteLeg::wind(self : RouteLeg) -> WindVector {
  self.wind
}

///|
/// The wind triangle of the leg: heading, ground speed and the components a
/// pilot reads the wind in.
pub fn RouteLeg::triangle(self : RouteLeg) -> WindTriangle {
  self.triangle
}

///|
/// The distance of the leg, in nautical miles.
pub fn RouteLeg::distance(self : RouteLeg) -> Double {
  self.segment.distance
}

///|
/// The course of the leg, in degrees true.
pub fn RouteLeg::true_course(self : RouteLeg) -> Double {
  self.segment.true_course
}

///|
/// The heading to steer along the leg, in degrees true.
pub fn RouteLeg::heading(self : RouteLeg) -> Double {
  self.triangle.heading()
}

///|
/// The ground speed the leg is flown at, in knots.
pub fn RouteLeg::ground_speed(self : RouteLeg) -> Double {
  self.triangle.ground_speed()
}

///|
/// The wind component along the leg, in knots: positive against the aircraft,
/// so a tailwind is negative.
pub fn RouteLeg::headwind(self : RouteLeg) -> Double {
  self.triangle.headwind()
}

///|
/// The wind component across the leg, in knots: positive from the right.
pub fn RouteLeg::crosswind(self : RouteLeg) -> Double {
  self.triangle.crosswind()
}

///|
/// The time the leg takes, in hours: its distance over its ground speed.
pub fn RouteLeg::time_hours(self : RouteLeg) -> Double {
  self.segment.distance / self.triangle.ground_speed()
}

///|
/// A route planned at one altitude and airspeed: the legs in order, each with
/// the wind it was planned with, and the totals over the whole route.
pub struct RoutePlan {
  source : String?
  altitude : Int
  airspeed : Double
  legs : Array[RouteLeg]
}

///|
/// The station the forecast came from, when the plan was built on one
/// station's winds rather than on a wind the caller supplies.
pub fn RoutePlan::source(self : RoutePlan) -> String? {
  self.source
}

///|
/// The altitude the route is planned at, in feet.
pub fn RoutePlan::altitude(self : RoutePlan) -> Int {
  self.altitude
}

///|
/// The true airspeed the route is planned at, in knots.
pub fn RoutePlan::airspeed(self : RoutePlan) -> Double {
  self.airspeed
}

///|
/// The legs, in order.
pub fn RoutePlan::legs(self : RoutePlan) -> Array[RouteLeg] {
  self.legs
}

///|
/// The distance of the whole route, in nautical miles.
pub fn RoutePlan::total_distance(self : RoutePlan) -> Double {
  let mut total = 0.0
  for leg in self.legs {
    total += leg.distance()
  }
  total
}

///|
/// The time the whole route takes, in hours.
pub fn RoutePlan::total_time_hours(self : RoutePlan) -> Double {
  let mut total = 0.0
  for leg in self.legs {
    total += leg.time_hours()
  }
  total
}

///|
/// Plan the route at `altitude` feet and `airspeed` knots, reading the wind
/// for each leg from `wind_at`, which is given the middle of the leg and the
/// altitude.
///
/// The wind is read at the middle of a leg because that is the wind that
/// carries the aircraft over most of it, and the position is offered to the
/// caller so that a forecast which varies over the route can be used: the
/// station nearest each leg, or a grid of forecast winds.
///
/// A leg that has no forecast at that altitude is reported with
/// `FlightError::NoForecast`, and a leg the wind beats — one whose ground
/// speed comes out at or below zero — with `FlightError::NoGroundSpeed`,
/// rather than being planned with a time that means nothing.
pub fn Route::plan_with(
  self : Route,
  wind_at : (Coordinate, Int) -> WindVector?,
  altitude : Int,
  airspeed : Double,
) -> RoutePlan raise FlightError {
  let legs : Array[RouteLeg] = []
  for segment in self.segments() {
    let wind = match wind_at(segment.midpoint(), altitude) {
      Some(found) => found
      None => raise FlightError::NoForecast(altitude)
    }
    let triangle = WindTriangle::solve(segment.true_course, airspeed, wind)
    if triangle.ground_speed() <= 0.0 {
      raise FlightError::NoGroundSpeed(triangle.ground_speed())
    }
    legs.push({ segment, wind, triangle, })
  }
  { source: None, altitude, airspeed, legs, }
}

///|
/// Plan the route at `altitude` feet and `airspeed` knots with one station's
/// forecast, read at each leg's middle.
///
/// One station stands in for the whole route, which is what a route flown
/// within one station's area wants. A longer route is planned in parts, one
/// call per part, each with the station nearest it; the parts add up.
pub fn Route::plan(
  self : Route,
  station : StationWinds,
  altitude : Int,
  airspeed : Double,
) -> RoutePlan raise FlightError {
  let plan = self.plan_with(
    fn(_position, level) { station.vector_at(level) },
    altitude,
    airspeed,
  )
  {
    source: Some(station.station()),
    altitude: plan.altitude(),
    airspeed: plan.airspeed(),
    legs: plan.legs(),
  }
}
