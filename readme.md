# Tutorial

Will conduct the tutorial for the current character from immediately after character creation through completing all steps (required and optional) in both **Basic Training** and **The Revolt of Gloomingdeep**.

## Deployment

1. Download the archive to `<MQ directory>\lua`.
2. Extract contents there (some files are placed in the `\lib` directory).

## Usage

```text
/lua run Tutorial [option]
```

Where `option` can be:

- `nopause`

## Credits

Heavily based on the work done initially by **Chatwiththisname** and later by **Cannonballdex** (and anyone else I missed who contributed to the original project).
Rouneq for the original LUA refactor.

## Notes

Designed to be restartable if it gets stuck in some way and is stopped (the original was too; this version verifies it still does). Intended to run attended in the foreground.


## Enhancements

- Adds three "pause" points throughout the tutorial to give the user an opportunity to upgrade like-for-like spells/tomes (e.g., replace a nuke in gem slot 1 with a better nuke).
  - If a non-like spell is used in place (e.g., replace a nuke with a DoT), it will still cast, but it will not recognize differences in how to cast/re-cast the spell.
  - Use `/resume` or click the **Resume** button in the UI.
  - If pausing is not desired, uncheck the **Break For Spells/Skills** option.
- Will stop and get pets for the three major pet classes (Necros may need to farm more bone chips).
- Will use speed spells/songs if bought, memorized, and loaded (Bard, Druid, Shaman).
- Will use healing song (Bard) if bought, memorized, and loaded.
- Basic navigation to move to a "safe" spot when personal regen situations are called for (not perfect and does not currently work for group).
- Will work for free-to-play accounts (including hiring a mercenary), but progress is much slower.
- Tested with many different class types (YMMV). More work could be done to enhance class interactions within the tutorial. Patches are appreciated.

## Caveats

After hiring a mercenary, it is necessary to set its role. The normal EQ command (`/grouproles`) does not support mercs. Use the Group window to set this role appropriately (Main Tank is recommended in some cases).
