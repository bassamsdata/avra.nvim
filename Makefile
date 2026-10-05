.PHONY: all
all: format-check lint accessibility-check

.PHONY: format-check
format-check:
	stylua . --check

.PHONY: format
format:
	stylua .

.PHONY: lint
lint:
	luacheck -q .

.PHONY: accessibility-check
accessibility-check:
	python3 -B tools/test_contrast.py
	python3 tools/check_contrast.py

CONTRAST_REPORT ?= /tmp/avra-contrast-report.html
.PHONY: accessibility-report
accessibility-report:
	python3 tools/check_contrast.py --report "$(CONTRAST_REPORT)"
