///|
/// Apparent temperature: the temperature the weather feels like, rather than
/// the one a thermometer reads.
///
/// Moving air carries heat away from skin, so a cold day feels colder in a
/// wind — that is the wind chill, written in the United States over Fahrenheit
/// and miles per hour and in Canada over Celsius and kilometres per hour, both
/// for a wind at 10 metres. Humid air cannot take sweat away, so a warm day
/// feels warmer: the heat index is the American regression of that, the
/// humidex is the Canadian one, and the apparent temperature is the Australian
/// Bureau of Meteorology's, which counts the wind as well as the humidity.
///
/// Every one of them is defined only where it was fitted, and answers `None`
/// outside that rather than extrapolating: the wind chill at or below 50 °F
/// (10 °C) with a wind above 3 mph (4.8 km/h), the heat index from 80 °F to
/// 112 °F. The humidex and the apparent temperature are defined over the whole
/// range of their inputs, less the negative ones, which are not inputs.
///
/// Temperatures are in degrees Celsius unless the name says Fahrenheit, speeds
/// are in the unit the name says, and a relative humidity is a percentage.

///|
/// Air whose apparent temperature will not do: a percentage that is not one,
/// or a wind that blows backwards.
pub suberror ApparentTemperatureError {
  /// A relative humidity is a percentage from 0 to 100, and this one is not.
  /// The payload is the offending percentage.
  BadRelativeHumidity(Double)
  /// A wind speed cannot be negative. The payload is the offending speed.
  BadWindSpeed(Double)
}

///|
/// The warmest air the wind chill is defined at, in degrees Fahrenheit.
let wind_chill_maximum_fahrenheit : Double = 50.0

///|
/// The slowest wind the wind chill is defined at, in miles per hour, which the
/// index excludes: below it there is too little wind to chill anything.
let wind_chill_minimum_miles_per_hour : Double = 3.0

///|
/// The warmest air the metric wind chill is defined at, in degrees Celsius.
let metric_wind_chill_maximum_celsius : Double = 10.0

///|
/// The slowest wind the metric wind chill is defined at, in kilometres per
/// hour, which the index excludes.
let metric_wind_chill_minimum_kilometers_per_hour : Double = 4.8

///|
/// The coldest air the heat index is defined at, in degrees Fahrenheit: below
/// it the index would only repeat the air temperature.
let heat_index_minimum_fahrenheit : Double = 80.0

///|
/// The warmest air the heat index regression was fitted over, in degrees
/// Fahrenheit.
let heat_index_maximum_fahrenheit : Double = 112.0

///|
/// The wind chill of air at `fahrenheit` moving at `miles_per_hour`, in
/// degrees Fahrenheit: how much colder the wind makes exposed skin feel.
///
/// The value is the formula the National Weather Service and Environment
/// Canada adopted in 2001, `35.74 + 0.6215·T − 35.75·V^0.16 +
/// 0.4275·T·V^0.16`, for a wind at 10 metres. It is defined at or below 50 °F
/// with a wind above 3 mph, and answers `None` outside that rather than
/// extrapolating into a chill the index does not stand behind.
pub fn wind_chill_fahrenheit(
  fahrenheit : Double,
  miles_per_hour : Double,
) -> Double? raise ApparentTemperatureError {
  if miles_per_hour < 0.0 {
    raise ApparentTemperatureError::BadWindSpeed(miles_per_hour)
  }
  if fahrenheit > wind_chill_maximum_fahrenheit ||
    miles_per_hour <= wind_chill_minimum_miles_per_hour {
    return None
  }
  let power = @math.pow(miles_per_hour, 0.16)
  Some(
    35.74 + 0.6215 * fahrenheit - 35.75 * power + 0.4275 * fahrenheit * power,
  )
}

///|
/// The wind chill of air at `celsius` moving at `kilometers_per_hour`, in
/// degrees Celsius: the same index as `wind_chill_fahrenheit`, written in the
/// units Canada reads it in, `13.12 + 0.6215·T − 11.37·V^0.16 +
/// 0.3965·T·V^0.16`.
///
/// It is defined at or below 10 °C with a wind above 4.8 km/h, and answers
/// `None` outside that.
pub fn wind_chill_celsius(
  celsius : Double,
  kilometers_per_hour : Double,
) -> Double? raise ApparentTemperatureError {
  if kilometers_per_hour < 0.0 {
    raise ApparentTemperatureError::BadWindSpeed(kilometers_per_hour)
  }
  if celsius > metric_wind_chill_maximum_celsius ||
    kilometers_per_hour <= metric_wind_chill_minimum_kilometers_per_hour {
    return None
  }
  let power = @math.pow(kilometers_per_hour, 0.16)
  Some(13.12 + 0.6215 * celsius - 11.37 * power + 0.3965 * celsius * power)
}

///|
/// The wind chill of a reported `wind` at `celsius`, in degrees Celsius: the
/// knots the data model keeps are converted to the kilometres per hour the
/// metric index is written in.
///
/// A light and variable wind — the one with no direction, a wind below 5 knots
/// — is answered with `None`, and so is a temperature above 10 °C.
pub fn wind_chill_from_wind(
  wind : Wind,
  celsius : Double,
) -> Double? raise ApparentTemperatureError {
  if wind.direction() is None {
    return None
  }
  wind_chill_celsius(
    celsius,
    knots_to_kilometers_per_hour(wind.speed().to_double()),
  )
}

