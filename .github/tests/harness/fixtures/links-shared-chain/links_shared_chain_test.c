#include "crypto_host.h"
#include "shared_buffer.h"
#include "shared_logger.h"
#include "shared_base.h"

int main(void)
{
    if (shared_base_tag() != 1)
        return 1;
    if (shared_logger_tag() != 11)
        return 2;
    if (shared_buffer_tag() != 111)
        return 3;
    if (crypto_host_tag() != 1111)
        return 4;
    return 0;
}
