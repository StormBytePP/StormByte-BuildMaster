cmake_minimum_required(VERSION 3.20)
project(HarnessBuildOnlyLib C)

add_library(bolib STATIC bolib.c)
# Upstream-style variant name; BuildMaster RENAME → bolib in BUILDDIR
set_target_properties(bolib PROPERTIES OUTPUT_NAME "bolib-static")
target_include_directories(bolib PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}")

# No install() — BUILDONLY must not rely on install to the shared prefix.
# Archives stay under the component BUILDDIR for RENAME + OUTPUT contract.