///|
/// The heat index of air at `fahrenheit` holding `relative_humidity` percent
/// of the water it could, in degrees Fahrenheit: how much hotter the humidity
/// makes it feel.
///
/// The value is the Rothfusz regression the National Weather Service uses,
/// with the two corrections it applies at the ends of the humidity range — a
/// subtraction in very dry air, an addition in very damp air — and its
/// fallback of `0.5·(T + 61.0 + (T − 68.0)·1.2 + RH·0.094)` when the
/// regression comes out below 80 °F, where the index is the air temperature
/// rather than something felt.
///
/// It is defined from 80 °F to 112 °F, the range it was fitted over, and
/// answers `None` outside it. A relative humidity outside 0 to 100 is refused.
pub fn heat_index_fahrenheit(
  fahrenheit : Double,
  relative_humidity : Double,
) -> Double? raise ApparentTemperatureError {
  if relative_humidity < 0.0 || relative_humidity > 100.0 {
    raise ApparentTemperatureError::BadRelativeHumidity(relative_humidity)
  }
  if fahrenheit < heat_index_minimum_fahrenheit ||
    fahrenheit > heat_index_maximum_fahrenheit {
    return None
  }
  let mut index = -42.379 +
    2.04901523 * fahrenheit +
    10.14333127 * relative_humidity -
    0.22475541 * fahrenheit * relative_humidity -
    6.83783e-3 * fahrenheit * fahrenheit -
    5.481717e-2 * relative_humidity * relative_humidity +
    1.22874e-3 * fahrenheit * fahrenheit * relative_humidity +
    8.5282e-4 * fahrenheit * relative_humidity * relative_humidity -
    1.99e-6 * fahrenheit * fahrenheit * relative_humidity * relative_humidity
  // Both corrections carry a temperature range of their own, which the two
  // checks above have already narrowed to the 80 °F to 112 °F they want.
  if relative_humidity < 13.0 {
    index = index -
      (13.0 - relative_humidity) /
      4.0 *
      ((17.0 - (fahrenheit - 95.0).abs()) / 17.0).sqrt()
  }
  if relative_humidity > 85.0 {
    index = index +
      (relative_humidity - 85.0) / 10.0 * ((87.0 - fahrenheit) / 5.0)
  }
  if index < 80.0 {
    index = 0.5 *
      (
        fahrenheit +
        61.0 +
        (fahrenheit - 68.0) * 1.2 +
        relative_humidity * 0.094
      )
  }
  Some(index)
}

///|
/// The heat index of air at `celsius` holding `relative_humidity` percent of
/// the water it could, in degrees Celsius: `heat_index_fahrenheit` read in the
/// units the rest of the world uses.
///
/// The temperature is converted to Fahrenheit to be read against the range the
/// regression was fitted over, so an air temperature just below 26.7 °C is
/// outside it even though it looks like round numbers in Celsius.
pub fn heat_index_celsius(
  celsius : Double,
  relative_humidity : Double,
) -> Double? raise ApparentTemperatureError {
  match
    heat_index_fahrenheit(celsius_to_fahrenheit(celsius), relative_humidity) {
    Some(index) => Some(fahrenheit_to_celsius(index))
    None => None
  }
}

///|
/// The humidex of air at `celsius` whose dew point is `dew_point_celsius`, in
/// degrees Celsius: Environment Canada's index of how hot the humidity makes
/// it feel, `T + (5/9)·(e − 10)` with `e` the vapour pressure in hectopascals.
///
/// The vapour pressure is the saturation one at the dew point, which is the
/// vapour pressure of the air itself. A dew point above the air temperature
/// would make the air supersaturated and is refused, as it is by
/// `relative_humidity`.
pub fn humidex(
  celsius : Double,
  dew_point_celsius : Double,
) -> Double raise HumidityError {
  if dew_point_celsius > celsius {
    raise HumidityError::DewPointAboveTemperature(dew_point_celsius, celsius)
  }
  celsius + 5.0 / 9.0 * (saturation_vapor_pressure(dew_point_celsius) - 10.0)
}

///|
/// The apparent temperature of air at `celsius` holding `relative_humidity`
/// percent, with a wind of `wind_speed_meters_per_second` at 10 metres, in
/// degrees Celsius: what the Bureau of Meteorology calls "feels like".
///
/// The value is the Bureau's `T + 0.33·e − 0.70·ws − 4.00`, with `e` the part
/// of the saturation vapour pressure that the humidity holds, both in the
/// units above. The Bureau computes its own vapour pressure; this one is the
/// Magnus form the rest of the humidity calculations use, which differs from
/// it by at most 0.07 hPa at 30 °C, and by 0.02 °C in the result.
pub fn apparent_temperature(
  celsius : Double,
  relative_humidity : Double,
  wind_speed_meters_per_second : Double,
) -> Double raise ApparentTemperatureError {
  if relative_humidity < 0.0 || relative_humidity > 100.0 {
    raise ApparentTemperatureError::BadRelativeHumidity(relative_humidity)
  }
  if wind_speed_meters_per_second < 0.0 {
    raise ApparentTemperatureError::BadWindSpeed(wind_speed_meters_per_second)
  }
  celsius +
  0.33 * (relative_humidity / 100.0 * saturation_vapor_pressure(celsius)) -
  0.70 * wind_speed_meters_per_second -
  4.00
}
