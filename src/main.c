#define DEFINE_CONST
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

void registerXInput2() {
	XIEventMask m;
	m.deviceid = XIAllMasterDevices;
	m.mask_len = XIMaskLen(XI_LASTEVENT);
	m.mask = calloc(m.mask_len, sizeof(char));
	XISetMask(m.mask, XI_RawKeyPress);
	XISetMask(m.mask, XI_RawKeyRelease);
	XISetMask(m.mask, XI_RawButtonPress);
	XISetMask(m.mask, XI_RawButtonRelease);
	XISetMask(m.mask, XI_RawMotion);
	XISelectEvents(g_dis, g_root, &m, 1);
	XSync(g_dis, false);
	free(m.mask);
}

void registerWindowMove() {
	XSelectInput(g_dis, g_root, SubstructureNotifyMask);
}

void handleOpenSnap(t_open_state *state) {
	if (!state->opened && state->configuring && state->ctrl_down) {
		state->opened = true;
		printf("Open\n");
		openOverlay();
	}
}

void handleCtrlUp(t_open_state *state) {
	state->ctrl_down = false;
	if (state->opened) {
		state->opened = false;
		printf("Cancel\n");
		closeOverlay();
	}
}

void handleButtonRelease(t_open_state *state) {
	Window	curr_focus_window;

	state->configuring = false;
	if (state->opened) {
		state->opened = false;
        state->has_configured = true;
		curr_focus_window = getActiveWindow();
		snap_window(curr_focus_window);
		closeOverlay();
	}
}

void handleMouseMotion(XGenericEventCookie *cookie) {
	t_pos pos;

	getCursorPos(&pos);
	// printf("Motion %d %d\n", pos.x, pos.y);
}

void loop() {
	XEvent	ev;
	XGenericEventCookie *cookie = (XGenericEventCookie*)&ev.xcookie;
	t_open_state state = {0};

	KeyCode	ctrll = XKeysymToKeycode(g_dis, XK_Control_L);
	KeyCode ctrlr = XKeysymToKeycode(g_dis, XK_Control_R);

	while (True) {
		XNextEvent(g_dis, &ev);
		if (XGetEventData(g_dis, cookie)) {
			if (cookie->type == GenericEvent && cookie->extension == g_xiOpcode) {
				if (cookie->evtype == XI_RawKeyPress
					&& (((XIRawEvent *)cookie->data)->detail == ctrll
						|| ((XIRawEvent *)cookie->data)->detail == ctrlr)) {
                            state.ctrl_down = true;
							handleOpenSnap(&state);
				}
				if (cookie->evtype == XI_RawKeyRelease
					&& (((XIRawEvent *)cookie->data)->detail == ctrll
						|| ((XIRawEvent *)cookie->data)->detail == ctrlr)) {
							handleCtrlUp(&state);
				}
				if (cookie->evtype == XI_RawButtonPress
					&& (((XIRawEvent *)cookie->data)->detail == Button1
						|| ((XIRawEvent *)cookie->data)->detail == Button3)) {
							// No op ?
				}
				if (cookie->evtype == XI_RawButtonRelease
					&& (((XIRawEvent *)cookie->data)->detail == Button1
						|| ((XIRawEvent *)cookie->data)->detail == Button3)) {
							handleButtonRelease(&state);
				}
				if (cookie->evtype == XI_RawMotion && state.opened) {
					handleMouseMotion(cookie);
				}
			}
		}
		if (ev.type == ConfigureNotify) {
            if (state.has_configured) {
                state.has_configured = false;
            } else {
			    state.configuring = true;
                handleOpenSnap(&state);
            }
		}
		XFreeEventData(g_dis, cookie);
	}
}

void getDefaults() {
	g_dis = XOpenDisplay(NULL);
	g_screen = XDefaultScreen(g_dis);
	g_root = DefaultRootWindow(g_dis);

	// Test for XInput 2 extension
	int queryEvent, queryError;
	if (!XQueryExtension(g_dis, "XInputExtension", &g_xiOpcode,
				&queryEvent, &queryError)) {
		fprintf(stderr, "X Input extension not available\n");
		exit(2);
	}
}

int main(int argc, char **argv) {
	getDefaults();
	registerXInput2();
	registerWindowMove();
	loop();
	return (0);
}