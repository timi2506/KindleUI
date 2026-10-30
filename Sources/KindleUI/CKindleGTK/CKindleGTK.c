#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif
#include "CKindleGTK.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#if !defined(_WIN32)
#include <dlfcn.h>
#include <pthread.h>
#include <unistd.h>
#include <ctype.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#endif

typedef struct {
    uint32_t pixel;
    uint16_t red;
    uint16_t green;
    uint16_t blue;
} KGdkColor;

typedef struct _KGList {
    void* data;
    struct _KGList* next;
    struct _KGList* prev;
} KGList;

typedef struct {
    int x;
    int y;
    int width;
    int height;
} KGtkAllocation;

typedef struct {
    int width;
    int height;
} KGtkRequisition;

#if !defined(_WIN32)
static void* g_gtk_lib = NULL;
static void* g_gdk_lib = NULL;
static void* g_gobj_lib = NULL;
static void* g_glib_lib = NULL;
static void* g_pango_lib = NULL;
static void* g_cairo_lib = NULL;
static void* g_lipc_lib = NULL;
static void* g_webkit_lib = NULL;
static void* g_gthread_lib = NULL;
static void* g_curl_lib = NULL;

static void kgtk_detach_cached_webviews(void);

static bool g_slider_dragging = false;
static bool g_gesture_dragging = false;
static bool g_canvas_dragging = false;
static double g_last_scroll_y = 0.0;
static double g_pending_scroll_restore = 0.0;
static bool g_scroll_reset_requested = false;
static bool g_scroll_tracking_enabled = true;
static int g_window_freeze_depth = 0;
static KWidgetRef g_active_scrolled_window = NULL;
static KWidgetRef g_active_modal_scrolled_window = NULL;
static bool g_has_frozen_scroll = false;
static KWindowKeyCallback g_global_key_handler = NULL;
static void* g_global_key_user_data = NULL;

typedef struct {
    KWidgetRef active_sw;
    KWidgetRef source_widget;
    bool active;
    bool threshold_crossed;
    double start_root_y;
    double anchor_root_y;
    double last_root_y;
    double start_scroll_val;
} KGlobalScrollDrag;

static KGlobalScrollDrag g_scroll_drag = { NULL, NULL, false, false, 0.0, 0.0, 0.0, 0.0 };

#if defined(__arm__) && defined(KINDLE_SOFTFP)
#define KGTK_ABI __attribute__((pcs("aapcs")))
#else
#define KGTK_ABI
#endif

// Function pointer typedefs
typedef int (KGTK_ABI *fn_gtk_init_check)(int*, char***);
typedef void (KGTK_ABI *fn_gtk_main)(void);
typedef void (KGTK_ABI *fn_gtk_main_quit)(void);
typedef int (KGTK_ABI *fn_gtk_events_pending)(void);
typedef int (KGTK_ABI *fn_gtk_main_iteration_do)(int);
typedef unsigned int (KGTK_ABI *fn_g_idle_add)(int (*)(void*), void*);
typedef unsigned int (KGTK_ABI *fn_g_idle_add_full)(int, int (*)(void*), void*, void (*)(void*));

typedef KWidgetRef (KGTK_ABI *fn_gtk_window_new)(int);
typedef void (KGTK_ABI *fn_gtk_window_set_title)(KWidgetRef, const char*);
typedef void (KGTK_ABI *fn_gtk_window_set_default_size)(KWidgetRef, int, int);
typedef void (KGTK_ABI *fn_gtk_window_set_position)(KWidgetRef, int);
typedef void (KGTK_ABI *fn_gtk_window_fullscreen)(KWidgetRef);

typedef KWidgetRef (KGTK_ABI *fn_gtk_box_new_2)(int, int);
typedef void (KGTK_ABI *fn_gtk_box_pack_start)(KWidgetRef, KWidgetRef, int, int, unsigned int);
typedef void (KGTK_ABI *fn_gtk_container_add)(KWidgetRef, KWidgetRef);
typedef void (KGTK_ABI *fn_gtk_container_remove)(KWidgetRef, KWidgetRef);
typedef KGList* (KGTK_ABI *fn_gtk_container_get_children)(KWidgetRef);
typedef void (KGTK_ABI *fn_gtk_container_set_border_width)(KWidgetRef, unsigned int);
typedef void (KGTK_ABI *fn_gtk_container_check_resize)(KWidgetRef);
typedef void (KGTK_ABI *fn_gtk_widget_size_allocate)(KWidgetRef, KGtkAllocation*);
typedef void (KGTK_ABI *fn_gtk_container_propagate_expose)(KWidgetRef, KWidgetRef, void*);
typedef void (KGTK_ABI *fn_gdk_window_freeze_updates)(void*);
typedef void (KGTK_ABI *fn_gdk_window_thaw_updates)(void*);
typedef void (KGTK_ABI *fn_gdk_window_process_all_updates)(void);
typedef void (KGTK_ABI *fn_gdk_window_process_updates)(void*, int);
typedef void (KGTK_ABI *fn_gdk_flush)(void);
typedef void* (KGTK_ABI *fn_gdk_region_rectangle)(const KGtkAllocation*);
typedef void (KGTK_ABI *fn_gdk_region_destroy)(void*);
typedef void (KGTK_ABI *fn_gdk_gc_set_clip_rectangle)(void*, const KGtkAllocation*);
typedef void (KGTK_ABI *fn_cairo_clip)(void*);
typedef void (KGTK_ABI *fn_g_list_free)(KGList*);

typedef KWidgetRef (KGTK_ABI *fn_gtk_alignment_new)(float, float, float, float);
typedef void (KGTK_ABI *fn_gtk_alignment_set_padding)(KWidgetRef, unsigned int, unsigned int, unsigned int, unsigned int);
typedef KWidgetRef (KGTK_ABI *fn_gtk_frame_new)(const char*);
typedef void (KGTK_ABI *fn_gtk_frame_set_shadow_type)(KWidgetRef, int);
typedef KWidgetRef (KGTK_ABI *fn_gtk_frame_get_label_widget)(KWidgetRef);
typedef KWidgetRef (KGTK_ABI *fn_gtk_bin_get_child)(KWidgetRef);
typedef KWidgetRef (KGTK_ABI *fn_gtk_scrolled_window_new)(void*, void*);
typedef void (KGTK_ABI *fn_gtk_scrolled_window_set_policy)(KWidgetRef, int, int);
typedef void (KGTK_ABI *fn_gtk_scrolled_window_add_with_viewport)(KWidgetRef, KWidgetRef);
typedef void* (KGTK_ABI *fn_gtk_scrolled_window_get_vadjustment)(KWidgetRef);
typedef double (KGTK_ABI *fn_gtk_adjustment_get_value)(void*);
typedef void (KGTK_ABI *fn_gtk_adjustment_set_value)(void*, double);
typedef double (KGTK_ABI *fn_gtk_adjustment_get_upper)(void*);
typedef double (KGTK_ABI *fn_gtk_adjustment_get_page_size)(void*);
typedef void (KGTK_ABI *fn_gtk_viewport_set_shadow_type)(KWidgetRef, int);
typedef KWidgetRef (KGTK_ABI *fn_gtk_event_box_new)(void);
typedef void (KGTK_ABI *fn_gtk_event_box_set_visible_window)(KWidgetRef, int);
typedef void (KGTK_ABI *fn_gtk_event_box_set_above_child)(KWidgetRef, int);
typedef KWidgetRef (KGTK_ABI *fn_gtk_table_new)(unsigned int, unsigned int, int);
typedef void (KGTK_ABI *fn_gtk_table_attach)(KWidgetRef, KWidgetRef, unsigned int, unsigned int, unsigned int, unsigned int, int, int, unsigned int, unsigned int);
typedef void (KGTK_ABI *fn_gtk_widget_set_sensitive)(KWidgetRef, int);
typedef void (KGTK_ABI *fn_gtk_widget_set_redraw_on_allocate)(KWidgetRef, int);
typedef void (KGTK_ABI *fn_cairo_set_source_rgba)(void*, double, double, double, double);

typedef KWidgetRef (KGTK_ABI *fn_gtk_label_new)(const char*);
typedef void (KGTK_ABI *fn_gtk_label_set_text)(KWidgetRef, const char*);
typedef void (KGTK_ABI *fn_gtk_label_set_markup)(KWidgetRef, const char*);
typedef void (KGTK_ABI *fn_gtk_label_set_line_wrap)(KWidgetRef, int);
typedef void (KGTK_ABI *fn_gtk_label_set_justify)(KWidgetRef, int);
typedef void (KGTK_ABI *fn_gtk_misc_set_alignment)(KWidgetRef, float, float);

typedef KWidgetRef (KGTK_ABI *fn_gtk_button_new_with_label)(const char*);
typedef void (KGTK_ABI *fn_gtk_button_set_label)(KWidgetRef, const char*);

typedef KWidgetRef (KGTK_ABI *fn_gtk_check_button_new_with_label)(const char*);
typedef int (KGTK_ABI *fn_gtk_toggle_button_get_active)(KWidgetRef);
typedef void (KGTK_ABI *fn_gtk_toggle_button_set_active)(KWidgetRef, int);

typedef KWidgetRef (KGTK_ABI *fn_gtk_entry_new)(void);
typedef void (KGTK_ABI *fn_gtk_entry_set_text)(KWidgetRef, const char*);
typedef const char* (KGTK_ABI *fn_gtk_entry_get_text)(KWidgetRef);

typedef KWidgetRef (KGTK_ABI *fn_gtk_progress_bar_new)(void);
typedef void (KGTK_ABI *fn_gtk_progress_bar_set_fraction)(KWidgetRef, double);
typedef void (KGTK_ABI *fn_gtk_progress_bar_set_text)(KWidgetRef, const char*);

typedef KWidgetRef (KGTK_ABI *fn_gtk_hscale_new_with_range)(double, double, double);
typedef double (KGTK_ABI *fn_gtk_range_get_value)(KWidgetRef);
typedef void (KGTK_ABI *fn_gtk_range_set_value)(KWidgetRef, double);

typedef KWidgetRef (KGTK_ABI *fn_gtk_separator_new)(void);
typedef KWidgetRef (KGTK_ABI *fn_gtk_image_new_from_file)(const char*);

typedef KWidgetRef (KGTK_ABI *fn_gtk_drawing_area_new)(void);
typedef void (KGTK_ABI *fn_gtk_widget_add_events)(KWidgetRef, int);
typedef void (KGTK_ABI *fn_gtk_widget_get_allocation)(KWidgetRef, KGtkAllocation*);
typedef void* (KGTK_ABI *fn_gtk_widget_get_window)(KWidgetRef);
typedef void (KGTK_ABI *fn_gtk_widget_queue_draw_area)(KWidgetRef, int, int, int, int);

typedef void* (KGTK_ABI *fn_gdk_gc_new)(void*);
typedef void (KGTK_ABI *fn_gdk_draw_gray_image)(void*, void*, int, int, int, int, int, const uint8_t*, int);
typedef int (KGTK_ABI *fn_gdk_event_get_coords)(void*, double*, double*);
typedef void* (KGTK_ABI *fn_gdk_screen_get_default)(void);
typedef int (KGTK_ABI *fn_gdk_screen_get_width)(void*);
typedef int (KGTK_ABI *fn_gdk_screen_get_height)(void*);

// Cairo functions (via GDK 2.8+ / libcairo.so.2)
typedef void* (KGTK_ABI *fn_gdk_cairo_create)(void*);
typedef void (KGTK_ABI *fn_cairo_destroy)(void*);
typedef void (KGTK_ABI *fn_cairo_save)(void*);
typedef void (KGTK_ABI *fn_cairo_restore)(void*);
typedef void (KGTK_ABI *fn_cairo_translate)(void*, double, double);
typedef void (KGTK_ABI *fn_cairo_scale)(void*, double, double);
typedef void (KGTK_ABI *fn_cairo_set_source_rgb)(void*, double, double, double);
typedef void (KGTK_ABI *fn_cairo_set_line_width)(void*, double);
typedef void (KGTK_ABI *fn_cairo_set_line_cap)(void*, int);
typedef void (KGTK_ABI *fn_cairo_set_line_join)(void*, int);
typedef void (KGTK_ABI *fn_cairo_new_path)(void*);
typedef void (KGTK_ABI *fn_cairo_close_path)(void*);
typedef void (KGTK_ABI *fn_cairo_move_to)(void*, double, double);
typedef void (KGTK_ABI *fn_cairo_line_to)(void*, double, double);
typedef void (KGTK_ABI *fn_cairo_arc)(void*, double, double, double, double, double);
typedef void (KGTK_ABI *fn_cairo_rectangle)(void*, double, double, double, double);
typedef void (KGTK_ABI *fn_cairo_fill)(void*);
typedef void (KGTK_ABI *fn_cairo_fill_preserve)(void*);
typedef void (KGTK_ABI *fn_cairo_stroke)(void*);

typedef void (*fn_gtk_widget_set_size_request)(KWidgetRef, int, int);
typedef void (*fn_gtk_widget_show)(KWidgetRef);
typedef void (*fn_gtk_widget_show_all)(KWidgetRef);
typedef void (*fn_gtk_widget_hide)(KWidgetRef);
typedef void (*fn_gtk_widget_destroy)(KWidgetRef);
typedef void (*fn_gtk_widget_queue_draw)(KWidgetRef);
typedef void (*fn_gtk_widget_modify_bg)(KWidgetRef, int, const KGdkColor*);
typedef void (*fn_gtk_widget_modify_fg)(KWidgetRef, int, const KGdkColor*);
typedef void (*fn_gtk_widget_modify_font)(KWidgetRef, void*);

typedef void* (KGTK_ABI *fn_pango_font_description_from_string)(const char*);
typedef int (KGTK_ABI *fn_pango_font_description_get_size)(const void*);
typedef void (KGTK_ABI *fn_pango_font_description_set_absolute_size)(void*, double);
typedef void (KGTK_ABI *fn_pango_font_description_free)(void*);

typedef unsigned long (*fn_g_signal_connect_data)(void*, const char*, void*, void*, void*, int);
typedef void (*fn_g_object_set_data_full)(void*, const char*, void*, void (*)(void*));
typedef void* (*fn_g_object_get_data)(void*, const char*);
typedef void (*fn_g_object_unref)(void*);
typedef unsigned long (*fn_gtk_type_Fn)(void);
typedef int (*fn_g_type_check_instance_is_a)(void*, unsigned long);

// LIPC functions on Kindle
typedef void* (*fn_LipcOpenNoName)(void);
typedef void (*fn_LipcClose)(void*);
typedef int (*fn_LipcGetIntProperty)(void*, const char*, const char*, int*);
typedef int (*fn_LipcSetIntProperty)(void*, const char*, const char*, int);
typedef int (*fn_LipcSetStringProperty)(void*, const char*, const char*, const char*);

/* dlsym() walks up to eight libraries for every miss, and a UI rebuild issues thousands of
 * resolve_sym() calls. Successful lookups are memoised in a small open-addressed hash table
 * (keyed by symbol-name content) so each symbol is only ever resolved once per process.
 * Only positive results are cached: optional libraries (e.g. WebKit) may be loaded later. */
#define KGTK_SYM_CACHE_SIZE 1024 /* power of two, > number of distinct symbols used */

typedef struct {
    const char* name; /* strdup'd, NULL when the slot is free */
    void* sym;
} KSymCacheEntry;

static KSymCacheEntry g_sym_cache[KGTK_SYM_CACHE_SIZE];
static pthread_mutex_t g_sym_cache_mutex = PTHREAD_MUTEX_INITIALIZER;

static uint32_t sym_name_hash(const char* name) {
    uint32_t h = 2166136261u; /* FNV-1a */
    for (const unsigned char* p = (const unsigned char*)name; *p; ++p) {
        h ^= *p;
        h *= 16777619u;
    }
    return h;
}

static void* resolve_sym_uncached(const char* name);

static void* resolve_sym(const char* name) {
    uint32_t hash = sym_name_hash(name);
    uint32_t mask = KGTK_SYM_CACHE_SIZE - 1;

    pthread_mutex_lock(&g_sym_cache_mutex);
    uint32_t idx = hash & mask;
    for (uint32_t probes = 0; probes < KGTK_SYM_CACHE_SIZE; ++probes) {
        KSymCacheEntry* e = &g_sym_cache[idx];
        if (!e->name) break;
        if (strcmp(e->name, name) == 0) {
            void* cached = e->sym;
            pthread_mutex_unlock(&g_sym_cache_mutex);
            return cached;
        }
        idx = (idx + 1) & mask;
    }
    pthread_mutex_unlock(&g_sym_cache_mutex);

    void* sym = resolve_sym_uncached(name);
    if (!sym) return NULL;

    pthread_mutex_lock(&g_sym_cache_mutex);
    idx = hash & mask;
    for (uint32_t probes = 0; probes < KGTK_SYM_CACHE_SIZE; ++probes) {
        KSymCacheEntry* e = &g_sym_cache[idx];
        if (!e->name) {
            char* copy = strdup(name);
            if (copy) {
                e->sym = sym;
                e->name = copy;
            }
            break;
        }
        if (strcmp(e->name, name) == 0) break; /* raced with another thread */
        idx = (idx + 1) & mask;
    }
    pthread_mutex_unlock(&g_sym_cache_mutex);
    return sym;
}

static void* resolve_sym_uncached(const char* name) {
    void* sym = NULL;
    if (g_gtk_lib && (sym = dlsym(g_gtk_lib, name))) return sym;
    if (g_gdk_lib && (sym = dlsym(g_gdk_lib, name))) return sym;
    if (g_webkit_lib && (sym = dlsym(g_webkit_lib, name))) return sym;
    if (g_cairo_lib && (sym = dlsym(g_cairo_lib, name))) return sym;
    if (g_gobj_lib && (sym = dlsym(g_gobj_lib, name))) return sym;
    if (g_glib_lib && (sym = dlsym(g_glib_lib, name))) return sym;
    if (g_gthread_lib && (sym = dlsym(g_gthread_lib, name))) return sym;
    if (g_pango_lib && (sym = dlsym(g_pango_lib, name))) return sym;
    return dlsym(RTLD_DEFAULT, name);
}
#endif

bool kgtk_init(void) {
#if defined(_WIN32)
    return false;
#else
    const char* gtk_candidates[] = {
        "libgtk-x11-2.0.so.0",
        "libgtk-x11-2.0.so",
        "libgtk-x11-2.0.0.dylib",
        "libgtk-quartz-2.0.0.dylib",
        NULL
    };
    for (int i = 0; gtk_candidates[i] != NULL; ++i) {
        g_gtk_lib = dlopen(gtk_candidates[i], RTLD_LAZY | RTLD_GLOBAL);
        if (g_gtk_lib) break;
    }
    if (!g_gtk_lib) {
        return false;
    }
    g_gdk_lib = dlopen("libgdk-x11-2.0.so.0", RTLD_LAZY | RTLD_GLOBAL);
    g_cairo_lib = dlopen("libcairo.so.2", RTLD_LAZY | RTLD_GLOBAL);
    if (!g_cairo_lib) {
        g_cairo_lib = dlopen("libcairo.2.dylib", RTLD_LAZY | RTLD_GLOBAL);
    }
    g_gobj_lib = dlopen("libgobject-2.0.so.0", RTLD_LAZY | RTLD_GLOBAL);
    g_glib_lib = dlopen("libglib-2.0.so.0", RTLD_LAZY | RTLD_GLOBAL);
    g_gthread_lib = dlopen("libgthread-2.0.so.0", RTLD_LAZY | RTLD_GLOBAL);
    g_pango_lib = dlopen("libpango-1.0.so.0", RTLD_LAZY | RTLD_GLOBAL);
    g_lipc_lib = dlopen("liblipc.so", RTLD_LAZY | RTLD_GLOBAL);

    typedef void (KGTK_ABI *fn_g_thread_init)(void*);
    fn_g_thread_init thread_init = (fn_g_thread_init)resolve_sym("g_thread_init");
    if (thread_init) {
        thread_init(NULL);
    }

    const char* webkit_candidates[] = {
        "libwebkitgtk-1.0.so.0",
        "/usr/lib/libwebkitgtk-1.0.so.0",
        "libwebkit-1.0.so.2",
        "/usr/lib/libwebkit-1.0.so.2",
        "libwebkitgtk-1.0.so",
        NULL
    };
    for (int i = 0; webkit_candidates[i] != NULL; ++i) {
        g_webkit_lib = dlopen(webkit_candidates[i], RTLD_LAZY | RTLD_GLOBAL);
        if (g_webkit_lib) break;
    }

    fn_gtk_init_check init_fn = (fn_gtk_init_check)resolve_sym("gtk_init_check");
    if (!init_fn) return false;
    int argc = 0;
    char** argv = NULL;
    if (init_fn(&argc, &argv) == 0) {
        return false;
    }
    return true;
#endif
}

#if !defined(_WIN32)
typedef struct _KIdleTask {
    KIdleCallback callback;
    void* user_data;
    struct _KIdleTask* next;
} KIdleTask;

typedef unsigned int (KGTK_ABI *fn_g_timeout_add)(unsigned int, int (*)(void*), void*);
typedef void (KGTK_ABI *fn_g_main_context_wakeup)(void*);

static pthread_mutex_t g_idle_mutex = PTHREAD_MUTEX_INITIALIZER;
static pthread_mutex_t g_fallback_idle_mutex = PTHREAD_MUTEX_INITIALIZER;
static KIdleTask* g_idle_head = NULL;
static KIdleTask* g_idle_tail = NULL;
static volatile int g_has_pending_idle = 0;
static int g_draining_idle_tasks = 0;
static int g_idle_pump_registered = 0;

static void kgtk_drain_idle_tasks(void) {
    if (g_draining_idle_tasks) {
        // Prevent re-entrant draining when kgtk_flush_updates() pumps gtk_main_iteration_do(0)
        // in the middle of a UI rebuild; the outer loop will continue draining queued tasks.
        return;
    }
    g_draining_idle_tasks = 1;

    pthread_mutex_lock(&g_idle_mutex);
    KIdleTask* list = g_idle_head;
    g_idle_head = NULL;
    g_idle_tail = NULL;
    g_has_pending_idle = 0;
    pthread_mutex_unlock(&g_idle_mutex);

    while (list) {
        KIdleTask* task = list;
        list = task->next;
        if (task->callback) {
            task->callback(task->user_data);
        }
        free(task);
    }
    g_draining_idle_tasks = 0;
}

static int c_idle_trampoline(void* data) {
    (void)data;
    kgtk_drain_idle_tasks();
    return 0; // G_SOURCE_REMOVE (one-shot)
}

static int c_periodic_idle_pump(void* data) {
    (void)data;
    if (g_has_pending_idle) {
        kgtk_drain_idle_tasks();
    }
    return 1; // G_SOURCE_CONTINUE (keep 35ms pump alive)
}

static void kgtk_ensure_idle_pump(void) {
    if (!g_idle_pump_registered) {
        fn_g_timeout_add timeout_add = (fn_g_timeout_add)resolve_sym("g_timeout_add");
        if (timeout_add) {
            g_idle_pump_registered = 1;
            timeout_add(35, c_periodic_idle_pump, NULL);
        }
    }
}
#endif

void kgtk_main(void) {
#if !defined(_WIN32)
    kgtk_ensure_idle_pump();
    kgtk_drain_idle_tasks();
    fn_gtk_main fn = (fn_gtk_main)resolve_sym("gtk_main");
    if (fn) fn();
#endif
}

void kgtk_main_quit(void) {
#if !defined(_WIN32)
    fn_gtk_main_quit fn = (fn_gtk_main_quit)resolve_sym("gtk_main_quit");
    if (fn) fn();
#endif
}

void kgtk_drain_events(void) {
#if !defined(_WIN32)
    fn_gtk_events_pending pending = (fn_gtk_events_pending)resolve_sym("gtk_events_pending");
    fn_gtk_main_iteration_do iter = (fn_gtk_main_iteration_do)resolve_sym("gtk_main_iteration_do");
    if (pending && iter) {
        int max_iters = 256;
        while (pending() && max_iters-- > 0) {
            iter(0);
        }
    }
#endif
}

void kgtk_reset_scroll_position(void) {
#if !defined(_WIN32)
    g_last_scroll_y = 0.0;
    g_pending_scroll_restore = 0.0;
    g_scroll_reset_requested = true;
#endif
}

void kgtk_set_scroll_position(double y) {
#if !defined(_WIN32)
    double clamped_y = y < 0.0 ? 0.0 : y;
    g_scroll_reset_requested = false;
    g_last_scroll_y = clamped_y;
    g_pending_scroll_restore = clamped_y;
    if (g_active_scrolled_window) {
        fn_gtk_scrolled_window_get_vadjustment get_vadj = (fn_gtk_scrolled_window_get_vadjustment)resolve_sym("gtk_scrolled_window_get_vadjustment");
        fn_gtk_adjustment_set_value set_val = (fn_gtk_adjustment_set_value)resolve_sym("gtk_adjustment_set_value");
        fn_gtk_adjustment_get_upper get_upper = (fn_gtk_adjustment_get_upper)resolve_sym("gtk_adjustment_get_upper");
        fn_gtk_adjustment_get_page_size get_page = (fn_gtk_adjustment_get_page_size)resolve_sym("gtk_adjustment_get_page_size");
        if (get_vadj && set_val) {
            void* vadj = get_vadj(g_active_scrolled_window);
            if (vadj) {
                double target = clamped_y;
                if (get_upper && get_page) {
                    double upper = get_upper(vadj);
                    double page = get_page(vadj);
                    if (upper > 1.0 && page > 1.0) {
                        double max_val = upper > page ? (upper - page) : 0.0;
                        if (target > max_val) target = max_val;
                        g_pending_scroll_restore = 0.0;
                    }
                }
                set_val(vadj, target);
                g_last_scroll_y = target;
            }
        }
    }
#else
    (void)y;
#endif
}

double kgtk_get_scroll_position(void) {
#if !defined(_WIN32)
    return g_last_scroll_y;
#else
    return 0.0;
#endif
}

void kgtk_window_freeze_updates(KWidgetRef window) {
#if !defined(_WIN32)
    if (!window) return;
    fn_gtk_widget_get_window get_win = (fn_gtk_widget_get_window)resolve_sym("gtk_widget_get_window");
    fn_gdk_window_freeze_updates freeze_fn = (fn_gdk_window_freeze_updates)resolve_sym("gdk_window_freeze_updates");
    if (get_win && freeze_fn) {
        void* gdk_win = get_win(window);
        if (gdk_win) {
            freeze_fn(gdk_win);
            g_window_freeze_depth++;
        }
    }
#else
    (void)window;
#endif
}

void kgtk_window_thaw_updates(KWidgetRef window) {
#if !defined(_WIN32)
    if (!window || g_window_freeze_depth <= 0) return;
    fn_gtk_widget_get_window get_win = (fn_gtk_widget_get_window)resolve_sym("gtk_widget_get_window");
    fn_gdk_window_thaw_updates thaw_fn = (fn_gdk_window_thaw_updates)resolve_sym("gdk_window_thaw_updates");
    if (get_win && thaw_fn) {
        void* gdk_win = get_win(window);
        if (gdk_win) {
            while (g_window_freeze_depth > 0) {
                thaw_fn(gdk_win);
                g_window_freeze_depth--;
            }
        } else {
            g_window_freeze_depth = 0;
        }
    } else {
        g_window_freeze_depth = 0;
    }
#else
    (void)window;
#endif
}

void kgtk_flush_updates(KWidgetRef window) {
#if !defined(_WIN32)
    fn_gtk_container_check_resize check_resize = (fn_gtk_container_check_resize)resolve_sym("gtk_container_check_resize");
    fn_gdk_window_process_all_updates process_updates = (fn_gdk_window_process_all_updates)resolve_sym("gdk_window_process_all_updates");
    fn_gdk_flush flush_fn = (fn_gdk_flush)resolve_sym("gdk_flush");
    fn_gtk_scrolled_window_get_vadjustment get_vadj = (fn_gtk_scrolled_window_get_vadjustment)resolve_sym("gtk_scrolled_window_get_vadjustment");
    fn_gtk_adjustment_set_value set_val = (fn_gtk_adjustment_set_value)resolve_sym("gtk_adjustment_set_value");
    fn_gtk_adjustment_get_upper get_upper = (fn_gtk_adjustment_get_upper)resolve_sym("gtk_adjustment_get_upper");
    fn_gtk_adjustment_get_page_size get_page = (fn_gtk_adjustment_get_page_size)resolve_sym("gtk_adjustment_get_page_size");

    double saved_scroll_y = g_pending_scroll_restore > 0.0 ? g_pending_scroll_restore : g_last_scroll_y;
    g_scroll_tracking_enabled = false;

    if (check_resize && window) {
        check_resize(window);
    }

    if (g_active_scrolled_window && get_vadj && set_val && saved_scroll_y > 0.0) {
        void* vadj_early = get_vadj(g_active_scrolled_window);
        if (vadj_early) {
            double target_early = saved_scroll_y;
            if (get_upper && get_page) {
                double u = get_upper(vadj_early);
                double p = get_page(vadj_early);
                if (u > p + 1.0 && p > 1.0) {
                    double max_v = u - p;
                    if (target_early > max_v) target_early = max_v;
                }
            }
            if (target_early > 0.0) {
                set_val(vadj_early, target_early);
            }
        }
    }

    // Drain pending GTK size-request/size-allocate idle handlers while window updates are still frozen
    // and scroll tracking is disabled so vadj->upper and vadj->page_size reach their true final heights.
    kgtk_drain_events();

    if (check_resize && window) {
        check_resize(window);
    }
    kgtk_drain_events();

    if (g_active_scrolled_window && get_vadj && set_val) {
        void* vadj = get_vadj(g_active_scrolled_window);
        if (vadj) {
            double target = saved_scroll_y;
            if (get_upper && get_page) {
                double upper = get_upper(vadj);
                double page = get_page(vadj);
                if (upper > page + 1.0 && page > 1.0) {
                    double max_val = upper - page;
                    if (target > max_val) target = max_val;
                    g_pending_scroll_restore = 0.0;
                } else if (upper > 1.0 && page > 1.0 && upper <= page + 1.0) {
                    target = 0.0;
                    g_pending_scroll_restore = 0.0;
                }
            }
            if (target < 0.0) target = 0.0;
            set_val(vadj, target);
            g_last_scroll_y = target;
            if (check_resize && window && target > 0.0) {
                check_resize(window);
            }
        }
    } else {
        g_last_scroll_y = saved_scroll_y;
    }

    kgtk_window_thaw_updates(window);

    if (process_updates) {
        process_updates();
    }
    kgtk_drain_events();
    if (process_updates) {
        process_updates();
    }
    if (flush_fn) {
        flush_fn();
    }
    g_scroll_tracking_enabled = true;
#else
    (void)window;
#endif
}

void kgtk_flush_live_drag(KWidgetRef window) {
#if !defined(_WIN32)
    fn_gtk_container_check_resize check_resize = (fn_gtk_container_check_resize)resolve_sym("gtk_container_check_resize");
    fn_gtk_bin_get_child get_child = (fn_gtk_bin_get_child)resolve_sym("gtk_bin_get_child");
    fn_gdk_window_process_all_updates process_updates = (fn_gdk_window_process_all_updates)resolve_sym("gdk_window_process_all_updates");
    fn_gdk_flush flush_fn = (fn_gdk_flush)resolve_sym("gdk_flush");

    if (check_resize && window) {
        if (g_active_scrolled_window && get_child) {
            KWidgetRef vp = get_child(g_active_scrolled_window);
            if (vp) check_resize(vp);
        }
        check_resize(window);
    }
    if (process_updates) {
        process_updates();
    }
    if (flush_fn) {
        flush_fn();
    }
#else
    (void)window;
#endif
}

