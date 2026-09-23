# moonwind

Upper-air weather for flight planning, in pure MoonBit: winds and
temperatures aloft (FD) bulletins, and the wind-triangle calculations that
turn them into ground speed, wind correction angle and crosswind components.

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
let heading = triangle.heading()          // 097.99°, course plus the correction

///|
let ground_speed = triangle.ground_speed() // 111.01 kt
```

A headwind is positive when it comes from ahead, so a tailwind is negative,
and a crosswind is positive when it comes from the right of the track. The
wind correction angle has the same sign as the crosswind, so steering into the
wind is steering by the correction angle.

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
let crosswind = runway.crosswind(wind)   // positive from the right

///|
let headwind = runway.headwind(wind)     // negative for a tailwind

///|
let other_end = runway.reciprocal().unwrap() // runway 09
```

## Testing

```
moon test
```

The tests run against real products captured from the Aviation Weather
Center text data API, stored in `tests/fixtures/` and embedded into the test
build by `scripts/gen_fixtures.py`:

```
python scripts/gen_fixtures.py > fd_fixtures_wbtest.mbt
```

They cover the decode rules, the golden values of specific stations, a
byte-for-byte round trip of every product, and the interpolation, conversion
and standard-atmosphere values quoted above.
