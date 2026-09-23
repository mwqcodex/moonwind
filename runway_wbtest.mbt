///|
/// Whether two values agree to within `tolerance`.
fn runway_close(actual : Double, expected : Double, tolerance : Double) -> Bool {
  (actual - expected).abs() <= tolerance
}

///|
/// A designator is its heading in tens of degrees: `27` lies along 270, `09`
/// along 90, `36` along 360. One or two digits are accepted, with an optional
/// `L`, `C` or `R` for parallel runways.
test "a runway designator is its heading in tens of degrees" {
  assert_eq(Runway::parse("27").unwrap().heading(), 270)
  assert_eq(Runway::parse("09").unwrap().heading(), 90)
  assert_eq(Runway::parse("36").unwrap().heading(), 360)
  assert_eq(Runway::parse("01").unwrap().heading(), 10)
  assert_eq(Runway::parse("9").unwrap().heading(), 90)
  assert_eq(Runway::parse("18R").unwrap().heading(), 180)
  assert_eq(Runway::parse("36C").unwrap().heading(), 360)
  assert_eq(Runway::parse("36C").unwrap().designator(), "36C")
}

///|
/// Anything that is not a runway number from 01 to 36, with at most one side
/// letter, is refused.
test "a malformed designator is not a runway" {
  let bad : Array[String] = [
    "", "00", "37", "99", "abc", "27X", "27LR", "1L2", "271",
  ]
  for designator in bad {
    assert_true(Runway::parse(designator) is None)
  }
}

///|
/// The reciprocal is the other end of the same strip: 180 degrees around,
/// with the same parallel-runway letter.
test "the reciprocal is the runway at the other end" {
  assert_eq(
    Runway::parse("27").unwrap().reciprocal().unwrap().designator(),
    "09",
  )
  assert_eq(Runway::parse("09").unwrap().reciprocal().unwrap().heading(), 270)
  assert_eq(
    Runway::parse("09L").unwrap().reciprocal().unwrap().designator(),
    "27L",
  )
  assert_eq(
    Runway::parse("18").unwrap().reciprocal().unwrap().designator(),
    "36",
  )
  assert_eq(
    Runway::parse("36").unwrap().reciprocal().unwrap().designator(),
    "18",
  )
  assert_eq(
    Runway::parse("01").unwrap().reciprocal().unwrap().designator(),
    "19",
  )
}

///|
/// A wind 50 degrees off runway 27 blows mostly down the runway: 9.64 kt of
/// headwind and 11.49 kt from the left. The same wind on runway 09, the other
/// direction down the same strip, is a tailwind with the crosswind from the
/// right.
test "the wind resolves onto the runway" {
  let wind = { direction: Some(220), speed: 15, }
  let runway27 = Runway::parse("27").unwrap()
  assert_true(runway_close(runway27.headwind(wind), 9.641814145, 1.0e-6))
  assert_true(runway_close(runway27.crosswind(wind), -11.490666647, 1.0e-6))
  let runway09 = Runway::parse("09").unwrap()
  assert_true(runway_close(runway09.headwind(wind), -9.641814145, 1.0e-6))
  assert_true(runway_close(runway09.crosswind(wind), 11.490666647, 1.0e-6))
}

///|
/// A wind at right angles to the runway is pure crosswind: 20 kt from the
/// west on runway 36, from the left of its 360-degree heading.
test "a wind across the runway is pure crosswind" {
  let wind = { direction: Some(270), speed: 20, }
  let runway36 = Runway::parse("36").unwrap()
  assert_true(runway_close(runway36.headwind(wind), 0.0, 1.0e-9))
  assert_true(runway_close(runway36.crosswind(wind), -20.0, 1.0e-9))
}

///|
/// A light and variable wind has no direction, so it has neither component.
test "a light and variable wind contributes nothing to a runway" {
  let wind = { direction: None, speed: 0, }
  let runway = Runway::parse("18").unwrap()
  assert_true(runway_close(runway.headwind(wind), 0.0, 1.0e-12))
  assert_true(runway_close(runway.crosswind(wind), 0.0, 1.0e-12))
}
