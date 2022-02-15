#include <flz.h>

void  snap_window(Window win) {
  t_pos		pos;
  int     slice_size;
  int     win_group;

  getCursorPos(&pos);

  // TODO maybe use NET_WORKAREA property to get screen usable real estate

  slice_size = getCurrDisplayWidth() / zone_count;
  win_group = pos.x / slice_size;
  XMoveResizeWindow(g_dis, win, win_group * slice_size, 0, slice_size, getCurrDisplayHeight());
  printf("Snap to %d %d %d %d\n", win_group * slice_size, 0, slice_size, getCurrDisplayHeight());
}