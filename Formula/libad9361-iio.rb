# typed: false
# frozen_string_literal: true

# AD9361 IIO support library for Analog Devices PlutoSDR / ADALM-PLUTO
# and AD9361-based development boards. Layered on top of libiio.
class Libad9361Iio < Formula
  desc "IIO AD9361 library for Analog Devices PlutoSDR and ADALM-PLUTO"
  homepage "https://github.com/analogdevicesinc/libad9361-iio"
  url "https://github.com/analogdevicesinc/libad9361-iio/archive/refs/tags/v0.4.0.tar.gz"
  sha256 "f4976a1317a0b7cf84727d068be5a52c070539ca7301f0160b0677a429538d87"
  license "LGPL-2.1-or-later"
  head "https://github.com/analogdevicesinc/libad9361-iio.git", branch: "main"

  livecheck do
    url :stable
    strategy :github_latest
    regex(/^v?(\d+(?:\.\d+)+)$/i)
  end

  depends_on "cmake" => :build
  depends_on "libiio"

  # Pothos tap ships an identically-named formula. Both install
  # `lib/libad9361.dylib`, `include/ad9361.h`, and the matching .pc --
  # `brew link` would refuse on file collision. Declare explicitly so
  # the user gets a clear error instead of a cryptic link failure.
  conflicts_with "pothosware/pothos/libad9361-iio",
    because: "both install libad9361 headers and libraries"

  def install
    # libad9361 v0.4.0 uses option(OSX_FRAMEWORK ON), defaulting to a macOS
    # framework bundle. Pass OFF so headers land in #{include} and the dylib
    # lands in #{lib}. cmake_minimum_raised to VERSION 3.5.0 so no CMake 4
    # compat floor needed.
    args = %w[
      -DOSX_FRAMEWORK=OFF
      -DOSX_PACKAGE=OFF
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