void kgtk_schedule_idle(KIdleCallback callback, void* user_data) {
#if !defined(_WIN32)
    if (!callback) return;
    fn_g_idle_add idle_add = (fn_g_idle_add)resolve_sym("g_idle_add");
    fn_g_idle_add_full idle_add_full = (fn_g_idle_add_full)resolve_sym("g_idle_add_full");
    fn_g_main_context_wakeup wakeup_fn = (fn_g_main_context_wakeup)resolve_sym("g_main_context_wakeup");
    if (idle_add || idle_add_full) {
        KIdleTask* task = (KIdleTask*)malloc(sizeof(KIdleTask));
        if (task) {
            task->callback = callback;
            task->user_data = user_data;
            task->next = NULL;

            pthread_mutex_lock(&g_idle_mutex);
            int was_pending = g_has_pending_idle;
            if (g_idle_tail) {
                g_idle_tail->next = task;
                g_idle_tail = task;
            } else {
                g_idle_head = task;
                g_idle_tail = task;
            }
            g_has_pending_idle = 1;
            pthread_mutex_unlock(&g_idle_mutex);

            if (!was_pending) {
                // Schedule at G_PRIORITY_HIGH_IDLE (100) so state-driven UI rebuilds execute
                // BEFORE GTK_PRIORITY_RESIZE (110) and GDK_PRIORITY_REDRAW (120) waste a frame
                // redrawing widgets that are about to be replaced.
                if (idle_add_full) {
                    idle_add_full(100, c_idle_trampoline, NULL, NULL);
                } else if (idle_add) {
                    idle_add(c_idle_trampoline, NULL);
                }
                if (wakeup_fn) {
                    wakeup_fn(NULL);
                }
            }
            return;
        }
    }
    pthread_mutex_lock(&g_fallback_idle_mutex);
    callback(user_data);
    pthread_mutex_unlock(&g_fallback_idle_mutex);
#endif
}

bool kgtk_is_slider_dragging(void) {
#if !defined(_WIN32)
    return g_slider_dragging || g_gesture_dragging || g_canvas_dragging || (g_scroll_drag.active && g_scroll_drag.threshold_crossed);
#else
    return false;
#endif
}

void kgtk_reset_slider_dragging(void) {
#if !defined(_WIN32)
    g_slider_dragging = false;
    g_gesture_dragging = false;
    g_canvas_dragging = false;
#endif
}

static int g_simulated_screen_width = 1236;
static int g_simulated_screen_height = 1648;
static bool g_has_simulated_screen_size = false;
static double g_ui_scale = 0.0;

void kgtk_set_simulated_screen_size(int width, int height) {
    if (width > 0 && height > 0) {
        g_simulated_screen_width = width;
        g_simulated_screen_height = height;
        g_has_simulated_screen_size = true;
        g_ui_scale = 0.0;
    }
}

void kgtk_get_screen_size(int* out_width, int* out_height) {
    int w = g_simulated_screen_width;
    int h = g_simulated_screen_height;
#if !defined(_WIN32)
    if (!g_has_simulated_screen_size) {
        fn_gdk_screen_get_default get_def = (fn_gdk_screen_get_default)resolve_sym("gdk_screen_get_default");
        fn_gdk_screen_get_width get_w = (fn_gdk_screen_get_width)resolve_sym("gdk_screen_get_width");
        fn_gdk_screen_get_height get_h = (fn_gdk_screen_get_height)resolve_sym("gdk_screen_get_height");
        if (get_def && get_w && get_h) {
            void* screen = get_def();
            if (screen) {
                int sw = get_w(screen);
                int sh = get_h(screen);
                if (sw > 0 && sh > 0) {
                    w = sw;
                    h = sh;
                }
            }
        }
    }
#endif
    if (out_width) *out_width = w;
    if (out_height) *out_height = h;
}

double kgtk_get_ui_scale(void) {
    if (g_ui_scale > 0.01) return g_ui_scale;
    const char* env_scale = getenv("KINDLEUI_SCALE");
    if (env_scale && env_scale[0] != '\0') {
        double custom = atof(env_scale);
        if (custom >= 0.2 && custom <= 3.0) {
            g_ui_scale = custom;
            return g_ui_scale;
        }
    }
    int sw = 1860, sh = 2480;
    kgtk_get_screen_size(&sw, &sh);
    if (sw <= 0) sw = 1860;
    if (sh <= 0) sh = 2480;
    int short_side = sw < sh ? sw : sh;
    int long_side  = sw < sh ? sh : sw;
    double sx = (double)short_side / 1860.0;
    double sy = (double)long_side  / 2480.0;
    double s = sx < sy ? sx : sy;
    if (s < 0.28) s = 0.28;
    if (s > 2.00) s = 2.00;
    g_ui_scale = s;
    fprintf(stderr, "[KindleUI] Detected screen %dx%d -> UI Scale %.3f\n", sw, sh, g_ui_scale);
    return g_ui_scale;
}

int kgtk_scale_px(int val) {
    if (val <= 0) return val;
    double s = kgtk_get_ui_scale();
    int out = (int)((double)val * s + 0.5);
    return out < 1 ? 1 : out;
}

static int kgtk_scale_signed_px(int val) {
    if (val == 0) return 0;
    if (val > 0) return kgtk_scale_px(val);
    return -kgtk_scale_px(-val);
}

KWidgetRef kgtk_window_new(int window_type) {
#if !defined(_WIN32)
    fn_gtk_window_new fn = (fn_gtk_window_new)resolve_sym("gtk_window_new");
    if (fn) return fn(window_type);
#endif
    return NULL;
}

void kgtk_window_set_title(KWidgetRef window, const char* title) {
#if !defined(_WIN32)
    fn_gtk_window_set_title fn = (fn_gtk_window_set_title)resolve_sym("gtk_window_set_title");
    if (fn && window) fn(window, title);
#endif
}

typedef void (*fn_gtk_window_set_resizable)(KWidgetRef, int);

#if !defined(_WIN32)
static int g_window_default_w = 0;
static int g_window_default_h = 0;

static void c_window_clamp_size_request(KWidgetRef widget, KGtkRequisition* req, void* data) {
    (void)widget;
    (void)data;
    if (!req) return;
    if (g_window_default_w > 0) {
        req->width = g_window_default_w;
    }
    if (g_window_default_h > 0) {
        req->height = g_window_default_h;
    }
}
#endif

void kgtk_window_set_default_size(KWidgetRef window, int width, int height) {
#if !defined(_WIN32)
    g_window_default_w = width;
    g_window_default_h = height;
    fn_gtk_window_set_default_size fn = (fn_gtk_window_set_default_size)resolve_sym("gtk_window_set_default_size");
    fn_gtk_widget_set_size_request sr = (fn_gtk_widget_set_size_request)resolve_sym("gtk_widget_set_size_request");
    fn_gtk_window_set_resizable res = (fn_gtk_window_set_resizable)resolve_sym("gtk_window_set_resizable");
    fn_g_signal_connect_data conn = (fn_g_signal_connect_data)resolve_sym("g_signal_connect_data");
    if (fn && window) fn(window, width, height);
    if (sr && window) sr(window, width, height);
    if (res && window) res(window, 0);
    if (conn && window) {
        conn(window, "size-request", (void*)c_window_clamp_size_request, NULL, NULL, 1);
    }
#endif
}

void kgtk_window_set_position(KWidgetRef window, int position) {
#if !defined(_WIN32)
    fn_gtk_window_set_position fn = (fn_gtk_window_set_position)resolve_sym("gtk_window_set_position");
    if (fn && window) fn(window, position);
#endif
}

void kgtk_window_fullscreen(KWidgetRef window) {
#if !defined(_WIN32)
    fn_gtk_window_fullscreen fn = (fn_gtk_window_fullscreen)resolve_sym("gtk_window_fullscreen");
    if (fn && window) fn(window);
#endif
}

#if !defined(_WIN32)
typedef struct {
    int type;
    void* window;
    int8_t send_event;
    uint32_t time;
    unsigned int state;
    unsigned int keyval;
    int length;
    char* string;
    uint16_t hardware_keycode;
} KGdkEventKey;

typedef uint32_t (KGTK_ABI *fn_gdk_keyval_to_unicode)(unsigned int);

static int c_window_key_press(KWidgetRef widget, void* event, void* data) {
    (void)widget;
    KIdleTask* task = (KIdleTask*)data;
    if (event) {
        KGdkEventKey* kev = (KGdkEventKey*)event;
        if (g_global_key_handler) {
            unsigned int kv = kev->keyval;
            if (kv != 0xff1b && kv != 0xff08 && kv != 0xffff && kv != 0xff0d && kv != 0xff8d) {
                fn_gdk_keyval_to_unicode to_uni = (fn_gdk_keyval_to_unicode)resolve_sym("gdk_keyval_to_unicode");
                if (to_uni) {
                    uint32_t u = to_uni(kv);
                    if (u >= 0x20) {
                        kv = (unsigned int)u;
                    }
                }
            }
            if (g_global_key_handler(kv, g_global_key_user_data)) {
                return 1;
            }
        }
        // Escape (0xff1b or keycode 9) quits when no modal keyboard consumes it
        if ((kev->keyval == 0xff1b || kev->hardware_keycode == 9) && task && task->callback) {
            task->callback(task->user_data);
            return 1;
        }
    }
    return 0;
}
#endif

void kgtk_set_global_key_handler(KWindowKeyCallback handler, void* user_data) {
#if !defined(_WIN32)
    g_global_key_handler = handler;
    g_global_key_user_data = user_data;
#else
    (void)handler;
    (void)user_data;
#endif
}

void kgtk_window_connect_quit_keys(KWidgetRef window, KIdleCallback on_quit, void* user_data) {
#if !defined(_WIN32)
    fn_g_signal_connect_data conn = (fn_g_signal_connect_data)resolve_sym("g_signal_connect_data");
    fn_g_object_set_data_full set_data = (fn_g_object_set_data_full)resolve_sym("g_object_set_data_full");
    if (conn && window && on_quit) {
        KIdleTask* task = (KIdleTask*)malloc(sizeof(KIdleTask));
        if (task) {
            task->callback = on_quit;
            task->user_data = user_data;
            if (set_data) {
                set_data(window, "kindle-quit-key-task", task, free);
            }
            conn(window, "key-press-event", (void*)c_window_key_press, task, NULL, 0);
        }
    }
#endif
}

KWidgetRef kgtk_vbox_new(bool homogeneous, int spacing) {
#if !defined(_WIN32)
    fn_gtk_box_new_2 fn = (fn_gtk_box_new_2)resolve_sym("gtk_vbox_new");
    if (fn) return fn(homogeneous ? 1 : 0, kgtk_scale_px(spacing));
#endif
    return NULL;
}

KWidgetRef kgtk_hbox_new(bool homogeneous, int spacing) {
#if !defined(_WIN32)
    fn_gtk_box_new_2 fn = (fn_gtk_box_new_2)resolve_sym("gtk_hbox_new");
    if (fn) return fn(homogeneous ? 1 : 0, kgtk_scale_px(spacing));
#endif
    return NULL;
}

void kgtk_box_pack_start(KWidgetRef box, KWidgetRef child, bool expand, bool fill, int padding) {
#if !defined(_WIN32)
    fn_gtk_box_pack_start fn = (fn_gtk_box_pack_start)resolve_sym("gtk_box_pack_start");
    if (fn && box && child) fn(box, child, expand ? 1 : 0, fill ? 1 : 0, (unsigned int)kgtk_scale_px(padding));
#endif
}

void kgtk_container_add(KWidgetRef container, KWidgetRef widget) {
#if !defined(_WIN32)
    fn_gtk_container_add fn = (fn_gtk_container_add)resolve_sym("gtk_container_add");
    if (fn && container && widget) fn(container, widget);
#endif
}

void kgtk_container_remove(KWidgetRef container, KWidgetRef widget) {
#if !defined(_WIN32)
    fn_gtk_container_remove fn = (fn_gtk_container_remove)resolve_sym("gtk_container_remove");
    if (fn && container && widget) fn(container, widget);
#endif
}

void kgtk_container_clear(KWidgetRef container) {
#if !defined(_WIN32)
    g_scroll_drag.active = false;
    g_scroll_drag.threshold_crossed = false;
    g_scroll_drag.active_sw = NULL;
    g_scroll_drag.source_widget = NULL;

    if (g_scroll_reset_requested) {
        g_last_scroll_y = 0.0;
        g_pending_scroll_restore = 0.0;
        g_scroll_reset_requested = false;
    } else if (g_active_scrolled_window) {
        fn_gtk_scrolled_window_get_vadjustment get_vadj = (fn_gtk_scrolled_window_get_vadjustment)resolve_sym("gtk_scrolled_window_get_vadjustment");
        fn_gtk_adjustment_get_value get_val = (fn_gtk_adjustment_get_value)resolve_sym("gtk_adjustment_get_value");
        if (get_vadj && get_val) {
            void* vadj = get_vadj(g_active_scrolled_window);
            if (vadj) {
                double cur = get_val(vadj);
                if (g_pending_scroll_restore <= 0.0 || cur > 0.0) {
                    g_last_scroll_y = cur < 0.0 ? 0.0 : cur;
                }
            }
        }
    }
    g_pending_scroll_restore = g_last_scroll_y;
    g_scroll_tracking_enabled = false;
    g_active_scrolled_window = NULL;
    g_active_modal_scrolled_window = NULL;
    g_has_frozen_scroll = false;
    kgtk_detach_cached_webviews();
    fn_gtk_container_get_children get_children = (fn_gtk_container_get_children)resolve_sym("gtk_container_get_children");
    fn_gtk_widget_destroy destroy_fn = (fn_gtk_widget_destroy)resolve_sym("gtk_widget_destroy");
    fn_g_list_free free_fn = (fn_g_list_free)resolve_sym("g_list_free");
    if (get_children && destroy_fn && container) {
        KGList* list = get_children(container);
        for (KGList* iter = list; iter != NULL; iter = iter->next) {
            if (iter->data) {
                destroy_fn(iter->data);
            }
        }
        if (free_fn && list) free_fn(list);
    }
#endif
}

void kgtk_container_set_border_width(KWidgetRef container, int border_width) {
#if !defined(_WIN32)
    fn_gtk_container_set_border_width fn = (fn_gtk_container_set_border_width)resolve_sym("gtk_container_set_border_width");
    if (fn && container) fn(container, (unsigned int)kgtk_scale_px(border_width));
#endif
}

KWidgetRef kgtk_alignment_new(float xalign, float yalign, float xscale, float yscale) {
#if !defined(_WIN32)
    fn_gtk_alignment_new fn = (fn_gtk_alignment_new)resolve_sym("gtk_alignment_new");
    if (fn) {
        return fn(xalign, yalign, xscale, yscale);
    }
#endif
    return NULL;
}

void kgtk_alignment_set_padding(KWidgetRef alignment, int top, int bottom, int left, int right) {
#if !defined(_WIN32)
    fn_gtk_alignment_set_padding fn = (fn_gtk_alignment_set_padding)resolve_sym("gtk_alignment_set_padding");
    if (fn && alignment) {
        fn(
            alignment,
            (unsigned int)kgtk_scale_px(top),
            (unsigned int)kgtk_scale_px(bottom),
            (unsigned int)kgtk_scale_px(left),
            (unsigned int)kgtk_scale_px(right)
        );
    }
#endif
}

KWidgetRef kgtk_frame_new(const char* label) {
#if !defined(_WIN32)
    fn_gtk_frame_new fn = (fn_gtk_frame_new)resolve_sym("gtk_frame_new");
    if (fn) return fn(label);
#endif
    return NULL;
}

void kgtk_frame_set_shadow_type(KWidgetRef frame, int shadow_type) {
#if !defined(_WIN32)
    fn_gtk_frame_set_shadow_type fn = (fn_gtk_frame_set_shadow_type)resolve_sym("gtk_frame_set_shadow_type");
    if (fn && frame) fn(frame, shadow_type);
#endif
}

#if !defined(_WIN32)
typedef int (KGTK_ABI *fn_gdk_event_get_root_coords)(void*, double*, double*);
typedef int (KGTK_ABI *fn_gdk_event_get_state)(void*, unsigned int*);
typedef KWidgetRef (KGTK_ABI *fn_gtk_widget_get_parent)(KWidgetRef);

typedef struct {
    KWidgetRef scrolled_window;
    bool dragging;
    double start_root_y;
    double start_scroll_val;
} KScrollDragState;

typedef struct {
    int type;
    void* window;
    int8_t send_event;
    uint32_t time;
    double x;
    double y;
    double* axes;
    unsigned int state;
    unsigned int button;
    void* device;
    double x_root;
    double y_root;
} KGdkEventButton;

static bool c_event_is_button1_press(void* event) {
    if (!event) return false;
    const KGdkEventButton* bev = (const KGdkEventButton*)event;
    // GDK_BUTTON_PRESS == 4 (ignore GDK_2BUTTON_PRESS=5, GDK_3BUTTON_PRESS=6, and X11 multitouch.so swipe buttons 2..10)
    return bev->type == 4 && bev->button == 1;
}

static bool c_event_is_button1_release(void* event) {
    if (!event) return false;
    const KGdkEventButton* bev = (const KGdkEventButton*)event;
    // GDK_BUTTON_RELEASE == 7, primary touch button == 1
    return bev->type == 7 && bev->button == 1;
}

static int c_ignore_scroll_wheel_event(KWidgetRef widget, void* event, void* data) {
    (void)widget;
    (void)event;
    (void)data;
    // Block Xorg multitouch.so's synthetic Button 4/5/6/7 swipe-wheel events from
    // triggering GtkScrolledWindow's built-in pow(page_size, 2/3) step jump.
    return 1;
}

static bool c_event_has_button1_mask(void* event) {
    if (!event) return false;
    fn_gdk_event_get_state get_state = (fn_gdk_event_get_state)resolve_sym("gdk_event_get_state");
    if (!get_state) return true;
    unsigned int state = 0;
    if (get_state(event, &state)) {
        // GDK_BUTTON1_MASK = 1 << 8 = 256
        return (state & (1u << 8)) != 0;
    }
    return true;
}

static KWidgetRef c_find_enclosing_scrolled_window(KWidgetRef widget) {
    fn_gtk_widget_get_parent get_parent = (fn_gtk_widget_get_parent)resolve_sym("gtk_widget_get_parent");
    typedef void* (*fn_g_object_get_data)(void*, const char*);
    fn_g_object_get_data get_data = (fn_g_object_get_data)resolve_sym("g_object_get_data");
    if (!get_parent || !get_data) {
        return g_active_modal_scrolled_window ? g_active_modal_scrolled_window : g_active_scrolled_window;
    }
    KWidgetRef cur = widget;
    while (cur) {
        if (get_data(cur, "kindle-is-scrolled-window") != NULL) {
            return cur;
        }
        cur = get_parent(cur);
    }
    return NULL;
}

static void c_scroll_drag_begin(KWidgetRef widget, KWidgetRef explicit_sw, void* event, bool use_threshold) {
    if (!c_event_is_button1_press(event)) {
        return;
    }
    if (g_slider_dragging || g_canvas_dragging) {
        g_scroll_drag.active = false;
        g_scroll_drag.threshold_crossed = false;
        return;
    }
    KWidgetRef sw = explicit_sw ? explicit_sw : c_find_enclosing_scrolled_window(widget);
    if (!sw) {
        g_scroll_drag.active = false;
        g_scroll_drag.threshold_crossed = false;
        return;
    }
    fn_gdk_event_get_root_coords get_root = (fn_gdk_event_get_root_coords)resolve_sym("gdk_event_get_root_coords");
    fn_gtk_scrolled_window_get_vadjustment get_vadj = (fn_gtk_scrolled_window_get_vadjustment)resolve_sym("gtk_scrolled_window_get_vadjustment");
    fn_gtk_adjustment_get_value get_val = (fn_gtk_adjustment_get_value)resolve_sym("gtk_adjustment_get_value");
    if (!get_root || !get_vadj || !get_val) return;
    void* vadj = get_vadj(sw);
    if (!vadj) return;
    double rx = 0.0, ry = 0.0;
    get_root(event, &rx, &ry);
    double cur_val = get_val(vadj);
    g_scroll_drag.active_sw = sw;
    g_scroll_drag.source_widget = widget;
    g_scroll_drag.active = true;
    g_scroll_drag.threshold_crossed = !use_threshold;
    g_scroll_drag.start_root_y = ry;
    g_scroll_drag.anchor_root_y = ry;
    g_scroll_drag.last_root_y = ry;
    g_scroll_drag.start_scroll_val = cur_val;
}

static bool c_scroll_drag_update(void* event) {
    if (!event) return false;
    if (!c_event_has_button1_mask(event) || g_slider_dragging || g_canvas_dragging) {
        g_scroll_drag.active = false;
        g_scroll_drag.threshold_crossed = false;
        g_scroll_drag.active_sw = NULL;
        g_scroll_drag.source_widget = NULL;
        return false;
    }
    if (!g_scroll_drag.active || !g_scroll_drag.active_sw) return false;
    fn_gdk_event_get_root_coords get_root = (fn_gdk_event_get_root_coords)resolve_sym("gdk_event_get_root_coords");
    fn_gtk_scrolled_window_get_vadjustment get_vadj = (fn_gtk_scrolled_window_get_vadjustment)resolve_sym("gtk_scrolled_window_get_vadjustment");
    fn_gtk_adjustment_get_value get_val = (fn_gtk_adjustment_get_value)resolve_sym("gtk_adjustment_get_value");
    fn_gtk_adjustment_set_value set_val = (fn_gtk_adjustment_set_value)resolve_sym("gtk_adjustment_set_value");
    fn_gtk_adjustment_get_upper get_upper = (fn_gtk_adjustment_get_upper)resolve_sym("gtk_adjustment_get_upper");
    fn_gtk_adjustment_get_page_size get_page = (fn_gtk_adjustment_get_page_size)resolve_sym("gtk_adjustment_get_page_size");
    fn_gdk_window_process_all_updates process_updates = (fn_gdk_window_process_all_updates)resolve_sym("gdk_window_process_all_updates");
    if (!get_root || !get_vadj || !get_val || !set_val) return false;
    void* vadj = get_vadj(g_scroll_drag.active_sw);
    if (!vadj) return false;
    double rx = 0.0, ry = 0.0;
    get_root(event, &rx, &ry);

    if (!g_scroll_drag.threshold_crossed) {
        double total_dy = ry - g_scroll_drag.start_root_y;
        double abs_dy = total_dy < 0.0 ? -total_dy : total_dy;
        if (abs_dy <= 10.0) {
            g_scroll_drag.last_root_y = ry;
            return false;
        }
        g_scroll_drag.threshold_crossed = true;
        g_scroll_drag.anchor_root_y = ry;
        g_scroll_drag.last_root_y = ry;
        g_scroll_drag.start_scroll_val = get_val(vadj);
    } else {
        // Guard against Kindle Xorg multitouch.so's release pointer warp back to start_root_y (0xa5c0..0xa5cc)
        // right before Button 1 UP is posted.
        double prev_dist = g_scroll_drag.last_root_y - g_scroll_drag.start_root_y;
        if (prev_dist < 0.0) prev_dist = -prev_dist;
        double cur_dist = ry - g_scroll_drag.start_root_y;
        if (cur_dist < 0.0) cur_dist = -cur_dist;
        if (prev_dist > 20.0 && cur_dist <= 2.0) {
            return true;
        }
        g_scroll_drag.last_root_y = ry;
    }

    double dy = ry - g_scroll_drag.anchor_root_y;
    double target = (double)((int)(g_scroll_drag.start_scroll_val - dy + 0.5));
    if (get_upper && get_page) {
        double max_val = (double)((int)(get_upper(vadj) - get_page(vadj) + 0.5));
        if (max_val < 0.0) max_val = 0.0;
        if (target > max_val) target = max_val;
    }
    if (target < 0.0) target = 0.0;
    if (g_scroll_drag.active_sw == g_active_scrolled_window) {
        g_pending_scroll_restore = 0.0;
        g_last_scroll_y = target;
    }
    double cur_val = get_val(vadj);
    double diff = target - cur_val;
    if (diff < 0.0) diff = -diff;
    if (diff >= 1.0) {
        set_val(vadj, target);
        if (process_updates) {
            process_updates();
        }
    }
    return true;
}

static bool c_scroll_drag_end(void) {
    bool did_scroll = (g_scroll_drag.active && g_scroll_drag.threshold_crossed);
    g_scroll_drag.active = false;
    g_scroll_drag.threshold_crossed = false;
    g_scroll_drag.active_sw = NULL;
    g_scroll_drag.source_widget = NULL;
    if (did_scroll) {
        fn_gdk_window_process_all_updates process_updates = (fn_gdk_window_process_all_updates)resolve_sym("gdk_window_process_all_updates");
        fn_gdk_flush flush_fn = (fn_gdk_flush)resolve_sym("gdk_flush");
        if (process_updates) process_updates();
        if (flush_fn) flush_fn();
    }
    return did_scroll;
}

static void c_webview_schedule_tap_input_check(KWidgetRef web_view, int tap_x, int tap_y);

static int c_scroll_drag_press(KWidgetRef widget, void* event, void* data) {
    KScrollDragState* st = (KScrollDragState*)data;
    if (!st || !event || !st->scrolled_window) return 0;
    if (!c_event_is_button1_press(event)) return 1;
    typedef void (KGTK_ABI *fn_gtk_widget_grab_focus)(KWidgetRef);
    fn_gtk_widget_grab_focus grab_focus = (fn_gtk_widget_grab_focus)resolve_sym("gtk_widget_grab_focus");
    if (grab_focus && widget) {
        grab_focus(widget);
    }
    c_scroll_drag_begin(widget, st->scrolled_window, event, true);
    return 0;
}

static int c_scroll_drag_motion(KWidgetRef widget, void* event, void* data) {
    (void)widget;
    KScrollDragState* st = (KScrollDragState*)data;
    if (!st || !event || !st->scrolled_window) return 0;
    c_scroll_drag_update(event);
    return 0;
}

static int c_scroll_drag_release(KWidgetRef widget, void* event, void* data) {
    (void)data;
    if (!c_event_is_button1_release(event)) return 1;
    bool did_scroll = c_scroll_drag_end();
    if (!did_scroll && widget && event) {
        const KGdkEventButton* bev = (const KGdkEventButton*)event;
        c_webview_schedule_tap_input_check(widget, (int)bev->x, (int)bev->y);
    }
    return 0;
}

static void c_viewport_child_size_request(KWidgetRef widget, KGtkRequisition* req, void* data) {
    (void)widget;
    (void)data;
    // Clamp the top-level scroll child's requested width so GtkViewport
    // (which sets child_allocation.width = MAX(viewport_width, child_requisition.width))
    // never allocates the child wider than the visible viewport width.
    if (req && req->width > 100) {
        req->width = 100;
    }
}

static void c_scrolled_window_size_request(KWidgetRef widget, KGtkRequisition* req, void* data) {
    (void)widget;
    (void)data;
    // Clamp GtkScrolledWindow's own requisition so it always fits inside the fixed-height
    // window above bottom toolbars/TabBars regardless of inner content height.
    if (req) {
        if (req->width > 100) req->width = 100;
        if (req->height > 100) req->height = 100;
    }
}

static void c_vadj_value_changed(void* vadj, void* data) {
    (void)data;
    if (!g_scroll_tracking_enabled || !vadj) return;
    fn_gtk_adjustment_get_value get_val = (fn_gtk_adjustment_get_value)resolve_sym("gtk_adjustment_get_value");
    if (get_val) {
        double val = get_val(vadj);
        if (g_pending_scroll_restore > 0.0 && val < 1.0) {
            return;
        }
        g_last_scroll_y = val < 0.0 ? 0.0 : val;
    }
}

static void c_vadj_changed(void* vadj, void* data) {
    (void)data;
    if (!g_scroll_tracking_enabled || !vadj || g_pending_scroll_restore <= 0.0) return;
    fn_gtk_adjustment_get_upper get_upper = (fn_gtk_adjustment_get_upper)resolve_sym("gtk_adjustment_get_upper");
    fn_gtk_adjustment_get_page_size get_page = (fn_gtk_adjustment_get_page_size)resolve_sym("gtk_adjustment_get_page_size");
    fn_gtk_adjustment_set_value set_val = (fn_gtk_adjustment_set_value)resolve_sym("gtk_adjustment_set_value");
    if (get_upper && get_page && set_val) {
        double upper = get_upper(vadj);
        double page = get_page(vadj);
        if (upper > page + 1.0 && page > 1.0) {
            double target = g_pending_scroll_restore;
            double max_val = upper - page;
            if (target > max_val) target = max_val;
            if (target < 0.0) target = 0.0;
            g_pending_scroll_restore = 0.0;
            set_val(vadj, target);
            g_last_scroll_y = target;
        }
    }
}

typedef struct {
    int type;
    void* window;
    int8_t send_event;
    KGtkAllocation area;
    void* region;
    int count;
} KGdkEventExpose;

typedef struct {
    KWidgetRef child;
    double scroll_y;
    int child_natural_height;
    uint8_t bg_gray;
    bool in_reallocate;
} KFrozenScrollState;

static void c_frozen_child_size_request(KWidgetRef widget, KGtkRequisition* req, void* data) {
    (void)widget;
    KFrozenScrollState* st = (KFrozenScrollState*)data;
    if (req) {
        if (st && req->height > 100) {
            st->child_natural_height = req->height;
        }
        if (req->width > 100) req->width = 100;
        if (req->height > 100) req->height = 100;
    }
}

static void c_frozen_scroll_size_allocate(KWidgetRef widget, KGtkAllocation* alloc, void* data) {
    (void)widget;
    KFrozenScrollState* st = (KFrozenScrollState*)data;
    if (!st || !st->child || !alloc || st->in_reallocate) return;
    fn_gtk_widget_size_allocate size_alloc = (fn_gtk_widget_size_allocate)resolve_sym("gtk_widget_size_allocate");
    if (!size_alloc) return;

    int nat_h = st->child_natural_height > alloc->height ? st->child_natural_height : alloc->height;
    double max_scroll = (double)(nat_h - alloc->height);
    if (max_scroll < 0.0) max_scroll = 0.0;
    double sy = st->scroll_y;
    if (sy > max_scroll) sy = max_scroll;
    if (sy < 0.0) sy = 0.0;

    KGtkAllocation child_alloc;
    child_alloc.x = alloc->x;
    child_alloc.y = alloc->y - (int)(sy + 0.5);
    child_alloc.width = alloc->width;
    child_alloc.height = nat_h;

    st->in_reallocate = true;
    size_alloc(st->child, &child_alloc);
    st->in_reallocate = false;
}

