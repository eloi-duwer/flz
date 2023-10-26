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

static void getWindowMargins(Window win, t_margins *margins) {
    unsigned long nitems;
    unsigned char *prop;
    getPropertyValue(win, "_GTK_FRAME_EXTENTS", 4, &nitems, &prop);
    if (nitems == 0) {
        margins->left = 0;
        margins->right = 0;
        margins->top = 0;
        margins->bottom = 0;
    } else {
        unsigned long *nums = (unsigned long *)prop;
        margins->left = nums[0];
        margins->right = nums[1];
        margins->top = nums[2];
        margins->bottom = nums[3];
    }
    printf("Margins: l: %lu, t: %lu, r: %lu, b: %lu\n", margins->left, margins->top, margins->right, margins->bottom);
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

void snap_to_with_parents(int *n_configured, Window win, int x, int y, int width, int height) {
    Window parent;
    t_margins margins;

    (*n_configured)++;
    getWindowMargins(win, &margins);
    printf("Snaping %ld to %d %d %d %d\n", win, x, y, width, height);
    XMoveResizeWindow(g_dis, win, x - margins.right, y - margins.top, width + margins.right + margins.left, height + margins.top + margins.bottom);
    if (get_parent_window(win, &parent) == 0 && *n_configured < 10) {
        snap_to_with_parents(n_configured, parent, x, y, width, height);
    }
}

void  snap_window(Window win, int *n_configured) {
    t_pos		pos;
    int       slice_size;
    int       win_group;
    t_pos     xy;
    t_pos     wh;

    getCursorPos(&pos);
    getWorkableArea(&xy, &wh);

    slice_size = wh.x / zone_count;
    win_group = pos.x / slice_size;

    snap_to_with_parents(n_configured, win, win_group * slice_size, 0, slice_size, wh.y);
}