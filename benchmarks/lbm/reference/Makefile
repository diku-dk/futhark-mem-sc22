RUNS ?= 100

EXTERNALS_DIR = ../../../externals
PARBOIL_DIR = $(EXTERNALS_DIR)/parboil

results.json:
	cd $(PARBOIL_DIR)

	for i in $(shell seq 0 $(RUNS)); do (cd $(PARBOIL_DIR); ./parboil run lbm opencl_nvidia short); done \
	  | grep "Kernel  " \
	  | tail -n +2 \
	  | cut -d: -f2 \
	  | jq -nR '{"data/short.data": { "runtimes": [inputs | select(length>0) | tonumber | . * 1000000]}}' \
	  > $@

	for i in $(shell seq 0 $(RUNS)); do (cd $(PARBOIL_DIR); ./parboil run lbm opencl_nvidia long); done \
	  | grep "Kernel  " \
	  | tail -n +2 \
	  | cut -d: -f2 \
	  | jq -nR '{"data/long.data": { "runtimes": [inputs | select(length>0) | tonumber | . * 1000000]}}' \
	  | jq -s '.[0] + .[1]' - $@ \
	  | sponge $@

clean:
	rm -f results.json
