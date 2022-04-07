CC = g++
CC_FLAGS = -g -O3 -Wall

RUNS ?= 10

results.json: lud
	./$< -s 8192 -r $(RUNS) \
	  | jq -nR '{"generate 8192i64": { "runtimes": [inputs | select(length>0) | tonumber]}}' \
	  > $@

	./$< -s 16384 -r $(RUNS) \
	  | jq -nR '{"generate 16384i64": { "runtimes": [inputs | select(length>0) | tonumber]}}' \
	  | jq -s '.[0] + .[1]' - $@ \
	  | sponge $@

	./$< -s 32768 -r $(RUNS) \
	  | jq -nR '{"generate 32768i64": { "runtimes": [inputs | select(length>0) | tonumber]}}' \
	  | jq -s '.[0] + .[1]' - $@ \
	  | sponge $@

lud: lud.cpp common.c common.h
	$(CC) $(CC_FLAGS) -o $@ lud.cpp common.c -lOpenCL

clean:
	rm -f lud results.json
