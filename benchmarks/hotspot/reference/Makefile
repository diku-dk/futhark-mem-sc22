CC = gcc
CC_FLAGS = -g -O3 -Wall -std=c99

RUNS ?= 10

results.json: hotspot
	./$< 8192 2 10 10 \
	  | jq -nR '{"10i32 [8192][8192]f32 [8192][8192]f32": { "runtimes": [inputs | select(length>0) | tonumber]}}' \
	  > $@

	./$< 16384 2 10 10 \
	  | jq -nR '{"10i32 [16384][16384]f32 [16384][16384]f32": { "runtimes": [inputs | select(length>0) | tonumber]}}' \
	  | jq -s '.[0] + .[1]' - $@ \
	  | sponge $@

	./$< 32768 2 10 10 \
	  | jq -nR '{"10i32 [32768][32768]f32 [32768][32768]f32": { "runtimes": [inputs | select(length>0) | tonumber]}}' \
	  | jq -s '.[0] + .[1]' - $@ \
	  | sponge $@

hotspot: hotspot.c hotspot_kernel.cl common.h
	$(CC) $(CC_FLAGS) -o $@ $< -lm -lOpenCL

clean:
	rm -f hotspot results.json
