# typed: false
# frozen_string_literal: true

# SoapySDR plugin that exposes UHD/USRP devices through the SoapySDR API.
# Works with either stock `uhd` or the overclocked `gretel/sdr/uhd-oc` --
# the formula picks whichever is currently installed at parse time. We
# do NOT hardcode any paths to `uhd-oc` here: uhd-oc is meant to be a
# drop-in replacement for `uhd`, and consumers like soapyuhd should not
# need to know which keg is active.
#
# Default `brew install` builds pothosware/SoapyUHD (upstream), pinned
# by SHA for reproducibility. Pothosware master is pre-fork baseline:
# C++14, Boost-dependent, no BUILD_SOAPY_SUPPORT toggle, missing the
# gretel-only commits (UHD 4.10 mtu kwarg, channel-count cache, etc.).
# It needs three Homebrew-side workarounds (CMake 4 policy, C++17 bump
# for UHD 4.10 headers, missing boost/lexical_cast.hpp include).
#
# `brew install --HEAD` builds gretel/SoapyUHD master, the modernized
# fork (C++20, Boost-free, target-scoped CMake, UHD 4.10 native, post
# 76f6923 hot-path channel-count cache). No inreplace patches needed
# in the fork build path.
#
# This formula is intentionally tap-only by design: the parse-time
# `Formula[...].any_version_installed?` conditional below is not
# acceptable in homebrew-core (which forbids conditional dependencies
# on tap formulae and resolves graphs purely from the .rb at parse
# time without inspecting the local Cellar). A future homebrew-core
# variant would replace the conditional block with a single
# `depends_on "uhd"`.
class Soapyuhd < Formula
  desc "SoapySDR plugin for UHD/USRP devices"
  homepage "https://github.com/pothosware/SoapyUHD"
  license "GPL-3.0-or-later"
  revision 3

  stable do
    # Pothosware upstream master tip post-0.4.1, pinned by SHA so the
    # default install is reproducible across upstream pushes.
    url "https://github.com/pothosware/SoapyUHD/archive/2a5d381f68fd05d5b3c0e7db56c36892ea99b4ae.tar.gz"
    version "0.4.2"
    sha256 "a28c38123d9b96d54834acab54a839372bbb1ba456bfa34233bfad079333c170"

    # Pothosware still uses boost::lexical_cast / boost::format /
    # boost::bind. The gretel HEAD fork has purged Boost entirely.
    depends_on "boost"
  end

  head do
    url "https://github.com/gretel/SoapyUHD.git", branch: "master"
  end

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
    if build.stable?
      # Pothosware master pins CMAKE_CXX_STANDARD 14 -- UHD 4.10
      # headers need at least C++17 (std::optional, std::is_same_v).
      inreplace "CMakeLists.txt",
                "set(CMAKE_CXX_STANDARD 14)",
                "set(CMAKE_CXX_STANDARD 17)"

      # SoapyUHDDevice.cpp uses boost::lexical_cast but relies on a
      # transitive include newer Boost no longer ships.
      inreplace "SoapyUHDDevice.cpp",
                "#include <iostream>",
                "#include <iostream>\n#include <boost/lexical_cast.hpp>"
    end

    # No UHD_DIR / UHD_INCLUDE_DIRS / UHD_LIBRARIES override: the
    # active uhd / uhd-oc keg is on CMAKE_PREFIX_PATH automatically
    # via Homebrew's superenv, so `find_package(UHD NO_MODULE)`
    # resolves against `<keg>/lib/cmake/uhd/UHDConfig.cmake` directly.
    args = std_cmake_args + %W[
      -DSoapySDR_DIR=#{Formula["soapysdr"].opt_lib}/cmake/SoapySDR
    ]

    if build.stable?
      # Pothosware's `cmake_minimum_required(VERSION 2.8.12...3.10)`
      # is rejected by CMake 4 -- pass the compatibility floor.
      boost = Formula["boost"]
      args += %W[
        -DCMAKE_POLICY_VERSION_MINIMUM=3.5
        -DBOOST_ROOT=#{boost.opt_prefix}
        -DBoost_NO_SYSTEM_PATHS=ON
        -DBoost_NO_BOOST_CMAKE=OFF
        -DCMAKE_POLICY_DEFAULT_CMP0167=NEW
      ]
    else
      # Gretel fork added BUILD_SOAPY_SUPPORT toggle in 6463fb0. The
      # soapySupport target (UHD<-Soapy) installs into
      # ${UHD_ROOT}/lib/uhd/modules outside our keg sandbox, writing
      # into the uhd / uhd-oc keg. SoapySDR consumers only need
      # uhdSupport (Soapy<-UHD).
      args << "-DBUILD_SOAPY_SUPPORT=OFF"
    end

    system "cmake", "-S", ".", "-B", "build", *args

    if build.stable?
      # Pothosware has no BUILD_SOAPY_SUPPORT toggle, so build only
      # the uhdSupport target and install the module by hand.
      # SOAPY_SDR_MODULE_UTIL produces `libuhdSupport.so` on macOS too
      # (SoapySDR forces .so suffix for cross-platform module loading).
      system "cmake", "--build", "build", "--target", "uhdSupport"
      (lib/"SoapySDR/modules0.8").install "build/libuhdSupport.so"
    else
      system "cmake", "--build", "build"
      system "cmake", "--install", "build"
    end
  end

  def caveats
    <<~EOS
      soapyuhd links against whichever uhd keg was active at build
      time (stock `uhd` or `gretel/sdr/uhd-oc`). The RPATH is baked
      into the uhdSupport plugin and points at that specific keg's
      lib dir.

      After switching between `uhd` and `uhd-oc` you MUST rebuild
      soapyuhd or its plugin will fail to dlopen libuhd:

        brew reinstall gretel/sdr/soapyuhd

      Same applies to any other consumer of libuhd (gnuradio, etc.).

      Default install builds pothosware/SoapyUHD upstream (pre-fork
      baseline). To use the gretel fork (C++20, Boost-free, UHD 4.10
      modernization, post-76f6923 hot-path optimizations):

        brew install --HEAD gretel/sdr/soapyuhd
    EOS
  end

  test do
    output = shell_output("#{Formula["soapysdr"].opt_bin}/SoapySDRUtil --info 2>&1")
    assert_match "uhd", output

    # Probe for UHD devices via the just-installed uhdSupport module.
    # Without USRP hardware attached, SoapySDRUtil exits 1 and prints
    # "No devices found" -- which still proves the module loaded and
    # the driver registered with SoapySDR. With hardware attached,
    # exit 0 + "Found device" appears instead. Mask the exit code via
    # `|| true` so the assertion runs in both cases.
    probe = shell_output("#{Formula["soapysdr"].opt_bin}/SoapySDRUtil --find=driver=uhd 2>&1 || true")
    assert_match(/(No devices found|Found device)/, probe)
  end
end