static int c_frozen_scroll_expose(KWidgetRef widget, void* event, void* data) {
    KFrozenScrollState* st = (KFrozenScrollState*)data;
    if (!st || !st->child || !widget || !event) return 1;

    fn_gtk_widget_get_allocation get_alloc = (fn_gtk_widget_get_allocation)resolve_sym("gtk_widget_get_allocation");
    fn_gtk_container_propagate_expose prop_expose = (fn_gtk_container_propagate_expose)resolve_sym("gtk_container_propagate_expose");
    fn_gdk_region_rectangle reg_rect = (fn_gdk_region_rectangle)resolve_sym("gdk_region_rectangle");
    fn_gdk_region_destroy reg_destroy = (fn_gdk_region_destroy)resolve_sym("gdk_region_destroy");
    if (!get_alloc || !prop_expose) return 0;

    KGtkAllocation alloc = { 0, 0, 0, 0 };
    get_alloc(widget, &alloc);
    if (alloc.width <= 1 || alloc.height <= 1) return 1;

    KGdkEventExpose* ev = (KGdkEventExpose*)event;
    int x1 = ev->area.x > alloc.x ? ev->area.x : alloc.x;
    int y1 = ev->area.y > alloc.y ? ev->area.y : alloc.y;
    int x2_ev = ev->area.x + ev->area.width;
    int y2_ev = ev->area.y + ev->area.height;
    int x2_al = alloc.x + alloc.width;
    int y2_al = alloc.y + alloc.height;
    int x2 = x2_ev < x2_al ? x2_ev : x2_al;
    int y2 = y2_ev < y2_al ? y2_ev : y2_al;
    if (x2 <= x1 || y2 <= y1) {
        return 1;
    }

    KGtkAllocation saved_area = ev->area;
    void* saved_region = ev->region;

    KGtkAllocation clipped = { x1, y1, x2 - x1, y2 - y1 };
    ev->area = clipped;
    void* new_reg = reg_rect ? reg_rect(&clipped) : NULL;
    if (new_reg) {
        ev->region = new_reg;
    }

    prop_expose(widget, st->child, event);

    ev->area = saved_area;
    ev->region = saved_region;
    if (new_reg && reg_destroy) {
        reg_destroy(new_reg);
    }
    return 1;
}
#endif

KWidgetRef kgtk_frozen_scrolled_view_new(uint8_t bg_gray) {
#if !defined(_WIN32)
    double saved_y = g_pending_scroll_restore > 0.0 ? g_pending_scroll_restore : g_last_scroll_y;
    g_pending_scroll_restore = saved_y;
    g_last_scroll_y = saved_y;
    g_active_scrolled_window = NULL;
    g_has_frozen_scroll = true;

    KWidgetRef eb = kgtk_event_box_new();
    fn_gtk_event_box_set_visible_window set_vis = (fn_gtk_event_box_set_visible_window)resolve_sym("gtk_event_box_set_visible_window");
    fn_g_signal_connect_data conn = (fn_g_signal_connect_data)resolve_sym("g_signal_connect_data");
    fn_g_object_set_data_full set_data = (fn_g_object_set_data_full)resolve_sym("g_object_set_data_full");
    if (!eb) return NULL;
    if (set_vis) set_vis(eb, 0);

    KFrozenScrollState* st = (KFrozenScrollState*)malloc(sizeof(KFrozenScrollState));
    if (st && conn) {
        st->child = NULL;
        st->scroll_y = saved_y;
        st->child_natural_height = 0;
        st->bg_gray = bg_gray;
        st->in_reallocate = false;
        if (set_data) {
            set_data(eb, "kindle-frozen-scroll-state", st, free);
        }
        conn(eb, "size-request", (void*)c_scrolled_window_size_request, NULL, NULL, 1);
        conn(eb, "size-allocate", (void*)c_frozen_scroll_size_allocate, st, NULL, 1);
        conn(eb, "expose-event", (void*)c_frozen_scroll_expose, st, NULL, 0);
    } else if (st) {
        free(st);
    }
    return eb;
#else
    (void)bg_gray;
    return NULL;
#endif
}

void kgtk_frozen_scrolled_view_add(KWidgetRef frozen_view, KWidgetRef child) {
#if !defined(_WIN32)
    if (!frozen_view || !child) return;
    typedef void* (*fn_g_object_get_data)(void*, const char*);
    fn_g_object_get_data get_data = (fn_g_object_get_data)resolve_sym("g_object_get_data");
    fn_g_signal_connect_data conn = (fn_g_signal_connect_data)resolve_sym("g_signal_connect_data");
    KFrozenScrollState* st = get_data ? (KFrozenScrollState*)get_data(frozen_view, "kindle-frozen-scroll-state") : NULL;
    if (st) {
        st->child = child;
    }
    if (conn) {
        conn(child, "size-request", (void*)c_frozen_child_size_request, st, NULL, 1);
    }
    kgtk_container_add(frozen_view, child);
#else
    (void)frozen_view;
    (void)child;
#endif
}

KWidgetRef kgtk_scrolled_window_new(void) {
#if !defined(_WIN32)
    fn_gtk_scrolled_window_new fn = (fn_gtk_scrolled_window_new)resolve_sym("gtk_scrolled_window_new");
    fn_gtk_scrolled_window_set_policy policy_fn = (fn_gtk_scrolled_window_set_policy)resolve_sym("gtk_scrolled_window_set_policy");
    fn_g_object_set_data_full set_data = (fn_g_object_set_data_full)resolve_sym("g_object_set_data_full");
    fn_g_signal_connect_data conn = (fn_g_signal_connect_data)resolve_sym("g_signal_connect_data");
    if (fn) {
        KWidgetRef sw = fn(NULL, NULL);
        if (policy_fn && sw) {
            // Horizontal: GTK_POLICY_NEVER (2), Vertical: GTK_POLICY_AUTOMATIC (1) so scrollbar only appears when content overflows
            policy_fn(sw, 2, 1);
        }
        if (set_data && sw) {
            set_data(sw, "kindle-is-scrolled-window", (void*)1, NULL);
        }
        if (conn && sw) {
            conn(sw, "scroll-event", (void*)c_ignore_scroll_wheel_event, NULL, NULL, 0);
        }
        if (sw) {
            if (!g_has_frozen_scroll && g_active_scrolled_window == NULL) {
                g_active_scrolled_window = sw;
            } else if (g_has_frozen_scroll && g_active_modal_scrolled_window == NULL) {
                g_active_modal_scrolled_window = sw;
            }
        }
        return sw;
    }
#endif
    return NULL;
}

void kgtk_scrolled_window_set_show_indicators(KWidgetRef scrolled_window, bool show_indicators) {
#if !defined(_WIN32)
    fn_gtk_scrolled_window_set_policy policy_fn = (fn_gtk_scrolled_window_set_policy)resolve_sym("gtk_scrolled_window_set_policy");
    if (policy_fn && scrolled_window) {
        // Horizontal: GTK_POLICY_NEVER (2), Vertical: AUTOMATIC (1) or NEVER (2)
        policy_fn(scrolled_window, 2, show_indicators ? 1 : 2);
    }
#endif
}

void kgtk_scrolled_window_set_bg_gray(KWidgetRef scrolled_window, uint8_t gray_level) {
#if !defined(_WIN32)
    if (!scrolled_window) return;
    kgtk_widget_modify_bg_gray(scrolled_window, 0, gray_level);
    fn_gtk_bin_get_child get_child = (fn_gtk_bin_get_child)resolve_sym("gtk_bin_get_child");
    if (get_child) {
        KWidgetRef vp = get_child(scrolled_window);
        if (vp) {
            kgtk_widget_modify_bg_gray(vp, 0, gray_level);
        }
    }
#endif
}

void kgtk_scrolled_window_add_with_viewport(KWidgetRef scrolled_window, KWidgetRef child) {
#if !defined(_WIN32)
    fn_gtk_scrolled_window_add_with_viewport fn = (fn_gtk_scrolled_window_add_with_viewport)resolve_sym("gtk_scrolled_window_add_with_viewport");
    fn_gtk_bin_get_child get_child = (fn_gtk_bin_get_child)resolve_sym("gtk_bin_get_child");
    fn_gtk_viewport_set_shadow_type set_shadow = (fn_gtk_viewport_set_shadow_type)resolve_sym("gtk_viewport_set_shadow_type");
    fn_gtk_widget_add_events add_events = (fn_gtk_widget_add_events)resolve_sym("gtk_widget_add_events");
    fn_g_signal_connect_data conn = (fn_g_signal_connect_data)resolve_sym("g_signal_connect_data");
    fn_g_object_set_data_full set_data = (fn_g_object_set_data_full)resolve_sym("g_object_set_data_full");
    fn_gtk_scrolled_window_get_vadjustment get_vadj = (fn_gtk_scrolled_window_get_vadjustment)resolve_sym("gtk_scrolled_window_get_vadjustment");
    if (fn && scrolled_window && child) {
        bool is_primary_scroll = (scrolled_window == g_active_scrolled_window);
        if (!is_primary_scroll && !g_has_frozen_scroll && g_active_scrolled_window == NULL) {
            g_active_scrolled_window = scrolled_window;
            is_primary_scroll = true;
        } else if (!is_primary_scroll && g_has_frozen_scroll && g_active_modal_scrolled_window == NULL) {
            g_active_modal_scrolled_window = scrolled_window;
        }
        if (conn) {
            // Connect G_CONNECT_AFTER (1) on child's "size-request" so GtkViewport never overflows horizontally
            conn(child, "size-request", (void*)c_viewport_child_size_request, NULL, NULL, 1);
            // Connect G_CONNECT_AFTER (1) on scrolled_window's "size-request" so it never pushes bottom bars off-screen
            conn(scrolled_window, "size-request", (void*)c_scrolled_window_size_request, NULL, NULL, 1);
            if (is_primary_scroll && get_vadj) {
                void* vadj = get_vadj(scrolled_window);
                if (vadj) {
                    conn(vadj, "value-changed", (void*)c_vadj_value_changed, NULL, NULL, 0);
                    conn(vadj, "changed", (void*)c_vadj_changed, NULL, NULL, 0);
                }
            }
        }
        fn(scrolled_window, child);
        if (get_child) {
            KWidgetRef vp = get_child(scrolled_window);
            if (vp) {
                if (set_shadow) set_shadow(vp, 0); // GTK_SHADOW_NONE = 0
                if (add_events && conn) {
                    // GDK_POINTER_MOTION_MASK (4) | GDK_BUTTON_PRESS_MASK (256) | GDK_BUTTON_RELEASE_MASK (512)
                    add_events(vp, 4 | 256 | 512);
                    conn(vp, "scroll-event", (void*)c_ignore_scroll_wheel_event, NULL, NULL, 0);
                    KScrollDragState* st = (KScrollDragState*)malloc(sizeof(KScrollDragState));
                    if (st) {
                        st->scrolled_window = scrolled_window;
                        st->dragging = false;
                        st->start_root_y = 0.0;
                        st->start_scroll_val = 0.0;
                        if (set_data) {
                            set_data(vp, "kindle-scroll-drag-state", st, free);
                        }
                        conn(vp, "button-press-event", (void*)c_scroll_drag_press, st, NULL, 0);
                        conn(vp, "motion-notify-event", (void*)c_scroll_drag_motion, st, NULL, 0);
                        conn(vp, "button-release-event", (void*)c_scroll_drag_release, st, NULL, 0);
                    }
                }
            }
        }
    }
#endif
}

KWidgetRef kgtk_event_box_new(void) {
#if !defined(_WIN32)
    fn_gtk_event_box_new fn = (fn_gtk_event_box_new)resolve_sym("gtk_event_box_new");
    if (fn) return fn();
#endif
    return NULL;
}

#if !defined(_WIN32)
static void c_zstack_clamp_size_request(KWidgetRef widget, KGtkRequisition* req, void* data) {
    (void)widget;
    (void)data;
    if (!req) return;
    if (g_window_default_w > 0 && req->width > g_window_default_w) {
        req->width = g_window_default_w;
    }
    if (g_window_default_h > 0 && req->height > g_window_default_h) {
        req->height = g_window_default_h;
    }
}
#endif

KWidgetRef kgtk_zstack_new(void) {
#if !defined(_WIN32)
    fn_gtk_table_new fn = (fn_gtk_table_new)resolve_sym("gtk_table_new");
    fn_g_signal_connect_data conn = (fn_g_signal_connect_data)resolve_sym("g_signal_connect_data");
    if (fn) {
        KWidgetRef tbl = fn(1, 1, 0);
        if (tbl && conn) {
            conn(tbl, "size-request", (void*)c_zstack_clamp_size_request, NULL, NULL, 1);
        }
        return tbl;
    }
#endif
    return kgtk_vbox_new(false, 0);
}

void kgtk_zstack_add(KWidgetRef zstack, KWidgetRef child) {
#if !defined(_WIN32)
    fn_gtk_table_attach attach = (fn_gtk_table_attach)resolve_sym("gtk_table_attach");
    if (attach && zstack && child) {
        // GTK_EXPAND | GTK_SHRINK | GTK_FILL = 1 | 2 | 4 = 7
        attach(zstack, child, 0, 1, 0, 1, 7, 7, 0, 0);
        return;
    }
#endif
    if (zstack && child) {
        kgtk_box_pack_start(zstack, child, true, true, 0);
    }
}

void kgtk_widget_set_sensitive(KWidgetRef widget, bool sensitive) {
#if !defined(_WIN32)
    fn_gtk_widget_set_sensitive fn = (fn_gtk_widget_set_sensitive)resolve_sym("gtk_widget_set_sensitive");
    if (fn && widget) fn(widget, sensitive ? 1 : 0);
#endif
}

#if !defined(_WIN32)
typedef struct {
    uint8_t bg_gray;
    double alpha;
} KModalScrimState;

static int c_modal_scrim_expose(KWidgetRef widget, void* event, void* data) {
    (void)event;
    KModalScrimState* st = (KModalScrimState*)data;
    if (!st || !widget) return 0;

    fn_gtk_widget_get_window get_win = (fn_gtk_widget_get_window)resolve_sym("gtk_widget_get_window");
    fn_gtk_widget_get_allocation get_alloc = (fn_gtk_widget_get_allocation)resolve_sym("gtk_widget_get_allocation");
    fn_gdk_cairo_create cairo_create = (fn_gdk_cairo_create)resolve_sym("gdk_cairo_create");
    fn_cairo_destroy cairo_destroy = (fn_cairo_destroy)resolve_sym("cairo_destroy");
    fn_cairo_set_source_rgba set_rgba = (fn_cairo_set_source_rgba)resolve_sym("cairo_set_source_rgba");
    fn_cairo_rectangle rect = (fn_cairo_rectangle)resolve_sym("cairo_rectangle");
    fn_cairo_fill fill = (fn_cairo_fill)resolve_sym("cairo_fill");
    if (!get_win || !get_alloc || !cairo_create || !cairo_destroy || !set_rgba || !rect || !fill) return 0;

    void* gdk_win = get_win(widget);
    if (!gdk_win) return 0;
    KGtkAllocation alloc = { 0, 0, 0, 0 };
    get_alloc(widget, &alloc);
    if (alloc.width <= 1 || alloc.height <= 1) return 0;

    void* cr = cairo_create(gdk_win);
    if (!cr) return 0;
    double g = (double)st->bg_gray / 255.0;
    set_rgba(cr, g, g, g, st->alpha);
    rect(cr, (double)alloc.x, (double)alloc.y, (double)alloc.width, (double)alloc.height);
    fill(cr);
    cairo_destroy(cr);
    return 0;
}
#endif

KWidgetRef kgtk_modal_scrim_new(KWidgetRef child, uint8_t bg_gray, double alpha, double xalign, double yalign, double xscale, double yscale) {
#if !defined(_WIN32)
    KWidgetRef align = kgtk_alignment_new(xalign, yalign, xscale, yscale);
    fn_g_signal_connect_data conn = (fn_g_signal_connect_data)resolve_sym("g_signal_connect_data");
    fn_g_object_set_data_full set_data = (fn_g_object_set_data_full)resolve_sym("g_object_set_data_full");
    if (!align) return child;
    if (child) kgtk_container_add(align, child);
    KModalScrimState* st = (KModalScrimState*)malloc(sizeof(KModalScrimState));
    if (st && conn) {
        st->bg_gray = bg_gray;
        st->alpha = alpha;
        if (set_data) {
            set_data(align, "kindle-modal-scrim-state", st, free);
        }
        conn(align, "expose-event", (void*)c_modal_scrim_expose, st, NULL, 0);
    } else if (st) {
        free(st);
    }
    return align;
#else
    return child;
#endif
}

KWidgetRef kgtk_label_new(const char* text) {
#if !defined(_WIN32)
    fn_gtk_label_new fn = (fn_gtk_label_new)resolve_sym("gtk_label_new");
    if (fn) return fn(text);
#endif
    return NULL;
}

void kgtk_label_set_text(KWidgetRef label, const char* text) {
#if !defined(_WIN32)
    fn_gtk_label_set_text fn = (fn_gtk_label_set_text)resolve_sym("gtk_label_set_text");
    if (fn && label) fn(label, text);
#endif
}

void kgtk_label_set_markup(KWidgetRef label, const char* markup) {
#if !defined(_WIN32)
    fn_gtk_label_set_markup fn = (fn_gtk_label_set_markup)resolve_sym("gtk_label_set_markup");
    if (fn && label) fn(label, markup);
#endif
}

#if !defined(_WIN32)
typedef void* (KGTK_ABI *fn_gtk_label_get_layout)(KWidgetRef);
typedef void (KGTK_ABI *fn_pango_layout_set_width)(void*, int);
typedef void (KGTK_ABI *fn_pango_layout_set_wrap)(void*, int);
typedef int (KGTK_ABI *fn_pango_layout_get_width)(void*);
typedef void (KGTK_ABI *fn_pango_layout_get_pixel_size)(void*, int*, int*);
typedef void (KGTK_ABI *fn_gtk_widget_queue_resize)(KWidgetRef);

static void c_label_wrap_size_request(KWidgetRef widget, KGtkRequisition* req, void* data) {
    (void)data;
    if (!widget || !req) return;
    fn_gtk_label_get_layout get_layout = (fn_gtk_label_get_layout)resolve_sym("gtk_label_get_layout");
    fn_pango_layout_set_width set_width = (fn_pango_layout_set_width)resolve_sym("pango_layout_set_width");
    fn_pango_layout_set_wrap set_wrap = (fn_pango_layout_set_wrap)resolve_sym("pango_layout_set_wrap");
    fn_pango_layout_get_pixel_size get_pixel_size = (fn_pango_layout_get_pixel_size)resolve_sym("pango_layout_get_pixel_size");
    fn_g_object_get_data get_data = (fn_g_object_get_data)resolve_sym("g_object_get_data");
    if (!get_layout || !set_width || !get_pixel_size) return;

    void* layout = get_layout(widget);
    if (!layout) return;
    if (set_wrap) set_wrap(layout, 0); // PANGO_WRAP_WORD

    int saved_w = get_data ? (int)(intptr_t)get_data(widget, "kindle-label-wrap-w") : 0;
    int wrap_w = saved_w;
    if (wrap_w <= 60) {
        wrap_w = kgtk_scale_px(1120);
        if (wrap_w <= 60) wrap_w = 750;
    }

    int pad_deduct = (saved_w > 60) ? 2 : 6;
    int target_pango_w = (wrap_w - pad_deduct) * 1024;
    set_width(layout, target_pango_w);

    int lw = 0, lh = 0;
    get_pixel_size(layout, &lw, &lh);
    req->width = (saved_w > 60) ? saved_w : kgtk_scale_px(120);
    if (lh > 0) {
        req->height = lh + 4;
    }
}

static void c_label_wrap_size_allocate(KWidgetRef widget, KGtkAllocation* alloc, void* data) {
    (void)data;
    if (!widget || !alloc || alloc->width <= 60) return;
    fn_gtk_label_get_layout get_layout = (fn_gtk_label_get_layout)resolve_sym("gtk_label_get_layout");
    fn_pango_layout_set_width set_width = (fn_pango_layout_set_width)resolve_sym("pango_layout_set_width");
    fn_pango_layout_set_wrap set_wrap = (fn_pango_layout_set_wrap)resolve_sym("pango_layout_set_wrap");
    fn_pango_layout_get_width get_width = (fn_pango_layout_get_width)resolve_sym("pango_layout_get_width");
    fn_pango_layout_get_pixel_size get_pixel_size = (fn_pango_layout_get_pixel_size)resolve_sym("pango_layout_get_pixel_size");
    fn_gtk_widget_queue_resize queue_resize = (fn_gtk_widget_queue_resize)resolve_sym("gtk_widget_queue_resize");
    fn_g_object_get_data get_data = (fn_g_object_get_data)resolve_sym("g_object_get_data");
    fn_g_object_set_data_full set_data = (fn_g_object_set_data_full)resolve_sym("g_object_set_data_full");
    if (!get_layout || !set_width) return;

    void* layout = get_layout(widget);
    if (!layout) return;
    if (set_wrap) set_wrap(layout, 0); // PANGO_WRAP_WORD

    int prev_w = get_data ? (int)(intptr_t)get_data(widget, "kindle-label-wrap-w") : 0;
    int target_pango_w = (alloc->width - 2) * 1024;
    if (!get_width || get_width(layout) != target_pango_w) {
        set_width(layout, target_pango_w);
    }

    int diff_w = alloc->width - prev_w;
    if (diff_w < 0) diff_w = -diff_w;
    if (diff_w > 4) {
        if (set_data) {
            set_data(widget, "kindle-label-wrap-w", (void*)(intptr_t)alloc->width, NULL);
        }
        if (get_pixel_size && queue_resize) {
            int lw = 0, lh = 0;
            get_pixel_size(layout, &lw, &lh);
            if (lh > 0 && (alloc->height < lh + 2 || alloc->height > lh + 10)) {
                queue_resize(widget);
            }
        }
    }
}
#endif

void kgtk_label_set_line_wrap(KWidgetRef label, bool wrap) {
#if !defined(_WIN32)
    fn_gtk_label_set_line_wrap fn = (fn_gtk_label_set_line_wrap)resolve_sym("gtk_label_set_line_wrap");
    if (fn && label) fn(label, wrap ? 1 : 0);
    if (wrap && label) {
        fn_g_signal_connect_data conn = (fn_g_signal_connect_data)resolve_sym("g_signal_connect_data");
        if (conn) {
            conn(label, "size-request", (void*)c_label_wrap_size_request, NULL, NULL, 1);
            conn(label, "size-allocate", (void*)c_label_wrap_size_allocate, NULL, NULL, 0);
        }
    }
#endif
}

void kgtk_label_set_justify(KWidgetRef label, int justify) {
#if !defined(_WIN32)
    fn_gtk_label_set_justify fn = (fn_gtk_label_set_justify)resolve_sym("gtk_label_set_justify");
    if (fn && label) fn(label, justify);
#endif
}

void kgtk_misc_set_alignment(KWidgetRef misc, float xalign, float yalign) {
#if !defined(_WIN32)
    fn_gtk_misc_set_alignment fn = (fn_gtk_misc_set_alignment)resolve_sym("gtk_misc_set_alignment");
    if (fn && misc) fn(misc, xalign, yalign);
#endif
}

KWidgetRef kgtk_button_new_with_label(const char* label) {
#if !defined(_WIN32)
    fn_gtk_button_new_with_label fn = (fn_gtk_button_new_with_label)resolve_sym("gtk_button_new_with_label");
    if (fn) return fn(label);
#endif
    return NULL;
}

void kgtk_button_set_label(KWidgetRef button, const char* label) {
#if !defined(_WIN32)
    fn_gtk_button_set_label fn = (fn_gtk_button_set_label)resolve_sym("gtk_button_set_label");
    if (fn && button) fn(button, label);
#endif
}

KWidgetRef kgtk_check_button_new_with_label(const char* label) {
#if !defined(_WIN32)
    fn_gtk_check_button_new_with_label fn = (fn_gtk_check_button_new_with_label)resolve_sym("gtk_check_button_new_with_label");
    if (fn) return fn(label);
#endif
    return NULL;
}

bool kgtk_toggle_button_get_active(KWidgetRef toggle_button) {
#if !defined(_WIN32)
    fn_gtk_toggle_button_get_active fn = (fn_gtk_toggle_button_get_active)resolve_sym("gtk_toggle_button_get_active");
    if (fn && toggle_button) return fn(toggle_button) != 0;
#endif
    return false;
}

void kgtk_toggle_button_set_active(KWidgetRef toggle_button, bool is_active) {
#if !defined(_WIN32)
    fn_gtk_toggle_button_set_active fn = (fn_gtk_toggle_button_set_active)resolve_sym("gtk_toggle_button_set_active");
    if (fn && toggle_button) fn(toggle_button, is_active ? 1 : 0);
#endif
}

KWidgetRef kgtk_entry_new(void) {
#if !defined(_WIN32)
    fn_gtk_entry_new fn = (fn_gtk_entry_new)resolve_sym("gtk_entry_new");
    if (fn) return fn();
#endif
    return NULL;
}

void kgtk_entry_set_text(KWidgetRef entry, const char* text) {
#if !defined(_WIN32)
    fn_gtk_entry_set_text fn = (fn_gtk_entry_set_text)resolve_sym("gtk_entry_set_text");
    if (fn && entry && text) fn(entry, text);
#endif
}

const char* kgtk_entry_get_text(KWidgetRef entry) {
#if !defined(_WIN32)
    fn_gtk_entry_get_text fn = (fn_gtk_entry_get_text)resolve_sym("gtk_entry_get_text");
    if (fn && entry) return fn(entry);
#endif
    return "";
}

KWidgetRef kgtk_progress_bar_new(void) {
#if !defined(_WIN32)
    fn_gtk_progress_bar_new fn = (fn_gtk_progress_bar_new)resolve_sym("gtk_progress_bar_new");
    if (fn) return fn();
#endif
    return NULL;
}

void kgtk_progress_bar_set_fraction(KWidgetRef pbar, double fraction) {
#if !defined(_WIN32)
    fn_gtk_progress_bar_set_fraction fn = (fn_gtk_progress_bar_set_fraction)resolve_sym("gtk_progress_bar_set_fraction");
    if (fn && pbar) fn(pbar, fraction);
#endif
}

void kgtk_progress_bar_set_text(KWidgetRef pbar, const char* text) {
#if !defined(_WIN32)
    fn_gtk_progress_bar_set_text fn = (fn_gtk_progress_bar_set_text)resolve_sym("gtk_progress_bar_set_text");
    if (fn && pbar) fn(pbar, text);
#endif
}

KWidgetRef kgtk_hscale_new_with_range(double min, double max, double step) {
#if !defined(_WIN32)
    fn_gtk_hscale_new_with_range fn = (fn_gtk_hscale_new_with_range)resolve_sym("gtk_hscale_new_with_range");
    if (fn) return fn(min, max, step);
#endif
    return NULL;
}

double kgtk_range_get_value(KWidgetRef range) {
#if !defined(_WIN32)
    fn_gtk_range_get_value fn = (fn_gtk_range_get_value)resolve_sym("gtk_range_get_value");
    if (fn && range) return fn(range);
#endif
    return 0.0;
}

void kgtk_range_set_value(KWidgetRef range, double value) {
#if !defined(_WIN32)
    fn_gtk_range_set_value fn = (fn_gtk_range_set_value)resolve_sym("gtk_range_set_value");
    if (fn && range) fn(range, value);
#endif
}

#if !defined(_WIN32)
static int c_scale_button_press(KWidgetRef widget, void* event, void* data) {
    (void)widget; (void)data;
    if (!c_event_is_button1_press(event)) return 1;
    g_slider_dragging = true;
    return 0; // FALSE: let GtkRange handle the press too
}

static int c_scale_button_release(KWidgetRef widget, void* event, void* data) {
    (void)widget;
    if (!c_event_is_button1_release(event)) return 1;
    g_slider_dragging = false;
    KIdleTask* task = (KIdleTask*)data;
    if (task && task->callback) {
        kgtk_schedule_idle(task->callback, task->user_data);
    }
    return 0; // FALSE: let GtkRange finish handling release
}
#endif

void kgtk_scale_connect_drag_watch(KWidgetRef scale, KIdleCallback on_drag_end, void* user_data) {
#if !defined(_WIN32)
    fn_g_signal_connect_data conn = (fn_g_signal_connect_data)resolve_sym("g_signal_connect_data");
    fn_g_object_set_data_full set_data = (fn_g_object_set_data_full)resolve_sym("g_object_set_data_full");
    if (conn && scale && on_drag_end) {
        KIdleTask* task = (KIdleTask*)malloc(sizeof(KIdleTask));
        if (task) {
            task->callback = on_drag_end;
            task->user_data = user_data;
            if (set_data) {
                set_data(scale, "kindle-scale-drag-task", task, free);
            }
            conn(scale, "button-press-event", (void*)c_scale_button_press, task, NULL, 0);
            conn(scale, "button-release-event", (void*)c_scale_button_release, task, NULL, 0);
        }
    }
#endif
}

KWidgetRef kgtk_hseparator_new(void) {
#if !defined(_WIN32)
    fn_gtk_separator_new fn = (fn_gtk_separator_new)resolve_sym("gtk_hseparator_new");
    if (fn) return fn();
#endif
    return NULL;
}

KWidgetRef kgtk_vseparator_new(void) {
#if !defined(_WIN32)
    fn_gtk_separator_new fn = (fn_gtk_separator_new)resolve_sym("gtk_vseparator_new");
    if (fn) return fn();
#endif
    return NULL;
}

static uint8_t kgtk_quantize_eink_gray(uint8_t gray);

KWidgetRef kgtk_image_new_from_file(const char* filename) {
#if !defined(_WIN32)
    fn_gtk_image_new_from_file fn = (fn_gtk_image_new_from_file)resolve_sym("gtk_image_new_from_file");
    if (fn && filename) return fn(filename);
#endif
    return NULL;
}

KWidgetRef kgtk_image_new_from_file_scaled(const char* filename, int max_width, int max_height) {
#if !defined(_WIN32)
    if (!filename) return NULL;
    typedef void* (KGTK_ABI *fn_gdk_pixbuf_new_from_file_at_scale)(const char*, int, int, int, void**);
    typedef void* (KGTK_ABI *fn_gdk_pixbuf_new_from_file)(const char*, void**);
    typedef KWidgetRef (KGTK_ABI *fn_gtk_image_new_from_pixbuf)(void*);
    typedef uint8_t* (KGTK_ABI *fn_gdk_pixbuf_get_pixels)(void*);
    typedef int (KGTK_ABI *fn_gdk_pixbuf_get_width)(void*);
    typedef int (KGTK_ABI *fn_gdk_pixbuf_get_height)(void*);
    typedef int (KGTK_ABI *fn_gdk_pixbuf_get_rowstride)(void*);
    typedef int (KGTK_ABI *fn_gdk_pixbuf_get_n_channels)(void*);

    fn_gdk_pixbuf_new_from_file_at_scale pb_scale = (fn_gdk_pixbuf_new_from_file_at_scale)resolve_sym("gdk_pixbuf_new_from_file_at_scale");
    fn_gdk_pixbuf_new_from_file pb_file = (fn_gdk_pixbuf_new_from_file)resolve_sym("gdk_pixbuf_new_from_file");
    fn_gtk_image_new_from_pixbuf img_from_pb = (fn_gtk_image_new_from_pixbuf)resolve_sym("gtk_image_new_from_pixbuf");
    fn_gdk_pixbuf_get_pixels get_pixels = (fn_gdk_pixbuf_get_pixels)resolve_sym("gdk_pixbuf_get_pixels");
    fn_gdk_pixbuf_get_width get_w = (fn_gdk_pixbuf_get_width)resolve_sym("gdk_pixbuf_get_width");
    fn_gdk_pixbuf_get_height get_h = (fn_gdk_pixbuf_get_height)resolve_sym("gdk_pixbuf_get_height");
    fn_gdk_pixbuf_get_rowstride get_stride = (fn_gdk_pixbuf_get_rowstride)resolve_sym("gdk_pixbuf_get_rowstride");
    fn_gdk_pixbuf_get_n_channels get_ch = (fn_gdk_pixbuf_get_n_channels)resolve_sym("gdk_pixbuf_get_n_channels");
    fn_g_object_unref unref = (fn_g_object_unref)resolve_sym("g_object_unref");

    void* pb = NULL;
    int sw = max_width > 0 ? kgtk_scale_px(max_width) : -1;
    int sh = max_height > 0 ? kgtk_scale_px(max_height) : -1;
    if ((sw > 0 || sh > 0) && pb_scale) {
        pb = pb_scale(filename, sw, sh, 1, NULL);
    } else if (pb_file) {
        pb = pb_file(filename, NULL);
    }

    if (pb && img_from_pb) {
        if (get_pixels && get_w && get_h && get_stride && get_ch) {
            uint8_t* pixels = get_pixels(pb);
            int w = get_w(pb);
            int h = get_h(pb);
            int stride = get_stride(pb);
            int nch = get_ch(pb);
            if (pixels && w > 0 && h > 0 && (nch == 3 || nch == 4)) {
                for (int y = 0; y < h; ++y) {
                    uint8_t* row = pixels + y * stride;
                    for (int x = 0; x < w; ++x) {
                        uint8_t r = row[x * nch + 0];
                        uint8_t g = row[x * nch + 1];
                        uint8_t b = row[x * nch + 2];
                        unsigned int lum = (77u * r + 150u * g + 29u * b) >> 8;
                        if (nch == 4) {
                            unsigned int a = row[x * nch + 3];
                            lum = (lum * a + 255u * (255u - a)) / 255u;
                            row[x * nch + 3] = 255;
                        }
                        uint8_t q = kgtk_quantize_eink_gray((uint8_t)lum);
                        row[x * nch + 0] = q;
                        row[x * nch + 1] = q;
                        row[x * nch + 2] = q;
                    }
                }
            }
        }
        KWidgetRef img = img_from_pb(pb);
        if (unref) unref(pb);
        return img;
    }
#endif
    return kgtk_image_new_from_file(filename);
}

