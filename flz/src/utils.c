#include <flz.h>

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

void setDontInterceptInputs() {
    XRectangle rect;
    XserverRegion region = XFixesCreateRegion(g_dis, &rect, 1);
    XFixesSetWindowShapeRegion(g_dis, g_win, ShapeInput, 0, 0, region);
    XFixesDestroyRegion(g_dis, region);
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

void getCursorPos(t_pos *ret_pos) {
    Window        _root;
    Window          _win;
    int                  _x;
    int                  _y;
    unsigned int  _mask;

    XQueryPointer(g_dis, g_root, &_root, &_win, &ret_pos->x, &ret_pos->y, &_x, &_y, &_mask);
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