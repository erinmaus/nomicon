MSYS_VERSION := $(if $(findstring Msys, $(shell uname -o)),$(word 1, $(subst ., ,$(shell uname -r))),0)
ifneq ($(MSYS_VERSION),0)
	PLATFORM := Windows
else ifeq ($(shell uname),Darwin)
	PLATFORM := macOS
else
	PLATFORM := Linux
endif

ifeq ($(PLATFORM),Windows)
	override INK_RELEASE_ZIP_URL := https://github.com/inkle/ink/releases/download/v.1.2.0/inklecate_windows.zip
	override INK_BINARY := ./ink/inklecate.exe
	override LOVE_BINARY := lovec
else ifeq ($(PLATFORM),macOS)
	override INK_RELEASE_ZIP_URL := https://github.com/inkle/ink/releases/download/v.1.2.0/inklecate_mac.zip
	override INK_BINARY := ./ink/inklecate
	override LOVE_BINARY := love
else
	override INK_RELEASE_ZIP_URL := https://github.com/inkle/ink/releases/download/v.1.2.0/inklecate_linux.zip
	override INK_BINARY := ./ink/inklecate
	override LOVE_BINARY := love
endif

INK_INPUT_SOURCES = $(wildcard tests/simple/*.ink) $(wildcard tests/automatic/*.ink) $(wildcard tests/manual/*.ink)
INK_OUTPUT_JSON = $(INK_INPUT_SOURCES:%.ink=%.json)

ink.zip:
	curl -L $(INK_RELEASE_ZIP_URL) -o ink.zip

$(INK_BINARY): ink.zip
	mkdir -p ink
	cd ink && unzip -o ../ink.zip
	touch $(INK_BINARY)

%.json: %.ink $(INK_BINARY)
	$(INK_BINARY) -j -o $@ $<
	touch $@

%.json: %.ink $(INK_BINARY)
	$(INK_BINARY) -j -o $@ $<
	touch $@

%.json: %.ink $(INK_BINARY)
	$(INK_BINARY) -j -o $@ $<
	touch $@

all: $(INK_OUTPUT_JSON)

clean:
	rm -fr ./ink
	rm -f ./tests/simple/*.json
	rm -f ./tests/automatic/*.json
	rm -f ./tests/manual/*.json

.PHONY: all
