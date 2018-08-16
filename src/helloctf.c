#include <string.h>

typedef struct ctf_proto {
	int a;
	int b;
	int c;
	char d[10];
} ctf_proto_t;

int
main(int argc, char *argv[])
{
	ctf_proto_t dummy;
	(void) memset(&dummy, 0, sizeof (ctf_proto_t));
	return (0);
}
