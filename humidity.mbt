///|
/// Humidity: how much water the air holds, and the temperatures that say so.
///
/// Saturation vapour pressure is the pressure the water vapour in the air has
/// when the air holds as much as it can at that temperature. A dew point is
/// the temperature the air would have to be cooled to for that to happen, so
/// the two say the same thing in different words; relative humidity is how far
/// the air is from that state, the frost point is the dew point read against
/// ice rather than water, the wet-bulb temperature is what a wet thermometer
/// reads in moving air, and the absolute humidity is the mass of vapour in a
/// cubic metre.
///
/// They are all read off one Magnus form, from Alduchov and Eskridge (1996),
/// so that a vapour pressure and its dew point are exact inverses of each
/// other: `6.1094 · exp(17.625·T / (T + 243.04))` over water and
/// `6.1121 · exp(22.587·T / (T + 273.86))` over ice, both in hectopascals.
/// Bolton's more common `6.112 · exp(17.67·T / (T + 243.5))` differs from it
/// by less than half a percent at room temperature.
///
/// Temperatures are in degrees Celsius, relative humidity is a percentage and
/// pressures are in hectopascals.

///|
/// Air whose humidity will not do: a percentage that is not one, or a parcel
/// that is already supersaturated.
pub suberror HumidityError {
  /// A relative humidity is a percentage above zero and at most 100, and this
  /// one is not. The payload is the offending percentage. Air that holds no
  /// water at all has no dew point — it would have to be infinitely cold — so
  /// a humidity of zero is refused along with the percentages beyond the
  /// range.
  BadRelativeHumidity(Double)
  /// A parcel whose dew point is above its own temperature would be
  /// supersaturated, which no report of one means. The payloads are the dew
  /// point and the temperature, in degrees Celsius.
  DewPointAboveTemperature(Double, Double)
}

///|
/// The vapour pressure of water at 0 °C, in hectopascals: where the Magnus
/// curve over water passes through.
let water_reference_pressure : Double = 6.1094

///|
/// The pressure coefficient `a` of the Magnus form over water.
let water_pressure_coefficient : Double = 17.625

///|
/// The temperature coefficient `b` of the Magnus form over water, in degrees
/// Celsius.
let water_temperature_coefficient : Double = 243.04

///|
/// The vapour pressure of ice at 0 °C, in hectopascals.
let ice_reference_pressure : Double = 6.1121

///|
/// The pressure coefficient `a` of the Magnus form over ice.
let ice_pressure_coefficient : Double = 22.587

///|
/// The temperature coefficient `b` of the Magnus form over ice, in degrees
/// Celsius.
let ice_temperature_coefficient : Double = 273.86

///|
/// The coldest air Stull's wet-bulb fit is defined at, in degrees Celsius.
let wet_bulb_minimum_temperature : Double = -20.0

///|
/// The warmest air Stull's wet-bulb fit is defined at, in degrees Celsius.
let wet_bulb_maximum_temperature : Double = 50.0

///|
/// The driest air Stull's wet-bulb fit is defined at, in percent.
let wet_bulb_minimum_humidity : Double = 5.0

///|
/// The most humid air Stull's wet-bulb fit is defined at, in percent.
let wet_bulb_maximum_humidity : Double = 99.0

///|
/// The molar mass of water, in grams per mole.
let water_molar_mass : Double = 18.01528

///|
/// The molar gas constant, in joules per mole kelvin.
let ideal_gas_constant : Double = 8.314462618

///|
/// The vapour pressure of air saturated with water at `celsius`, in
/// hectopascals: how much pressure its water vapour would have if the air held
/// all it can at that temperature.
///
/// This is also the actual vapour pressure of air whose dew point is
/// `celsius`, which is how the relative humidity and the dew point are read
/// off it.
pub fn saturation_vapor_pressure(celsius : Double) -> Double {
  water_reference_pressure *
  @math.exp(
    water_pressure_coefficient *
    celsius /
    (celsius + water_temperature_coefficient),
  )
}

///|
/// The vapour pressure of air saturated with respect to ice at `celsius`, in
/// hectopascals.
///
/// Below freezing the air saturates against ice rather than water, and the
/// pressure over ice is the lower of the two — 2.597 hPa against 2.868 hPa at
/// −10 °C — so a frost point sits above the dew point at the same humidity.
pub fn saturation_vapor_pressure_over_ice(celsius : Double) -> Double {
  ice_reference_pressure *
  @math.exp(
    ice_pressure_coefficient * celsius / (celsius + ice_temperature_coefficient),
  )
}

