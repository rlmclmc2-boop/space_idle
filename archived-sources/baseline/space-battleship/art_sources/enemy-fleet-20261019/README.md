# Approved eight enemy hull sources

`base-eight-transparent.png`: parent-approved atlas from f9af84734145a6df6bcc1998fff15730936aa78a. Source order: scout/sentry/interceptor/swarm/anchor/reactive/shielded/command. Anchor crosses a nominal tile boundary; use prepare_assets.py regions.

`reactive-refined-approved.png`: user-approved parent imagegen refinement delivered by e9e8da87b96ba8a191b0ba275a344f4733279ba4; prompt intent: three major white-grey armor masses around a small burgundy/orange core, open structural gaps, blunt front, no central long nose, transparent background and no installed weapons. This is the runtime reactive source; the other seven retain atlas pixels. Import only cleans alpha residue, scales uniformly to 720px body width and centres on 887×1774. No procedural hull drawing. Runtime consumer uses the approved 90.4×79.333 logical display box independently of formation or actor rank.
