# File Path: src/hardware/CMakeLists.txt (Inside Power-Systems Repo)
cmake_minimum_required(VERSION 3.20.0)
project(univac_power_systems_core)

# Registers the hardware breaker controller for Xilinx Vivado headless tracking loops
add_library(univac_breaker_control STATIC univac_breaker_control.vhd)

message(STATUS "[+] UNIVAC Solid-State Power Conversion Group (SSPC) modules registered successfully.")