// --- Interactive E-Ink Drawing Canvas (GtkDrawingArea) ---

KWidgetRef kgtk_drawing_area_new(void) {
#if !defined(_WIN32)
    fn_gtk_drawing_area_new fn = (fn_gtk_drawing_area_new)resolve_sym("gtk_drawing_area_new");
    fn_gtk_widget_add_events add_events = (fn_gtk_widget_add_events)resolve_sym("gtk_widget_add_events");
    if (fn) {
        KWidgetRef da = fn();
        if (da && add_events) {
            // GDK_EXPOSURE_MASK (2) | GDK_POINTER_MOTION_MASK (4) | GDK_BUTTON_MOTION_MASK (16)
            // | GDK_BUTTON1_MOTION_MASK (32) | GDK_BUTTON_PRESS_MASK (256) | GDK_BUTTON_RELEASE_MASK (512)
            add_events(da, 2 | 4 | 16 | 32 | 256 | 512);
        }
        return da;
    }
#endif
    return NULL;
}

KWidgetRef kgtk_nowindow_canvas_new(void) {
#if !defined(_WIN32)
    KWidgetRef align = kgtk_alignment_new(0.0, 0.0, 1.0, 1.0);
    fn_g_object_set_data_full set_data = (fn_g_object_set_data_full)resolve_sym("g_object_set_data_full");
    if (align && set_data) {
        set_data(align, "kindle-nowindow-canvas", (void*)1, NULL);
    }
    return align;
#else
    return NULL;
#endif
}

#if !defined(_WIN32)
static KGtkAllocation g_canvas_expose_area = { 0, 0, 0, 0 };
static bool g_has_canvas_expose_area = false;
#endif

void kgtk_widget_get_size(KWidgetRef widget, int* out_width, int* out_height) {
    int w = 0, h = 0;
#if !defined(_WIN32)
    fn_gtk_widget_get_allocation get_alloc = (fn_gtk_widget_get_allocation)resolve_sym("gtk_widget_get_allocation");
    if (get_alloc && widget) {
        KGtkAllocation alloc = { 0, 0, 0, 0 };
        get_alloc(widget, &alloc);
        w = alloc.width;
        h = alloc.height;
    }
#endif
    if (out_width) *out_width = w;
    if (out_height) *out_height = h;
}

void kgtk_widget_queue_draw_rect(KWidgetRef widget, int x, int y, int width, int height) {
#if !defined(_WIN32)
    fn_gtk_widget_queue_draw_area fn = (fn_gtk_widget_queue_draw_area)resolve_sym("gtk_widget_queue_draw_area");
    fn_gtk_widget_get_window get_win = (fn_gtk_widget_get_window)resolve_sym("gtk_widget_get_window");
    fn_gdk_window_process_updates proc_win = (fn_gdk_window_process_updates)resolve_sym("gdk_window_process_updates");
    if (fn && widget && width > 0 && height > 0) {
        fn(widget, x, y, width, height);
        if (get_win && proc_win) {
            void* gdk_win = get_win(widget);
            if (gdk_win) {
                proc_win(gdk_win, 0);
            }
        }
    }
#endif
}

void kgtk_draw_gray_pixels(KWidgetRef widget, const uint8_t* pixels, int width, int height, int stride) {
#if !defined(_WIN32)
    fn_gtk_widget_get_window get_win = (fn_gtk_widget_get_window)resolve_sym("gtk_widget_get_window");
    fn_gtk_widget_get_allocation get_alloc = (fn_gtk_widget_get_allocation)resolve_sym("gtk_widget_get_allocation");
    fn_gdk_gc_new gc_new = (fn_gdk_gc_new)resolve_sym("gdk_gc_new");
    fn_gdk_gc_set_clip_rectangle set_clip = (fn_gdk_gc_set_clip_rectangle)resolve_sym("gdk_gc_set_clip_rectangle");
    fn_gdk_draw_gray_image draw_gray = (fn_gdk_draw_gray_image)resolve_sym("gdk_draw_gray_image");
    fn_g_object_unref unref = (fn_g_object_unref)resolve_sym("g_object_unref");
    typedef void* (*fn_g_object_get_data)(void*, const char*);
    fn_g_object_get_data get_data = (fn_g_object_get_data)resolve_sym("g_object_get_data");
    if (get_win && gc_new && draw_gray && widget && pixels && width > 0 && height > 0) {
        void* gdk_win = get_win(widget);
        if (gdk_win) {
            void* gc = gc_new(gdk_win);
            if (gc) {
                bool is_nowin = get_data && (get_data(widget, "kindle-nowindow-canvas") != NULL);
                if (is_nowin && get_alloc) {
                    KGtkAllocation alloc = { 0, 0, 0, 0 };
                    get_alloc(widget, &alloc);
                    if (set_clip && g_has_canvas_expose_area) {
                        set_clip(gc, &g_canvas_expose_area);
                    }
                    draw_gray(gdk_win, gc, alloc.x, alloc.y, width, height, 0, pixels, stride);
                } else if (g_has_canvas_expose_area) {
                    int rx = g_canvas_expose_area.x;
                    int ry = g_canvas_expose_area.y;
                    int rw = g_canvas_expose_area.width;
                    int rh = g_canvas_expose_area.height;
                    if (rx < 0) { rw += rx; rx = 0; }
                    if (ry < 0) { rh += ry; ry = 0; }
                    if (rx + rw > width) rw = width - rx;
                    if (ry + rh > height) rh = height - ry;
                    if (rw > 0 && rh > 0) {
                        draw_gray(gdk_win, gc, rx, ry, rw, rh, 0, pixels + ry * stride + rx, stride);
                    }
                } else {
                    draw_gray(gdk_win, gc, 0, 0, width, height, 0, pixels, stride);
                }
                if (unref) unref(gc);
            }
        }
    }
#endif
}

#if !defined(_WIN32)
typedef struct {
    KCanvasExposeCallback on_expose;
    KCanvasPointerCallback on_pointer;
    void* user_data;
} KCanvasHandler;

static int c_canvas_expose(KWidgetRef widget, void* event, void* data) {
    KCanvasHandler* h = (KCanvasHandler*)data;
    if (h && h->on_expose) {
        int w = 0, height = 0;
        kgtk_widget_get_size(widget, &w, &height);
        if (w > 0 && height > 0) {
            if (event) {
                g_canvas_expose_area = ((KGdkEventExpose*)event)->area;
                g_has_canvas_expose_area = true;
            }
            h->on_expose(widget, w, height, h->user_data);
            g_has_canvas_expose_area = false;
        }
    }
    return 0;
}

static int c_canvas_button_press(KWidgetRef widget, void* event, void* data) {
    if (!c_event_is_button1_press(event)) return 1;
    KCanvasHandler* h = (KCanvasHandler*)data;
    g_canvas_dragging = true;
    if (h && h->on_pointer && event) {
        fn_gdk_event_get_coords get_coords = (fn_gdk_event_get_coords)resolve_sym("gdk_event_get_coords");
        double x = 0, y = 0;
        if (get_coords && get_coords(event, &x, &y)) {
            h->on_pointer(widget, 0, (int)x, (int)y, h->user_data);
        }
    }
    return 1;
}

static int c_canvas_motion_notify(KWidgetRef widget, void* event, void* data) {
    if (!g_canvas_dragging) return 0;
    KCanvasHandler* h = (KCanvasHandler*)data;
    if (h && h->on_pointer && event) {
        fn_gdk_event_get_coords get_coords = (fn_gdk_event_get_coords)resolve_sym("gdk_event_get_coords");
        double x = 0, y = 0;
        if (get_coords && get_coords(event, &x, &y)) {
            h->on_pointer(widget, 1, (int)x, (int)y, h->user_data);
        }
    }
    return 1;
}

static int c_canvas_button_release(KWidgetRef widget, void* event, void* data) {
    if (!c_event_is_button1_release(event)) return 1;
    if (!g_canvas_dragging) return 0;
    g_canvas_dragging = false;
    KCanvasHandler* h = (KCanvasHandler*)data;
    if (h && h->on_pointer && event) {
        fn_gdk_event_get_coords get_coords = (fn_gdk_event_get_coords)resolve_sym("gdk_event_get_coords");
        double x = 0, y = 0;
        if (get_coords && get_coords(event, &x, &y)) {
            h->on_pointer(widget, 2, (int)x, (int)y, h->user_data);
        }
    }
    return 1;
}
#endif

void kgtk_drawing_area_connect(
    KWidgetRef widget,
    KCanvasExposeCallback on_expose,
    KCanvasPointerCallback on_pointer,
    void* user_data
) {
#if !defined(_WIN32)
    fn_g_signal_connect_data conn = (fn_g_signal_connect_data)resolve_sym("g_signal_connect_data");
    fn_g_object_set_data_full set_data = (fn_g_object_set_data_full)resolve_sym("g_object_set_data_full");
    if (conn && widget) {
        KCanvasHandler* h = (KCanvasHandler*)malloc(sizeof(KCanvasHandler));
        if (h) {
            h->on_expose = on_expose;
            h->on_pointer = on_pointer;
            h->user_data = user_data;
            if (set_data) {
                set_data(widget, "kindle-canvas-handler", h, free);
            }
            conn(widget, "expose-event", (void*)c_canvas_expose, h, NULL, 0);
            conn(widget, "button-press-event", (void*)c_canvas_button_press, h, NULL, 0);
            conn(widget, "motion-notify-event", (void*)c_canvas_motion_notify, h, NULL, 0);
            conn(widget, "button-release-event", (void*)c_canvas_button_release, h, NULL, 0);
        }
    }
#endif
}

void kgtk_widget_set_size_request(KWidgetRef widget, int width, int height) {
#if !defined(_WIN32)
    fn_gtk_widget_set_size_request fn = (fn_gtk_widget_set_size_request)resolve_sym("gtk_widget_set_size_request");
    int sw = width > 0 ? kgtk_scale_px(width) : width;
    int sh = height > 0 ? kgtk_scale_px(height) : height;
    if (sw > 0 && widget) {
        fn_g_object_set_data_full set_data = (fn_g_object_set_data_full)resolve_sym("g_object_set_data_full");
        if (set_data) {
            set_data(widget, "kindle-label-wrap-w", (void*)(intptr_t)sw, NULL);
        }
    }
    if (fn && widget) fn(widget, sw, sh);
#endif
}

void kgtk_widget_show(KWidgetRef widget) {
#if !defined(_WIN32)
    fn_gtk_widget_show fn = (fn_gtk_widget_show)resolve_sym("gtk_widget_show");
    if (fn && widget) fn(widget);
#endif
}

void kgtk_widget_show_all(KWidgetRef widget) {
#if !defined(_WIN32)
    fn_gtk_widget_show_all fn = (fn_gtk_widget_show_all)resolve_sym("gtk_widget_show_all");
    if (fn && widget) fn(widget);
#endif
}

void kgtk_widget_hide(KWidgetRef widget) {
#if !defined(_WIN32)
    fn_gtk_widget_hide fn = (fn_gtk_widget_hide)resolve_sym("gtk_widget_hide");
    if (fn && widget) fn(widget);
#endif
}

void kgtk_widget_destroy(KWidgetRef widget) {
#if !defined(_WIN32)
    fn_gtk_widget_destroy fn = (fn_gtk_widget_destroy)resolve_sym("gtk_widget_destroy");
    if (fn && widget) fn(widget);
#endif
}

void kgtk_widget_queue_draw(KWidgetRef widget) {
#if !defined(_WIN32)
    fn_gtk_widget_queue_draw fn = (fn_gtk_widget_queue_draw)resolve_sym("gtk_widget_queue_draw");
    if (fn && widget) fn(widget);
#endif
}

#if !defined(_WIN32)
static bool is_gtk_button(KWidgetRef widget) {
    fn_gtk_type_Fn get_type = (fn_gtk_type_Fn)resolve_sym("gtk_button_get_type");
    fn_g_type_check_instance_is_a check_is_a = (fn_g_type_check_instance_is_a)resolve_sym("g_type_check_instance_is_a");
    if (get_type && check_is_a && widget) {
        return check_is_a(widget, get_type()) != 0;
    }
    return false;
}

static bool is_gtk_frame(KWidgetRef widget) {
    fn_gtk_type_Fn get_type = (fn_gtk_type_Fn)resolve_sym("gtk_frame_get_type");
    fn_g_type_check_instance_is_a check_is_a = (fn_g_type_check_instance_is_a)resolve_sym("g_type_check_instance_is_a");
    if (get_type && check_is_a && widget) {
        return check_is_a(widget, get_type()) != 0;
    }
    return false;
}
static uint8_t kgtk_quantize_eink_gray(uint8_t gray) {
    // Snap 8-bit gray to the 16 native E-Ink / Cairo 8-bit Xlib gray cube levels (0x00, 0x11, ..., 0xEE, 0xFF).
    // This prevents Cairo's XFillRectangle fast-path and Cairo's image compositor (rounded corners / Pango glyphs)
    // from emitting different 8-bit colormap indices that map to different 4-bit E-Ink nibbles.
    if (gray >= 240 && gray < 252) return 0xEE;
    if (gray > 3 && gray <= 15) return 0x11;
    unsigned int idx = ((unsigned int)gray + 8u) / 17u;
    if (idx > 15u) idx = 15u;
    return (uint8_t)(idx * 17u);
}
#endif

void kgtk_widget_modify_bg_gray(KWidgetRef widget, int state, uint8_t gray_level) {
#if !defined(_WIN32)
    fn_gtk_widget_modify_bg fn = (fn_gtk_widget_modify_bg)resolve_sym("gtk_widget_modify_bg");
    if (fn && widget) {
        gray_level = kgtk_quantize_eink_gray(gray_level);
        uint16_t c16 = ((uint16_t)gray_level << 8) | gray_level;
        KGdkColor color = { 0, c16, c16, c16 };
        fn(widget, state, &color);
        if (state == 0) {
            // Also set PRELIGHT (2) and ACTIVE (1) so E-Ink buttons retain high contrast
            fn(widget, 2, &color);
            uint8_t active_gray = kgtk_quantize_eink_gray(gray_level > 128 ? (gray_level - 34) : (gray_level + 34));
            uint16_t ac16 = ((uint16_t)active_gray << 8) | active_gray;
            KGdkColor active_color = { 0, ac16, ac16, ac16 };
            fn(widget, 1, &active_color);
        }
    }
#endif
}

void kgtk_widget_modify_fg_gray(KWidgetRef widget, int state, uint8_t gray_level) {
#if !defined(_WIN32)
    fn_gtk_widget_modify_fg fn = (fn_gtk_widget_modify_fg)resolve_sym("gtk_widget_modify_fg");
    if (fn && widget) {
        gray_level = kgtk_quantize_eink_gray(gray_level);
        uint16_t c16 = ((uint16_t)gray_level << 8) | gray_level;
        KGdkColor color = { 0, c16, c16, c16 };
        fn(widget, state, &color);
        if (state == 0) {
            fn(widget, 1, &color);
            fn(widget, 2, &color);
        }
        if (is_gtk_frame(widget)) {
            fn_gtk_frame_get_label_widget get_lbl = (fn_gtk_frame_get_label_widget)resolve_sym("gtk_frame_get_label_widget");
            if (get_lbl) {
                KWidgetRef lbl = get_lbl(widget);
                if (lbl) kgtk_widget_modify_fg_gray(lbl, state, gray_level);
            }
        } else if (is_gtk_button(widget)) {
            fn_gtk_bin_get_child get_child = (fn_gtk_bin_get_child)resolve_sym("gtk_bin_get_child");
            if (get_child) {
                KWidgetRef child = get_child(widget);
                if (child) kgtk_widget_modify_fg_gray(child, state, gray_level);
            }
        }
    }
#endif
}

void kgtk_widget_modify_font_string(KWidgetRef widget, const char* font_desc_str) {
#if !defined(_WIN32)
    fn_gtk_widget_modify_font modify_fn = (fn_gtk_widget_modify_font)resolve_sym("gtk_widget_modify_font");
    fn_pango_font_description_from_string from_str = (fn_pango_font_description_from_string)resolve_sym("pango_font_description_from_string");
    fn_pango_font_description_get_size get_sz = (fn_pango_font_description_get_size)resolve_sym("pango_font_description_get_size");
    fn_pango_font_description_set_absolute_size set_abs = (fn_pango_font_description_set_absolute_size)resolve_sym("pango_font_description_set_absolute_size");
    fn_pango_font_description_free free_fn = (fn_pango_font_description_free)resolve_sym("pango_font_description_free");
    if (modify_fn && from_str && widget && font_desc_str) {
        void* desc = from_str(font_desc_str);
        if (desc) {
            if (get_sz && set_abs) {
                int pango_pts = get_sz(desc);
                if (pango_pts > 0) {
                    // Convert logical points to exact scaled physical pixels (2.75 px/pt on 1860x2480 reference)
                    double abs_pango = (double)pango_pts * 2.75 * kgtk_get_ui_scale();
                    if (abs_pango < 9.0 * 1024.0) abs_pango = 9.0 * 1024.0;
                    set_abs(desc, abs_pango);
                }
            }
            modify_fn(widget, desc);
            if (free_fn) free_fn(desc);
        }
        if (is_gtk_frame(widget)) {
            fn_gtk_frame_get_label_widget get_lbl = (fn_gtk_frame_get_label_widget)resolve_sym("gtk_frame_get_label_widget");
            if (get_lbl) {
                KWidgetRef lbl = get_lbl(widget);
                if (lbl) kgtk_widget_modify_font_string(lbl, font_desc_str);
            }
        } else if (is_gtk_button(widget)) {
            fn_gtk_bin_get_child get_child = (fn_gtk_bin_get_child)resolve_sym("gtk_bin_get_child");
            if (get_child) {
                KWidgetRef child = get_child(widget);
                if (child) kgtk_widget_modify_font_string(child, font_desc_str);
            }
        }
    }
#endif
}

unsigned long kgtk_signal_connect(KWidgetRef instance, const char* detailed_signal, KSignalCallback callback, void* user_data) {
#if !defined(_WIN32)
    fn_g_signal_connect_data fn = (fn_g_signal_connect_data)resolve_sym("g_signal_connect_data");
    if (fn && instance && detailed_signal && callback) {
        return fn(instance, detailed_signal, (void*)callback, user_data, NULL, 0);
    }
#endif
    return 0;
}

// --- Cairo-Rendered Modern E-Ink Components ---

#if !defined(_WIN32)
static void kcairo_rounded_rect(void* cr, double x, double y, double w, double h, double r) {
    fn_cairo_new_path new_path = (fn_cairo_new_path)resolve_sym("cairo_new_path");
    fn_cairo_close_path close_path = (fn_cairo_close_path)resolve_sym("cairo_close_path");
    fn_cairo_arc arc = (fn_cairo_arc)resolve_sym("cairo_arc");
    fn_cairo_rectangle rect = (fn_cairo_rectangle)resolve_sym("cairo_rectangle");
    if (!new_path || !rect || w <= 0 || h <= 0) return;

    double max_r = (w < h ? w : h) * 0.5;
    if (r > max_r) r = max_r;
    if (r <= 0.5 || !arc || !close_path) {
        new_path(cr);
        rect(cr, x, y, w, h);
        return;
    }
    const double pi = 3.14159265358979323846;
    new_path(cr);
    arc(cr, x + w - r, y + r,     r, -0.5 * pi, 0.0);
    arc(cr, x + w - r, y + h - r, r, 0.0,       0.5 * pi);
    arc(cr, x + r,     y + h - r, r, 0.5 * pi,  pi);
    arc(cr, x + r,     y + r,     r, pi,        1.5 * pi);
    close_path(cr);
}

static void kcairo_set_gray(void* cr, uint8_t gray) {
    fn_cairo_set_source_rgb set_rgb = (fn_cairo_set_source_rgb)resolve_sym("cairo_set_source_rgb");
    if (set_rgb) {
        uint8_t q = kgtk_quantize_eink_gray(gray);
        double g = (double)q / 255.0;
        set_rgb(cr, g, g, g);
    }
}

static void kcairo_clip_to_expose(void* cr, void* event) {
    if (!cr || !event) return;
    fn_cairo_new_path new_path = (fn_cairo_new_path)resolve_sym("cairo_new_path");
    fn_cairo_rectangle rect = (fn_cairo_rectangle)resolve_sym("cairo_rectangle");
    fn_cairo_clip clip = (fn_cairo_clip)resolve_sym("cairo_clip");
    if (new_path && rect && clip) {
        KGdkEventExpose* ev = (KGdkEventExpose*)event;
        if (ev->area.width > 0 && ev->area.height > 0) {
            new_path(cr);
            rect(cr, (double)ev->area.x, (double)ev->area.y, (double)ev->area.width, (double)ev->area.height);
            clip(cr);
        }
    }
}

static void kcairo_uneven_rounded_rect(void* cr, double x, double y, double w, double h, double tl, double tr, double br, double bl) {
    fn_cairo_new_path new_path = (fn_cairo_new_path)resolve_sym("cairo_new_path");
    fn_cairo_close_path close_path = (fn_cairo_close_path)resolve_sym("cairo_close_path");
    fn_cairo_arc arc = (fn_cairo_arc)resolve_sym("cairo_arc");
    fn_cairo_move_to move_to = (fn_cairo_move_to)resolve_sym("cairo_move_to");
    fn_cairo_line_to line_to = (fn_cairo_line_to)resolve_sym("cairo_line_to");
    fn_cairo_rectangle rect = (fn_cairo_rectangle)resolve_sym("cairo_rectangle");
    if (!new_path || !rect || w <= 0 || h <= 0) return;

    double max_r = (w < h ? w : h) * 0.5;
    if (tl < 0) tl = 0; if (tl > max_r) tl = max_r;
    if (tr < 0) tr = 0; if (tr > max_r) tr = max_r;
    if (br < 0) br = 0; if (br > max_r) br = max_r;
    if (bl < 0) bl = 0; if (bl > max_r) bl = max_r;

    if ((tl <= 0.5 && tr <= 0.5 && br <= 0.5 && bl <= 0.5) || !arc || !close_path || !move_to || !line_to) {
        new_path(cr);
        rect(cr, x, y, w, h);
        return;
    }

    const double pi = 3.14159265358979323846;
    new_path(cr);
    move_to(cr, x + tl, y);
    if (tr > 0.5) {
        arc(cr, x + w - tr, y + tr, tr, -0.5 * pi, 0.0);
    } else {
        line_to(cr, x + w, y);
    }
    if (br > 0.5) {
        arc(cr, x + w - br, y + h - br, br, 0.0, 0.5 * pi);
    } else {
        line_to(cr, x + w, y + h);
    }
    if (bl > 0.5) {
        arc(cr, x + bl, y + h - bl, bl, 0.5 * pi, pi);
    } else {
        line_to(cr, x, y + h);
    }
    if (tl > 0.5) {
        arc(cr, x + tl, y + tl, tl, pi, 1.5 * pi);
    } else {
        line_to(cr, x, y);
    }
    close_path(cr);
}

static void kcairo_ellipse(void* cr, double x, double y, double w, double h) {
    fn_cairo_save save = (fn_cairo_save)resolve_sym("cairo_save");
    fn_cairo_restore restore = (fn_cairo_restore)resolve_sym("cairo_restore");
    fn_cairo_translate translate = (fn_cairo_translate)resolve_sym("cairo_translate");
    fn_cairo_scale scale = (fn_cairo_scale)resolve_sym("cairo_scale");
    fn_cairo_new_path new_path = (fn_cairo_new_path)resolve_sym("cairo_new_path");
    fn_cairo_close_path close_path = (fn_cairo_close_path)resolve_sym("cairo_close_path");
    fn_cairo_arc arc = (fn_cairo_arc)resolve_sym("cairo_arc");
    if (!save || !restore || !translate || !scale || !new_path || !arc || w <= 1.0 || h <= 1.0) {
        kcairo_rounded_rect(cr, x, y, w, h, (w < h ? w : h) * 0.5);
        return;
    }
    const double pi = 3.14159265358979323846;
    new_path(cr);
    save(cr);
    translate(cr, x + w * 0.5, y + h * 0.5);
    scale(cr, w * 0.5, h * 0.5);
    arc(cr, 0.0, 0.0, 1.0, 0.0, 2.0 * pi);
    if (close_path) close_path(cr);
    restore(cr);
}

typedef struct {
    bool has_bg;
    uint8_t bg_gray;
    int border_width;
    uint8_t border_gray;
    int corner_radius;
    bool has_uneven_corners;
    int corner_tl;
    int corner_tr;
    int corner_br;
    int corner_bl;
    bool is_ellipse;
    int shadow_x;
    int shadow_y;
    uint8_t shadow_gray;
    bool is_interactive;
    bool is_enabled;
    bool is_pressed;
    bool dragged_scroll;
    double press_root_y;
    double start_scroll_val;
    KSignalCallback on_click;
    void* user_data;
} KStyledBoxState;

static void kcairo_box_path(void* cr, const KStyledBoxState* st, double x, double y, double w, double h, double inset) {
    if (!st) return;
    if (st->is_ellipse) {
        kcairo_ellipse(cr, x, y, w, h);
    } else if (st->has_uneven_corners) {
        double tl = (double)st->corner_tl - inset;
        double tr = (double)st->corner_tr - inset;
        double br = (double)st->corner_br - inset;
        double bl = (double)st->corner_bl - inset;
        kcairo_uneven_rounded_rect(cr, x, y, w, h, tl, tr, br, bl);
    } else {
        double r = (double)st->corner_radius - inset;
        if (r < 0.0) r = 0.0;
        kcairo_rounded_rect(cr, x, y, w, h, r);
    }
}

static int c_styled_box_expose(KWidgetRef widget, void* event, void* data) {
    KStyledBoxState* st = (KStyledBoxState*)data;
    if (!st || !widget) return 0;

    fn_gtk_widget_get_window get_win = (fn_gtk_widget_get_window)resolve_sym("gtk_widget_get_window");
    fn_gdk_cairo_create cairo_create = (fn_gdk_cairo_create)resolve_sym("gdk_cairo_create");
    fn_cairo_destroy cairo_destroy = (fn_cairo_destroy)resolve_sym("cairo_destroy");
    fn_cairo_fill fill = (fn_cairo_fill)resolve_sym("cairo_fill");
    fn_cairo_stroke stroke = (fn_cairo_stroke)resolve_sym("cairo_stroke");
    fn_cairo_set_line_width set_lw = (fn_cairo_set_line_width)resolve_sym("cairo_set_line_width");
    if (!get_win || !cairo_create || !cairo_destroy || !fill || !stroke || !set_lw) return 0;

    void* gdk_win = get_win(widget);
    if (!gdk_win) return 0;

    KGtkAllocation alloc = { 0, 0, 0, 0 };
    kgtk_widget_get_size(widget, &alloc.width, &alloc.height);
    fn_gtk_widget_get_allocation get_alloc = (fn_gtk_widget_get_allocation)resolve_sym("gtk_widget_get_allocation");
    if (get_alloc) {
        get_alloc(widget, &alloc);
    }
    if (alloc.width <= 1 || alloc.height <= 1) return 0;

    void* cr = cairo_create(gdk_win);
    if (!cr) return 0;
    kcairo_clip_to_expose(cr, event);

    int abs_sx = st->shadow_x < 0 ? -st->shadow_x : st->shadow_x;
    int abs_sy = st->shadow_y < 0 ? -st->shadow_y : st->shadow_y;
    double box_w = (double)(alloc.width - abs_sx);
    double box_h = (double)(alloc.height - abs_sy);
    double box_x = (double)alloc.x + (st->shadow_x < 0 ? abs_sx : 0);
    double box_y = (double)alloc.y + (st->shadow_y < 0 ? abs_sy : 0);

    if ((abs_sx > 0 || abs_sy > 0) && box_w > 2 && box_h > 2) {
        double sx = box_x + st->shadow_x;
        double sy = box_y + st->shadow_y;
        kcairo_box_path(cr, st, sx, sy, box_w, box_h, 0.0);
        kcairo_set_gray(cr, st->shadow_gray);
        fill(cr);
    }

    if (st->is_interactive && st->is_pressed && (abs_sx > 0 || abs_sy > 0)) {
        // Tactile shift toward the shadow when pressed
        box_x += (st->shadow_x > 0 ? 1.5 : 0.0);
        box_y += (st->shadow_y > 0 ? 1.5 : 0.0);
    }

    if (st->has_bg || (st->is_interactive && st->is_pressed)) {
        uint8_t effective_bg = st->has_bg ? st->bg_gray : 0xEE;
        if (st->is_interactive && st->is_pressed) {
            if (effective_bg > 128) {
                effective_bg = (effective_bg > 48) ? (uint8_t)(effective_bg - 48) : 0x99;
            } else {
                effective_bg = (uint8_t)(effective_bg + 56);
            }
        }
        kcairo_box_path(cr, st, box_x, box_y, box_w, box_h, 0.0);
        kcairo_set_gray(cr, effective_bg);
        fill(cr);
    }

    if (st->border_width > 0) {
        double bw = (double)st->border_width + (st->is_interactive && st->is_pressed ? 1.0 : 0.0);
        double half = bw * 0.5;
        kcairo_box_path(cr, st, box_x + half, box_y + half, box_w - bw, box_h - bw, half);
        set_lw(cr, bw);
        kcairo_set_gray(cr, st->border_gray);
        stroke(cr);
    }

    cairo_destroy(cr);
    return 0; // Let GtkContainer propagate expose to children on top
}

static KWidgetRef c_current_draggable_scroll_window(void) {
    return g_active_modal_scrolled_window ? g_active_modal_scrolled_window : g_active_scrolled_window;
}

