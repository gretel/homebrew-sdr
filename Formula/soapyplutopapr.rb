# typed: false
# frozen_string_literal: true

# SoapySDR plugin for PlutoSDR with extended Tezuka streaming formats
# (CS12, CS8, PAPR modes). Forked from F5OEO/SoapyPlutoPAPR; we re-brand
# the in-tree "tezuka" naming to "papr" via inreplace at install time
# so the SoapySDR module registers as "plutoPAPR" rather than "tezuka",
# disambiguating from any other "tezuka"-named SoapySDR modules.
class Soapyplutopapr < Formula
  desc "SoapySDR plugin for PlutoSDR with extended Tezuka/PAPR streaming formats"
  homepage "https://github.com/F5OEO/SoapyPlutoPAPR"
  # Pinned to commit ec1c92d (post-0.2.1, includes the CS8/CS16 fixes
  # and the upstream "tezuka" rename). Upstream has not tagged this
  # commit; we synthesise a version string from the commit date.
  url "https://github.com/F5OEO/SoapyPlutoPAPR.git",
      revision: "ec1c92dbef83631657fd58f49f2d0e363d4394c0"
  version "0.2.1+git.20250605"
  license "LGPL-2.1-or-later"
  head "https://github.com/F5OEO/SoapyPlutoPAPR.git", branch: "master"

  depends_on "cmake" => :build
  depends_on "libad9361-iio"
  depends_on "libiio"
  depends_on "libusb"
  depends_on "soapysdr"

  def install
    # Rename the upstream "tezuka" branding to "papr". These are
    # Homebrew-only renames that disambiguate the SoapySDR module name
    # and the per-device kwarg key. We do this via inreplace rather
    # than a patch because the change is purely cosmetic and won't be
    # accepted upstream.
    if File.read("CMakeLists.txt").include?("TezukaSupport")
      inreplace "CMakeLists.txt", "TARGET TezukaSupport", "TARGET PlutoPAPRSupport"
    end

    if File.read("PlutoSDR_Registration.cpp").include?("tezuka")
      inreplace "PlutoSDR_Registration.cpp" do |s|
        s.gsub! 'args.count("tezuka_format")', 'args.count("papr_format")'
        s.gsub! 'options["tezuka_format"]=args.at("tezuka_format")',
                'options["papr_format"]=args.at("papr_format")'
        s.gsub! 'register_plutosdr("tezuka",', 'register_plutosdr("plutoPAPR",'
      end
    end

    if File.read("PlutoSDR_Settings.cpp").include?("tezuka_format")
      inreplace "PlutoSDR_Settings.cpp",
                'args.count("tezuka_format") != 0) && strncmp(args.at("tezuka_format")',
                'args.count("papr_format") != 0) && strncmp(args.at("papr_format")'
    end

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
