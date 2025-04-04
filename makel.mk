MAKEL_VERSION=1.0.0

MAKEL_LOAD_PATH=-L . $(patsubst %,-L ../%,$(ELPA_DEPENDENCIES))

MAKEL_SET_ARCHIVES0=${ELPA_ARCHIVES}
MAKEL_SET_ARCHIVES1=$(patsubst gnu,(cons \"gnu\" \"https://elpa.gnu.org/packages/\"),${MAKEL_SET_ARCHIVES0})
MAKEL_SET_ARCHIVES2=$(patsubst elpa,(cons \"elpa\" \"https://elpa.gnu.org/packages/\"),${MAKEL_SET_ARCHIVES1}) # alias of the previous one
MAKEL_SET_ARCHIVES3=$(patsubst elpa-devel,(cons \"gnu\" \"https://elpa.gnu.org/devel/\"),${MAKEL_SET_ARCHIVES2})
MAKEL_SET_ARCHIVES4=$(patsubst nongnu,(cons \"nongnu\" \"https://elpa.nongnu.org/nongnu/\"),${MAKEL_SET_ARCHIVES3})
MAKEL_SET_ARCHIVES5=$(patsubst melpa,(cons \"melpa\" \"https://melpa.org/packages/\"),${MAKEL_SET_ARCHIVES4})
MAKEL_SET_ARCHIVES6=$(patsubst melpa-stable,(cons \"melpa-stable\" \"https://stable.melpa.org/packages/\"),${MAKEL_SET_ARCHIVES5})
MAKEL_SET_ARCHIVES7=$(patsubst org,(cons \"org\" \"https://orgmode.org/elpa/\"),${MAKEL_SET_ARCHIVES6})
MAKEL_SET_ARCHIVES=(setq package-archives (list ${MAKEL_SET_ARCHIVES7}))

EMACSBIN?=emacs
BATCH=$(EMACSBIN) -Q --batch $(MAKEL_LOAD_PATH) \
		--eval "(setq load-prefer-newer t)" \
		--eval "(require 'package)" \
		--eval "${MAKEL_SET_ARCHIVES}" \
		--eval "(setq enable-dir-local-variables nil)" \
		--funcall package-initialize

CURL = curl --fail --silent --show-error --insecure \
	--location --retry 9 --retry-delay 9 \
	--remote-name-all

# Definition of a utility function `split_with_commas`.
# Argument 1: a space-separated list of filenames
# Return: a comma+space-separated list of filenames
comma:=,
empty:=
space:=$(empty) $(empty)
split_with_commas=$(subst ${space},${comma}${space},$(1))


.PHONY: debug install-elpa-dependencies download-non-elpa-dependencies ci-dependencies check test test-ert test-buttercup lint lint-checkdoc lint-package-lint lint-compile

makel-version:
	@echo "makel v${MAKEL_VERSION}"

debug:
	@echo "MAKEL_LOAD_PATH=${MAKEL_LOAD_PATH}"
	@echo "MAKEL_SET_ARCHIVES=${MAKEL_SET_ARCHIVES}"
	@${BATCH} --eval "(message \"%S\" package-archives)"

install-elpa-dependencies:
	@if [ -n "${ELPA_DEPENDENCIES}" ]; then \
	  echo "# Install ELPA dependencies: $(call split_with_commas,${ELPA_DEPENDENCIES})…"; \
	  output=$$($(BATCH) \
	    --funcall package-refresh-contents \
	    ${patsubst %,--eval "(package-install (quote %))",${ELPA_DEPENDENCIES}} 2>&1) \
	    || ( echo "$${output}" && exit 1 ); \
	fi

download-non-elpa-dependencies:
	@if [ -n "${DOWNLOAD_DEPENDENCIES}" ]; then \
	  echo "# Download non-ELPA dependencies: $(call split_with_commas,${DOWNLOAD_DEPENDENCIES})…"; \
	  $(CURL) $(patsubst %,"%",${DOWNLOAD_DEPENDENCIES}); \
	fi

ci-dependencies: install-elpa-dependencies download-non-elpa-dependencies

check: test lint

####################################
# Tests
####################################

test: test-ert test-buttercup test-ecukes

####################################
# Tests - ERT
####################################

MAKEL_TEST_ERT_FILES0=$(filter-out %-autoloads.el,${TEST_ERT_FILES})
MAKEL_TEST_ERT_FILES=$(patsubst %,(load-file \"%\"),${MAKEL_TEST_ERT_FILES0})

test-ert:
	@if [ -n "${TEST_ERT_FILES}" ]; then \
	  echo "# Run ert tests from $(call split_with_commas,${MAKEL_TEST_ERT_FILES0})…"; \
	  output=$$(${BATCH} \
	  $(if ${TEST_ERT_OPTIONS},${TEST_ERT_OPTIONS}) \
	  --eval "(progn ${MAKEL_TEST_ERT_FILES} (ert-run-tests-batch-and-exit))" 2>&1) \
	  || ( echo "$${output}" && exit 1 ); \
	fi;

####################################
# Tests - Buttercup
####################################

test-buttercup:
	@if [ -n "${TEST_BUTTERCUP_OPTIONS}" ]; then \
	  echo "# Run buttercup tests on $(call split_with_commas,${TEST_BUTTERCUP_OPTIONS})"; \
	  output=$$(${BATCH} \
	    --eval "(require 'buttercup)" \
	    -f buttercup-run-discover ${TEST_BUTTERCUP_OPTIONS} 2>&1) \
	    || ( echo "$${output}" && exit 1 ); \
	fi;

####################################
# Tests - Ecukes
####################################

# This rule has to work around the fact that checkdoc doesn't throw
# errors, it always succeeds. We thus have to check if checkdoc
# printed anything to decide the exit status of the rule.
test-ecukes:
	@if [ -n "${TEST_ECUKES_FEATURE_FILES}" ]; then \
	  echo "# Run ecukes tests on $(call split_with_commas,${TEST_ECUKES_FEATURE_FILES})"; \
	  output=$$(${BATCH} \
	    --eval "(require 'ecukes)" \
	    -f ecukes-load \
	    --eval "(ecukes-reporter-use \"magnars\")" \
	    --eval "(ecukes-run '($(patsubst %,\"%\", ${TEST_ECUKES_FEATURE_FILES})))" \
	    2>&1); \
	  ( echo "$$output" | tail -n 1 | sed -e "s/.*\([0-9]\+\) failed.*/\1/" | grep --quiet "^0$$" ) \
	    || ( echo "$${output}" && exit 1 ); \
	fi;

####################################
# Lint
####################################

lint: lint-checkdoc lint-package-lint lint-compile

####################################
# Lint - Checkdoc
####################################

MAKEL_LINT_CHECKDOC_FILES0=$(filter-out %-autoloads.el,${LINT_CHECKDOC_FILES})
MAKEL_LINT_CHECKDOC_FILES=$(patsubst %,\"%\",${MAKEL_LINT_CHECKDOC_FILES0})

# This rule has to work around the fact that checkdoc doesn't throw
# errors, it always succeeds. We thus have to check if checkdoc
# printed anything to decide the exit status of the rule.
lint-checkdoc:
	@if [ -n "${LINT_CHECKDOC_FILES}" ]; then \
	  echo "# Run checkdoc on $(call split_with_commas,${MAKEL_LINT_CHECKDOC_FILES0})…"; \
	  output=$$(${BATCH} \
	    $(if ${LINT_CHECKDOC_OPTIONS},${LINT_CHECKDOC_OPTIONS}) \
	    --eval "(mapcar #'checkdoc-file (list ${MAKEL_LINT_CHECKDOC_FILES}))" 2>&1); \
	  [ -z "$${output}" ] || (echo "$${output}"; exit 1); \
	fi;

####################################
# Lint - Package-lint
####################################

MAKEL_LINT_PACKAGE_LINT_FILES=$(filter-out %-autoloads.el,${LINT_PACKAGE_LINT_FILES})

lint-package-lint:
	@if [ -n "${LINT_PACKAGE_LINT_FILES}" ]; then \
	  echo "# Run package-lint on $(call split_with_commas,${MAKEL_LINT_PACKAGE_LINT_FILES})…"; \
	  ${BATCH} \
	  --eval "(require 'package-lint)" \
	  $(if ${LINT_PACKAGE_LINT_OPTIONS},${LINT_PACKAGE_LINT_OPTIONS}) \
	  --funcall package-lint-batch-and-exit \
	  ${MAKEL_LINT_PACKAGE_LINT_FILES}; \
	fi;

####################################
# Lint - Compilation
####################################

MAKEL_LINT_COMPILE_FILES=$(filter-out %-autoloads.el,${LINT_COMPILE_FILES})

lint-compile:
	@if [ -n "${LINT_COMPILE_FILES}" ]; then \
	  echo "# Run byte compilation on $(call split_with_commas,${MAKEL_LINT_COMPILE_FILES})…"; \
	  ${BATCH} \
	  --eval "(setq byte-compile-error-on-warn t)" \
	  $(if ${LINT_COMPILE_OPTIONS},${LINT_COMPILE_OPTIONS}) \
	  --funcall batch-byte-compile \
	  ${MAKEL_LINT_COMPILE_FILES}; \
	fi