static int c_styled_button_press(KWidgetRef widget, void* event, void* data) {
    KStyledBoxState* st = (KStyledBoxState*)data;
    if (!st || !st->is_interactive) return 1;
    if (!c_event_is_button1_press(event)) return 1;
    st->dragged_scroll = false;
    st->press_root_y = 0.0;
    st->start_scroll_val = 0.0;
    c_scroll_drag_begin(widget, NULL, event, true);
    if (!st->is_enabled) {
        st->is_pressed = false;
        return 1;
    }
    st->is_pressed = true;
    kgtk_widget_queue_draw(widget);
    return 1;
}

static int c_styled_button_motion(KWidgetRef widget, void* event, void* data) {
    KStyledBoxState* st = (KStyledBoxState*)data;
    if (!st || !st->is_interactive || !event) return 0;
    if (!c_event_has_button1_mask(event)) {
        st->dragged_scroll = false;
        if (st->is_pressed) {
            st->is_pressed = false;
            kgtk_widget_queue_draw(widget);
        }
        c_scroll_drag_end();
        return 0;
    }
    if (c_scroll_drag_update(event)) {
        st->dragged_scroll = true;
        if (st->is_pressed) {
            st->is_pressed = false;
            kgtk_widget_queue_draw(widget);
        }
        return 1;
    }
    return (st->is_pressed || st->dragged_scroll || g_scroll_drag.active) ? 1 : 0;
}

static KWidgetRef g_suppressed_redraw_widget = NULL;

KWidgetRef kgtk_take_suppressed_redraw_widget(void) {
    KWidgetRef w = g_suppressed_redraw_widget;
    g_suppressed_redraw_widget = NULL;
    return w;
}

static int c_styled_button_release(KWidgetRef widget, void* event, void* data) {
    if (!c_event_is_button1_release(event)) return 1;
    KStyledBoxState* st = (KStyledBoxState*)data;
    bool did_scroll = c_scroll_drag_end();
    if (!st || !st->is_interactive) return 1;
    bool was_pressed = st->is_pressed;
    bool was_dragged = st->dragged_scroll || did_scroll;
    st->is_pressed = false;
    st->dragged_scroll = false;
    if (was_pressed && !was_dragged && st->is_enabled && st->on_click) {
        st->on_click(widget, st->user_data);
        if (!g_has_pending_idle) {
            kgtk_widget_queue_draw(widget);
        } else {
            /* A rebuild is pending and would normally repaint this button. If the renderer applies that
             * rebuild in place instead, the widget survives and must be redrawn (un-pressed) by the
             * renderer: remember it. */
            g_suppressed_redraw_widget = widget;
        }
    } else if (was_pressed) {
        kgtk_widget_queue_draw(widget);
    }
    return 1;
}

static KWidgetRef create_styled_box_internal(
    KWidgetRef child,
    bool has_bg,
    uint8_t bg_gray,
    int border_width,
    uint8_t border_gray,
    int corner_radius,
    int shadow_x,
    int shadow_y,
    uint8_t shadow_gray,
    int pad_top,
    int pad_bottom,
    int pad_left,
    int pad_right,
    float xalign,
    float yalign,
    float xscale,
    float yscale,
    bool is_interactive,
    bool is_enabled,
    KSignalCallback on_click,
    void* user_data
) {
    fn_gtk_event_box_set_visible_window set_vis = (fn_gtk_event_box_set_visible_window)resolve_sym("gtk_event_box_set_visible_window");
    fn_gtk_event_box_set_above_child set_above = (fn_gtk_event_box_set_above_child)resolve_sym("gtk_event_box_set_above_child");
    fn_gtk_widget_add_events add_events = (fn_gtk_widget_add_events)resolve_sym("gtk_widget_add_events");
    fn_g_signal_connect_data conn = (fn_g_signal_connect_data)resolve_sym("g_signal_connect_data");
    fn_g_object_set_data_full set_data = (fn_g_object_set_data_full)resolve_sym("g_object_set_data_full");

    int abs_sx = shadow_x < 0 ? -shadow_x : shadow_x;
    int abs_sy = shadow_y < 0 ? -shadow_y : shadow_y;
    int bw = border_width > 0 ? border_width : 0;
    int eff_top    = pad_top    + bw + (shadow_y < 0 ? abs_sy : 0);
    int eff_bottom = pad_bottom + bw + (shadow_y > 0 ? abs_sy : 0);
    int eff_left   = pad_left   + bw + (shadow_x < 0 ? abs_sx : 0);
    int eff_right  = pad_right  + bw + (shadow_x > 0 ? abs_sx : 0);

    KWidgetRef align = kgtk_alignment_new(xalign, yalign, xscale, yscale);
    if (!align) return child;
    kgtk_alignment_set_padding(align, eff_top, eff_bottom, eff_left, eff_right);
    if (child) kgtk_container_add(align, child);

    KWidgetRef host = align;
    if (is_interactive) {
        KWidgetRef eb = kgtk_event_box_new();
        if (eb) {
            if (set_vis) set_vis(eb, 0);
            if (set_above) set_above(eb, 1);
            if (add_events) add_events(eb, 4 | 256 | 512); // GDK_POINTER_MOTION_MASK | GDK_BUTTON_PRESS_MASK | GDK_BUTTON_RELEASE_MASK
            kgtk_container_add(eb, align);
            host = eb;
        }
    }

    KStyledBoxState* st = (KStyledBoxState*)malloc(sizeof(KStyledBoxState));
    if (st && conn) {
        st->has_bg = has_bg;
        st->bg_gray = bg_gray;
        st->border_width = bw > 0 ? kgtk_scale_px(bw) : 0;
        st->border_gray = border_gray;
        st->corner_radius = corner_radius > 0 ? kgtk_scale_px(corner_radius) : 0;
        st->has_uneven_corners = false;
        st->corner_tl = 0;
        st->corner_tr = 0;
        st->corner_br = 0;
        st->corner_bl = 0;
        st->is_ellipse = false;
        st->shadow_x = kgtk_scale_signed_px(shadow_x);
        st->shadow_y = kgtk_scale_signed_px(shadow_y);
        st->shadow_gray = shadow_gray;
        st->is_interactive = is_interactive;
        st->is_enabled = is_enabled;
        st->is_pressed = false;
        st->dragged_scroll = false;
        st->press_root_y = 0.0;
        st->start_scroll_val = 0.0;
        st->on_click = on_click;
        st->user_data = user_data;
        if (set_data) {
            set_data(host, "kindle-styled-box-state", st, free);
        }
        conn(host, "expose-event", (void*)c_styled_box_expose, st, NULL, 0);
        if (is_interactive) {
            conn(host, "button-press-event", (void*)c_styled_button_press, st, NULL, 0);
            conn(host, "motion-notify-event", (void*)c_styled_button_motion, st, NULL, 0);
            conn(host, "button-release-event", (void*)c_styled_button_release, st, NULL, 0);
        }
    } else if (st) {
        free(st);
    }

    return host;
}
#endif

KWidgetRef kgtk_styled_container_new(
    KWidgetRef child,
    bool has_bg,
    uint8_t bg_gray,
    int border_width,
    uint8_t border_gray,
    int corner_radius,
    int shadow_x,
    int shadow_y,
    uint8_t shadow_gray,
    int pad_top,
    int pad_bottom,
    int pad_left,
    int pad_right,
    float xalign,
    float yalign,
    float xscale,
    float yscale
) {
#if !defined(_WIN32)
    return create_styled_box_internal(
        child, has_bg, bg_gray, border_width, border_gray, corner_radius,
        shadow_x, shadow_y, shadow_gray, pad_top, pad_bottom, pad_left, pad_right,
        xalign, yalign, xscale, yscale, false, false, NULL, NULL
    );
#else
    return child;
#endif
}

void kgtk_styled_box_set_shape(
    KWidgetRef widget,
    int tl,
    int tr,
    int br,
    int bl,
    bool is_ellipse
) {
#if !defined(_WIN32)
    if (!widget) return;
    fn_g_object_get_data get_data = (fn_g_object_get_data)resolve_sym("g_object_get_data");
    if (!get_data) return;
    KStyledBoxState* st = (KStyledBoxState*)get_data(widget, "kindle-styled-box-state");
    if (!st) return;
    st->is_ellipse = is_ellipse;
    if (!is_ellipse) {
        st->has_uneven_corners = true;
        st->corner_tl = tl > 0 ? kgtk_scale_px(tl) : 0;
        st->corner_tr = tr > 0 ? kgtk_scale_px(tr) : 0;
        st->corner_br = br > 0 ? kgtk_scale_px(br) : 0;
        st->corner_bl = bl > 0 ? kgtk_scale_px(bl) : 0;
    }
#else
    (void)widget; (void)tl; (void)tr; (void)br; (void)bl; (void)is_ellipse;
#endif
}

KWidgetRef kgtk_styled_button_new(
    KWidgetRef child,
    bool has_bg,
    uint8_t bg_gray,
    int border_width,
    uint8_t border_gray,
    int corner_radius,
    int shadow_x,
    int shadow_y,
    uint8_t shadow_gray,
    int pad_top,
    int pad_bottom,
    int pad_left,
    int pad_right,
    float xalign,
    float yalign,
    float xscale,
    float yscale,
    bool is_enabled,
    KSignalCallback on_click,
    void* user_data
) {
#if !defined(_WIN32)
    return create_styled_box_internal(
        child, has_bg, bg_gray, border_width, border_gray, corner_radius,
        shadow_x, shadow_y, shadow_gray, pad_top, pad_bottom, pad_left, pad_right,
        xalign, yalign, xscale, yscale, true, is_enabled, on_click, user_data
    );
#else
    return child;
#endif
}

// --- Custom Cairo Switch / Checkbox ---

#if !defined(_WIN32)
typedef struct {
    bool is_on;
    int style_mode; // 0 = switch, 1 = checkbox
    uint8_t fg_gray;
    uint8_t bg_gray;
    uint8_t track_gray;
} KCustomSwitchState;

static int c_custom_switch_expose(KWidgetRef widget, void* event, void* data) {
    KCustomSwitchState* st = (KCustomSwitchState*)data;
    if (!st || !widget) return 0;

    fn_gtk_widget_get_window get_win = (fn_gtk_widget_get_window)resolve_sym("gtk_widget_get_window");
    fn_gtk_widget_get_allocation get_alloc = (fn_gtk_widget_get_allocation)resolve_sym("gtk_widget_get_allocation");
    fn_gdk_cairo_create cairo_create = (fn_gdk_cairo_create)resolve_sym("gdk_cairo_create");
    fn_cairo_destroy cairo_destroy = (fn_cairo_destroy)resolve_sym("cairo_destroy");
    fn_cairo_fill fill = (fn_cairo_fill)resolve_sym("cairo_fill");
    fn_cairo_stroke stroke = (fn_cairo_stroke)resolve_sym("cairo_stroke");
    fn_cairo_set_line_width set_lw = (fn_cairo_set_line_width)resolve_sym("cairo_set_line_width");
    fn_cairo_set_line_cap set_cap = (fn_cairo_set_line_cap)resolve_sym("cairo_set_line_cap");
    fn_cairo_set_line_join set_join = (fn_cairo_set_line_join)resolve_sym("cairo_set_line_join");
    fn_cairo_new_path new_path = (fn_cairo_new_path)resolve_sym("cairo_new_path");
    fn_cairo_arc arc = (fn_cairo_arc)resolve_sym("cairo_arc");
    fn_cairo_move_to move_to = (fn_cairo_move_to)resolve_sym("cairo_move_to");
    fn_cairo_line_to line_to = (fn_cairo_line_to)resolve_sym("cairo_line_to");

    if (!get_win || !get_alloc || !cairo_create || !cairo_destroy || !fill || !stroke || !set_lw) return 0;
    void* gdk_win = get_win(widget);
    if (!gdk_win) return 0;

    KGtkAllocation alloc = { 0, 0, 0, 0 };
    get_alloc(widget, &alloc);
    if (alloc.width <= 4 || alloc.height <= 4) return 0;

    void* cr = cairo_create(gdk_win);
    if (!cr) return 0;
    kcairo_clip_to_expose(cr, event);

    const double pi = 3.14159265358979323846;
    double s = kgtk_get_ui_scale();
    double ox = (double)alloc.x;
    double oy = (double)alloc.y;
    double w = (double)alloc.width;
    double h = (double)alloc.height;
    double inset = 6.0 * s;
    if (inset < 2.0) inset = 2.0;
    double lw = 3.0 * s;
    if (lw < 1.5) lw = 1.5;

    if (st->style_mode == 1) {
        // Crisp rounded checkbox
        double sz = (w < h ? w : h) - inset;
        double x = ox + (w - sz) * 0.5;
        double y = oy + (h - sz) * 0.5;
        double rad = 12.0 * s;
        if (rad < 4.0) rad = 4.0;
        kcairo_rounded_rect(cr, x, y, sz, sz, rad);
        kcairo_set_gray(cr, st->is_on ? st->fg_gray : st->bg_gray);
        fill(cr);

        kcairo_rounded_rect(cr, x, y, sz, sz, rad);
        set_lw(cr, lw);
        kcairo_set_gray(cr, st->fg_gray);
        stroke(cr);

        if (st->is_on && new_path && move_to && line_to) {
            if (set_cap) set_cap(cr, 1);   // CAIRO_LINE_CAP_ROUND
            if (set_join) set_join(cr, 1); // CAIRO_LINE_JOIN_ROUND
            new_path(cr);
            move_to(cr, x + sz * 0.24, y + sz * 0.52);
            line_to(cr, x + sz * 0.44, y + sz * 0.72);
            line_to(cr, x + sz * 0.78, y + sz * 0.30);
            double clw = 4.5 * s;
            if (clw < 2.0) clw = 2.0;
            set_lw(cr, clw);
            kcairo_set_gray(cr, st->bg_gray);
            stroke(cr);
        }
    } else {
        // Capsule switch
        double sw = w - inset;
        double sh = h - inset;
        double sx = ox + inset * 0.5;
        double sy = oy + inset * 0.5;
        double r = sh * 0.5;

        kcairo_rounded_rect(cr, sx, sy, sw, sh, r);
        kcairo_set_gray(cr, st->is_on ? st->fg_gray : st->track_gray);
        fill(cr);

        kcairo_rounded_rect(cr, sx, sy, sw, sh, r);
        set_lw(cr, lw);
        kcairo_set_gray(cr, st->fg_gray);
        stroke(cr);

        if (new_path && arc) {
            double thumb_pad = 7.0 * s;
            if (thumb_pad < 2.5) thumb_pad = 2.5;
            double thumb_r = r - thumb_pad;
            if (thumb_r < 3.0) thumb_r = 3.0;
            double cx = st->is_on ? (sx + sw - r) : (sx + r);
            double cy = sy + r;
            new_path(cr);
            arc(cr, cx, cy, thumb_r, 0.0, 2.0 * pi);
            kcairo_set_gray(cr, st->is_on ? st->bg_gray : st->fg_gray);
            fill(cr);
        }
    }

    cairo_destroy(cr);
    return 0;
}
#endif

KWidgetRef kgtk_custom_switch_new(
    bool is_on,
    int style_mode,
    uint8_t fg_gray,
    uint8_t bg_gray,
    uint8_t track_gray
) {
#if !defined(_WIN32)
    KWidgetRef eb = kgtk_alignment_new(0.5, 0.5, 0.0, 0.0);
    fn_g_signal_connect_data conn = (fn_g_signal_connect_data)resolve_sym("g_signal_connect_data");
    fn_g_object_set_data_full set_data = (fn_g_object_set_data_full)resolve_sym("g_object_set_data_full");
    if (!eb || !conn) return eb;

    if (style_mode == 1) {
        kgtk_widget_set_size_request(eb, 52, 52);
    } else {
        kgtk_widget_set_size_request(eb, 104, 56);
    }

    KCustomSwitchState* st = (KCustomSwitchState*)malloc(sizeof(KCustomSwitchState));
    if (st) {
        st->is_on = is_on;
        st->style_mode = style_mode;
        st->fg_gray = fg_gray;
        st->bg_gray = bg_gray;
        st->track_gray = track_gray;
        if (set_data) {
            set_data(eb, "kindle-custom-switch-state", st, free);
        }
        conn(eb, "expose-event", (void*)c_custom_switch_expose, st, NULL, 0);
    }
    return eb;
#else
    return NULL;
#endif
}

// --- Custom Cairo E-Ink Slider ---

#if !defined(_WIN32)
typedef struct {
    double value;
    double min_val;
    double max_val;
    double step;
    uint8_t fg_gray;
    uint8_t bg_gray;
    uint8_t track_gray;
    KSignalCallback on_value_changed;
    void* value_user_data;
    KIdleCallback on_drag_end;
    void* drag_user_data;
} KCustomSliderState;

static void update_slider_from_x(KWidgetRef widget, KCustomSliderState* st, double x) {
    static bool s_in_slider_update = false;
    if (s_in_slider_update) return;

    int w = 0, h = 0;
    kgtk_widget_get_size(widget, &w, &h);
    double pad = 28.0 * kgtk_get_ui_scale();
    double usable = (double)w - 2.0 * pad;
    if (usable <= 1.0) return;

    double frac = (x - pad) / usable;
    if (frac < 0.0) frac = 0.0;
    if (frac > 1.0) frac = 1.0;

    double span = st->max_val - st->min_val;
    double raw = st->min_val + frac * span;
    if (st->step > 0.00001) {
        double steps = (raw - st->min_val) / st->step;
        long rounded = (long)(steps + 0.5);
        raw = st->min_val + (double)rounded * st->step;
    }
    if (raw < st->min_val) raw = st->min_val;
    if (raw > st->max_val) raw = st->max_val;

    double diff = raw - st->value;
    if (diff < 0.0) diff = -diff;
    if (diff > 0.00001) {
        s_in_slider_update = true;
        st->value = raw;
        kgtk_widget_queue_draw(widget);
        if (st->on_value_changed) {
            st->on_value_changed(widget, st->value_user_data);
        }
        s_in_slider_update = false;
    }
}

static int c_custom_slider_expose(KWidgetRef widget, void* event, void* data) {
    KCustomSliderState* st = (KCustomSliderState*)data;
    if (!st || !widget) return 0;

    fn_gtk_widget_get_window get_win = (fn_gtk_widget_get_window)resolve_sym("gtk_widget_get_window");
    fn_gtk_widget_get_allocation get_alloc = (fn_gtk_widget_get_allocation)resolve_sym("gtk_widget_get_allocation");
    fn_gdk_cairo_create cairo_create = (fn_gdk_cairo_create)resolve_sym("gdk_cairo_create");
    fn_cairo_destroy cairo_destroy = (fn_cairo_destroy)resolve_sym("cairo_destroy");
    fn_cairo_fill fill = (fn_cairo_fill)resolve_sym("cairo_fill");
    fn_cairo_stroke stroke = (fn_cairo_stroke)resolve_sym("cairo_stroke");
    fn_cairo_set_line_width set_lw = (fn_cairo_set_line_width)resolve_sym("cairo_set_line_width");
    fn_cairo_new_path new_path = (fn_cairo_new_path)resolve_sym("cairo_new_path");
    fn_cairo_arc arc = (fn_cairo_arc)resolve_sym("cairo_arc");

    if (!get_win || !get_alloc || !cairo_create || !cairo_destroy || !fill || !stroke || !set_lw) return 0;
    void* gdk_win = get_win(widget);
    if (!gdk_win) return 0;

    KGtkAllocation alloc = { 0, 0, 0, 0 };
    get_alloc(widget, &alloc);
    if (alloc.width <= 8 || alloc.height <= 8) return 0;

    void* cr = cairo_create(gdk_win);
    if (!cr) return 0;
    kcairo_clip_to_expose(cr, event);

    double s = kgtk_get_ui_scale();
    double ox = (double)alloc.x;
    double oy = (double)alloc.y;
    double w = (double)alloc.width;
    double h = (double)alloc.height;

    double pad = 28.0 * s;
    double track_w = w - 2.0 * pad;
    if (track_w < 10.0) track_w = 10.0;
    double track_h = 16.0 * s;
    if (track_h < 6.0) track_h = 6.0;
    double cy = oy + h * 0.5;
    double track_x = ox + pad;
    double track_y = cy - track_h * 0.5;

    double span = st->max_val - st->min_val;
    double frac = (span > 0.00001) ? ((st->value - st->min_val) / span) : 0.0;
    if (frac < 0.0) frac = 0.0;
    if (frac > 1.0) frac = 1.0;

    // Inactive track pill
    kcairo_rounded_rect(cr, track_x, track_y, track_w, track_h, track_h * 0.5);
    kcairo_set_gray(cr, st->track_gray);
    fill(cr);

    double trk_lw = 1.6 * s;
    if (trk_lw < 1.0) trk_lw = 1.0;
    kcairo_rounded_rect(cr, track_x, track_y, track_w, track_h, track_h * 0.5);
    set_lw(cr, trk_lw);
    kcairo_set_gray(cr, st->fg_gray);
    stroke(cr);

    // Active filled portion
    double fill_w = frac * track_w;
    if (fill_w > 4.0 * s) {
        kcairo_rounded_rect(cr, track_x, track_y, fill_w, track_h, track_h * 0.5);
        kcairo_set_gray(cr, st->fg_gray);
        fill(cr);
    }

    const double pi = 3.14159265358979323846;

    // Step tick marks if discrete steps <= 24
    if (st->step > 0.00001 && span > 0.00001 && new_path && arc) {
        int num_steps = (int)((span / st->step) + 0.5);
        if (num_steps >= 2 && num_steps <= 24) {
            double tick_r = 2.5 * s;
            if (tick_r < 1.2) tick_r = 1.2;
            for (int i = 1; i < num_steps; ++i) {
                double t_frac = (double)i / (double)num_steps;
                double tx = track_x + t_frac * track_w;
                new_path(cr);
                arc(cr, tx, cy, tick_r, 0.0, 2.0 * pi);
                kcairo_set_gray(cr, (t_frac <= frac) ? st->bg_gray : st->fg_gray);
                fill(cr);
            }
        }
    }

    // Circular E-Ink thumb with bullseye
    if (new_path && arc) {
        double thumb_x = track_x + frac * track_w;
        double thumb_r = 22.0 * s;
        if (thumb_r < 7.0) thumb_r = 7.0;
        if (thumb_r > h * 0.5 - 2.0) thumb_r = h * 0.5 - 2.0;

        new_path(cr);
        arc(cr, thumb_x, cy, thumb_r, 0.0, 2.0 * pi);
        kcairo_set_gray(cr, st->bg_gray);
        fill(cr);

        double th_lw = 3.5 * s;
        if (th_lw < 1.5) th_lw = 1.5;
        new_path(cr);
        arc(cr, thumb_x, cy, thumb_r, 0.0, 2.0 * pi);
        set_lw(cr, th_lw);
        kcairo_set_gray(cr, st->fg_gray);
        stroke(cr);

        double dot_r = 7.0 * s;
        if (dot_r < 2.2) dot_r = 2.2;
        new_path(cr);
        arc(cr, thumb_x, cy, dot_r, 0.0, 2.0 * pi);
        kcairo_set_gray(cr, st->fg_gray);
        fill(cr);
    }

    cairo_destroy(cr);
    return 0;
}

static int c_custom_slider_press(KWidgetRef widget, void* event, void* data) {
    KCustomSliderState* st = (KCustomSliderState*)data;
    if (!st || !event) return 1;
    if (!c_event_is_button1_press(event)) return 1;
    g_slider_dragging = true;
    fn_gdk_event_get_coords get_coords = (fn_gdk_event_get_coords)resolve_sym("gdk_event_get_coords");
    double x = 0, y = 0;
    if (get_coords && get_coords(event, &x, &y)) {
        update_slider_from_x(widget, st, x);
    }
    return 1;
}

static int c_custom_slider_motion(KWidgetRef widget, void* event, void* data) {
    KCustomSliderState* st = (KCustomSliderState*)data;
    if (!st || !event || !g_slider_dragging) return 1;
    fn_gdk_event_get_coords get_coords = (fn_gdk_event_get_coords)resolve_sym("gdk_event_get_coords");
    double x = 0, y = 0;
    if (get_coords && get_coords(event, &x, &y)) {
        update_slider_from_x(widget, st, x);
    }
    return 1;
}

static int c_custom_slider_release(KWidgetRef widget, void* event, void* data) {
    KCustomSliderState* st = (KCustomSliderState*)data;
    if (!st) return 1;
    if (!c_event_is_button1_release(event)) return 1;
    fn_gdk_event_get_coords get_coords = (fn_gdk_event_get_coords)resolve_sym("gdk_event_get_coords");
    double x = 0, y = 0;
    if (event && get_coords && get_coords(event, &x, &y)) {
        update_slider_from_x(widget, st, x);
    }
    g_slider_dragging = false;
    if (st->on_drag_end) {
        kgtk_schedule_idle(st->on_drag_end, st->drag_user_data);
    }
    return 1;
}
#endif

KWidgetRef kgtk_custom_slider_new(
    double value,
    double min_val,
    double max_val,
    double step,
    uint8_t fg_gray,
    uint8_t bg_gray,
    uint8_t track_gray,
    KSignalCallback on_value_changed,
    void* value_user_data,
    KIdleCallback on_drag_end,
    void* drag_user_data
) {
#if !defined(_WIN32)
    KWidgetRef eb = kgtk_event_box_new();
    fn_gtk_event_box_set_visible_window set_vis = (fn_gtk_event_box_set_visible_window)resolve_sym("gtk_event_box_set_visible_window");
    fn_gtk_event_box_set_above_child set_above = (fn_gtk_event_box_set_above_child)resolve_sym("gtk_event_box_set_above_child");
    fn_gtk_widget_add_events add_events = (fn_gtk_widget_add_events)resolve_sym("gtk_widget_add_events");
    fn_g_signal_connect_data conn = (fn_g_signal_connect_data)resolve_sym("g_signal_connect_data");
    fn_g_object_set_data_full set_data = (fn_g_object_set_data_full)resolve_sym("g_object_set_data_full");
    if (!eb || !conn) return eb;

    if (set_vis) set_vis(eb, 0);
    if (set_above) set_above(eb, 1);
    if (add_events) add_events(eb, 2 | 4 | 16 | 32 | 256 | 512);

    kgtk_widget_set_size_request(eb, -1, 64);

    KCustomSliderState* st = (KCustomSliderState*)malloc(sizeof(KCustomSliderState));
    if (st) {
        st->value = value;
        st->min_val = min_val;
        st->max_val = max_val;
        st->step = step;
        st->fg_gray = fg_gray;
        st->bg_gray = bg_gray;
        st->track_gray = track_gray;
        st->on_value_changed = on_value_changed;
        st->value_user_data = value_user_data;
        st->on_drag_end = on_drag_end;
        st->drag_user_data = drag_user_data;
        if (set_data) {
            set_data(eb, "kindle-custom-slider-state", st, free);
        }
        conn(eb, "expose-event", (void*)c_custom_slider_expose, st, NULL, 0);
        conn(eb, "button-press-event", (void*)c_custom_slider_press, st, NULL, 0);
        conn(eb, "motion-notify-event", (void*)c_custom_slider_motion, st, NULL, 0);
        conn(eb, "button-release-event", (void*)c_custom_slider_release, st, NULL, 0);
    }
    return eb;
#else
    return NULL;
#endif
}

double kgtk_custom_slider_get_value(KWidgetRef slider) {
#if !defined(_WIN32)
    typedef void* (*fn_g_object_get_data)(void*, const char*);
    fn_g_object_get_data get_data = (fn_g_object_get_data)resolve_sym("g_object_get_data");
    if (get_data && slider) {
        KCustomSliderState* st = (KCustomSliderState*)get_data(slider, "kindle-custom-slider-state");
        if (st) return st->value;
    }
#endif
    return kgtk_range_get_value(slider);
}

// --- Custom Cairo Progress Bar & Divider ---

#if !defined(_WIN32)
typedef struct {
    double fraction;
    uint8_t fg_gray;
    uint8_t bg_gray;
    uint8_t track_gray;
} KCustomProgressState;

static int c_custom_progress_expose(KWidgetRef widget, void* event, void* data) {
    KCustomProgressState* st = (KCustomProgressState*)data;
    if (!st || !widget) return 0;

    fn_gtk_widget_get_window get_win = (fn_gtk_widget_get_window)resolve_sym("gtk_widget_get_window");
    fn_gtk_widget_get_allocation get_alloc = (fn_gtk_widget_get_allocation)resolve_sym("gtk_widget_get_allocation");
    fn_gdk_cairo_create cairo_create = (fn_gdk_cairo_create)resolve_sym("gdk_cairo_create");
    fn_cairo_destroy cairo_destroy = (fn_cairo_destroy)resolve_sym("cairo_destroy");
    fn_cairo_fill fill = (fn_cairo_fill)resolve_sym("cairo_fill");
    fn_cairo_stroke stroke = (fn_cairo_stroke)resolve_sym("cairo_stroke");
    fn_cairo_set_line_width set_lw = (fn_cairo_set_line_width)resolve_sym("cairo_set_line_width");
    if (!get_win || !get_alloc || !cairo_create || !cairo_destroy || !fill || !stroke || !set_lw) return 0;

    void* gdk_win = get_win(widget);
    if (!gdk_win) return 0;

    KGtkAllocation alloc = { 0, 0, 0, 0 };
    get_alloc(widget, &alloc);
    if (alloc.width <= 4 || alloc.height <= 4) return 0;

    void* cr = cairo_create(gdk_win);
    if (!cr) return 0;
    kcairo_clip_to_expose(cr, event);

    double ox = (double)alloc.x + 1.5;
    double oy = (double)alloc.y + 1.5;
    double w = (double)alloc.width - 3.0;
    double h = (double)alloc.height - 3.0;
    double r = h * 0.5;

    kcairo_rounded_rect(cr, ox, oy, w, h, r);
    kcairo_set_gray(cr, st->track_gray);
    fill(cr);

    double fill_w = w * st->fraction;
    if (fill_w > 4.0) {
        kcairo_rounded_rect(cr, ox, oy, fill_w, h, r);
        kcairo_set_gray(cr, st->fg_gray);
        fill(cr);
    }

    double lw = 1.6 * kgtk_get_ui_scale();
    if (lw < 1.0) lw = 1.0;
    kcairo_rounded_rect(cr, ox, oy, w, h, r);
    set_lw(cr, lw);
    kcairo_set_gray(cr, st->fg_gray);
    stroke(cr);

    cairo_destroy(cr);
    return 0;
}

typedef struct {
    uint8_t gray_level;
} KCustomDividerState;

static int c_custom_divider_expose(KWidgetRef widget, void* event, void* data) {
    KCustomDividerState* st = (KCustomDividerState*)data;
    if (!st || !widget) return 0;

    fn_gtk_widget_get_window get_win = (fn_gtk_widget_get_window)resolve_sym("gtk_widget_get_window");
    fn_gtk_widget_get_allocation get_alloc = (fn_gtk_widget_get_allocation)resolve_sym("gtk_widget_get_allocation");
    fn_gdk_cairo_create cairo_create = (fn_gdk_cairo_create)resolve_sym("gdk_cairo_create");
    fn_cairo_destroy cairo_destroy = (fn_cairo_destroy)resolve_sym("cairo_destroy");
    fn_cairo_fill fill = (fn_cairo_fill)resolve_sym("cairo_fill");
    if (!get_win || !get_alloc || !cairo_create || !cairo_destroy || !fill) return 0;

    void* gdk_win = get_win(widget);
    if (!gdk_win) return 0;

    KGtkAllocation alloc = { 0, 0, 0, 0 };
    get_alloc(widget, &alloc);
    if (alloc.width <= 0 || alloc.height <= 0) return 0;

    void* cr = cairo_create(gdk_win);
    if (!cr) return 0;
    kcairo_clip_to_expose(cr, event);

    kcairo_rounded_rect(cr, (double)alloc.x, (double)alloc.y, (double)alloc.width, (double)alloc.height, 0);
    kcairo_set_gray(cr, st->gray_level);
    fill(cr);
    cairo_destroy(cr);
    return 0;
}
#endif

