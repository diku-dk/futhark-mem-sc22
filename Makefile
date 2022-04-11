.PHONY: tables

tables:
	make -C benchmarks

bin/futhark:
	cd futhark && nix-build --argstr suffix short-circuiting
	mkdir -p bin
	tar --extract -C bin/ --strip-components 2 -f futhark/result/futhark-short-circuiting.tar.xz futhark-short-circuiting/bin/futhark

%.tar.gz: %.nix
	nix-build $< -o $@
