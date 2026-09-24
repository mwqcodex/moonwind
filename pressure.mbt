///|
/// Pressure and altitude: the pressure a station reports, the sea-level
/// pressure that makes two stations comparable, and the altitudes a barometer
/// and an altimeter are read against.
///
/// A barometer reads the pressure where it stands, which falls with elevation,
/// so a station high up reports a lower number than one at the coast on the
/// same day. Reducing the reading to sea level takes the elevation back out,
/// and the altimeter setting is the same reduction read the other way: the
/// pressure the station would report at sea level, which an aircraft's
/// altimeter is set to so that it reads the elevation of the field it is
/// standing on.
///
/// The other two altitudes come out of the standard atmosphere rather than out
/// of a station: the pressure altitude is the height the standard atmosphere
/// has that pressure at, equivalently the altitude an altimeter set to
/// 1013.25 hPa reads, and the density altitude is the height the standard
/// atmosphere has that air density at, which is what a wing and an engine are
/// really working in — warm and damp air both thin it, and the two together
/// raise the density altitude by hundreds of feet.
///
/// Pressures are in hectopascals unless the name says otherwise, elevations and
/// altitudes are in metres unless the name says feet, and temperatures are in
/// degrees Celsius.

///|
/// Air whose pressure will not do: a station standing above the standard
/// troposphere, where the reduction has no answer.
pub suberror PressureError {
  /// An altimeter setting is only defined below 44330.77 m, the height at
  /// which the standard troposphere would reach absolute zero. The payload is
  /// the offending elevation in metres.
  ElevationTooHigh(Double)
}

///|
/// The pressure of the standard atmosphere at sea level, in hectopascals.
let standard_pressure_hpa : Double = 1013.25

///|
/// Hectopascals in an inch of mercury: 25.4 millimetres, which is what the
/// conventional 33.86388640341 comes from.
let hectopascals_per_inch_of_mercury : Double = 33.86388640341

///|
/// Hectopascals in a millimetre of mercury.
let hectopascals_per_millimeter_of_mercury : Double = 1.33322387415

///|
/// Standard gravity, in metres per second squared.
let standard_gravity : Double = 9.80665

///|
/// The gas constant of dry air, in joules per kilogram per kelvin.
let dry_air_gas_constant : Double = 287.05

///|
/// The temperature lapse rate of the standard troposphere, in degrees Celsius
/// per metre.
let temperature_lapse_rate : Double = 0.0065

///|
/// The kelvin of 0 °C.
let kelvin_offset : Double = 273.15

///|
/// The sea level temperature of the standard atmosphere, in kelvin.
let sea_level_temperature_kelvin : Double = 288.15

///|
/// The exponent that turns a pressure ratio into a height in the standard
/// atmosphere, 5.25588: `g / (R·L)` at the gas constant the altimetry tables
/// are built on, 287.05287, rather than at the 287.05 the sea-level reduction
/// above uses.
let isa_pressure_exponent : Double = 5.25588

///|
/// The height of the standard troposphere at absolute zero, in feet — 44330.77
/// m — which is the coefficient that writes a pressure ratio as a pressure
/// altitude.
let pressure_altitude_coefficient : Double = 145442.16

///|
/// The height at which the standard troposphere would reach absolute zero, in
/// metres: 288.15 / 0.0065 m, above which the altimeter setting has no answer.
let maximum_elevation_meters : Double = 44330.77

///|
/// How much the density altitude moves per degree away from the standard
/// atmosphere's temperature, in feet: the rule of thumb that a pilot reads a
/// density altitude off, 120 ft per degree Celsius.
let density_altitude_temperature_step : Double = 120.0

///|
/// The density of moist air against the density of dry air at the same
/// pressure and virtual temperature, `1 − 0.378`: a water molecule is lighter
/// than the air it displaces, so vapour makes air thinner.
let water_vapor_density_factor : Double = 0.378

///|
/// Hectopascals to inches of mercury, the unit an altimeter setting is
/// published in over much of the world.
pub fn hectopascals_to_inches_of_mercury(hectopascals : Double) -> Double {
  hectopascals / hectopascals_per_inch_of_mercury
}

///|
/// Inches of mercury to hectopascals.
pub fn inches_of_mercury_to_hectopascals(inches_of_mercury : Double) -> Double {
  inches_of_mercury * hectopascals_per_inch_of_mercury
}

///|
/// Hectopascals to millimetres of mercury, which is the same unit as the
/// torr.
pub fn hectopascals_to_millimeters_of_mercury(hectopascals : Double) -> Double {
  hectopascals / hectopascals_per_millimeter_of_mercury
}

///|
/// Millimetres of mercury to hectopascals.
pub fn millimeters_of_mercury_to_hectopascals(
  millimeters_of_mercury : Double,
) -> Double {
  millimeters_of_mercury * hectopascals_per_millimeter_of_mercury
}

///|
/// The sea-level pressure of a station reporting `station_pressure_hpa` at
/// `elevation_meters` with an air temperature of `celsius`, in hectopascals:
/// the reading with the weight of the air below it added back.
///
/// The value is the reduction the World Meteorological Organization specifies,
/// `P·exp(g·z / (R·(T + L·z/2)))`, which takes the column of air between the
/// station and the sea to warm at half the standard lapse rate — the best a
/// station can say about a column it only has one temperature from. A station
/// at sea level reduces to itself.
///
/// The water in the air is left out of it: vapour lightens the column by a
/// tenth of a percent at ordinary humidity, less than the temperature of the
/// column moves the answer by.
pub fn mean_sea_level_pressure(
  station_pressure_hpa : Double,
  elevation_meters : Double,
  celsius : Double,
) -> Double {
  station_pressure_hpa *
  @math.exp(
    standard_gravity *
    elevation_meters /
    (
      dry_air_gas_constant *
      (
        celsius +
        kelvin_offset +
        temperature_lapse_rate * elevation_meters / 2.0
      )
    ),
  )
}

