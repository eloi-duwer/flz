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

static void getWindowMargins(Window win) {
    unsigned long nitems;
    unsigned char *prop;
    getPropertyValue(win, "_GTK_FRAME_EXTENTS", 4, &nitems, &prop);
    if (nitems == 0) {
        printf("Can't find margins\n");
    } else {
        unsigned long *nums = (unsigned long *)prop;
        printf("margins: %lu %lu %lu %lu\n", nums[0], nums[1], nums[2], nums[3]);
    }
}

Window root_window(Window win) {
    Window root;
    Window parent;
    Window *childs;
    unsigned int nchilds;

    XTextProperty text;
    XGetWMName(g_dis, win, &text);
    if (text.value) {
        printf("Window %ld: %s\n", win, text.value);
    } else {
        printf("Window %ld has no name\n", win);
    }
    XQueryTree(g_dis, win, &root, &parent, &childs, &nchilds);
    if (childs) {
        int i = 0;
        while (i < nchilds) {
            XGetWMName(g_dis, win, &text);
            printf("| Child %ld: %s \n", childs[i], text.value);
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

int get_parent_window (Window win, Window *ret_win) {
    Window root;
    Window parent;
    Window *childs;
    unsigned int nchilds;

    XQueryTree(g_dis, win, &root, &parent, &childs, &nchilds);

        if (childs) {
        XFree(childs);
    }
    if (parent != root) {
        *ret_win = parent;
        return 0;
    }
    return 1;
}

void print_attributes(Window win) {
    XWindowAttributes attrs;

    XGetWindowAttributes(g_dis, win, &attrs);
    printf("Window attributes after placement (relative to its parent): x %d y %d w %d h %d\n", attrs.x, attrs.y, attrs.width, attrs.height);
}

void snap_to_with_parents(Window win, int x, int y, int width, int height) {
    Window parent;

    printf("Snaping %ld to %d %d %d %d\n", win, x, y, width, height);
    getWindowMargins(win);
    print_attributes(win);
    XMoveResizeWindow(g_dis, win, x, y, width, height);
    if (get_parent_window(win, &parent) == 0) {
        snap_to_with_parents(parent, x, y, width, height);
    }
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

  // win = root_window(win);

    snap_to_with_parents(win,  win_group * slice_size, 0, slice_size, wh.y);
}