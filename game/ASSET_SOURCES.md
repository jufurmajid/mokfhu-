# Runtime asset sources

The Android build vendors ready-made 3D assets at build time so the visible combat presentation does not use primitive box/capsule placeholder art.

## First-person arms and rifle

- Asset: **FPS AK-74m animations**
- Author: **Cransh**
- Source mirror used by CI: `Ayush-Mohanty/FPS-Arms-3D`, folder `Models/fps_ak-74m_animations`
- Original source: Sketchfab model `fps-ak-74m-animations-94be8385c402474cacd39bc096c6ca14`
- License: **CC BY 4.0**
- Runtime animations used: `Rig|AK_Idle`, `Rig|AK_Walk`, `Rig|AK_Shot`, `Rig|AK_Reload_full`

Credit required by the model license:
> This work is based on "FPS AK-74m animations" by Cransh, licensed under CC BY 4.0.

## Environment

- Asset: Godot Engine **TPS Demo** level geometry and textures, tag `4.2-f0587b2`
- Authors/assets: Juan Linietsky and Fernando Miguel Calabró
- Asset license: **CC BY 3.0**
- Code license: MIT
- Runtime uses the authored level geometry/scenes instead of procedural visible boxes.

## Animated enemy

- Asset: `protagonist-vet-sniper.glb`
- Source: `mars-tw/storm-apocalypse`
- License in source repository: **MIT** (Copyright 2026 mars-tw)
- Used as an animated military enemy visual so enemies are no longer capsule/box characters.

## User-provided assets

The user-provided `ak_47.glb` was inspected and contains a skin plus real `Fire` and `Reload` animations. The user-provided `soldier.glb` was also inspected, but it contains no skeleton, skin, or animations. The connected repository writer cannot directly commit these Library binary uploads, so this build uses the licensed ready-made animated assets above while preserving the user's original combat audio files already stored in the repository.

No art, audio, or models are extracted from commercial games such as Combat Master or Modern Combat.
