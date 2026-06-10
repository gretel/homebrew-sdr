# typed: false
# frozen_string_literal: true

# SoapySDR plugin for PlutoSDR with extended PAPR streaming formats
# (CS8, CS12, CS16, CF32).  Tracks the gretel/SoapyPlutoPAPR fork of
# F5OEO/SoapyPlutoPAPR on the feat-setts branch, which carries the
# pothosware/SoapyPlutoSDR settings API, CS12 support, MTU
# adaptation, and streaming improvements rebased onto F5OEO master
# (rename + BB-rate ordering fix) with the tezuka driver key.
# No inreplace patches needed.
class Soapyplutopapr < Formula
  desc "SoapySDR plugin for PlutoSDR with extended PAPR streaming formats"
  homepage "https://github.com/gretel/SoapyPlutoPAPR"
  # Pinned to the head of feat-setts, which carries:
  #   - 95f3139  F5OEO upstream: tezuka rename + BB rate fix
  #   - ed4c01e  pothosware #76: remove device cache from find
  #   - 819c58b  pothosware #77: fix tx_streamer bufflen + MTU
  #   - d48d4b9  feat-setts + tezuka driver key
  # Syncs F5OEO fork with pothosware/SoapyPlutoSDR (master + feat-setts).
  url "https://github.com/gretel/SoapyPlutoPAPR.git",
      revision: "d48d4b91ec49e5a4cebfe682df3dc85de84c03c3"
  version "0.2.2+git.20260610"
  license "LGPL-2.1-or-later"
  head "https://github.com/gretel/SoapyPlutoPAPR.git", branch: "feat-setts"

  livecheck do
    # Tracked branch is gretel/SoapyPlutoPAPR feat-setts (a fork
    # of pothosware/SoapyPlutoSDR feat-setts, rebased onto F5OEO
    # master + tezuka driver key). Upstream tags follow
    # `soapy-plutosdr-*`, which do not match the fork version.
    # Bump manually when the fork is rebased onto a new baseline.
    skip "fork-tracked: gretel/SoapyPlutoPAPR feat-setts"
  end

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

    # SoapySDRUtil --find exits 1 when no devices match; mask with `|| true`
    # so the assertion runs regardless of exit code. The driver loaded
    # successfully if it reports either "No devices found" (no hardware
    # attached) or "Found device" (hardware attached).
    probe = shell_output("#{Formula["soapysdr"].opt_bin}/SoapySDRUtil --find=driver=tezuka 2>&1 || true")
    assert_match(/(No devices found|Found device)/, probe)
  end
end
