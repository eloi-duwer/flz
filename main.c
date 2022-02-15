#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/Xos.h>
#include <X11/Xatom.h>
#include <X11/extensions/shape.h>
#include <X11/extensions/Xfixes.h>
#include <X11/extensions/XInput2.h>
#include <stdio.h>
#include <stdbool.h>
#include <stdlib.h>

Display	*dis;
GC		gc;
Window	win;
Window	root;
int		screen;
int		xiOpcode;
const double	alpha = 0.2;
const char		*base_color = "#ffffff";

// call AFTER the window is shown with XMapRaised
void setAbove() {
	XEvent event;
	Atom wm_state = XInternAtom(dis, "_NET_WM_STATE", False);
	Atom wm_state_above = XInternAtom(dis, "_NET_WM_STATE_ABOVE", False);
	XChangeProperty(dis, win, wm_state, XA_ATOM, 32, PropModeReplace, (unsigned char *)&wm_state_above, 1);
}

void removeWindowInterface() {
	Atom type = XInternAtom(dis,"_NET_WM_WINDOW_TYPE", False);
    Atom value = XInternAtom(dis,"_NET_WM_WINDOW_TYPE_SPLASH", False);
	XChangeProperty(dis, win, type, XA_ATOM, 32, PropModeReplace, (unsigned char *)&value, 1);
}

void setTransparent() {
	unsigned long opacity = (unsigned long)(0xFFFFFFFFul * alpha);
	Atom XA_NET_WM_WINDOW_OPACITY = XInternAtom(dis, "_NET_WM_WINDOW_OPACITY", False);
	XChangeProperty(dis, win, XA_NET_WM_WINDOW_OPACITY, XA_CARDINAL, 32, PropModeReplace, (unsigned char *)&opacity, 1L);
}

void setDontInterceptInputs() {
	XRectangle rect;
	XserverRegion region = XFixesCreateRegion(dis, &rect, 1);
	XFixesSetWindowShapeRegion(dis, win, ShapeInput, 0, 0, region);
	XFixesDestroyRegion(dis, region);
}

unsigned long getColor(const char *colorString) {
	XColor color;
	Colormap colormap;

	colormap = DefaultColormap(dis, 0);
	XParseColor(dis, colormap, colorString, &color);
	XAllocColor(dis, colormap, &color);
	return color.pixel;
}

Display *open_overlay() {
	unsigned long	white;

	white = WhitePixel(dis, screen);

	XVisualInfo vinfo;
	XMatchVisualInfo(dis, screen, 32, TrueColor, &vinfo);
	win = XCreateSimpleWindow(dis, DefaultRootWindow(dis), 0, 0, 42, 42, 42, white, getColor(base_color));
	gc = XCreateGC(dis, win, 0, 0);

	setTransparent();
	removeWindowInterface();
	setDontInterceptInputs();

	XClearWindow(dis, win);
	XMapWindow(dis, win);
	setAbove();

	XMoveResizeWindow(dis, win, 0, 0, DisplayWidth(dis, screen), DisplayHeight(dis, screen));

	return (dis);
}

void close_overlay() {
	XFreeGC(dis, gc);
	XDestroyWindow(dis, win);
}

void register_keys() {
	XIEventMask m;
	m.deviceid = XIAllMasterDevices;
	m.mask_len = XIMaskLen(XI_LASTEVENT);
	m.mask = calloc(m.mask_len, sizeof(char));
	XISetMask(m.mask, XI_RawKeyPress);
	XISetMask(m.mask, XI_RawKeyRelease);
	XISetMask(m.mask, XI_RawButtonPress);
	XISetMask(m.mask, XI_RawButtonRelease);
	XISelectEvents(dis, root, &m, 1);
	XSync(dis, false);
	free(m.mask);
}

void register_window_move() {
	XSelectInput(dis, root, SubstructureNotifyMask);
}

void loop() {
	XEvent	ev;
	XGenericEventCookie *cookie = (XGenericEventCookie*)&ev.xcookie;
	bool	ctrl_down = false;
	bool	configuring = false;
	bool	opened = false;

	KeyCode	ctrll = XKeysymToKeycode(dis, XK_Control_L);
	KeyCode ctrlr = XKeysymToKeycode(dis, XK_Control_R);

	while (True) {
		XNextEvent(dis, &ev);
		if (XGetEventData(dis, cookie)) {
			if (cookie->type == GenericEvent && cookie->extension == xiOpcode) {
                if (cookie->evtype == XI_RawKeyPress
					&& (((XIRawEvent *)cookie->data)->detail == ctrll
						|| ((XIRawEvent *)cookie->data)->detail == ctrlr)) {
							ctrl_down = true;
							if (!opened && configuring && ctrl_down) {
								opened = true;
								printf("Open\n");
								open_overlay();
							}
				}
				if (cookie->evtype == XI_RawKeyRelease
					&& (((XIRawEvent *)cookie->data)->detail == ctrll
						|| ((XIRawEvent *)cookie->data)->detail == ctrlr)) {
							ctrl_down = false;
							if (opened) {
								opened = false;
								printf("Cancel\n");
								close_overlay();
							}
				}
				if (cookie->evtype == XI_RawButtonPress
					&& (((XIRawEvent *)cookie->data)->detail == Button1
						|| ((XIRawEvent *)cookie->data)->detail == Button3)) {
					// No op ?
				}
				if (cookie->evtype == XI_RawButtonRelease
					&& (((XIRawEvent *)cookie->data)->detail == Button1
						|| ((XIRawEvent *)cookie->data)->detail == Button3)) {
							configuring = false;
							if (opened) {
								opened = false;
								printf("Snap\n");
								close_overlay();
							}
				}
			}
		}
		if (ev.type == ConfigureNotify) {
			configuring = true;
		}
		XFreeEventData(dis, cookie);
	}
}

void getDefaults() {
	dis = XOpenDisplay(NULL);
	screen = XDefaultScreen(dis);
	root = DefaultRootWindow(dis);

	// Test for XInput 2 extension
	int queryEvent, queryError;
	if (!XQueryExtension(dis, "XInputExtension", &xiOpcode,
				&queryEvent, &queryError)) {
		fprintf(stderr, "X Input extension not available\n");
		exit(2);
	}
}

int main(int argc, char **argv) {
	getDefaults();
	register_keys();
	register_window_move();
	loop();
	return (0);
}