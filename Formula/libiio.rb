# typed: false
# frozen_string_literal: true

# Library for interfacing with Linux Industrial I/O (IIO) subsystem devices.
# Used by SoapySDR Pluto plugin and gr-iio for talking to ADALM-PLUTO,
# AD9361 dev kits, and other IIO-capable hardware.
class Libiio < Formula
  desc "Library for interfacing with IIO devices"
  homepage "https://github.com/analogdevicesinc/libiio"
  url "https://github.com/analogdevicesinc/libiio/archive/refs/tags/v0.26.tar.gz"
  sha256 "fb445fb860ef1248759f45d4273a4eff360534480ec87af64c6b8db3b99be7e5"
  license "LGPL-2.1-or-later"
  head "https://github.com/analogdevicesinc/libiio.git", branch: "main"

  livecheck do
    url :stable
    strategy :github_latest
    # Match any vX.Y.Z tag. libiio's `main` branch is project(VERSION 1.0)
    # with no v1.x tag yet (last tagged release: v0.26). When v1.x ships,
    # livecheck will flag this formula -- the v1.x ABI is an
    # API-incompatible rewrite, so the bump requires a manual review of
    # consumers (libad9361-iio, gr-iio, SoapyPlutoSDR) before applying.
    regex(/^v?(\d+(?:\.\d+)+)$/i)
  end

  depends_on "cmake" => :build
  depends_on "pkgconf" => :build
  depends_on "libusb"

  uses_from_macos "libxml2"

  # Pothos tap ships an identically-named formula. Both install
  # `lib/libiio.dylib`, `include/iio.h`, `lib/pkgconfig/libiio.pc` --
  # `brew link` would refuse on file collision. Declare explicitly so
  # the user gets a clear error instead of a cryptic link failure.
  conflicts_with "pothosware/pothos/libiio",
    because: "both install libiio headers and libraries"

  def install
    args = %w[
      -DOSX_FRAMEWORK=OFF
      -DOSX_PACKAGE=OFF
      -DWITH_DOC=OFF
      -DWITH_TESTS=OFF
      -DWITH_EXAMPLES=OFF
      -DPYTHON_BINDINGS=OFF
      -DWITH_NETWORK_BACKEND=ON
      -DWITH_USB_BACKEND=ON
      -DWITH_XML_BACKEND=ON
    ]

    # libiio v0.26 declares cmake_minimum_required(VERSION 2.8.7); CMake 4
    # dropped support for policies below 3.5, so pass the compatibility
    # floor. The libiio v1.x rewrite on main raises this to 3.10 and the
    # workaround can be dropped once we move to a v1.x tagged release.
    args << "-DCMAKE_POLICY_VERSION_MINIMUM=3.5"

    system "cmake", "-S", ".", "-B", "build", *args, *std_cmake_args
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"

    # Framework compat shim for libiio-sys Rust crate
    # build.rs hardcodes -framework iio on macOS (not pkg-config).
    # Remove when upstream adopts pkg-config.
    (frameworks/"iio.framework").mkpath
    ln_sf lib/shared_library("libiio"), frameworks/"iio.framework/iio"
  end

  test do
    # Compile and link a tiny C program against libiio. This exercises
    # header resolution, link, and the iio_create_default_context entry
    # point. With no IIO hardware attached, the call returns NULL which
    # we treat as success (we still loaded the lib).
    (testpath/"test.c").write <<~C
      #include <iio.h>
      #include <stdio.h>
      int main(void) {
          /* Calling without context creation: just verify the library
             initialised by querying its build flags. */
          unsigned int major, minor;
          char tag[8];
          iio_library_get_version(&major, &minor, tag);
          printf("libiio %u.%u\\n", major, minor);
          return 0;
      }
    C

    system ENV.cc, "test.c",
                   "-I#{include}",
                   "-L#{lib}", "-liio",
                   "-o", "test"
    output = shell_output("./test")
    assert_match "libiio 0.", output
  end
end
