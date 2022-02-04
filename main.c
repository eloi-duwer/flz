#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/Xos.h>
#include <X11/Xatom.h>
#include <X11/extensions/Xcomposite.h>
#include <stdio.h>

Display	*dis;
GC		gc;
Window	win;
int		screen;

Display *open_display() {
	unsigned long	black, white;

	dis = XOpenDisplay(NULL);
	screen = DefaultScreen(dis);
	black = BlackPixel(dis, screen);
	white = WhitePixel(dis, screen);

	XVisualInfo vinfo;
	XMatchVisualInfo(dis, screen, 32, TrueColor, &vinfo);

	win = XCompositeGetOverlayWindow(dis, DefaultRootWindow(dis));

	// win = XCreateSimpleWindow(dis, DefaultRootWindow(dis), 0, 0, 500, 400, 5, white, white);

	/*double alpha = 0.2;
	unsigned long opacity = (unsigned long)(0xFFFFFFFFul * alpha);
	Atom XA_NET_WM_WINDOW_OPACITY = XInternAtom(dis, "_NET_WM_WINDOW_OPACITY", False);
	XChangeProperty(dis, win, XA_NET_WM_WINDOW_OPACITY, XA_CARDINAL, 32, PropModeReplace, (unsigned char *)&opacity, 1L);*/

	/*Atom type = XInternAtom(dis,"_NET_WM_WINDOW_TYPE", False);
    Atom value = XInternAtom(dis,"_NET_WM_WINDOW_TYPE_SPLASH", False);
	XChangeProperty(dis, win, type, XA_ATOM, 32, PropModeReplace, (unsigned char *)&value, 1);*/

	XSetStandardProperties(dis, win, "window", "lol", None, NULL, 0, NULL);
	XSelectInput(dis, win, ExposureMask | ButtonPressMask | KeyPressMask);
	gc = XCreateGC(dis, win, 0, 0);

	XClearWindow(dis, win);
	XMapRaised(dis, win);

	return (dis);
}

void close_x() {
	XFreeGC(dis, gc);
	XDestroyWindow(dis, win);
	XCloseDisplay(dis);
}

void redraw() {
	unsigned long white = WhitePixel(dis, screen);
	XSetBackground(dis, gc, BlackPixel(dis, screen));
	XSetForeground(dis, gc, white);
	XFillRectangle(dis, win, gc, 0, 0, 300, 200);
}

int main(int argc, char **argv) {

	Display	*dis;
	XEvent	event;
	KeySym	key;
	char	text[255];


	dis = open_display();
	while (1) {
		XNextEvent(dis, &event);

		if (event.type == Expose && event.xexpose.count == 0) {
			redraw();
		} else if (event.type == KeyPress && XLookupString(&event.xkey, text, 255, &key, 0) == 1) {
			if (text[0] == 'q' || text[0] == 27) {
				close_x();
				return (0);
			}
		}
		if (event.type == ButtonPress) {
			printf("Click %d %d\n", event.xbutton.x, event.xbutton.y);
		}
	}

	return (0);
}