# GBJAM 14 ~ How we can work without killing each other

Read this before you touch anything. It's short and simple :)

## Setup

**Godot 4.7.2, exactly.** Different versions rewrite `.tscn` files on save and you'll hand everyone a merge conflict for free.
Clone, open `project.godot` in Godot, hit play. Main scene is `scenes/main.tscn`.

## Folder structure

That's a structure I've used in some Godot projects. It's easy to maintain and easy to follow rules.

```
assets/
  audio/
    music/
    sfx/
  fonts/
  palettes/       .gpl files
  sprites/
  ...
globals/          autoloads
entities/         scripts, scenes, etc. relative to specific prefabs (like player, enemy, etc.)
scenes/
  levels/
  ui/
  ...
scripts/
  core/           generic, reusable
  scenes/
  ...
shaders/
...
```

Keep it tidy, if you're about to drop a file in the root, it belongs in one of these.

**Naming:** `snake_case` for everything, files and folders.

## Scenes

`main.tscn` holds a `SubViewport` where the whole game lives. It exists once, in that file only.

**Don't copy it into your scenes.** What you build are plain scenes with just your content. The scene manager loads them inside the viewport.

Prefer small scenes composed together over one big scene. A level is a scene that instances a player scene, an enemy scene, and so on. It's more files, but it's the only way two people can work on the same level without fighting.

A scene's specific script will have the same name. For example `player.tscn` will have `player.gd`. General-purpose scenes will have their scripts under `/scripts/scenes` folder. Entities scripts live next to their scene under `entities/`.

## Coding

Remember to write comments on hard stuff! Two lines of explanation are 10x better than 2 hours waiting for a direct explanation from the code's writer ;)

## Git

**One branch per feature/content/bugfix/etc. No direct pushes to main, ever.** Open a PR, get a look from someone, then merge.

Branch naming: describe shortly what you're doing, like `adjusting_inputs`. Plus, keep branches short-lived. Once you're done with a job, open a new one for the next one.

## Releases

**A release is a `v*` tag on `main`. That's the only thing that ships the game, and the only thing that starts
CI at all.**

```bash
git checkout main && git pull
git tag v0.1.0
git push origin v0.1.0
```

Then leave it alone. CI exports Windows, Linux, macOS and Web, pushes all four to itch.io on the `windows`,
`linux`, `osx` and `html5` channels, and creates a GitHub Release with the four zips attached. Nothing is done
by hand. The version drops the `v`, so `v0.1.0` ships as `0.1.0`. The zips also end up as downloadable
artifacts on the run page, which is the easiest way to grab a Windows build if you're on macOS.

Pushing a branch triggers nothing, and there's no manual button in the Actions tab either. No tag, no build.

**The tag has to be on `main`.** CI checks that the tagged commit is reachable from `main` and stops the run in
the first few seconds if it isn't — nothing gets built, nothing gets published. If that happens, merge the
commit into `main` and move the tag; don't try to release off a branch.

**Changing where it publishes** means editing the `env:` block at the top of `.github/workflows/release.yml`:
`ITCH_TARGET` is the itch page (`user/game`, currently `m4niek/gbjam14`), `PROJECT_NAME` is the name of the
built files, so it has to keep matching what the export presets produce. The upload also needs a
`BUTLER_API_KEY` repository secret (Settings → Secrets and variables → Actions) belonging to an account with
push rights on that page — it's a secret, so it never goes in the YAML, and if you rename it there you have to
rename it in the workflow too.

### Very important!

**`main.tscn` is the danger zone.** Godot scene files don't merge: two people editing the same `.tscn` means one of you loses work, and git will happily hide that from you. The workflow around it:

1. On your branch, work on a **copy** of `main.tscn`. Do whatever you need in there.
2. When you're ready, ask in #code whether anyone has pending changes to main scene.
3. Once you get the go-ahead, port your changes onto the real `main.tscn` (only the ones that actually need to land) and then delete the copy.
4. Open the PR.

Once the PR is merged, everyone else rebases onto `main` **before** touching the main scene themselves. That way there's only ever one version of that file in flight.

Same rule for any shared scene, not just `main.tscn`.

**Pull before you open Godot**, not after. Godot caches the scene tree in memory!
So pulling changes underneath a running editor causes weird states and accidental reverts.
