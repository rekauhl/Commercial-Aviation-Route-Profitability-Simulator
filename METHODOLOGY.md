# Methodology & Data Sourcing

Full formula-by-formula documentation.

---

## 1. Network & Distance

- **Airports:** `FRA`, `MUC` (hubs); `KRK`, `WAW`, `PRG`, `BUD`, `POZ` (spokes). Coordinates from OpenFlights `airports.dat`. OpenFlights' route data (which airline flies where) is explicitly excluded. The provider stopped updating it in 2014.
- **Distance:** Great-circle (Haversine), via `geosphere::distHaversine()`. However, real airway routing is typically slightly longer than the great-circle distance between the airports. This is a simplification.

## 2. Fleet Specifications

| Aircraft | Seats | MTOW | Cruise Speed | Source |
|---|---|---|---|---|
| A319-100 | 138 | 68.0 t | 840 km/h | Lufthansa Group fleet page: https://www.lufthansagroup.com/en/company/fleet/lufthansa-and-regional-partners.html#collapse-6478 |
| A320neo | 180 | 73.5 t  | 840 km/h | same as above |
| A321neo | 215 | 89.0 t  | 840 km/h | same as above |

## 3. Fuel Burn

```
Fuel Cost = Trip_Fuel_kg × €1.11/kg
```

