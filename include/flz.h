#ifndef __FLZ_H__
# define __FLZ_H__

#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/Xos.h>
#include <X11/Xatom.h>
#include <X11/extensions/shape.h>
#include <X11/extensions/Xfixes.h>
#include <X11/extensions/XInput2.h>
#include <stdio.h>
#include <stdbool.h>
#include <stdlib.h>


// Globals
Display       *g_dis;
GC	          g_gc;
Window        g_win;
Window	      g_root;
int	          g_screen;
int	          g_xiOpcode;

# ifdef DEFINE_CONST
const double	g_alpha = 0.2;
const char		*g_base_color = "#ffffff";
const unsigned int zone_count = 3;
# else
extern const double g_alpha;
extern const char   *g_base_color;
extern const unsigned int zone_count;
# endif

typedef struct  s_open_state {
  bool	ctrl_down;
	bool	configuring;
	bool	opened;
}               t_open_state;

typedef struct  s_pos {
  int x;
  int y;
}               t_pos;

// utils.c
unsigned long getColor(const char *colorString);
void          setAbove();
void          removeWindowInterface();
void          setTransparent(const double alpha);
void          setDontInterceptInputs();
Window        getActiveWindow();
int           getCurrDisplayWidth();
int           getCurrDisplayHeight();
void          getCursorPos(t_pos *ret_pos);
void          snap_window();

// window_positions.c


#endif