#!/usr/bin/env bash
# Builds Levels Ranks for Linux and Windows in Docker on this machine and, with --upload,
# publishes the packages to this fork's GitHub releases. Replaces upstream's GitHub Actions
# workflow; this fork has no CI.
#
# Usage: support/local-release.sh [--upload|--dry-run] [--clobber] [--targets linux,windows]
#
#   --upload    create/update the GitHub release for this version and attach the packages;
#               does nothing when that release already has every package
#   --dry-run   like --upload, but only builds and prints what would be released
#   --clobber   with --upload, replace assets that already exist on the release
#   --targets   comma list of linux,windows (default: both)
#
# Linux builds in the SteamRT3 (sniper, glibc 2.31) SDK container. glibc is backward
# compatible, so that one binary loads on CS2 servers running either SteamRT3 or SteamRT4;
# the build fails if the binary needs a newer glibc than 2.31. Windows builds with real MSVC
# under Wine (msvc-wine image from cs2-build-system/msvc-wine-runner).
#
# Built against mrc4tt/hl2sdk (cs2) and mrc4tt/metamod-source. The plugin API of that fork is
# identical to alliedmodders/metamod-source, so the packages load on either Metamod build.
#
# Output: build-release/levels_ranks-<version>-{linux.tar.gz,windows.zip}
# Cache:  ${XDG_CACHE_HOME:-~/.cache}/lvl-ranks-local-release (SDKs, Metamod, AMBuild, Windows Python)
set -euo pipefail

UPLOAD=0
DRY_RUN=0
CLOBBER=0
TARGETS="linux,windows"
while [ $# -gt 0 ]; do
	case "$1" in
		--upload)  UPLOAD=1 ;;
		--dry-run) UPLOAD=1; DRY_RUN=1 ;;
		--clobber) CLOBBER=1 ;;
		--targets) TARGETS="$2"; shift ;;
		-h|--help) sed -n '2,23p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
		*) echo "Unknown argument '$1' (see --help)" >&2; exit 1 ;;
	esac
	shift
done

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/lvl-ranks-local-release"
OUT="$REPO/build-release"
LINUX_IMAGE="${LINUX_IMAGE:-ghcr.io/source2ze/build-containers:steamrt3}"
MSVC_IMAGE="${MSVC_IMAGE:-msvc-wine:latest}"
GH_REPO="${GH_REPO:-mrc4tt/cs2-lvl_ranks}"
GLIBC_MAX="2.31"
WINPY_VERSION=3.12.7

# Version = product.version + commit count, so every pushed commit maps to one release.
version_base=$(cat "$REPO/product.version")
version_rev=$(git -C "$REPO" rev-list --count HEAD)
version="${version_base}-r${version_rev}"
commit=$(git -C "$REPO" rev-parse HEAD)
shorthash=$(git -C "$REPO" rev-parse --short HEAD)

echo "==> Levels Ranks $version ($shorthash), targets=$TARGETS"

if [ "$UPLOAD" = "1" ]; then
	command -v gh >/dev/null || { echo "ERROR: --upload needs the gh CLI" >&2; exit 1; }
	# The release tag points at this commit, so GitHub has to know it.
	if [ -z "$(git -C "$REPO" branch -r --contains "$commit" 2>/dev/null)" ]; then
		echo "ERROR: $shorthash is not on any remote branch; push it before --upload" >&2
		exit 1
	fi
	if [ "$CLOBBER" = "0" ]; then
		have=$(gh release view "$version" --repo "$GH_REPO" --json assets -q '.assets[].name' 2>/dev/null || true)
		missing=0
		IFS=',' read -ra target_list <<< "$TARGETS"
		for target in "${target_list[@]}"; do
			case "$target" in linux) ext=tar.gz ;; *) ext=zip ;; esac
			grep -qxF "levels_ranks-${version}-$target.$ext" <<< "$have" || missing=1
		done
		if [ "$missing" = "0" ]; then
			echo "==> $version is already released with every package, nothing to do"
			exit 0
		fi
	fi
