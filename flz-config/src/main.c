#define DEFINE_CONST
#include <flz-config.h>

void getDefaults() {
    g_dis = XOpenDisplay(NULL);
    g_screen = XDefaultScreen(g_dis);
    g_root = XDefaultRootWindow(g_dis);

    // Test for XInput 2 extension
    int queryEvent, queryError;
    if (!XQueryExtension(g_dis, "XInputExtension", &g_xiOpcode,
                &queryEvent, &queryError)) {
        fprintf(stderr, "X Input extension not available\n");
        exit(2);
    }
}

int main() {
    GC gc;

    g_dis = XOpenDisplay(NULL);


    return 0;
}

