# Runtime asset sources

This prototype intentionally avoids primitive placeholder art in the visible combat presentation.

- First-person arms / reload rig: Ayush-Mohanty/FPS-Arms-3D (MIT). The Android build workflow vendors the public Godot-ready asset at build time.
- Environment geometry: godotengine/tps-demo tag 4.2-f0587b2 (MIT / repository asset licensing). The Android build workflow vendors its level geometry at build time.
- Enemy visual target: the project is prepared to use the user's `soldier.glb`; the current connected-repository workflow cannot directly commit binary Library uploads, so the gameplay layer keeps a dedicated enemy visual root for that asset rather than rebuilding a box/capsule character.

No third-party game assets are extracted from commercial games.
