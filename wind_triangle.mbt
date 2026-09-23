///|
/// The wind triangle: what a wind does to an aeroplane.
///
/// An aeroplane flying at a true airspeed through a moving air mass is
/// carried with the air: its path over the ground is the sum of the two
/// velocities. The wind triangle solves that sum for flight planning — given
/// the course to make good, the airspeed to fly and the wind, it gives the
/// heading to steer, the ground speed that results, and the two components a
/// pilot reads a wind in: headwind and crosswind.
///
/// Components follow the aviation convention: a headwind is positive when
/// the wind comes from ahead (a tailwind is a negative headwind), and a
/// crosswind is positive when the wind comes from the right of the track,
/// which is the side a wind correction angle steers into.

///|
/// A wind triangle that cannot be flown.
pub suberror FlightError {
  /// The airspeed must be positive.
  BadAirspeed(Double)
  /// The wind blows sideways faster than the aeroplane flies, so no heading
  /// can hold the course. The payloads are the crosswind and the airspeed.
  CrosswindExceedsAirspeed(Double, Double)
}

///|
/// The solution of one wind triangle: the inputs, and the heading, ground
/// speed and wind components they give.
pub struct WindTriangle {
  /// The course to make good, in degrees true.
  course : Double
  /// The true airspeed, in knots.
  airspeed : Double
  /// The wind, as a vector.
  wind : WindVector
  /// The heading to steer, in degrees true: the course plus the wind
  /// correction angle.
  heading : Double
  /// The wind correction angle, in degrees: positive when the heading is to
  /// the right of the course, steering into a right crosswind.
  wind_correction_angle : Double
  /// The ground speed, in knots.
  ground_speed : Double
  /// The wind along the track, in knots: positive against the aircraft, so a
  /// tailwind is negative.
  headwind : Double
  /// The wind across the track, in knots: positive from the right.
  crosswind : Double
}

///|
pub fn WindTriangle::course(self : WindTriangle) -> Double {
  self.course
}

///|
pub fn WindTriangle::airspeed(self : WindTriangle) -> Double {
  self.airspeed
}

///|
pub fn WindTriangle::wind(self : WindTriangle) -> WindVector {
  self.wind
}

///|
pub fn WindTriangle::heading(self : WindTriangle) -> Double {
  self.heading
}

///|
pub fn WindTriangle::wind_correction_angle(self : WindTriangle) -> Double {
  self.wind_correction_angle
}

///|
pub fn WindTriangle::ground_speed(self : WindTriangle) -> Double {
  self.ground_speed
}

///|
pub fn WindTriangle::headwind(self : WindTriangle) -> Double {
  self.headwind
}

///|
pub fn WindTriangle::crosswind(self : WindTriangle) -> Double {
  self.crosswind
}

///|
/// The wind along `direction`, in degrees true, in knots.
///
/// Positive when the wind comes from ahead, so a tailwind is negative. A
/// light and variable wind has no direction, and contributes nothing.
pub fn WindVector::headwind_component(
  self : WindVector,
  direction : Double,
) -> Double {
  let radians = direction * @math.PI / 180.0
  -(self.u * @math.sin(radians) + self.v * @math.cos(radians))
}

///|
/// The wind across `direction`, in degrees true, in knots.
///
/// Positive when the wind comes from the right, the side that makes an
/// aircraft steer a positive wind correction angle.
pub fn WindVector::crosswind_component(
  self : WindVector,
  direction : Double,
) -> Double {
  let radians = direction * @math.PI / 180.0
  self.v * @math.sin(radians) - self.u * @math.cos(radians)
}

///|
/// Bring degrees into `[0, 360)`.
fn normalize_degrees(degrees : Double) -> Double {
  let mut out = degrees
  while out < 0.0 {
    out += 360.0
  }
  while out >= 360.0 {
    out -= 360.0
  }
  out
}

///|
/// Solve the wind triangle.
///
/// The heading to steer is the course plus the wind correction angle, which
/// is read off the two components of the wind along the track: the angle
/// whose sine is the crosswind over the airspeed. When the crosswind exceeds
/// the airspeed there is no such angle, and the triangle cannot be flown.
pub fn WindTriangle::solve(
  course : Double,
  airspeed : Double,
  wind : WindVector,
) -> WindTriangle raise FlightError {
  if airspeed <= 0.0 {
    raise FlightError::BadAirspeed(airspeed)
  }
  let crosswind = wind.crosswind_component(course)
  let headwind = wind.headwind_component(course)
  let along = airspeed * airspeed - crosswind * crosswind
  if along < 0.0 {
    raise FlightError::CrosswindExceedsAirspeed(crosswind, airspeed)
  }
  let wind_correction_angle = @math.atan2(crosswind, along.sqrt()) *
    180.0 /
    @math.PI
  let heading = normalize_degrees(course + wind_correction_angle)
  let ground_speed = along.sqrt() - headwind
  {
    course,
    airspeed,
    wind,
    heading,
    wind_correction_angle,
    ground_speed,
    headwind,
    crosswind,
  }
}
