///|
/// Reading and writing winds and temperatures aloft (FD) bulletins.
///
/// A bulletin is a fixed-column text product: a few header lines, an `FT`
/// line listing the forecast levels, one line per station, and optionally
/// trailing notes. The column layout is *derived* from the `FT` line rather
/// than hard-coded, so the same code reads the nine-level low-level products
/// (`FD1US1`) and the two-level high-level ones (`FD8US7`).
///
/// The wire format compresses the numbers:
///
/// * wind: `ddss`, tens of degrees and knots. For speeds of 100 knots or
///   more the encoder adds 50 to the direction, so a direction above 36 is
///   folded back by 50 and the speed gains 100. `9900` means light and
///   variable.
/// * temperature: `+TT` or `-TT` in degrees Celsius below 24,000 ft. At and
///   above 24,000 ft temperatures are always negative and the sign is
///   omitted, so the field is a bare two-digit magnitude.
/// * the 3,000 ft column carries no temperature at all.
///
/// A real product is a few hundred station lines of nine columns each, so
/// parsing walks the text once and reads every field through a `StringView`:
/// nothing is copied out of the text until a value is kept, which is what
/// keeps a parse of a 12 kB product in the hundreds of microseconds.

///|
/// The end of the line that starts at `start`, and where the line after it
/// starts.
///
/// A carriage return before the newline is not part of the line, so a product
/// that comes back from a server with CRLF endings parses the same way.
fn line_bounds(text : StringView, start : Int) -> (Int, Int) {
  let n = text.length()
  let mut end = start
  while end < n && text.at(end) != '\n' {
    end += 1
  }
  let mut content_end = end
  if content_end > start && text.at(content_end - 1) == '\r' {
    content_end -= 1
  }
  let next = if end < n { end + 1 } else { n }
  (content_end, next)
}

///|
/// The part of `text` after `prefix`, or `None` when it does not start with
/// it.
fn after_prefix(text : StringView, prefix : StringView) -> StringView? {
  if text.has_prefix(prefix) {
    Some(text[prefix.length():])
  } else {
    None
  }
}

///|
/// The text before the first blank, or the whole text when it has none.
fn first_token(text : StringView) -> StringView {
  let n = text.length()
  let mut i = 0
  while i < n && text.at(i) != ' ' && text.at(i) != '\t' {
    i += 1
  }
  text[0:i]
}

///|
/// Digits of `text`, or `None` when it is empty or holds anything else.
fn parse_int(text : StringView) -> Int? {
  let t = text.trim()
  if t.length() == 0 {
    return None
  }
  let mut v = 0
  for i = 0; i < t.length(); i = i + 1 {
    let c = t.at(i)
    if c < '0' || c > '9' {
      return None
    }
    v = v * 10 + (c.to_int() - '0'.to_int())
  }
  Some(v)
}

///|
/// A character of the station identifier alphabet: digits and capitals.
/// String indexing yields the UTF-16 code unit, hence the `UInt16`.
fn is_station_char(c : UInt16) -> Bool {
  let v = c.to_int()
  (v >= 'A'.to_int() && v <= 'Z'.to_int()) ||
  (v >= '0'.to_int() && v <= '9'.to_int())
}

///|
/// Whether a line looks like a station data line: three identifier
/// characters followed by a blank.
fn is_station_line(line : StringView) -> Bool {
  line.length() >= 4 &&
  is_station_char(line.at(0)) &&
  is_station_char(line.at(1)) &&
  is_station_char(line.at(2)) &&
  line.at(3) == ' '
}

///|
/// The column of each forecast level in a station line, as `(start, width)`.
///
/// The first field starts at column 4 (after the three-character station
/// identifier and a blank) and fields are separated by one blank. A field is
/// four characters wide when no temperature is carried (the 3,000 ft level),
/// six when the temperature is an unsigned magnitude above 24,000 ft, and
/// seven otherwise.
pub fn field_layout(altitudes : Array[Int]) -> Array[(Int, Int)] {
  let out : Array[(Int, Int)] = []
  let mut start = 4
  for altitude in altitudes {
    let width = if altitude == 3000 {
      4
    } else if altitude > 24000 {
      6
    } else {
      7
    }
    out.push((start, width))
    start = start + width + 1
  }
  out
}

