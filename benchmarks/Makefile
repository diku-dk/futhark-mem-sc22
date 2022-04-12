.PHONY: help all table1 table2 table3 table4 table5 table6

help:
	@echo "futhark-mem-sc22 benchmarks"
	@echo "---------------------------"
	@echo
	@echo 'Targets:'
	@echo '  `make tables` - Compile and run all benchmarks to reproduce tables from the paper'.
	@echo '  `make table1` - Compile and run NW benchmarks'
	@echo '  `make table2` - Compile and run LUD benchmarks'
	@echo '  `make table3` - Compile and run Hotspot benchmarks'
	@echo '  `make table4` - Compile and run LBM benchmarks'
	@echo '  `make table5` - Compile and run OptionPricing benchmarks'
	@echo '  `make table6` - Compile and run LocVolCalib benchmarks'
	@echo
	@echo '  `make clean`  - Cleanup all cached results'
	@echo '  `make help`   - Show help information.'
	@echo
	@echo 'For all targets, you can specify a different version of `futhark` by setting `FUTHARK=my-futhark`.'
	@echo 'Similarly, you can specify how many executions of each benchmark you want to use with e.g. `RUNS=10`.'

tables: table1 table2 table3 table4 table5 table6
	./result-table.py nw
	./result-table.py lud
	./result-table.py hotspot
	./result-table.py lbm
	./result-table.py OptionPricing
	./result-table.py LocVolCalib

table1:
	make -C nw/futhark all
	make -C nw/reference results.json
	./result-table.py nw

table2:
	make -C lud/futhark all
	make -C lud/reference results.json
	./result-table.py lud

table3:
	make -C hotspot/futhark all
	make -C hotspot/reference results.json
	./result-table.py hotspot

table4:
	make -C lbm/futhark all
	make -C lbm/reference results.json
	./result-table.py lbm

table5:
	make -C OptionPricing/futhark all
	make -C OptionPricing/reference results.json
	./result-table.py OptionPricing

table6:
	make -C LocVolCalib/futhark all
	make -C LocVolCalib/reference results.json
	./result-table.py LocVolCalib

.PHONY: clean
clean:
	make -C nw/futhark clean
	make -C nw/reference clean

	make -C lud/futhark clean
	make -C lud/reference clean

	make -C hotspot/futhark clean
	make -C hotspot/reference clean

	make -C lbm/futhark clean
	make -C lbm/reference clean

	make -C OptionPricing/futhark clean
	make -C OptionPricing/reference clean

	make -C LocVolCalib/futhark clean
	make -C LocVolCalib/reference clean
