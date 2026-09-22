///|
/// Upper-air weather for flight planning, in pure MoonBit.
///
/// Two layers, usable together or on their own:
///
/// * `parse_bulletin` / `format_bulletin` - read the winds and temperatures
///   aloft (FD) bulletins that aviation weather services publish, and write
///   them back. Bulletins are fixed-column text products, and the column
///   layout is derived from the `FT` header line, so the same code reads the
///   nine-level low-level products and the two-level high-level ones.
///   Parsing is lossless: `format_bulletin` reproduces the input byte for
///   byte, which is what the tests assert over real products.
///
/// * wind and route calculations - `Wind`, `wind_triangle`, `Route` and
///   friends turn a parsed bulletin into the numbers a flight plan needs:
///   wind correction angle, ground speed, headwind and crosswind components
///   for a leg, and the runway components for a take-off or landing.
///
/// ```moonbit nocheck
/// let bulletin = @moonwind.parse_bulletin(metar_text)
/// let abr = bulletin.station("ABR").unwrap()
/// let wind = abr.wind_at(24000).unwrap() // interpolated to any altitude
/// ```
