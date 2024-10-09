#include "config.h"
#include "common.h"
#include "managed_bridge.h"
#include "managed_exports.h"

DNNE_EXTERN_C DNNE_API 
void DNNE_CALLTYPE csharp_log(char* msg) {
	printf("%s\n", msg);
}

int main(int argc, char** argv)
{
	load_managed_runtime();
	OnInit();
}
