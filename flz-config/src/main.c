#define DEFINE_CONST
#include <flz-config.h>

static Window create_win() {
	unsigned long   white;
    XSetWindowAttributes xwa = { .background_pixel = WhitePixel(g_dis, g_screen), .event_mask = KeyPressMask };

    white = WhitePixel(g_dis, g_screen);

    XVisualInfo vinfo;
    XMatchVisualInfo(g_dis, g_screen, 32, TrueColor, &vinfo);
    g_win = XCreateWindow(g_dis, DefaultRootWindow(g_dis),
        0, 0, 42, 42, 42,
        DefaultDepth(g_dis, g_screen), InputOutput,
        g_vis, CWEventMask | CWBackPixel , &xwa
    );
    g_gc = XCreateGC(g_dis, g_win, 0, 0);

    setTransparent(g_alpha);
    removeWindowInterface();

    XClearWindow(g_dis, g_win);
    XMapWindow(g_dis, g_win);
    setAbove();

    XMoveResizeWindow(g_dis, g_win, 0, 0, getCurrDisplayWidth(), getCurrDisplayHeight());
}

void getDefaults() {
    g_dis = XOpenDisplay(NULL);
    g_screen = XDefaultScreen(g_dis);
    g_root = XDefaultRootWindow(g_dis);
    g_vis = XDefaultVisual(g_dis, g_screen);

    // Test for XInput 2 extension
    int queryEvent, queryError;
    if (!XQueryExtension(g_dis, "XInputExtension", &g_xiOpcode,
                &queryEvent, &queryError)) {
        fprintf(stderr, "X Input extension not available\n");
        exit(2);
    }
}

void closeOverlay() {
    XFreeGC(g_dis, g_gc);
    XDestroyWindow(g_dis, g_win);
}

void loop() {
    XEvent ev;

    while (True) {
        XNextEvent(g_dis, &ev);
        switch (ev.type) {
            case KeyPress:
                if (XkbKeycodeToKeysym(g_dis, ev.xkey.keycode, 0, ev.xkey.state & ShiftMask ? 1 : 0) == XK_Escape) {
                    return closeOverlay();
                }
                break;
        }
    }

}

int main() {
    GC gc;

    getDefaults();
    create_win();
    loop();

    return 0;
}

