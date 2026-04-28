# typed: false
# frozen_string_literal: true

# UHD with the AD9361 overclock patch from MothMaux/uhd-oc.
# Raises AD9361_MAX_CLOCK_RATE from 61.44 MS/s to 122.88 MS/s.
# Host-side only -- no FPGA or firmware changes.
#
# This formula is a downstream fork-by-patch of homebrew-core's `uhd`.
# It is intentionally NOT eligible for homebrew-core (Homebrew rejects
# parallel patched versions of existing core formulae). Conflicts with
# the stock `uhd` formula -- you must `brew uninstall uhd` before
# installing `uhd-oc`.
class UhdOc < Formula
  include Language::Python::Virtualenv

  desc "UHD with AD9361 overclock patch (122.88 MS/s)"
  homepage "https://files.ettus.com/manual/"
  url "https://github.com/EttusResearch/uhd/archive/refs/tags/v4.10.0.0.tar.gz"
  sha256 "a9c66b52abcd586b513999f3a52345807b7551d01efac8c98eed813838be0297"
  license all_of: [
    "GPL-3.0-or-later",
    "LGPL-3.0-or-later",
    "MIT",
    "BSD-3-Clause",
    "Apache-2.0",
  ]
  compatibility_version 1
  head "https://github.com/EttusResearch/uhd.git", branch: "master"

  livecheck do
    url :stable
    strategy :github_latest
  end

  depends_on "cmake" => :build
  depends_on "doxygen" => :build
  depends_on "pkgconf" => :build
  depends_on "boost"
  depends_on "libusb"
  depends_on "python@3.14"

  on_linux do
    depends_on "ncurses"
  end

  conflicts_with "uhd",
    because: "both install libuhd, uhd_usrp_probe, and the same UHD headers"

  pypi_packages package_name:   "",
                extra_packages: "mako"

  resource "mako" do
    url "https://files.pythonhosted.org/packages/59/8a/805404d0c0b9f3d7a326475ca008db57aea9c5c9f2e1e39ed0faa335571c/mako-1.3.11.tar.gz"
    sha256 "071eb4ab4c5010443152255d77db7faa6ce5916f35226eb02dc34479b6858069"
  end

  resource "markupsafe" do
    url "https://files.pythonhosted.org/packages/7e/99/7690b6d4034fffd95959cbe0c02de8deb3098cc577c67bb6a24fe5d7caa7/markupsafe-3.0.3.tar.gz"
    sha256 "722695808f4b6457b320fdc131280796bdceb04ab50fe1795cd540799ebe1698"
  end

  # setuptools is not bundled in python's ensurepip (PEP 632 removed it
  # from default venvs starting in 3.12), but UHD's host/python/CMakeLists.txt
  # invokes `python setup.py -q build` directly (no PEP 517 isolation),
  # which imports setuptools at parse time. Stock homebrew-core `uhd` gets
  # away with this because it pours from a CI-built bottle whose build
  # environment happens to have setuptools in scope; source builds need
  # setuptools in the venv explicitly.
  resource "setuptools" do
    url "https://files.pythonhosted.org/packages/4f/db/cfac1baf10650ab4d1c111714410d2fbb77ac5a616db26775db562c8fab2/setuptools-82.0.1.tar.gz"
    sha256 "7d872682c5d01cfde07da7bccc7b65469d3dca203318515ada1de5eda35efbf9"
  end

  # AD9361 overclock patch -- raises AD9361_MAX_CLOCK_RATE from 61.44 MS/s
  # to 122.88 MS/s, adds new sample-rate brackets, and bypasses the FIR
  # filters above 70 MS/s. Host-side only (single file: ad9361_device.cpp).
  #
  # Source:    https://github.com/MothMaux/uhd-oc (master @ 4c3086d, 5 cpp commits)
  #            771b74f Overclock allow
  #            c048216 FIR Filter fix      (rxfilt 11001100, rfir_factor=0)
  #            3480b60 Timing change removed (drop WIP +0x22 margin)
  #            f2af59b 104e6-122.88e6 Samplerates Fix (poke8 0x006 timing)
  #            4d276ea whoopsies           (missing semicolons)
  # Canonical: gr4-lora/docs/ad9361-overclock.patch
  # Risks:     no FIR filtering above 70 MS/s, ADC rates >100 MS/s outside
  #            AD9361 spec, not validated by Analog Devices or Ettus.
  #            Reportedly stable up to ~100 MS/s; degraded above.
  patch :DATA

  def python3
    "python3.14"
  end

  def install
    # Boost 1.89+ compatibility -- mirror upstream `uhd` formula. The
    # `system` Boost component was renamed/removed; UHDConfig.cmake.in
    # still lists it, breaking find_package(Boost) consumers.
    inreplace "host/cmake/Modules/UHDConfig.cmake.in", /\s+system\n/, ""

    venv = virtualenv_create(buildpath/"venv", python3)
    venv.pip_install resources
    ENV.prepend_path "PYTHONPATH", venv.site_packages

    # UHD's host/lib/CMakeLists.txt adds `-flat_namespace` to libuhd
    # on APPLE (line ~228 in 4.10.0.0). This is an obsolete workaround
    # for a macOS linker quirk from the debian packaging era -- but today
    # it triggers `brew audit` warnings (flat-namespace libraries).
    # Remove the line so libuhd links with the default two-level
    # namespace. The accompanying `-undefined,dynamic_lookup` line is
    # also unnecessary for libuhd itself (it's a library, not an
    # extension module) but we leave it alone to minimise the diff.
    if OS.mac?
      inreplace "host/lib/CMakeLists.txt",
                "    target_link_options(uhd PRIVATE \"-flat_namespace\")\n",
                ""
    end

    # ENABLE_SIM=OFF: disable the MPMD software simulator. It pulls in
    # `host/python/simulator/setup.py` which imports setuptools (not in
    # python's default venv per PEP 632), AND it causes `libuhd`
    # itself to link against the Python framework via
    # `UHD_LIB_ADD_PYTHON(uhd)` in host/lib/CMakeLists.txt -- which
    # `brew audit` flags as a framework-link violation. The simulator
    # target is for software-only MPMD testing and is irrelevant for
    # UHD hardware use.
    args = %W[
      -DENABLE_TESTS=OFF
      -DENABLE_SIM=OFF
      -DUHD_VERSION=#{version}-oc
    ]
    system "cmake", "-S", "host", "-B", "build", *args, *std_cmake_args
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"
  end

  def caveats
    <<~EOS
      uhd-oc is a patched fork of homebrew-core's `uhd`. The stock `uhd`
      formula must be uninstalled before installing this one:

        brew uninstall uhd; brew install uhd-oc

      Verify the overclock build:

        uhd_config_info --version # should print "#{version}-oc"
    EOS
  end

  test do
    # Compile and run a tiny C++ program against multi_usrp.hpp -- this
    # exercises libuhd loading, header resolution, link, and the device
    # factory entry point. Without USB hardware attached, make_device()
    # throws cleanly which we catch and verify.
    (testpath/"test.cpp").write <<~CPP
      #include <uhd/usrp/multi_usrp.hpp>
      #include <uhd/version.hpp>
      #include <iostream>
      int main() {
          std::cout << "uhd version: " << uhd::get_version_string() << std::endl;
          try {
              auto usrp = uhd::usrp::multi_usrp::make(std::string(""));
              std::cout << "device found" << std::endl;
          } catch (const std::exception &e) {
              // Expected when no hardware attached.
              std::cout << "no device: ok" << std::endl;
          }
          return 0;
      }
    CPP

    system ENV.cxx, "-std=c++17", "test.cpp",
                    "-I#{include}",
                    "-L#{lib}", "-luhd",
                    "-o", "test"
    output = shell_output("./test")
    assert_match version.to_s, output
    assert_match(/(device found|no device: ok)/, output)
  end
