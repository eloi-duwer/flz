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

#ifdef DEFINE_CONST
    // Globals
    Display       *g_dis;
    GC              g_gc;
    Window        g_win;
    Window          g_root;
    int              g_screen;
    int              g_xiOpcode;
#else
    extern Display  *g_dis;
    extern GC       g_gc;
    extern Window   g_win;
    Window          g_root;
    extern int      g_screen;
#endif

#endif