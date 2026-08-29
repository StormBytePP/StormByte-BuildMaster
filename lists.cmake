# =============================================================================
# lists.cmake — list join and boolean toggle
# =============================================================================

## @brief Toggle a boolean-style variable between TRUE and FALSE in the
##        parent scope.
## @param[in] var_name Name of the variable to toggle; the current value
##            is read and the negated value is written into the parent
##            scope.
function(_bm_list_toggle_bool _var)
	_bm_log_message(CORE LOWLEVEL "Entering _bm_list_toggle_bool")
	if(NOT ARGC EQUAL 1)
		_bm_log_message(CORE FATAL "_bm_list_toggle_bool requires one variable name")
	endif()

	if(${${_var}})
		set(${_var} FALSE PARENT_SCOPE)
	else()
		set(${_var} TRUE PARENT_SCOPE)
	endif()
	_bm_log_message(CORE LOWLEVEL "Exiting _bm_list_toggle_bool")
endfunction()

## @brief Join a CMake list into a single string while preserving
##        semicolons inside quoted substrings.
## @param[out] _out_var Name of the variable to set in the parent scope
##            with the resulting joined string.
## @param[in] _list_var Name of a variable that contains a CMake list
##            (pass the variable name, not a literal list).
## @param[in] _separator String used to replace top-level semicolons
##            (those not inside quotes).
## @note Iterates the serialized list character-by-character tracking
##       quote state; replaces semicolons only when not inside quotes.
##       Does not validate matching quotes; unbalanced quotes may produce
##       unexpected output. Quote characters themselves are not copied
##       into the result (the joined string is wrapped in one pair of `"`).
function(_bm_list_join _out_var _raw_string _separator)
	_bm_log_message(CORE LOWLEVEL "Entering _bm_list_join")
	set(result "\"")
	set(in_single_quote FALSE)
	set(in_double_quote FALSE)

	set(raw "${_raw_string}")

	if(NOT "${raw}" STREQUAL "")
		string(LENGTH "${raw}" N)
		math(EXPR N "${N} - 1")

		foreach(i RANGE ${N})
			string(SUBSTRING "${raw}" ${i} 1 ch)

			if(ch STREQUAL "'")
				if(NOT in_double_quote)
					_bm_list_toggle_bool(in_single_quote)
				endif()
				continue()
			endif()

			if(ch STREQUAL "\"")
				if(NOT in_single_quote)
					_bm_list_toggle_bool(in_double_quote)
				endif()
				continue()
			endif()

			if(ch STREQUAL ";")
				if(NOT in_single_quote AND NOT in_double_quote)
					set(ch "\"${_separator}\"")
				else()
					set(ch ";")
				endif()
			endif()

			set(result "${result}${ch}")
		endforeach()
	endif()

	set(result "${result}\"")
	set(${_out_var} "${result}" PARENT_SCOPE)
	_bm_log_message(CORE LOWLEVEL "Exiting _bm_list_join")
endfunction()
