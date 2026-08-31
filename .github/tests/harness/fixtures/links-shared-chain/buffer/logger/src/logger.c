#include "shared_logger.h"
#include "shared_base.h"

int shared_logger_tag(void)
{
    return 10 + shared_base_tag();
}
