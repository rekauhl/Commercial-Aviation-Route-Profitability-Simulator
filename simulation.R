library(tidyverse)
library(geosphere)

# ==============================================================================
# GLOBAL PARAMETERS
# ==============================================================================
JET_FUEL_EUR_PER_KG   <- 1.11   # Jet fuel cost (€/kg)
HOURLY_DOC_EUR_PER_HR <- 1800   # Non-fuel DOC (Crew, Ownership, Maintenance)
YIELD_EUR_PER_RPK     <- 0.10   # System-wide passenger yield (€/RPK)
CRUISE_SPEED_KMH      <- 840    # Cruise speed (km/h)
BLOCK_BUFFER_HOURS    <- 0.35   # Taxiing and Speed Restriction buffer (hours)

# Spoke Airport Fee Estimates
DEFAULT_SPOKE_MASS_FEE <- 2.00  # Take-off/Landing mass fee (€/tonne MTOW)
DEFAULT_SPOKE_PAX_FEE  <- 15.00 # Passenger departure fee (€/passenger)

# OpenFlights Dataset URL & Target Network
OPENFLIGHTS_URL <- "https://raw.githubusercontent.com/jpatokal/openflights/master/data/airports.dat"
TARGET_IATAS    <- c("FRA", "MUC", "KRK", "WAW", "PRG", "BUD", "POZ")

# ==============================================================================
# 1. LOOKUP TABLES & DATA
# ==============================================================================
# Fuel Consumption Table
fuel_samples <- tibble(
  aircraft_type = rep(c("A319", "A320neo", "A321neo"), each = 5),
  dist_nm       = rep(c(125, 250, 500, 750, 1000), times = 3),
  fuel_kg       = c(
    # A319 Samples
    1596, 3259, 4323, 5830, 7271,
    # A320neo Samples
    1714, 2360, 3652, 4944, 6236,
    # A321neo Samples
    2090, 2790, 4191, 5592, 6992
  )
)

# Fleet Specifications
fleet_specs <- tibble(
  aircraft_type = c("A319", "A320neo", "A321neo"),
  seats         = c(138, 180, 215),
  mtow_tonnes   = c(68.0, 73.5, 89.0)
)

# Airport Fee Structure (Hub Tariffs vs Spoke Estimates)
airport_tariffs <- tibble(
  iata             = c("FRA", "MUC", "KRK", "WAW", "PRG", "BUD", "POZ"),
  country          = c("DE",  "DE",  "PL",  "PL",  "CZ",  "HU",  "PL"),
  mass_fee_per_t   = c(2.50,  2.38,  DEFAULT_SPOKE_MASS_FEE, DEFAULT_SPOKE_MASS_FEE, DEFAULT_SPOKE_MASS_FEE, DEFAULT_SPOKE_MASS_FEE, DEFAULT_SPOKE_MASS_FEE),
  pax_fee_per_pax  = c(28.10, 27.86, DEFAULT_SPOKE_PAX_FEE,  DEFAULT_SPOKE_PAX_FEE,  DEFAULT_SPOKE_PAX_FEE,  DEFAULT_SPOKE_PAX_FEE,  DEFAULT_SPOKE_PAX_FEE)
)

# EUROCONTROL Unit Rates (En-Route Charges)
unit_rates <- tibble(
  country   = c("DE", "PL", "CZ", "HU"),
  unit_rate = c(97.79, 98.29, 79.34, 42.73)
)

# Fetch Geographic Coordinates from OpenFlights
airports_geo <- read_csv(OPENFLIGHTS_URL, col_names = FALSE, show_col_types = FALSE) %>%
  select(iata = X5, latitude = X7, longitude = X8) %>%
  filter(iata %in% TARGET_IATAS)

# ==============================================================================
# 2. SCENARIO MATRIX GENERATION (210 Combinations)
# ==============================================================================
scenario_matrix <- crossing(
  hub_code         = c("FRA", "MUC"),
  spoke_code       = c("KRK", "WAW", "PRG", "BUD", "POZ"),
  aircraft_type    = c("A319", "A320neo", "A321neo"),
  passenger_demand = seq(100, 220, by = 20)
)