**Method:** piecewise linear interpolation (`approx()`, `rule = 2`) over five real ICAO stage-length data points per aircraft (125/250/500/750/1000 nm) **[Source: ICAO Carbon Emissions Calculator Methodology v13.1, Appendix C, https://icec.icao.int/Documents/Methodology%20ICAO%20Carbon%20Emissions%20Calculator_v13_Final.pdf]**.

A global linear regression was tested first and rejected: A320neo/A321neo fuel burn is genuinely linear across this range, but A319's real data is not (a steep near 3x jump in per-nm burn between 125nm and 250nm), so a single fitted line distorted its short-distance fuel cost by ~25%. Interpolation preserves the real, non-linear shape instead.

**Fuel price:** €1.11/kg **[Source: IATA Jet Fuel Price Monitor, https://www.iata.org/en/publications/economics/fuel-monitor/]**. Elevated due to the 2026 fuel-price crisis.

## 4. Block Time

```
Block Hours = (Distance_km / 840) + 0.35
```

[**Assumption**] The 0.35h (21 min) buffer covers taxi and speed restrictions (take-off, landing). This is an assumed flat figure, not airport-specific.

## 5. Fixed Hourly DOC (Direct Operating Cost)

```
Hourly Cost = Block Hours × €1,800/hr
```

[**Assumption**] Crew, ownership, and maintenance combined. No airline publicly discloses this at per-aircraft-type, per-block-hour granularity.

## 6. En-Route Navigation Charges

```
En-Route Fee = (Distance_km / 100) × sqrt(MTOW_tonnes / 50) × Blended Unit Rate
Blended Unit Rate = (Origin Country Rate + Destination Country Rate) / 2
```

Formula verified against EUROCONTROL's *"Conditions of Application of the Route Charges System and Conditions of Payment"* **[Source: https://www.eurocontrol.int/sites/default/files/2021-10/doc-21-60-02-eurocontrol-conditions-application-november-2021-en.pdf]**. Origin/destination averaging is a simplification for the true per-country-crossed calculation.

| Country | Unit Rate (€) | Source |
|---|---|---|
| Germany | 97.79 | EUROCONTROL's adjusted unit rates table: https://www.eurocontrol.int/sites/default/files/2026-07/ur2607.pdf |
| Poland | 98.29 | same as above |
| Czech Republic | 79.34 | same as above |
| Hungary | 42.73 | same as above |

## 7. Airport Charges

Passenger-count charges are **departure-only** in both real tariffs (no charge on arriving passengers). Mass charges apply to every movement, landing and takeoff alike.

**Frankfurt** **[Source: Fraport, Airport Charges according to Art. 19b Air Traffic Act, https://www.fraport.com/en/business-areas/operations/airport-charges.html]**:

```
Mass fee = €2.50 × ⌈MTOW_tonnes⌉  (per movement)
Passenger fee = €28.10/departing passenger
              = €1.79 (§1.2.4) + €24.56 (§1.3.2) + €1.63 (§1.4) + €0.12 (§1.6.2)
```

**Munich** **[Source: Flughafen München, Airport Charges Tariff Regulations 2026, Part 1, https://www.munich-airport.com/airport-charges-1325117]**):

```
Mass fee = €2.38 × ⌈MTOW_tonnes⌉  (per movement)
Passenger fee = €27.86/departing passenger
              = €26.36 (§2.6) + €1.50 (§2.11)
```

[**Assumption**] **Spoke airports** (KRK/WAW/PRG/BUD/POZ), not sourced from national tariffs due to simplification. Estimated lower than the hub airport tariffs:

```
Mass fee = €2.00 × ⌈MTOW_tonnes⌉
Passenger fee = €15.00/departing passenger
```

Deliberately excluded: noise-based charges, emissions/pollution charges (require certified per-engine NOx data), and many more, due to simplification.

## 8. Round Trip Cost Accounting 

To capture the full economic cost of operating a route, all financial line items are synthesized into a complete round trip rotation ($\text{Hub} \leftrightarrow \text{Spoke}$). [**Assumption**] We assumed that passenger demand is the same in each direction (due to simplifications):

### A. Flight Operational Expenses (Symmetric)
These parameters occur identically on both the outbound and inbound legs:

```
Operational Cost (Round Trip) = 2 × (Fuel Cost + Hourly Cost + En-Route Fee)
```

### B. Aircraft Mass Charges (4 Individual Airport Movements)
Because a complete round trip consists of two landings and two takeoffs, mass charges apply twice at the hub and twice at the spoke:

```
Mass Fee (Round Trip) = 2 × (Mass Fee Hub + Mass Fee Spoke)
```

### C. Passenger Handling Fees (Single Departure per Passenger)
Because passenger fees are assessed strictly at the airport of departure, each passenger on a round trip rotation pays the hub departure fee once and the spoke departure fee once:

```
Passenger Fee (Round Trip) = min(Demand, Seats) × (Passenger Fee Hub + Passenger Fee Spoke)
```

## 9. Yield

```
Yield = Passenger Traffic Revenue / RPK = €0.102/RPK (rounded to €0.10 in the model)
```

Derived from Lufthansa Group's own disclosed 2025 figures **[Source 1: https://report.lufthansagroup.com/2025/annual-report/en/company/key-figures-lufthansa-group/]**, **[Source 2: https://report.lufthansagroup.com/2025/annual-report/en/combined-management-report/economic-report/financial-performance/earnings-position/]**: €28,623m passenger traffic revenue ÷ 281,765m RPK. Passenger (not total) traffic revenue is used deliberately. Total traffic revenue includes cargo revenue (€3,702m in 2025), which is generated by RTK, not RPK. Mixing the two would be a unit mismatch. This is a system-wide average across short- and long-haul combined. Actual short-haul yield is likely somewhat higher.

## 10. Decision Metrics

```
Total DOC (Round Trip) = Operational Cost (Round Trip) + Mass Fee (Round Trip) + Passenger Fee (Round Trip)
Total Revenue (Round Trip) = 2 × min(Demand, Seats) × Distance_km × Yield
Net Profit (Round Trip ) = Total Revenue (Round Trip) - Total DOC (Round Trip)

CASK = Total DOC (Round Trip)/(Seats × Distance × 2) (Total DOC accounts for a round trip; hence the 2 in the denominator)
BELF = CASK / Yield
Actual LF = min(Demand, Seats) / Seats
```

Note: Total cost here reflects direct operating costs only. Indirect operating costs (ground handling, station administration, ...) are not modeled, so absolute CASK/BELF figures are understated relative to a full cost basis. However, this would likely only change the absolute profit/CASK/BELF numbers, but shouldn't meaningfully change the ranking (relative comparisons of which aircraft wins).
