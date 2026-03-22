# Lava System Visual Audit — Bomb Survival

## 1. Current Issues with Lava Visibility

### The Critical Bug: Lava Is Physically Unreachable

The lava system has a fundamental design contradiction that makes it functionally invisible during normal gameplay.

**The geometry:** LOW tier has 3 tile layers stacked above lava. Each tile is 8 studs tall. Lava sits at Y = -24.5, while the LOW surface is at Y = 0. That's 24.5 studs of solid tile between the player and the lava.

**The destruction rule:** `MapManager.DestroyAt` iterates `layer = 1` to `maxLayers - 1`. For LOW tier (3 layers), this means only layers 1 and 2 can ever be destroyed. Layer 3 — the bottom tile sitting directly on top of the lava — is permanently protected. Even if every bomb in the game targets one spot, the bottom tile survives. The lava terrain is never visually revealed.

**The depth cap:** Bombs pass `depthLayers = 2`, which means a single explosion removes at most 2 layers. With 3 layers in LOW tier, this leaves Layer 3 intact even without the `maxLayers - 1` protection.

**Result:** Players can never see the CrackedLava terrain. The lava system is a hidden damage source with no visual payoff from the destruction mechanic.

### VFX Can't Bridge the Gap

The current PointLights and ember particles are placed at Y = -20 (inside Layer 3). The PointLights have range 12, reaching up to Y = -8 — still 8 studs below the LOW surface. Players standing on intact LOW tiles see nothing. Even after Layer 1 is destroyed (exposing Layer 2 at Y = -12), the light barely touches the underside of the exposed tile, creating a faint orange tint that's easy to miss.

The embers travel 4-9 studs/sec for 1.5-3 seconds, giving a max vertical reach of ~27 studs. Since they start at Y = -20, they could theoretically reach Y = 7 — just above the LOW surface. But with SpreadAngle of 12 degrees and Rate of only 2 per second, the visual density is too sparse to be noticed during fast gameplay, especially from MID (Y = 8) or HIGH (Y = 18) elevations looking down.

### Lava Appears as Rigid Squares

Each lava block is an axis-aligned `FillBlock` of `T-1 = 7` studs, placed per grid cell. When lava IS visible (e.g., if the bottom-layer protection were removed), it appears as discrete 7x7 square patches with sharp edges — one per tile. Adjacent lava cells create a grid pattern rather than organic pools. This looks mechanical and breaks the cartoony, natural aesthetic.

---

## 2. Recommended Visual Improvements

### Priority 1: Fix the Bottom-Layer Protection (Zero VFX Cost)

The single highest-impact change: allow the bottom tile layer to be destroyed. Change the destruction loop from `layer = 1, maxLayers - 1` to `layer = 1, maxLayers`. This is not a VFX change — it's a gameplay logic fix that unlocks the entire lava reveal mechanic.

Without this fix, no amount of VFX work will make lava visually readable, because the geometry permanently blocks line-of-sight to the lava terrain.

**Suggested approach:** Keep the bottom layer *harder* to destroy (lower probability, e.g., 50% of normal destroyChance) rather than immune. This creates a satisfying progression: early rounds chip surface layers, later rounds start punching through to bedrock and revealing lava.

### Priority 2: Boost Ember Particles (Low Cost, High Impact)

Once lava can be revealed, embers become the primary "danger nearby" signal. Current settings are too subtle.

| Parameter | Current | Recommended | Why |
|-----------|---------|-------------|-----|
| Rate | 2/sec | 5-8/sec | More visible particle density |
| Speed | 4-9 | 6-14 | Reach surface faster, travel higher |
| Lifetime | 1.5-3.0s | 2.0-4.0s | Travel further before fading |
| Size start | 0.3 | 0.5 | More visible at distance |
| SpreadAngle | 12 | 20-25 | Wider spread = less grid-like appearance |
| Acceleration Y | 1 | 2-3 | Embers rise more aggressively |

Additionally, add a second particle layer: **heat haze**. A subtle, almost-transparent whitish particle with large size (2-3 studs), very slow rise, high transparency (0.85-0.95), that creates a shimmer effect above exposed lava. This reads as "hot air" without cluttering the screen.

### Priority 3: PointLight Tuning (Zero Cost)

Current lights are buried inside the bottom tile. Reposition them and increase range:

- **Position:** Move to `bottomTileBottom` (Y = -24) instead of `bottomTileBottom + T*0.5` (Y = -20). Light should emanate from the lava surface, not from inside a tile.
- **Range:** Increase from 12 to 20-24. This lets light reach the LOW surface at Y = 0 and creates visible orange underglow through cracks.
- **Brightness:** Increase from 1.2 to 2.0-2.5 after tiles are destroyed. Consider a dynamic system: brightness starts at 0.8 (subtle underglow through solid tiles), then ramps to 2.5 when tiles above are destroyed.

### Priority 4: Surface Warning Decals (Medium Cost, High Readability)

Place subtle orange/brown crack decals on the top surface of Layer 1 tiles that sit above lava. This gives players a visual hint before any destruction occurs. Use SurfaceDecal on the top face with:

- A cracked-earth texture (Roblox asset or custom)
- Low transparency (0.6-0.7) so it blends with the grass
- Slight orange tint to suggest heat beneath

This approach communicates "lava below" without showing the lava itself, preserving the reveal mechanic while giving players information to make strategic decisions.

---

## 3. Natural Integration Strategies for Organic Lava Pools

### Problem: Grid-Aligned Lava Squares

Currently, each lava cell is a standalone `FillBlock`. Even with the `T-1` inset, adjacent lava cells have a 1-stud gap between them. From above, revealed lava looks like a checkerboard of orange squares.

