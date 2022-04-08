.PHONY: all table1 table2 table3 table4 table5 table6
all: table1 table2 table3 table4 table5 table6

table1:
	make -C benchmarks/nw/futhark all
	make -C benchmarks/nw/reference results.json
	tools/result-table.py benchmarks/nw

table2:
	make -C benchmarks/lud/futhark all
	make -C benchmarks/lud/reference results.json
	tools/result-table.py benchmarks/lud

table3:
	make -C benchmarks/hotspot/futhark all
	make -C benchmarks/hotspot/reference results.json
	tools/result-table.py benchmarks/hotspot

table4:
	make -C benchmarks/lbm/futhark all
	make -C benchmarks/lbm/reference results.json
	tools/result-table.py benchmarks/lbm

table5:
	make -C benchmarks/OptionPricing/futhark all
	make -C benchmarks/OptionPricing/reference results.json
	tools/result-table.py benchmarks/OptionPricing

table6:
	make -C benchmarks/LocVolCalib/futhark all
	make -C benchmarks/LocVolCalib/reference results.json
	tools/result-table.py benchmarks/LocVolCalib


.PHONY: clean
clean:
	make -C benchmarks/nw/futhark clean
	make -C benchmarks/nw/reference clean

	make -C benchmarks/lud/futhark clean
	make -C benchmarks/lud/reference clean

	make -C benchmarks/hotspot/futhark clean
	make -C benchmarks/hotspot/reference clean

	make -C benchmarks/lbm/futhark clean
	make -C benchmarks/lbm/reference clean

	make -C benchmarks/OptionPricing/futhark clean
	make -C benchmarks/OptionPricing/reference clean

	make -C benchmarks/LocVolCalib/futhark clean
	make -C benchmarks/LocVolCalib/reference clean
