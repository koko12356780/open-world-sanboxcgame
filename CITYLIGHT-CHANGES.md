# v0.8 Citylight

This separate project preserves the v0.7 driving/economy/garage/save features while replacing the city's surface and facade shading and adding original scenery. Use standard Godot 4.6.1 to import this folder's project.godot. Press F5 to run; the portable player download needs no editor.

- Locally authored 1024px asphalt albedo and normal textures, plus concrete and alpha-scissored foliage textures.
- Recessed window shading with frames, curtains/blinds, varied lit rooms, brick mortar and physical fire-escape ledges.
- Framed shopfronts, display shelves, original business signs, palms, parked vehicles with collisions, and five stepped downtown towers.
- A clouded sky shader with sunset haze, moon and stars; localized building reflections on cars near the starting area.
- Smoothed car mesh normals, metallic wheels, panel seams, gaskets and lamp detail.
- Matching static scenery batches grouped by block; individual collision bodies and animated lamp fixtures are preserved.
- Default Compatibility rendering; optional Forward+ adds SSAO, screen-space reflections and restrained bloom. No claim of ray tracing or GTA-level asset quality.

GTA city screenshots were viewed as visual references for street lighting, storefront layering and city silhouettes. All shipped models, textures, shaders and signage are original; no Rockstar assets were downloaded or copied into the project.

The optional effects can be previewed using Godot's `--rendering-method forward_plus` argument. Main renderer defaults to `gl_compatibility`. Screenshot capture scripts require a rendered window; do not run cockpit image tests headlessly. Tests use separate saves.

To export from an automated Windows shell, set APPDATA, TEMP and TMP to writable build folders before invoking `--export-pack "Windows Desktop" <destination.pck>`. The separate portable launcher build uses the unchanged official Windows release template and the exported PCK. It verifies their hashes before Play.
