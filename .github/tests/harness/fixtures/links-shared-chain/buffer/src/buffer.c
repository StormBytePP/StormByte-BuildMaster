#include "shared_buffer.h"
#include "shared_logger.h"

int shared_buffer_tag(void)
{
    return 100 + shared_logger_tag();
}
