#include <flz.h>

static void    getWorkableArea(t_pos *xy, t_pos *wh) {
    unsigned long   nitems;
    long            *coords;

    getPropertyValue(g_root, "_NET_WORKAREA", 32 * 4, &nitems, (unsigned char **)&coords);

    xy->x = coords[0];
    xy->y = coords[1];
    wh->x = coords[2] - xy->x;
    wh->y = coords[3] - xy->y;
}

Window root_window(Window win) {
    Window root;
    Window parent;
    Window *childs;
    unsigned int nchilds;

    XTextProperty text;
    XGetWMName(g_dis, win, &text);
    if (text.value) {
        printf("Window %lx: %s\n", win, text.value);
    } else {
        printf("Window %lx has no name\n", win);
    }
    XQueryTree(g_dis, win, &root, &parent, &childs, &nchilds);
    if (childs) {
        int i = 0;
        while (i < nchilds) {
            XGetWMName(g_dis, win, &text);
            printf("| Child %lx: %s \n", childs[i], text.value);
            print_window_childs(childs[i], 2);
            i++;
        }
        XFree(childs);
    }
    if (parent && parent != root) {
        return root_window(parent);
    }
    return win;
}

void  snap_window(Window win) {
  t_pos		pos;
  int       slice_size;
  int       win_group;
  t_pos     xy;
  t_pos     wh;

  getCursorPos(&pos);
  getWorkableArea(&xy, &wh);

  slice_size = wh.x / zone_count;
  win_group = pos.x / slice_size;
  win = root_window(win);
  int x_return;
  int y_return;
  unsigned int _useless;
  Window _useless_too;
  // maybe xcb is better https://www.systutorials.com/docs/linux/man/3-xcb_get_geometry_reply/
  // Try to get the same values as xwininfo on -geometry https://gitlab.freedesktop.org/xorg/app/xwininfo/-/blob/master/xwininfo.c
  // Find a way to know if we need to find root window or not to actually move the window
  // TODO check what xdotools does
  // It looks like we're using the same window Ids, so the method used for resizing might be the solution (xdo_set_window_size, zdo_set_window_pos & xdo_move_window)
  XGetGeometry(g_dis, win, &_useless_too, &x_return, &y_return, &_useless, &_useless, &_useless, &_useless);
  printf("%d, %d\n", x_return, y_return);
  XMoveResizeWindow(g_dis, win, win_group * slice_size, 0, slice_size, 1390);
  printf("Snap to %d %d %d %d\n", win_group * slice_size, xy.y, slice_size, wh.y);
}