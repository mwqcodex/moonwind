///|
/// A runway and the wind across it.
///
/// A runway is named for its magnetic direction rounded to the nearest ten
/// degrees and cut to two digits: runway 27 lies along 270 degrees, runway 09
/// is the same strip of concrete approached from the other end. What a
/// take-off or landing cares about is the wind across the runway, which a
/// crosswind limit is written against, and the wind along it, which shortens
/// or lengthens the ground roll.

///|
/// One runway, by its designator and magnetic heading.
pub struct Runway {
  /// The designator as written, such as `27` or `09L`.
  designator : String
  /// The magnetic heading of the runway, in degrees: two digits times ten.
  heading : Int
}

///|
pub fn Runway::designator(self : Runway) -> String {
  self.designator
}

///|
pub fn Runway::heading(self : Runway) -> Int {
  self.heading
}

///|
/// The runway at the other end of the same strip, if it has one: runway 09 is
/// the reciprocal of runway 27, and the other way round. Every runway pair
/// has one, but some one-way strips carry no designator.
pub fn Runway::reciprocal(self : Runway) -> Runway? {
  let mut heading = (self.heading + 180) % 360
  if heading == 0 {
    // The other end of runway 18 is runway 36, heading 360 degrees.
    heading = 360
  }
  let digits = two_runway_digits(heading)
  let side = side_of(self.designator)
  match (digits, side) {
    (Some(designator), None) => Some({ designator, heading, })
    (Some(designator), Some(side)) =>
      Some({ designator: designator + side, heading, })
    _ => None
  }
}

///|
/// The `L`, `C` or `R` of a parallel-runway designator, if it carries one.
fn side_of(designator : String) -> String? {
  let n = designator.length()
  if n > 0 &&
    (
      designator[n - 1] == 'L' ||
      designator[n - 1] == 'C' ||
      designator[n - 1] == 'R'
    ) {
    Some(designator[n - 1:n].to_owned())
  } else {
    None
  }
}

///|
/// Two decimal digits, zero padded, for a runway heading.
fn two_runway_digits(heading : Int) -> String? {
  if heading % 10 != 0 {
    return None
  }
  let number = heading / 10
  if number < 1 || number > 36 {
    return None
  }
  let tens = number / 10
  let ones = number % 10
  Some(
    String::from_array([
      ('0'.to_int() + tens).unsafe_to_char(),
      ('0'.to_int() + ones).unsafe_to_char(),
    ]),
  )
}

///|
/// A runway from its designator, such as `27`, `09L` or `36`.
///
/// The designator is a runway number from 01 to 36 — its heading in tens of
/// degrees — optionally followed by `L`, `C` or `R` for one of a set of
/// parallel runways. Anything else is not a runway, and parses to `None`.
pub fn Runway::parse(designator : String) -> Runway? {
  let n = designator.length()
  let mut digits = 0
  while digits < n && designator[digits] >= '0' && designator[digits] <= '9' {
    digits += 1
  }
  if digits == 0 || digits > 2 {
    return None
  }
  let number = match parse_digits(designator[0:digits].to_owned()) {
    Some(value) => value
    None => return None
  }
  if number < 1 || number > 36 {
    return None
  }
  match side_of(designator) {
    Some(_) => if digits + 1 != n { return None }
    None => if digits != n { return None }
  }
  Some({ designator, heading: number * 10, })
}

///|
/// The value of a string of one or two digits.
fn parse_digits(text : String) -> Int? {
  if text.length() == 0 {
    return None
  }
  let mut value = 0
  for i = 0; i < text.length(); i = i + 1 {
    let c = text[i]
    if c < '0' || c > '9' {
      return None
    }
    value = value * 10 + (c.to_int() - '0'.to_int())
  }
  Some(value)
}

///|
/// The wind along the runway, in knots, positive against the landing or
/// take-off direction.
pub fn Runway::headwind(self : Runway, wind : Wind) -> Double {
  WindVector::from_wind(wind).headwind_component(self.heading.to_double())
}

///|
/// The wind across the runway, in knots, positive from the right of the
/// landing or take-off direction.
pub fn Runway::crosswind(self : Runway, wind : Wind) -> Double {
  WindVector::from_wind(wind).crosswind_component(self.heading.to_double())
}
