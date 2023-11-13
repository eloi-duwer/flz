#include <flz-config.h>

const double    alpha = 0.2;
const char        *base_color = "#ffffff";

unsigned long getColor(const char *colorString) {
    XColor color;
    Colormap colormap;

    colormap = DefaultColormap(g_dis, 0);
    XParseColor(g_dis, colormap, colorString, &color);
    XAllocColor(g_dis, colormap, &color);
    return color.pixel;
}

// call AFTER the window is shown with XMapRaised
void setAbove() {
    XEvent event;
    Atom wm_state = XInternAtom(g_dis, "_NET_WM_STATE", False);
    Atom wm_state_above = XInternAtom(g_dis, "_NET_WM_STATE_ABOVE", False);
    XChangeProperty(g_dis, g_win, wm_state, XA_ATOM, 32, PropModeReplace, (unsigned char *)&wm_state_above, 1);
}

void removeWindowInterface() {
    Atom type = XInternAtom(g_dis,"_NET_WM_WINDOW_TYPE", False);
  Atom value = XInternAtom(g_dis,"_NET_WM_WINDOW_TYPE_SPLASH", False);
    XChangeProperty(g_dis, g_win, type, XA_ATOM, 32, PropModeReplace, (unsigned char *)&value, 1);
}

void setTransparent(const double alpha) {
    unsigned long opacity = (unsigned long)(0xFFFFFFFFul * alpha);
    Atom atom_opacity = XInternAtom(g_dis, "_NET_WM_WINDOW_OPACITY", False);
    XChangeProperty(g_dis, g_win, atom_opacity, XA_CARDINAL, 32, PropModeReplace, (unsigned char *)&opacity, 1L);
}

Window getActiveWindow() {
  Window  focused;
  int     revert;

  XGetInputFocus(g_dis, &focused, &revert);
  return focused;
}

int getCurrDisplayWidth() {
  return DisplayWidth(g_dis, g_screen);
}

int getCurrDisplayHeight() {
    return DisplayHeight(g_dis, g_screen);
}

void getPropertyValue(Window win, char *propname, long max_length, unsigned long *nitems_return, unsigned char **prop_return)
{
    int result;
    Atom property;
    Atom actual_type_return;
    int actual_format_return;
    unsigned long bytes_after_return;

    property = XInternAtom(g_dis, propname, True);

    result = XGetWindowProperty(g_dis, win, property, 0,    /* offset */
                max_length,    /* length */
                False,    /* delete */
                AnyPropertyType,    /* req_type */
                &actual_type_return,
                &actual_format_return,
                nitems_return, &bytes_after_return, prop_return);
}

void print_window_childs(Window win, int depth) {
    Window root;
    Window parent;
    Window *childs;
    unsigned int nchilds;
    XTextProperty text;

    XQueryTree(g_dis, win, &root, &parent, &childs, &nchilds);
    if (childs) {
        int i = 0;
        while (i < nchilds) {
            XGetWMName(g_dis, win, &text);
            printf("%*s", depth, "");
            printf("| ");
            printf("Child %ld: %s \n", childs[i], text.value);
            print_window_childs(childs[i], depth + 2);
            i++;
        }
        XFree(childs);
    }
}

void print_conf(t_conf *conf, int depth, char *lr) {
    printf("%*s|-> %s Window %ld\n", 2 * depth, "", lr, conf->win);
    if (conf->left != NULL) {
        print_conf(conf->left, depth + 1, conf->split_type == VERTICAL ? "Left  " : "Top   ");
    }
    if (conf->right != NULL) {
        print_conf(conf->right, depth + 1, conf->split_type == VERTICAL ? "Right " : "Bottom");
    }
}

void    getWindowDimensions(Window win, t_window_pos *pos) {
    XWindowAttributes attrs;

    XGetWindowAttributes(g_dis, win, &attrs);
    pos->x = attrs.x;
    pos->y = attrs.y;
    pos->w = attrs.width;
    pos->h = attrs.height;
}

void calcWindowNeededDimensions(Window parent, split_type split, float start_percent, float end_percent, t_window_pos *pos) {
    t_window_pos parent_pos;
    getWindowDimensions(parent, &parent_pos);

    // Positions are relative to parent
    if (split == VERTICAL) {
        pos->x = parent_pos.w * start_percent;
        pos->y = 0;
        pos->w = parent_pos.w * (end_percent - start_percent);
        pos->h = parent_pos.h;
    } else {
        pos->x = 0;
        pos->y = parent_pos.h * start_percent;
        pos->w = parent_pos.w;
        pos->h = parent_pos.h * (end_percent - start_percent);
    }
}