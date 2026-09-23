///|
/// A flight plan from the command line.
///
/// Reads one of the winds and temperatures aloft products the demo carries,
/// plans a route across it at one altitude and airspeed, and prints the legs
/// with the wind that was forecast for each of them:
///
///     moon run cmd/main
///     moon run cmd/main -- --station ABR --altitude 12000 --airspeed 120 \
///         --legs 4 45,-98 44,-96 43,-94
///
/// Without waypoints it plans the demonstration route below, which crosses
/// the northern plains where `ABR` forecasts.

///|
/// The route planned when the command line gives none: three waypoints across
/// the northern plains, in South Dakota and Minnesota.
let demonstration_route : Array[@moonwind.Coordinate] = [
  @moonwind.Coordinate::new(45.0, -98.0),
  @moonwind.Coordinate::new(44.0, -96.0),
  @moonwind.Coordinate::new(43.0, -94.0),
]

///|
/// A route to plan, as the command line asked for it.
priv struct Request {
  product : String
  station : String
  altitude : Int
  airspeed : Double
  legs : Int
  waypoints : Array[@moonwind.Coordinate]
}

///|
/// What the command line asked for.
priv enum Command {
  Plan(Request)
  ListStations(String)
  Help
  Bad(String)
}

///|
fn main {
  match command(@env.args()) {
    Help => println(usage())
    Bad(message) => {
      println(message)
      println("")
      println(usage())
    }
    ListStations(product) => list_stations(product)
    Plan(request) => plan_route(request)
  }
}

///|
/// How the demo is used.
fn usage() -> String {
  [
    "moonwind — plan a route against a winds and temperatures aloft product", "",
    "  moon run cmd/main -- [options] [lat,lon ...]", "", "  --product NAME   the product to plan with: fd1us1 (default), fd2us1",
    "                   for the 12-hour forecast, or fd8us7 for the high", "                   level product of 45,000 and 53,000 ft",
    "  --station ID     the station to read the wind from; the first station", "                   of the product by default",
    "  --altitude FT    the altitude to plan at, in feet: 12000 by default", "  --airspeed KT    the true airspeed, in knots: 120 by default",
    "  --legs N         divide every hop into N legs, so that the course of", "                   each one stays close to the course at its start",
    "  --list           list the stations the product reports", "  --help           this",
    "", "Waypoints are latitudes and longitudes in degrees, as in 45,-98, and at",
    "least two of them make a route. Without any, the demonstration route", "over the northern plains is planned.",
  ].join("\n")
}

///|
/// The command the arguments describe.
fn command(arguments : Array[String]) -> Command {
  let mut product = "fd1us1"
  let mut station = "ABR"
  let mut altitude = 12000
  let mut airspeed = 120.0
  let mut legs = 1
  let waypoints : Array[@moonwind.Coordinate] = []
  let mut list = false
  let mut index = 0
  while index < arguments.length() {
    let argument = arguments[index]
    if argument == "--help" || argument == "-h" {
      return Help
    } else if argument == "--list" {
      list = true
      index = index + 1
    } else if argument == "--product" {
      match following(arguments, index) {
        Some(value) => product = value
        None => return Bad("--product needs the name of a product")
      }
      index = index + 2
    } else if argument == "--station" {
      match following(arguments, index) {
        Some(value) => station = value
        None => return Bad("--station needs a station identifier")
      }
      index = index + 2
    } else if argument == "--altitude" {
      match following(arguments, index) {
        Some(value) =>
          match whole_number(value) {
            Some(feet) => altitude = feet
            None => return Bad("\{value} is not an altitude in feet")
          }
        None => return Bad("--altitude needs an altitude in feet")
      }
      index = index + 2
    } else if argument == "--airspeed" {
      match following(arguments, index) {
        Some(value) =>
          match number(value) {
            Some(knots) => airspeed = knots
            None => return Bad("\{value} is not an airspeed in knots")
          }
        None => return Bad("--airspeed needs an airspeed in knots")
      }
      index = index + 2
    } else if argument == "--legs" {
      match following(arguments, index) {
        Some(value) =>
          match whole_number(value) {
            Some(count) => legs = count
            None => return Bad("\{value} is not a number of legs")
          }
        None => return Bad("--legs needs a number of legs")
      }
      index = index + 2
    } else {
      match waypoint(argument) {
        Some(position) => waypoints.push(position)
        None =>
          // The first argument of a program is the program itself; anything
          // else that is not a position is a mistake worth reporting.
          if index > 0 {
            return Bad("\{argument} is not a latitude,longitude position")
          }
      }
      index = index + 1
    }
  }
  if list {
    return ListStations(product)
  }
  if waypoints.length() == 1 {
    return Bad("a route needs at least two waypoints")
  }
  if altitude < 0 {
    return Bad("an altitude cannot be below sea level")
  }
  if airspeed <= 0.0 {
    return Bad("an airspeed must be positive")
  }
  if legs < 1 {
    return Bad("a route cannot be divided into fewer than one leg")
  }
  Plan({ product, station, altitude, airspeed, legs, waypoints, })
}