end

__END__
--- a/host/lib/usrp/common/ad9361_driver/ad9361_device.cpp
+++ b/host/lib/usrp/common/ad9361_driver/ad9361_device.cpp
@@ -81,7 +81,7 @@
 
 const double ad9361_device_t::AD9361_MAX_GAIN         = 89.75;
 const double ad9361_device_t::AD9361_MIN_CLOCK_RATE   = 220e3;
-const double ad9361_device_t::AD9361_MAX_CLOCK_RATE   = 61.44e6;
+const double ad9361_device_t::AD9361_MAX_CLOCK_RATE   = 122.88e6;
 const double ad9361_device_t::AD9361_CAL_VALID_WINDOW = 100e6;
 // Max bandwdith is due to filter rolloff in analog filter stage
 const double ad9361_device_t::AD9361_MIN_BW = 200e3;
@@ -1217,7 +1217,7 @@
     int vcodiv;
 
     /* Iterate over VCO dividers until appropriate divider is found. */
-    int i = 1;
+    int i = 0;
     for (; i <= 6; i++) {
         vcodiv  = 1 << i;
         vcorate = rate * vcodiv;
@@ -1489,17 +1489,24 @@
         divfactor    = 12;
         _tfir_factor = 2;
         _rfir_factor = 2;
-    } else if ((rate > 58e6) && (rate <= 61.44e6)) {
+    } else if ((rate > 58e6) && (rate <= 70e6)) {
         // RX1 + RX2 enabled, 2, 1, 2, 2
         _regs.rxfilt = B8(11001110);
 
-
         // TX1 + TX2 enabled, 2, 1, 1, 2
         _regs.txfilt = B8(11010010);
 
         divfactor    = 8;
         _tfir_factor = 2;
         _rfir_factor = 2;
+    } else if ((rate > 70e6) && (rate <= 122.88e6)) {
+
+        _regs.rxfilt = B8(11001100);
+        _regs.txfilt = B8(11001100);
+
+        divfactor    = 4;
+        _tfir_factor = 0;
+        _rfir_factor = 0;
     } else {
         // should never get in here
         throw uhd::runtime_error("[ad9361_device_t] [_setup_rates] INVALID_CODE_PATH");
@@ -1543,6 +1550,12 @@
     _io_iface->poke8(0x004, _regs.inputsel);
     _io_iface->poke8(0x00A, _regs.bbpll);
 
+    if (rate > 100e6) {
+        _io_iface->poke8(0x006, 0x0A); // Decrease RX timings above 100e6
+    } else {
+        _io_iface->poke8(0x006, 0x0F); // Reset to default
+    }
+
     UHD_LOG_TRACE("AD936X", "[ad9361_device_t::_setup_rates] adcclk=" << adcclk);
     _baseband_bw = (adcclk / divfactor);
 
@@ -1566,8 +1579,8 @@
     const size_t num_tx_taps = get_num_taps(max_tx_taps);
     const size_t num_rx_taps = get_num_taps(max_rx_taps);
 
-    _setup_tx_fir(num_tx_taps, _tfir_factor);
-    _setup_rx_fir(num_rx_taps, _rfir_factor);
+    if (_tfir_factor != 0) {_setup_tx_fir(num_tx_taps, _tfir_factor);}
+    if (_rfir_factor != 0) {_setup_rx_fir(num_rx_taps, _rfir_factor);}

     return _baseband_bw;
 }
@@ -1857,7 +1870,7 @@
 {
     std::lock_guard<std::recursive_mutex> lock(_mutex);
 
-    if (req_rate > 61.44e6) {
+    if (req_rate > 122.88e6) {
         throw uhd::runtime_error(
             "[ad9361_device_t] Requested master clock rate outside range");
     }
