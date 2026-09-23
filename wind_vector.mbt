///|
/// Winds as vectors, for the arithmetic that a report cannot carry.
///
/// A bulletin gives a wind as a direction and a speed, which is what a
/// forecaster reads but not what a calculation wants: the wind between two
/// levels is not the average of two directions and two speeds. Interpolation
/// is done on the two components of the wind, and the direction and speed of
/// the result are read back off the interpolated vector.

///|
/// A horizontal wind as a velocity vector: `u` is the eastward component and
/// `v` the northward one, both in knots.
///
/// This is the direction the air is moving *towards*, the opposite of the
/// direction a bulletin reports, since a wind direction names where the wind
/// comes from.
pub struct WindVector {
  u : Double
  v : Double
}

///|
pub fn WindVector::u(self : WindVector) -> Double {
  self.u
}

///|
pub fn WindVector::v(self : WindVector) -> Double {
  self.v
}

///|
/// The wind speed, in knots: the length of the vector.
pub fn WindVector::speed(self : WindVector) -> Double {
  (self.u * self.u + self.v * self.v).sqrt()
}

///|
/// The direction the wind comes from, in degrees true, in `[0, 360)`.
///
/// Undefined for a vector of zero length, where it returns 0.
pub fn WindVector::direction(self : WindVector) -> Double {
  let degrees = @math.atan2(-self.u, -self.v) * 180.0 / @math.PI
  // atan2 returns (-180, 180]; a reported direction is in [0, 360).
  if degrees < 0.0 {
    degrees + 360.0
  } else {
    degrees
  }
}

///|
/// A wind vector from its eastward and northward components, in knots.
pub fn WindVector::from_components(u : Double, v : Double) -> WindVector {
  { u, v, }
}

///|
/// The vector of a reported wind.
///
/// A light and variable wind has no direction, and becomes the zero vector:
/// it contributes nothing to an interpolated wind.
pub fn WindVector::from_wind(wind : Wind) -> WindVector {
  match wind.direction {
    None => { u: 0.0, v: 0.0, }
    Some(direction) => {
      let radians = direction.to_double() * @math.PI / 180.0
      let speed = wind.speed.to_double()
      { u: -speed * @math.sin(radians), v: -speed * @math.cos(radians), }
    }
  }
}

///|
/// A vector weaker than this, in knots, has no direction worth reporting.
let calm_threshold : Double = 0.5

///|
/// The wind as a `Wind`, rounded to the nearest knot and degree, with 360°
/// folded back to 0°.
///
/// A vector below half a knot rounds to zero speed, and is reported the way
/// the bulletins report a negligible wind: light and variable.
pub fn WindVector::to_wind(self : WindVector) -> Wind {
  let speed = self.speed()
  if speed < calm_threshold {
    { direction: None, speed: 0, }
  } else {
    {
      direction: Some(@math.round(self.direction()).to_int() % 360),
      speed: @math.round(speed).to_int(),
    }
  }
}

///|
/// The vector `fraction` of the way from `a` to `b`, component by component.
///
/// A wind forecast for two levels is taken to vary linearly between them, the
/// same way its temperature does.
pub fn WindVector::interpolate(
  a : WindVector,
  b : WindVector,
  fraction : Double,
) -> WindVector {
  { u: a.u + (b.u - a.u) * fraction, v: a.v + (b.v - a.v) * fraction, }
}
