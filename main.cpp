#include "config.h"
#include "common.h"
#include "managed_bridge.h"
#include "managed_exports.h"

DNNE_EXTERN_C
void csharp_log(char* msg) {
	printf("%s\n", msg);
}

int main(int argc, char** argv)
{
	OnInit();
}