///|
/// Two decimal digits starting at `at`.
fn digits2(text : StringView, at : Int) -> Int raise FdError {
  if at < 0 || at + 2 > text.length() {
    raise FdError::BadWindGroup(text.to_owned())
  }
  let hi = text.at(at)
  let lo = text.at(at + 1)
  if hi < '0' || hi > '9' || lo < '0' || lo > '9' {
    raise FdError::BadWindGroup(text.to_owned())
  }
  (hi.to_int() - '0'.to_int()) * 10 + (lo.to_int() - '0'.to_int())
}

///|
/// Decode the four-character wind group at the start of `group`.
fn decode_wind_group(group : StringView) -> Wind raise FdError {
  let dd = digits2(group, 0)
  let ss = digits2(group, 2)
  if dd == 99 && ss == 0 {
    // Light and variable: below 5 knots, direction not meaningful.
    { direction: None, speed: 0, }
  } else if dd > 36 {
    // Speeds of 100 knots or more carry the direction offset by 50.
    if dd < 50 || dd > 86 {
      raise FdError::BadWindGroup(group.to_owned())
    }
    { direction: Some((dd - 50) * 10), speed: ss + 100, }
  } else {
    { direction: Some(dd * 10), speed: ss, }
  }
}

///|
/// Decode a four-character wind group `ddss`.
pub fn decode_wind(group : String) -> Wind raise FdError {
  let view : StringView = group
  if view.length() != 4 {
    raise FdError::BadWindGroup(group)
  }
  decode_wind_group(view)
}

///|
/// Decode a temperature field, which is the text after the wind group.
///
/// A signed field (`+18`, `-06`) is read as written. An unsigned field is a
/// magnitude above 24,000 ft, where temperatures are always negative.
fn decode_temperature(
  text : StringView,
  unsigned : Bool,
  station : String,
  altitude : Int,
) -> Int raise FdError {
  if text.length() == 0 {
    raise FdError::BadTemperature("\{station} \{altitude}")
  }
  if !unsigned {
    let sign = text.at(0)
    if sign != '+' && sign != '-' {
      raise FdError::BadTemperature("\{station} \{altitude} \{text}")
    }
    let magnitude = match parse_int(text[1:]) {
      Some(v) => v
      None => raise FdError::BadTemperature("\{station} \{altitude} \{text}")
    }
    if sign == '-' {
      -magnitude
    } else {
      magnitude
    }
  } else {
    match parse_int(text) {
      Some(v) => -v
      None => raise FdError::BadTemperature("\{station} \{altitude} \{text}")
    }
  }
}

///|
/// Parse one station line.
fn parse_station_line(
  line : StringView,
  altitudes : Array[Int],
  layout : Array[(Int, Int)],
) -> StationWinds raise FdError {
  let station = line[0:3].to_owned()
  let levels : Array[Level] = []
  for i = 0; i < altitudes.length(); i = i + 1 {
    let (start, width) = layout[i]
    if start >= line.length() {
      continue
    }
    let mut end = start + width
    if end > line.length() {
      end = line.length()
    }
    let field = line[start:end].trim()
    if field.length() == 0 {
      continue
    }
    if field.length() < 4 {
      raise FdError::BadWindGroup(line.to_owned())
    }
    let wind = decode_wind_group(field)
    let rest = field[4:].trim()
    let temperature = if rest.length() == 0 {
      None
    } else {
      Some(
        decode_temperature(rest, altitudes[i] > 24000, station, altitudes[i]),
      )
    }
    levels.push({ altitude: altitudes[i], wind, temperature, })
  }
  { station, levels, }
}

///|
/// The levels listed in an `FT` header line.
fn parse_level_header(line : StringView) -> Array[Int] raise FdError {
  let rest = match after_prefix(line, "FT") {
    Some(rest) => rest
    None => raise FdError::BadLevelHeader(line.to_owned())
  }
  let altitudes : Array[Int] = []
  for token in rest.split(" ") {
    match parse_int(token) {
      Some(v) => altitudes.push(v)
      None =>
        if token.trim().length() > 0 {
          raise FdError::BadLevelHeader(line.to_owned())
        }
    }
  }
  if altitudes.length() == 0 {
    raise FdError::BadLevelHeader(line.to_owned())
  }
  altitudes
}

