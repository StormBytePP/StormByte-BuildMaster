# 2.1 form: id title srcdir options mode produced [optstr]
create_cmake_component(
    omit-lib
    "Harness omit builddir"
    "${CMAKE_CURRENT_SOURCE_DIR}/lib"
    ""
    static
    "omitlib"
    "INDENT=1"
)
