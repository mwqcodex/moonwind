///|
/// A station with three levels, the wind strengthening with height. The
/// route below runs east and the wind is a westerly, so every level is a
/// tailwind and the highest one is the fastest.
fn climbing_station() -> StationWinds {
  {
    station: "TEST",
    levels: [
      { altitude: 6000, wind: Wind::new(Some(270), 10), temperature: Some(5), },
      {
        altitude: 12000,
        wind: Wind::new(Some(270), 40),
        temperature: Some(-5),
      },
      {
        altitude: 18000,
        wind: Wind::new(Some(270), 70),
        temperature: Some(-20),
      },
    ],
  }
}

///|
/// The same shape, with a middle level whose wind is stronger than the
/// airspeed and straight ahead — a level no aeroplane can fly.
fn station_with_an_unfliable_level() -> StationWinds {
  {
    station: "MIX",
    levels: [
      { altitude: 6000, wind: Wind::new(Some(270), 10), temperature: Some(5), },
      {
        altitude: 9000,
        wind: Wind::new(Some(90), 200),
        temperature: Some(-10),
      },
      {
        altitude: 12000,
        wind: Wind::new(Some(270), 40),
        temperature: Some(-5),
      },
    ],
  }
}

///|
/// A two-leg route running east along the equator, where a course of 090 is
/// exact rather than nearly so.
fn eastbound_route() -> Route {
  Route::new([
    Coordinate::new(0.0, -100.0),
    Coordinate::new(0.0, -99.0),
    Coordinate::new(0.0, -98.0),
  ])
}

///|
test "every forecast level is planned" {
  let plans = eastbound_route().plans_at_levels(climbing_station(), 120.0)
  inspect(plans.length().to_string(), content="3")
}

///|
/// The study is worth nothing unless it is ordered, and ordered fastest
/// first: that is the first line of the answer.
test "the levels come back fastest first" {
  let plans = eastbound_route().plans_at_levels(climbing_station(), 120.0)
  inspect(plans[0].altitude().to_string(), content="18000")
  inspect(plans[1].altitude().to_string(), content="12000")
  inspect(plans[2].altitude().to_string(), content="6000")
  inspect(
    (plans[0].total_time_hours() < plans[1].total_time_hours()).to_string(),
    content="true",
  )
  inspect(
    (plans[1].total_time_hours() < plans[2].total_time_hours()).to_string(),
    content="true",
  )
  match eastbound_route().fastest_level(climbing_station(), 120.0) {
    Some(fastest) => inspect(fastest.altitude().to_string(), content="18000")
    None => abort("a station with three flyable levels has a fastest one")
  }
}

///|
/// The route and the airspeed do not change with height, so the still-air
/// time is the same at every level and only the wind moves the total. That
/// is what makes the difference between the plans the wind's doing.
test "the still-air time is the same at every level" {
  let plans = eastbound_route().plans_at_levels(climbing_station(), 120.0)
  let still = plans[0].still_air_time_hours()
  for plan in plans {
    inspect((plan.still_air_time_hours() == still).to_string(), content="true")
    // A tailwind: the flight is quicker than it would be in still air.
    inspect((plan.wind_effect_hours() < 0.0).to_string(), content="true")
  }
}

///|
test "the wind effect is the difference between the two times" {
  let plans = eastbound_route().plans_at_levels(climbing_station(), 120.0)
  let plan = plans[0]
  let expected = plan.total_time_hours() - plan.still_air_time_hours()
  inspect((plan.wind_effect_hours() == expected).to_string(), content="true")
}

///|
test "fuel is the time at the burn rate, plus the reserve" {
  let plan = eastbound_route().fastest_level(climbing_station(), 120.0).unwrap()
  let fuel = plan.fuel(8.0, 45.0)
  inspect(
    (fuel.trip_hours() == plan.total_time_hours()).to_string(),
    content="true",
  )
  inspect(
    (fuel.trip_fuel() == plan.total_time_hours() * 8.0).to_string(),
    content="true",
  )
  inspect((fuel.reserve_fuel() == 0.75 * 8.0).to_string(), content="true")
  inspect(
    (fuel.total_fuel() == fuel.trip_fuel() + fuel.reserve_fuel()).to_string(),
    content="true",
  )
}

///|
/// A level whose wind is stronger than the airspeed and straight ahead has
/// no ground speed, so it is dropped rather than sinking the study.
test "a level that cannot be flown is left out" {
  let plans = eastbound_route().plans_at_levels(
    station_with_an_unfliable_level(),
    120.0,
  )
  inspect(plans.length().to_string(), content="2")
  inspect(plans[0].altitude().to_string(), content="12000")
  inspect(plans[1].altitude().to_string(), content="6000")
}

///|
test "a station with no flyable level has no fastest level" {
  let empty : StationWinds = { station: "NONE", levels: [], }
  match eastbound_route().fastest_level(empty, 120.0) {
    Some(_) => abort("a station with no levels has no fastest")
    None => inspect("none", content="none")
  }
}