KWidgetRef kgtk_custom_progress_new(
    double fraction,
    uint8_t fg_gray,
    uint8_t bg_gray,
    uint8_t track_gray,
    int height
) {
#if !defined(_WIN32)
    KWidgetRef eb = kgtk_alignment_new(0.5, 0.5, 1.0, 1.0);
    fn_g_signal_connect_data conn = (fn_g_signal_connect_data)resolve_sym("g_signal_connect_data");
    fn_g_object_set_data_full set_data = (fn_g_object_set_data_full)resolve_sym("g_object_set_data_full");
    if (!eb || !conn) return eb;

    kgtk_widget_set_size_request(eb, -1, height > 8 ? height : 28);

    KCustomProgressState* st = (KCustomProgressState*)malloc(sizeof(KCustomProgressState));
    if (st) {
        st->fraction = fraction < 0.0 ? 0.0 : (fraction > 1.0 ? 1.0 : fraction);
        st->fg_gray = fg_gray;
        st->bg_gray = bg_gray;
        st->track_gray = track_gray;
        if (set_data) {
            set_data(eb, "kindle-custom-progress-state", st, free);
        }
        conn(eb, "expose-event", (void*)c_custom_progress_expose, st, NULL, 0);
    }
    return eb;
#else
    return NULL;
#endif
}

void kgtk_custom_progress_set_fraction(KWidgetRef pbar, double fraction) {
#if !defined(_WIN32)
    typedef void* (*fn_g_object_get_data)(void*, const char*);
    fn_g_object_get_data get_data = (fn_g_object_get_data)resolve_sym("g_object_get_data");
    if (get_data && pbar) {
        KCustomProgressState* st = (KCustomProgressState*)get_data(pbar, "kindle-custom-progress-state");
        if (st) {
            double clamped = fraction < 0.0 ? 0.0 : (fraction > 1.0 ? 1.0 : fraction);
            st->fraction = clamped;
            kgtk_widget_queue_draw(pbar);
        }
    }
#else
    (void)pbar;
    (void)fraction;
#endif
}

KWidgetRef kgtk_custom_divider_new(
    bool vertical,
    int thickness,
    uint8_t gray_level
) {
#if !defined(_WIN32)
    KWidgetRef eb = kgtk_alignment_new(0.5, 0.5, 1.0, 1.0);
    fn_g_signal_connect_data conn = (fn_g_signal_connect_data)resolve_sym("g_signal_connect_data");
    fn_g_object_set_data_full set_data = (fn_g_object_set_data_full)resolve_sym("g_object_set_data_full");
    if (!eb || !conn) return eb;

    int t = thickness > 0 ? thickness : 2;
    if (vertical) {
        kgtk_widget_set_size_request(eb, t, -1);
    } else {
        kgtk_widget_set_size_request(eb, -1, t);
    }

    KCustomDividerState* st = (KCustomDividerState*)malloc(sizeof(KCustomDividerState));
    if (st) {
        st->gray_level = gray_level;
        if (set_data) {
            set_data(eb, "kindle-custom-divider-state", st, free);
        }
        conn(eb, "expose-event", (void*)c_custom_divider_expose, st, NULL, 0);
    }
    return eb;
#else
    return NULL;
#endif
}

// --- Cairo Vector Icons, Multi-Line TextEditor, and Gesture Event Box ---

#if !defined(_WIN32)
#include <sys/time.h>

typedef struct {
    int icon_id;
    int size;
    uint8_t fg_gray;
    uint8_t bg_gray;
    bool has_bg;
} KCustomIconState;

static int c_custom_icon_expose(KWidgetRef widget, void* event, void* data) {
    KCustomIconState* st = (KCustomIconState*)data;
    if (!st || !widget) return 0;

    fn_gtk_widget_get_window get_win = (fn_gtk_widget_get_window)resolve_sym("gtk_widget_get_window");
    fn_gtk_widget_get_allocation get_alloc = (fn_gtk_widget_get_allocation)resolve_sym("gtk_widget_get_allocation");
    fn_gdk_cairo_create cairo_create = (fn_gdk_cairo_create)resolve_sym("gdk_cairo_create");
    fn_cairo_destroy cairo_destroy = (fn_cairo_destroy)resolve_sym("cairo_destroy");
    fn_cairo_new_path new_path = (fn_cairo_new_path)resolve_sym("cairo_new_path");
    fn_cairo_close_path close_path = (fn_cairo_close_path)resolve_sym("cairo_close_path");
    fn_cairo_move_to move_to = (fn_cairo_move_to)resolve_sym("cairo_move_to");
    fn_cairo_line_to line_to = (fn_cairo_line_to)resolve_sym("cairo_line_to");
    fn_cairo_arc arc = (fn_cairo_arc)resolve_sym("cairo_arc");
    fn_cairo_fill fill = (fn_cairo_fill)resolve_sym("cairo_fill");
    fn_cairo_stroke stroke = (fn_cairo_stroke)resolve_sym("cairo_stroke");
    fn_cairo_set_line_width set_lw = (fn_cairo_set_line_width)resolve_sym("cairo_set_line_width");
    fn_cairo_set_line_cap set_cap = (fn_cairo_set_line_cap)resolve_sym("cairo_set_line_cap");
    fn_cairo_set_line_join set_join = (fn_cairo_set_line_join)resolve_sym("cairo_set_line_join");
    if (!get_win || !get_alloc || !cairo_create || !cairo_destroy || !move_to || !line_to || !arc || !fill || !stroke || !set_lw) return 0;

    void* gdk_win = get_win(widget);
    if (!gdk_win) return 0;

    KGtkAllocation alloc = { 0, 0, 0, 0 };
    get_alloc(widget, &alloc);
    if (alloc.width <= 2 || alloc.height <= 2) return 0;

    void* cr = cairo_create(gdk_win);
    if (!cr) return 0;
    kcairo_clip_to_expose(cr, event);

    double w = (double)alloc.width;
    double h = (double)alloc.height;
    double s = w < h ? w : h;
    double cx = (double)alloc.x + w * 0.5;
    double cy = (double)alloc.y + h * 0.5;
    double r = s * 0.45;
    double lw = s * 0.085;
    if (lw < 2.0) lw = 2.0;

    if (st->has_bg) {
        kcairo_rounded_rect(cr, (double)alloc.x, (double)alloc.y, w, h, s * 0.22);
        kcairo_set_gray(cr, st->bg_gray);
        fill(cr);
    }

    kcairo_set_gray(cr, st->fg_gray);
    set_lw(cr, lw);
    if (set_cap) set_cap(cr, 1);   // CAIRO_LINE_CAP_ROUND
    if (set_join) set_join(cr, 1); // CAIRO_LINE_JOIN_ROUND

    const double pi = 3.14159265358979323846;

    switch (st->icon_id) {
    case 0: // wifi
        if (new_path) new_path(cr);
        arc(cr, cx, cy + r * 0.55, r * 0.12, 0, 2 * pi);
        fill(cr);
        for (int ring = 1; ring <= 3; ++ring) {
            if (new_path) new_path(cr);
            arc(cr, cx, cy + r * 0.55, r * (0.38 * ring), 1.22 * pi, 1.78 * pi);
            stroke(cr);
        }
        break;

    case 1: // battery
        kcairo_rounded_rect(cr, cx - r * 0.95, cy - r * 0.52, r * 1.65, r * 1.04, r * 0.18);
        stroke(cr);
        kcairo_rounded_rect(cr, cx + r * 0.75, cy - r * 0.25, r * 0.20, r * 0.50, r * 0.06);
        fill(cr);
        kcairo_rounded_rect(cr, cx - r * 0.72, cy - r * 0.30, r * 1.05, r * 0.60, r * 0.08);
        fill(cr);
        break;

    case 2: // sun
        if (new_path) new_path(cr);
        arc(cr, cx, cy, r * 0.45, 0, 2 * pi);
        stroke(cr);
        for (int i = 0; i < 8; ++i) {
            double ang = (double)i * (pi / 4.0);
            double c = (i % 2 == 0) ? ((i == 0) ? 1.0 : (i == 4 ? -1.0 : 0.0)) : ((i == 1 || i == 7) ? 0.7071 : -0.7071);
            double sn = (i % 2 == 0) ? ((i == 2) ? 1.0 : (i == 6 ? -1.0 : 0.0)) : ((i == 1 || i == 3) ? 0.7071 : -0.7071);
            (void)ang;
            move_to(cr, cx + c * r * 0.68, cy + sn * r * 0.68);
            line_to(cr, cx + c * r * 0.98, cy + sn * r * 0.98);
        }
        stroke(cr);
        break;

    case 3: // moon
        if (new_path) new_path(cr);
        arc(cr, cx, cy, r * 0.78, 0.25 * pi, 1.55 * pi);
        arc(cr, cx + r * 0.35, cy - r * 0.22, r * 0.62, 1.40 * pi, 0.40 * pi);
        if (close_path) close_path(cr);
        stroke(cr);
        break;

    case 4: // refresh
        if (new_path) new_path(cr);
        arc(cr, cx, cy, r * 0.78, 0.15 * pi, 1.75 * pi);
        stroke(cr);
        move_to(cr, cx + r * 0.30, cy - r * 0.82);
        line_to(cr, cx + r * 0.78, cy - r * 0.55);
        line_to(cr, cx + r * 0.42, cy - r * 0.20);
        stroke(cr);
        break;

    case 5: // chevronLeft
        move_to(cr, cx + r * 0.30, cy - r * 0.68);
        line_to(cr, cx - r * 0.38, cy);
        line_to(cr, cx + r * 0.30, cy + r * 0.68);
        stroke(cr);
        break;

    case 6: // chevronRight
        move_to(cr, cx - r * 0.30, cy - r * 0.68);
        line_to(cr, cx + r * 0.38, cy);
        line_to(cr, cx - r * 0.30, cy + r * 0.68);
        stroke(cr);
        break;

    case 7: // chevronDown
        move_to(cr, cx - r * 0.68, cy - r * 0.28);
        line_to(cr, cx, cy + r * 0.38);
        line_to(cr, cx + r * 0.68, cy - r * 0.28);
        stroke(cr);
        break;

    case 8: // chevronUp
        move_to(cr, cx - r * 0.68, cy + r * 0.28);
        line_to(cr, cx, cy - r * 0.38);
        line_to(cr, cx + r * 0.68, cy + r * 0.28);
        stroke(cr);
        break;

    case 9: // search
        if (new_path) new_path(cr);
        arc(cr, cx - r * 0.15, cy - r * 0.15, r * 0.58, 0, 2 * pi);
        stroke(cr);
        move_to(cr, cx + r * 0.28, cy + r * 0.28);
        line_to(cr, cx + r * 0.85, cy + r * 0.85);
        stroke(cr);
        break;

    case 10: // bookmark
        move_to(cr, cx - r * 0.58, cy - r * 0.85);
        line_to(cr, cx + r * 0.58, cy - r * 0.85);
        line_to(cr, cx + r * 0.58, cy + r * 0.85);
        line_to(cr, cx, cy + r * 0.38);
        line_to(cr, cx - r * 0.58, cy + r * 0.85);
        if (close_path) close_path(cr);
        stroke(cr);
        break;

    case 11: // check
        move_to(cr, cx - r * 0.72, cy + r * 0.05);
        line_to(cr, cx - r * 0.18, cy + r * 0.58);
        line_to(cr, cx + r * 0.78, cy - r * 0.52);
        stroke(cr);
        break;

    case 12: // warning
        move_to(cr, cx, cy - r * 0.85);
        line_to(cr, cx + r * 0.88, cy + r * 0.75);
        line_to(cr, cx - r * 0.88, cy + r * 0.75);
        if (close_path) close_path(cr);
        stroke(cr);
        move_to(cr, cx, cy - r * 0.25);
        line_to(cr, cx, cy + r * 0.25);
        stroke(cr);
        if (new_path) new_path(cr);
        arc(cr, cx, cy + r * 0.50, lw * 0.6, 0, 2 * pi);
        fill(cr);
        break;

    case 13: // info
        if (new_path) new_path(cr);
        arc(cr, cx, cy, r * 0.85, 0, 2 * pi);
        stroke(cr);
        move_to(cr, cx, cy - r * 0.05);
        line_to(cr, cx, cy + r * 0.48);
        stroke(cr);
        if (new_path) new_path(cr);
        arc(cr, cx, cy - r * 0.42, lw * 0.6, 0, 2 * pi);
        fill(cr);
        break;

    case 14: // book
        move_to(cr, cx, cy - r * 0.65);
        line_to(cr, cx, cy + r * 0.75);
        move_to(cr, cx, cy - r * 0.65);
        line_to(cr, cx - r * 0.85, cy - r * 0.78);
        line_to(cr, cx - r * 0.85, cy + r * 0.62);
        line_to(cr, cx, cy + r * 0.75);
        line_to(cr, cx + r * 0.85, cy + r * 0.62);
        line_to(cr, cx + r * 0.85, cy - r * 0.78);
        if (close_path) close_path(cr);
        stroke(cr);
        break;

    case 15: // globe
        if (new_path) new_path(cr);
        arc(cr, cx, cy, r * 0.85, 0, 2 * pi);
        stroke(cr);
        if (new_path) new_path(cr);
        arc(cr, cx - r * 0.72, cy, r * 1.12, -0.26 * pi, 0.26 * pi);
        stroke(cr);
        if (new_path) new_path(cr);
        arc(cr, cx + r * 0.72, cy, r * 1.12, 0.74 * pi, 1.26 * pi);
        stroke(cr);
        move_to(cr, cx - r * 0.85, cy);
        line_to(cr, cx + r * 0.85, cy);
        move_to(cr, cx, cy - r * 0.85);
        line_to(cr, cx, cy + r * 0.85);
        stroke(cr);
        break;

    case 16: // cloud
        kcairo_rounded_rect(cr, cx - r * 0.85, cy - r * 0.25, r * 1.70, r * 0.85, r * 0.42);
        stroke(cr);
        if (new_path) new_path(cr);
        arc(cr, cx - r * 0.15, cy - r * 0.25, r * 0.45, pi, 2 * pi);
        stroke(cr);
        break;

    case 17: // gear / settings
        if (new_path) new_path(cr);
        arc(cr, cx, cy, r * 0.42, 0, 2 * pi);
        stroke(cr);
        for (int i = 0; i < 8; ++i) {
            double c = (i % 2 == 0) ? ((i == 0) ? 1.0 : (i == 4 ? -1.0 : 0.0)) : ((i == 1 || i == 7) ? 0.7071 : -0.7071);
            double sn = (i % 2 == 0) ? ((i == 2) ? 1.0 : (i == 6 ? -1.0 : 0.0)) : ((i == 1 || i == 3) ? 0.7071 : -0.7071);
            move_to(cr, cx + c * r * 0.45, cy + sn * r * 0.45);
            line_to(cr, cx + c * r * 0.88, cy + sn * r * 0.88);
        }
        stroke(cr);
        break;

    case 18: // sliders
        for (int row = -1; row <= 1; ++row) {
            double ry = cy + (double)row * r * 0.55;
            move_to(cr, cx - r * 0.82, ry);
            line_to(cr, cx + r * 0.82, ry);
            stroke(cr);
            double kx = cx + (row == 0 ? r * 0.32 : -r * 0.28);
            if (new_path) new_path(cr);
            arc(cr, kx, ry, r * 0.18, 0, 2 * pi);
            fill(cr);
        }
        break;

    case 19: // plus
        move_to(cr, cx - r * 0.72, cy);
        line_to(cr, cx + r * 0.72, cy);
        move_to(cr, cx, cy - r * 0.72);
        line_to(cr, cx, cy + r * 0.72);
        stroke(cr);
        break;

    case 20: // minus
        move_to(cr, cx - r * 0.72, cy);
        line_to(cr, cx + r * 0.72, cy);
        stroke(cr);
        break;

    case 21: // close
        move_to(cr, cx - r * 0.62, cy - r * 0.62);
        line_to(cr, cx + r * 0.62, cy + r * 0.62);
        move_to(cr, cx + r * 0.62, cy - r * 0.62);
        line_to(cr, cx - r * 0.62, cy + r * 0.62);
        stroke(cr);
        break;

    case 22: // star
        move_to(cr, cx, cy - r * 0.85);
        line_to(cr, cx + r * 0.52, cy + r * 0.75);
        line_to(cr, cx - r * 0.82, cy - r * 0.22);
        line_to(cr, cx + r * 0.82, cy - r * 0.22);
        line_to(cr, cx - r * 0.52, cy + r * 0.75);
        if (close_path) close_path(cr);
        stroke(cr);
        break;

    case 23: // bolt
        move_to(cr, cx + r * 0.12, cy - r * 0.88);
        line_to(cr, cx - r * 0.55, cy + r * 0.08);
        line_to(cr, cx + r * 0.05, cy + r * 0.08);
        line_to(cr, cx - r * 0.12, cy + r * 0.88);
        line_to(cr, cx + r * 0.55, cy - r * 0.08);
        line_to(cr, cx - r * 0.05, cy - r * 0.08);
        if (close_path) close_path(cr);
        stroke(cr);
        break;

    case 24: // pencil
        // Diagonal pencil body + nib at bottom-left
        move_to(cr, cx - r * 0.78, cy + r * 0.78);
        line_to(cr, cx - r * 0.72, cy + r * 0.30);
        line_to(cr, cx + r * 0.36, cy - r * 0.78);
        line_to(cr, cx + r * 0.78, cy - r * 0.36);
        line_to(cr, cx - r * 0.30, cy + r * 0.72);
        if (close_path) close_path(cr);
        stroke(cr);
        // Eraser collar line
        move_to(cr, cx + r * 0.16, cy - r * 0.58);
        line_to(cr, cx + r * 0.58, cy - r * 0.16);
        stroke(cr);
        // Nib collar line
        move_to(cr, cx - r * 0.72, cy + r * 0.30);
        line_to(cr, cx - r * 0.30, cy + r * 0.72);
        stroke(cr);
        break;

    case 25: // share (box tray + upward arrow)
        move_to(cr, cx - r * 0.42, cy - r * 0.08);
        line_to(cr, cx - r * 0.72, cy - r * 0.08);
        line_to(cr, cx - r * 0.72, cy + r * 0.80);
        line_to(cr, cx + r * 0.72, cy + r * 0.80);
        line_to(cr, cx + r * 0.72, cy - r * 0.08);
        line_to(cr, cx + r * 0.42, cy - r * 0.08);
        stroke(cr);
        move_to(cr, cx, cy + r * 0.36);
        line_to(cr, cx, cy - r * 0.82);
        stroke(cr);
        move_to(cr, cx - r * 0.36, cy - r * 0.44);
        line_to(cr, cx, cy - r * 0.82);
        line_to(cr, cx + r * 0.36, cy - r * 0.44);
        stroke(cr);
        break;

    case 26: // folder
        move_to(cr, cx - r * 0.85, cy - r * 0.58);
        line_to(cr, cx - r * 0.22, cy - r * 0.58);
        line_to(cr, cx - r * 0.02, cy - r * 0.32);
        line_to(cr, cx + r * 0.85, cy - r * 0.32);
        line_to(cr, cx + r * 0.85, cy + r * 0.68);
        line_to(cr, cx - r * 0.85, cy + r * 0.68);
        if (close_path) close_path(cr);
        stroke(cr);
        break;

    case 27: // document
        move_to(cr, cx - r * 0.65, cy - r * 0.82);
        line_to(cr, cx + r * 0.25, cy - r * 0.82);
        line_to(cr, cx + r * 0.65, cy - r * 0.42);
        line_to(cr, cx + r * 0.65, cy + r * 0.82);
        line_to(cr, cx - r * 0.65, cy + r * 0.82);
        if (close_path) close_path(cr);
        stroke(cr);
        move_to(cr, cx + r * 0.25, cy - r * 0.82);
        line_to(cr, cx + r * 0.25, cy - r * 0.42);
        line_to(cr, cx + r * 0.65, cy - r * 0.42);
        stroke(cr);
        move_to(cr, cx - r * 0.36, cy + r * 0.05);
        line_to(cr, cx + r * 0.36, cy + r * 0.05);
        move_to(cr, cx - r * 0.36, cy + r * 0.38);
        line_to(cr, cx + r * 0.36, cy + r * 0.38);
        stroke(cr);
        break;

    case 28: // calendar
        kcairo_rounded_rect(cr, cx - r * 0.78, cy - r * 0.62, r * 1.56, r * 1.40, r * 0.16);
        stroke(cr);
        move_to(cr, cx - r * 0.78, cy - r * 0.18);
        line_to(cr, cx + r * 0.78, cy - r * 0.18);
        move_to(cr, cx - r * 0.38, cy - r * 0.82);
        line_to(cr, cx - r * 0.38, cy - r * 0.46);
        move_to(cr, cx + r * 0.38, cy - r * 0.82);
        line_to(cr, cx + r * 0.38, cy - r * 0.46);
        stroke(cr);
        break;

    case 29: // bookmarkFill
        move_to(cr, cx - r * 0.58, cy - r * 0.85);
        line_to(cr, cx + r * 0.58, cy - r * 0.85);
        line_to(cr, cx + r * 0.58, cy + r * 0.85);
        line_to(cr, cx, cy + r * 0.38);
        line_to(cr, cx - r * 0.58, cy + r * 0.85);
        if (close_path) close_path(cr);
        fill(cr);
        move_to(cr, cx - r * 0.58, cy - r * 0.85);
        line_to(cr, cx + r * 0.58, cy - r * 0.85);
        line_to(cr, cx + r * 0.58, cy + r * 0.85);
        line_to(cr, cx, cy + r * 0.38);
        line_to(cr, cx - r * 0.58, cy + r * 0.85);
        if (close_path) close_path(cr);
        stroke(cr);
        break;

    default:
        kcairo_rounded_rect(cr, cx - r * 0.78, cy - r * 0.62, r * 1.56, r * 1.40, r * 0.16);
        stroke(cr);
        break;
    }

    cairo_destroy(cr);
    return 0;
}

typedef struct {
    int press_x;
    int press_y;
    double press_root_x;
    double press_root_y;
    double last_root_x;
    double last_root_y;
    long long press_ms;
    bool pressed;
    bool captures_drag;
    int long_press_ms;
    int swipe_threshold_px;
    KGestureCallback on_gesture;
    void* user_data;
} KGestureBoxState;

static long long kgtk_now_ms(void) {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return (long long)tv.tv_sec * 1000LL + (long long)(tv.tv_usec / 1000);
}

static int c_gesture_box_press(KWidgetRef widget, void* event, void* data) {
    KGestureBoxState* st = (KGestureBoxState*)data;
    if (!st || !event) return 0;
    if (!c_event_is_button1_press(event)) return 1;
    fn_gdk_event_get_coords get_coords = (fn_gdk_event_get_coords)resolve_sym("gdk_event_get_coords");
    fn_gdk_event_get_root_coords get_root = (fn_gdk_event_get_root_coords)resolve_sym("gdk_event_get_root_coords");
    double x = 0.0, y = 0.0;
    if (get_coords) get_coords(event, &x, &y);
    double rx = x, ry = y;
    if (get_root) get_root(event, &rx, &ry);
    st->press_x = (int)x;
    st->press_y = (int)y;
    st->press_root_x = rx;
    st->press_root_y = ry;
    st->last_root_x = rx;
    st->last_root_y = ry;
    st->press_ms = kgtk_now_ms();
    st->pressed = true;
    if (!st->captures_drag) {
        c_scroll_drag_begin(widget, NULL, event, true);
    }
    if (st->on_gesture) {
        st->on_gesture(12, st->press_x, st->press_y, st->user_data);
    }
    return 1;
}

static int c_gesture_box_motion(KWidgetRef widget, void* event, void* data) {
    (void)widget;
    KGestureBoxState* st = (KGestureBoxState*)data;
    if (!st || !st->pressed || !event) return 0;
    if (!c_event_has_button1_mask(event)) {
        st->pressed = false;
        g_gesture_dragging = false;
        c_scroll_drag_end();
        return 0;
    }
    if (!st->captures_drag) {
        c_scroll_drag_update(event);
    }
    fn_gdk_event_get_root_coords get_root = (fn_gdk_event_get_root_coords)resolve_sym("gdk_event_get_root_coords");
    double rx = 0.0, ry = 0.0;
    if (get_root) get_root(event, &rx, &ry);
    double prev_dx = st->last_root_x - st->press_root_x;
    double prev_dy = st->last_root_y - st->press_root_y;
    double cur_dx = rx - st->press_root_x;
    double cur_dy = ry - st->press_root_y;
    if (!((prev_dx * prev_dx + prev_dy * prev_dy) > 400.0 && (cur_dx * cur_dx + cur_dy * cur_dy) <= 4.0)) {
        st->last_root_x = rx;
        st->last_root_y = ry;
    } else {
        rx = st->last_root_x;
        ry = st->last_root_y;
    }
    int dx = (int)(rx - st->press_root_x);
    int dy = (int)(ry - st->press_root_y);
    int adx = dx < 0 ? -dx : dx;
    int ady = dy < 0 ? -dy : dy;
    if (st->captures_drag && (adx >= 6 || ady >= 6)) {
        g_gesture_dragging = true;
        if (st->on_gesture) {
            st->on_gesture(10, dx, dy, st->user_data);
        }
    }
    return 1;
}

static int c_gesture_box_release(KWidgetRef widget, void* event, void* data) {
    (void)widget;
    KGestureBoxState* st = (KGestureBoxState*)data;
    if (!c_event_is_button1_release(event)) return 1;
    bool did_scroll = c_scroll_drag_end();
    if (!st || !st->pressed || !event) return 0;
    st->pressed = false;
    bool was_dragging = g_gesture_dragging;
    g_gesture_dragging = false;
    fn_gdk_event_get_root_coords get_root = (fn_gdk_event_get_root_coords)resolve_sym("gdk_event_get_root_coords");
    double rx = st->last_root_x, ry = st->last_root_y;
    if (get_root) {
        double erx = 0.0, ery = 0.0;
        if (get_root(event, &erx, &ery)) {
            double prev_dx = st->last_root_x - st->press_root_x;
            double prev_dy = st->last_root_y - st->press_root_y;
            double cur_dx = erx - st->press_root_x;
            double cur_dy = ery - st->press_root_y;
            if (!((prev_dx * prev_dx + prev_dy * prev_dy) > 400.0 && (cur_dx * cur_dx + cur_dy * cur_dy) <= 4.0)) {
                rx = erx;
                ry = ery;
            }
        }
    }
    int dx = (int)(rx - st->press_root_x);
    int dy = (int)(ry - st->press_root_y);
    int adx = dx < 0 ? -dx : dx;
    int ady = dy < 0 ? -dy : dy;
    long long elapsed = kgtk_now_ms() - st->press_ms;
    int thresh = st->swipe_threshold_px > 10 ? st->swipe_threshold_px : 40;
    int lp_ms = st->long_press_ms > 100 ? st->long_press_ms : 500;
    KGestureCallback cb = st->on_gesture;
    void* ud = st->user_data;
    if (!cb) return 1;

    if (adx >= thresh || ady >= thresh) {
        if (adx >= ady && (!did_scroll || adx >= ady * 2)) {
            cb(dx < 0 ? 3 : 4, dx, dy, ud);
        } else if (!did_scroll) {
            cb(dy < 0 ? 5 : 6, dx, dy, ud);
        }
    }

    if (st->captures_drag && (was_dragging || adx >= 6 || ady >= 6)) {
        cb(11, dx, dy, ud);
    } else if (!did_scroll && adx < 10 && ady < 10) {
        if (elapsed >= (long long)lp_ms) {
            cb(2, dx, dy, ud);
        } else {
            cb(1, dx, dy, ud);
        }
    }
    return 1;
}

typedef KWidgetRef (KGTK_ABI *fn_gtk_text_view_new)(void);
typedef void* (KGTK_ABI *fn_gtk_text_view_get_buffer)(KWidgetRef);
typedef void (KGTK_ABI *fn_gtk_text_view_set_wrap_mode)(KWidgetRef, int);
typedef void (KGTK_ABI *fn_gtk_text_view_set_left_margin)(KWidgetRef, int);
typedef void (KGTK_ABI *fn_gtk_text_view_set_right_margin)(KWidgetRef, int);
typedef void (KGTK_ABI *fn_gtk_text_buffer_set_text)(void*, const char*, int);
typedef void (KGTK_ABI *fn_gtk_text_buffer_get_start_iter)(void*, void*);
typedef void (KGTK_ABI *fn_gtk_text_buffer_get_end_iter)(void*, void*);
typedef char* (KGTK_ABI *fn_gtk_text_buffer_get_text)(void*, const void*, const void*, int);
typedef void (KGTK_ABI *fn_g_free)(void*);

typedef struct {
    KWidgetRef text_view;
    KSignalCallback on_changed;
    void* user_data;
} KTextEditorState;

static void c_text_buffer_changed(void* buffer, void* data) {
    (void)buffer;
    KTextEditorState* st = (KTextEditorState*)data;
    if (st && st->on_changed) {
        st->on_changed(st->text_view, st->user_data);
    }
}
#endif

KWidgetRef kgtk_custom_icon_new(
    int icon_id,
    int size,
    uint8_t fg_gray,
    uint8_t bg_gray,
    bool has_bg
) {
#if !defined(_WIN32)
    KWidgetRef eb = kgtk_alignment_new(0.5, 0.5, 0.0, 0.0);
    fn_g_signal_connect_data conn = (fn_g_signal_connect_data)resolve_sym("g_signal_connect_data");
    fn_g_object_set_data_full set_data = (fn_g_object_set_data_full)resolve_sym("g_object_set_data_full");
    if (!eb || !conn) return eb;

    int px = (int)((size > 8 ? size : 40) * 1.35);
    kgtk_widget_set_size_request(eb, px, px);

    KCustomIconState* st = (KCustomIconState*)malloc(sizeof(KCustomIconState));
    if (st) {
        st->icon_id = icon_id;
        st->size = px;
        st->fg_gray = fg_gray;
        st->bg_gray = bg_gray;
        st->has_bg = has_bg;
        if (set_data) {
            set_data(eb, "kindle-custom-icon-state", st, free);
        }
        conn(eb, "expose-event", (void*)c_custom_icon_expose, st, NULL, 0);
    }
    return eb;
#else
    return NULL;
#endif
}

