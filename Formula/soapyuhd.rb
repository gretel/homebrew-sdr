# typed: false
# frozen_string_literal: true

# SoapySDR plugin that exposes UHD/USRP devices through the SoapySDR API.
# Works with either stock `uhd` or the overclocked `gretel/sdr/uhd-oc` --
# the formula picks whichever is currently installed at parse time. We
# do NOT hardcode any paths to `uhd-oc` here: uhd-oc is meant to be a
# drop-in replacement for `uhd`, and consumers like soapyuhd should not
# need to know which keg is active.
#
# This formula is intentionally tap-only by design: the parse-time
# `Formula[...].any_version_installed?` conditional below is not
# acceptable in homebrew-core (which forbids conditional dependencies on
# tap formulae and resolves graphs purely from the .rb at parse time
# without inspecting the local Cellar). A future homebrew-core variant
# would replace the conditional block with a single `depends_on "uhd"`.
class Soapyuhd < Formula
  desc "SoapySDR plugin for UHD/USRP devices"
  homepage "https://github.com/pothosware/SoapyUHD"
  # Pinned to gretel/SoapyUHD master, which carries fork-specific
  # modernization (UHD 4.10 compat, C++20, Boost-free, target-scoped
  # CMake) while upstream pothosware reviews the equivalent PRs. The
  # fork itself does not issue releases; we track upstream's last
  # version label and bump `revision` for fork patch updates.
  url "https://github.com/gretel/SoapyUHD/archive/87547481d4fedc21841891812f1a703eabd0c6ae.tar.gz"
  version "0.4.2"
  sha256 "04a69f135140789b6174806a193d34025d8af09b782b3103fc5fcca087d9eb54"
  license "GPL-3.0-or-later"
  revision 2

  head "https://github.com/gretel/SoapyUHD.git", branch: "master"

  depends_on "cmake" => :build
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
    # The fork removed the need for inreplace patches the previous
    # formula carried (CMAKE_CXX_STANDARD bump, explicit
    # <boost/lexical_cast.hpp> include, -DCMAKE_POLICY_VERSION_MINIMUM=3.5).
    # cmake_minimum is now 3.10..3.30 in the fork and Boost is no
    # longer linked.
    #
    # No UHD_DIR override: the active uhd / uhd-oc keg is on
    # CMAKE_PREFIX_PATH via Homebrew's superenv, so
    # `find_package(UHD NO_MODULE)` resolves against
    # `<keg>/lib/cmake/uhd/UHDConfig.cmake` directly.
    #
    # BUILD_SOAPY_SUPPORT=OFF: the soapySupport target (UHD<-Soapy)
    # would install into ${UHD_ROOT}/lib/uhd/modules outside our keg
    # sandbox, writing into the uhd / uhd-oc keg. SoapySDR consumers
    # only need uhdSupport (Soapy<-UHD).

    args = std_cmake_args + %W[
      -DSoapySDR_DIR=#{Formula["soapysdr"].opt_lib}/cmake/SoapySDR
      -DBUILD_SOAPY_SUPPORT=OFF
    ]

    system "cmake", "-S", ".", "-B", "build", *args
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"
  end

  test do
    output = shell_output("#{Formula["soapysdr"].opt_bin}/SoapySDRUtil --info 2>&1")
    assert_match "uhd", output

    # Probe for UHD devices via the just-installed uhdSupport module.
    # Without USRP hardware attached, SoapySDRUtil exits 1 and prints
    # "No devices found" -- which still proves the module loaded and the
    # driver registered with SoapySDR. With hardware attached, exit 0 +
    # "Found device" appears instead. Mask the exit code via `|| true`
    # so the assertion runs in both cases.
    probe = shell_output("#{Formula["soapysdr"].opt_bin}/SoapySDRUtil --find=driver=uhd 2>&1 || true")
    assert_match(/(No devices found|Found device)/, probe)
  end
end
