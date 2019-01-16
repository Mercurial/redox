build/libkernel.a: kernel/Cargo.lock kernel/Cargo.toml kernel/src/* kernel/src/*/* kernel/src/*/*/* kernel/src/*/*/*/* build/initfs.tag
	export PATH="$(PREFIX_PATH):$$PATH" && \
	export INITFS_FOLDER=$(ROOT)/build/initfs && \
	cd kernel && \
	xargo rustc --lib --target $(KTARGET) --release -- -C soft-float -C debuginfo=2 --emit link=../$@

build/libkernel_live.a: kernel/Cargo.toml kernel/src/* kernel/src/*/* kernel/src/*/*/* kernel/src/*/*/*/* build/initfs_live.tag
	export PATH="$(PREFIX_PATH):$$PATH" && \
	export INITFS_FOLDER=$(ROOT)/build/initfs_live && \
	cd kernel && \
	xargo rustc --lib --target $(KTARGET) --release --features live -- -C soft-float -C debuginfo=2 --emit link=../$@

build/kernel: kernel/linkers/$(ARCH).ld build/libkernel.a
	export PATH="$(PREFIX_PATH):$$PATH" && \
	$(LD) --gc-sections -z max-page-size=0x1000 -T $< -o $@ build/libkernel.a && \
	$(OBJCOPY) --only-keep-debug $@ $@.sym && \
	$(OBJCOPY) --strip-debug $@

build/kernel_live: kernel/linkers/$(ARCH).ld build/libkernel_live.a build/live.o
	export PATH="$(PREFIX_PATH):$$PATH" && \
	$(LD) --gc-sections -z max-page-size=0x1000 -T $< -o $@ build/libkernel_live.a build/live.o && \
	$(OBJCOPY) --only-keep-debug $@ $@.sym && \
	$(OBJCOPY) --strip-debug $@
	$(MAKE) post_kbuild_platform_hook
