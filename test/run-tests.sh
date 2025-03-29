#!/usr/bin/env bash

nb_tests=0
nb_failures=0

function run {
    ((nb_tests++))
    TEST_PARAMS="$*"
    OUTPUT=$(make --file ../makel.mk "$@" 2>&1)
    EXIT_STATUS=$?
}

function record_failure {
    echo
    echo "Failure in test ${nb_tests}"
    ((nb_failures++));
}

function conclude {
    if [[ $nb_failures -eq 0 ]]; then
        exit 0
    elif [[ $nb_failures -eq 1 ]]; then
        echo
        echo "There was 1 failure out of ${nb_tests} tests"
        exit 1
    else
        echo
        echo "There were ${nb_failures} failures out of ${nb_tests} tests"
        exit 1
    fi
}

function display_output {
    echo
    echo ----BEGIN----
    echo "$OUTPUT"
    echo -----END-----
}

function check_output {
    echo "$OUTPUT" | grep --quiet "$1"
    if [[ ${PIPESTATUS[1]} -eq 1 ]]; then
        record_failure
        echo "Failure finding '$1' within the result of 'make ${TEST_PARAMS}', output was:"
        display_output
    fi
}

function check_not_output {
    echo "$OUTPUT" | grep --quiet "$1"
    if [[ ${PIPESTATUS[1]} -eq 0 ]]; then
        record_failure
        echo "Unexpected finding of '$1' within the result of 'make ${TEST_PARAMS}', output was:"
        display_output
    fi
}

function check_exit_success {
    if [[ ! "$EXIT_STATUS" -eq 0 ]]; then
        record_failure
        echo "Exit status of 'make ${TEST_PARAMS} was expected to be 0 but was ${EXIT_STATUS}."
    fi
}

function check_exit_failure {
    if [[ "$EXIT_STATUS" -eq 0 ]]; then
        record_failure
        echo "Exit status of 'make ${TEST_PARAMS} was expected to be different from 0 but it was not."
    fi
}

####################################
# Tests - ELPA ARCHIVES
####################################

# Check that package-archives is populated properly
run ELPA_ARCHIVES=gnu debug
check_output "https://elpa.gnu.org/packages"

run ELPA_ARCHIVES=elpa debug
check_output "https://elpa.gnu.org/packages"

run ELPA_ARCHIVES=elpa-devel debug
check_output "https://elpa.gnu.org/devel"

run ELPA_ARCHIVES=nongnu debug
check_output "https://elpa.nongnu.org/nongnu"

run ELPA_ARCHIVES=melpa debug
check_output "https://melpa.org/packages"

run ELPA_ARCHIVES=melpa-stable debug
check_output "https://stable.melpa.org/packages"

run ELPA_ARCHIVES=org debug
check_output "https://orgmode.org/elpa"

####################################
# Tests - CI-DEPENDENCIES
####################################

# Check that multiple files can be downloaded with curl
run CURL="echo curl" DOWNLOAD_DEPENDENCIES="gitlab.com/foo.el gitlab.com/bar.el" ci-dependencies
check_output "curl gitlab.com/foo.el gitlab.com/bar.el"

# Check that downloading dependencies when there are none is ok
run CURL="echo curl" DOWNLOAD_DEPENDENCIES="" ci-dependencies
check_not_output "curl"

####################################
# Tests - ERT
####################################

# Check that running tests displays the test file
run TEST_ERT_FILES="data/test-ert-ok-1.el" test-ert
check_output "from data/test-ert-ok-1.el…"

# Check that running tests displays test files separated with commas
run TEST_ERT_FILES="data/test-ert-ok-1.el data/test-ert-ok-2.el" test-ert
check_output "from data/test-ert-ok-1.el, data/test-ert-ok-2.el…"

# Check that running tests does not display test function names when all tests pass
run TEST_ERT_FILES="data/test-ert-ok-1.el" test-ert
check_not_output "test-ert-ok-1-1"

# Check that running tests displays test function names that fail
run TEST_ERT_FILES="data/test-ert-ko.el" test-ert
check_output "test-ert-ko-1"

# Check that running successful tests exits with success status
run TEST_ERT_FILES="data/test-ert-ok-1.el" test-ert
check_exit_success

# Check that running a failing test exits with failure status
run TEST_ERT_FILES="data/test-ert-ko.el" test-ert
check_exit_failure

# Check that running several tests including one failing exits with failure status
run TEST_ERT_FILES="data/test-ert-ok-1.el data/test-ert-ko.el" test-ert
check_exit_failure

# Check that empty TEST_ERT_FILES doesn't run ert
run TEST_ERT_FILES="" test-ert
check_not_output "ert"

####################################
# Tests - Buttercup
####################################

# Check that running tests displays the options
run TEST_BUTTERCUP_OPTIONS="data/buttercup/ok" test-buttercup
check_output data/buttercup/ok

# Check that running successful tests exits with success status
run TEST_BUTTERCUP_OPTIONS="data/buttercup/ok" test-buttercup
check_exit_success

# Check that running a failing test exits with failure status
run TEST_BUTTERCUP_OPTIONS="data/buttercup/ko" test-buttercup
check_exit_failure

# Check that running tests displays test names that fail
run TEST_BUTTERCUP_OPTIONS="data/buttercup/ko" test-buttercup
check_output "test-buttercup-ko should fail"

