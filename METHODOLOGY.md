# Methodology & Data Sourcing

Full formula-by-formula documentation.

---

## 1. Network & Distance

- **Airports:** `FRA`, `MUC` (hubs); `KRK`, `WAW`, `PRG`, `BUD`, `POZ` (spokes). Coordinates from OpenFlights `airports.dat` **[Sourced]**. OpenFlights' route data (which airline flies where) is explicitly excluded. The provider stopped updating it in 2014.
- **Distance:** Great-circle (Haversine), via `geosphere::distHaversine()`. Real airway routing is typically slightly longer than the great-circle distance between the airports. Noted as a simplification.

## 2. Fleet Specifications

| Aircraft | Seats | MTOW | Cruise Speed | Source |
|---|---|---|---|---|
| A319-100 | 138 | 68.0 t | 840 km/h | Lufthansa Group fleet page: https://www.lufthansagroup.com/en/company/fleet/lufthansa-and-regional-partners.html#collapse-6478 |
| A320neo | 180 | 73.5 t  | 840 km/h | same as above |
| A321neo | 215 | 89.0 t  | 840 km/h | same as above |

## 3. Fuel Burn

**Method:** piecewise linear interpolation (`approx()`, `rule = 2`) over five real ICAO stage-length data points per aircraft (125/250/500/750/1000 nm) **[Source: ICAO Carbon Emissions Calculator Methodology v13.1, Appendix C, Link: https://icec.icao.int/Documents/Methodology%20ICAO%20Carbon%20Emissions%20Calculator_v13_Final.pdf]**.

A global linear regression was tested first and rejected: A320neo/A321neo fuel burn is genuinely linear across this range, but A319's real data is not (a steep near 3x jump in per-nm burn between 125nm and 250nm), so a single fitted line distorted its short-distance fuel cost by ~25%. Interpolation preserves the real, non-linear shape instead.

**Fuel price:** €1.11/kg **[Source: IATA Jet Fuel Price Monitor, Link: https://www.iata.org/en/publications/economics/fuel-monitor/]**. Noted as elevated due to the 2026 fuel-price crisis.

## 4. Block Time

```
Block Hours = (Distance_km / 840) + 0.35
```
[Assumption] The 0.35h (21 min) buffer covers taxi and speed restrictions (take-off, landing). This is an assumed flat figure, not airport-specific.

## 5. En-Route Navigation Charges

```
Fee = (Distance_km / 100) × √(MTOW_tonnes / 50) × Blended_Unit_Rate
Blended_Unit_Rate = (Origin_Country_Rate + Destination_Country_Rate) / 2
```
Formula verified against EUROCONTROL's *"Conditions of Application of the Route Charges System and Conditions of Payment"* **[Link: https://www.eurocontrol.int/sites/default/files/2021-10/doc-21-60-02-eurocontrol-conditions-application-november-2021-en.pdf]**. Origin/destination averaging is a stated simplification for the true per-country-crossed, distance-weighted calculation.

| Country | Unit Rate (€) | Source |
|---|---|---|
| Germany | 97.79 | EUROCONTROL's adjusted unit rates table: https://www.eurocontrol.int/sites/default/files/2026-07/ur2607.pdf |
| Poland | 98.29 | same as above |
| Czech Republic | 79.34 | same as above |
| Hungary | 42.73 | same as above |

## 6. Airport Charges

Passenger-count charges are **departure-only** in both real tariffs (no charge on arriving passengers). Mass charges apply to every movement, landing and takeoff alike.

**Frankfurt** (Fraport, "Airport Charges according to Art. 19b Air Traffic Act",  **[Source: https://www.fraport.com/en/business-areas/operations/airport-charges.html]**):
```
Mass fee = €2.50 × ⌈MTOW_tonnes⌉  (per movement)
Passenger fee = €28.10/departing passenger
             = €1.79 (§1.2.4) + €24.56 (§1.3.2) + €1.63 (§1.4) + €0.12 (§1.6.2)
```

**Munich** (Flughafen München, Airport Charges Tariff Regulations 2026, Part 1 **[Source: https://www.munich-airport.com/airport-charges-1325117]**):
```
Mass fee = €2.38 × ⌈MTOW_tonnes⌉  (per movement)
Passenger fee = €27.86/departing passenger = €26.36 (§2.6) + €1.50 (§2.11)
```

**Spoke airports** (KRK/WAW/PRG/BUD/POZ) [Assumption], not sourced from national tariffs but estimated lower than the hub airport tariffs:
```
Mass fee = €2.00 × ⌈MTOW_tonnes⌉
Passenger fee = €15.00/departing passenger
```
Deliberately excluded: noise-based charges, emissions/pollution charges (require certified per-engine NOx data), and many more. 

## 7. Round-Trip Cost Accounting

Because passenger fees are departure-only, a full rotation (Hub↔Spoke) is built as:
```
Mass fees:     2 × (Hub_mass_fee + Spoke_mass_fee)     — charged every movement
Passenger fees: Pax × (Hub_pax_fee + Spoke_pax_fee)    — charged once each, at own departure point
Fuel, hourly DOC, en-route fees: 2 × one-way value     — symmetric both directions
```

## 8. Fixed Hourly DOC

```
Hourly Cost = Block Hours × €1,800/hr
```
[Assumption] Crew, ownership, and maintenance combined. No airline publicly discloses this at per-aircraft-type, per-block-hour granularity.

## 9. Yield

```
Yield = Passenger Traffic Revenue / RPK = €0.103/RPK (rounded to €0.10 in the model)
```
Derived from Lufthansa Group's own disclosed 2025 figures [Source 1: https://report.lufthansagroup.com/2025/annual-report/en/company/key-figures-lufthansa-group/] [Source 2: https://report.lufthansagroup.com/2025/annual-report/en/combined-management-report/economic-report/financial-performance/earnings-position/]: €28,623m passenger traffic revenue ÷ 281,765m RPK. Passenger (not total) traffic revenue is used deliberately. Total traffic revenue includes cargo revenue (€3,702m in 2025), which is generated by RTK, not RPK. Mixing the two would be a unit mismatch. This is a system-wide average across short- and long-haul combined. Actual short-haul yield is likely somewhat higher.

## 10. Air Traffic Metrics

```
CASK = Total DOC / (Seats × Distance × 2) - this is the round trip CASK; hence the 2 in the denominator
BELF = CASK / Yield
Actual LF = min(Demand, Seats) / Seats
```
