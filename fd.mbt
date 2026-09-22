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

///|
/// Split text into lines, dropping the final empty piece so that a trailing
/// newline does not produce a phantom line.
fn split_lines(text : String) -> Array[String] {
  let out : Array[String] = []
  let n = text.length()
  let mut start = 0
  for i = 0; i < n; i = i + 1 {
    if text[i] == '\n' {
      let mut end = i
      if end > start && text[end - 1] == '\r' {
        end -= 1
      }
      out.push(text[start:end].to_owned())
      start = i + 1
    }
  }
  if start < n {
    let mut end = n
    if end > start && text[end - 1] == '\r' {
      end -= 1
    }
    out.push(text[start:end].to_owned())
  }
  out
}

///|
/// Strip leading and trailing blanks.
fn trim_ws(s : String) -> String {
  let n = s.length()
  let mut start = 0
  let mut end = n
  while start < end && (s[start] == ' ' || s[start] == '\t') {
    start += 1
  }
  while end > start && (s[end - 1] == ' ' || s[end - 1] == '\t') {
    end -= 1
  }
  s[start:end].to_owned()
}

///|
/// The text before the first blank, or the whole text when it has none.
fn first_token(s : String) -> String {
  let n = s.length()
  let mut i = 0
  while i < n && s[i] != ' ' && s[i] != '\t' {
    i += 1
  }
  s[0:i].to_owned()
}

///|
/// The part of `s` after `prefix`, or `None` when it does not start with it.
fn after_prefix(s : String, prefix : String) -> String? {
  if s.has_prefix(prefix) {
    Some(s[prefix.length():].to_owned())
  } else {
    None
  }
}

///|
/// The index of the first occurrence of `needle` in `s`.
fn find_sub(s : String, needle : String) -> Int? {
  let n = s.length()
  let m = needle.length()
  if m == 0 || m > n {
    return None
  }
  for i = 0; i <= n - m; i = i + 1 {
    if s[i:i + m].to_owned() == needle {
      return Some(i)
    }
  }
  None
}

