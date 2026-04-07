# homebrew-sdr

Homebrew tap to keg off additional formulae related to [SDR](https://en.wikipedia.org/wiki/Software-defined_radio).

## Tap

```bash
brew tap gretel/sdr
```

Formulae are then available as `gretel/sdr/<formula>`.

## Formulae

### [`libiio`](https://github.com/analogdevicesinc/libiio) — 0.26

Analog Devices' C library for reading and writing Linux IIO
(Industrial I/O) devices: ADCs, DACs, sensors, and RF transceivers
that expose themselves through the kernel IIO subsystem. The
foundation for talking to any ADI hardware from userspace — over
USB, over the network, or against a local sysfs tree.

### [`libad9361-iio`](https://github.com/analogdevicesinc/libad9361-iio) — 0.3

Helper library on top of `libiio` for the AD9361 — the wideband RF
transceiver chip inside the ADALM-PLUTO SDR and many AD9361
development boards. Handles baseband rate setup, filter
programming, and other AD9361-specific configuration that plain
`libiio` can't do.

### [`soapy-pluto-papr`](https://github.com/F5OEO/SoapyPlutoPAPR) — 0.2.1+git

A SoapySDR module for the PlutoSDR. SoapySDR is the vendor-neutral
SDR abstraction layer used by GNU Radio, CubicSDR, SDRangel, and
similar tools. This fork of the upstream Pluto plugin adds CS8 and
CS12 streaming sample formats on top of the usual float32 — useful
when USB bandwidth becomes the bottleneck at high sample rates, or
when passing samples through a gateway that prefers fixed-point.

### [`uhd-oc`](https://github.com/EttusResearch/uhd) — 4.9.0.1-oc

Ettus UHD — the driver suite for USRP radios — patched to raise
the internal AD9361 clock ceiling from 61.44 MS/s to 122.88 MS/s.
Used with B200, B210, and B220 devices to push beyond the
officially supported sample rates. The overclock patch is from
[MothMaux/uhd-oc](https://github.com/MothMaux/uhd-oc) and is
applied at build time; no FPGA or firmware changes.

**Conflicts with the stock `uhd` formula** — you must
`brew uninstall uhd` first. `brew info gretel/sdr/uhd-oc`
prints the full swap procedure including how to preserve the FPGA
image directory across the swap.
