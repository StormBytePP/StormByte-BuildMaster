#include "links_host.h"
#include "stormbyte_buffer.h"
#include "stormbyte_logger.h"
#include "stormbyte_base.h"
int main(void)
{
    if (stormbyte_base_tag() != 1)
        return 1;
    if (stormbyte_logger_tag() != 11)
        return 2;
    if (stormbyte_buffer_tag() != 111)
        return 3;
    if (links_host_tag() != 1111)
        return 4;
    return 0;
}
