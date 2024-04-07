#define DEFINE_CONST
#include <flz.h>

void registerXInput2() {
    XIEventMask m;
    m.deviceid = XIAllMasterDevices;
    m.mask_len = XIMaskLen(XI_LASTEVENT);
    m.mask = calloc(m.mask_len, sizeof(char));
    // We want to get notified by key press, key release, button press, button release, mouse motion
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
    // Get notified when a window is reconfigured (= moved/resized)
    XSelectInput(g_dis, g_root, SubstructureNotifyMask);
}

void handleOpenSnap(t_open_state *state) {
    // Open the overlay only if we're not already & if we're configuring while ctrl is down
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
    Window  curr_focus_window;

    state->configuring = false;
    if (state->opened) {
        printf("Close\n");
        state->opened = false;
        state->n_configuring++;
        curr_focus_window = getActiveWindow();
        snap_window(curr_focus_window, &state->n_configuring);
        closeOverlay();
    }
}

void handleMouseMotion(XGenericEventCookie *cookie) {
    t_pos   pos;

    getCursorPos(&pos);
    // printf("Motion %d %d\n", pos.x, pos.y);
}

void loop() {
    XEvent  ev;
    XGenericEventCookie *cookie = (XGenericEventCookie*)&ev.xcookie;
    t_open_state    state = {0};

    KeyCode    ctrll = XKeysymToKeycode(g_dis, XK_Control_L);
    KeyCode ctrlr = XKeysymToKeycode(g_dis, XK_Control_R);

    while (True) {
        XNextEvent(g_dis, &ev);
        if (XGetEventData(g_dis, cookie)) {
            if (cookie->type == GenericEvent && cookie->extension == g_xiOpcode) {
                if (cookie->evtype == XI_RawKeyPress
                    && (((XIRawEvent *)cookie->data)->detail == ctrll
                        || ((XIRawEvent *)cookie->data)->detail == ctrlr)) {
                            // Pressing ctrl right or left
                            state.ctrl_down = true;
                            handleOpenSnap(&state);
                }
                if (cookie->evtype == XI_RawKeyRelease
                    && (((XIRawEvent *)cookie->data)->detail == ctrll
                        || ((XIRawEvent *)cookie->data)->detail == ctrlr)) {
                            // Releasing crtl right or left
                            handleCtrlUp(&state);
                }
                if (cookie->evtype == XI_RawButtonPress
                    && (((XIRawEvent *)cookie->data)->detail == Button1
                        || ((XIRawEvent *)cookie->data)->detail == Button3)) {
                            // Left or Right mouse click
                            // No op ?
                }
                if (cookie->evtype == XI_RawButtonRelease
                    && (((XIRawEvent *)cookie->data)->detail == Button1
                        || ((XIRawEvent *)cookie->data)->detail == Button3)) {
                            // Left or Right mouse release
                            handleButtonRelease(&state);
                }
                if (cookie->evtype == XI_RawMotion && state.opened) {
                    // Mouse moved
                    handleMouseMotion(cookie);
                }
            }
        }
        if (ev.type == ConfigureNotify) {
            // Configuring (= We're moving or resizing the window)
            // Since we end up moving/resizing windows ourselves, we want to skip the next n events after a snap
            // (We need to move the window + all it's parents, so it can send multiple configure events)
            if (state.n_configuring > 0) {
                state.n_configuring--;
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
    g_root = XDefaultRootWindow(g_dis);

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