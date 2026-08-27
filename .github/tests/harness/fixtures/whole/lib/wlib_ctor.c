extern int wlib_registered;

#if defined(_MSC_VER)
#  pragma section(".CRT$XCU", read)
static void __cdecl wlib_register(void);
__declspec(allocate(".CRT$XCU")) void (__cdecl *wlib_register_)(void) = wlib_register;
static void __cdecl wlib_register(void)
#else
static void wlib_register(void) __attribute__((constructor));
static void wlib_register(void)
#endif
{
	wlib_registered = 1;
}
