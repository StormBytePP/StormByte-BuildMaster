/* bm_lf_ok exists only if this host's WINDOWS/LINUX/MAC group reached the linker. */
#ifdef _WIN32
extern int bm_lf_ok;
int main(void) {
	return (&bm_lf_ok == 0);
}
#else
extern char bm_lf_ok;
int main(void) {
	return ((long)(void *)&bm_lf_ok == 0);
}
#endif
