///|
/// Wind barbs: a wind drawn on a station plot as a staff with feathers, rather
/// than written as a number.
///
/// The staff points into the wind, and the feathers count the speed in the
/// increments a station plot has room for: a half barb for 5 knots, a full barb
/// for 10, and a pennant for 50. A 25 kt wind is two full barbs and a half one;
/// a 65 kt wind is a pennant and one of each. A calm is drawn as a circle with
/// no staff at all.
///
/// This type holds the barb rather than the picture: the direction in tens of
/// degrees, which is the direction the staff points along, and the three counts
/// the feathers are made of. The direction is `0` when the wind has none — a
/// light and variable report — and `36` for a wind out of the north, which is
/// how a station plot writes 360°, so that a direction that comes in as 0°
/// reads back out as 0°.
///
/// The speed is drawn to the nearest 5 knots, which is all the feathers can
/// say: a 12 kt wind is drawn as 10 and a 3 kt wind as 5, so a barb read back
/// with `to_wind` is that rounded speed and not the one it was made from. A
/// wind below 2.5 kt is drawn as a bare staff.
///
/// `to_unicode` draws the barb with the characters a station plot uses —
/// `⚑ ─ ╌ │ ○` — and `to_ascii` spells the same barb with characters every
/// font has, for the terminal that has no glyph for a pennant.

///|
/// A wind whose speed will not do: the feathers count a speed, and a negative
/// one is not a speed.
pub suberror WindBarbError {
  /// A wind speed cannot be negative. The payload is the offending speed.
  BadWindSpeed(Double)
}

///|
/// A wind drawn as a barb: the direction the staff points along, in tens of
/// degrees, and the pennants, full barbs and half barbs hanging off it.
pub struct WindBarb {
  direction_tens : Int
  pennants : Int
  full_barbs : Int
  half_barbs : Int
}

///|
/// A pennant: 50 knots.
let pennant_unicode : String = "⚑"

///|
/// A full barb: 10 knots.
let full_barb_unicode : String = "─"

///|
/// A half barb: 5 knots.
let half_barb_unicode : String = "╌"

///|
/// The staff the feathers hang off.
let staff_unicode : String = "│"

///|
/// A calm: no staff and no feathers.
let calm_unicode : String = "○"

///|
/// A pennant in characters every font has.
let pennant_ascii : String = "P"

///|
/// A full barb in characters every font has.
let full_barb_ascii : String = "="

///|
/// A half barb in characters every font has.
let half_barb_ascii : String = "-"

///|
/// The staff in characters every font has.
let staff_ascii : String = "|"

///|
/// A calm in characters every font has.
let calm_ascii : String = "O"

///|
/// The knots a pennant counts.
let knots_per_pennant : Int = 50

///|
/// The knots a full barb counts.
let knots_per_full_barb : Int = 10

///|
/// The knots a half barb counts.
let knots_per_half_barb : Int = 5

///|
/// The direction a wind out of the north is written as, in tens of degrees:
/// 36, so that 0 can mean "no direction" and still be told apart from it.
let north_direction_tens : Int = 36

///|
/// The wind barb of a reported `wind`: its direction in tens of degrees and its
/// speed counted out in pennants, full barbs and half barbs.
pub fn WindBarb::from_wind(wind : Wind) -> WindBarb raise WindBarbError {
  WindBarb::from_knots(wind.direction(), wind.speed().to_double())
}

///|
/// The wind barb of a wind from `direction` degrees at `knots`, for a caller
/// that has the two numbers rather than a `Wind` to report. A direction of
/// `None` is written as no direction at all — tens of 0 — and a direction of
/// 0 degrees, the north, as 36.
pub fn WindBarb::from_knots(
  direction : Int?,
  knots : Double,
) -> WindBarb raise WindBarbError {
  if knots < 0.0 {
    raise WindBarbError::BadWindSpeed(knots)
  }
  let direction_tens = match direction {
    None => 0
    Some(degrees) =>
      if degrees == 0 {
        north_direction_tens
      } else {
        degrees / 10
      }
  }
  // The feathers are drawn to the nearest 5 knots: a pennant is ten steps of
  // five, a full barb two and a half barb one.
  let steps = @math.round(knots / 5.0).to_int()
  {
    direction_tens,
    pennants: steps / 10,
    full_barbs: steps % 10 / 2,
    half_barbs: steps % 2,
  }
}

