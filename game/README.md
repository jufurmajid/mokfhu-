# Mokfhu: Field Combat

Mobile-first first-person field combat prototype built in Godot 4.3 using the Compatibility renderer. The repository was empty at kickoff, so this is the initial project scaffold rather than an edit to existing game code.

## Open and run

1. Open `project.godot` with Godot 4.3 or later.
2. Press **F6** to run the current field scene or **F5** to run the project.
3. On Android, use the left half of the screen to move, drag the right half to aim, tap/hold **إطلاق**, and tap **تلقيم** to reload.

Desktop testing uses WASD or arrow keys, mouse look, left mouse to fire, and R to reload. The window is configured for landscape orientation.

## Prototype features

- Small original desert outpost with cover, buildings, road, rocks, and low-detail shrubs.
- First-person camera and lightweight AK-style weapon silhouette.
- Five hostile soldiers with two uniform color variants, simple approach/strafe behavior, hits, and low-cost physics ragdolls.
- Mobile touch controls plus desktop test controls.
- Player, reserve ammunition, and remaining-enemy HUD.
- Spatial gunfire with smooth distance-layer blending and a capped number of active audio voices.
- Enemy projectiles that can deal damage or trigger a directional near-miss flyby.
- Android-focused landscape setup and Godot Compatibility renderer for mid-range devices.

## Audio

The three uploaded OGG clips are kept under their original Arabic filenames in `assets/audio/`. `combat_audio.gd` assigns the close clip to the player's shot and blends close, medium, and distant layers for enemy fire. The uploaded close and medium OGG files contain identical audio data, so the medium layer adds a stronger low-pass filter and lower level to keep distance audible. The compact `bullet_whiz.wav` and `reload_click.wav` are generated project effects because no dedicated uploaded flyby or reload clips were available.

## Asset sources

No external model or texture packs are required by this scaffold; the environment and soldiers are assembled from lightweight Godot primitives. The supplied sound files came from the project owner. This keeps the first playable version self-contained and avoids untracked third-party assets.

## Export policy

Do not export during ordinary development. The requested deliverable is Android APK only, and an APK should be created only after Jaafar explicitly says **«صدر»**. No export preset, signing key, or APK is included in this source scaffold.
