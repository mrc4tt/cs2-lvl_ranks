# [LR] Core — Levels Ranks for CS2 (mrc4tt fork)

Levels Ranks core for Counter-Strike 2: experience, ranks, top lists and an API for
`[LR]` modules. Fork of [Pisex/cs2-lvl_ranks](https://github.com/Pisex/cs2-lvl_ranks),
kept building against the latest CS2 SDK.

## Compatibility

| | |
|---|---|
| Metamod:Source | [mrc4tt/metamod-source](https://github.com/mrc4tt/metamod-source) **and** [alliedmodders/metamod-source](https://github.com/alliedmodders/metamod-source) 2.x. The plugin API is the same in both, so one package works on either. |
| Linux | `steamrt3` and `steamrt4` packages. **Not sure? Take `steamrt3`.** It is held to glibc 2.31, so it loads on both SteamRT3 (sniper) and SteamRT4 servers. |
| Windows | Built with MSVC. |

## Requirements

Install these first. Without them the core unloads itself on start.

- [Game Utils](https://github.com/Pisex/cs2-menus) (`utils`). Levels Ranks is loaded by it
  from `addons/plugins`, and gets its commands, events and menus from it. Without it the
  console shows `[LR] Missing Utils system plugin`.
- [SQLMM](https://github.com/Pisex/mysql_mm) (`sql_mm`) and a MySQL / MariaDB server.

## Installation

1. Download `cs2-lvl_ranks-<version>-steamrt3.tar.gz` (Linux) or `-windows.zip` from
   [Releases](https://github.com/mrc4tt/cs2-lvl_ranks/releases). The release notes have a
   table of which file loads where.
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
- No GitHub Actions. Releases are built and published on our own build server with
  [cs2-build-system](https://github.com/mrc4tt/cs2-build-system)'s `build-all.sh`.

## Building

Clone with submodules (`git clone --recursive`). You need
[mrc4tt/hl2sdk](https://github.com/mrc4tt/hl2sdk) (`cs2` branch),
[mrc4tt/metamod-source](https://github.com/mrc4tt/metamod-source) (with submodules),
[hl2sdk-manifests](https://github.com/alliedmodders/hl2sdk-manifests) next to this folder, and
[AMBuild](https://github.com/alliedmodders/ambuild):

```bash
mkdir build && cd build
python3 ../configure.py -s cs2 --targets=x86_64 --enable-optimize \
  --hl2sdk-root=/path/to/sdks --mms_path=/path/to/metamod-source
ambuild
```

`--hl2sdk-root` is the folder that holds `hl2sdk-cs2`. The plugin ends up in `build/package/`.

Releases are built in Docker by [cs2-build-system](https://github.com/mrc4tt/cs2-build-system):
Windows with MSVC under Wine, Linux in the SteamRT3 and SteamRT4 build containers.

```bash
./build-all.sh --only cs2-lvl_ranks                       # build into output/release/
./build-all.sh --release --dry-run --only cs2-lvl_ranks   # show the version plan, build, change nothing
./build-all.sh --release --only cs2-lvl_ranks             # bump, tag, push, publish
```

The version is the string `LR::GetVersion()` returns in `levels_ranks.cpp`, and tags have
no `v` prefix (`1.2.5`). A release with changes since the last tag bumps that string, commits
`Release <version>` and tags it.

## Credits

[Pisex](https://github.com/Pisex): Levels Ranks for CS2 and SchemaEntity. Based on
Levels Ranks for SourceMod by RoadSide Romeo and Wend4r. Licensed under GPL.
