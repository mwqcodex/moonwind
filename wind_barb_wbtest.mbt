///|
/// The feathers count the speed out in fifties, tens and fives: 25 kt is two
/// full barbs and a half one, 65 kt is a pennant and one of each, 150 kt is
/// three pennants, and 10 kt is a single full barb.
test "a barb counts the feathers out" {
  let quarter = WindBarb::from_wind(Wind::new(Some(270), 25))
  assert_eq(quarter.direction_tens(), 27)
  assert_eq(quarter.pennants(), 0)
  assert_eq(quarter.full_barbs(), 2)
  assert_eq(quarter.half_barbs(), 1)
  assert_true(quarter.speed_knots() == 25.0)
  let gale = WindBarb::from_wind(Wind::new(Some(150), 65))
  assert_eq(gale.direction_tens(), 15)
  assert_eq(gale.pennants(), 1)
  assert_eq(gale.full_barbs(), 1)
  assert_eq(gale.half_barbs(), 1)
  assert_true(gale.speed_knots() == 65.0)
  let hurricane = WindBarb::from_wind(Wind::new(Some(90), 150))
  assert_eq(hurricane.pennants(), 3)
  assert_eq(hurricane.full_barbs(), 0)
  assert_eq(hurricane.half_barbs(), 0)
  assert_true(hurricane.speed_knots() == 150.0)
  let breeze = WindBarb::from_wind(Wind::new(Some(180), 10))
  assert_eq(breeze.pennants(), 0)
  assert_eq(breeze.full_barbs(), 1)
  assert_eq(breeze.half_barbs(), 0)
}

///|
/// The barb as a station plot draws it: the feathers along the staff, from the
/// pennants down to the half barbs, and a bare staff for a wind too light to
/// feather. The ASCII form spells the same barb with characters every font has.
test "a barb is drawn with the station plot's characters" {
  let quarter = WindBarb::from_wind(Wind::new(Some(270), 25))
  assert_eq(quarter.to_unicode(), "──╌│")
  assert_eq(quarter.to_ascii(), "==-|")
  let gale = WindBarb::from_wind(Wind::new(Some(150), 65))
  assert_eq(gale.to_unicode(), "⚑─╌│")
  assert_eq(gale.to_ascii(), "P=-|")
  let hurricane = WindBarb::from_wind(Wind::new(Some(90), 150))
  assert_eq(hurricane.to_unicode(), "⚑⚑⚑│")
  assert_eq(hurricane.to_ascii(), "PPP|")
  assert_eq(WindBarb::from_wind(Wind::new(Some(180), 10)).to_ascii(), "=|")
  assert_eq(WindBarb::from_wind(Wind::new(Some(180), 2)).to_ascii(), "|")
}

///|
/// A calm is a circle and no staff, and a wind with a direction but too little
/// speed to draw a feather is not a calm: it has a staff, and it points
/// somewhere.
test "a calm is a circle and a still wind is a staff" {
  let calm = WindBarb::from_wind(Wind::new(None, 0))
  assert_true(calm.is_calm())
  assert_eq(calm.to_unicode(), "○")
  assert_eq(calm.to_ascii(), "O")
  assert_eq(calm.direction_tens(), 0)
  assert_true(calm.speed_knots() == 0.0)
  let still = WindBarb::from_wind(Wind::new(Some(270), 2))
  assert_false(still.is_calm())
  assert_eq(still.to_unicode(), "│")
  assert_true(still.speed_knots() == 0.0)
}

///|
/// The feathers are drawn to the nearest 5 knots, which is all they can say:
/// 12 kt is drawn as 10, 13 as 15, 3 as 5, and 2 as nothing at all.
test "a barb rounds its speed to the nearest five knots" {
  assert_true(
    WindBarb::from_wind(Wind::new(Some(270), 12)).speed_knots() == 10.0,
  )
  assert_true(
    WindBarb::from_wind(Wind::new(Some(270), 13)).speed_knots() == 15.0,
  )
  assert_true(WindBarb::from_wind(Wind::new(Some(270), 3)).speed_knots() == 5.0)
  assert_true(WindBarb::from_wind(Wind::new(Some(270), 2)).speed_knots() == 0.0)
  assert_eq(WindBarb::from_wind(Wind::new(Some(270), 13)).to_ascii(), "=-|")
  assert_eq(WindBarb::from_wind(Wind::new(Some(270), 3)).to_ascii(), "-|")
}

///|
/// The direction is held in tens of degrees, which is how a station plot
/// writes it: 270° is 27, and a wind out of the north is 36 so that 0 can mean
/// "no direction" and the two can be told apart. Reading the wind back gives
/// the direction it was drawn from — 0° for the north, and its own degrees
/// otherwise — at the rounded speed.
test "a direction reads back as it was drawn" {
  let quarter = WindBarb::from_wind(Wind::new(Some(270), 25))
  assert_true(quarter.to_wind().direction() == Some(270))
  assert_eq(quarter.to_wind().speed(), 25)
  let north = WindBarb::from_wind(Wind::new(Some(0), 10))
  assert_eq(north.direction_tens(), 36)
  assert_true(north.to_wind().direction() == Some(0))
  assert_eq(north.to_wind().speed(), 10)
  // 360° and 0° are the same direction, and what is drawn for one reads back
  // as the other.
  assert_eq(WindBarb::from_wind(Wind::new(Some(360), 10)).direction_tens(), 36)
  assert_true(
    WindBarb::from_wind(Wind::new(Some(360), 10)).to_wind().direction() ==
    Some(0),
  )
  let light = WindBarb::from_wind(Wind::new(Some(270), 3))
  assert_true(light.to_wind().direction() == Some(270))
  assert_eq(light.to_wind().speed(), 5)
  let calm = WindBarb::from_wind(Wind::new(None, 0))
  assert_true(calm.to_wind().is_light_and_variable())
  assert_eq(calm.to_wind().speed(), 0)
  let still = WindBarb::from_wind(Wind::new(Some(270), 0))
  assert_true(still.to_wind().direction() == Some(270))
  assert_eq(still.to_wind().speed(), 0)
}

///|
/// The two numbers a wind is reported with can be given directly, without a
/// `Wind` to put them in.
test "a barb is built from a direction and a speed" {
  let barb = WindBarb::from_knots(Some(90), 45.0)
  assert_eq(barb.direction_tens(), 9)
  assert_eq(barb.pennants(), 0)
  assert_eq(barb.full_barbs(), 4)
  assert_eq(barb.half_barbs(), 1)
  assert_true(barb.to_wind().direction() == Some(90))
  assert_eq(WindBarb::from_knots(None, 20.0).direction_tens(), 0)
}

///|
/// A wind does not blow backwards: a negative speed is refused, and the error
/// carries the offending speed.
test "a negative wind speed is refused" {
  let from_wind_failed = try {
    let _ = WindBarb::from_wind(Wind::new(Some(270), -1))
    false
  } catch {
    WindBarbError::BadWindSpeed(refused) => refused == -1.0
  }
  assert_true(from_wind_failed)
  let from_knots_failed = try {
    let _ = WindBarb::from_knots(Some(270), -2.5)
    false
  } catch {
    WindBarbError::BadWindSpeed(refused) => refused == -2.5
  }
  assert_true(from_knots_failed)
}
