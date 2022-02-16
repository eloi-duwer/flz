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
  XMoveResizeWindow(g_dis, win, win_group * slice_size, 0, slice_size, 1390);
  printf("Snap to %d %d %d %d\n", win_group * slice_size, xy.y, slice_size, wh.y);
}