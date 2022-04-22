CC = g++

SRC = nearestNeighbor.cpp clutils.cpp utils.cpp

CC_FLAGS = -g -O3

EXE = nn

RUNS ?= 10

results.json: nn
	RODINIA_RUNS=$(RUNS) RODINIA_REPEAT_DATA=20 ./nn filelist.txt -r 100 -lat 30 -lng 90 -p 0 -d 0 \
	  | jq -nR '{"100i64 30.0f32 90.0f32 [855280]f32 [855280]f32": { "runtimes": [inputs | select(length>0) | tonumber]}}' \
	  > $@

	RODINIA_RUNS=$(RUNS) RODINIA_REPEAT_DATA=200 ./nn filelist.txt -r 100 -lat 30 -lng 90 -p 0 -d 0 \
	  | jq -nR '{"100i64 30.0f32 90.0f32 [8552800]f32 [8552800]f32": { "runtimes": [inputs | select(length>0) | tonumber]}}' \
	  | jq -s '.[0] + .[1]' - $@ \
	  | sponge $@


nn: $(SRC)
	$(CC) $(CC_FLAGS) -lOpenCL  -fopenmp $(SRC) -o $(EXE)

clean:
	rm -f nn results.json
