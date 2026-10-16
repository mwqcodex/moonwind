///|
/// Planning a route against a whole forecast.
///
/// `Route::plan` answers what one level at one airspeed costs. A flight plan
/// asks two more questions: which of the forecast levels is worth flying, and
/// what the tank has to carry to fly it. Both are arithmetic over the legs a
/// plan already carries, so they live here rather than in the triangle.

///|
/// What a plan burns.
pub struct FuelPlan {
  trip_hours : Double
  trip_fuel : Double
  reserve_fuel : Double
}

///|
/// The fuel for a plan at `burn_per_hour`, with a reserve expressed in
/// minutes of flying.
pub fn RoutePlan::fuel(
  self : RoutePlan,
  burn_per_hour : Double,
  reserve_minutes : Double,
) -> FuelPlan {
  let hours = self.total_time_hours()
  {
    trip_hours: hours,
    trip_fuel: hours * burn_per_hour,
    reserve_fuel: reserve_minutes / 60.0 * burn_per_hour,
  }
}

///|
/// The time the plan takes, in hours.
pub fn FuelPlan::trip_hours(self : FuelPlan) -> Double {
  self.trip_hours
}

///|
/// The fuel the flight itself burns.
pub fn FuelPlan::trip_fuel(self : FuelPlan) -> Double {
  self.trip_fuel
}

///|
/// The fuel the reserve needs.
pub fn FuelPlan::reserve_fuel(self : FuelPlan) -> Double {
  self.reserve_fuel
}

///|
/// Trip fuel and reserve together, which is what has to be aboard.
pub fn FuelPlan::total_fuel(self : FuelPlan) -> Double {
  self.trip_fuel + self.reserve_fuel
}

///|
/// The time the same route would take in still air: the distance at the
/// plan's airspeed, with no wind at all.
pub fn RoutePlan::still_air_time_hours(self : RoutePlan) -> Double {
  self.total_distance() / self.airspeed()
}

///|
/// What the wind is worth on this route, in hours: positive when the flight
/// takes longer than it would in still air, negative when the wind pays.
pub fn RoutePlan::wind_effect_hours(self : RoutePlan) -> Double {
  self.total_time_hours() - self.still_air_time_hours()
}

///|
/// The route planned at every level the station forecasts, the fastest level
/// first.
///
/// A level the station does not forecast, or one whose wind leaves no ground
/// speed, is left out rather than failing the whole study — a level that
/// cannot be flown is not an answer, but it is not a reason to stop asking
/// about the others.
pub fn Route::plans_at_levels(
  self : Route,
  station : StationWinds,
  airspeed : Double,
) -> Array[RoutePlan] {
  let plans : Array[RoutePlan] = []
  for level in station.levels() {
    let planned = Some(self.plan(station, level.altitude(), airspeed)) catch {
      _ => None
    }
    match planned {
      Some(plan) => plans.push(plan)
      None => ()
    }
  }
  sort_by_total_time(plans)
  plans
}

///|
/// The fastest level the station forecasts, or `None` when none of them can
/// be flown.
pub fn Route::fastest_level(
  self : Route,
  station : StationWinds,
  airspeed : Double,
) -> RoutePlan? {
  let plans = self.plans_at_levels(station, airspeed)
  if plans.length() == 0 {
    None
  } else {
    Some(plans[0])
  }
}

///|
/// Put the plans in order of total time, fastest first.
fn sort_by_total_time(plans : Array[RoutePlan]) -> Unit {
  for i = 1; i < plans.length(); i = i + 1 {
    let current = plans[i]
    let mut j = i
    while j > 0 && plans[j - 1].total_time_hours() > current.total_time_hours() {
      plans[j] = plans[j - 1]
      j -= 1
    }
    plans[j] = current
  }
}
