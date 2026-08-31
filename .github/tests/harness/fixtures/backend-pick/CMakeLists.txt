# Dual markers. BACKEND=cmake must win; meson.build is poison.
buildmaster_component(
    be-pick
    "Harness BACKEND=cmake"
    "${CMAKE_CURRENT_SOURCE_DIR}/src"
    ""
    static
    "bepick"
    "BACKEND=cmake"
)