# ==============================================================================
# 3. SIMULATION
# ==============================================================================
simulation_results <- scenario_matrix %>%
  # Attach Aircraft Specs
  left_join(fleet_specs, by = "aircraft_type") %>%
  
  # Attach Airport Coordinates & Tariffs
  left_join(airports_geo, by = c("hub_code" = "iata")) %>%
  rename(hub_lat = latitude, hub_lon = longitude) %>%
  left_join(airports_geo, by = c("spoke_code" = "iata")) %>%
  rename(spoke_lat = latitude, spoke_lon = longitude) %>%
  
  left_join(airport_tariffs, by = c("hub_code" = "iata")) %>%
  rename(hub_country = country, hub_mass_fee = mass_fee_per_t, hub_pax_fee = pax_fee_per_pax) %>%
  left_join(airport_tariffs, by = c("spoke_code" = "iata")) %>%
  rename(spoke_country = country, spoke_mass_fee = mass_fee_per_t, spoke_pax_fee = pax_fee_per_pax) %>%
  
  # Attach EUROCONTROL Unit Rates
  left_join(unit_rates, by = c("hub_country" = "country")) %>%
  rename(hub_unit_rate = unit_rate) %>%
  left_join(unit_rates, by = c("spoke_country" = "country")) %>%
  rename(spoke_unit_rate = unit_rate) %>%
  
  # Calculate Flight Distances (Haversine)
  rowwise() %>%
  mutate(
    distance_km = distHaversine(c(hub_lon, hub_lat), c(spoke_lon, spoke_lat)) / 1000,
    distance_nm = distance_km / 1.852
  ) %>%
  ungroup() %>%
  
  # Calculate Fuel Consumption Via Piecewise Linear Interpolation
  group_by(aircraft_type) %>%
  mutate(
    one_way_fuel_kg = approx(
      x    = fuel_samples$dist_nm[fuel_samples$aircraft_type == first(aircraft_type)],
      y    = fuel_samples$fuel_kg[fuel_samples$aircraft_type == first(aircraft_type)],
      xout = distance_nm,
      rule = 2
    )$y
  ) %>%
  ungroup() %>%
  
  # Calculate Cost & Revenue
  mutate(
    # Traffic Scalars
    block_hours_per_leg = (distance_km / CRUISE_SPEED_KMH) + BLOCK_BUFFER_HOURS,
    passengers_boarded  = pmin(passenger_demand, seats),
    uncaptured_demand   = pmax(0, passenger_demand - seats),
    blended_unit_rate   = (hub_unit_rate + spoke_unit_rate) / 2,
    
    # Total Cost (Full Round Trip)
    roundtrip_fuel_cost    = 2 * (one_way_fuel_kg * JET_FUEL_EUR_PER_KG),
    roundtrip_hourly_cost  = 2 * (block_hours_per_leg * HOURLY_DOC_EUR_PER_HR),
    roundtrip_enroute_cost = 2 * ((distance_km / 100) * sqrt(mtow_tonnes / 50) * blended_unit_rate),
    roundtrip_mass_fees    = 2 * (ceiling(mtow_tonnes) * hub_mass_fee + ceiling(mtow_tonnes) * spoke_mass_fee),
    roundtrip_pax_fees     = passengers_boarded * hub_pax_fee + passengers_boarded * spoke_pax_fee,
    
    total_roundtrip_doc    = roundtrip_fuel_cost + roundtrip_hourly_cost + roundtrip_enroute_cost + roundtrip_mass_fees + roundtrip_pax_fees,
    
    # Revenue & Profit (Full Round Trip)
    roundtrip_revenue     = 2 * (passengers_boarded * distance_km * YIELD_EUR_PER_RPK),
    uncaptured_revenue    = 2 * (uncaptured_demand * distance_km * YIELD_EUR_PER_RPK),
    net_roundtrip_profit  = roundtrip_revenue - total_roundtrip_doc,
    
    # Unit Air Traffic Metrics
    cask_eur_per_ask      = total_roundtrip_doc / (2 * seats * distance_km),
    breakeven_lf          = round((total_roundtrip_doc / (2 * seats * distance_km * YIELD_EUR_PER_RPK)) * 100, 1),
    actual_lf             = round((passengers_boarded / seats) * 100, 1)
  )

# ==============================================================================
# 4. EXPORT FOR TABLEAU
# ==============================================================================
write_csv(simulation_results, "Simulation_Results_Final.csv")