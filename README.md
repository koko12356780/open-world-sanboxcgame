# Open Streets

A Windows driving and walking sandbox built with Godot 4.6.1.

## Players
Open the companion launcher and press **Update Game**. It checks this repository's latest release, downloads a new version and installs it without a file picker. Saved cars, coins and upgrades stay in your local save folder.

Get the launcher from https://github.com/koko12356780/luncvher-repop/releases/latest . Game source ZIPs are for editing, not playing.

## Game
Drivable cars, cockpit and chase cameras, workshop upgrades, currency, premium flight, rear thrusters, Ice City through the blue tower portal, visible shopfronts and walking mode. Stop and press E to leave/enter your car; WASD walk, Shift run, Space jump, R recover. Shopfronts are scenery, not enterable stores.

## Development and automatic publishing
Import project.godot into standard Godot 4.6.1 (no .NET) and press F5.

To publish an update, increase config/version in project.godot and push changes to main. GitHub Actions imports the project, runs the headless game tests, exports the Windows PCK and creates a release containing latest.json and OpenStreets-update.zip. No manual game ZIP upload is needed. Already-published versions are never overwritten.

The workflow uses GitHub's built-in temporary token and pinned official Godot downloads. No developer password or saved game is committed. Original source/art/audio uses MIT; engine notices are in licenses/.
