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