///|
/// The argument after an option, when the command line has one.
fn following(arguments : Array[String], index : Int) -> String? {
  if index + 1 < arguments.length() {
    Some(arguments[index + 1])
  } else {
    None
  }
}

///|
/// A waypoint written as a latitude and longitude in degrees, such as
/// `45,-98`.
fn waypoint(text : String) -> @moonwind.Coordinate? {
  let parts = text.split(",").to_array()
  if parts.length() != 2 {
    return None
  }
  match (degrees(parts[0]), degrees(parts[1])) {
    (Some(latitude), Some(longitude)) =>
      Some(@moonwind.Coordinate::new(latitude, longitude))
    _ => None
  }
}

///|
/// A latitude or longitude in degrees, which cannot lie outside the globe.
fn degrees(text : StringView) -> Double? {
  let value = @string.parse_double(text) catch { _ => return None }
  if value != value || value.abs() > 180.0 {
    return None
  }
  Some(value)
}

///|
/// A whole number.
fn whole_number(text : String) -> Int? {
  let value = @string.parse_int(text) catch { _ => return None }
  Some(value)
}

///|
/// A number.
fn number(text : String) -> Double? {
  Some(@string.parse_double(text)) catch {
    _ => None
  }
}

///|
/// The text of the product named on the command line.
fn product_text(name : String) -> String? {
  match name {
    "fd1us1" => Some(sample_fd1us1)
    "fd2us1" => Some(sample_fd2us1)
    "fd8us7" => Some(sample_fd8us7)
    _ => None
  }
}

///|
/// A number written with `decimals` digits after the point, which is how a
/// flight plan is read: 104.591137317 nm is 104.6 nm.
fn fixed(value : Double, decimals : Int) -> String {
  if decimals < 1 {
    return @math.round(value).to_string()
  }
  let scale = @math.pow(10.0, decimals.to_double())
  let rounded = @math.round(value * scale) / scale
  let text = rounded.to_string()
  match text.split_once(".") {
    Some((whole, fraction)) =>
      "\{whole}.\{fraction.to_owned().pad_end(decimals, '0')}"
    None => "\{text}.\{"".pad_start(decimals, '0')}"
  }
}

///|
/// A position written the way a chart has it: `44.50N 96.99W`.
fn position_text(position : @moonwind.Coordinate) -> String {
  let latitude = position.latitude()
  let longitude = position.longitude()
  let north_south = if latitude < 0.0 { "S" } else { "N" }
  let east_west = if longitude < 0.0 { "W" } else { "E" }
  "\{fixed(latitude.abs(), 2)}\{north_south} \{fixed(longitude.abs(), 2)}\{east_west}"
}

///|
/// A wind as it is reported: `150 at 14 kt`, or light and variable.
fn wind_text(wind : @moonwind.WindVector) -> String {
  let reported = wind.to_wind()
  match reported.direction() {
    Some(direction) =>
      "\{direction.to_string().pad_start(3, '0')} at \{reported.speed()} kt"
    None => "light and variable"
  }
}

///|
/// Hours written as hours and minutes, which is how a flight is read: 1.96
/// hours is 1 h 58 min.
fn hours_text(hours : Double) -> String {
  let minutes = @math.round(hours * 60.0).to_int()
  if minutes < 60 {
    "\{minutes} min"
  } else {
    "\{minutes / 60} h \{minutes % 60} min"
  }
}

///|
/// List the stations of a product, with the levels each of them reports.
fn list_stations(name : String) -> Unit {
  let text = match product_text(name) {
    Some(found) => found
    None => {
      println(
        "\{name} is not a product the demo carries: fd1us1, fd2us1, fd8us7",
      )
      return
    }
  }
  let bulletin = @moonwind.parse_bulletin(text) catch {
    _ => {
      println("the \{name} product could not be read")
      return
    }
  }
  println("")
  println("\{name}\{validity_text(bulletin)}")
  println("")
  for station in bulletin.stations() {
    let lowest = match station.lowest_altitude() {
      Some(altitude) => altitude
      None => 0
    }
    let highest = match station.highest_altitude() {
      Some(altitude) => altitude
      None => 0
    }
    println(
      "  \{station.station()}  \{lowest} to \{highest} ft, \{station.levels().length()} levels",
    )
  }
}

