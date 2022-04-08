.PHONY: all table1 table2 table3 table4 table5 table6
all: table1 table2 table3 table4 table5 table6

table1:
	make -C nw/futhark all
	make -C nw/reference results.json
	result-table.py nw

table2:
	make -C lud/futhark all
	make -C lud/reference results.json
	result-table.py lud

table3:
	make -C hotspot/futhark all
	make -C hotspot/reference results.json
	result-table.py hotspot

table4:
	make -C lbm/futhark all
	make -C lbm/reference results.json
	result-table.py lbm

table5:
	make -C OptionPricing/futhark all
	make -C OptionPricing/reference results.json
	result-table.py OptionPricing

table6:
	make -C LocVolCalib/futhark all
	make -C LocVolCalib/reference results.json
	result-table.py LocVolCalib

bin/futhark:
	cd futhark && nix-build --argstr suffix short-circuiting
	mkdir -p bin
	tar --extract -C bin/ --strip-components 2 -f futhark/result/futhark-short-circuiting.tar.xz futhark-short-circuiting/bin/futhark

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
