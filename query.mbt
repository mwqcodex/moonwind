///|
/// Asking a station for the wind and temperature at an altitude it did not
/// forecast.
///
/// A bulletin forecasts a handful of levels; a flight plan wants the wind at
/// the altitude it will fly, which usually falls between two of them. Both
/// are interpolated from the levels that bracket the altitude, and answered
/// with `None` outside the levels the station reports — a forecast is not
/// extrapolated beyond what was forecast.

///|
/// The altitudes this station reports, in feet, in the order the bulletin
/// lists them, which is ascending.
///
/// A station does not necessarily report every level of the product: a column
/// the bulletin leaves blank is simply absent.
pub fn StationWinds::altitudes(self : StationWinds) -> Array[Int] {
  let out : Array[Int] = []
  for level in self.levels {
    out.push(level.altitude)
  }
  out
}

///|
/// The lowest altitude this station reports, in feet.
pub fn StationWinds::lowest_altitude(self : StationWinds) -> Int? {
  if self.levels.length() == 0 {
    None
  } else {
    Some(self.levels[0].altitude)
  }
}

///|
/// The highest altitude this station reports, in feet.
pub fn StationWinds::highest_altitude(self : StationWinds) -> Int? {
  if self.levels.length() == 0 {
    None
  } else {
    Some(self.levels[self.levels.length() - 1].altitude)
  }
}

///|
/// The wind at `altitude` feet, as a vector in knots.
///
/// A reported level is returned as it was reported. An altitude between two
/// reported levels is interpolated between them, component by component; a
/// light and variable level counts as no wind at all. `None` when the station
/// reports nothing on both sides of `altitude`.
pub fn StationWinds::vector_at(
  self : StationWinds,
  altitude : Int,
) -> WindVector? {
  match self.level_at(altitude) {
    Some(level) => return Some(WindVector::from_wind(level.wind))
    None => ()
  }
  match self.bracketing_levels(altitude, fn(_) { true }) {
    (Some(lower), Some(upper)) =>
      Some(
        WindVector::interpolate(
          WindVector::from_wind(lower.wind),
          WindVector::from_wind(upper.wind),
          fraction_between(altitude, lower.altitude, upper.altitude),
        ),
      )
    _ => None
  }
}

///|
/// The temperature at `altitude` feet, in degrees Celsius, interpolated
/// between the levels that forecast one.
///
/// `None` when no level on both sides of `altitude` carries a temperature,
/// which is the case at 3,000 ft, where the product never forecasts one.
pub fn StationWinds::temperature_at(
  self : StationWinds,
  altitude : Int,
) -> Double? {
  match self.level_at(altitude) {
    Some(level) =>
      match level.temperature {
        Some(temperature) => return Some(temperature.to_double())
        None => ()
      }
    None => ()
  }
  match
    self.bracketing_levels(altitude, fn(level) { level.temperature is Some(_) }) {
    (Some(lower), Some(upper)) =>
      match (lower.temperature, upper.temperature) {
        (Some(low), Some(high)) => {
          let low = low.to_double()
          let high = high.to_double()
          Some(
            low +
            (high - low) *
            fraction_between(altitude, lower.altitude, upper.altitude),
          )
        }
        _ => None
      }
    _ => None
  }
}

///|
/// The reported levels that bracket `altitude`: the highest one below it and
/// the lowest one above it.
///
/// `usable` picks the levels to consider, so that a temperature is
/// interpolated between the levels that carry one.
fn StationWinds::bracketing_levels(
  self : StationWinds,
  altitude : Int,
  usable : (Level) -> Bool,
) -> (Level?, Level?) {
  let mut lower : Level? = None
  let mut upper : Level? = None
  for level in self.levels {
    if !usable(level) {
      continue
    }
    if level.altitude < altitude {
      // The levels are ascending, so the last one below is the highest.
      lower = Some(level)
    } else if level.altitude > altitude && upper is None {
      upper = Some(level)
    }
  }
  (lower, upper)
}

///|
/// Where `altitude` falls between `low` and `high`, as a fraction from 0 to 1.
fn fraction_between(altitude : Int, low : Int, high : Int) -> Double {
  (altitude - low).to_double() / (high - low).to_double()
}
