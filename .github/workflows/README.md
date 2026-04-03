# GitHub Actions Workflows

## test.yml
Runs tests on push/PR to `develop` branch.

## test-all-branches.yml
Runs tests on push/PR to all branches (main, master).

Both workflows install bats via apt and execute the test suite in `./bats-tests/run-tests.sh`.
