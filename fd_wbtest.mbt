///|
/// Wind groups.
test "plain wind group" {
  let wind = decode_wind("2713")
  assert_eq(wind.direction, Some(270))
  assert_eq(wind.speed, 13)
}

///|
test "light and variable wind" {
  let wind = decode_wind("9900")
  assert_true(wind.is_light_and_variable())
  assert_eq(wind.direction, None)
  assert_eq(wind.speed, 0)
}

///|
/// Speeds of 100 knots or more are encoded with the direction offset by 50
/// and the speed reduced by 100, so `7601` is 260 degrees at 101 knots.
test "wind of 100 knots or more" {
  let wind = decode_wind("7601")
  assert_eq(wind.direction, Some(260))
  assert_eq(wind.speed, 101)
  let fast = decode_wind("8654")
  assert_eq(fast.direction, Some(360))
  assert_eq(fast.speed, 154)
}

///|
test "malformed wind groups are rejected" {
  let bad : Array[String] = ["271", "27x3", "9999", "4500", "9901"]
  for group in bad {
    let failed = try {
      let _ = decode_wind(group)
      false
    } catch {
      FdError::BadWindGroup(_) => true
      _ => false
    }
    assert_true(failed)
  }
}

///|
test "wind groups round trip" {
  let groups : Array[String] = ["9900", "2713", "0000", "3606", "7601", "8654"]
  for group in groups {
    assert_eq(encode_wind(decode_wind(group)), group)
  }
}

///|
/// Above 24,000 ft the sign is dropped from the temperature, so a bare
/// two-digit field is a negative temperature.
test "temperature fields round trip" {
  assert_eq(decode_temperature("+18", false, "ABR", 12000), 18)
  assert_eq(decode_temperature("-06", false, "ABR", 18000), -6)
  assert_eq(decode_temperature("33", true, "ABR", 30000), -33)
  assert_eq(encode_temperature(18, 12000), "+18")
  assert_eq(encode_temperature(-6, 18000), "-06")
  assert_eq(encode_temperature(-33, 30000), "33")
  assert_eq(
    encode_level({
      altitude: 3000,
      wind: decode_wind("1519"),
      temperature: None,
    }),
    "1519",
  )
  assert_eq(
    encode_level({
      altitude: 24000,
      wind: decode_wind("1612"),
      temperature: Some(-25),
    }),
    "1612-25",
  )
  assert_eq(
    encode_level({
      altitude: 39000,
      wind: decode_wind("2577"),
      temperature: Some(-56),
    }),
    "257756",
  )
}

///|
/// The column layout follows from the level list: 4,000 ft carries no
/// temperature, levels above 24,000 ft carry an unsigned one.
test "column layout is derived from the level list" {
  let low = field_layout([3000, 6000, 9000])
  assert_eq(low, [(4, 4), (9, 7), (17, 7)])
  let high = field_layout([45000, 53000])
  assert_eq(high, [(4, 6), (11, 6)])
}

///|
test "bulletin header" {
  let bulletin = parse_bulletin(fixture_fd1us1)
  assert_eq(bulletin.designator, Some("FD1US1"))
  assert_eq(bulletin.wmo_header, Some("FBUS31 KWNO 221358"))
  assert_eq(bulletin.based_on, Some("221200Z"))
  assert_eq(bulletin.valid, Some("221800Z"))
  assert_eq(bulletin.use_window, Some("1400-2100Z"))
  assert_eq(bulletin.temps_negative_above, Some(24000))
  assert_eq(bulletin.altitudes, [
    3000, 6000, 9000, 12000, 18000, 24000, 30000, 34000, 39000,
  ])
  assert_eq(bulletin.stations.length(), 176)
}

