# Crew presentation

`locked.svg` is an original repository-native 64×64 SVG lock badge displayed at 42 logical pixels on the next locked crew row. Cream/slate/navy shapes match the accepted shell. It has no baked labels or character identity and does not encode an unlock threshold.

The crew page reuses `assets/ui/shell/{crew,equipment,research,reactor,jewel,planet,galaxy}.svg` at 26–96 logical pixels. These badges describe the **current assignment**, never a permanent occupation or character identity. Idle uses the shell crew symbol. The actual configured name remains the primary identity. Existing unlocked level/XP templates retain their configuration authority.

A valid configured custom portrait always takes precedence in both the roster and detail. The known shipped generic `assets/ui/crew.svg`, an absent icon, or a missing icon resource uses the current assignment badge as fallback. A separate small assignment badge remains visible beside status for custom portraits. Selection is presentation-only and no additional crew equipment UI is introduced.

The coordinated enhancement rollout retains the `jewel` assignment identity. When its UI-owned `assets/ui/shell/enhancement.svg` is available, that current-job badge takes precedence over the legacy shell jewel symbol; this page does not rename assignment keys or own enhancement wording.
