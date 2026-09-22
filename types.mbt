///|
/// Errors raised while reading or writing winds-aloft (FD) bulletins.
pub suberror FdError {
  /// A required header line (the `FT` column header) is missing.
  MissingLevelHeader
  /// The `FT` header lists no usable levels.
  BadLevelHeader(String)
  /// A station line is too short or its identifier is malformed.
  BadStationLine(String)
  /// A wind group is not four digits, or decodes outside the valid range.
  BadWindGroup(String)
  /// A temperature field is malformed.
  BadTemperature(String)
}

///|
/// One upper-air wind: the direction the wind blows *from*, in degrees true,
/// and its speed in knots.
///
/// `direction` is `None` for a light and variable wind (encoded `9900`),
/// which is a wind below 5 knots with no useful direction. Directions are
/// always multiples of 10 degrees, as the wire format carries tens of
/// degrees.
pub struct Wind {
  direction : Int?
  speed : Int
}

///|
/// One forecast level of a station: the altitude in feet above mean sea
/// level, the wind, and the temperature in degrees Celsius. `temperature` is
/// `None` when the product does not forecast one, which is always the case at
/// 3,000 ft and at levels close to the station elevation.
pub struct Level {
  altitude : Int
  wind : Wind
  temperature : Int?
}

///|
/// The winds and temperatures aloft forecast for one station.
///
/// `levels` holds only the altitudes the product actually reports for this
/// station; a missing level is simply absent, exactly as a blank column in
/// the bulletin.
pub struct StationWinds {
  station : String
  levels : Array[Level]
}

///|
/// A parsed winds and temperatures aloft bulletin, such as the `FD1US1`
/// product.
///
/// The header lines are kept verbatim so that `format_bulletin` reproduces
/// the original text byte for byte.
pub struct Bulletin {
  /// Every line before the `FT` column header, verbatim.
  header : Array[String]
  /// The `FT` column header line, verbatim.
  level_header : String
  /// Forecast levels in column order, in feet MSL, parsed from `level_header`.
  altitudes : Array[Int]
  /// The WMO abbreviated heading, such as `FBUS31 KWNO 221358`.
  wmo_header : String?
  /// The product designator, such as `FD1US1`.
  designator : String?
  /// The `DATA BASED ON ...Z` observation time, when present.
  based_on : String?
  /// The `VALID ...Z` valid time, when present.
  valid : String?
  /// The `FOR USE ...Z` usable window, when present.
  use_window : String?
  /// The altitude above which temperatures are reported without a sign,
  /// parsed from `TEMPS NEG ABV n`; 24,000 ft in current products.
  temps_negative_above : Int?
  stations : Array[StationWinds]
  /// Lines after the last station line, verbatim. Present in some products,
  /// which end with a list of stations that were not received.
  trailing : Array[String]
}

///|
/// Accessors.
pub fn Wind::direction(self : Wind) -> Int? {
  self.direction
}

///|
pub fn Wind::speed(self : Wind) -> Int {
  self.speed
}

///|
/// Whether this wind is a light and variable report (`9900`).
pub fn Wind::is_light_and_variable(self : Wind) -> Bool {
  self.direction is None && self.speed == 0
}

///|
pub fn Level::altitude(self : Level) -> Int {
  self.altitude
}

///|
pub fn Level::wind(self : Level) -> Wind {
  self.wind
}

///|
pub fn Level::temperature(self : Level) -> Int? {
  self.temperature
}

///|
pub fn StationWinds::station(self : StationWinds) -> String {
  self.station
}

///|
pub fn StationWinds::levels(self : StationWinds) -> Array[Level] {
  self.levels
}

///|
/// The level at exactly `altitude` feet, if the station reports one.
pub fn StationWinds::level_at(self : StationWinds, altitude : Int) -> Level? {
  for level in self.levels {
    if level.altitude == altitude {
      return Some(level)
    }
  }
  None
}

///|
pub fn Bulletin::stations(self : Bulletin) -> Array[StationWinds] {
  self.stations
}

///|
/// The forecast for one station, by its three-character identifier.
pub fn Bulletin::station(self : Bulletin, id : String) -> StationWinds? {
  for station in self.stations {
    if station.station == id {
      return Some(station)
    }
  }
  None
}