///|
/// Parse a winds and temperatures aloft bulletin.
///
/// Header lines, the `FT` line and any trailing lines are kept verbatim, so
/// `format_bulletin` reproduces the input byte for byte.
pub fn parse_bulletin(text : String) -> Bulletin raise FdError {
  let view : StringView = text
  let n = view.length()
  let header : Array[String] = []
  let mut path_start = -1
  let mut path_end = 0
  let mut rest = n
  let mut start = 0
  while start < n {
    let (end, next) = line_bounds(view, start)
    let line = view[start:end]
    if line.has_prefix("FT ") || line == "FT" {
      path_start = start
      path_end = end
      rest = next
      break
    }
    header.push(line.to_owned())
    start = next
  }
  if path_start < 0 {
    raise FdError::MissingLevelHeader
  }
  let level_header = view[path_start:path_end].to_owned()
  let altitudes = parse_level_header(view[path_start:path_end])
  let layout = field_layout(altitudes)

  // Header metadata.
  let mut based_on : String? = None
  let mut valid : String? = None
  let mut use_window : String? = None
  let mut temps_negative_above : Int? = None
  let mut wmo_header : String? = None
  let mut designator : String? = None
  for line in header {
    let line : StringView = line
    if line.length() == 0 {
      continue
    }
    match after_prefix(line, "DATA BASED ON ") {
      Some(found) => based_on = Some(first_token(found).to_owned())
      None => ()
    }
    match after_prefix(line, "VALID ") {
      Some(found) => {
        valid = Some(first_token(found).to_owned())
        match found.find("FOR USE ") {
          // The window is followed by a full stop: `FOR USE 1400-2100Z.`
          Some(at) =>
            use_window = Some(
              trim_end_char(first_token(found[at + 8:]).to_owned(), '.'),
            )
          None => ()
        }
        match found.find("TEMPS NEG ABV ") {
          Some(at) =>
            temps_negative_above = parse_int(first_token(found[at + 14:]))
          None => ()
        }
      }
      None => ()
    }
    if wmo_header is None && line.length() >= 6 && line.has_prefix("FB") {
      wmo_header = Some(line.to_owned())
    }
    if designator is None && line.length() == 6 && line.has_prefix("FD") {
      designator = Some(line.to_owned())
    }
  }

  // Station data, then anything that follows it.
  let stations : Array[StationWinds] = []
  let index : @hashmap.HashMap[String, StationWinds] = @hashmap.HashMap([])
  let mut i = rest
  while i < n {
    let (end, next) = line_bounds(view, i)
    let line = view[i:end]
    if is_station_line(line) {
      let station = parse_station_line(line, altitudes, layout)
      index.set(station.station, station)
      stations.push(station)
      i = next
    } else if line.trim().length() == 0 && next < n {
      // A blank line inside the data section is not data.
      let (peek_end, _) = line_bounds(view, next)
      if is_station_line(view[next:peek_end]) {
        i = next
      } else {
        break
      }
    } else {
      break
    }
  }
  let trailing : Array[String] = []
  while i < n {
    let (end, next) = line_bounds(view, i)
    trailing.push(view[i:end].to_owned())
    i = next
  }
  {
    header,
    level_header,
    altitudes,
    based_on,
    valid,
    use_window,
    temps_negative_above,
    wmo_header,
    designator,
    stations,
    index,
    trailing,
  }
}

///|
/// Two decimal digits, zero padded, written straight into `out`.
fn write_two_digits(out : StringBuilder, v : Int) -> Unit {
  out.write_char(('0'.to_int() + v / 10 % 10).unsafe_to_char())
  out.write_char(('0'.to_int() + v % 10).unsafe_to_char())
}

///|
/// Write a wind as its four-character group.
fn write_wind(out : StringBuilder, wind : Wind) -> Unit raise FdError {
  if wind.is_light_and_variable() {
    out.write_string("9900")
    return
  }
  let direction = match wind.direction {
    Some(d) => d
    None => raise FdError::BadWindGroup("wind has no direction and is not calm")
  }
  if direction < 0 || direction > 360 || direction % 10 != 0 {
    raise FdError::BadWindGroup("direction must be a multiple of 10 in 0-360")
  }
  if wind.speed < 0 || wind.speed > 199 {
    raise FdError::BadWindGroup("speed must be in 0-199 knots")
  }
  let tens = direction / 10
  if wind.speed >= 100 {
    write_two_digits(out, tens + 50)
    write_two_digits(out, wind.speed - 100)
  } else {
    write_two_digits(out, tens)
    write_two_digits(out, wind.speed)
  }
}

