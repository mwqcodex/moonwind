# moonwind

Upper-air weather for flight planning, in pure MoonBit: winds and
temperatures aloft (FD) bulletins, the wind-triangle calculations that turn
them into headings, ground speeds and crosswind components, and the
great-circle routes those are flown along. `cmd/main` is a demo that plans a
route from the command line.

```moonbit nocheck
///|
let bulletin = @moonwind.parse_bulletin(product_text)

///|
let station = bulletin.station("ABR").unwrap()

///|
let level = station.level_at(24000).unwrap() // wind and temperature
```

## Bulletins

`parse_bulletin` reads a winds and temperatures aloft product — the
fixed-column text products that aviation weather services publish — into
`Bulletin`, `StationWinds`, `Level` and `Wind` values. `format_bulletin`
writes it back; parsing is lossless, so a parsed bulletin re-formats byte for
byte.

The wire format compresses the numbers, and the parser handles all of it:

| Field | Encoding |
| --- | --- |
| Wind | `ddss`: tens of degrees and knots. `9900` is light and variable |
| Wind ≥ 100 kt | 50 is added to the direction and 100 taken off the speed |
| Temperature | `+TT` / `-TT` in °C |
| Temperature above 24,000 ft | always negative, so the sign is dropped |
| 3,000 ft | no temperature at all |

The column layout is derived from the `FT` header line rather than
hard-coded, so the same code reads nine-level low-level products (`FD1US1`)
and two-level high-level ones (`FD8US7`):

```
FT  3000    6000    9000   12000   18000   24000  30000  34000  39000
ABR 1519 1618+06 1614+03 1514+01 1509-13 1612-25 260739 311344 331151
ACK 0623 1108+05 2805+03 3010+00 2642-10 2648-20 266535 256945 257756
```

which reads as: `ABR` at 3,000 ft, wind 150° at 19 kt; at 24,000 ft, 160° at
12 kt and −25 °C; at 30,000 ft, 260° at 7 kt and −39 °C.

## Between the levels

A bulletin forecasts a handful of levels, and a flight plan wants the altitude
it will actually fly, which usually falls between two of them. A station
answers for any altitude between the levels it reports:

```moonbit nocheck
///|
let wind = station.vector_at(4500).unwrap()

///|
let temperature = station.temperature_at(7500) // Some(4.5)

///|
let reported = station.vector_at(4500).unwrap().to_wind() // rounded to whole numbers
```

The wind is interpolated as a vector rather than as a direction and a speed,
because a wind does not turn evenly between two levels: `LOU` goes from 70° at
13 kt at 3,000 ft to 260° at 9 kt at 6,000 ft, and half way between them the
two nearly cancel, leaving 2.2 kt from 49° — not the 165° at 11 kt that
averaging the numbers alone would give. A light and variable level counts as
no wind at all.

`WindVector` is a wind as a velocity vector, `u` east and `v` north in knots,
with `direction`, `speed` and `to_wind` to read a report back off it.

Nothing is extrapolated: an altitude above the highest or below the lowest
level a station reports is answered with `None`, and stations do not all
report the same levels. `DEN`, high in the Rockies, starts at 9,000 ft because
the levels below it are under the ground; the 3,000 ft column never carries a
temperature, so `temperature_at` starts at 6,000 ft.

## Units and the standard atmosphere

The data model keeps the units the bulletins are written in — knots, feet,
degrees Celsius — and `units.mbt` converts them: knots to metres per second,
kilometres per hour or miles per hour, feet to metres, Celsius to Fahrenheit.
It also carries the standard atmosphere, which is what a reported temperature
is read against:

```moonbit nocheck
///|
let standard = @moonwind.isa_temperature(24000.0) // -32.5488

///|
let deviation = @moonwind.isa_deviation(-25.0, 24000.0) // 7.5488, warmer than standard
```

## The wind triangle

The wind that is forecast is not the wind the aeroplane flies through: it
carries the aircraft with it. `WindTriangle::solve` takes the course to make
good, the true airspeed and the wind, and gives back the heading to steer, the
ground speed that results, and the components a pilot reads a wind in:

```moonbit nocheck
///|
let triangle = @moonwind.WindTriangle::solve(90.0, 120.0, wind)

///|
let heading = triangle.heading() // 097.99°, course plus the correction

///|
let ground_speed = triangle.ground_speed() // 111.01 kt
```

A headwind is positive when it comes from ahead, so a tailwind is negative,
and a crosswind is positive when it comes from the right of the track. The
wind correction angle has the same sign as the crosswind, so steering into the
wind is steering by the correction angle.

