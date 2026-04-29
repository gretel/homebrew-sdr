# typed: false
# frozen_string_literal: true

# AD9361 IIO support library for Analog Devices PlutoSDR / ADALM-PLUTO
# and AD9361-based development boards. Layered on top of libiio.
class Libad9361Iio < Formula
  desc "IIO AD9361 library for Analog Devices PlutoSDR and ADALM-PLUTO"
  homepage "https://github.com/analogdevicesinc/libad9361-iio"
  url "https://github.com/analogdevicesinc/libad9361-iio/archive/refs/tags/v0.3.tar.gz"
  sha256 "1dc35dd997e1938a97489fa1f349ee16889f9de8901a2c7af46184468dc90598"
  license "LGPL-2.1-or-later"
  head "https://github.com/analogdevicesinc/libad9361-iio.git", branch: "main"

  livecheck do
    url :stable
    strategy :github_latest
    regex(/^v?(\d+(?:\.\d+)+)$/i)
  end

  depends_on "cmake" => :build
  depends_on "libiio"

  def install
    # libad9361-iio v0.3 hardcodes `FRAMEWORK TRUE` on the ad9361 target,
    # forcing a macOS framework bundle instead of the traditional
    # header+dylib install layout. Strip the property so headers land in
    # #{include} and the dylib lands in #{lib}. Homebrew-only build-system
    # patch -- not relevant upstream.
    inreplace "CMakeLists.txt", "\tFRAMEWORK TRUE\n", "" if OS.mac?

    # libad9361 v0.3 uses cmake_minimum_required(VERSION 2.8.12); CMake 4
    # dropped support for policies below 3.5, so pass the compatibility
    # floor. libiio is found via the Homebrew superenv CMAKE_PREFIX_PATH.
    args = %w[
      -DCMAKE_POLICY_VERSION_MINIMUM=3.5
      -DOSX_PACKAGE=OFF
      -DPYTHON_BINDINGS=OFF
    ]

    system "cmake", "-S", ".", "-B", "build", *args, *std_cmake_args
    # Build only the library target -- the test subdirectory has
    # hardware-only executables that fail to compile on macOS without
    # target hardware attached.
    system "cmake", "--build", "build", "--target", "ad9361"
    system "cmake", "--install", "build"
  end

  test do
    # Compile and link a tiny C program against libad9361. Exercises
    # header resolution, libiio + libad9361 link, and verifies the
    # ad9361 symbol table is accessible.
    (testpath/"test.c").write <<~C
      #include <iio.h>
      #include <ad9361.h>
      #include <stdio.h>
      /* Take the address of an ad9361 symbol so the linker pulls the
         library in. Runtime behaviour doesn't matter for the test --
         header resolution, link, and symbol lookup is what we verify. */
      int (*fn)(struct iio_device *, unsigned long) = &ad9361_set_bb_rate;
      int main(void) {
          (void)fn;
          printf("ad9361 ok\\n");
          return 0;
      }
    C

    system ENV.cc, "test.c",
                   "-I#{include}",
                   "-I#{Formula["libiio"].opt_include}",
                   "-L#{lib}", "-lad9361",
                   "-L#{Formula["libiio"].opt_lib}", "-liio",
                   "-o", "test"
    assert_equal "ad9361 ok", shell_output("./test").strip
  end
end