///|
/// Encode a wind as its four-character group.
pub fn encode_wind(wind : Wind) -> String raise FdError {
  let out = StringBuilder(size_hint=4)
  write_wind(out, wind)
  out.to_string()
}

///|
/// Write a temperature field for a level: unsigned above 24,000 ft, where
/// temperatures are always negative, and signed below.
fn write_temperature(
  out : StringBuilder,
  temperature : Int,
  altitude : Int,
) -> Unit raise FdError {
  let magnitude = if temperature < 0 { -temperature } else { temperature }
  if magnitude > 99 {
    raise FdError::BadTemperature("temperature must be in -99..99")
  }
  if altitude > 24000 {
    if temperature > 0 {
      raise FdError::BadTemperature("above 24,000 ft the sign is not carried")
    }
    write_two_digits(out, magnitude)
  } else {
    out.write_char(if temperature < 0 { '-' } else { '+' })
    write_two_digits(out, magnitude)
  }
}

///|
/// Encode a temperature field for a level: unsigned above 24,000 ft, where
/// temperatures are always negative, and signed below.
pub fn encode_temperature(
  temperature : Int,
  altitude : Int,
) -> String raise FdError {
  let out = StringBuilder(size_hint=3)
  write_temperature(out, temperature, altitude)
  out.to_string()
}

///|
/// The width of a level's field: the four characters of the wind group, plus
/// three for a signed temperature, or two above 24,000 ft, where the sign is
/// not carried.
fn field_length(level : Level) -> Int {
  match level.temperature {
    None => 4
    Some(_) => if level.altitude > 24000 { 6 } else { 7 }
  }
}

///|
/// Encode one level as its column field, without padding.
pub fn encode_level(level : Level) -> String raise FdError {
  let out = StringBuilder(size_hint=field_length(level))
  write_wind(out, level.wind)
  match level.temperature {
    None => ()
    Some(t) => write_temperature(out, t, level.altitude)
  }
  out.to_string()
}

///|
/// Format one station line, placing each level in its column.
pub fn format_station(
  station : StationWinds,
  altitudes : Array[Int],
) -> String raise FdError {
  let layout = field_layout(altitudes)
  let out = StringBuilder(size_hint=80)
  out.write_string(station.station)
  let mut column = station.station.length()
  while column < 3 {
    out.write_char(' ')
    column += 1
  }
  // The levels and the columns are both ascending, so they are walked in one
  // pass, and a blank column is skipped without a search.
  let mut index = 0
  for i = 0; i < altitudes.length(); i = i + 1 {
    let (start, width) = layout[i]
    while index < station.levels.length() &&
          station.levels[index].altitude < altitudes[i] {
      index += 1
    }
    if index >= station.levels.length() {
      break
    }
    let level = station.levels[index]
    if level.altitude != altitudes[i] {
      continue
    }
    if field_length(level) > width {
      raise FdError::BadStationLine(
        "field \{encode_level(level)} is wider than its \{width}-character column",
      )
    }
    while column < start {
      out.write_char(' ')
      column += 1
    }
    write_wind(out, level.wind)
    match level.temperature {
      None => ()
      Some(t) => write_temperature(out, t, level.altitude)
    }
    column += field_length(level)
  }
  // The line ends at the last reported level, matching the wire format, which
  // stops at the last group written.
  out.to_string()
}

///|
/// Strip trailing occurrences of `c`.
fn trim_end_char(s : String, c : Char) -> String {
  let target = c.to_int()
  let mut end = s.length()
  while end > 0 && s[end - 1].to_int() == target {
    end -= 1
  }
  s[0:end].to_owned()
}

///|
/// Write a parsed bulletin back as text.
///
/// For a bulletin produced by `parse_bulletin` this reproduces the input
/// byte for byte, apart from a final newline, which is always written.
pub fn format_bulletin(bulletin : Bulletin) -> String raise FdError {
  let out = StringBuilder(size_hint=4096)
  for line in bulletin.header {
    out.write_string(line)
    out.write_char('\n')
  }
  out.write_string(bulletin.level_header)
  out.write_char('\n')
  for station in bulletin.stations {
    out.write_string(format_station(station, bulletin.altitudes))
    out.write_char('\n')
  }
  for line in bulletin.trailing {
    out.write_string(line)
    out.write_char('\n')
  }
  out.to_string()
}
