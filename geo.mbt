///|
/// Positions on the globe, and the great-circle paths between them.
///
/// A route is flown over a sphere: the shortest way between two positions is
/// an arc of a great circle, not a straight line drawn on a chart, and the
/// direction to fly changes along it. Everything here is in degrees of
/// latitude and longitude — positive north and east — and nautical miles, on
/// a sphere of the Earth's mean radius.

///|
/// The mean radius of the Earth, in nautical miles.
let earth_radius_nm : Double = 3440.065

///|
/// A position on the globe: latitude and longitude in degrees, positive north
/// and east.
pub struct Coordinate {
  latitude : Double
  longitude : Double
}

///|
/// A position from its latitude and longitude, in degrees.
pub fn Coordinate::new(latitude : Double, longitude : Double) -> Coordinate {
  { latitude, longitude, }
}

///|
pub fn Coordinate::latitude(self : Coordinate) -> Double {
  self.latitude
}

///|
pub fn Coordinate::longitude(self : Coordinate) -> Double {
  self.longitude
}

///|
/// Degrees as radians.
fn to_radians(degrees : Double) -> Double {
  degrees * @math.PI / 180.0
}

///|
/// Radians as degrees.
fn to_degrees(radians : Double) -> Double {
  radians * 180.0 / @math.PI
}

///|
/// The signed difference between two longitudes, in degrees, taken the short
/// way round: from 170 east to 170 west is 20 degrees, not 340. A path across
/// the date line turns on this.
fn longitude_difference(from : Double, to : Double) -> Double {
  let mut difference = to - from
  while difference > 180.0 {
    difference -= 360.0
  }
  while difference <= -180.0 {
    difference += 360.0
  }
  difference
}

///|
/// The great-circle distance to `other`, in nautical miles.
///
/// This is the haversine formula, written as an `atan2` rather than as an
/// arcsine so that it keeps its accuracy at both ends of its range: for the
/// short hops a route is built from, and for the near-antipodal distances a
/// long flight covers.
pub fn Coordinate::distance_to(self : Coordinate, other : Coordinate) -> Double {
  let latitude_1 = to_radians(self.latitude)
  let latitude_2 = to_radians(other.latitude)
  let half_latitude = (latitude_2 - latitude_1) / 2.0
  let half_longitude = to_radians(
      longitude_difference(self.longitude, other.longitude),
    ) /
    2.0
  let sin_latitude = @math.sin(half_latitude)
  let sin_longitude = @math.sin(half_longitude)
  let haversine = sin_latitude * sin_latitude +
    @math.cos(latitude_1) *
    @math.cos(latitude_2) *
    sin_longitude *
    sin_longitude
  let clamped = if haversine < 0.0 {
    0.0
  } else if haversine > 1.0 {
    1.0
  } else {
    haversine
  }
  2.0 * earth_radius_nm * @math.atan2(clamped.sqrt(), (1.0 - clamped).sqrt())
}

///|
/// The initial true course from here to `other`, in degrees clockwise from
/// north.
///
/// A great circle is not a straight line on a chart, so its direction changes
/// along the way, and this is the course at the start of the path: the one to
/// steer as the leg begins. Over a long path the course drifts — a great
/// circle from New York to London leaves on 051 and arrives on 108 — which is
/// why a long hop is flown as several short ones, each with its own course.
pub fn Coordinate::initial_course_to(
  self : Coordinate,
  other : Coordinate,
) -> Double {
  let latitude_1 = to_radians(self.latitude)
  let latitude_2 = to_radians(other.latitude)
  let difference = to_radians(
    longitude_difference(self.longitude, other.longitude),
  )
  let north = @math.sin(difference) * @math.cos(latitude_2)
  let east = @math.cos(latitude_1) * @math.sin(latitude_2) -
    @math.sin(latitude_1) * @math.cos(latitude_2) * @math.cos(difference)
  normalize_degrees(to_degrees(@math.atan2(north, east)))
}

///|
/// A position as a unit vector from the centre of the Earth, which is where
/// the great-circle arithmetic is easiest: mixing two of these mixes the
/// positions themselves.
priv struct UnitVector {
  x : Double
  y : Double
  z : Double
}

///|
/// The unit vector pointing at `position`.
fn unit_vector(position : Coordinate) -> UnitVector {
  let latitude = to_radians(position.latitude)
  let longitude = to_radians(position.longitude)
  {
    x: @math.cos(latitude) * @math.cos(longitude),
    y: @math.cos(latitude) * @math.sin(longitude),
    z: @math.sin(latitude),
  }
}

///|
/// The position a unit vector points at, back on the surface.
fn position_of(vector : UnitVector) -> Coordinate {
  {
    latitude: to_degrees(@math.atan2(vector.z, @math.hypot(vector.x, vector.y))),
    longitude: to_degrees(@math.atan2(vector.y, vector.x)),
  }
}

///|
/// The angle between two unit vectors, in radians.
fn angle_between(one : UnitVector, other : UnitVector) -> Double {
  let dot = one.x * other.x + one.y * other.y + one.z * other.z
  let square = 1.0 - dot * dot
  @math.atan2((if square < 0.0 { 0.0 } else { square }).sqrt(), dot)
}

///|
/// The position `fraction` of the way along the great circle to `other`:
/// 0 is here, 1 is there, and 0.5 is half way by distance.
///
/// The path is interpolated on the sphere, by mixing the two positions as
/// vectors and putting the result back on the surface, so the points land on
/// the great circle itself and equal fractions cover equal distances. Two
/// positions that coincide have no path between them and answer themselves;
/// two exactly opposite positions have no single great circle at all, and
/// answer themselves as well.
pub fn Coordinate::interpolate(
  self : Coordinate,
  other : Coordinate,
  fraction : Double,
) -> Coordinate {
  let from = unit_vector(self)
  let to = unit_vector(other)
  let angle = angle_between(from, to)
  if angle < 1.0e-12 || angle > @math.PI - 1.0e-12 {
    return self
  }
  let sine = @math.sin(angle)
  let weight_from = @math.sin((1.0 - fraction) * angle) / sine
  let weight_to = @math.sin(fraction * angle) / sine
  position_of({
    x: weight_from * from.x + weight_to * to.x,
    y: weight_from * from.y + weight_to * to.y,
    z: weight_from * from.z + weight_to * to.z,
  })
}

///|
/// Half way along the great circle to `other`, by distance.
pub fn Coordinate::midpoint(
  self : Coordinate,
  other : Coordinate,
) -> Coordinate {
  self.interpolate(other, 0.5)
}