A wind does not have to come from a bulletin: `Wind::new(Some(150), 14)` is
150 degrees at 14 kt, and `WindVector::from_wind` turns a reported wind into
the vector a triangle solves. The other way round, `WindVector::to_wind`
reads a wind back off a vector, as a rounded direction and speed.

A crosswind stronger than the airspeed has no solution — the aircraft cannot
hold the course at any heading — and `solve` reports it with
`FlightError::CrosswindExceedsAirspeed` rather than returning a heading that
does not exist.

## Runways

A runway is named for its magnetic direction in tens of degrees, and the wind
across it is what a crosswind limit is written against:

```moonbit nocheck
///|
let runway = @moonwind.Runway::parse("27").unwrap()

///|
let crosswind = runway.crosswind(wind) // positive from the right

///|
let headwind = runway.headwind(wind) // negative for a tailwind

///|
let other_end = runway.reciprocal().unwrap() // runway 09
```

## Routes

A route is a list of waypoints, and the path between two of them is a great
circle. The course of a great circle drifts as it is flown — the one from New
York to London leaves on 051 and arrives on 108 — so a long hop is cut into
shorter legs, each with a course of its own:

```moonbit nocheck
///|
let route = @moonwind.Route::new([
  @moonwind.Coordinate::new(45.0, -98.0),
  @moonwind.Coordinate::new(44.0, -96.0),
  @moonwind.Coordinate::new(43.0, -94.0),
])

///|
let distance = route.distance() // 210.38 nm along the waypoints

///|
let segments = route.segments() // a distance and a course for every hop

///|
let shorter = route.subdivided(8) // every hop flown as eight shorter ones

///|
let middle = route.points()[0].midpoint(route.points()[1])
```

`Coordinate` does the geometry: the great-circle `distance_to` another
position, the `initial_course_to` it, and `interpolate` and `midpoint` for the
positions along the way. Distances are nautical miles on a sphere of the
Earth's mean radius, and a path across the date line is taken the short way,
so the course from 170 east to 170 west is 270 rather than 90.

A route is planned against a forecast at one altitude and airspeed. Each leg
is flown at the wind over its own middle, where a leg is most of the way
through it:

```moonbit nocheck
///|
let plan = route.plan(station, 12000, 120.0)

///|
let legs = plan.legs() // each with its wind, heading, ground speed and time

///|
let hours = plan.total_time_hours()

///|
let distance = plan.total_distance()
```

`Route::plan` reads one station's forecast at the level it reports for that
altitude. `Route::plan_with` takes the wind from a function of the position
and the altitude instead, so a forecast that varies over a route — the station
nearest each leg, or a grid of forecast winds — is used where the leg is.

A leg that has no forecast at that altitude is reported with
`FlightError::NoForecast`, and a leg the wind beats — a headwind stronger than
the airspeed, so the ground speed comes out at or below zero — with
`FlightError::NoGroundSpeed`, rather than being given a time that means
nothing.

## Running the demo

`cmd/main` plans a route against one of the products it carries and prints it
leg by leg:

```
moon run cmd/main
moon run cmd/main -- --station ABR --altitude 12000 --airspeed 120 \
    --legs 4 45,-98 44,-96 43,-94
```

```
moonwind — a flight plan from a winds and temperatures aloft product

  product   fd1us1  FD1US1  valid 221800Z
  station   ABR at 12000 ft: 150 at 14 kt, 1.0 C
  route     3 waypoints, 2 legs, 210.4 nm, at 120 kt

  leg  1   45.00N 98.00W -> 44.00N 96.00W
          104.6 nm on course 124.3, wind 150 at 14 kt, heading 127.2 at 107.2 kt, 0.98 h
          6.1 kt across, 12.6 kt along
  leg  2   44.00N 96.00W -> 43.00N 94.00W
          105.8 nm on course 123.9, wind 150 at 14 kt, heading 126.8 at 107.3 kt, 0.99 h
          6.2 kt across, 12.6 kt along

  total     210.4 nm in 1 h 58 min
```

`--help` lists the options, `--list` lists the stations of a product, and
`--product fd8us7` plans at 45,000 and 53,000 ft with the high-level product.
The products it carries are the real ones the tests run against.

## Testing

```
moon test
```

The tests run against real products captured from the Aviation Weather
Center text data API, stored in `tests/fixtures/` and embedded into the build
by `scripts/gen_fixtures.py`:

```
python scripts/gen_fixtures.py > fd_fixtures_wbtest.mbt
python scripts/gen_fixtures.py --cli > cmd/main/sample.mbt
moon fmt
```

They cover the decode rules, the golden values of specific stations, a
byte-for-byte round trip of every product, the interpolation, conversion,
standard-atmosphere and great-circle values quoted above, and the command
line demo's reading of its arguments.
