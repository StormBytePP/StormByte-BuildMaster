# Raw names only. Do not invent a BM dest called "m".
if(WIN32)
    set(_RAW "LINK={kernel32}")
else()
    set(_RAW "LINK={m}")
endif()

create_cmake_component(
    raw-lib
    "Harness raw LINK"
    "${CMAKE_CURRENT_SOURCE_DIR}/lib"
    "${CMAKE_CURRENT_BINARY_DIR}/raw-lib"
    ""
    static
    "rawlib"
    "${_RAW}"
)
