#include "rshi.h"
#include "rslo.h"
#include "rspub.h"

int main(void)
{
    return (rshi_flag() == 12 && rslo_flag() == 10 && rspub_flag() == 8) ? 0 : 1;
}
