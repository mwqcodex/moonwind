///|
/// Weather computation in pure MoonBit, in the layers a weather report is
/// read in.
///
/// Three layers, usable together or on their own:
///
/// * weather calculations - humidity (`dew_point`, `wet_bulb_temperature`,
///   `absolute_humidity`), apparent temperature (`wind_chill_celsius`,
///   `heat_index_celsius`, `humidex`), pressure and altitude
///   (`mean_sea_level_pressure`, `altimeter_setting_hpa`, `density_altitude`),
///   and the Beaufort scale and wind barbs: the numbers a weather report can
///   be turned into, from the formulas and tables the weather services
///   publish.
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