///|
/// The pressure a station at `elevation_meters` reports when the sea-level
/// pressure is `sea_level_pressure_hpa` and the air is at `celsius`, in
/// hectopascals: the inverse of `mean_sea_level_pressure`.
pub fn station_pressure(
  sea_level_pressure_hpa : Double,
  elevation_meters : Double,
  celsius : Double,
) -> Double {
  sea_level_pressure_hpa *
  @math.exp(
    -standard_gravity *
    elevation_meters /
    (
      dry_air_gas_constant *
      (
        celsius +
        kelvin_offset +
        temperature_lapse_rate * elevation_meters / 2.0
      )
    ),
  )
}

///|
/// The altimeter setting of a station reporting `station_pressure_hpa` at
/// `elevation_meters`, in hectopascals: the pressure the station would report
/// if it stood at sea level in the standard atmosphere, which is what an
/// aircraft's altimeter is set to.
///
/// The value is the barometric formula, `P·(288.15 / (288.15 − 0.0065·z))^5.25588`,
/// and it takes no temperature: the setting is defined so that an altimeter
/// standing at the field reads the elevation of the field, and the two
/// formulas cancel exactly when it does. A station in the standard atmosphere
/// at 500 m reports 954.61 hPa and has a setting of 1013.25.
///
/// An elevation of 44330.77 m or more is above the atmosphere the formula is
/// written for, and is refused rather than answered with a number that does
/// not exist.
pub fn altimeter_setting_hpa(
  station_pressure_hpa : Double,
  elevation_meters : Double,
) -> Double raise PressureError {
  if elevation_meters >= maximum_elevation_meters {
    raise PressureError::ElevationTooHigh(elevation_meters)
  }
  station_pressure_hpa *
  @math.pow(
    sea_level_temperature_kelvin /
    (sea_level_temperature_kelvin - temperature_lapse_rate * elevation_meters),
    isa_pressure_exponent,
  )
}

///|
/// The altimeter setting of a station reporting `station_pressure_hpa` at
/// `elevation_meters`, in inches of mercury, which is how it is read aloud in
/// North America.
pub fn altimeter_setting_inhg(
  station_pressure_hpa : Double,
  elevation_meters : Double,
) -> Double raise PressureError {
  hectopascals_to_inches_of_mercury(
    altimeter_setting_hpa(station_pressure_hpa, elevation_meters),
  )
}

///|
/// The pressure altitude of `pressure_hpa`, in feet: the height in the
/// standard atmosphere that has that pressure.
///
/// The value is `145442.16·(1 − (P/1013.25)^(1/5.25588))`, so the standard sea
/// level pressure reads 0 ft, the 850 hPa level reads 4,781 ft and the 700 hPa
/// level 9,882. An altimeter set to the standard sea level pressure reads it
/// directly.
pub fn pressure_altitude(pressure_hpa : Double) -> Double {
  pressure_altitude_coefficient *
  (
    1.0 -
    @math.pow(pressure_hpa / standard_pressure_hpa, 1.0 / isa_pressure_exponent)
  )
}

///|
/// The density altitude of air at `pressure_hpa` and `celsius`, in feet: the
/// height in the standard atmosphere that has that air density, which is what
/// an engine, a propeller and a wing are working in.
///
/// The value is the rule of thumb a pilot reads off a chart, the pressure
/// altitude plus 120 ft for every degree the air is warmer than the standard
/// atmosphere is at that altitude, so standard air at sea level reads 0 ft and
/// a 25 °C day at sea level reads 1,200. It reads a little high: the exact
/// answer for dry air on that day is 1,162 ft. The water in the air is left
/// out of this one as well — `density_altitude_with_dew_point` counts it, and
/// a damp day is a few hundred feet higher again.
pub fn density_altitude(pressure_hpa : Double, celsius : Double) -> Double {
  let altitude = pressure_altitude(pressure_hpa)
  altitude +
  density_altitude_temperature_step * (celsius - isa_temperature(altitude))
}

///|
/// The density altitude of air at `pressure_hpa`, `celsius` and a dew point of
/// `dew_point_celsius`, in feet: the same altitude as `density_altitude`,
/// read off the air's density rather than off the rule of thumb, and with the
/// water in it counted.
///
/// The vapour the dew point stands for lightens the air, so its density is
/// read at the virtual temperature the dry air alone would have to be at to
/// weigh the same, `T / (1 − 0.378·e/P)` with `e` the vapour pressure in
/// hectopascals, and the altitude is where the standard atmosphere has that
/// density. Saturated air at sea level on a 15 °C day reads 218 ft above the
/// dry-air answer, and 109 ft at 50 % humidity.
///
/// A dew point above the air temperature would make the air supersaturated and
/// is refused, as it is by `relative_humidity`.
pub fn density_altitude_with_dew_point(
  pressure_hpa : Double,
  celsius : Double,
  dew_point_celsius : Double,
) -> Double raise HumidityError {
  if dew_point_celsius > celsius {
    raise HumidityError::DewPointAboveTemperature(dew_point_celsius, celsius)
  }
  let virtual_temperature = (celsius + kelvin_offset) /
    (
      1.0 -
      water_vapor_density_factor *
      saturation_vapor_pressure(dew_point_celsius) /
      pressure_hpa
    )
  let density_ratio = pressure_hpa /
    standard_pressure_hpa *
    (sea_level_temperature_kelvin / virtual_temperature)
  pressure_altitude_coefficient *
  (1.0 - @math.pow(density_ratio, 1.0 / (isa_pressure_exponent - 1.0)))
}
