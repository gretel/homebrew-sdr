# typed: strict
# frozen_string_literal: true

# SoapySDR plugin that exposes UHD/USRP devices through the SoapySDR API.
# Works with either stock `uhd` or the overclocked `gretel/sdr/uhd-oc` —
# install whichever you prefer before installing this formula.
class Soapyuhd < Formula
  desc "SoapySDR plugin for UHD/USRP devices"
  homepage "https://github.com/pothosware/SoapyUHD"
  url "https://github.com/pothosware/SoapyUHD/archive/refs/tags/soapy-uhd-0.4.1.tar.gz"
  version "0.4.1"
  sha256 "9779cce2e732cd41905b6cf8ea85edbbf51b1ac918e6180bd4891eebb4c8d085"
  license "GPL-3.0-or-later"

  head "https://github.com/pothosware/SoapyUHD.git", branch: "master"

  depends_on "cmake" => :build
  depends_on "boost"
  depends_on "soapysdr"

  def uhd_formula
    # uhd-oc and uhd conflict — exactly one will be installed.
    # Prefer uhd-oc if available, fall back to stock uhd.
    Formula["gretel/sdr/uhd-oc"]
  rescue FormulaUnavailableError, FormulaUnspecifiedError
    Formula["uhd"]
  end

  def install
    # SoapyUHD 0.4.1 uses cmake_minimum_required(VERSION 2.8.7); CMake 4
    # no longer accepts this — pass the compatibility flag as a workaround.
    #
    # Explicitly pass UHD/Boost paths so CMake doesn't pick up stale opt
    # symlinks from a previously uninstalled uhd keg.
    #
    # soapySupport (UHD→Soapy direction) fails to build against uhd 4.9:
    # UHDSoapyTxStream doesn't implement post_output_action(), a pure virtual
    # added in uhd/stream.hpp. Only uhdSupport (Soapy→UHD direction) is
    # needed for SoapySDR use. Build and install that target only.
    uhd = uhd_formula
    boost = Formula["boost"]
    args = std_cmake_args + %W[
      -DCMAKE_POLICY_VERSION_MINIMUM=3.5
      -DSoapySDR_DIR=#{Formula["soapysdr"].opt_lib}/cmake/SoapySDR
      -DUHD_DIR=#{uhd.opt_lib}/cmake/uhd
      -DUHD_INCLUDE_DIRS=#{uhd.opt_include}
      -DUHD_LIBRARIES=#{uhd.opt_lib}/#{shared_library("libuhd")}
      -DBOOST_ROOT=#{boost.opt_prefix}
      -DBoost_NO_SYSTEM_PATHS=ON
      -DBoost_NO_BOOST_CMAKE=OFF
      -DCMAKE_POLICY_DEFAULT_CMP0167=NEW
    ]

    system "cmake", "-S", ".", "-B", "build", *args
    system "cmake", "--build", "build", "--target", "uhdSupport"
    (lib/"SoapySDR/modules0.8").install "build/libuhdSupport.so"
  end

  test do
    output = shell_output("#{Formula["soapysdr"].opt_bin}/SoapySDRUtil --info 2>&1")
    assert_match "uhd", output
  end
end
