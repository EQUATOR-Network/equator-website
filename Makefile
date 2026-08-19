SHELL := /bin/bash
RG_DIR := reporting-guidelines
RG_DEV_DIR := $(RG_DIR)/under-development

rg:
	@read -p "Enter guideline title " title && \
	source _utils/create-slug.sh && \
	slug=$$(slugify "$$title") && \
	rg_dir="$(RG_DIR)/$$slug" && \
	rg_index_path="$$rg_dir/index.qmd" && \
	mkdir "$$rg_dir" && \
	cp "$(RG_DIR)/_blank_rg.qmd" "$$rg_index_path" && \
	echo "Created: $$rg_index_path"

rg-under-development:
	@bash _utils/create-rg-under-development.sh

publish: render
	quarto publish gh-pages --no-render

render:
	quarto render

check-links:
	@bash _tests/check-link-integrity.sh

check-render-artifacts:
	@bash _tests/check-render-artifacts.sh

check-site: check-links check-render-artifacts

preview:
	quarto preview

test: 
	bash _tests/check-link-integrity.sh
	bash _tests/check-render-artifacts.sh

.PHONY: rg rg-under-development publish render check-links check-render-artifacts check-site preview