#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

package_name_for_file() {
  local file_dir
  file_dir="$(dirname "$1")"

  while [ "$file_dir" != "/" ]; do
    if [ -f "$file_dir/pubspec.yaml" ]; then
      awk '
        /^name:[[:space:]]*/ {
          sub(/^name:[[:space:]]*/, "", $0)
          print $0
          exit
        }
      ' "$file_dir/pubspec.yaml"
      return 0
    fi
    file_dir="$(dirname "$file_dir")"
  done

  return 1
}

violations=0

while IFS= read -r dart_file; do
  if ! current_package_name="$(package_name_for_file "$dart_file")"; then
    echo "package name could not be determined for: $dart_file" >&2
    violations=$((violations + 1))
    continue
  fi

  while IFS=: read -r line_number line_text; do
    if [[ $line_text =~ ^[[:space:]]*(import|export|part)[[:space:]]+ ]] && [[ $line_text == *package:*"/src/"* ]]; then
      imported_package_name="${line_text#*package:}"
      imported_package_name="${imported_package_name%%/src/*}"
    else
      imported_package_name=""
    fi

    if [ -n "$imported_package_name" ] && [ "$imported_package_name" != "$current_package_name" ]; then
      echo "${dart_file}:${line_number}: cross-package src import detected"
      echo "  current package:   ${current_package_name}"
      echo "  imported package:  ${imported_package_name}"
      echo "  directive:         ${line_text}"
      violations=$((violations + 1))
    fi
  done < <(
    rg -n --glob '*.dart' --glob '!**/.dart_tool/**' --glob '!**/build/**' \
      'package:[^/]+/src/' \
      "$dart_file"
  )
done < <(
  find "$ROOT_DIR/packages" "$ROOT_DIR/examples" \
    -type f -name '*.dart' \
    -not -path '*/.dart_tool/*' \
    -not -path '*/build/*' \
    | sort
)

if [ "$violations" -ne 0 ]; then
  echo
  echo "Cross-package src import check failed with ${violations} violation(s)." >&2
  exit 1
fi

echo "Cross-package src import check passed."
