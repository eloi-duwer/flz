#ifndef __FLZ_CONFIG_H__
# define __FLZ_CONFIG_H__

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
#include <X11/XKBlib.h>

#define NO_WINDOW (Window)0

#ifdef DEFINE_CONST
    const double    g_alpha = 0.9;
    const int       g_margin = 20;
    const int       g_min_size = 100;
    // Globals
    Display *g_dis;
    GC      g_gc;
    Window  g_win;
    Window  g_root;
    int     g_screen;
    int     g_xiOpcode;
    Visual  *g_vis;
#else
    extern const double g_alpha;
    extern const int    g_margin;
    extern const int    g_min_size;
    extern Display  *g_dis;
    extern GC       g_gc;
    extern Window   g_win;
    extern Window   g_root;
    extern int      g_screen;
    extern Visual   *g_vis;
#endif

typedef enum    e_split_type {
    NONE,
    VERTICAL,
    HORIZONTAL
}               split_type;

typedef enum    e_window_type {
    ALL,
    TOP,
    BOTTOM,
    LEFT,
    RIGHT
}               window_type;
typedef struct  s_conf {
    Window          win;
    window_type     window_type;
    Window          resize;
    split_type      split_type;
    float           percent;
    struct s_conf   *parent;
    struct s_conf   *left;
    struct s_conf   *right;
}               t_conf;

// utils.c
unsigned long getColor(const char *colorString);
void          setAbove();
void          removeWindowInterface();
void          setTransparent(const double alpha);
Window        getActiveWindow();
int           getCurrDisplayWidth();
int           getCurrDisplayHeight();
void          getPropertyValue(Window win, char *propname, long max_length, unsigned long *nitems_return, unsigned char **prop_return);
void          print_window_childs(Window win, int depth);

#endif