///|
/// Values read straight off the wire: `ABR` is the first line with all nine
/// columns filled, `ACK` and `BGR` carry high-level temperatures and a
/// triple-digit wind speed, and `MBW` reports a level without a temperature.
test "station values from a real bulletin" {
  let bulletin = parse_bulletin(fixture_fd1us1)

  let abr = bulletin.station("ABR").unwrap()
  let low = abr.level_at(3000).unwrap()
  assert_eq(low.wind.direction, Some(150))
  assert_eq(low.wind.speed, 19)
  assert_eq(low.temperature, None)
  let mid = abr.level_at(24000).unwrap()
  assert_eq(mid.wind.direction, Some(160))
  assert_eq(mid.wind.speed, 12)
  assert_eq(mid.temperature, Some(-25))
  let top = abr.level_at(30000).unwrap()
  assert_eq(top.wind.direction, Some(260))
  assert_eq(top.wind.speed, 7)
  assert_eq(top.temperature, Some(-39))

  let ack = bulletin.station("ACK").unwrap()
  let ack_top = ack.level_at(39000).unwrap()
  assert_eq(ack_top.wind.direction, Some(250))
  assert_eq(ack_top.wind.speed, 77)
  assert_eq(ack_top.temperature, Some(-56))

  let bgr = bulletin.station("BGR").unwrap()
  let bgr_top = bgr.level_at(34000).unwrap()
  assert_eq(bgr_top.wind.direction, Some(260))
  assert_eq(bgr_top.wind.speed, 115)
  assert_eq(bgr_top.temperature, Some(-48))

  let tvc = bulletin.station("TVC").unwrap()
  let tvc_top = tvc.level_at(34000).unwrap()
  assert_true(tvc_top.wind.is_light_and_variable())
  assert_eq(tvc_top.temperature, Some(-52))

  // A station with no data for a level simply has no entry for it.
  let abi = bulletin.station("ABI").unwrap()
  assert_true(abi.level_at(3000) is None)
  assert_eq(abi.level_at(6000).unwrap().wind.speed, 5)

  // A level can carry a wind without a temperature.
  let mbw = bulletin.station("MBW").unwrap()
  let mbw_mid = mbw.level_at(9000).unwrap()
  assert_eq(mbw_mid.wind.direction, Some(250))
  assert_eq(mbw_mid.wind.speed, 9)
  assert_eq(mbw_mid.temperature, None)
}

///|
/// The high-level product lists two levels, 30,000 ft apart.
test "high level product" {
  let bulletin = parse_bulletin(fixture_fd8us7)
  assert_eq(bulletin.designator, Some("FD8US7"))
  assert_eq(bulletin.altitudes, [45000, 53000])
  let abi = bulletin.station("ABI").unwrap()
  let low = abi.level_at(45000).unwrap()
  assert_eq(low.wind.direction, Some(260))
  assert_eq(low.wind.speed, 28)
  assert_eq(low.temperature, Some(-63))
  let high = abi.level_at(53000).unwrap()
  assert_eq(high.wind.direction, Some(250))
  assert_eq(high.wind.speed, 17)
  assert_eq(high.temperature, Some(-73))
}

///|
/// Parsing and re-formatting a real product must reproduce it exactly.
test "bulletins round trip byte for byte" {
  let fixtures : Array[String] = [
    fixture_fd1us1, fixture_fd2us1, fixture_fd8us7,
  ]
  for fixture in fixtures {
    assert_eq(format_bulletin(parse_bulletin(fixture)), fixture)
  }
}

///|
/// Every station of the sample survives a parse, a re-format and a second
/// parse with all of its levels intact.
test "every station survives a round trip" {
  let bulletin = parse_bulletin(fixture_fd1us1)
  let reparsed = parse_bulletin(format_bulletin(bulletin))
  assert_eq(reparsed.stations.length(), bulletin.stations.length())
  for i = 0; i < bulletin.stations.length(); i = i + 1 {
    let before = bulletin.stations[i]
    let after = reparsed.stations[i]
    assert_eq(after.station, before.station)
    assert_eq(after.levels.length(), before.levels.length())
    for j = 0; j < before.levels.length(); j = j + 1 {
      assert_eq(after.levels[j].altitude, before.levels[j].altitude)
      assert_eq(after.levels[j].wind.direction, before.levels[j].wind.direction)
      assert_eq(after.levels[j].wind.speed, before.levels[j].wind.speed)
      assert_eq(after.levels[j].temperature, before.levels[j].temperature)
    }
  }
}

///|
test "a bulletin without a level header is rejected" {
  let failed = try {
    let _ = parse_bulletin("FBUS31 KWNO 221358\nno level header here\n")
    false
  } catch {
    FdError::MissingLevelHeader => true
    _ => false
  }
  assert_true(failed)
}
