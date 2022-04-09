FUTHARK ?= ../../../bin/futhark
RUNS ?= 10

BENCHMARK ?= hotspot.fut

EXTRA_DEPS =

OUTPUTS = plain.json optimized.json

.PHONY: all
all: $(OUTPUTS)

plain.json: $(BENCHMARK) $(EXTRA_DEPS)
	$(FUTHARK) dev --gpu -a -e --cse -e --double-buffer -e --cse -e --expand-allocations -e --backend=opencl --server $<
	$(FUTHARK) bench --backend=opencl --skip-compilation --json $@ --runs $(RUNS) $<
	jq '."hotspot.fut".datasets | map_values(del(.stderr)) | map_values(.bytes |= .device)' $@ \
	  | sponge $@

optimized.json: $(BENCHMARK) $(EXTRA_DEPS)
	$(FUTHARK) dev --gpu -a -e --cse -e --double-buffer -e --cse --lift-allocations-gpu -e --short-circuit-gpu -e --cse -e --lower-allocations-gpu --cse -e --memory-block-merging -e --expand-allocations -e --backend=opencl --server $<
	$(FUTHARK) bench --backend=opencl --skip-compilation --json $@ --runs $(RUNS) $<
	jq '."hotspot.fut".datasets | map_values(del(.stderr)) | map_values(.bytes |= .device)' $@ \
	  | sponge $@
clean:
	rm -f $(OUTPUTS) hotspot hotspot.c
