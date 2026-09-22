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

They cover the decode rules, the golden values of specific stations, and a
byte-for-byte round trip of every product.
