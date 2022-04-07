outputs/tables.pdf: outputs/tables.tex outputs/table1.tex outputs/table2.tex outputs/table3.tex outputs/table4.tex outputs/table5.tex outputs/table6.tex
	cd outputs && pdflatex $@

outputs/table1.tex:
	make -C benchmarks/nw/futhark all
	make -C benchmarks/nw/reference results.json
	tools/result-table.py benchmarks/nw > $@

outputs/table2.tex:
	make -C benchmarks/lud/futhark all
	make -C benchmarks/lud/reference results.json
	tools/result-table.py benchmarks/lud > $@

outputs/table3.tex:
	make -C benchmarks/hotspot/futhark all
	make -C benchmarks/hotspot/reference results.json
	tools/result-table.py benchmarks/hotspot > $@

outputs/table4.tex:
	make -C benchmarks/lbm/futhark all
	make -C benchmarks/lbm/reference results.json
	tools/result-table.py benchmarks/lbm > $@

outputs/table5.tex:
	make -C benchmarks/OptionPricing/futhark all
	make -C benchmarks/OptionPricing/reference results.json
	tools/result-table.py benchmarks/OptionPricing > $@

outputs/table6.tex:
	make -C benchmarks/LocVolCalib/futhark all
	make -C benchmarks/LocVolCalib/reference results.json
	tools/result-table.py benchmarks/LocVolCalib > $@


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
