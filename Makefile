# Rubin stoker profile — maintenance tasks.
#
# The pinned upstream ref lives in UPSTREAM_STOKER_REF (written by the sync
# script). A no-argument `make sync-upstream` re-syncs that pinned ref; pass
# STOKER_REF=<ref> to bump it.
STOKER_REF ?= $(shell sed -n 's/^ref = //p' UPSTREAM_STOKER_REF 2>/dev/null)

.PHONY: help
help:  ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

.PHONY: sync-upstream
sync-upstream:  ## Fetch upstream base skills into .upstream-cache/ for diffing
	@if [ -z "$(STOKER_REF)" ]; then \
		echo "error: STOKER_REF is unset and UPSTREAM_STOKER_REF is missing;" >&2; \
		echo "       run: make sync-upstream STOKER_REF=<tag|branch|sha>" >&2; \
		exit 2; \
	fi
	STOKER_REF=$(STOKER_REF) scripts/sync-upstream.sh

.PHONY: lint
lint:  ## Run pre-commit across all files
	pre-commit run --all-files
