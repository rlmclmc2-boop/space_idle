# One building, one platform — direction review

Source branch: `art/cosmic-city-individual-direction`, commit `ededd13303cc6f4125d5ca2fc5e9540cdf65ef78`. Based on accepted three-building sample `8f19a7487ff8516499fbdd735d8241edff80f767` and main `10360c57f1057c51ba7106f84581fdd5b1383c62`, not the rejected shared-district runtime. Not merged.

`individual-city-full-ui.png` is the actual 1372×883 game root framebuffer. `individual-city-viewport.png` is its native galaxy viewport, without UI. Isolated synthetic fixture, all 30 existing buildings with mixed levels; no reference art, user save or image composition.

The direction is 30 individual 16×16 platforms with distinct silhouettes, original building models, mounting collars and socket interfaces. Each has a stable slot ID. Six types are interleaved rather than grouped as same-type precincts. A separate headquarters connects through 32 short service bridges; uneven branch lengths and gaps provide an irregular perimeter. Shared functional decks: zero. The approved three-building sample's hull/port/bridge geometry is retained and statically baked.

This is a static art-direction preview only, implemented under dev/. Production runtime, economy, save schema, configuration workbooks and existing GLBs are unchanged. The preview hides the production map and displays proposed geometry inside its existing viewport. Interaction/picking, construction states and moving transport for this layout are not integrated or claimed tested. No broad test/video run was requested or performed. Startup succeeded; diagnostic output confirms 30 platforms/buildings, 32 connections and all 30 reachable. Native screenshot was visually inspected.

Next gate: parent visual review of individual building identity and connected-city composition before production adaptation. Keep the rejected shared-district proposal unmerged.
