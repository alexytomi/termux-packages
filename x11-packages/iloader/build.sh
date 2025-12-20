TERMUX_PKG_HOMEPAGE=https://github.com/nab138/iloader
TERMUX_PKG_DESCRIPTION="User friendly sideloader. Install SideStore (or other apps) and import your pairing file with ease"
TERMUX_PKG_LICENSE="MIT"
TERMUX_PKG_MAINTAINER="@termux"
TERMUX_PKG_VERSION="1.1.5"
TERMUX_PKG_REVISION=1
TERMUX_PKG_SRCURL=git+https://github.com/nab138/iloader.git
TERMUX_PKG_DEPENDS="webkit2gtk-4.1, usbmuxd"
TERMUX_PKG_RECOMMENDS="usbmuxd" # Reccomends because this is in root repository so it can't be essential. TODO: Make essential.

termux_step_make() {
	termux_setup_rust
	termux_setup_nodejs
	cd $TERMUX_PKG_SRCDIR/src-tauri
	cargo clean
	cargo vendor vendor/
	echo "" >> Cargo.toml
	echo '[patch.crates-io]' >> Cargo.toml

	crates_to_patch=(
		softbuffer
		tao
		tauri-macros
		tauri-plugin-dialog
		tauri-plugin-fs
		tauri-plugin-opener
		tauri-runtime-wry
		tauri-runtime
		tauri-utils
		tauri
		tauri-plugin
		wry
		muda
		rfd
	)
	# # If there is an issue with the automated patching, uncomment these to make it save the patches in src-tauri/patches
	# git add -A && git commit -m "add vendored folders" && git tag -d unpatched
	# git tag unpatched
	for crate in "${crates_to_patch[@]}"; do
			echo "termuxifying '$crate'..."
			find "vendor/$crate" -type f | \
					xargs -n 1 sed -i \
					-e 's|"android"|"disabling_this_because_it_is_for_building_an_apk"|g' \
					-e 's|"linux"|"android"|g' \
					-e "s|libxkbcommon.so.0|libxkbcommon.so|g" \
					-e "s|libxkbcommon-x11.so.0|libxkbcommon-x11.so|g" \
					-e "s|libxcb.so.1|libxcb.so|g" \
					-e "s|/tmp|$TERMUX_PREFIX/tmp|g"

			echo "$crate = { path = \"./vendor/$crate\" }" >> Cargo.toml
			# git add -A && git commit -m "automated termux patch for $crate"
	done
	# git format-patch unpatched -o patches
	npm install && npm run build # Generate dist folder

	cd $TERMUX_PKG_SRCDIR/src-tauri/vendor # Apply patch that allows arm and i686 to successfully build
	patch -N -p1 -i $TERMUX_PKG_BUILDER_DIR/0001-Fix-failure-to-compile-to-32-bit.diff
	cd $TERMUX_PKG_SRCDIR/src-tauri
	echo "idevice = { path = \"./vendor/idevice\" }" >> Cargo.toml


	export OPENSSL_NO_VENDOR=1 # OpenSSL doesn't declare ERR_print_error_fp without this which is used by zsign-rust
	cargo build --bins --features tauri/custom-protocol --release --target $CARGO_TARGET_NAME
}

termux_step_make_install() {
	install -Dm700 -t $TERMUX_PREFIX/bin $TERMUX_PKG_SRCDIR/src-tauri/target/$CARGO_TARGET_NAME/release/iloader
}
