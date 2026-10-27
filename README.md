# [LR] Core — Levels Ranks for CS2 (mrc4tt fork)

Levels Ranks core for Counter-Strike 2: experience, ranks, top lists and an API for
`[LR]` modules. Fork of [Pisex/cs2-lvl_ranks](https://github.com/Pisex/cs2-lvl_ranks),
kept building against the latest CS2 SDK.

## Compatibility

| | |
|---|---|
| Metamod:Source | [mrc4tt/metamod-source](https://github.com/mrc4tt/metamod-source) **and** [alliedmodders/metamod-source](https://github.com/alliedmodders/metamod-source) 2.x. The plugin API is the same in both, so one package works on either. |
| Linux | One package for both **SteamRT3** (sniper) and **SteamRT4** servers. It is built in the SteamRT3 SDK, and the build fails if the binary needs a newer glibc than 2.31. |
| Windows | Built with MSVC. |

## Requirements

Install these first. Without them the core unloads itself on start.

- [Game Utils](https://github.com/Pisex/cs2-menus) (`utils`). Levels Ranks is loaded by it
  from `addons/plugins`, and gets its commands, events and menus from it. Without it the
  console shows `[LR] Missing Utils system plugin`.
- [SQLMM](https://github.com/Pisex/mysql_mm) (`sql_mm`) and a MySQL / MariaDB server.

## Installation

1. Download `levels_ranks-<version>-linux.tar.gz` or `-windows.zip` from
   [Releases](https://github.com/mrc4tt/cs2-lvl_ranks/releases).
2. Extract it into `game/csgo/`, so the `addons` folder merges with yours:
   ```
   addons/plugins/levels_ranks.so          (levels_ranks.dll on Windows)
   addons/configs/levels_ranks/settings.ini
   addons/translations/lr_core.phrases.txt
   addons/translations/lr_core_ranks.phrases.txt
   addons/data/lr_data.ini
   ```
3. Set the database connection and options in `addons/configs/levels_ranks/settings.ini`.
4. Restart the server or change map.

## Commands

The chat commands work with `!`, `/` or no prefix, e.g. `!lvl`, `/lvl`, `lvl`.

| Chat | Console | Description |
|---|---|---|
| `lvl` | `mm_lvl`, `sm_lvl` | Main menu |
| `rank` | `mm_rank`, `sm_rank` | Your rank and stats in chat |
| `top` | `mm_top`, `sm_top` | Top players by experience |
| `toptime` | `mm_toptime`, `sm_toptime` | Top players by playtime |
| `session` | `mm_session`, `sm_session` | Session stats |

## Troubleshooting

**`Failed to establish a MySQL connection: Plugin caching_sha2_password could not be loaded`**
MySQL 8 uses `caching_sha2_password` by default, and the MySQL client inside SQLMM cannot
load it. This comes from SQLMM, not Levels Ranks. Switch the database user to
`mysql_native_password`, or ask your host to:
```sql
ALTER USER 'user'@'%' IDENTIFIED WITH mysql_native_password BY 'password';
FLUSH PRIVILEGES;
```
MariaDB does not have this problem.

**`[LR] Missing Utils system plugin`**: Game Utils is not installed or not loaded, see
[Requirements](#requirements).

## Changes from upstream

- Builds against [mrc4tt/hl2sdk](https://github.com/mrc4tt/hl2sdk) (cs2) and Metamod:Source 2.x
  with KHook. SchemaEntity is the [mrc4tt/SchemaEntity](https://github.com/mrc4tt/SchemaEntity)
  fork, ported to that SDK, as a submodule in `schemaentity/`.
- Fixed: `/` prefix for chat commands ([upstream #22](https://github.com/Pisex/cs2-lvl_ranks/issues/22)).
- Fixed: `Duplicate column name 'online'` on every start. The column is only added when an
  old table is missing it ([upstream #14](https://github.com/Pisex/cs2-lvl_ranks/issues/14)).
- Documented: the MySQL 8 auth and missing Utils errors
  ([upstream #20](https://github.com/Pisex/cs2-lvl_ranks/issues/20)).
- No GitHub Actions. Releases are built and published locally with `support/local-release.sh`.

## Building

You need Docker. Clone with submodules (`git clone --recursive`). The script builds both platforms in containers and fetches the SDK,
Metamod:Source (with [mrc4tt/KHook](https://github.com/mrc4tt/KHook)), hl2sdk-manifests
and AMBuild into `~/.cache/lvl-ranks-local-release`.

```bash
support/local-release.sh                    # build Linux + Windows into build-release/
support/local-release.sh --targets linux    # Linux only
support/local-release.sh --dry-run          # build, show what would be released
support/local-release.sh --upload           # build and publish a GitHub release
```

- Linux uses `ghcr.io/source2ze/build-containers:steamrt3`.
- Windows uses the `msvc-wine` image from `cs2-build-system/msvc-wine-runner`.
- The version is `product.version` plus the commit count, e.g. `1.2.4f-r26`. Push before
  `--upload`, because the release tag points at the current commit.

## Credits

[Pisex](https://github.com/Pisex): Levels Ranks for CS2 and SchemaEntity. Based on
Levels Ranks for SourceMod by RoadSide Romeo and Wend4r. Licensed under GPL.
