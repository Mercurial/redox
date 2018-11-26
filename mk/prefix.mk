PREFIX=$(ROOT)/prefix/$(TARGET)

PREFIX_BINUTILS_PATH:=$(PREFIX)/binutils-install/bin
PREFIX_FREESTANDING_PATH:=$(PREFIX)/gcc-freestanding-install/bin:$(PREFIX_BINUTILS_PATH)
PREFIX_PATH:=$(PREFIX)/gcc-install/bin:$(PREFIX_BINUTILS_PATH)

PREFIX_FREESTANDING_TARGETS=\
	$(PREFIX)/binutils-install \
	$(PREFIX)/gcc-freestanding-install

PREFIX_TARGETS=\
	$(PREFIX)/binutils-install \
	$(PREFIX)/gcc-install

ifeq ($(PREFIX_RUSTC),1)

PREFIX_FREESTANDING_PATH:=$(PREFIX)/rust-freestanding-install/bin:$(PREFIX_FREESTANDING_PATH)

PREFIX_PATH:=$(PREFIX)/rust-freestanding-install/bin:$(PREFIX_PATH)

PREFIX_FREESTANDING_TARGETS+=$(PREFIX)/rust-freestanding-install

PREFIX_TARGETS+=$(PREFIX)/rust-freestanding-install

export RUSTUP_TOOLCHAIN=$(PREFIX)/rust-freestanding-install

endif

prefix-freestanding: $(PREFIX_FREESTANDING_TARGETS)

prefix: $(PREFIX_TARGETS)

$(PREFIX)/binutils.tar.bz2:
	mkdir -p "$(@D)"
	wget -O $@.partial "https://gitlab.redox-os.org/redox-os/binutils-gdb/-/archive/master/binutils-gdb-master.tar.bz2"
	mv $@.partial $@

$(PREFIX)/binutils: $(PREFIX)/binutils.tar.bz2
	mkdir -p "$@.partial"
	tar --extract --file "$<" --directory "$@.partial" --strip-components=1
	mv "$@.partial" "$@"
	touch "$@"

$(PREFIX)/binutils-install: $(PREFIX)/binutils
	rm -rf "$<-build" "$@"
	mkdir -p "$<-build" "$@"
	cd "$<-build" && \
	"$</configure" --target="$(TARGET)" --disable-werror --prefix="$@" && \
	make all -j `nproc` && \
	make install -j `nproc`
	touch "$@"

$(PREFIX)/gcc.tar.bz2:
	mkdir -p "$(@D)"
	wget -O $@.partial "https://gitlab.redox-os.org/redox-os/gcc/-/archive/redox/gcc-redox.tar.bz2"
	mv "$@.partial" "$@"

$(PREFIX)/gcc: $(PREFIX)/gcc.tar.bz2
	mkdir -p "$@.partial"
	tar --extract --file "$<" --directory "$@.partial" --strip-components=1
	cd "$@.partial" && ./contrib/download_prerequisites
	mv "$@.partial" "$@"
	touch "$@"

$(PREFIX)/gcc-freestanding-install: $(PREFIX)/gcc | $(PREFIX)/binutils-install
	rm -rf "$<-freestanding-build" "$@"
	mkdir -p "$<-freestanding-build" "$@"
	cd "$<-freestanding-build" && \
	export PATH="$(PREFIX_BINUTILS_PATH):$$PATH" && \
	"$</configure" --target="$(TARGET)" --prefix="$@" --disable-nls --enable-languages=c,c++ --without-headers && \
	make all-gcc -j `nproc` && \
	make all-target-libgcc -j `nproc` && \
	make install-gcc -j `nproc` && \
	make install-target-libgcc -j `nproc`
	touch "$@"

$(PREFIX)/rust-freestanding-install: $(ROOT)/rust
	rm -rf "$(PREFIX)/rust-freestanding-build" "$@"
	mkdir -p "$(PREFIX)/rust-freestanding-build" "$@"
	cd "$(PREFIX)/rust-freestanding-build" && \
	"$</configure" --prefix="$@" --disable-docs && \
	make -j `nproc` && \
	make install -j `nproc`
	touch "$@"

$(PREFIX)/relibc-install: $(ROOT)/relibc | $(PREFIX_FREESTANDING_TARGETS)
	rm -rf "$@"
	cd "$<" && \
	export PATH="$(PREFIX_FREESTANDING_PATH):$$PATH" && \
	make CARGO=xargo all && \
	make CARGO=xargo DESTDIR="$@/usr" install
	touch "$@"

$(PREFIX)/gcc-install: $(PREFIX)/gcc | $(PREFIX)/relibc-install
	rm -rf "$<-build" "$@"
	mkdir -p "$<-build" "$@"
	cd "$<-build" && \
	export PATH="$(PREFIX_FREESTANDING_PATH):$$PATH" && \
	"$</configure" --target="$(TARGET)" --disable-werror --prefix="$@" --with-sysroot="$(PREFIX)/relibc-install" --disable-nls --enable-languages=c,c++ && \
	make all-gcc -j `nproc` && \
	make all-target-libgcc -j `nproc` && \
	make install-gcc -j `nproc` && \
	make install-target-libgcc -j `nproc` && \
	make all-target-libstdc++-v3 -j `nproc` && \
	make install-target-libstdc++-v3 -j `nproc`
	touch "$@"

# Building full rustc may not be required
# $(PREFIX)/rust-install: $(ROOT)/rust | $(PREFIX)/gcc-install
# 	rm -rf "$(PREFIX)/rust-build" "$@"
# 	mkdir -p "$(PREFIX)/rust-build" "$@"
# 	cd "$(PREFIX)/rust-build" && \
# 	export PATH="$(PREFIX_PATH):$$PATH" && \
# 	export AR_$(subst -,_,$(TARGET))="$(TARGET)-ar" && \
# 	export CC_$(subst -,_,$(TARGET))="$(TARGET)-gcc" && \
# 	export CXX_$(subst -,_,$(TARGET))="$(TARGET)-g++" && \
# 	"$</configure" --target="$(TARGET)" --prefix="$@" --disable-docs && \
# 	make -j `nproc` && \
# 	make install -j `nproc`
# 	touch "$@"
