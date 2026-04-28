SHELL := /bin/bash
RG_DIR := reporting-guidelines
RG_DEV_DIR := $(RG_DIR)/under-development

rg:
	@read -p "Enter guideline title " title && \
	source utils/create-slug.sh && \
	slug=$$(slugify "$$title") && \
	rg_dir="$(RG_DIR)/$$slug" && \
	rg_index_path="$$rg_dir/index.qmd" && \
	mkdir "$$rg_dir" && \
	cp "$(RG_DIR)/_blank_rg.qmd" "$$rg_index_path" && \
	echo "Created: $$rg_index_path"
