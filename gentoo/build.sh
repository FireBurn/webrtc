#!/bin/bash
# Build libwebrtc.a for Linux with clang and the system's C++ library, and
# lay it out the way livekit's webrtc-sys expects (LK_CUSTOM_WEBRTC).
#   build.sh <src> <destination> [clang prefix]
set -euo pipefail
src=$(cd "${1:?usage: build.sh <src> <destination> [clang-prefix]}" && pwd)
dest=$(realpath -m "${2:?destination}")
clang_base=${3:-/usr}
here=$(cd "$(dirname "$0")" && pwd)
out=${src}/out/gentoo
arch=${GENTOO_WEBRTC_ARCH:-x64}

mkdir -p "${out}" "${dest}/lib"
cat > "${out}/args.gn" <<EOF
is_debug = false
target_os = "linux"
target_cpu = "${arch}"
is_clang = true
clang_base_path = "${clang_base}"
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
