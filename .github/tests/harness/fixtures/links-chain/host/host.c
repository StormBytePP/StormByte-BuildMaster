#include "links_host.h"
#include "stormbyte_buffer.h"
int links_host_tag(void) { return 1000 + stormbyte_buffer_tag(); }
