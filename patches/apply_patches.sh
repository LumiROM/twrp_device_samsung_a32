#!/bin/bash
#
# Applies the TWRP source patches of this device tree to bootable/recovery.
#
# The patches live here (and not as commits in bootable/recovery) because the
# TWRP sources are managed by `repo sync`, which resets that project and would
# throw the changes away. Run this script after every sync, before building.
#
# Usage:
#   device/samsung/a32/patches/apply_patches.sh [twrp-source-root]
#
# The source root defaults to the tree this device tree lives in. The script is
# safe to run more than once: patches that are already applied are skipped.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TWRP_ROOT="${1:-$(cd "$SCRIPT_DIR/../../../.." && pwd)}"
SRC_DIR="$TWRP_ROOT/bootable/recovery"

if [ ! -d "$SRC_DIR/.git" ]; then
	echo "ERROR: '$SRC_DIR' is not a TWRP source tree." >&2
	echo "       Pass the TWRP source root as the first argument." >&2
	exit 1
fi

ret=0
applied=0
for patch in "$SCRIPT_DIR"/*.patch; do
	[ -e "$patch" ] || continue
	name="$(basename "$patch")"

	if git -C "$SRC_DIR" apply --check --reverse "$patch" >/dev/null 2>&1; then
		echo " - $name: already applied, skipping."
		continue
	fi

	if ! git -C "$SRC_DIR" apply --check "$patch" >/dev/null 2>&1; then
		echo "ERROR: $name does not apply to '$SRC_DIR'." >&2
		echo "       The TWRP sources probably changed; check the patch." >&2
		ret=1
		continue
	fi

	if git -C "$SRC_DIR" apply "$patch"; then
		echo " - $name: applied."
		applied=$((applied + 1))
	else
		echo "ERROR: failed to apply $name." >&2
		ret=1
	fi
done

if [ "$ret" -eq 0 ]; then
	echo "Patches OK ($applied applied)."
fi

exit "$ret"
