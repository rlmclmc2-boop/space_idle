# 熔炉产出

- Each furnace produces from its own non-furnace historical income peak (no self-feed); the input window, production and lifetime use game time, no offline catch-up. Resource receipts also retain a wall timestamp for the HUD; productionElapsed and production timestamps persist and pause with game time. Galaxy production reads the same game-time direct-income window. Chrono changes presentation speed while combat retains 1/60 game-second maximum steps. Scientist construction is visual only: no new resource or timer.
