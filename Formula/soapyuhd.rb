# typed: false
# frozen_string_literal: true

# SoapySDR plugin that exposes UHD/USRP devices through the SoapySDR API.
# Works with either stock `uhd` or the overclocked `gretel/sdr/uhd-oc` --
# the formula picks whichever is currently installed at parse time. We
# do NOT hardcode any paths to `uhd-oc` here: uhd-oc is meant to be a
# drop-in replacement for `uhd`, and consumers like soapyuhd should not
# need to know which keg is active.
class Soapyuhd < Formula
  desc "SoapySDR plugin for UHD/USRP devices"
  homepage "https://github.com/pothosware/SoapyUHD"
  # Track master past 0.4.1 to pick up post_output_action() stub in
  # UHDSoapyDevice.cpp -- needed to compile soapySupport against UHD
  # 4.x's pure-virtual added in uhd/stream.hpp.
  url "https://github.com/pothosware/SoapyUHD/archive/2a5d381f68fd05d5b3c0e7db56c36892ea99b4ae.tar.gz"
  version "0.4.2"
  sha256 "a28c38123d9b96d54834acab54a839372bbb1ba456bfa34233bfad079333c170"
  license "GPL-3.0-or-later"

  head "https://github.com/pothosware/SoapyUHD.git", branch: "master"

  depends_on "cmake" => :build
  depends_on "boost"
  depends_on "soapysdr"

  # Parse-time conditional: prefer the overclocked uhd-oc keg if the
  # user has it installed, otherwise pick stock uhd. The two formulae
  # `conflicts_with` each other so at most one is ever installed.
  uhd_oc_installed = begin
    Formula["gretel/sdr/uhd-oc"].any_version_installed?
  rescue FormulaUnavailableError, FormulaUnspecifiedError
    false
  end

  if uhd_oc_installed
    depends_on "gretel/sdr/uhd-oc"
  else
    depends_on "uhd"
  end

  def install
    # SoapyUHD's CMakeLists.txt uses `cmake_minimum_required(VERSION
    # 2.8.12...3.10)` which CMake 4 no longer accepts -- pass the
    # compatibility flag.
    #
    # No UHD_DIR / UHD_INCLUDE_DIRS / UHD_LIBRARIES overrides: the
    # active uhd / uhd-oc keg is on CMAKE_PREFIX_PATH automatically via
    # Homebrew's superenv, so `find_package(UHD NO_MODULE)` resolves
    # against `<keg>/lib/cmake/uhd/UHDConfig.cmake` directly.

    # UHD 4.10 headers use C++17 features (`std::optional`,
    # `std::is_same_v`, etc.). SoapyUHD master pins
    # `CMAKE_CXX_STANDARD 14` which can't include UHD's headers
    # cleanly. Bump the standard to 17.
    inreplace "CMakeLists.txt",
              "set(CMAKE_CXX_STANDARD 14)",
              "set(CMAKE_CXX_STANDARD 17)"

    # SoapyUHDDevice.cpp uses `boost::lexical_cast` but relies on a
    # transitive include from another Boost header that newer Boost
    # versions no longer pull in. Add the explicit include alongside
    # the other system headers.
    inreplace "SoapyUHDDevice.cpp",
              "#include <iostream>",
              "#include <iostream>\n#include <boost/lexical_cast.hpp>"

    boost = Formula["boost"]
    args = std_cmake_args + %W[
      -DCMAKE_POLICY_VERSION_MINIMUM=3.5
      -DSoapySDR_DIR=#{Formula["soapysdr"].opt_lib}/cmake/SoapySDR
      -DBOOST_ROOT=#{boost.opt_prefix}
      -DBoost_NO_SYSTEM_PATHS=ON
      -DBoost_NO_BOOST_CMAKE=OFF
      -DCMAKE_POLICY_DEFAULT_CMP0167=NEW
    ]

    # Only build `uhdSupport` (Soapy<-UHD direction). The `soapySupport`
    # target (UHD<-Soapy) installs into ${UHD_ROOT}/lib/uhd/modules,
    # which is outside our Homebrew sandbox -- it would write into the
    # uhd / uhd-oc keg. SoapySDR consumers only need uhdSupport.
    system "cmake", "-S", ".", "-B", "build", *args
    system "cmake", "--build", "build", "--target", "uhdSupport"

    # SOAPY_SDR_MODULE_UTIL produces `libuhdSupport.so` on macOS too
    # (SoapySDR forces .so suffix for cross-platform module loading).
    (lib/"SoapySDR/modules0.8").install "build/libuhdSupport.so"
  end

  test do
    output = shell_output("#{Formula["soapysdr"].opt_bin}/SoapySDRUtil --info 2>&1")
    assert_match "uhd", output
  end
end
