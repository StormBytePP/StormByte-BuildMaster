#include "crypto_host.h"
#include "shared_buffer.h"
#include "shared_base.h"

int crypto_host_tag(void)
{
    /* Direct Base symbol, same class as StormByte::Exception in Crypto.so */
    if (shared_base_tag() != 1)
        return -1;
    return 1000 + shared_buffer_tag();
}