KWidgetRef kgtk_gesture_box_new(
    KWidgetRef child,
    int long_press_ms,
    int swipe_threshold_px,
    KGestureCallback on_gesture,
    void* user_data
) {
#if !defined(_WIN32)
    KWidgetRef eb = kgtk_event_box_new();
    fn_gtk_event_box_set_visible_window set_vis = (fn_gtk_event_box_set_visible_window)resolve_sym("gtk_event_box_set_visible_window");
    fn_gtk_widget_add_events add_events = (fn_gtk_widget_add_events)resolve_sym("gtk_widget_add_events");
    fn_g_signal_connect_data conn = (fn_g_signal_connect_data)resolve_sym("g_signal_connect_data");
    fn_g_object_set_data_full set_data = (fn_g_object_set_data_full)resolve_sym("g_object_set_data_full");
    if (!eb) return child;
    if (set_vis) set_vis(eb, 0);
    // GDK_POINTER_MOTION_MASK (4) | GDK_BUTTON_PRESS_MASK (256) | GDK_BUTTON_RELEASE_MASK (512)
    if (add_events) add_events(eb, 4 | 256 | 512);
    if (child) kgtk_container_add(eb, child);

    KGestureBoxState* st = (KGestureBoxState*)malloc(sizeof(KGestureBoxState));
    if (st && conn) {
        bool captures = swipe_threshold_px < 0;
        int raw_thresh = captures ? -swipe_threshold_px : swipe_threshold_px;
        st->press_x = 0;
        st->press_y = 0;
        st->press_root_x = 0.0;
        st->press_root_y = 0.0;
        st->press_ms = 0;
        st->pressed = false;
        st->captures_drag = captures;
        st->long_press_ms = long_press_ms;
        st->swipe_threshold_px = kgtk_scale_px(raw_thresh);
        st->on_gesture = on_gesture;
        st->user_data = user_data;
        if (set_data) {
            set_data(eb, "kindle-gesture-box-state", st, free);
        }
        conn(eb, "button-press-event", (void*)c_gesture_box_press, st, NULL, 0);
        conn(eb, "motion-notify-event", (void*)c_gesture_box_motion, st, NULL, 0);
        conn(eb, "button-release-event", (void*)c_gesture_box_release, st, NULL, 0);
    } else if (st) {
        free(st);
    }
    return eb;
#else
    return child;
#endif
}

KWidgetRef kgtk_text_editor_new(
    const char* text,
    int min_height,
    uint8_t fg_gray,
    uint8_t bg_gray,
    const char* font_desc,
    KSignalCallback on_changed,
    void* user_data
) {
#if !defined(_WIN32)
    fn_gtk_text_view_new tv_new = (fn_gtk_text_view_new)resolve_sym("gtk_text_view_new");
    fn_gtk_text_view_get_buffer get_buf = (fn_gtk_text_view_get_buffer)resolve_sym("gtk_text_view_get_buffer");
    fn_gtk_text_view_set_wrap_mode set_wrap = (fn_gtk_text_view_set_wrap_mode)resolve_sym("gtk_text_view_set_wrap_mode");
    fn_gtk_text_view_set_left_margin set_lm = (fn_gtk_text_view_set_left_margin)resolve_sym("gtk_text_view_set_left_margin");
    fn_gtk_text_view_set_right_margin set_rm = (fn_gtk_text_view_set_right_margin)resolve_sym("gtk_text_view_set_right_margin");
    fn_gtk_text_buffer_set_text set_txt = (fn_gtk_text_buffer_set_text)resolve_sym("gtk_text_buffer_set_text");
    fn_g_signal_connect_data conn = (fn_g_signal_connect_data)resolve_sym("g_signal_connect_data");
    fn_g_object_set_data_full set_data = (fn_g_object_set_data_full)resolve_sym("g_object_set_data_full");
    if (!tv_new || !get_buf) return NULL;

    KWidgetRef tv = tv_new();
    if (!tv) return NULL;
    if (set_wrap) set_wrap(tv, 2); // GTK_WRAP_WORD = 2
    int margin = kgtk_scale_px(16);
    if (set_lm) set_lm(tv, margin);
    if (set_rm) set_rm(tv, margin);
    if (min_height > 0) {
        kgtk_widget_set_size_request(tv, -1, min_height);
    }
    if (font_desc) {
        kgtk_widget_modify_font_string(tv, font_desc);
    }
    kgtk_widget_modify_fg_gray(tv, 0, fg_gray);
    kgtk_widget_modify_bg_gray(tv, 0, bg_gray);

    void* buf = get_buf(tv);
    if (buf && set_txt && text) {
        set_txt(buf, text, -1);
    }

    if (buf && conn && on_changed) {
        KTextEditorState* st = (KTextEditorState*)malloc(sizeof(KTextEditorState));
        if (st) {
            st->text_view = tv;
            st->on_changed = on_changed;
            st->user_data = user_data;
            if (set_data) {
                set_data(tv, "kindle-text-editor-state", st, free);
            }
            conn(buf, "changed", (void*)c_text_buffer_changed, st, NULL, 0);
        }
    }
    return tv;
#else
    return NULL;
#endif
}

char* kgtk_text_editor_get_text(KWidgetRef editor) {
#if !defined(_WIN32)
    if (!editor) return NULL;
    fn_gtk_text_view_get_buffer get_buf = (fn_gtk_text_view_get_buffer)resolve_sym("gtk_text_view_get_buffer");
    fn_gtk_text_buffer_get_start_iter get_start = (fn_gtk_text_buffer_get_start_iter)resolve_sym("gtk_text_buffer_get_start_iter");
    fn_gtk_text_buffer_get_end_iter get_end = (fn_gtk_text_buffer_get_end_iter)resolve_sym("gtk_text_buffer_get_end_iter");
    fn_gtk_text_buffer_get_text get_txt = (fn_gtk_text_buffer_get_text)resolve_sym("gtk_text_buffer_get_text");
    if (!get_buf || !get_start || !get_end || !get_txt) return NULL;

    void* buf = get_buf(editor);
    if (!buf) return NULL;
    // GtkTextIter is 80 bytes on 64-bit / 56 bytes on 32-bit; allocate 128 bytes safely.
    uint8_t start_iter[128] = {0};
    uint8_t end_iter[128] = {0};
    get_start(buf, start_iter);
    get_end(buf, end_iter);
    return get_txt(buf, start_iter, end_iter, 1);
#else
    return NULL;
#endif
}

void kgtk_free_string(char* str) {
#if !defined(_WIN32)
    if (!str) return;
    fn_g_free gfree = (fn_g_free)resolve_sym("g_free");
    if (gfree) {
        gfree(str);
    } else {
        free(str);
    }
#endif
}

#if !defined(_WIN32)
typedef int (KGTK_ABI *fn_LipcGetStringProperty)(void*, const char*, const char*, char**);
typedef void (KGTK_ABI *fn_LipcFreeString)(char*);

static pthread_mutex_t g_lipc_mutex = PTHREAD_MUTEX_INITIALIZER;
static void* g_lipc_handle = NULL;
static fn_LipcOpenNoName g_lipc_open_fn = NULL;
static fn_LipcClose g_lipc_close_fn = NULL;
static fn_LipcGetIntProperty g_lipc_get_int_fn = NULL;
static fn_LipcSetIntProperty g_lipc_set_int_fn = NULL;
static fn_LipcGetStringProperty g_lipc_get_str_fn = NULL;
static fn_LipcSetStringProperty g_lipc_set_str_fn = NULL;
static fn_LipcFreeString g_lipc_free_str_fn = NULL;

static void* c_get_lipc_handle_locked(void) {
    if (!g_lipc_lib) {
        g_lipc_lib = dlopen("liblipc.so", RTLD_LAZY | RTLD_GLOBAL);
    }
    if (!g_lipc_lib) return NULL;
    if (!g_lipc_open_fn) {
        g_lipc_open_fn = (fn_LipcOpenNoName)dlsym(g_lipc_lib, "LipcOpenNoName");
        g_lipc_close_fn = (fn_LipcClose)dlsym(g_lipc_lib, "LipcClose");
        g_lipc_get_int_fn = (fn_LipcGetIntProperty)dlsym(g_lipc_lib, "LipcGetIntProperty");
        g_lipc_set_int_fn = (fn_LipcSetIntProperty)dlsym(g_lipc_lib, "LipcSetIntProperty");
        g_lipc_get_str_fn = (fn_LipcGetStringProperty)dlsym(g_lipc_lib, "LipcGetStringProperty");
        g_lipc_set_str_fn = (fn_LipcSetStringProperty)dlsym(g_lipc_lib, "LipcSetStringProperty");
        g_lipc_free_str_fn = (fn_LipcFreeString)dlsym(g_lipc_lib, "LipcFreeString");
    }
    if (!g_lipc_handle && g_lipc_open_fn) {
        g_lipc_handle = g_lipc_open_fn();
    }
    return g_lipc_handle;
}
#endif

bool klipc_is_available(void) {
#if !defined(_WIN32)
    if (!g_lipc_lib) {
        g_lipc_lib = dlopen("liblipc.so", RTLD_LAZY | RTLD_GLOBAL);
    }
    return g_lipc_lib != NULL;
#else
    return false;
#endif
}

int klipc_get_int_property(const char* service, const char* prop, int* out_val) {
#if !defined(_WIN32)
    pthread_mutex_lock(&g_lipc_mutex);
    void* handle = c_get_lipc_handle_locked();
    if (!handle || !g_lipc_get_int_fn) {
        pthread_mutex_unlock(&g_lipc_mutex);
        return -1;
    }
    int res = g_lipc_get_int_fn(handle, service, prop, out_val);
    pthread_mutex_unlock(&g_lipc_mutex);
    return res;
#else
    return -1;
#endif
}

int klipc_set_int_property(const char* service, const char* prop, int val) {
#if !defined(_WIN32)
    pthread_mutex_lock(&g_lipc_mutex);
    void* handle = c_get_lipc_handle_locked();
    if (!handle || !g_lipc_set_int_fn) {
        pthread_mutex_unlock(&g_lipc_mutex);
        return -1;
    }
    int res = g_lipc_set_int_fn(handle, service, prop, val);
    pthread_mutex_unlock(&g_lipc_mutex);
    return res;
#else
    return -1;
#endif
}

int klipc_get_string_property(const char* service, const char* prop, char* out_buf, int buf_len) {
#if !defined(_WIN32)
    if (!out_buf || buf_len <= 0) return -1;
    pthread_mutex_lock(&g_lipc_mutex);
    void* handle = c_get_lipc_handle_locked();
    if (!handle || !g_lipc_get_str_fn) {
        pthread_mutex_unlock(&g_lipc_mutex);
        return -1;
    }
    char* val = NULL;
    int res = g_lipc_get_str_fn(handle, service, prop, &val);
    if (res == 0 && val) {
        strncpy(out_buf, val, (size_t)(buf_len - 1));
        out_buf[buf_len - 1] = '\0';
        if (g_lipc_free_str_fn) g_lipc_free_str_fn(val);
    }
    pthread_mutex_unlock(&g_lipc_mutex);
    return res;
#else
    return -1;
#endif
}

int klipc_set_string_property(const char* service, const char* prop, const char* val) {
#if !defined(_WIN32)
    pthread_mutex_lock(&g_lipc_mutex);
    void* handle = c_get_lipc_handle_locked();
    if (!handle || !g_lipc_set_str_fn) {
        pthread_mutex_unlock(&g_lipc_mutex);
        return -1;
    }
    int res = g_lipc_set_str_fn(handle, service, prop, val);
    pthread_mutex_unlock(&g_lipc_mutex);
    return res;
#else
    return -1;
#endif
}

// --- Embedded WebKitGTK 1.0 WebView (libwebkitgtk-1.0.so.0) ---

#if !defined(_WIN32)
typedef KWidgetRef (KGTK_ABI *fn_webkit_web_view_new)(void);
typedef void (KGTK_ABI *fn_webkit_web_view_load_uri)(KWidgetRef, const char*);
typedef void (KGTK_ABI *fn_webkit_web_view_load_html_string)(KWidgetRef, const char*, const char*);
typedef void (KGTK_ABI *fn_webkit_web_view_reload)(KWidgetRef);
typedef void (KGTK_ABI *fn_webkit_web_view_stop_loading)(KWidgetRef);
typedef void (KGTK_ABI *fn_webkit_web_view_go_back)(KWidgetRef);
typedef void (KGTK_ABI *fn_webkit_web_view_go_forward)(KWidgetRef);
typedef int (KGTK_ABI *fn_webkit_web_view_can_go_back)(KWidgetRef);
typedef int (KGTK_ABI *fn_webkit_web_view_can_go_forward)(KWidgetRef);
typedef void (KGTK_ABI *fn_webkit_web_view_set_zoom_level)(KWidgetRef, float);
typedef float (KGTK_ABI *fn_webkit_web_view_get_zoom_level)(KWidgetRef);
typedef void (KGTK_ABI *fn_webkit_web_view_set_full_content_zoom)(KWidgetRef, int);
typedef void (KGTK_ABI *fn_webkit_web_view_execute_script)(KWidgetRef, const char*);
typedef const char* (KGTK_ABI *fn_webkit_web_view_get_title)(KWidgetRef);
typedef const char* (KGTK_ABI *fn_webkit_web_view_get_uri)(KWidgetRef);
typedef void* (KGTK_ABI *fn_webkit_web_view_get_settings)(KWidgetRef);
typedef void (*fn_g_object_set_int)(void*, const char*, int, void*);
typedef KWidgetRef (KGTK_ABI *fn_gtk_widget_get_parent)(KWidgetRef);
typedef void* (KGTK_ABI *fn_g_object_ref_sink)(void*);
typedef void* (KGTK_ABI *fn_g_object_ref)(void*);

#define MAX_WEBVIEW_SLOTS 8

typedef struct {
    bool in_use;
    char view_id[64];
    KWidgetRef scrolled_window;
    KWidgetRef web_view;
    char* last_url;
    char* last_html;
    float last_zoom;
    KIdleCallback on_load_finished;
    void* user_data;
} KWebViewSlot;

static KWebViewSlot g_webview_slots[MAX_WEBVIEW_SLOTS];

static KWebViewSlot* kgtk_find_webview_slot(const char* view_id) {
    if (!view_id) view_id = "default";
    for (int i = 0; i < MAX_WEBVIEW_SLOTS; ++i) {
        if (g_webview_slots[i].in_use && strcmp(g_webview_slots[i].view_id, view_id) == 0) {
            return &g_webview_slots[i];
        }
    }
    return NULL;
}

static void kgtk_detach_cached_webviews(void) {
    fn_gtk_widget_get_parent get_parent = (fn_gtk_widget_get_parent)resolve_sym("gtk_widget_get_parent");
    fn_gtk_container_remove remove_fn = (fn_gtk_container_remove)resolve_sym("gtk_container_remove");
    if (!get_parent || !remove_fn) return;
    for (int i = 0; i < MAX_WEBVIEW_SLOTS; ++i) {
        if (g_webview_slots[i].in_use && g_webview_slots[i].scrolled_window) {
            KWidgetRef parent = get_parent(g_webview_slots[i].scrolled_window);
            if (parent) {
                remove_fn(parent, g_webview_slots[i].scrolled_window);
            }
        }
    }
}

static void kgtk_webview_write_and_load_html(KWidgetRef wv, const char* html, const char* base_uri) {
    if (!wv || !html) return;
    fn_webkit_web_view_load_html_string load_html = (fn_webkit_web_view_load_html_string)resolve_sym("webkit_web_view_load_html_string");
    if (load_html) {
        load_html(wv, html, (base_uri && base_uri[0]) ? base_uri : "file:///");
    }
}

static void c_webview_load_finished_idle(void* data) {
    KWebViewSlot* slot = (KWebViewSlot*)data;
    if (slot && slot->in_use && slot->on_load_finished && slot->user_data) {
        slot->on_load_finished(slot->user_data);
    }
}

static void c_webview_sync_slot_url(KWebViewSlot* slot) {
    if (!slot || !slot->web_view || slot->last_html != NULL) return;
    fn_webkit_web_view_get_uri get_uri = (fn_webkit_web_view_get_uri)resolve_sym("webkit_web_view_get_uri");
    if (!get_uri) return;
    const char* raw = get_uri(slot->web_view);
    if (!raw || !raw[0]) return;
    if (!slot->last_url || strcmp(slot->last_url, raw) != 0) {
        if (slot->last_url) free(slot->last_url);
        slot->last_url = strdup(raw);
    }
}

static void c_webview_load_committed(KWidgetRef web_view, void* frame, void* data) {
    (void)web_view;
    (void)frame;
    KWebViewSlot* slot = (KWebViewSlot*)data;
    if (slot) {
        c_webview_sync_slot_url(slot);
        if (slot->on_load_finished) {
            kgtk_schedule_idle(c_webview_load_finished_idle, slot);
        }
    }
}

static void c_webview_load_finished(KWidgetRef web_view, void* frame, void* data) {
    (void)web_view;
    (void)frame;
    KWebViewSlot* slot = (KWebViewSlot*)data;
    if (slot) {
        if (slot->web_view) {
            c_webview_sync_slot_url(slot);
            kgtk_widget_queue_draw(slot->web_view);
        }
        if (slot->on_load_finished) {
            kgtk_schedule_idle(c_webview_load_finished_idle, slot);
        }
    }
}
#endif

bool kgtk_webkit_available(void) {
#if !defined(_WIN32)
    if (!g_webkit_lib) {
        const char* webkit_candidates[] = {
            "libwebkitgtk-1.0.so.0",
            "/usr/lib/libwebkitgtk-1.0.so.0",
            "libwebkit-1.0.so.2",
            "/usr/lib/libwebkit-1.0.so.2",
            "libwebkitgtk-1.0.so",
            NULL
        };
        for (int i = 0; webkit_candidates[i] != NULL; ++i) {
            g_webkit_lib = dlopen(webkit_candidates[i], RTLD_LAZY | RTLD_GLOBAL);
            if (g_webkit_lib) break;
        }
    }
    return resolve_sym("webkit_web_view_new") != NULL;
#else
    return false;
#endif
}

KWidgetRef kgtk_webview_obtain(
    const char* view_id,
    const char* url,
    const char* html,
    const char* base_url,
    double zoom_level,
    int min_height,
    KIdleCallback on_load_finished,
    void* user_data
) {
#if !defined(_WIN32)
    if (!view_id || !view_id[0]) view_id = "default";
    if (!kgtk_webkit_available()) {
        return kgtk_label_new("WebKitGTK (libwebkitgtk-1.0.so.0) is not available on this host.");
    }

    fn_webkit_web_view_new wv_new = (fn_webkit_web_view_new)resolve_sym("webkit_web_view_new");
    fn_webkit_web_view_load_uri load_uri = (fn_webkit_web_view_load_uri)resolve_sym("webkit_web_view_load_uri");
    fn_webkit_web_view_set_zoom_level set_zoom = (fn_webkit_web_view_set_zoom_level)resolve_sym("webkit_web_view_set_zoom_level");
    fn_webkit_web_view_set_full_content_zoom set_full_zoom = (fn_webkit_web_view_set_full_content_zoom)resolve_sym("webkit_web_view_set_full_content_zoom");
    fn_gtk_scrolled_window_set_policy policy_fn = (fn_gtk_scrolled_window_set_policy)resolve_sym("gtk_scrolled_window_set_policy");
    fn_gtk_widget_get_parent get_parent = (fn_gtk_widget_get_parent)resolve_sym("gtk_widget_get_parent");
    fn_g_object_ref_sink ref_sink = (fn_g_object_ref_sink)resolve_sym("g_object_ref_sink");
    fn_g_object_ref ref_fn = (fn_g_object_ref)resolve_sym("g_object_ref");
    fn_g_signal_connect_data conn = (fn_g_signal_connect_data)resolve_sym("g_signal_connect_data");

    KWebViewSlot* slot = kgtk_find_webview_slot(view_id);
    if (!slot) {
        for (int i = 0; i < MAX_WEBVIEW_SLOTS; ++i) {
            if (!g_webview_slots[i].in_use) {
                slot = &g_webview_slots[i];
                break;
            }
        }
        if (!slot) slot = &g_webview_slots[0];

        KWidgetRef sw = kgtk_scrolled_window_new();
        KWidgetRef wv = wv_new ? wv_new() : NULL;
        if (!sw || !wv) return NULL;

        if (policy_fn) {
            // GTK_POLICY_AUTOMATIC (1) for horizontal and vertical
            policy_fn(sw, 1, 1);
        }
        if (ref_sink) ref_sink(sw);
        if (ref_fn) ref_fn(sw);

        if (set_full_zoom) {
            set_full_zoom(wv, 1);
        }

        kgtk_container_add(sw, wv);

        // Attach touch-drag scrolling to the WebView so dragging scrolls the scrolled_window
        KScrollDragState* drag_st = (KScrollDragState*)malloc(sizeof(KScrollDragState));
        if (drag_st && conn) {
            drag_st->scrolled_window = sw;
            drag_st->dragging = false;
            drag_st->start_root_y = 0.0;
            drag_st->start_scroll_val = 0.0;
            conn(wv, "button-press-event", (void*)c_scroll_drag_press, drag_st, NULL, 0);
            conn(wv, "motion-notify-event", (void*)c_scroll_drag_motion, drag_st, NULL, 0);
            conn(wv, "button-release-event", (void*)c_scroll_drag_release, drag_st, NULL, 0);
        } else if (drag_st) {
            free(drag_st);
        }

        slot->in_use = true;
        strncpy(slot->view_id, view_id, sizeof(slot->view_id) - 1);
        slot->view_id[sizeof(slot->view_id) - 1] = '\0';
        slot->scrolled_window = sw;
        slot->web_view = wv;
        slot->last_url = NULL;
        slot->last_html = NULL;
        slot->last_zoom = 0.0f;
        slot->on_load_finished = on_load_finished;
        slot->user_data = user_data;

        if (conn) {
            conn(wv, "load-committed", (void*)c_webview_load_committed, slot, NULL, 0);
            conn(wv, "load-finished", (void*)c_webview_load_finished, slot, NULL, 0);
        }
        fn_webkit_web_view_get_settings get_settings = (fn_webkit_web_view_get_settings)resolve_sym("webkit_web_view_get_settings");
        fn_g_object_set_int set_prop = (fn_g_object_set_int)resolve_sym("g_object_set");
        typedef void (KGTK_ABI *fn_g_object_set_str)(void*, const char*, const char*, void*);
        fn_g_object_set_str set_str_prop = (fn_g_object_set_str)resolve_sym("g_object_set");
        if (get_settings && set_prop) {
            void* settings = get_settings(wv);
            if (settings) {
                set_prop(settings, "auto-load-images", 1, NULL);
                set_prop(settings, "enable-scripts", 1, NULL);
                set_prop(settings, "enable-universal-access-from-file-uris", 1, NULL);
                set_prop(settings, "enable-file-access-from-file-uris", 1, NULL);
                set_prop(settings, "enforce-96-dpi", 1, NULL);
                set_prop(settings, "default-font-size", 16, NULL);
                set_prop(settings, "default-monospace-font-size", 13, NULL);
                set_prop(settings, "minimum-font-size", 1, NULL);
                if (set_str_prop) {
                    set_str_prop(
                        settings,
                        "user-agent",
                        "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36",
                        NULL
                    );
                }
            }
        }
    } else {
        slot->on_load_finished = on_load_finished;
        slot->user_data = user_data;
        if (get_parent && slot->scrolled_window) {
            KWidgetRef parent = get_parent(slot->scrolled_window);
            if (parent) {
                kgtk_container_remove(parent, slot->scrolled_window);
            }
        }
    }

    if (min_height > 0 && slot->scrolled_window) {
        kgtk_widget_set_size_request(slot->scrolled_window, -1, min_height);
    }

    float z = (zoom_level > 0.2 ? (float)zoom_level : 2.0f) * (float)kgtk_get_ui_scale();
    if (z < 0.4f) z = 0.4f;
    if (set_zoom && slot->web_view && (slot->last_zoom < z - 0.01f || slot->last_zoom > z + 0.01f)) {
        slot->last_zoom = z;
        set_zoom(slot->web_view, z);
    }

    if (html && html[0] != '\0') {
        if (!slot->last_html || strcmp(slot->last_html, html) != 0) {
            if (slot->last_html) free(slot->last_html);
            slot->last_html = strdup(html);
            if (slot->last_url) {
                free(slot->last_url);
                slot->last_url = NULL;
            }
            if (slot->web_view) {
                kgtk_webview_write_and_load_html(slot->web_view, html, base_url);
            }
        }
    } else if (url && url[0] != '\0') {
        if (!slot->last_url || strcmp(slot->last_url, url) != 0) {
            if (slot->last_url) free(slot->last_url);
            slot->last_url = strdup(url);
            if (slot->last_html) {
                free(slot->last_html);
                slot->last_html = NULL;
            }
            if (load_uri && slot->web_view) {
                load_uri(slot->web_view, url);
            }
        }
    }

    kgtk_widget_show_all(slot->scrolled_window);
    return slot->scrolled_window;
#else
    (void)view_id; (void)url; (void)html; (void)base_url;
    (void)zoom_level; (void)min_height; (void)on_load_finished; (void)user_data;
    return NULL;
#endif
}

void kgtk_webview_load_uri(const char* view_id, const char* uri) {
#if !defined(_WIN32)
    KWebViewSlot* slot = kgtk_find_webview_slot(view_id);
    if (!slot || !slot->web_view || !uri) return;
    if (slot->last_url) free(slot->last_url);
    slot->last_url = strdup(uri);
    if (slot->last_html) {
        free(slot->last_html);
        slot->last_html = NULL;
    }
    fn_webkit_web_view_load_uri load_uri = (fn_webkit_web_view_load_uri)resolve_sym("webkit_web_view_load_uri");
    if (load_uri) {
        load_uri(slot->web_view, uri);
    }
#endif
}

void kgtk_webview_load_html(const char* view_id, const char* html, const char* base_uri) {
#if !defined(_WIN32)
    KWebViewSlot* slot = kgtk_find_webview_slot(view_id);
    if (!slot || !slot->web_view || !html) return;
    if (slot->last_html) free(slot->last_html);
    slot->last_html = strdup(html);
    if (slot->last_url) {
        free(slot->last_url);
        slot->last_url = NULL;
    }
    kgtk_webview_write_and_load_html(slot->web_view, html, base_uri);
#endif
}

void kgtk_webview_reload(const char* view_id) {
#if !defined(_WIN32)
    KWebViewSlot* slot = kgtk_find_webview_slot(view_id);
    if (!slot || !slot->web_view) return;
    fn_webkit_web_view_reload fn = (fn_webkit_web_view_reload)resolve_sym("webkit_web_view_reload");
    if (fn) fn(slot->web_view);
#endif
}

void kgtk_webview_stop_loading(const char* view_id) {
#if !defined(_WIN32)
    KWebViewSlot* slot = kgtk_find_webview_slot(view_id);
    if (!slot || !slot->web_view) return;
    fn_webkit_web_view_stop_loading fn = (fn_webkit_web_view_stop_loading)resolve_sym("webkit_web_view_stop_loading");
    if (fn) fn(slot->web_view);
#endif
}

void kgtk_webview_go_back(const char* view_id) {
#if !defined(_WIN32)
    KWebViewSlot* slot = kgtk_find_webview_slot(view_id);
    if (!slot || !slot->web_view) return;
    fn_webkit_web_view_go_back fn = (fn_webkit_web_view_go_back)resolve_sym("webkit_web_view_go_back");
    if (fn) fn(slot->web_view);
#endif
}

void kgtk_webview_go_forward(const char* view_id) {
#if !defined(_WIN32)
    KWebViewSlot* slot = kgtk_find_webview_slot(view_id);
    if (!slot || !slot->web_view) return;
    fn_webkit_web_view_go_forward fn = (fn_webkit_web_view_go_forward)resolve_sym("webkit_web_view_go_forward");
    if (fn) fn(slot->web_view);
#endif
}

bool kgtk_webview_can_go_back(const char* view_id) {
#if !defined(_WIN32)
    KWebViewSlot* slot = kgtk_find_webview_slot(view_id);
    if (!slot || !slot->web_view) return false;
    fn_webkit_web_view_can_go_back fn = (fn_webkit_web_view_can_go_back)resolve_sym("webkit_web_view_can_go_back");
    return fn ? (fn(slot->web_view) != 0) : false;
#else
    return false;
#endif
}

bool kgtk_webview_can_go_forward(const char* view_id) {
#if !defined(_WIN32)
    KWebViewSlot* slot = kgtk_find_webview_slot(view_id);
    if (!slot || !slot->web_view) return false;
    fn_webkit_web_view_can_go_forward fn = (fn_webkit_web_view_can_go_forward)resolve_sym("webkit_web_view_can_go_forward");
    return fn ? (fn(slot->web_view) != 0) : false;
#else
    return false;
#endif
}

void kgtk_webview_execute_script(const char* view_id, const char* script) {
#if !defined(_WIN32)
    KWebViewSlot* slot = kgtk_find_webview_slot(view_id);
    if (!slot || !slot->web_view || !script) return;
    fn_webkit_web_view_execute_script fn = (fn_webkit_web_view_execute_script)resolve_sym("webkit_web_view_execute_script");
    if (fn) {
        fn(slot->web_view, script);
        kgtk_widget_queue_draw(slot->web_view);
    }
#endif
}

const char* kgtk_webview_get_title(const char* view_id) {
#if !defined(_WIN32)
    KWebViewSlot* slot = kgtk_find_webview_slot(view_id);
    if (!slot || !slot->web_view) return "";
    fn_webkit_web_view_get_title fn = (fn_webkit_web_view_get_title)resolve_sym("webkit_web_view_get_title");
    const char* res = fn ? fn(slot->web_view) : NULL;
    return res ? res : "";
#else
    return "";
#endif
}

const char* kgtk_webview_get_uri(const char* view_id) {
#if !defined(_WIN32)
    KWebViewSlot* slot = kgtk_find_webview_slot(view_id);
    if (!slot || !slot->web_view) return "";
    fn_webkit_web_view_get_uri fn = (fn_webkit_web_view_get_uri)resolve_sym("webkit_web_view_get_uri");
    const char* res = fn ? fn(slot->web_view) : NULL;
    if (res && res[0]) return res;
    return slot->last_url ? slot->last_url : "";
#else
    return "";
#endif
}

#if !defined(_WIN32)
static KWebViewInputFocusCallback g_webview_input_focus_handler = NULL;
static void* g_webview_input_focus_user_data = NULL;

typedef struct {
    KWebViewSlot* slot;
    int tap_x;
    int tap_y;
} KWebViewTapCheckCtx;

static int c_webview_scroll_active_input_timeout(void* data) {
    KWebViewSlot* slot = (KWebViewSlot*)data;
    if (!slot || !slot->in_use || !slot->web_view) return 0;
    fn_webkit_web_view_execute_script exec_fn = (fn_webkit_web_view_execute_script)resolve_sym("webkit_web_view_execute_script");
    if (exec_fn) {
        exec_fn(
            slot->web_view,
            "(function(){"
            "var el=window.__kuiActiveInput;"
            "if(!el)return;"
            "try{el.focus();}catch(e){}"
            "if(el.scrollIntoView){try{el.scrollIntoView(true);}catch(e){}}"
            "if(el.getBoundingClientRect){"
            "var r=el.getBoundingClientRect();"
            "if(r.top>120||r.top<24){window.scrollBy(0,r.top-70);}"
            "}"
            "})();"
        );
    }
    return 0;
}

