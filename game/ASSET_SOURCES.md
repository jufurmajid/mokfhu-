# Asset sources and licences

This build intentionally avoids visible cube/capsule placeholder art. Primitive shapes are used only for invisible physics collision.

## First-person AK-74M hands

- Asset: **FPS AK-74m animations**
- Author: **Cransh**
- Source mirror used by CI: `Ayush-Mohanty/FPS-Arms-3D`
- Folder: `Models/fps_ak-74m_animations`
- License: **CC BY 4.0**
- Animations used: `Rig|AK_Idle`, `Rig|AK_Walk`, `Rig|AK_Shot`, `Rig|AK_Reload_full`

Required credit:
> This work is based on "FPS AK-74m animations" by Cransh, licensed under CC BY 4.0.

The Android framing was calibrated directly on the target phone and locked to:
- X: 0.090
- Y: -0.200
- Z: -0.160
- Scale: 0.300
- FOV: 60.0

## Combat arena cover — CC0

All cover models below are downloaded from **3DAssets.dev** and are **CC0 1.0 Universal**:

- Sandbag Emplacement — asset ID `28257`
  - https://cdn.3dassets.dev/assets/28257/v1/model.glb
- Concrete Jersey Barrier — asset ID `28258`
  - https://cdn.3dassets.dev/assets/28258/v1/model.glb
- Precast Blast Wall 4 m — asset ID `28213`
  - https://cdn.3dassets.dev/assets/28213/v1/model.glb
- Frontier sandstone outcrop — asset ID `133`
  - https://cdn.3dassets.dev/assets/133/v1/model.glb

The visible ground is a custom procedural sand shader. No visible BoxMesh walls are used.

## Tactical enemies — CC0

The lightweight enemies use two static tactical operator poses from the **Tactical Shooter Hill Town** pack on 3DAssets.dev:

- Assault Trooper Standing Aim Pose — asset ID `27567`
- Assault Trooper Running Pose — asset ID `27569`

License: **CC0 1.0 Universal**.

The controller switches between authored running and aiming meshes. Physics uses an invisible capsule. The combat AI uses lightweight steering and hitscan fire instead of spawning physical bullet bodies, reducing Android CPU/physics cost.

## Audio

The repository contains the project owner's weapon recordings:

- `صوت سلاح الاعب .ogg`
- `صوت سلاح متوسط المسافة.ogg`
- `صوت سلاح بعيد المدئ.ogg`
- `bullet_whiz.wav`
- `reload_click.wav`

The runtime audio manager preallocates/reuses voices instead of creating a new audio node for every enemy shot. Player fire combines the close recording with a quiet distant tail; enemy fire chooses near/mid/far recordings based on distance.
