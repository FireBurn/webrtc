#!/bin/bash
# Build libwebrtc.a for Linux with clang and the system's C++ library, and
# lay it out the way livekit's webrtc-sys expects (LK_CUSTOM_WEBRTC).
#   build.sh <src> <destination>
set -euo pipefail
src=$(cd "${1:?usage: build.sh <src> <destination>}" && pwd)
dest=$(realpath -m "${2:?destination}")
clang=$(command -v "${CC:-clang}")
here=$(cd "$(dirname "$0")" && pwd)
out=${src}/out/gentoo
arch=${GENTOO_WEBRTC_ARCH:-x64}

mkdir -p "${out}" "${dest}/lib"

# gn looks for clang's runtime under <prefix>/lib/clang/<major>/lib/<triple>,
# which is not where a distribution puts it, so a prefix of links is made
resource=$("${clang}" --print-resource-dir)
major=$("${clang}" -dumpversion | cut -d. -f1)
clang_base=${out}/clang
triple_dir=${clang_base}/lib/clang/${major}/lib/x86_64-unknown-linux-gnu
rm -rf "${clang_base}"
mkdir -p "${triple_dir}"
ln -s "$(dirname "$(readlink -f "${clang}")")" "${clang_base}/bin"
ln -s "${resource}/include" "${clang_base}/lib/clang/${major}/include"
ln -s "$(find "${resource}/lib" -name 'libclang_rt.builtins-x86_64.a' | head -1)" \
	"${triple_dir}/libclang_rt.builtins.a"
cat > "${out}/args.gn" <<EOF
is_debug = false
target_os = "linux"
target_cpu = "${arch}"
is_clang = true
clang_base_path = "${clang_base}"
clang_version = "${major}"
clang_use_chrome_plugins = false
use_lld = true
use_sysroot = false
use_custom_libcxx = false
use_custom_libcxx_for_host = false
use_llvm_libatomic = false
use_libcxx_modules = false
use_rtti = true
treat_warnings_as_errors = false
is_component_build = false
rtc_include_tests = false
rtc_build_tools = false
rtc_build_examples = false
rtc_enable_protobuf = false
rtc_use_h264 = true
rtc_use_h265 = true
rtc_use_pipewire = true
rtc_use_x11 = true
rtc_libvpx_build_vp9 = true
enable_libaom = true
ffmpeg_branding = "Chrome"
symbol_level = 0
enable_iterator_debugging = false
enable_rust = false
EOF

cd "${src}"
gn gen "${out}"
ninja -C "${out}" :default

find "${out}/obj" -name '*.o' -not -path '*/third_party/nasm/*' > "${out}/objects.txt"
rm -f "${dest}/lib/libwebrtc.a"
llvm-ar rcs "${dest}/lib/libwebrtc.a" "@${out}/objects.txt"
llvm-objcopy --redefine-syms="${here}/boringssl_prefix_symbols.txt" "${dest}/lib/libwebrtc.a"

cp "${out}/obj/webrtc.ninja" "${out}/obj/modules/desktop_capture/desktop_capture.ninja" \
	"${out}/args.gn" "${dest}/"
cp "${src}/LICENSE" "${dest}/LICENSE.md"
find . -path ./out -prune -o \( -name '*.h' -o -name '*.inc' \) -print |
	cpio -pdm "${dest}/include"
