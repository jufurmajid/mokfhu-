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

## Compact desert arena

The heavy industrial TPS level was removed for the mobile build. The new arena is approximately 42 x 42 metres and uses small ready-made CC0 GLB assets from **3DAssets.dev**:

- `Desert Ground Module` — asset ID `38107`, CC0 1.0
- `Desert Ground Module Dark` — asset ID `38108`, CC0 1.0
- `Sand Drift` — asset ID `38109`, CC0 1.0
- `Frontier sandstone outcrop` — asset ID `133`, CC0 1.0

The two 6 m ground modules are instanced with different rotations to form the floor. Rock outcrops and sand drifts are instanced as cover and dressing. Only invisible gameplay collision boxes are generated in code; no visible primitive boxes are used for the environment.

## Realistic tactical enemy

The previous stylized low-poly enemy was replaced with two realistic tactical operator poses from the **Tactical Shooter Hill Town** pack on 3DAssets.dev:

- `Assault Trooper Standing Aim Pose` — asset ID `27567`, CC0 1.0
- `Assault Trooper Running Pose` — asset ID `27569`, CC0 1.0

The enemy controller switches between the running and aiming authored meshes depending on movement/fire state. The models include the tactical uniform, helmet, plate carrier and rifle as authored geometry. Invisible capsule collision is used only for gameplay physics.

## User-provided assets

The user-provided `ak_47.glb` was inspected and contains a skin plus real `Fire` and `Reload` animations. The user-provided `soldier.glb` was also inspected, but it contains no skeleton, skin, or animations. The connected repository writer cannot directly commit these Library binary uploads, so the build uses the licensed ready-made assets above while preserving the user's original combat audio files already stored in the repository.

No art, audio, or models are extracted from commercial games such as Combat Master or Modern Combat.