///|
/// Digits of `s`, or `None` when it is empty or holds anything else.
fn parse_int(s : String) -> Int? {
  let t = trim_ws(s)
  if t.length() == 0 {
    return None
  }
  let mut v = 0
  for i = 0; i < t.length(); i = i + 1 {
    let c = t[i]
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
fn is_station_line(line : String) -> Bool {
  line.length() >= 4 &&
  is_station_char(line[0]) &&
  is_station_char(line[1]) &&
  is_station_char(line[2]) &&
  line[3] == ' '
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
fn digits2(s : String, at : Int, whole : String) -> Int raise FdError {
  if at < 0 || at + 2 > s.length() {
    raise FdError::BadWindGroup(whole)
  }
  let hi = s[at]
  let lo = s[at + 1]
  if hi < '0' || hi > '9' || lo < '0' || lo > '9' {
    raise FdError::BadWindGroup(whole)
  }
  (hi.to_int() - '0'.to_int()) * 10 + (lo.to_int() - '0'.to_int())
}

///|
/// Decode a four-character wind group `ddss`.
pub fn decode_wind(group : String) -> Wind raise FdError {
  if group.length() != 4 {
    raise FdError::BadWindGroup(group)
  }
  let dd = digits2(group, 0, group)
  let ss = digits2(group, 2, group)
  if dd == 99 && ss == 0 {
    // Light and variable: below 5 knots, direction not meaningful.
    { direction: None, speed: 0, }
  } else if dd > 36 {
    // Speeds of 100 knots or more carry the direction offset by 50.
    if dd < 50 || dd > 86 {
      raise FdError::BadWindGroup(group)
    }
    { direction: Some((dd - 50) * 10), speed: ss + 100, }
  } else {
    { direction: Some(dd * 10), speed: ss, }
  }
}

///|
/// Decode a temperature field, which is the text after the wind group.
///
/// A signed field (`+18`, `-06`) is read as written. An unsigned field is a
/// magnitude above 24,000 ft, where temperatures are always negative.
fn decode_temperature(
  text : String,
  unsigned : Bool,
  whole : String,
) -> Int raise FdError {
  if text.length() == 0 {
    raise FdError::BadTemperature(whole)
  }
  if !unsigned {
    let sign = text[0]
    if sign != '+' && sign != '-' {
      raise FdError::BadTemperature(whole)
    }
    let magnitude = match parse_int(text[1:].to_owned()) {
      Some(v) => v
      None => raise FdError::BadTemperature(whole)
    }
    if sign == '-' {
      -magnitude
    } else {
      magnitude
    }
  } else {
    match parse_int(text) {
      Some(v) => -v
      None => raise FdError::BadTemperature(whole)
    }
  }
}

///|
/// Parse one station line.
fn parse_station_line(
  line : String,
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
    let field = trim_ws(line[start:end].to_owned())
    if field.length() == 0 {
      continue
    }
    if field.length() < 4 {
      raise FdError::BadWindGroup(line)
    }
    let wind = decode_wind(field[0:4].to_owned())
    let rest = trim_ws(field[4:].to_owned())
    let temperature = if rest.length() == 0 {
      None
    } else {
      Some(
        decode_temperature(
          rest,
          altitudes[i] > 24000,
          "\{station} \{altitudes[i]} \{field}",
        ),
      )
    }
    levels.push({ altitude: altitudes[i], wind, temperature, })
  }
  { station, levels, }
}

///|
/// The levels listed in an `FT` header line.
fn parse_level_header(line : String) -> Array[Int] raise FdError {
  let rest = match after_prefix(line, "FT") {
    Some(r) => r
    None => raise FdError::BadLevelHeader(line)
  }
  let altitudes : Array[Int] = []
  for token in rest.split(" ") {
    let t = trim_ws(token.to_owned())
    if t.length() == 0 {
      continue
    }
    match parse_int(t) {
      Some(v) => altitudes.push(v)
      None => raise FdError::BadLevelHeader(line)
    }
  }
  if altitudes.length() == 0 {
    raise FdError::BadLevelHeader(line)
  }
  altitudes
}

///|
/// Parse a winds and temperatures aloft bulletin.
///
/// Header lines, the `FT` line and any trailing lines are kept verbatim, so
/// `format_bulletin` reproduces the input byte for byte.
pub fn parse_bulletin(text : String) -> Bulletin raise FdError {
  let lines = split_lines(text)
  let header : Array[String] = []
  let trailing : Array[String] = []
  let mut indexPath : Int? = None
  for i = 0; i < lines.length(); i = i + 1 {
    if lines[i].has_prefix("FT ") || lines[i] == "FT" {
      indexPath = Some(i)
      break
    }
    header.push(lines[i])
  }
  let path_index = match indexPath {
    Some(i) => i
    None => raise FdError::MissingLevelHeader
  }
  let level_header = lines[path_index]
  let altitudes = parse_level_header(level_header)
  let layout = field_layout(altitudes)

  // Header metadata.
  let mut based_on : String? = None
  let mut valid : String? = None
  let mut use_window : String? = None
  let mut temps_negative_above : Int? = None
  let mut wmo_header : String? = None
  let mut designator : String? = None
  for line in header {
    if line.length() == 0 {
      continue
    }
    match after_prefix(line, "DATA BASED ON ") {
      Some(rest) => based_on = Some(first_token(rest))
      None => ()
    }
    match after_prefix(line, "VALID ") {
      Some(rest) => {
        valid = Some(first_token(rest))
        match find_sub(rest, "FOR USE ") {
          // The window is followed by a full stop: `FOR USE 1400-2100Z.`
          Some(at) =>
            use_window = Some(
              trim_end_char(first_token(rest[at + 8:].to_owned()), '.'),
            )
          None => ()
        }
        match find_sub(rest, "TEMPS NEG ABV ") {
          Some(at) =>
            temps_negative_above = parse_int(
              first_token(rest[at + 14:].to_owned()),
            )
          None => ()
        }
      }
      None => ()
    }
    if wmo_header is None && line.length() >= 6 && line.has_prefix("FB") {
      wmo_header = Some(line)
    }
    if designator is None && line.length() == 6 && line.has_prefix("FD") {
      designator = Some(line)
    }
  }

  // Station data, then anything that follows it.
  let stations : Array[StationWinds] = []
  let mut i = path_index + 1
  while i < lines.length() {
    if is_station_line(lines[i]) {
      stations.push(parse_station_line(lines[i], altitudes, layout))
      i += 1
    } else if trim_ws(lines[i]).length() == 0 &&
      i + 1 < lines.length() &&
      is_station_line(lines[i + 1]) {
      // A blank line inside the data section is not data.
      i += 1
    } else {
      break
    }
  }
  while i < lines.length() {
    trailing.push(lines[i])
    i += 1
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
    trailing,
  }
}

///|
/// Two decimal digits, zero padded.
fn two_digits(v : Int) -> String {
  let tens = v / 10 % 10
  let ones = v % 10
  String::from_array([
    ('0'.to_int() + tens).unsafe_to_char(),
    ('0'.to_int() + ones).unsafe_to_char(),
  ])
}

///|
/// Encode a wind as its four-character group.
pub fn encode_wind(wind : Wind) -> String raise FdError {
  if wind.is_light_and_variable() {
    return "9900"
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
    return two_digits(tens + 50) + two_digits(wind.speed - 100)
  }
  two_digits(tens) + two_digits(wind.speed)
}

///|
/// Encode a temperature field for a level: unsigned above 24,000 ft, where
/// temperatures are always negative, and signed below.
pub fn encode_temperature(
  temperature : Int,
  altitude : Int,
) -> String raise FdError {
  let magnitude = if temperature < 0 { -temperature } else { temperature }
  if magnitude > 99 {
    raise FdError::BadTemperature("temperature must be in -99..99")
  }
  if altitude > 24000 {
    if temperature > 0 {
      raise FdError::BadTemperature("above 24,000 ft the sign is not carried")
    }
    two_digits(magnitude)
  } else if temperature < 0 {
    "-" + two_digits(magnitude)
  } else {
    "+" + two_digits(magnitude)
  }
}

///|
/// Encode one level as its column field, without padding.
pub fn encode_level(level : Level) -> String raise FdError {
  let wind = encode_wind(level.wind)
  match level.temperature {
    None => wind
    Some(t) => wind + encode_temperature(t, level.altitude)
  }
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
  let mut col = station.station.length()
  while col < 3 {
    out.write_char(' ')
    col += 1
  }
  for i = 0; i < altitudes.length(); i = i + 1 {
    let (start, width) = layout[i]
    match station.level_at(altitudes[i]) {
      None => ()
      Some(level) => {
        while col < start {
          out.write_char(' ')
          col += 1
        }
        let field = encode_level(level)
        if field.length() > width {
          raise FdError::BadStationLine(
            "field \{field} is wider than its \{width}-character column",
          )
        }
        out.write_string(field)
        col += field.length()
        let mut padded = field.length()
        while padded < width {
          out.write_char(' ')
          col += 1
          padded += 1
        }
      }
    }
  }
  // Columns after the last reported level are not padded, matching the wire
  // format, which ends the line at the last group.
  let text = out.to_string()
  trim_end(text)
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
/// Strip trailing blanks.
fn trim_end(s : String) -> String {
  let mut end = s.length()
  while end > 0 && (s[end - 1] == ' ' || s[end - 1] == '\t') {
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
