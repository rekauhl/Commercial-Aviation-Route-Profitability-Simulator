# Commercial Aviation Route Profitability Simulator

A route-economics model evaluating 10 Lufthansa Group regional feeder routes into Frankfurt and Munich, across three aircraft types and seven demand scenarios, to answer one question: **when does an aircraft swap save a losing route, and when is the demand shortfall too structural for any aircraft to fix?**

---

## Key Findings

**1. The A319 is never the right choice, at any tested demand level, on any route.**
Despite having the lowest airport charges (smallest MTOW) of the three aircraft, its lack of neo-generation engines means it burns more fuel per leg than the larger A320neo at comparable distances (~4,323 kg vs. ~3,652 kg at 500nm, per ICAO's certified fuel data). Airframe size alone doesn't predict fuel efficiency. Engine generation does.

**2. The A320neo → A321neo crossover point is remarkably consistent across the network (~190–210 passengers), because it's driven by the aircraft seat capacity, not the route.**
A320neo's fixed 180-seat cap is the mechanism: below it, A320neo's higher load factor wins; above it, A321neo's extra capacity captures demand A320neo would not capture. This threshold holds within a narrow band regardless of which route is chosen.

**3. Prague routes (both FRA–PRG and MUC–PRG) are unprofitable across every aircraft and every demand level tested.**
This isn't a demand-dependent finding. It holds at both the lowest and highest tested demand. Very short-haul routes carry largely fixed costs against distance-scaled revenue.

**4. Munich–Poznań, cancelled by Lufthansa Group in 2026, is not an outlier by our model.**
Its profitability curve is nearly identical to still-operating routes like Munich–Kraków and Munich–Budapest. The model can explain why a route in this cost/demand band would struggle, but it cannot (from public data alone) explain why Poznań specifically was selected over its structural peers. That gap is consistent with the real deciding factor being actual passenger demand data (and a more sophisticated model), which only Lufthansa's own Network Management has access to. This is a genuine limitation of the model.

---

## How It Works

```
OpenFlights (airport coordinates)
        │
        ▼
R script: distance, fuel burn (ICAO-sourced interpolation),
airport charges (Fraport/Munich tariffs), EUROCONTROL navigation fees,
yield (Lufthansa Group 2025 annual report)
        │
        ▼
210 scenarios (10 routes × 3 aircraft × 7 demand tiers)
        │
        ▼
CSV export → Tableau Story
```

## Repository Structure

| File | Contents |
|---|---|
| `simulation.R` | Full model: data ingestion, cost/revenue engine, scenario matrix |
| `Simulation_Results_Final.csv` | 210-row model output, one row per route/aircraft/demand scenario |
| `METHODOLOGY.md` | Methodology, data source, and explicit exclusions. See this for full sourcing detail |
| `METRICS.md` | Explains typical air traffic metrics and why they are used |
| `Commercial Aviation Route Profitability.twbx` | Tableau Public story, workbook version |
| `Commercial Aviation Route Profitability.pdf` | Tableau Public story, pdf version |
| `http://public.tableau.com/views/CommercialAviationRouteProfitability/Story1` | Tableau Public story link, rendering may vary by browser  |

## Running the Model

```r
# Requires: tidyverse, geosphere
source("simulation.R")
# Outputs LHG_Simulation_Results_Final.csv
```

Open the `.twbx` in Tableau and connect to the two CSVs if paths need updating.

## Data Sources (summary — full detail in `METHODOLOGY.md`)

- **Airport Coordinates:** OpenFlights database
- **Aircraft Specifications:** Lufthansa Group official fleet configurations
- **Fuel Consumption:** ICAO Carbon Emissions Calculator (Methodology v13.1, Appendix C)
- **En-Route Navigation Charges:** EUROCONTROL adjusted unit rates (July 2026)
- **Airport Tariffs:** Fraport (Frankfurt) and Flughafen München (Munich) official 2026 fee schedules
- **Jet Fuel Pricing:** IATA Jet Fuel Price Monitor
- **Passenger Yield:** Derived from Lufthansa Group 2025 Annual Report (Passenger Traffic Revenue ÷ Disclosed RPK)

## Known Limitations

- In a Hub-and-Spoke model like Lufthansa's flight network, a short-haul feeder route (e.g. Frankfurt-Prague) may look unprofitable due to a high CASK that exceeds its local ticket yield. However, if the majority of those passengers connect onto a high margin long-haul flight to New York or Tokyo, the route generates massive profit, which doesn't show up in our simulation.
- Applies a single Lufthansa Group system-wide average yield across all routes rather than accounting for route-specific fares or seasonal dynamic pricing. As a result, very short routes (e.g. Munich-Prague) are heavily penalized.
- Revenue is modeled strictly on passenger traffic, but real-world revenue also depends on belly cargo capacity and ancillary revenue (bags, seat selection), which significantly impact short-haul feeder routes.
- Spoke-airport (KRK/WAW/PRG/BUD/POZ) fees are modeled as a flat proxy, not sourced from each country's actual tariff. Frankfurt and Munich's charges are sourced precisely (though simplified).
- Fixed hourly DOC (crew/ownership/maintenance) is a stated benchmark assumption. No public source discloses this at the required granularity for any carrier.
- EUROCONTROL en-route fees average origin and destination unit rates rather than summing every individual overflew airspace along the flight path.
- Passenger demand is assumed identical in both directions, overlooking real-world imbalances (e.g. heavy morning inbound to hub, lighter outbound).
- A full sensitivity analysis on fuel price and yield was scoped but not built, given project time constraints.

Full reasoning for every exclusion is in `METHODOLOGY.md`.
