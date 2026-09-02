A breakdown of the core air traffic and economic metrics in our simulator, detailing how they are calculated and why they drive network steering decisions.

---

**1. Block Hours (Operational Time)**

* **Formula:**

$$\text{Block Hours} = \left( \frac{\text{Distance (km)}}{\text{Cruise Speed (km/h)}} \right) + 0.35\text{ hrs}$$


* **What it measures:** Total time from gate pushback at departure to gate arrival at destination.
* **Why it matters:** Flight crew wages, aircraft lease payments, and engine maintenance intervals are billed per block hour, not pure flight time.
* **Why done this way:** Dividing distance by cruise speed only captures time spent at cruising altitude. Adding 0.35 hours (21 minutes) accounts for hub taxi-out (12 min), outstation taxi-in (5 min), and low-altitude speed restrictions below 10,000 ft (4 min).

---

**2. Available Seat-Kilometers (ASK)**

* **Formula:**

$$\text{ASK} = \text{Seats} \times \text{Distance (km)}$$


* **What it measures:** The total passenger carrying capacity produced by a flight.
* **Why it matters:** It is the standard global metric for an airline's production output.
* **Why done this way:** A 100-seat plane flying 500 km (50,000 ASK) produces the same raw passenger capacity as a 200-seat plane flying 250 km. Multiplying seats by distance normalizes capacity across different routes and aircraft sizes.

---

**3. Revenue Passenger-Kilometers (RPK)**

* **Formula:**

$$\text{RPK} = \min(\text{Demand}, \text{Seats}) \times \text{Distance (km)}$$


* **What it measures:** The volume of paid passenger traffic carried over a given distance.
* **Why it matters:** Represents actual sold capacity (traffic volume).
* **Why done this way:** Using $\min(\text{Demand}, \text{Seats})$ caps passenger count at physical aircraft capacity, ensuring you never calculate revenue on seats that do not exist.

---

**4. Actual Load Factor (LF)**

* **Formula:**

$$\text{Load Factor (\%)} = \frac{\text{RPK}}{\text{ASK}} = \frac{\min(\text{Demand}, \text{Seats})}{\text{Seats}}$$


* **What it measures:** The percentage of available seats filled by paying passengers.
* **Why it matters:** Shows how efficiently an airline fills the capacity it puts into the market.
* **Why done this way:** Expressing occupancy as a percentage enables direct comparison between an A319 (138 seats) and an A321neo (215 seats) on the same route.

---

**5. Cost per Available Seat-Kilometer (CASK / Unit Cost)**

* **Formula:**

$$\text{CASK (€/ASK)} = \frac{\text{Total Direct Operating Costs (€)}}{\text{ASK}}$$


* **What it measures:** The unit cost to fly one seat over a distance of one kilometer.
* **Why it matters:** Isolates the operational cost efficiency of an airframe, independent of how many tickets were sold or at what price.
* **Why done this way:** Larger aircraft generally have a lower CASK due to economies of scale (spreading fixed flight deck and navigation costs over more seats). CASK evaluates whether an aircraft is inherently too expensive to operate on a given route.

---

**6. Yield (Pricing Power)**

* **Formula:**

$$\text{Yield (€/RPK)} = \frac{\text{Total Passenger Revenue (€)}}{\text{RPK}}$$


* **What it measures:** The average revenue earned from carrying one paying passenger over one kilometer.
* **Why it matters:** Measures pricing power and market willingness to pay.
* **Why done this way:** Raw ticket prices vary widely by distance. Converting revenue to a per-kilometer figure isolates market pricing strength from route length.

---

**7. Break-Even Load Factor (BELF)**

* **Formula:**

$$\text{BELF (\%)} = \frac{\text{CASK}}{\text{Yield}}$$


* **What it measures:** The minimum percentage of seats an aircraft must fill just to cover its operating costs.
* **Why it matters:** Serves as the ultimate decision threshold. If $\text{Actual Load Factor} < \text{BELF}$, the flight operates at a structural financial loss.
* **Why done this way:** It is derived mathematically by setting Total Revenue = Total Cost:

$$\text{RPK} \times \text{Yield} = \text{ASK} \times \text{CASK} \implies \frac{\text{RPK}}{\text{ASK}} = \frac{\text{CASK}}{\text{Yield}}$$

This links cost structure (CASK) and pricing power (Yield) into a single benchmark.
