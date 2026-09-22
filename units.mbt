///|
/// Unit conversions and the standard atmosphere.
///
/// The bulletins are written in knots, feet above mean sea level and degrees
/// Celsius, and that is what the data model keeps. These helpers convert to
/// the units a display, a flight plan or a downstream calculation asks for,
/// and give the standard-atmosphere temperature that a reported temperature
/// is compared against.

///|
/// Knots to metres per second.
pub fn knots_to_meters_per_second(knots : Double) -> Double {
  knots * 1852.0 / 3600.0
}

///|
/// Metres per second to knots.
pub fn meters_per_second_to_knots(meters_per_second : Double) -> Double {
  meters_per_second * 3600.0 / 1852.0
}

///|
/// Knots to kilometres per hour.
pub fn knots_to_kilometers_per_hour(knots : Double) -> Double {
  knots * 1852.0 / 1000.0
}

///|
/// Kilometres per hour to knots.
pub fn kilometers_per_hour_to_knots(kilometers_per_hour : Double) -> Double {
  kilometers_per_hour * 1000.0 / 1852.0
}

///|
/// Knots to statute miles per hour.
pub fn knots_to_miles_per_hour(knots : Double) -> Double {
  knots * 1.150779
}

///|
/// Statute miles per hour to knots.
pub fn miles_per_hour_to_knots(miles_per_hour : Double) -> Double {
  miles_per_hour / 1.150779
}

///|
/// Feet to metres.
pub fn feet_to_meters(feet : Double) -> Double {
  feet * 0.3048
}

///|
/// Metres to feet.
pub fn meters_to_feet(meters : Double) -> Double {
  meters / 0.3048
}

///|
/// Degrees Celsius to degrees Fahrenheit.
pub fn celsius_to_fahrenheit(celsius : Double) -> Double {
  celsius * 9.0 / 5.0 + 32.0
}

///|
/// Degrees Fahrenheit to degrees Celsius.
pub fn fahrenheit_to_celsius(fahrenheit : Double) -> Double {
  (fahrenheit - 32.0) * 5.0 / 9.0
}

///|
/// Sea level temperature of the international standard atmosphere, in
/// degrees Celsius.
let isa_sea_level_temperature : Double = 15.0

///|
/// Temperature lapse rate of the standard atmosphere, in degrees Celsius per
/// thousand feet, up to the tropopause.
let isa_lapse_rate : Double = 1.9812

///|
/// The tropopause of the standard atmosphere, in feet.
let isa_tropopause : Double = 36089.0

///|
/// The temperature of the standard atmosphere above the tropopause, in
/// degrees Celsius.
let isa_tropopause_temperature : Double = -56.5

///|
/// The temperature of the international standard atmosphere at `feet`, in
/// degrees Celsius: 15 °C at sea level, falling by 1.9812 °C per thousand feet
/// to the tropopause at 36,089 ft, and constant at −56.5 °C above it.
pub fn isa_temperature(feet : Double) -> Double {
  if feet >= isa_tropopause {
    isa_tropopause_temperature
  } else {
    isa_sea_level_temperature - isa_lapse_rate * feet / 1000.0
  }
}

///|
/// How much warmer than the standard atmosphere `celsius` is at `feet`, in
/// degrees Celsius: the ISA deviation a flight plan quotes, positive in warm
/// air.
pub fn isa_deviation(celsius : Double, feet : Double) -> Double {
  celsius - isa_temperature(feet)
}
