# typed: false
# frozen_string_literal: true

# SoapySDR plugin for PlutoSDR with extended PAPR streaming formats
# (CS12, CS8, PAPR modes).  Tracks the gretel/SoapyPlutoPAPR fork of
# F5OEO/SoapyPlutoPAPR, which commits the "tezuka" -> "plutoPAPR"
# rebrand at source level (no inreplace needed) and adds the
# ad9361_set_bb_rate-before-FPGA-data-port-rate ordering fix that
# unbreaks sample rates below the AD9361 native FIR-bypass minimum.
class Soapyplutopapr < Formula
  desc "SoapySDR plugin for PlutoSDR with extended PAPR streaming formats"
  homepage "https://github.com/gretel/SoapyPlutoPAPR"
  # Pinned to the head of feature/plutoPAPR, which carries:
  #   - ec1c92d  Change Name for tezuka specific features (F5OEO)
  #   - cee0631  rename: tezuka -> plutoPAPR (CMake, registry, kwarg)
  #   - 238fba5  fix(settings): ad9361_set_bb_rate before FPGA rate
  url "https://github.com/gretel/SoapyPlutoPAPR.git",
      revision: "238fba5b6b49155188c2733ac3a3fe78703ebf47"
  version "0.2.2+git.20260420"
  license "LGPL-2.1-or-later"
  head "https://github.com/gretel/SoapyPlutoPAPR.git", branch: "feature/plutoPAPR"

  depends_on "cmake" => :build
  depends_on "libad9361-iio"
  depends_on "libiio"
  depends_on "libusb"
  depends_on "soapysdr"

  def install
    args = %W[
      -DCMAKE_POLICY_VERSION_MINIMUM=3.5
      -DSoapySDR_DIR=#{Formula["soapysdr"].opt_lib}/cmake/SoapySDR
    ]

    system "cmake", "-S", ".", "-B", "build", *args, *std_cmake_args
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"
  end

  test do
    output = shell_output("#{Formula["soapysdr"].opt_bin}/SoapySDRUtil --info 2>&1")
    assert_match "Module", output
    assert_match "Soapy", output

    probe = shell_output("#{Formula["soapysdr"].opt_bin}/SoapySDRUtil --find=driver=plutoPAPR 2>&1")
    assert_match(/(No devices found|Found device)/, probe)
  end
end