### Strategy A: Merged Fill Regions (Recommended)

Instead of filling lava per-cell, scan for contiguous groups of lava cells and fill them as larger merged rectangles. For a 3x2 cluster of lava cells, use one `FillBlock` spanning the entire group rather than 6 individual blocks. This eliminates internal seams and creates larger, more organic-looking pools.

Implementation approach: After rolling `isLavaAt`, run a flood-fill to find connected components. For each component, compute the bounding box and fill it as a single terrain block with a small inset (0.5 studs) on the outer edges only.

### Strategy B: Oversize + Overlap

Make each lava FillBlock slightly larger than the tile (`T + 0.5` instead of `T - 1`). Adjacent lava cells will overlap, creating a seamless pool. Non-adjacent cells remain isolated but with softened edges from the terrain renderer. CrackedLava material naturally creates organic-looking texture, so the slight overlap hides the grid origin.

### Strategy C: Randomized Offset + Size Variation

For each lava cell, randomize the FillBlock position by +/- 1 stud and size by +/- 1.5 studs. This breaks the grid alignment. Combined with terrain's natural material rendering, pools look like irregular puddles rather than squares.

**Recommended combination:** Use Strategy B (oversize) for the base, then apply Strategy C (random offset) on top. This creates pools that merge naturally when adjacent and look irregular when isolated.

---

## 4. Player Experience Considerations

### Readability at Different Elevations

Players on HIGH tier (Y = 18) look down at LOW tier lava from 42+ studs away. At this distance, even bright particles are hard to see. The primary readability signal for HIGH players should be **color contrast and lighting**, not particles. Recommendations:

- Orange underglow on surrounding tiles (via PointLights) creates a warm color zone visible from any elevation
- Exposed lava terrain (CrackedLava material) is bright orange — naturally high-contrast against dark stone/slate tiles
- Heat haze particles with larger size (3-4 studs) are visible at distance even when individual embers aren't

### Tension and Discovery

The best lava experience follows a reveal arc: players start the round seeing only hints (subtle glow through tiles, crack decals on surfaces), then as bombs destroy layers, the danger becomes increasingly visible and urgent. This creates escalating tension that aligns with the round difficulty curve.

Key moments in the arc:

1. **Round start:** Faint orange underglow visible on LOW tier surfaces. Observant players notice crack decals and avoid those areas. Embers occasionally peek through.
2. **Mid-game (layers 1-2 destroyed):** Lava glow intensifies through exposed gaps. Embers rise freely through destroyed areas. Players on remaining tiles see bright orange below.
3. **Late-game (all layers destroyed in some cells):** Full lava pools visible. Bright terrain, dense embers, strong glow. Clear no-go zones. Players must navigate around open pits to survive.

### Audio Cue Integration

Visual clarity should be reinforced with audio. When a player is within 20 studs horizontally of exposed lava (tiles above destroyed), play a looping ambient lava bubble/hiss sound at low volume. This gives an additional sensory channel for danger awareness, especially valuable when the camera angle doesn't show the lava directly.

---

## 5. Potential Trade-offs

### Performance

- **Merged FillBlocks vs per-cell:** Fewer terrain operations = better build performance. Merged regions are strictly better for performance.
- **Increased particle rate (5-8/sec):** With ~50 lava cells, that's 250-400 particles active at peak. Roblox handles this comfortably on mid-tier devices. Not a concern.
- **Dynamic light brightness:** Requires checking tile destruction state, adding a per-cell check on bomb impact. Marginal cost, worthwhile payoff.
- **Surface decals:** One Decal instance per lava-topped cell (~50 decals). Negligible performance impact.
- **Heat haze particles:** Additional emitter per lava cell. With low rate (1-2/sec) and high transparency, performance impact is minimal.

### Style Consistency

The crack decals and heat haze must match the existing cartoony aesthetic. Avoid realistic lava textures — lean into bright orange, chunky particles, and exaggerated glow. The CrackedLava terrain material already has a stylized look that fits.

### Gameplay Readability vs. Surprise

Making lava too obvious removes tension. The crack decals should be subtle enough that inattentive players might miss them, but clear enough that observant players feel rewarded for noticing. The 0.6-0.7 transparency range hits this balance: visible if you're looking, easy to overlook if you're focused on dodging bombs.

### Bottom-Layer Destruction Implications

Allowing the bottom layer to break means players can fall through to lava. This changes the death flow:
- Currently: players can only take lava damage by falling off map edges to Y < -45 (where the kill plane is)
- Proposed: players fall through destroyed bottom tiles onto lava at Y = -24.5, taking lava DPS damage
- The existing lava damage system (`IsOverLava` + `hrp.Position.Y < lavaData.y + 3`) already handles this correctly for Y = -24.5
- This adds strategic depth: low-tier areas become progressively more dangerous as the round continues

---

## Summary: Priority Action Items

1. **Fix bottom-layer immunity** — Change destruction loop to allow Layer 3 (bottom) to break, with reduced probability. This is the prerequisite for everything else.
2. **Reposition and strengthen PointLights** — Move to lava surface, increase range to 20-24, increase brightness.
3. **Boost ember particles** — Higher rate, speed, lifetime, and spread for visibility from all elevations.
4. **Add heat haze particles** — Subtle shimmer layer above lava for atmospheric depth.
5. **Merge adjacent lava FillBlocks** — Eliminate grid seams, create organic pool shapes.
6. **Add surface crack decals** — Pre-destruction visual hints on tiles above lava.
7. **Dynamic light intensification** — Brightness increases as tiles above are destroyed.
