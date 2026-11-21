#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# rufus-cli - test runner.
#
#   run.sh [unit|e2e|all] [NAME-FILTER]
#
# unit tests need no privileges; e2e tests need root and loop devices and
# really partition, format and write disk images.
set -u

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
suite=${1:-unit}
filter=${2:-}

case $suite in
	unit) dirs=("$here/unit") ;;
	e2e) dirs=("$here/e2e") ;;
	all) dirs=("$here/unit" "$here/e2e") ;;
	*)
		echo "usage: run.sh [unit|e2e|all] [NAME-FILTER]" >&2
		exit 2
		;;
esac

total=0
failed=0
failed_names=()
for dir in "${dirs[@]}"; do
	[[ -d $dir ]] || continue
	for f in "$dir"/*.test.sh; do
		[[ -e $f ]] || continue
		name=${f##*/}
		if [[ -n $filter && $name != *"$filter"* ]]; then
			continue
		fi
		total=$((total + 1))
		printf '=== %s\n' "$name"
		if "$BASH" "$f"; then
			:
		else
			rc=$?
			failed=$((failed + 1))
			failed_names+=("$name (exit $rc)")
		fi
	done
done

printf '\n%d test file(s), %d failed\n' "$total" "$failed"
if ((failed > 0)); then
	printf '  %s\n' "${failed_names[@]}"
	exit 1
fi
if ((total == 0)); then
	echo "no tests found" >&2
	exit 1
fi
exit 0
