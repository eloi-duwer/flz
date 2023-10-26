#include <flz.h>

Display *openOverlay() {
	unsigned long	white;

	white = WhitePixel(g_dis, g_screen);

	XVisualInfo vinfo;
	XMatchVisualInfo(g_dis, g_screen, 32, TrueColor, &vinfo);
	g_win = XCreateSimpleWindow(g_dis, DefaultRootWindow(g_dis), 0, 0, 42, 42, 42, white, getColor(g_base_color));
	g_gc = XCreateGC(g_dis, g_win, 0, 0);

	setTransparent(g_alpha);
	removeWindowInterface();
	setDontInterceptInputs();

	XClearWindow(g_dis, g_win);
	XMapWindow(g_dis, g_win);
	setAbove();

	XMoveResizeWindow(g_dis, g_win, 0, 0, getCurrDisplayWidth(), getCurrDisplayHeight());

	return (g_dis);
}

void closeOverlay() {
	XFreeGC(g_dis, g_gc);
	XDestroyWindow(g_dis, g_win);
}