///|
/// The time a product is valid for, for a report.
fn validity_text(bulletin : @moonwind.Bulletin) -> String {
  let parts : Array[String] = []
  match bulletin.designator() {
    Some(designator) => parts.push(designator)
    None => ()
  }
  match bulletin.valid() {
    Some(valid) => parts.push("valid \{valid}")
    None => ()
  }
  if parts.length() == 0 {
    ""
  } else {
    "  " + parts.join("  ")
  }
}

///|
/// Plan a route and print it, leg by leg.
fn plan_route(request : Request) -> Unit {
  let text = match product_text(request.product) {
    Some(found) => found
    None => {
      println(
        "\{request.product} is not a product the demo carries: fd1us1, fd2us1, fd8us7",
      )
      return
    }
  }
  let bulletin = @moonwind.parse_bulletin(text) catch {
    _ => {
      println("the \{request.product} product could not be read")
      return
    }
  }
  let station = match bulletin.station(request.station) {
    Some(found) => found
    None => {
      println(
        "the \{request.product} product has no \{request.station}; --list shows the stations it has",
      )
      return
    }
  }
  let waypoints = if request.waypoints.length() == 0 {
    demonstration_route
  } else {
    request.waypoints
  }
  let route = @moonwind.Route::new(waypoints).subdivided(request.legs)
  let plan = route.plan(station, request.altitude, request.airspeed) catch {
    @moonwind.FlightError::NoForecast(altitude) => {
      println(
        "\{station.station()} forecasts no wind at \{altitude} ft: it reports \{level_range_text(station)}",
      )
      return
    }
    @moonwind.FlightError::NoGroundSpeed(speed) => {
      println(
        "the wind at \{request.altitude} ft beats the aircraft: a ground speed of \{fixed(speed, 1)} kt leaves no time to fly the leg",
      )
      return
    }
    _ => {
      println("the route could not be planned")
      return
    }
  }
  println("")
  println(
    "moonwind — a flight plan from a winds and temperatures aloft product",
  )
  println("")
  println("  product   \{request.product}\{validity_text(bulletin)}")
  println(
    "  station   \{station.station()} at \{request.altitude} ft: \{wind_text(station_wind(station, request.altitude))}\{temperature_text(station, request.altitude)}",
  )
  println(
    "  route     \{waypoints.length()} waypoints, \{plan.legs().length()} legs, \{fixed(plan.total_distance(), 1)} nm, at \{fixed(request.airspeed, 0)} kt",
  )
  println("")
  let legs = plan.legs()
  for index = 0; index < legs.length(); index = index + 1 {
    let leg = legs[index]
    println(
      "  leg \{(index + 1).to_string().pad_start(2, ' ')}   \{position_text(leg.segment().from())} -> \{position_text(leg.segment().to())}",
    )
    println(
      "          \{fixed(leg.distance(), 1)} nm on course \{fixed(leg.true_course(), 1)}, wind \{wind_text(leg.wind())}, heading \{fixed(leg.heading(), 1)} at \{fixed(leg.ground_speed(), 1)} kt, \{fixed(leg.time_hours(), 2)} h",
    )
    println(
      "          \{fixed(leg.crosswind(), 1)} kt across, \{fixed(leg.headwind(), 1)} kt along",
    )
  }
  println("")
  println(
    "  total     \{fixed(plan.total_distance(), 1)} nm in \{hours_text(plan.total_time_hours())}",
  )
  println("")
}

///|
/// The wind a station forecasts at an altitude, which the plan has already
/// found to be there.
fn station_wind(
  station : @moonwind.StationWinds,
  altitude : Int,
) -> @moonwind.WindVector {
  match station.vector_at(altitude) {
    Some(wind) => wind
    None => @moonwind.WindVector::from_components(0.0, 0.0)
  }
}

///|
/// The temperature a station forecasts at an altitude, when it forecasts one.
fn temperature_text(station : @moonwind.StationWinds, altitude : Int) -> String {
  match station.temperature_at(altitude) {
    Some(celsius) => ", \{fixed(celsius, 1)} C"
    None => ""
  }
}

///|
/// The levels a station reports, for a message about the ones it does not.
fn level_range_text(station : @moonwind.StationWinds) -> String {
  match (station.lowest_altitude(), station.highest_altitude()) {
    (Some(lowest), Some(highest)) => "\{lowest} to \{highest} ft"
    _ => "no levels"
  }
}
