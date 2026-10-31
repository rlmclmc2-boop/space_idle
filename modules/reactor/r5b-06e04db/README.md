# Reactor B01 R5b evidence — 2026-10-31

Production source: `implement/reactor-centered-godot@06e04dbbec01035a8886b84008e855e258641a22` (Godot 4.7.2, Linux Xorg, Mesa llvmpipe/OpenGL Compatibility, 1440×900, 1× normal game speed). This is the implementer's same-version evidence, not an independent visual or target-hardware acceptance.

The 1/2/3/4-route `reactor-r5b-controlled-{n}-{zero,active}.png` files are complete game frames. The 1/2-route `manual` frames and `reactor-r5b-controlled.log` record actual mouse slider events and accepted Reactor Owner ratios. The 1/2/3 states use isolated parameter copies; the 4-route state uses controlled availability grants. These frames prove neither natural unlocks nor pricing policy. `reactor-r5b-budget.log` and its three screenshots record a controlled 1000-uranium credit, a real MAX purchase of 11 levels for 752, 248 remaining, a next ×1 price of 272 shown red before the click, and the Owner's `InsufficientResources` refusal after clicking. The budget is controlled, not natural income.

`reactor-r5b-10s-1440x900-25fps.mp4` is a 10.000-second, 250-frame normal 1× four-route game capture. SHA-256: `0104c1da83c899eaa96eb0447ed6115f61c646d541245a2c3624e76eb8df902f`. The source retains distinct pipe shells/lumens, devices, and a core sphere bracketed by paired Blender rear/front gimbal frames with side clamps. No text or business values are embedded in the component art.

Performance, no recording, same process per A/B sequence, normal game speed, four routes at 25% each; autonomous battlefield state still varies between windows. FPS / mean / p50 / p95 frame ms:

| Condition | A1 | B1 | A2 | B2 |
|---|---|---|---|---|
| Product static cache off/on | 33.76 / 29.62 / 28.45 / 35.51 | 34.40 / 29.07 / 28.64 / 34.54 | 31.49 / 31.76 / 30.30 / 36.83 | 33.26 / 30.07 / 28.94 / 35.28 |
| Full stage visible/hidden | 32.85 / 30.44 / 29.01 / 36.06 | 44.32 / 22.56 / 22.22 / 25.31 | 33.41 / 29.93 / 28.99 / 35.00 | 44.77 / 22.34 / 21.98 / 25.82 |
| Core field visible/hidden | 34.08 / 29.34 / 28.00 / 35.25 | 34.51 / 28.98 / 28.24 / 35.30 | 33.38 / 29.95 / 29.16 / 34.92 | 34.36 / 29.10 / 28.08 / 35.27 |

The static cache saves the full-page drawing in identical phase (`reactor-r5b-cache-baseline.png` versus `cached.png`, RGB absolute error count 0); its FPS benefit is small and variable. Hiding the whole stage identifies the material stage cost in this software renderer, while hiding only the core field changes FPS by about 0.4–1.0, so the field shader is not the sole bottleneck. The hidden-stage and hidden-core windows are diagnostics only; the product keeps every effect active. Prior user-reported packed-architecture measurements were 31.29→32.33 and 31.61→32.23 FPS, and are not subtracted from this revised architecture. No target-machine renderer/resolution profile or stable 10-FPS recovery claim is available.

Drivers and raw logs accompany the images/video. R5b was visually inspected as complete 1/2/3/4-route pages and sampled video frames; external visual approval is still open.
