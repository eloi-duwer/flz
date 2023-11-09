#define DEFINE_CONST
#include <flz-config.h>

static Window create_win_global() {
    XSetWindowAttributes xwa = { .background_pixel = WhitePixel(g_dis, g_screen), .event_mask = KeyPressMask | ButtonPressMask };

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

    // Wait for the window to be actually mapped
    XFlush(g_dis);
    usleep(30000);
    XSetInputFocus(g_dis, g_win, RevertToParent, CurrentTime);
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

static void    getWindowDimensions(Window win, int *dimensions) {
    XWindowAttributes attrs;

    XGetWindowAttributes(g_dis, win, &attrs);
    dimensions[0] = attrs.x;
    dimensions[1] = attrs.y;
    dimensions[2] = attrs.width;
    dimensions[3] = attrs.height;
}

Window create_win(Window parent, split_type split, float start_percent, float end_percent) {
    Window win;
    XSetWindowAttributes xwa = { .background_pixel = (double)rand(), .event_mask = KeyPressMask | ButtonPressMask };
    int dimensions[4];

    getWindowDimensions(parent, dimensions);
    int x = dimensions[0];
    int y = dimensions[1];
    int width = dimensions[2];
    int height = dimensions[3];

    // Positions are relative to parent
    int actual_x = (width * start_percent);
    int actual_y = y;
    int actual_width = width * (end_percent - start_percent);
    int actual_height = height;
    printf("Creating window with parent %lu: x %d y %d w %d h %d\n", parent, actual_x, actual_y, actual_width, actual_height);

    win = XCreateWindow(g_dis, parent,
        actual_x, actual_y, actual_width, actual_height, 0,
        DefaultDepth(g_dis, g_screen), InputOutput,
        g_vis, CWEventMask | CWBackPixel , &xwa
    );
    XMapWindow(g_dis, win);
    XFlush(g_dis);
    return win;
}

t_conf *find_backing_conf(t_conf *conf, Window win) {
    if (conf == NULL || conf->win == NO_WINDOW) {
        return NO_WINDOW;
    }
    if (conf->win == win) {
        return conf;
    }
    t_conf *ret = find_backing_conf(conf->left, win);
    if (ret != NULL) {
        return ret;
    }
    return find_backing_conf(conf->right, win);
}

void print_conf(t_conf *conf, int depth, char *lr) {
    printf("%*s|-> %s Window %ld\n", 2 * depth, "", lr, conf->win);
    if (conf->left != NULL) {
        print_conf(conf->left, depth + 1, "Left ");
    }
    if (conf->right != NULL) {
        print_conf(conf->right, depth + 1, "Right");
    }
}

void redraw_windows(t_conf *conf) {
    if (conf->left != NULL) {
        conf->left->win = create_win(conf->win, conf->split_type, 0.0f, conf->percent);
        redraw_windows(conf->left);
    }
    if (conf->right != NULL) {
        conf->right->win = create_win(conf->win, conf->split_type, conf->percent, 1.0f);
        redraw_windows(conf->right);
    }
}

void splitWindow(t_conf *conf_root, Window target_win) {
    t_conf *conf = find_backing_conf(conf_root, target_win);
    if (conf == NULL) {
        dprintf(2, "Window clicked %ld is not in our repertoried list\n", target_win);
        return;
    }
    conf->split_type = HORIZONTAL;
    conf->percent = 0.5f;
    conf->left = (t_conf *)malloc(sizeof(t_conf));
    conf->right = (t_conf *)malloc(sizeof(t_conf));
    memset(conf->left, 0, sizeof(t_conf));
    memset(conf->right, 0, sizeof(t_conf));
    conf->left->parent = conf;
    conf->right->parent = conf;
    conf->left->window_type = LEFT;
    conf->right->window_type = RIGHT;
    redraw_windows(conf);
}

void loop() {
    t_conf conf = {
        .win = create_win(g_win, NONE, 0.0f, 1.0f),
        .resize = NO_WINDOW,
        .split_type = NONE,
        .left = NULL,
        .right = NULL,
        .percent = 0.0f,
        .parent = NULL,
        .window_type = ALL
    };

    XEvent ev;

    while (True) {
        XNextEvent(g_dis, &ev);
        switch (ev.type) {
            case KeyPress:
                if (XkbKeycodeToKeysym(g_dis, ev.xkey.keycode, 0, ev.xkey.state & ShiftMask ? 1 : 0) == XK_Escape) {
                    return closeOverlay();
                }
                break;
            case ButtonPress:
                printf("Clicked Window: %lu\n", ev.xbutton.window);
                print_conf(&conf, 0, "root");
                splitWindow(&conf, ev.xbutton.window);
                break;
        }
    }

}

int main() {
    GC gc;

    getDefaults();
    create_win_global();
    loop();

    return 0;
}