static int c_webview_tap_check_timeout(void* data) {
    KWebViewTapCheckCtx* ctx = (KWebViewTapCheckCtx*)data;
    if (!ctx) return 0;
    KWebViewSlot* slot = ctx->slot;
    int tx = ctx->tap_x;
    int ty = ctx->tap_y;
    free(ctx);

    if (!slot || !slot->in_use || !slot->web_view || !g_webview_input_focus_handler) {
        return 0;
    }

    fn_webkit_web_view_execute_script exec_fn = (fn_webkit_web_view_execute_script)resolve_sym("webkit_web_view_execute_script");
    fn_webkit_web_view_get_title title_fn = (fn_webkit_web_view_get_title)resolve_sym("webkit_web_view_get_title");
    if (!exec_fn || !title_fn) return 0;

    float z = slot->last_zoom > 0.2f ? slot->last_zoom : 1.0f;
    int zx = (int)((float)tx / z + 0.5f);
    int zy = (int)((float)ty / z + 0.5f);

    char check_js[4096];
    snprintf(
        check_js,
        sizeof(check_js),
        "(function(){"
        "function isEd(el){"
        "if(!el)return false;"
        "if(el.isContentEditable)return true;"
        "var tg=(el.tagName||'').toUpperCase();"
        "if(tg==='TEXTAREA')return !el.disabled && !el.readOnly;"
        "if(tg==='INPUT'){"
        "if(el.disabled || el.readOnly)return false;"
        "var t=(el.type||'text').toLowerCase();"
        "return !(t==='button'||t==='submit'||t==='reset'||t==='checkbox'||t==='radio'||t==='file'||t==='image'||t==='hidden'||t==='range'||t==='color');"
        "}"
        "return false;"
        "}"
        "function resolveHit(el){"
        "while(el && el!==document.body){"
        "if(isEd(el))return el;"
        "if((el.tagName||'').toUpperCase()==='LABEL'){"
        "if(el.control && isEd(el.control))return el.control;"
        "var f=el.getAttribute('for');"
        "if(f){var byId=document.getElementById(f);if(isEd(byId))return byId;}"
        "var q=el.querySelector?el.querySelector('input,textarea'):null;"
        "if(isEd(q))return q;"
        "}"
        "el=el.parentElement;"
        "}"
        "return null;"
        "}"
        "function cleanLbl(s){"
        "if(!s)return '';"
        "s=String(s).replace(/[\\r\\n|\\t]+/g,' ').replace(/\\s+/g,' ').replace(/^\\s+|\\s+$/g,'');"
        "s=s.replace(/[*:]+\\s*$/,'').replace(/^\\s+|\\s+$/g,'');"
        "return s;"
        "}"
        "function resolveLbl(el){"
        "var s='';"
        "if(el.id){"
        "var allL=document.getElementsByTagName('label');"
        "for(var i=0;i<allL.length;i++){"
        "if(allL[i].getAttribute('for')===el.id){s=cleanLbl(allL[i].innerText||allL[i].textContent);if(s)return s;}"
        "}"
        "}"
        "var p=el.parentElement;"
        "while(p && p!==document.body){"
        "if((p.tagName||'').toUpperCase()==='LABEL'){"
        "var clone=p.cloneNode(true);"
        "var ins=clone.querySelectorAll?clone.querySelectorAll('input,textarea,select'):[];"
        "for(var j=0;j<ins.length;j++){if(ins[j].parentNode)ins[j].parentNode.removeChild(ins[j]);}"
        "s=cleanLbl(clone.innerText||clone.textContent);"
        "if(s)return s;"
        "break;"
        "}"
        "p=p.parentElement;"
        "}"
        "s=cleanLbl(el.getAttribute('aria-label'));"
        "if(s)return s;"
        "if(el.parentNode){"
        "var txt='';"
        "var cn=el.parentNode.childNodes;"
        "for(var k=0;k<cn.length;k++){"
        "if(cn[k]===el)break;"
        "var nt=cn[k].nodeType;"
        "if(nt===3){txt+=cn[k].nodeValue||' ';}"
        "else if(nt===1){"
        "var ctg=(cn[k].tagName||'').toUpperCase();"
        "if(ctg!=='INPUT'&&ctg!=='TEXTAREA'&&ctg!=='SCRIPT'&&ctg!=='STYLE'){txt+=(cn[k].innerText||cn[k].textContent||' ')+' ';}"
        "}"
        "}"
        "s=cleanLbl(txt);"
        "if(s && s.length<=48)return s;"
        "}"
        "var prev=el.previousElementSibling;"
        "if(prev){"
        "var ptg=(prev.tagName||'').toUpperCase();"
        "if(ptg==='LABEL'||ptg==='SPAN'||ptg==='DIV'||ptg==='P'||ptg==='STRONG'||ptg==='B'){"
        "s=cleanLbl(prev.innerText||prev.textContent);"
        "if(s && s.length<=48)return s;"
        "}"
        "}"
        "return cleanLbl(el.getAttribute('placeholder')||el.name||el.id||'');"
        "}"
        "var el= resolveHit(document.elementFromPoint(%d,%d)) || resolveHit(document.elementFromPoint(%d,%d));"
        "if(!el && isEd(document.activeElement)) el=document.activeElement;"
        "if(!el)return;"
        "try{el.focus();}catch(e){}"
        "if(el.scrollIntoView){try{el.scrollIntoView(true);}catch(e){}}"
        "window.__kuiActiveInput=el;"
        "var tg=(el.tagName||'').toUpperCase();"
        "var t=(el.type||'text').toLowerCase();"
        "var sec=(tg==='INPUT' && t==='password')?'1':'0';"
        "var multi=(tg==='TEXTAREA' || !!el.isContentEditable)?'1':'0';"
        "var num=(tg==='INPUT' && (t==='number'||t==='tel'||el.getAttribute('inputmode')==='numeric'))?'1':'0';"
        "var lbl=resolveLbl(el)||(sec==='1'?'Password':'Web Input');"
        "lbl=String(lbl).replace(/[\\r\\n|]/g,' ').substring(0,48);"
        "var val=el.isContentEditable?(el.innerText||''):(el.value||'');"
        "window.__kuiSavedTitle=document.title||'';"
        "document.title='__KUI_KB__:'+sec+'|'+multi+'|'+num+'|'+lbl+'|'+val;"
        "})();",
        zx, zy, tx, ty
    );

    exec_fn(slot->web_view, check_js);
    const char* raw_title = title_fn(slot->web_view);
    if (raw_title && strncmp(raw_title, "__KUI_KB__:", 11) == 0) {
        char payload[2048];
        strncpy(payload, raw_title + 11, sizeof(payload) - 1);
        payload[sizeof(payload) - 1] = '\0';
        exec_fn(slot->web_view, "if(window.__kuiSavedTitle!==undefined){document.title=window.__kuiSavedTitle;}");

        // Format: sec|multi|num|label|val
        if (strlen(payload) >= 7 && payload[1] == '|' && payload[3] == '|' && payload[5] == '|') {
            bool is_sec = (payload[0] == '1');
            bool is_multi = (payload[2] == '1');
            bool is_num = (payload[4] == '1');
            char* label_start = payload + 6;
            char* bar = strchr(label_start, '|');
            if (bar) {
                *bar = '\0';
                const char* val_start = bar + 1;
                g_webview_input_focus_handler(
                    slot->view_id,
                    label_start[0] ? label_start : "Web Input",
                    val_start,
                    is_sec,
                    is_multi,
                    is_num,
                    g_webview_input_focus_user_data
                );
                fn_g_timeout_add timeout_add = (fn_g_timeout_add)resolve_sym("g_timeout_add");
                if (timeout_add) {
                    timeout_add(140, c_webview_scroll_active_input_timeout, slot);
                }
            }
        }
    }
    return 0;
}

static void c_webview_schedule_tap_input_check(KWidgetRef web_view, int tap_x, int tap_y) {
    if (!web_view || !g_webview_input_focus_handler) return;
    KWebViewSlot* matched = NULL;
    for (int i = 0; i < MAX_WEBVIEW_SLOTS; ++i) {
        if (g_webview_slots[i].in_use && g_webview_slots[i].web_view == web_view) {
            matched = &g_webview_slots[i];
            break;
        }
    }
    if (!matched) return;
    fn_g_timeout_add timeout_fn = (fn_g_timeout_add)resolve_sym("g_timeout_add");
    if (!timeout_fn) return;
    KWebViewTapCheckCtx* ctx = (KWebViewTapCheckCtx*)malloc(sizeof(KWebViewTapCheckCtx));
    if (!ctx) return;
    ctx->slot = matched;
    ctx->tap_x = tap_x;
    ctx->tap_y = tap_y;
    timeout_fn(45, c_webview_tap_check_timeout, ctx);
}
#endif

void kgtk_set_webview_input_focus_handler(KWebViewInputFocusCallback handler, void* user_data) {
#if !defined(_WIN32)
    g_webview_input_focus_handler = handler;
    g_webview_input_focus_user_data = user_data;
#else
    (void)handler;
    (void)user_data;
#endif
}

void kgtk_webview_set_input_text(const char* view_id, const char* text) {
#if !defined(_WIN32)
    KWebViewSlot* slot = kgtk_find_webview_slot(view_id);
    if (!slot || !slot->web_view) return;
    fn_webkit_web_view_execute_script exec_fn = (fn_webkit_web_view_execute_script)resolve_sym("webkit_web_view_execute_script");
    if (!exec_fn) return;
    if (!text) text = "";

    size_t tlen = strlen(text);
    size_t cap = tlen * 2 + 640;
    char* js = (char*)malloc(cap);
    if (!js) return;

    const char* prefix =
        "(function(v){"
        "var el=window.__kuiActiveInput||document.activeElement;"
        "if(!el)return;"
        "if(el.isContentEditable){el.innerText=v;}else{"
        "try{"
        "var p=(el.tagName==='TEXTAREA')?window.HTMLTextAreaElement.prototype:window.HTMLInputElement.prototype;"
        "var d=Object.getOwnPropertyDescriptor(p,'value');"
        "if(d&&d.set){d.set.call(el,v);}else{el.value=v;}"
        "}catch(e){el.value=v;}"
        "}"
        "try{"
        "var e1=document.createEvent('HTMLEvents');e1.initEvent('input',true,true);el.dispatchEvent(e1);"
        "var e2=document.createEvent('HTMLEvents');e2.initEvent('change',true,true);el.dispatchEvent(e2);"
        "}catch(e){}"
        "})(\"";
    size_t pos = strlen(prefix);
    memcpy(js, prefix, pos);

    for (size_t i = 0; i < tlen; ++i) {
        char c = text[i];
        if (c == '\\' || c == '"') {
            js[pos++] = '\\';
            js[pos++] = c;
        } else if (c == '\n') {
            js[pos++] = '\\';
            js[pos++] = 'n';
        } else if (c == '\r') {
            js[pos++] = '\\';
            js[pos++] = 'r';
        } else if (c == '\t') {
            js[pos++] = '\\';
            js[pos++] = 't';
        } else {
            js[pos++] = c;
        }
    }
    memcpy(js + pos, "\");", 4);
    exec_fn(slot->web_view, js);
    free(js);
    kgtk_widget_queue_draw(slot->web_view);
#else
    (void)view_id;
    (void)text;
#endif
}

void kgtk_webview_submit_input(const char* view_id) {
#if !defined(_WIN32)
    KWebViewSlot* slot = kgtk_find_webview_slot(view_id);
    if (!slot || !slot->web_view) return;
    fn_webkit_web_view_execute_script exec_fn = (fn_webkit_web_view_execute_script)resolve_sym("webkit_web_view_execute_script");
    if (!exec_fn) return;
    const char* js =
        "(function(){"
        "var el=window.__kuiActiveInput||document.activeElement;"
        "if(!el)return;"
        "try{"
        "var ev=document.createEvent('HTMLEvents');ev.initEvent('change',true,true);el.dispatchEvent(ev);"
        "}catch(e){}"
        "try{"
        "var t=(el.type||'').toLowerCase();"
        "if(el.form && (t==='search' || el.form.querySelectorAll('input:not([type=hidden]):not([type=submit]):not([type=button])').length<=1)){"
        "el.form.submit();"
        "}"
        "}catch(e){}"
        "})();";
    exec_fn(slot->web_view, js);
    kgtk_widget_queue_draw(slot->web_view);
#else
    (void)view_id;
#endif
}

// --- Fast Asynchronous IPv4 HTTPS Client (libcurl with Connection/TLS/DNS Pooling) ---

#if !defined(_WIN32)
typedef int (*fn_curl_global_init)(long);
typedef void* (*fn_curl_easy_init)(void);
typedef void (*fn_curl_easy_reset)(void*);
typedef int (*fn_curl_easy_setopt)(void*, int, ...);
typedef int (*fn_curl_easy_perform)(void*);
typedef int (*fn_curl_easy_getinfo)(void*, int, ...);
typedef void (*fn_curl_easy_cleanup)(void*);
typedef const char* (*fn_curl_easy_strerror)(int);
typedef void* (*fn_curl_share_init)(void);
typedef int (*fn_curl_share_setopt)(void*, int, ...);
typedef void* (*fn_curl_slist_append)(void*, const char*);
typedef void (*fn_curl_slist_free_all)(void*);

typedef struct _KHttpJob {
    char* url;
    int timeout_seconds;
    KHttpCallback callback;
    void* user_data;
    uint8_t* data;
    size_t len;
    size_t cap;
    int status_code;
    char error_msg[256];
    struct _KHttpJob* next;
} KHttpJob;

#define KHTTP_NUM_WORKERS 6
#define KHTTP_NUM_SHARE_LOCKS 8

typedef struct {
    int initialized;
    int available;
    fn_curl_global_init global_init;
    fn_curl_easy_init easy_init;
    fn_curl_easy_reset easy_reset;
    fn_curl_easy_setopt easy_setopt;
    fn_curl_easy_perform easy_perform;
    fn_curl_easy_getinfo easy_getinfo;
    fn_curl_easy_cleanup easy_cleanup;
    fn_curl_easy_strerror easy_strerror;
    fn_curl_share_init share_init;
    fn_curl_share_setopt share_setopt;
    fn_curl_slist_append slist_append;
    fn_curl_slist_free_all slist_free_all;
    void* share_handle;
    char dns_servers_csv[256];
} KCurlRuntime;

static pthread_mutex_t g_curl_init_mutex = PTHREAD_MUTEX_INITIALIZER;
static pthread_mutex_t g_curl_share_locks[KHTTP_NUM_SHARE_LOCKS] = {
    PTHREAD_MUTEX_INITIALIZER, PTHREAD_MUTEX_INITIALIZER,
    PTHREAD_MUTEX_INITIALIZER, PTHREAD_MUTEX_INITIALIZER,
    PTHREAD_MUTEX_INITIALIZER, PTHREAD_MUTEX_INITIALIZER,
    PTHREAD_MUTEX_INITIALIZER, PTHREAD_MUTEX_INITIALIZER
};
static pthread_mutex_t g_http_queue_mutex = PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t g_http_queue_cond = PTHREAD_COND_INITIALIZER;
static KHttpJob* g_http_queue_head = NULL;
static KHttpJob* g_http_queue_tail = NULL;
static KCurlRuntime g_curl = {0};

static void* resolve_curl_sym_unlocked(const char* name) {
    if (!g_curl_lib) {
        const char* candidates[] = {
            "libcurl.so.4",
            "/usr/lib/libcurl.so.4",
            "libcurl.so",
            "libcurl.4.dylib",
            NULL
        };
        for (int i = 0; candidates[i] != NULL; ++i) {
            g_curl_lib = dlopen(candidates[i], RTLD_LAZY | RTLD_GLOBAL);
            if (g_curl_lib) break;
        }
    }
    if (g_curl_lib) {
        void* sym = dlsym(g_curl_lib, name);
        if (sym) return sym;
    }
    return dlsym(RTLD_DEFAULT, name);
}

static void c_curl_share_lock(void* handle, int data, int access, void* userptr) {
    (void)handle; (void)access; (void)userptr;
    if (data >= 0 && data < KHTTP_NUM_SHARE_LOCKS) {
        pthread_mutex_lock(&g_curl_share_locks[data]);
    }
}

static void c_curl_share_unlock(void* handle, int data, void* userptr) {
    (void)handle; (void)userptr;
    if (data >= 0 && data < KHTTP_NUM_SHARE_LOCKS) {
        pthread_mutex_unlock(&g_curl_share_locks[data]);
    }
}

static void c_csv_append_unique(char* csv, size_t cap, const char* ip) {
    if (!ip || !ip[0]) return;
    size_t ip_len = strlen(ip);
    const char* p = csv;
    while (*p) {
        const char* comma = strchr(p, ',');
        size_t seg_len = comma ? (size_t)(comma - p) : strlen(p);
        if (seg_len == ip_len && strncmp(p, ip, ip_len) == 0) {
            return;
        }
        if (!comma) break;
        p = comma + 1;
    }
    size_t cur_len = strlen(csv);
    size_t needed = cur_len + (cur_len > 0 ? 1 : 0) + ip_len + 1;
    if (needed > cap) return;
    if (cur_len > 0) {
        csv[cur_len++] = ',';
    }
    memcpy(csv + cur_len, ip, ip_len);
    csv[cur_len + ip_len] = '\0';
}

// Inspects /etc/resolv.conf for QEMU SLIRP's 8.8.8.8 c-ares blackhole:
// When QEMU is launched with `-netdev user,dns=8.8.8.8`, libslirp rewrites outgoing
// packets to 8.8.8.8:53 to the host resolver, but _sotranslate_in fails to rewrite
// the source IP back to 8.8.8.8 because 8.8.8.8 is outside 10.0.2.0/24, causing c-ares
// to stall for its full 5000ms timeout before trying the second nameserver.
static void c_init_fast_dns_servers(char* out_csv, size_t cap) {
    out_csv[0] = '\0';
    const char* env_dns = getenv("KINDLEUI_DNS_SERVERS");
    if (env_dns && env_dns[0]) {
        strncpy(out_csv, env_dns, cap - 1);
        out_csv[cap - 1] = '\0';
        return;
    }

    FILE* f = fopen("/etc/resolv.conf", "r");
    int saw_8888 = 0;
    char non_8888[256];
    non_8888[0] = '\0';
    if (f) {
        char line[256];
        while (fgets(line, sizeof(line), f)) {
            char* p = line;
            while (*p == ' ' || *p == '\t') p++;
            if (strncmp(p, "nameserver", 10) != 0) continue;
            p += 10;
            if (*p != ' ' && *p != '\t') continue;
            while (*p == ' ' || *p == '\t') p++;
            char ip[64];
            size_t i = 0;
            while (*p && *p != ' ' && *p != '\t' && *p != '\r' && *p != '\n' && *p != '#' && *p != ';' && i + 1 < sizeof(ip)) {
                ip[i++] = *p++;
            }
            ip[i] = '\0';
            if (i == 0 || strchr(ip, ':') != NULL) continue; // skip empty or IPv6
            if (strcmp(ip, "8.8.8.8") == 0) {
                saw_8888 = 1;
            } else {
                c_csv_append_unique(non_8888, sizeof(non_8888), ip);
            }
        }
        fclose(f);
    }

    if (saw_8888 || non_8888[0] == '\0') {
        if (non_8888[0]) {
            strncpy(out_csv, non_8888, cap - 1);
            out_csv[cap - 1] = '\0';
        }
        c_csv_append_unique(out_csv, cap, "1.1.1.1");
        c_csv_append_unique(out_csv, cap, "1.0.0.1");
        c_csv_append_unique(out_csv, cap, "8.8.4.4");
        c_csv_append_unique(out_csv, cap, "8.8.8.8");

        if (!saw_8888 && non_8888[0] == '\0') {
            FILE* wf = fopen("/tmp/resolv.conf", "w");
            if (wf) {
                fprintf(wf, "nameserver 1.1.1.1\nnameserver 8.8.4.4\n");
                fclose(wf);
            }
        }
    }
}

static size_t c_curl_write_cb(const void* ptr, size_t size, size_t nmemb, void* userdata) {
    size_t total = size * nmemb;
    if (total == 0 || !ptr || !userdata) return total;
    KHttpJob* job = (KHttpJob*)userdata;
    if (job->len + total + 1 > job->cap) {
        size_t new_cap = job->cap == 0 ? 16384 : job->cap * 2;
        while (new_cap < job->len + total + 1) {
            new_cap *= 2;
        }
        uint8_t* next = (uint8_t*)realloc(job->data, new_cap);
        if (!next) return 0;
        job->data = next;
        job->cap = new_cap;
    }
    memcpy(job->data + job->len, ptr, total);
    job->len += total;
    job->data[job->len] = 0;
    return total;
}

static void c_http_job_finish_main(void* data) {
    KHttpJob* job = (KHttpJob*)data;
    if (!job) return;
    if (job->callback) {
        job->callback(
            job->status_code,
            job->data,
            (int)job->len,
            job->error_msg[0] ? job->error_msg : NULL,
            job->user_data
        );
    }
    if (job->url) free(job->url);
    if (job->data) free(job->data);
    free(job);
}

static void c_configure_curl_handle(void* curl, KHttpJob* job) {
    fn_curl_easy_setopt easy_setopt = g_curl.easy_setopt;
    if (g_curl.easy_reset) {
        g_curl.easy_reset(curl);
    }

    long timeout_sec = job->timeout_seconds > 0 ? (long)job->timeout_seconds : 8L;
    long conn_timeout = timeout_sec < 4L ? timeout_sec : 4L;

    easy_setopt(curl, 10002 /* CURLOPT_URL */, job->url);
    easy_setopt(curl, 10018 /* CURLOPT_USERAGENT */, "KindleUI/1.0 (https://github.com/kindlemodding/KindleUI; contact@kindlemodding.org; Kindle E-Ink)");
    easy_setopt(curl, 20011 /* CURLOPT_WRITEFUNCTION */, (void*)c_curl_write_cb);
    easy_setopt(curl, 10001 /* CURLOPT_WRITEDATA */, (void*)job);
    easy_setopt(curl, 52    /* CURLOPT_FOLLOWLOCATION */, 1L);
    easy_setopt(curl, 68    /* CURLOPT_MAXREDIRS */, 5L);
    easy_setopt(curl, 99    /* CURLOPT_NOSIGNAL */, 1L);
    easy_setopt(curl, 113   /* CURLOPT_IPRESOLVE */, 1L /* CURL_IPRESOLVE_V4 */);
    easy_setopt(curl, 78    /* CURLOPT_CONNECTTIMEOUT */, conn_timeout);
    easy_setopt(curl, 13    /* CURLOPT_TIMEOUT */, timeout_sec);
    easy_setopt(curl, 64    /* CURLOPT_SSL_VERIFYPEER */, 0L);
    easy_setopt(curl, 81    /* CURLOPT_SSL_VERIFYHOST */, 0L);
    // Prevent OpenSSL from loading & parsing 226KB /etc/ssl/certs/ca-certificates.crt on every new SSL_CTX
    easy_setopt(curl, 10065 /* CURLOPT_CAINFO */, (const char*)NULL);
    easy_setopt(curl, 10097 /* CURLOPT_CAPATH */, (const char*)NULL);
    // Keep DNS, TCP, and TLS sessions warm
    easy_setopt(curl, 92    /* CURLOPT_DNS_CACHE_TIMEOUT */, 600L);
    easy_setopt(curl, 121   /* CURLOPT_TCP_NODELAY */, 1L);
    easy_setopt(curl, 213   /* CURLOPT_TCP_KEEPALIVE */, 1L);
    easy_setopt(curl, 98    /* CURLOPT_BUFFERSIZE */, 65536L);
    easy_setopt(curl, 10102 /* CURLOPT_ACCEPT_ENCODING */, "");

    easy_setopt(curl, 58    /* CURLOPT_AUTOREFERER */, 1L);
    easy_setopt(curl, 10031 /* CURLOPT_COOKIEFILE */, "/var/local/kindleui_cookies.txt");
    easy_setopt(curl, 10082 /* CURLOPT_COOKIEJAR */, "/var/local/kindleui_cookies.txt");
    if (g_curl.share_handle) {
        easy_setopt(curl, 10100 /* CURLOPT_SHARE */, g_curl.share_handle);
    }
    if (g_curl.dns_servers_csv[0] != '\0') {
        easy_setopt(curl, 10211 /* CURLOPT_DNS_SERVERS */, g_curl.dns_servers_csv);
    }
}

static void c_execute_http_job(void** io_curl, KHttpJob* job) {
    if (!job) return;
    void* curl = *io_curl;
    if (!curl && g_curl.easy_init) {
        curl = g_curl.easy_init();
        *io_curl = curl;
    }
    if (!curl || !g_curl.easy_setopt || !g_curl.easy_perform) {
        snprintf(job->error_msg, sizeof(job->error_msg), "libcurl unavailable");
        kgtk_schedule_idle(c_http_job_finish_main, job);
        return;
    }

    c_configure_curl_handle(curl, job);
    int res = g_curl.easy_perform(curl);

    // If a pooled connection was closed by the remote server or hit a transient error,
    // recreate the easy handle once and retry immediately.
    if (res != 0 && res != 28 /* CURLE_OPERATION_TIMEDOUT */) {
        job->len = 0;
        if (job->data) job->data[0] = 0;
        if (g_curl.easy_cleanup) {
            g_curl.easy_cleanup(curl);
        }
        curl = g_curl.easy_init ? g_curl.easy_init() : NULL;
        *io_curl = curl;
        if (curl) {
            c_configure_curl_handle(curl, job);
            res = g_curl.easy_perform(curl);
        }
    }

    if (res == 0) {
        long http_code = 200;
        if (g_curl.easy_getinfo) {
            g_curl.easy_getinfo(curl, 0x200002 /* CURLINFO_RESPONSE_CODE */, &http_code);
        }
        if (http_code == 429 && curl) {
            usleep(650000);
            job->len = 0;
            if (job->data) job->data[0] = 0;
            c_configure_curl_handle(curl, job);
            if (g_curl.easy_perform(curl) == 0 && g_curl.easy_getinfo) {
                g_curl.easy_getinfo(curl, 0x200002 /* CURLINFO_RESPONSE_CODE */, &http_code);
            }
        }
        job->status_code = (int)http_code;
        job->error_msg[0] = '\0';
    } else {
        job->status_code = 0;
        const char* err = g_curl.easy_strerror ? g_curl.easy_strerror(res) : "curl perform error";
        snprintf(job->error_msg, sizeof(job->error_msg), "%s (code %d)", err ? err : "error", res);
    }

    // If easy_reset is unavailable on an older libcurl, clean up and recreate next time
    if (!g_curl.easy_reset && g_curl.easy_cleanup && *io_curl) {
        g_curl.easy_cleanup(*io_curl);
        *io_curl = NULL;
    }

    kgtk_schedule_idle(c_http_job_finish_main, job);
}

static void* c_http_pool_worker(void* arg) {
    (void)arg;
    void* worker_curl = g_curl.easy_init ? g_curl.easy_init() : NULL;
    for (;;) {
        pthread_mutex_lock(&g_http_queue_mutex);
        while (!g_http_queue_head) {
            pthread_cond_wait(&g_http_queue_cond, &g_http_queue_mutex);
        }
        KHttpJob* job = g_http_queue_head;
        g_http_queue_head = job->next;
        if (!g_http_queue_head) {
            g_http_queue_tail = NULL;
        }
        job->next = NULL;
        pthread_mutex_unlock(&g_http_queue_mutex);

        c_execute_http_job(&worker_curl, job);
    }
    return NULL;
}

static bool khttp_ensure_initialized(void) {
    pthread_mutex_lock(&g_curl_init_mutex);
    if (g_curl.initialized) {
        bool ok = g_curl.available != 0;
        pthread_mutex_unlock(&g_curl_init_mutex);
        return ok;
    }
    g_curl.initialized = 1;

    g_curl.global_init = (fn_curl_global_init)resolve_curl_sym_unlocked("curl_global_init");
    g_curl.easy_init = (fn_curl_easy_init)resolve_curl_sym_unlocked("curl_easy_init");
    g_curl.easy_reset = (fn_curl_easy_reset)resolve_curl_sym_unlocked("curl_easy_reset");
    g_curl.easy_setopt = (fn_curl_easy_setopt)resolve_curl_sym_unlocked("curl_easy_setopt");
    g_curl.easy_perform = (fn_curl_easy_perform)resolve_curl_sym_unlocked("curl_easy_perform");
    g_curl.easy_getinfo = (fn_curl_easy_getinfo)resolve_curl_sym_unlocked("curl_easy_getinfo");
    g_curl.easy_cleanup = (fn_curl_easy_cleanup)resolve_curl_sym_unlocked("curl_easy_cleanup");
    g_curl.easy_strerror = (fn_curl_easy_strerror)resolve_curl_sym_unlocked("curl_easy_strerror");
    g_curl.share_init = (fn_curl_share_init)resolve_curl_sym_unlocked("curl_share_init");
    g_curl.share_setopt = (fn_curl_share_setopt)resolve_curl_sym_unlocked("curl_share_setopt");
    g_curl.slist_append = (fn_curl_slist_append)resolve_curl_sym_unlocked("curl_slist_append");
    g_curl.slist_free_all = (fn_curl_slist_free_all)resolve_curl_sym_unlocked("curl_slist_free_all");

    if (!g_curl.easy_init || !g_curl.easy_setopt || !g_curl.easy_perform || !g_curl.easy_cleanup) {
        g_curl.available = 0;
        pthread_mutex_unlock(&g_curl_init_mutex);
        return false;
    }

    if (g_curl.global_init) {
        g_curl.global_init(3L /* CURL_GLOBAL_DEFAULT */);
    }

    c_init_fast_dns_servers(g_curl.dns_servers_csv, sizeof(g_curl.dns_servers_csv));

    if (g_curl.share_init && g_curl.share_setopt) {
        void* sh = g_curl.share_init();
        if (sh) {
            g_curl.share_setopt(sh, 3 /* CURLSHOPT_LOCKFUNC */, (void*)c_curl_share_lock);
            g_curl.share_setopt(sh, 4 /* CURLSHOPT_UNLOCKFUNC */, (void*)c_curl_share_unlock);
            g_curl.share_setopt(sh, 1 /* CURLSHOPT_SHARE */, 2L /* CURL_LOCK_DATA_COOKIE */);
            g_curl.share_setopt(sh, 1 /* CURLSHOPT_SHARE */, 3L /* CURL_LOCK_DATA_DNS */);
            g_curl.share_setopt(sh, 1 /* CURLSHOPT_SHARE */, 4L /* CURL_LOCK_DATA_SSL_SESSION */);
            g_curl.share_setopt(sh, 1 /* CURLSHOPT_SHARE */, 5L /* CURL_LOCK_DATA_CONNECT */);
            g_curl.share_handle = sh;
        }
    }

    int started_workers = 0;
    for (int i = 0; i < KHTTP_NUM_WORKERS; ++i) {
        pthread_t tid;
        if (pthread_create(&tid, NULL, c_http_pool_worker, NULL) == 0) {
            pthread_detach(tid);
            started_workers++;
        }
    }

    g_curl.available = (started_workers > 0) ? 1 : 0;
    pthread_mutex_unlock(&g_curl_init_mutex);
    return g_curl.available != 0;
}

#endif

bool khttp_get_async(
    const char* url,
    int timeout_seconds,
    KHttpCallback callback,
    void* user_data
) {
#if !defined(_WIN32)
    if (!url || !url[0] || !callback) return false;
    if (!khttp_ensure_initialized()) return false;

    KHttpJob* job = (KHttpJob*)calloc(1, sizeof(KHttpJob));
    if (!job) return false;
    job->url = strdup(url);
    if (!job->url) {
        free(job);
        return false;
    }
    job->timeout_seconds = timeout_seconds;
    job->callback = callback;
    job->user_data = user_data;
    job->next = NULL;

    pthread_mutex_lock(&g_http_queue_mutex);
    if (g_http_queue_tail) {
        g_http_queue_tail->next = job;
        g_http_queue_tail = job;
    } else {
        g_http_queue_head = job;
        g_http_queue_tail = job;
    }
    pthread_cond_signal(&g_http_queue_cond);
    pthread_mutex_unlock(&g_http_queue_mutex);
    return true;
#else
    (void)url; (void)timeout_seconds; (void)callback; (void)user_data;
    return false;
#endif
}

#if defined(_WIN32)
KWidgetRef kgtk_take_suppressed_redraw_widget(void) { return NULL; }
#endif