///|
/// The dew point of air at `celsius` holding `relative_humidity` percent of
/// the water it could, in degrees Celsius: the temperature it would have to be
/// cooled to for the vapour to begin condensing.
///
/// The relative humidity has to be above zero and at most 100.
pub fn dew_point(
  celsius : Double,
  relative_humidity : Double,
) -> Double raise HumidityError {
  if relative_humidity <= 0.0 || relative_humidity > 100.0 {
    raise HumidityError::BadRelativeHumidity(relative_humidity)
  }
  let gamma = @math.ln(
    relative_humidity /
    100.0 *
    saturation_vapor_pressure(celsius) /
    water_reference_pressure,
  )
  water_temperature_coefficient * gamma / (water_pressure_coefficient - gamma)
}

///|
/// The relative humidity of air at `celsius` whose dew point is
/// `dew_point_celsius`, in percent: how much of the water it could hold it is
/// holding.
///
/// A dew point above the temperature would be supersaturated, which is
/// refused rather than reported as a humidity above 100.
pub fn relative_humidity(
  celsius : Double,
  dew_point_celsius : Double,
) -> Double raise HumidityError {
  if dew_point_celsius > celsius {
    raise HumidityError::DewPointAboveTemperature(dew_point_celsius, celsius)
  }
  100.0 *
  saturation_vapor_pressure(dew_point_celsius) /
  saturation_vapor_pressure(celsius)
}

///|
/// The frost point of air at `celsius` holding `relative_humidity` percent of
/// the water it could, in degrees Celsius: the temperature at which the vapour
/// would begin to deposit as ice.
///
/// Below freezing this sits above the dew point of the same air, because the
/// vapour pressure over ice is the lower of the two.
pub fn frost_point(
  celsius : Double,
  relative_humidity : Double,
) -> Double raise HumidityError {
  if relative_humidity <= 0.0 || relative_humidity > 100.0 {
    raise HumidityError::BadRelativeHumidity(relative_humidity)
  }
  let gamma = @math.ln(
    relative_humidity /
    100.0 *
    saturation_vapor_pressure(celsius) /
    ice_reference_pressure,
  )
  ice_temperature_coefficient * gamma / (ice_pressure_coefficient - gamma)
}

///|
/// The wet-bulb temperature of air at `celsius` holding `relative_humidity`
/// percent of the water it could, in degrees Celsius: what a thermometer reads
/// with a wet wick over it in moving air, which evaporation cools below the
/// air temperature.
///
/// The value is Stull's fit (2011), `T·atan(0.151977·√(RH + 8.313659)) +
/// atan(T + RH) − atan(RH − 1.676331) + 0.00391838·RH^1.5·atan(0.023101·RH) −
/// 4.686035`, with the angles in radians. It is fitted over 5 % to 99 %
/// humidity and −20 °C to 50 °C, and answers `None` outside that, where it is
/// an extrapolation. Saturated air is outside it too: the fit drifts there,
/// and the wet-bulb temperature of saturated air is the air temperature
/// itself.
pub fn wet_bulb_temperature(
  celsius : Double,
  relative_humidity : Double,
) -> Double? {
  if celsius < wet_bulb_minimum_temperature ||
    celsius > wet_bulb_maximum_temperature ||
    relative_humidity < wet_bulb_minimum_humidity ||
    relative_humidity > wet_bulb_maximum_humidity {
    return None
  }
  Some(
    celsius * @math.atan(0.151977 * (relative_humidity + 8.313659).sqrt()) +
    @math.atan(celsius + relative_humidity) -
    @math.atan(relative_humidity - 1.676331) +
    0.00391838 *
    @math.pow(relative_humidity, 1.5) *
    @math.atan(0.023101 * relative_humidity) -
    4.686035,
  )
}

///|
/// How much water a cubic metre of air at `celsius` holds when its vapour
/// pressure is `vapor_pressure_hpa`, in grams per cubic metre.
///
/// The vapour pressure is what the dew point is: `saturation_vapor_pressure`
/// of it gives the vapour pressure of saturated air, and half of that is air
/// at 50 % humidity.
pub fn absolute_humidity(
  vapor_pressure_hpa : Double,
  celsius : Double,
) -> Double {
  vapor_pressure_hpa *
  100.0 *
  water_molar_mass /
  (ideal_gas_constant * (celsius + 273.15))
}
