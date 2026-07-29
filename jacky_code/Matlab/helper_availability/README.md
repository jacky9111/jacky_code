# Helper Availability under OneWeb-Like Density Variants

Independent, pure-MATLAB simulation module (no STK) that compares the
availability of recovery-capable helper satellites under three **OneWeb-like
polar** Walker geometries. All rows share the same shell:

- **1200 km**, **87.9°**, Walker **star** (RAAN over 180°)

Only plane count **P** and satellites-per-plane **S** change:

Partial runs: set `helperConstellationsToRun` / `helperPlotConstellationsToRun`
in `jacky.m` to `"Low-density"` (or any row name) via `select_helper_constellations`.

| Row | Planes × Sats/plane | Total | Density reference |
|-----|---------------------|-------|-------------------|
| `OneWeb-like reference` | 12 × 49 | 588 | Thesis main simulation |
| `High-density` | 36 × 74 | 2664 | ~Starlink-scale total |
| `Low-density` | 8 × 36 | 288 | ~Lightspeed-scale total |

High-density increases **both** orbital planes (12→36) and in-plane spacing
(49→74 sats/plane). Low-density reduces **both** planes (12→8) and in-plane
spacing (49→36 sats/plane).

> **Illustrative density variants only.** Beam, power and EPFD model are the
> thesis model; results do not reproduce any commercial constellation.

The experiment keeps an **identical** 16-beam satellite-fixed layout, beam
power, antenna pattern, EPFD model, EPFD limit, GS/GSO geometry and
helper-identification criteria for every case.

**Footprint size:** half-angles are calibrated on the reference geometry so
same-orbit ±1 neighbours meet at the middle sub-point; EW scales with NS
(34:33.5 aspect). That size is shared by all rows.

**Helper rule:** a visible non-critical satellite counts as a helper only if the
**sum** of its active-beam overlap areas with that critical's closed beams is
at least `helperMinOverlapBeamFrac` × one nominal beam area (default 1.0).
Tiny edge contacts are ignored. Scene plots draw the actual ray/Earth
16-beam footprint polygons.

## How to run

```matlab
addpath(genpath(fullfile(pwd, 'jacky_code', 'Matlab')));   % or run jacky.m section
[summaryTable, caseResults] = main_helper_availability();
```

`jacky.m` sets `helperMinOverlapBeamFrac` and passes `cfgHelper` to both the
summary table and worst-EPFD scene plots.

## File structure

```
main_helper_availability.m           entry point (loops every geometry)
config_helper_availability.m         ALL parameters (common + constellations)
calibrate_beam_for_half_orbit_overlap.m  reference half-overlap beam sizing
run_constellation_case.m             full pipeline for one geometry
main_worst_slot_schematic.m            worst-EPFD scene: SSP + 16 beams
identify_recovery_helpers.m          helper detection (overlap area sum)
...
```

Summary columns:

| Geometry | Avg. critical satellites per critical slot | Avg. recovery-capable helpers per critical satellite | Helper-availability ratio | Closed-beam helper-coverage ratio |

## Units

- distance: km (positions) / m (EPFD path terms)
- angle: deg (public API), rad (internal trigonometry only)
- power: W
- EPFD: linear W/m^2/reference-bandwidth internally; dB only for I/O
