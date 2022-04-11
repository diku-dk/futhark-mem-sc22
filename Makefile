.PHONY: help
help:
	@echo 'futhark-mem-sc22 artifact'
	@echo '-------------------------'
	@echo
	@echo 'Targets:'
	@echo '  `make tables`      - Compile and run all benchmarks to reproduce tables from paper'
	@echo '                       For more info, use `make help` inside the `benchmarks` directory.'
	@echo '  `make bin/futhark` - Rebuild the futhark binary.'
	@echo '  `make cuda.tar.gz` - Build the docker container for CUDA (A100) execution.'
	@echo '  `make rocm.tar.gz` - Build the docker container for ROCM (MI100) execution.'
	@echo
	@echo '  `make clean`       - Cleanup cached results.'
	@echo '  `make help`        - Show help information.'

.PHONY: tables
tables:
	make -C benchmarks tables

bin/futhark:
	cd futhark && nix-build --argstr suffix short-circuiting
	mkdir -p bin
	tar --extract -C bin/ --strip-components 2 -f futhark/result/futhark-short-circuiting.tar.xz futhark-short-circuiting/bin/futhark

%.tar.gz: %.nix clean
	nix-build $< -o $@

.PHONY: clean
clean:
	make -C benchmarks clean
