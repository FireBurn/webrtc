#!/bin/bash
# Prune a gclient checkout of this repository down to what libwebrtc needs on
# Linux: drop the git metadata and every third_party directory that is not in
# keep-third-party.txt. catapult is reduced to its build files.
set -euo pipefail
src=${1:?usage: prune.sh <checkout>/src}
here=$(cd "$(dirname "$0")" && pwd)

while IFS= read -r -d '' d; do
	name=${d##*/}
	grep -qx -- "${name}" "${here}/keep-third-party.txt" || rm -rf -- "${d}"
done < <(find "${src}/third_party" -mindepth 1 -maxdepth 1 -type d -print0)

# testing/BUILD.gn only needs catapult's build files
if [[ -d ${src}/third_party/catapult ]]; then
	find "${src}/third_party/catapult" -type f ! -name 'BUILD.gn' ! -name '*.gni' -delete
	find "${src}/third_party/catapult" -type d -empty -delete
fi

find "${src}" -name .git -prune -exec rm -rf {} +
rm -rf -- "${src}/out"
