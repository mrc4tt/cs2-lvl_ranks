# Levels Ranks for CS2

Ranks, experience points and top lists for your Counter-Strike 2 server, plus an API for
`[LR]` modules. This is a maintained fork of
[Pisex/cs2-lvl_ranks](https://github.com/Pisex/cs2-lvl_ranks) that keeps working with the
latest CS2 updates.

## Which download do I need?

Get the latest version from [Releases](https://github.com/mrc4tt/cs2-lvl_ranks/releases).

| Your server | File |
|---|---|
| Linux (most servers) | `cs2-lvl_ranks-<version>-steamrt3.tar.gz` |
| Linux, running Steam Runtime 4 | `cs2-lvl_ranks-<version>-steamrt4.tar.gz` (the steamrt3 file works too) |
| Windows | `cs2-lvl_ranks-<version>-windows.zip` |

Not sure? Take **steamrt3**. It works on every Linux CS2 server.

It runs on Metamod:Source 2.x, both the official
[alliedmodders](https://github.com/alliedmodders/metamod-source) version and
[mrc4tt/metamod-source](https://github.com/mrc4tt/metamod-source).

## Before you install

You need these two plugins and a database. Without them Levels Ranks will not start.

- [Game Utils](https://github.com/Pisex/cs2-menus) (gives Levels Ranks its menus, commands
  and events)
- [SQLMM](https://github.com/Pisex/mysql_mm) (the database connection)
- A MySQL or MariaDB database

## Install

1. Download the right file (see above).
2. Extract it into your server's `game/csgo/` folder. It adds these files to your `addons`
   folder:
   ```
   addons/plugins/levels_ranks.so          (levels_ranks.dll on Windows)
   addons/configs/levels_ranks/settings.ini
   addons/translations/lr_core.phrases.txt
   addons/translations/lr_core_ranks.phrases.txt
   addons/data/lr_data.ini
   ```
3. Open `addons/configs/levels_ranks/settings.ini` and fill in your database details.
4. Restart the server or change the map.

## Commands

Type them in chat with `!`, `/` or nothing in front, for example `!lvl`, `/lvl` or `lvl`.

| Chat | Console | What it does |
|---|---|---|
| `lvl` | `mm_lvl`, `sm_lvl` | Opens the main menu |
| `rank` | `mm_rank`, `sm_rank` | Shows your rank and stats in chat |
| `top` | `mm_top`, `sm_top` | Top players by experience |
| `toptime` | `mm_toptime`, `sm_toptime` | Top players by time played |
| `session` | `mm_session`, `sm_session` | Your stats for this session |

## Common problems

**`Failed to establish a MySQL connection: Plugin caching_sha2_password could not be loaded`**

Your database is MySQL 8, which uses a login method SQLMM does not support. Change the
database user to the older method (or ask your host to do it):

```sql
ALTER USER 'user'@'%' IDENTIFIED WITH mysql_native_password BY 'password';
FLUSH PRIVILEGES;
```

MariaDB does not have this problem.

**`[LR] Missing Utils system plugin`**

Game Utils is missing or did not load. Install it first, see [Before you install](#before-you-install).

## What is different from the original

- Updated for the latest CS2 and Metamod:Source 2.x.
- Fixed: chat commands with `/` in front did not work
  ([#22](https://github.com/Pisex/cs2-lvl_ranks/issues/22)).
- Fixed: `Duplicate column name 'online'` error on every start
  ([#14](https://github.com/Pisex/cs2-lvl_ranks/issues/14)).
- The two common errors above are now explained
  ([#20](https://github.com/Pisex/cs2-lvl_ranks/issues/20)).

## Building it yourself

Most people can skip this and use the files from Releases.

Clone with `git clone --recursive`. Put [mrc4tt/hl2sdk](https://github.com/mrc4tt/hl2sdk)
(`cs2` branch), [mrc4tt/metamod-source](https://github.com/mrc4tt/metamod-source) and
[hl2sdk-manifests](https://github.com/alliedmodders/hl2sdk-manifests) next to it, install
[AMBuild](https://github.com/alliedmodders/ambuild), then:

```bash
mkdir build && cd build
python3 ../configure.py -s cs2 --targets=x86_64 --enable-optimize \
  --hl2sdk-root=/path/to/sdks --mms_path=/path/to/metamod-source
ambuild
```

`--hl2sdk-root` is the folder that contains `hl2sdk-cs2`. The finished plugin is in
`build/package/`.

Official releases are built with [cs2-build-system](https://github.com/mrc4tt/cs2-build-system).

## Credits

Made by [Pisex](https://github.com/Pisex), based on Levels Ranks for SourceMod by RoadSide
Romeo and Wend4r. Licensed under GPL.
