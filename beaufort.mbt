///|
/// The Beaufort scale: a wind written as a force from 0 to 12 rather than as a
/// number.
///
/// Francis Beaufort's scale describes what a wind does — the sea it raises, the
/// trees it moves — and it is still how a wind is reported when the exact speed
/// is not the point: force 0 is calm, 2 a light breeze that leaves leaves
/// rustling, 6 a strong breeze that moves a branch, 8 a gale, and 12 a
/// hurricane. Each force covers a band of speeds rather than one speed, and
/// every band is closed at the bottom: force 4 runs from its own lower bound up
/// to the bound of force 5, not including it.
///
/// The bands are published in knots, in metres per second and in kilometres per
/// hour, and the three were rounded independently, so they do not quite agree
/// at their edges: 3.4 m/s is 6.61 kt, which is the top of force 2 in the knots
/// table and the bottom of force 3 in the metres-per-second one. Each
/// constructor here reads the table its own unit is published in rather than
/// converting, so a report is answered in the scale it was written against —
/// ask with the unit you have.

///|
/// A wind whose speed will not do: a wind does not blow backwards, and a
/// negative speed is not one.
pub suberror BeaufortError {
  /// A wind speed cannot be negative. The payload is the offending speed.
  BadWindSpeed(Double)
}

///|
/// A wind on the Beaufort scale, held as the force alone: the band it falls in
/// carries the description and the bounds.
pub struct Beaufort {
  force : Int
}

///|
/// The lower bound of each force in knots, inclusive, from calm to a
/// hurricane.
let beaufort_knots : Array[Double] = [
  0.0, 1.0, 4.0, 7.0, 11.0, 17.0, 22.0, 28.0, 34.0, 41.0, 48.0, 56.0, 64.0,
]

///|
/// The lower bound of each force in metres per second, inclusive.
let beaufort_meters_per_second : Array[Double] = [
  0.0, 0.3, 1.6, 3.4, 5.5, 8.0, 10.8, 13.9, 17.2, 20.8, 24.5, 28.5, 32.7,
]

///|
/// The lower bound of each force in kilometres per hour, inclusive.
let beaufort_kilometers_per_hour : Array[Double] = [
  0.0, 1.0, 6.0, 12.0, 20.0, 29.0, 39.0, 50.0, 62.0, 75.0, 89.0, 103.0, 118.0,
]

///|
/// What each force is called, from 0 to 12.
let beaufort_descriptions : Array[String] = [
  "Calm", "Light air", "Light breeze", "Gentle breeze", "Moderate breeze", "Fresh breeze",
  "Strong breeze", "Near gale", "Gale", "Strong gale", "Storm", "Violent storm",
  "Hurricane",
]

///|
/// The force `speed` falls in for one published table: the last force whose
/// lower bound it reaches.
fn force_in_table(thresholds : Array[Double], speed : Double) -> Int {
  let mut force = 0
  for index = 1; index < thresholds.length(); index = index + 1 {
    if speed >= thresholds[index] {
      force = index
    }
  }
  force
}

///|
/// The Beaufort force of a wind of `knots`, read from the scale as it is
/// published in knots.
pub fn Beaufort::from_knots(knots : Double) -> Beaufort raise BeaufortError {
  if knots < 0.0 {
    raise BeaufortError::BadWindSpeed(knots)
  }
  { force: force_in_table(beaufort_knots, knots), }
}

///|
/// The Beaufort force of a wind of `meters_per_second`, read from the scale as
/// it is published in metres per second.
pub fn Beaufort::from_meters_per_second(
  meters_per_second : Double,
) -> Beaufort raise BeaufortError {
  if meters_per_second < 0.0 {
    raise BeaufortError::BadWindSpeed(meters_per_second)
  }
  { force: force_in_table(beaufort_meters_per_second, meters_per_second), }
}

///|
/// The Beaufort force of a wind of `kilometers_per_hour`, read from the scale
/// as it is published in kilometres per hour.
pub fn Beaufort::from_kilometers_per_hour(
  kilometers_per_hour : Double,
) -> Beaufort raise BeaufortError {
  if kilometers_per_hour < 0.0 {
    raise BeaufortError::BadWindSpeed(kilometers_per_hour)
  }
  { force: force_in_table(beaufort_kilometers_per_hour, kilometers_per_hour), }
}

///|
/// The Beaufort force of a reported `wind`, read from the scale as it is
/// published in knots, which is the unit the data model keeps. A light and
/// variable wind is calm.
pub fn Beaufort::from_wind(wind : Wind) -> Beaufort raise BeaufortError {
  Beaufort::from_knots(wind.speed().to_double())
}

///|
/// The force, from 0 to 12.
pub fn Beaufort::force(self : Beaufort) -> Int {
  self.force
}

///|
/// What the force is called, such as "Moderate breeze".
pub fn Beaufort::description(self : Beaufort) -> String {
  beaufort_descriptions[self.force]
}

///|
/// The speed the force begins at, in knots, inclusive: the knots table's, even
/// for a force read from another unit's table.
pub fn Beaufort::lower_bound_knots(self : Beaufort) -> Double {
  beaufort_knots[self.force]
}

///|
/// The speed the next force begins at, in knots, which is where this one ends:
/// force 4 runs up to but not including force 5's 17 kt. A hurricane, force 12,
/// is the last of them and answers `None`, since the scale has no bound above
/// it.
pub fn Beaufort::upper_bound_knots(self : Beaufort) -> Double? {
  if self.force + 1 < beaufort_knots.length() {
    Some(beaufort_knots[self.force + 1])
  } else {
    None
  }
}