fi

git -C "$REPO" submodule update --init --recursive

mkdir -p "$CACHE/deps" "$OUT"
fetch_ref() {
	local repo="$1" ref="$2" dir="$3"
	if [ ! -d "$dir/.git" ]; then
		git init -q "$dir"
		git -C "$dir" remote add origin "$repo"
	fi
	git -C "$dir" fetch -q --depth 1 origin "$ref"
	git -C "$dir" checkout -q -f FETCH_HEAD
	git -C "$dir" submodule update -q --init --recursive --depth 1
}
# A stale SDK builds fine and then mis-targets vtables at runtime, so always refresh.
echo "==> hl2sdk-cs2, metamod-source, hl2sdk-manifests"
fetch_ref https://github.com/mrc4tt/hl2sdk cs2 "$CACHE/deps/hl2sdk-cs2"
fetch_ref https://github.com/mrc4tt/metamod-source master "$CACHE/metamod-source"
# AMBuildScript prefers a hl2sdk-manifests folder next to the source tree over the
# (possibly stale) copy vendored in this repo.
fetch_ref https://github.com/alliedmodders/hl2sdk-manifests master "$CACHE/hl2sdk-manifests"

if [ ! -d "$CACHE/ambuild/.git" ]; then
	git clone -q --depth 1 https://github.com/alliedmodders/ambuild "$CACHE/ambuild"
else
	git -C "$CACHE/ambuild" pull -q --ff-only
fi

package_name() { case "$1" in linux) echo "levels_ranks-${version}-linux.tar.gz" ;; *) echo "levels_ranks-${version}-windows.zip" ;; esac; }

DOCKER_MOUNTS=(
	-v "$REPO:/src:ro"
	-v "$CACHE/deps:/deps:ro"
	-v "$CACHE/metamod-source:/mms:ro"
	-v "$CACHE/hl2sdk-manifests:/manifests:ro"
	-v "$CACHE/ambuild:/ambuild:ro"
	-v "$OUT:/out"
)
# Same layout in both containers: /work/plugin, with the manifests as its sibling.
PREPARE_WORK='rm -rf /work && mkdir /work && cp -r /src /work/plugin && cp -r /manifests /work/hl2sdk-manifests
			rm -rf /work/plugin/build /work/plugin/build-release && mkdir /work/plugin/build && cd /work/plugin/build'

