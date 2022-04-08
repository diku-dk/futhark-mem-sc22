CFLAGS?=-O3
LDFLAGS?=-lOpenCL -lm

RUNS ?= 100

results.json: lbm
	for i in $(shell seq 0 $(RUNS)); do ./lbm 100 -o out -i 120_120_150_ldc.of; done \
	  | grep "Kernel  " \
	  | tail -n +2 \
	  | cut -d: -f2 \
	  | jq -nR '{"data/short.data": { "runtimes": [inputs | select(length>0) | tonumber | . * 1000000]}}' \
	  > $@

	for i in $(shell seq 0 $(RUNS)); do ./lbm 3000 -o out -i 120_120_150_ldc.of; done \
	  | grep "Kernel  " \
	  | tail -n +2 \
	  | cut -d: -f2 \
	  | jq -nR '{"data/long.data": { "runtimes": [inputs | select(length>0) | tonumber | . * 1000000]}}' \
	  | jq -s '.[0] + .[1]' - $@ \
	  | sponge $@

lbm: main.c lbm.c ocl.c parboil_opencl.c
	gcc -o $@ $^ $(CFLAGS) $(LDFLAGS)

clean:
	rm -f results.json lbm out
