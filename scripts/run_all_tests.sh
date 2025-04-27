#!/bin/bash

set -e # Exit immediately if a command exits with a non-zero status.

# Function to run tests in a directory if a 'test' subdirectory exists
run_tests_if_present() {
  dir=$1
  if [ -d "$dir/test" ]; then
    echo "--- Running tests in $dir ---"
    (cd "$dir" && fvm flutter test)
    echo "--- Finished tests in $dir ---"
    echo ""
  else
    echo "--- No tests found in $dir ---"
    echo ""
  fi
}

# Run tests in packages
echo "=== Running Package Tests ==="
for pkg_dir in packages/*; do
  if [ -d "$pkg_dir" ]; then
    run_tests_if_present "$pkg_dir"
  fi
done

# Run tests in examples
echo "=== Running Example Tests ==="
for example_dir in examples/*; do
  if [ -d "$example_dir" ]; then
    run_tests_if_present "$example_dir"
  fi
done

echo "=== All tests completed ===" 