///|
/// The direction the staff points along, in tens of degrees: 0 when the wind
/// has no direction, 36 for a wind out of the north, and otherwise the
/// direction over ten.
pub fn WindBarb::direction_tens(self : WindBarb) -> Int {
  self.direction_tens
}

///|
/// How many pennants hang off the staff, each of them 50 knots.
pub fn WindBarb::pennants(self : WindBarb) -> Int {
  self.pennants
}

///|
/// How many full barbs hang off the staff, each of them 10 knots.
pub fn WindBarb::full_barbs(self : WindBarb) -> Int {
  self.full_barbs
}

///|
/// How many half barbs hang off the staff, each of them 5 knots.
pub fn WindBarb::half_barbs(self : WindBarb) -> Int {
  self.half_barbs
}

///|
/// The speed the feathers count, in knots: the pennants at 50, the full barbs
/// at 10 and the half barbs at 5, which is the speed the barb was drawn from
/// rounded to the nearest 5 knots.
pub fn WindBarb::speed_knots(self : WindBarb) -> Double {
  (self.pennants * knots_per_pennant +
  self.full_barbs * knots_per_full_barb +
  self.half_barbs * knots_per_half_barb).to_double()
}

///|
/// Whether the barb is a calm: no wind at all, which a station plot draws as a
/// circle with no staff. A wind with a direction but too little speed to draw a
/// feather is not a calm — it has a staff, and it points somewhere.
pub fn WindBarb::is_calm(self : WindBarb) -> Bool {
  self.direction_tens == 0 && self.speed_knots() == 0.0
}

///|
/// The wind the barb was drawn from, as far as the drawing can say: the speed
/// rounded to the nearest 5 knots, and the direction the tens stand for — none
/// for 0, north for 36, and the tens of degrees otherwise.
pub fn WindBarb::to_wind(self : WindBarb) -> Wind {
  let direction = if self.direction_tens == 0 {
    None
  } else if self.direction_tens == north_direction_tens {
    Some(0)
  } else {
    Some(self.direction_tens * 10)
  }
  Wind::new(direction, self.speed_knots().to_int())
}

///|
/// The barb drawn with the characters a station plot uses: a pennant `⚑`, a
/// full barb `─`, a half barb `╌`, the staff `│` they hang off, and a circle
/// `○` for a calm. The feathers come in that order along the staff.
pub fn WindBarb::to_unicode(self : WindBarb) -> String {
  self.render(
    pennant_unicode, full_barb_unicode, half_barb_unicode, staff_unicode, calm_unicode,
  )
}

///|
/// The barb drawn with characters every font has — `P` for a pennant, `=` for
/// a full barb, `-` for a half barb, `|` for the staff and `O` for a calm —
/// for a terminal with no glyph for a pennant or a box-drawing line.
pub fn WindBarb::to_ascii(self : WindBarb) -> String {
  self.render(
    pennant_ascii, full_barb_ascii, half_barb_ascii, staff_ascii, calm_ascii,
  )
}

///|
/// The barb drawn with the given glyphs: the feathers the counts call for, in
/// pennants, full barbs and half barbs, then the staff — or the calm glyph
/// alone when there is no wind to draw.
fn WindBarb::render(
  self : WindBarb,
  pennant : String,
  full_barb : String,
  half_barb : String,
  staff : String,
  calm : String,
) -> String {
  if self.is_calm() {
    return calm
  }
  let out = StringBuilder(
    size_hint=self.pennants + self.full_barbs + self.half_barbs + 1,
  )
  append_glyphs(out, pennant, self.pennants)
  append_glyphs(out, full_barb, self.full_barbs)
  append_glyphs(out, half_barb, self.half_barbs)
  out.write_string(staff)
  out.to_string()
}

///|
/// `glyph` written `count` times.
fn append_glyphs(out : StringBuilder, glyph : String, count : Int) -> Unit {
  for i = 0; i < count; i = i + 1 {
    out.write_string(glyph)
  }
}
