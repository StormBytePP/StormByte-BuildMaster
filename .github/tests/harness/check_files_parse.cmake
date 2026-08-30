include("${CMAKE_CURRENT_LIST_DIR}/../../../log.cmake")
if(COMMAND _bm_log_level_init)
	_bm_log_level_init()
endif()

set(_sqlite_url "https://sqlite.org/2026/sqlite-amalgamation-3530400.zip")
set(_sqlite_hash "SHA3_256=fabc43dac6d1698d86e17b228c133f97e0263fa8c3859b56ed0e3a36ba02b7e6")
set(_opt "FILES={URL=${_sqlite_url};NAME=sqlite3;UNPACK;TITLE=SQLite3 amalgamation;EXPECTED_HASH=${_sqlite_hash}}")

_bm_opt_parse_files("${_opt}"
	_pres _urls _names _hashes _algos
	_unpacks _forces _sources _titles)

if(NOT _pres)
	_bm_log_message(CORE FATAL "files-parse: FILES key not seen")
endif()
if(NOT _names STREQUAL "sqlite3")
	_bm_log_message(CORE FATAL
		"files-parse: NAME='${_names}' (want sqlite3). opt=${_opt}")
endif()
if(NOT _urls STREQUAL "${_sqlite_url}")
	_bm_log_message(CORE FATAL
		"files-parse: URL='${_urls}'")
endif()
if(NOT _unpacks STREQUAL "TRUE")
	_bm_log_message(CORE FATAL
		"files-parse: UNPACK='${_unpacks}'")
endif()
if(NOT _titles STREQUAL "SQLite3 amalgamation")
	_bm_log_message(CORE FATAL
		"files-parse: TITLE='${_titles}'")
endif()
if(NOT _algos STREQUAL "SHA3_256" OR NOT _hashes STREQUAL "fabc43dac6d1698d86e17b228c133f97e0263fa8c3859b56ed0e3a36ba02b7e6")
	_bm_log_message(CORE FATAL
		"files-parse: hash='${_algos}=${_hashes}'")
endif()

_bm_log_message(CORE STATUS "files-parse sqlite shape: OK")
