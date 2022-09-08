
SHELL			= bash

NAME			= deepkey

HAPP_BUNDLE		= DeepKey.happ
DNA_DEEPKEY		= packs/deepkey.dna

TARGET			= release
DNA_DEEPKEY_WASM	= ./target/wasm32-unknown-unknown/release/deepkey.wasm \
			  ./target/wasm32-unknown-unknown/release/deepkey_integrity.wasm

# External targets; Uses a nix-shell environment to obtain Holochain runtimes, run tests, etc.
.PHONY: all FORCE
all: nix-test

# nix-test, nix-install, ...
nix-%:
	nix-shell --pure --run "make $*"

#
# Project
#
tests/package-lock.json:	tests/package.json
	touch $@
tests/node_modules:		tests/package-lock.json
	cd tests; npm install
	touch $@
clean:
	rm -rf \
	    tests/node_modules \
	    .cargo \
	    target \
	    Cargo.lock \
	    $(HAPP_BUNDLE) \
	    $(DNA_DEEPKEY)

.PHONY: rebuild build happ dna wasm
rebuild:			clean build

build:				happ

happ:				$(HAPP_BUNDLE)

$(HAPP_BUNDLE):			$(DNA_DEEPKEY) packs/happ.yaml
	hc app pack -o $@ ./packs/

dna:				$(DNA_DEEPKEY)

$(DNA_DEEPKEY):			$(DNA_DEEPKEY_WASM)

packs/%.dna:
	@echo "Packaging '$*': $@"
	@hc dna pack -o $@ packs/$*

wasm:				$(DNA_DEEPKEY_WASM)

target/wasm32-unknown-unknown/release/%.wasm:	Makefile zomes/%/src/*.rs zomes/%/Cargo.toml # deepkey_types/src/*.rs deepkey_types/Cargo.toml
	@echo "Building  '$*' WASM: $@"; \
	RUST_BACKTRACE=1 CARGO_TARGET_DIR=target cargo build --release \
	    --target wasm32-unknown-unknown \
	    --package $*
	@touch $@ # Cargo must have a cache somewhere because it doesn't update the file time


crates:				deepkey_types
deep_types:			deepkey_types/src/*.rs deepkey_types/Cargo.toml
	cd $@; cargo build && touch $@


#
# Testing
#
test:				happ	test-dnas	test-unit-all 
test-debug:			happ	test-dnas-debug	test-unit-all 

test-unit-all:			test-unit test-unit-dna_library test-unit-happ_library test-unit-web_assets
test-unit:
	cd devhub_types;	RUST_BACKTRACE=1 cargo test
test-unit-%:
	cd zomes;		RUST_BACKTRACE=1 cargo test $* -- --nocapture

tests/test.dna:
	cp $(DNA_DEEPKEY) $@
tests/test.gz:
	gzip -kc $(DNA_DEEPKEY) > $@

# DNAs
test-setup:			tests/node_modules

test-dnas:			test-setup test-dnarepo		test-happs		test-webassets		test-multi
test-dnas-debug:		test-setup test-dnarepo-debug	test-happs-debug	test-webassets-debug	test-multi-debug

test-dnarepo:			test-setup $(DNA_DEEPKEY)
	cd tests; RUST_LOG=none LOG_LEVEL=fatal npx mocha integration/test_dnarepo.js
test-dnarepo-debug:		test-setup $(DNA_DEEPKEY)
	cd tests; RUST_LOG=info LOG_LEVEL=silly npx mocha integration/test_dnarepo.js

test-happs:			test-setup $(HAPPDNA)
	cd tests; RUST_LOG=none LOG_LEVEL=fatal npx mocha integration/test_happs.js
test-happs-debug:		test-setup $(HAPPDNA)
	cd tests; RUST_LOG=info LOG_LEVEL=silly npx mocha integration/test_happs.js

test-webassets:			test-setup $(ASSETSDNA) tests/test.gz
	cd tests; RUST_LOG=none LOG_LEVEL=fatal npx mocha integration/test_webassets.js
test-webassets-debug:		test-setup $(ASSETSDNA) tests/test.gz
	cd tests; RUST_LOG=info LOG_LEVEL=silly npx mocha integration/test_webassets.js

test-multi:			test-setup $(DNA_DEEPKEY) $(HAPPDNA) $(ASSETSDNA) tests/test.gz tests/test.dna
	cd tests; RUST_LOG=none LOG_LEVEL=fatal npx mocha integration/test_multiple.js
test-multi-debug:		test-setup $(DNA_DEEPKEY) $(HAPPDNA) $(ASSETSDNA) tests/test.gz tests/test.dna
	cd tests; RUST_LOG=info LOG_LEVEL=silly npx mocha integration/test_multiple.js


#
# Repository
#
clean-remove-chaff:
	@find . -name '*~' -exec rm {} \;
clean-files:		clean-remove-chaff
	git clean -nd
clean-files-force:	clean-remove-chaff
	git clean -fd
clean-files-all:	clean-remove-chaff
	git clean -ndx
clean-files-all-force:	clean-remove-chaff
	git clean -fdx
