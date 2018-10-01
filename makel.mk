MAKEL_VERSION=0.1.0

MAKEL_LOAD_PATH=-L . $(patsubst %,-L ../%,$(ELPA_DEPENDENCIES))

MAKEL_SET_ARCHIVES0=${ELPA_ARCHIVES}
MAKEL_SET_ARCHIVES1=$(patsubst gnu,(cons \"gnu\" \"https://elpa.gnu.org/packages/\"),${MAKEL_SET_ARCHIVES0})
MAKEL_SET_ARCHIVES2=$(patsubst melpa,(cons \"melpa\" \"https://melpa.org/packages/\"),${MAKEL_SET_ARCHIVES1})
MAKEL_SET_ARCHIVES3=$(patsubst melpa-stable,(cons \"melpa-stable\" \"https://stable.melpa.org/packages/\"),${MAKEL_SET_ARCHIVES2})
MAKEL_SET_ARCHIVES4=$(patsubst org,(cons \"org\" \"https://orgmode.org/elpa/\"),${MAKEL_SET_ARCHIVES3})
MAKEL_SET_ARCHIVES=(setq package-archives (list ${MAKEL_SET_ARCHIVES4}))

EMACSBIN?=emacs
BATCH=$(EMACSBIN) -Q --batch $(MAKEL_LOAD_PATH) \
		--eval "(setq load-prefer-newer t)" \
		--eval "(require 'package)" \
		--eval "${MAKEL_SET_ARCHIVES}" \
		--eval "(setq enable-dir-local-variables nil)" \
		--funcall package-initialize

.PHONY: debug ci-dependencies check test test-ert lint lint-checkdoc lint-package-lint lint-compile

debug:
	@echo "MAKEL_LOAD_PATH=${MAKEL_LOAD_PATH}"
	@echo "MAKEL_SET_ARCHIVES=${MAKEL_SET_ARCHIVES}"
	@${BATCH} --eval "(message \"%S\" package-archives)"

ci-dependencies:
	# Install dependencies in a continuous integration environment
	$(BATCH) \
	--funcall package-refresh-contents \
	${patsubst %,--eval "(package-install (quote %))",${ELPA_DEPENDENCIES}}

####################################
# Check
####################################

check: test lint

####################################
# Tests
####################################

test: test-ert

####################################
# Tests - ERT
####################################

MAKEL_TEST_ERT_FILES0=$(filter-out %-autoloads.el,${TEST_ERT_FILES})
MAKEL_TEST_ERT_FILES=$(patsubst %,(load-file \"%\"),${MAKEL_TEST_ERT_FILES0})

test-ert:
	# Run ert tests…
	@output=$$(mktemp --tmpdir "makel-test-ert-XXXXX"); \
	${BATCH} \
	$(if ${TEST-ERT_OPTIONS},${TEST-ERT_OPTIONS}) \
	--eval "(progn ${MAKEL_TEST_ERT_FILES} (ert-run-tests-batch-and-exit))" \
	> $${output} 2>&1 || cat $${output}

####################################
# Lint
####################################

lint: lint-checkdoc lint-package-lint lint-compile

####################################
# Lint - Checkdoc
####################################

MAKEL_LINT_CHECKDOC_FILES0=$(filter-out %-autoloads.el,${LINT_CHECKDOC_FILES})
MAKEL_LINT_CHECKDOC_FILES=$(patsubst %,\"%\",${MAKEL_LINT_CHECKDOC_FILES0})

lint-checkdoc:
	# Run checkdoc to check Emacs Lisp conventions…
	@${BATCH} \
	$(if ${LINT_CHECKDOC_OPTIONS},${LINT_CHECKDOC_OPTIONS}) \
	--eval "(mapcar #'checkdoc-file (list ${MAKEL_LINT_CHECKDOC_FILES}))"

####################################
# Lint - Package-lint
####################################

MAKEL_LINT_PACKAGE_LINT_FILES=$(filter-out %-autoloads.el,${LINT_PACKAGE_LINT_FILES})

lint-package-lint:
	# Run package-lint to check for packaging mistakes…
	@${BATCH} \
	--eval "(require 'package-lint)" \
	$(if ${LINT_PACKAGE_LINT_OPTIONS},${LINT_PACKAGE_LINT_OPTIONS}) \
	--funcall package-lint-batch-and-exit \
	${MAKEL_LINT_PACKAGE_LINT_FILES}

####################################
# Lint - Compilation
####################################

MAKEL_LINT_COMPILE_FILES=$(filter-out %-autoloads.el,${LINT_COMPILE_FILES})

lint-compile:
	# Byte compile all and stop on any warning or error…
	@${BATCH} \
	--eval "(setq byte-compile-error-on-warn t)" \
	$(if ${LINT_COMPILE_OPTIONS},${LINT_COMPILE_OPTIONS}) \
	--funcall batch-byte-compile \
	${MAKEL_LINT_COMPILE_FILES}