# Check that empty TEST_BUTTERCUP_OPTIONS doesn't run buttercup
run TEST_BUTTERCUP_OPTIONS="" test-buttercup
check_not_output "buttercup"

####################################
# Lint - Checkdoc
####################################

# Check that linting displays file names separated with commas
run LINT_CHECKDOC_FILES="data/test-lint-checkdoc-ok.el data/test-lint-checkdoc-ko.el" lint-checkdoc
check_output "on data/test-lint-checkdoc-ok.el, data/test-lint-checkdoc-ko.el…"

# Check that linting ignores autoload files
run LINT_CHECKDOC_FILES="data/test-lint-checkdoc-ok.el data/test-lint-checkdoc-ko.el data/test-lint-checkdoc-autoloads.el" lint-checkdoc
check_output "on data/test-lint-checkdoc-ok.el, data/test-lint-checkdoc-ko.el…"

# Check that linting a clean file echoes no error line
run LINT_CHECKDOC_FILES="data/test-lint-checkdoc-ok.el" lint-checkdoc
check_not_output "^test-lint-checkdoc-ok.el:"

# Check that linting an unclean file echoes an error line
run LINT_CHECKDOC_FILES="data/test-lint-checkdoc-ko-1.el" lint-checkdoc
check_output "^test-lint-checkdoc-ko-1.el:.* Argument .foo. should appear (as FOO) in the doc string$"

# Check that linting a clean file exits with success status
run LINT_CHECKDOC_FILES="data/test-lint-checkdoc-ok.el" lint-checkdoc
check_exit_success

# Check that linting an unclean file exits with failure status
run LINT_CHECKDOC_FILES="data/test-lint-checkdoc-ko-1.el" lint-checkdoc
check_exit_failure

# Check that linting several files including an unclean one exits with failure status
run LINT_CHECKDOC_FILES="data/test-lint-checkdoc-ok.el data/test-lint-checkdoc-ko.el" lint-checkdoc
check_exit_failure

# Check that empty LINT_CHECKDOC_FILES doesn't run checkdoc
run LINT_CHECKDOC_FILES="" lint-checkdoc
check_not_output "checkdoc"

####################################
# Lint - Package-lint
####################################

# Check that running package-lint displays file names separated with commas
run LINT_PACKAGE_LINT_FILES="data/test-lint-package-lint-ok.el data/test-lint-package-lint-ko.el" lint-package-lint
check_output "on data/test-lint-package-lint-ok.el, data/test-lint-package-lint-ko.el…"

# Check that running package-lint a clean file echoes no error line
run LINT_PACKAGE_LINT_FILES="data/test-lint-package-lint-ok.el" lint-package-lint
check_not_output "^test-lint-package-lint-ok.el:"

# Check that running package-lint an unclean file echoes an error line
run LINT_PACKAGE_LINT_FILES="data/test-lint-package-lint-ko.el" lint-package-lint
check_output ":.* You can only depend on Emacs version 24 or greater"

# Check that running package-lint a clean file exits with success status
run LINT_PACKAGE_LINT_FILES="data/test-lint-package-lint-ok.el" lint-package-lint
check_exit_success

# Check that running package-lint an unclean file exits with failure status
run LINT_PACKAGE_LINT_FILES="data/test-lint-package-lint-ko.el" lint-package-lint
check_exit_failure

# Check that running package-lint several files including an unclean one exits with failure status
run LINT_PACKAGE_LINT_FILES="data/test-lint-package-lint-ok.el data/test-lint-package-lint-ko.el" lint-package-lint
check_exit_failure

# Check that empty LINT_PACKAGE_LINT_FILES doesn't run package-lint
run LINT_PACKAGE_LINT_FILES="" lint-package-lint
check_not_output "package-lint"

####################################
# Lint - Compilation
####################################

# Check that compilation displays file names separated with commas
run LINT_COMPILE_FILES="data/test-lint-compile-ok.el data/test-lint-compile-ko.el" lint-compile
check_output "on data/test-lint-compile-ok.el, data/test-lint-compile-ko.el…"

# Check that compilation of a clean file echoes no error line
run LINT_COMPILE_FILES="data/test-lint-compile-ok.el" lint-compile
check_not_output "^test-lint-compile-ok.el:"

# Check that compilation of an unclean file echoes an error line
run LINT_COMPILE_FILES="data/test-lint-compile-ko.el" lint-compile
check_output "data/test-lint-compile-ko.el:2:2: Error: the function .foo. is not known to be defined."

# Check that compilation of a clean file exits with success status
run LINT_COMPILE_FILES="data/test-lint-compile-ok.el" lint-compile
check_exit_success

# Check that compilation of an unclean file exits with failure status
run LINT_COMPILE_FILES="data/test-lint-compile-ko.el" lint-compile
check_exit_failure

# Check that compilation of several files including an unclean one exits with failure status
run LINT_COMPILE_FILES="data/test-lint-compile-ok.el data/test-lint-compile-ko.el" lint-compile
check_exit_failure

# Check that empty TEST_COMPILE-FILES doesn't byte compile
run TEST_COMPILE-FILES="" lint-compile
check_not_output "compil"


####################################
# Conclusion
####################################

conclude