build_linux() {
	local file; file=$(package_name linux)
	echo "==> Building linux ($LINUX_IMAGE)"
	docker run --rm "${DOCKER_MOUNTS[@]}" "$LINUX_IMAGE" \
		bash -euo pipefail -c "
			export PYTHONPATH=/ambuild CC=clang CXX=clang++
			$PREPARE_WORK
			python3 ../configure.py -s cs2 --targets=x86_64 --enable-optimize --mms_path=/mms --hl2sdk-root=/deps
			python3 -c 'import ambuild2.run as r; r.cli_run()'
			so=\$(find package -name '*.so' | head -1)
			test -n \"\$so\"
			need=\$(objdump -T \"\$so\" | grep -o 'GLIBC_[0-9.]*' | sed 's/GLIBC_//' | sort -uV | tail -1)
			echo \"==> \$so needs glibc \$need (limit $GLIBC_MAX)\"
			if [ \"\$(printf '%s\n' \"\$need\" '$GLIBC_MAX' | sort -V | tail -1)\" != '$GLIBC_MAX' ]; then
				echo 'ERROR: binary needs a newer glibc than SteamRT3 ships' >&2; exit 1
			fi
			cd package && tar zcf /out/$file addons
			chown $(id -u):$(id -g) /out/$file"
	echo "==> linux OK: $OUT/$file"
}

build_windows() {
	local file; file=$(package_name windows)
	docker image inspect "$MSVC_IMAGE" >/dev/null 2>&1 || {
		echo "ERROR: $MSVC_IMAGE not found; build it from cs2-build-system/msvc-wine-runner (docker build -t msvc-wine .)" >&2
		exit 1
	}
	if [ ! -f "$CACHE/winpy/tools/python.exe" ]; then
		echo "==> Fetching Windows Python $WINPY_VERSION"
		mkdir -p "$CACHE/winpy"
		curl -fsSL -o "$CACHE/winpy/python.nupkg" "https://www.nuget.org/api/v2/package/python/$WINPY_VERSION"
		python3 -c 'import sys, zipfile; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])' \
			"$CACHE/winpy/python.nupkg" "$CACHE/winpy"
	fi
	echo "==> Building windows"
	# Wine's Python cannot open its standard streams when they are redirected to a file,
	# so its output always goes through a pipe.
	docker run --rm "${DOCKER_MOUNTS[@]}" -v "$CACHE/winpy:/winpy:ro" "$MSVC_IMAGE" \
		bash -euo pipefail -c "
			. /opt/msvc/bin/x64/msvcenv.sh
			export WINEDEBUG=-all PYTHONPATH='Z:\\ambuild' PYTHONUTF8=1 CC=cl CXX=cl
			$PREPARE_WORK
			wine /winpy/tools/python.exe 'Z:\\work\\plugin\\configure.py' -s cs2 --targets=x86_64 --enable-optimize '--mms_path=Z:\\mms' '--hl2sdk-root=Z:\\deps' 2>&1 | cat
			wine /winpy/tools/python.exe -c 'import ambuild2.run as r; r.cli_run()' 2>&1 | cat
			test -n \"\$(find package -name '*.dll' | head -1)\"
			rm -rf /out/win-package && cp -r package /out/win-package
			chown -R $(id -u):$(id -g) /out/win-package"
	rm -f "$OUT/$file"
	(cd "$OUT/win-package" && python3 -c 'import os, sys, zipfile
with zipfile.ZipFile(sys.argv[1], "w", zipfile.ZIP_DEFLATED) as z:
	for root, _, files in os.walk("addons"):
		for f in files:
			z.write(os.path.join(root, f))' "$OUT/$file")
	rm -rf "$OUT/win-package"
	echo "==> windows OK: $OUT/$file"
}

files=()
IFS=',' read -ra target_list <<< "$TARGETS"
for target in "${target_list[@]}"; do
	case "$target" in
		linux)   build_linux ;;
		windows) build_windows ;;
		*) echo "Unknown target '$target' (use linux, windows)" >&2; exit 1 ;;
	esac
	files+=("$OUT/$(package_name "$target")")
done

notes="Built from ${shorthash} against mrc4tt/hl2sdk (cs2) and mrc4tt/metamod-source.

Works with both mrc4tt/metamod-source and alliedmodders/metamod-source.
The Linux package targets glibc ${GLIBC_MAX}, so it loads on SteamRT3 and SteamRT4 servers."

if [ "$DRY_RUN" = "1" ]; then
	echo "==> (dry run) would release $version on $GH_REPO ($shorthash) with:"
	printf '    %s\n' "${files[@]##*/}"
elif [ "$UPLOAD" = "1" ]; then
	if gh release view "$version" --repo "$GH_REPO" >/dev/null 2>&1; then
		echo "==> Release $version exists, uploading assets"
		upload_flags=()
		[ "$CLOBBER" = "1" ] && upload_flags+=(--clobber)
		gh release upload "$version" "${files[@]}" --repo "$GH_REPO" "${upload_flags[@]}"
	else
		echo "==> Creating release $version"
		gh release create "$version" "${files[@]}" --repo "$GH_REPO" \
			--target "$commit" --title "Levels Ranks $version" --notes "$notes" --latest
	fi
	echo "==> https://github.com/$GH_REPO/releases/tag/$version"
fi
