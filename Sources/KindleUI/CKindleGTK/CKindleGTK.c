#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif
#include "CKindleGTK.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <dlfcn.h>
#include <pthread.h>
#include <unistd.h>
#include <ctype.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>

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

    uint32_t idx = hash & mask;
    for (uint32_t probes = 0; probes < KGTK_SYM_CACHE_SIZE; ++probes) {
        KSymCacheEntry* e = &g_sym_cache[idx];
        const char* existing = __atomic_load_n(&e->name, __ATOMIC_ACQUIRE);
        if (!existing) break;
        if (strcmp(existing, name) == 0) {
            return e->sym;
        }
        idx = (idx + 1) & mask;
    }

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
                __atomic_store_n(&e->name, copy, __ATOMIC_RELEASE);
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

bool kgtk_init(void) {
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
}

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

static void kgtk_drain_idle_tasks(void) {
    if (g_draining_idle_tasks) {
        // Prevent re-entrant draining; the active outer loop will pick up newly queued tasks.
        return;
    }
    g_draining_idle_tasks = 1;

    for (;;) {
        pthread_mutex_lock(&g_idle_mutex);
        KIdleTask* list = g_idle_head;
        g_idle_head = NULL;
        g_idle_tail = NULL;
        if (!list) {
            g_has_pending_idle = 0;
            pthread_mutex_unlock(&g_idle_mutex);
            break;
        }
        pthread_mutex_unlock(&g_idle_mutex);

        while (list) {
            KIdleTask* task = list;
            list = task->next;
            if (task->callback) {
                task->callback(task->user_data);
            }
            free(task);
        }
    }
    g_draining_idle_tasks = 0;
}

static int c_idle_trampoline(void* data) {
    (void)data;
    if (g_draining_idle_tasks) {
        return 1; // G_SOURCE_CONTINUE until the active drain completes
    }
    kgtk_drain_idle_tasks();
    return 0; // G_SOURCE_REMOVE (one-shot)
}

void kgtk_main(void) {
    kgtk_drain_idle_tasks();
    fn_gtk_main fn = (fn_gtk_main)resolve_sym("gtk_main");
    if (fn) fn();
}

void kgtk_main_quit(void) {
    fn_gtk_main_quit fn = (fn_gtk_main_quit)resolve_sym("gtk_main_quit");
    if (fn) fn();
}

void kgtk_reset_scroll_position(void) {
    g_last_scroll_y = 0.0;
    g_pending_scroll_restore = 0.0;
    g_scroll_reset_requested = true;
}

void kgtk_set_scroll_position(double y) {
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
}

double kgtk_get_scroll_position(void) {
    return g_last_scroll_y;
}

static void* g_root_gdk_window = NULL;

void kgtk_window_freeze_updates(KWidgetRef window) {
    if (!window || g_window_freeze_depth > 0) return;
    fn_gtk_widget_get_window get_win = (fn_gtk_widget_get_window)resolve_sym("gtk_widget_get_window");
    fn_gdk_window_freeze_updates freeze_fn = (fn_gdk_window_freeze_updates)resolve_sym("gdk_window_freeze_updates");
    if (get_win && freeze_fn) {
        void* gdk_win = get_win(window);
        if (gdk_win) {
            g_root_gdk_window = gdk_win;
            freeze_fn(gdk_win);
            g_window_freeze_depth = 1;
        }
    }
}

void kgtk_window_thaw_updates(KWidgetRef window) {
    if (!window || g_window_freeze_depth <= 0) return;
    g_window_freeze_depth = 0;
    fn_gtk_widget_get_window get_win = (fn_gtk_widget_get_window)resolve_sym("gtk_widget_get_window");
    fn_gdk_window_thaw_updates thaw_fn = (fn_gdk_window_thaw_updates)resolve_sym("gdk_window_thaw_updates");
    if (get_win && thaw_fn) {
        void* gdk_win = get_win(window);
        if (gdk_win) {
            thaw_fn(gdk_win);
        }
    }
}

static bool g_label_wrap_queued_resize = false;

void kgtk_flush_updates(KWidgetRef window) {
    fn_gtk_container_check_resize check_resize = (fn_gtk_container_check_resize)resolve_sym("gtk_container_check_resize");
    fn_gtk_bin_get_child get_child = (fn_gtk_bin_get_child)resolve_sym("gtk_bin_get_child");
    fn_gdk_window_process_all_updates process_updates = (fn_gdk_window_process_all_updates)resolve_sym("gdk_window_process_all_updates");
    fn_gdk_flush flush_fn = (fn_gdk_flush)resolve_sym("gdk_flush");
    fn_gtk_scrolled_window_get_vadjustment get_vadj = (fn_gtk_scrolled_window_get_vadjustment)resolve_sym("gtk_scrolled_window_get_vadjustment");
    fn_gtk_adjustment_set_value set_val = (fn_gtk_adjustment_set_value)resolve_sym("gtk_adjustment_set_value");
    fn_gtk_adjustment_get_upper get_upper = (fn_gtk_adjustment_get_upper)resolve_sym("gtk_adjustment_get_upper");
    fn_gtk_adjustment_get_page_size get_page = (fn_gtk_adjustment_get_page_size)resolve_sym("gtk_adjustment_get_page_size");

    double saved_scroll_y = g_pending_scroll_restore > 0.0 ? g_pending_scroll_restore : g_last_scroll_y;
    g_scroll_tracking_enabled = false;

    if (check_resize && window) {
        for (int pass = 0; pass < 4; ++pass) {
            g_label_wrap_queued_resize = false;
            check_resize(window);
            if (g_active_scrolled_window && get_child) {
                KWidgetRef vp = get_child(g_active_scrolled_window);
                if (vp) check_resize(vp);
                check_resize(g_active_scrolled_window);
            }
            if (g_active_modal_scrolled_window && get_child) {
                KWidgetRef vp = get_child(g_active_modal_scrolled_window);
                if (vp) check_resize(vp);
                check_resize(g_active_modal_scrolled_window);
            }
            if (!g_label_wrap_queued_resize) break;
        }
    }

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
            if (check_resize && g_active_scrolled_window && target > 0.0) {
                check_resize(g_active_scrolled_window);
            }
        }
    } else {
        g_last_scroll_y = saved_scroll_y;
    }

    kgtk_widget_queue_draw(window);
    kgtk_window_thaw_updates(window);

    if (process_updates) {
        process_updates();
    }
    if (flush_fn) {
        flush_fn();
    }
    g_scroll_tracking_enabled = true;
}

void kgtk_flush_live_drag(KWidgetRef window) {
    fn_gtk_container_check_resize check_resize = (fn_gtk_container_check_resize)resolve_sym("gtk_container_check_resize");
    fn_gtk_bin_get_child get_child = (fn_gtk_bin_get_child)resolve_sym("gtk_bin_get_child");
    fn_gdk_window_process_all_updates process_updates = (fn_gdk_window_process_all_updates)resolve_sym("gdk_window_process_all_updates");
    fn_gdk_flush flush_fn = (fn_gdk_flush)resolve_sym("gdk_flush");

    if (check_resize && window) {
        for (int pass = 0; pass < 4; ++pass) {
            g_label_wrap_queued_resize = false;
            if (g_active_scrolled_window && get_child) {
                KWidgetRef vp = get_child(g_active_scrolled_window);
                if (vp) check_resize(vp);
            }
            if (g_active_modal_scrolled_window && get_child) {
                KWidgetRef vp = get_child(g_active_modal_scrolled_window);
                if (vp) check_resize(vp);
            }
            check_resize(window);
            if (!g_label_wrap_queued_resize) break;
        }
    }
    kgtk_window_thaw_updates(window);
    if (process_updates) {
        process_updates();
    }
    if (flush_fn) {
        flush_fn();
    }
}

void kgtk_schedule_idle(KIdleCallback callback, void* user_data) {
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
}

bool kgtk_is_slider_dragging(void) {
    return g_slider_dragging || g_gesture_dragging || g_canvas_dragging || (g_scroll_drag.active && g_scroll_drag.threshold_crossed);
}

void kgtk_reset_slider_dragging(void) {
    g_slider_dragging = false;
    g_gesture_dragging = false;
    g_canvas_dragging = false;
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
    fn_gtk_window_new fn = (fn_gtk_window_new)resolve_sym("gtk_window_new");
    if (fn) return fn(window_type);
    return NULL;
}

void kgtk_window_set_title(KWidgetRef window, const char* title) {
    fn_gtk_window_set_title fn = (fn_gtk_window_set_title)resolve_sym("gtk_window_set_title");
    if (fn && window) fn(window, title);
}

typedef void (*fn_gtk_window_set_resizable)(KWidgetRef, int);

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

void kgtk_window_set_default_size(KWidgetRef window, int width, int height) {
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
}

void kgtk_window_set_position(KWidgetRef window, int position) {
    fn_gtk_window_set_position fn = (fn_gtk_window_set_position)resolve_sym("gtk_window_set_position");
    if (fn && window) fn(window, position);
}

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

void kgtk_set_global_key_handler(KWindowKeyCallback handler, void* user_data) {
    g_global_key_handler = handler;
    g_global_key_user_data = user_data;
}

void kgtk_window_connect_quit_keys(KWidgetRef window, KIdleCallback on_quit, void* user_data) {
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
}

KWidgetRef kgtk_vbox_new(bool homogeneous, int spacing) {
    fn_gtk_box_new_2 fn = (fn_gtk_box_new_2)resolve_sym("gtk_vbox_new");
    if (fn) return fn(homogeneous ? 1 : 0, kgtk_scale_px(spacing));
    return NULL;
}

KWidgetRef kgtk_hbox_new(bool homogeneous, int spacing) {
    fn_gtk_box_new_2 fn = (fn_gtk_box_new_2)resolve_sym("gtk_hbox_new");
    if (fn) return fn(homogeneous ? 1 : 0, kgtk_scale_px(spacing));
    return NULL;
}

void kgtk_box_pack_start(KWidgetRef box, KWidgetRef child, bool expand, bool fill, int padding) {
    fn_gtk_box_pack_start fn = (fn_gtk_box_pack_start)resolve_sym("gtk_box_pack_start");
    if (fn && box && child) fn(box, child, expand ? 1 : 0, fill ? 1 : 0, (unsigned int)kgtk_scale_px(padding));
}

void kgtk_container_add(KWidgetRef container, KWidgetRef widget) {
    fn_gtk_container_add fn = (fn_gtk_container_add)resolve_sym("gtk_container_add");
    if (fn && container && widget) fn(container, widget);
}

static void kgtk_container_remove(KWidgetRef container, KWidgetRef widget) {
    fn_gtk_container_remove fn = (fn_gtk_container_remove)resolve_sym("gtk_container_remove");
    if (fn && container && widget) fn(container, widget);
}

void kgtk_container_clear(KWidgetRef container) {
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
}

KWidgetRef kgtk_alignment_new(float xalign, float yalign, float xscale, float yscale) {
    fn_gtk_alignment_new fn = (fn_gtk_alignment_new)resolve_sym("gtk_alignment_new");
    if (fn) {
        return fn(xalign, yalign, xscale, yscale);
    }
    return NULL;
}

void kgtk_alignment_set_padding(KWidgetRef alignment, int top, int bottom, int left, int right) {
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
}

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

KWidgetRef kgtk_frozen_scrolled_view_new(uint8_t bg_gray) {
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
}

void kgtk_frozen_scrolled_view_add(KWidgetRef frozen_view, KWidgetRef child) {
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
}

KWidgetRef kgtk_scrolled_window_new(void) {
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
    return NULL;
}

void kgtk_scrolled_window_set_show_indicators(KWidgetRef scrolled_window, bool show_indicators) {
    fn_gtk_scrolled_window_set_policy policy_fn = (fn_gtk_scrolled_window_set_policy)resolve_sym("gtk_scrolled_window_set_policy");
    if (policy_fn && scrolled_window) {
        // Horizontal: GTK_POLICY_NEVER (2), Vertical: AUTOMATIC (1) or NEVER (2)
        policy_fn(scrolled_window, 2, show_indicators ? 1 : 2);
    }
}

void kgtk_scrolled_window_set_bg_gray(KWidgetRef scrolled_window, uint8_t gray_level) {
    if (!scrolled_window) return;
    kgtk_widget_modify_bg_gray(scrolled_window, 0, gray_level);
    fn_gtk_bin_get_child get_child = (fn_gtk_bin_get_child)resolve_sym("gtk_bin_get_child");
    if (get_child) {
        KWidgetRef vp = get_child(scrolled_window);
        if (vp) {
            kgtk_widget_modify_bg_gray(vp, 0, gray_level);
        }
    }
}

void kgtk_scrolled_window_add_with_viewport(KWidgetRef scrolled_window, KWidgetRef child) {
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
}

KWidgetRef kgtk_event_box_new(void) {
    fn_gtk_event_box_new fn = (fn_gtk_event_box_new)resolve_sym("gtk_event_box_new");
    if (fn) return fn();
    return NULL;
}

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

KWidgetRef kgtk_zstack_new(void) {
    fn_gtk_table_new fn = (fn_gtk_table_new)resolve_sym("gtk_table_new");
    fn_g_signal_connect_data conn = (fn_g_signal_connect_data)resolve_sym("g_signal_connect_data");
    if (fn) {
        KWidgetRef tbl = fn(1, 1, 0);
        if (tbl && conn) {
            conn(tbl, "size-request", (void*)c_zstack_clamp_size_request, NULL, NULL, 1);
        }
        return tbl;
    }
    return kgtk_vbox_new(false, 0);
}

void kgtk_zstack_add(KWidgetRef zstack, KWidgetRef child) {
    fn_gtk_table_attach attach = (fn_gtk_table_attach)resolve_sym("gtk_table_attach");
    if (attach && zstack && child) {
        // GTK_EXPAND | GTK_SHRINK | GTK_FILL = 1 | 2 | 4 = 7
        attach(zstack, child, 0, 1, 0, 1, 7, 7, 0, 0);
        return;
    }
    if (zstack && child) {
        kgtk_box_pack_start(zstack, child, true, true, 0);
    }
}

void kgtk_widget_set_sensitive(KWidgetRef widget, bool sensitive) {
    fn_gtk_widget_set_sensitive fn = (fn_gtk_widget_set_sensitive)resolve_sym("gtk_widget_set_sensitive");
    if (fn && widget) fn(widget, sensitive ? 1 : 0);
}

KWidgetRef kgtk_label_new(const char* text) {
    fn_gtk_label_new fn = (fn_gtk_label_new)resolve_sym("gtk_label_new");
    if (fn) return fn(text);
    return NULL;
}

void kgtk_label_set_text(KWidgetRef label, const char* text) {
    fn_gtk_label_set_text fn = (fn_gtk_label_set_text)resolve_sym("gtk_label_set_text");
    if (fn && label) fn(label, text);
}

void kgtk_label_set_markup(KWidgetRef label, const char* markup) {
    fn_gtk_label_set_markup fn = (fn_gtk_label_set_markup)resolve_sym("gtk_label_set_markup");
    if (fn && label) fn(label, markup);
}

typedef void* (KGTK_ABI *fn_gtk_label_get_layout)(KWidgetRef);
typedef void (KGTK_ABI *fn_pango_layout_set_width)(void*, int);
typedef void (KGTK_ABI *fn_pango_layout_set_wrap)(void*, int);
typedef int (KGTK_ABI *fn_pango_layout_get_width)(void*);
typedef void (KGTK_ABI *fn_pango_layout_get_pixel_size)(void*, int*, int*);
typedef void (KGTK_ABI *fn_gtk_widget_queue_resize)(KWidgetRef);

static int c_label_target_pango_width(KWidgetRef widget) {
    fn_g_object_get_data get_data = (fn_g_object_get_data)resolve_sym("g_object_get_data");
    int saved_w = get_data ? (int)(intptr_t)get_data(widget, "kindle-label-wrap-w") : 0;
    int wrap_w = saved_w;
    if (wrap_w <= 60) {
        wrap_w = kgtk_scale_px(1720);
        if (wrap_w <= 60) wrap_w = 1120;
    }
    int pad_deduct = (saved_w > 60) ? 2 : 6;
    return (wrap_w - pad_deduct) * 1024;
}

static void c_label_wrap_size_request_pre(KWidgetRef widget, KGtkRequisition* req, void* data) {
    (void)req;
    (void)data;
    if (!widget) return;
    fn_gtk_label_get_layout get_layout = (fn_gtk_label_get_layout)resolve_sym("gtk_label_get_layout");
    fn_pango_layout_set_width set_width = (fn_pango_layout_set_width)resolve_sym("pango_layout_set_width");
    fn_pango_layout_get_width get_width = (fn_pango_layout_get_width)resolve_sym("pango_layout_get_width");
    fn_pango_layout_set_wrap set_wrap = (fn_pango_layout_set_wrap)resolve_sym("pango_layout_set_wrap");
    if (!get_layout || !set_width) return;

    void* layout = get_layout(widget);
    if (!layout) return;
    if (set_wrap) set_wrap(layout, 0); // PANGO_WRAP_WORD

    int target_pango_w = c_label_target_pango_width(widget);
    if (!get_width || get_width(layout) != target_pango_w) {
        set_width(layout, target_pango_w);
    }
}

static void c_label_wrap_size_request(KWidgetRef widget, KGtkRequisition* req, void* data) {
    (void)data;
    if (!widget || !req) return;
    fn_gtk_label_get_layout get_layout = (fn_gtk_label_get_layout)resolve_sym("gtk_label_get_layout");
    fn_pango_layout_set_width set_width = (fn_pango_layout_set_width)resolve_sym("pango_layout_set_width");
    fn_pango_layout_get_width get_width = (fn_pango_layout_get_width)resolve_sym("pango_layout_get_width");
    fn_pango_layout_set_wrap set_wrap = (fn_pango_layout_set_wrap)resolve_sym("pango_layout_set_wrap");
    fn_pango_layout_get_pixel_size get_pixel_size = (fn_pango_layout_get_pixel_size)resolve_sym("pango_layout_get_pixel_size");
    if (!get_layout || !set_width || !get_pixel_size) return;

    void* layout = get_layout(widget);
    if (!layout) return;
    if (set_wrap) set_wrap(layout, 0); // PANGO_WRAP_WORD

    int target_pango_w = c_label_target_pango_width(widget);
    if (!get_width || get_width(layout) != target_pango_w) {
        set_width(layout, target_pango_w);
    }

    int lw = 0, lh = 0;
    get_pixel_size(layout, &lw, &lh);
    req->width = kgtk_scale_px(120);
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
    if (diff_w > 2) {
        if (set_data) {
            set_data(widget, "kindle-label-wrap-w", (void*)(intptr_t)alloc->width, NULL);
        }
        if (get_pixel_size && queue_resize) {
            int lw = 0, lh = 0;
            get_pixel_size(layout, &lw, &lh);
            if (lh > 0 && (alloc->height < lh + 2 || alloc->height > lh + 8)) {
                g_label_wrap_queued_resize = true;
                queue_resize(widget);
            }
        }
    }
}

void kgtk_label_set_line_wrap(KWidgetRef label, bool wrap) {
    fn_gtk_label_set_line_wrap fn = (fn_gtk_label_set_line_wrap)resolve_sym("gtk_label_set_line_wrap");
    if (fn && label) fn(label, wrap ? 1 : 0);
    if (wrap && label) {
        fn_g_signal_connect_data conn = (fn_g_signal_connect_data)resolve_sym("g_signal_connect_data");
        if (conn) {
            conn(label, "size-request", (void*)c_label_wrap_size_request_pre, NULL, NULL, 0);
            conn(label, "size-request", (void*)c_label_wrap_size_request, NULL, NULL, 1);
            conn(label, "size-allocate", (void*)c_label_wrap_size_allocate, NULL, NULL, 0);
        }
    }
}

void kgtk_label_set_justify(KWidgetRef label, int justify) {
    fn_gtk_label_set_justify fn = (fn_gtk_label_set_justify)resolve_sym("gtk_label_set_justify");
    if (fn && label) fn(label, justify);
}

void kgtk_misc_set_alignment(KWidgetRef misc, float xalign, float yalign) {
    fn_gtk_misc_set_alignment fn = (fn_gtk_misc_set_alignment)resolve_sym("gtk_misc_set_alignment");
    if (fn && misc) fn(misc, xalign, yalign);
}

KWidgetRef kgtk_entry_new(void) {
    fn_gtk_entry_new fn = (fn_gtk_entry_new)resolve_sym("gtk_entry_new");
    if (fn) return fn();
    return NULL;
}

void kgtk_entry_set_text(KWidgetRef entry, const char* text) {
    fn_gtk_entry_set_text fn = (fn_gtk_entry_set_text)resolve_sym("gtk_entry_set_text");
    if (fn && entry && text) fn(entry, text);
}

const char* kgtk_entry_get_text(KWidgetRef entry) {
    fn_gtk_entry_get_text fn = (fn_gtk_entry_get_text)resolve_sym("gtk_entry_get_text");
    if (fn && entry) return fn(entry);
    return "";
}

static uint8_t kgtk_quantize_eink_gray(uint8_t gray);

static KWidgetRef kgtk_image_new_from_file(const char* filename) {
    fn_gtk_image_new_from_file fn = (fn_gtk_image_new_from_file)resolve_sym("gtk_image_new_from_file");
    if (fn && filename) return fn(filename);
    return NULL;
}

KWidgetRef kgtk_image_new_from_file_scaled(const char* filename, int max_width, int max_height) {
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
    return kgtk_image_new_from_file(filename);
}

// --- Interactive E-Ink Drawing Canvas (GtkDrawingArea) ---

KWidgetRef kgtk_drawing_area_new(void) {
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
    return NULL;
}

KWidgetRef kgtk_nowindow_canvas_new(void) {
    KWidgetRef align = kgtk_alignment_new(0.0, 0.0, 1.0, 1.0);
    fn_g_object_set_data_full set_data = (fn_g_object_set_data_full)resolve_sym("g_object_set_data_full");
    if (align && set_data) {
        set_data(align, "kindle-nowindow-canvas", (void*)1, NULL);
    }
    return align;
}

static KGtkAllocation g_canvas_expose_area = { 0, 0, 0, 0 };
static bool g_has_canvas_expose_area = false;

void kgtk_widget_get_size(KWidgetRef widget, int* out_width, int* out_height) {
    int w = 0, h = 0;
    fn_gtk_widget_get_allocation get_alloc = (fn_gtk_widget_get_allocation)resolve_sym("gtk_widget_get_allocation");
    if (get_alloc && widget) {
        KGtkAllocation alloc = { 0, 0, 0, 0 };
        get_alloc(widget, &alloc);
        w = alloc.width;
        h = alloc.height;
    }
    if (out_width) *out_width = w;
    if (out_height) *out_height = h;
}

void kgtk_widget_queue_draw_rect(KWidgetRef widget, int x, int y, int width, int height) {
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
}

void kgtk_draw_gray_pixels(KWidgetRef widget, const uint8_t* pixels, int width, int height, int stride) {
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
}

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

void kgtk_drawing_area_connect(
    KWidgetRef widget,
    KCanvasExposeCallback on_expose,
    KCanvasPointerCallback on_pointer,
    void* user_data
) {
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
}

void kgtk_widget_set_size_request(KWidgetRef widget, int width, int height) {
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
}

void kgtk_widget_show_all(KWidgetRef widget) {
    fn_gtk_widget_show_all fn = (fn_gtk_widget_show_all)resolve_sym("gtk_widget_show_all");
    if (fn && widget) fn(widget);
}

void kgtk_widget_queue_draw(KWidgetRef widget) {
    fn_gtk_widget_queue_draw fn = (fn_gtk_widget_queue_draw)resolve_sym("gtk_widget_queue_draw");
    if (fn && widget) fn(widget);
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

#define KGTK_FONT_CACHE_SIZE 64
typedef struct {
    char* key;
    double scale;
    void* desc;
} KFontCacheEntry;
static KFontCacheEntry g_font_cache[KGTK_FONT_CACHE_SIZE];

static void* kgtk_lookup_or_create_font_desc(const char* font_desc_str, uint32_t* out_idx) {
    if (out_idx) *out_idx = 63u;
    if (!font_desc_str) return NULL;

    double scale = kgtk_get_ui_scale();
    uint32_t hash = sym_name_hash(font_desc_str);
    uint32_t mask = KGTK_FONT_CACHE_SIZE - 1;
    uint32_t idx = hash & mask;

    // Reserve slot 63 as the "no font override" sentinel
    for (uint32_t probes = 0; probes < KGTK_FONT_CACHE_SIZE - 1; ++probes) {
        if (idx == 63u) idx = 0;
        KFontCacheEntry* e = &g_font_cache[idx];
        if (!e->key) break;
        if (e->scale == scale && strcmp(e->key, font_desc_str) == 0) {
            if (out_idx) *out_idx = idx;
            return e->desc;
        }
        idx = (idx + 1) & mask;
    }

    fn_pango_font_description_from_string from_str = (fn_pango_font_description_from_string)resolve_sym("pango_font_description_from_string");
    fn_pango_font_description_get_size get_sz = (fn_pango_font_description_get_size)resolve_sym("pango_font_description_get_size");
    fn_pango_font_description_set_absolute_size set_abs = (fn_pango_font_description_set_absolute_size)resolve_sym("pango_font_description_set_absolute_size");
    fn_pango_font_description_free free_fn = (fn_pango_font_description_free)resolve_sym("pango_font_description_free");
    if (!from_str) return NULL;

    void* desc = from_str(font_desc_str);
    if (!desc) return NULL;
    if (get_sz && set_abs) {
        int pango_pts = get_sz(desc);
        if (pango_pts > 0) {
            // Convert logical points to exact scaled physical pixels (2.75 px/pt on 1860x2480 reference)
            double abs_pango = (double)pango_pts * 2.75 * scale;
            if (abs_pango < 9.0 * 1024.0) abs_pango = 9.0 * 1024.0;
            set_abs(desc, abs_pango);
        }
    }

    idx = hash & mask;
    for (uint32_t probes = 0; probes < KGTK_FONT_CACHE_SIZE - 1; ++probes) {
        if (idx == 63u) idx = 0;
        KFontCacheEntry* e = &g_font_cache[idx];
        if (!e->key) {
            char* copy = strdup(font_desc_str);
            if (copy) {
                e->key = copy;
                e->scale = scale;
                e->desc = desc;
                if (out_idx) *out_idx = idx;
                return desc;
            }
            break;
        }
        idx = (idx + 1) & mask;
    }
    if (free_fn) free_fn(desc);
    return NULL;
}

/* Shared GtkRcStyle cache:
 * In GTK+-2.0, calling gtk_widget_modify_font / gtk_widget_modify_fg / gtk_widget_modify_bg
 * creates a private per-widget GtkRcStyle via gtk_widget_get_modifier_style(widget).
 * Because GTK2's realized_style_ht keys GtkStyle objects by the GSList of GtkRcStyle* pointers,
 * private per-widget GtkRcStyle instances cause a 100% GtkStyle cache miss during gtk_widget_realize,
 * forcing gtk_style_realize to run 40 synchronous XAllocColor X11 round-trips per widget!
 * Sharing a single cached GtkRcStyle* per (font_idx, has_fg, fg_gray, has_bg, bg_gray) tuple
 * via gtk_widget_modify_style(widget, rc_style) gives a 100% GtkStyle cache hit in realized_style_ht. */
#define KGTK_RC_STYLE_CACHE_SIZE 256
typedef struct {
    uint32_t style_key;
    void* rc_style;
    void* proto_gtk_style;
    void* pinned_gtk_style;
} KRcStyleCacheEntry;
static KRcStyleCacheEntry g_rc_style_cache[KGTK_RC_STYLE_CACHE_SIZE];

typedef void* (KGTK_ABI *fn_gtk_rc_style_new)(void);
typedef void (KGTK_ABI *fn_gtk_widget_modify_style)(KWidgetRef, void*);
typedef void* (KGTK_ABI *fn_gtk_widget_get_modifier_style)(KWidgetRef);
typedef void* (KGTK_ABI *fn_gtk_rc_get_style)(KWidgetRef);
typedef void (KGTK_ABI *fn_gtk_widget_set_style)(KWidgetRef, void*);
typedef void* (KGTK_ABI *fn_gtk_style_attach)(void*, void*);
typedef void* (KGTK_ABI *fn_g_object_ref)(void*);

static void kgtk_pin_cache_entry_style(KRcStyleCacheEntry* e, KWidgetRef widget) {
    if (!e || e->proto_gtk_style || !g_root_gdk_window || !widget) return;
    fn_gtk_rc_get_style rc_get_style = (fn_gtk_rc_get_style)resolve_sym("gtk_rc_get_style");
    fn_gtk_style_attach style_attach = (fn_gtk_style_attach)resolve_sym("gtk_style_attach");
    fn_gtk_widget_set_style set_style = (fn_gtk_widget_set_style)resolve_sym("gtk_widget_set_style");
    fn_g_object_ref obj_ref = (fn_g_object_ref)resolve_sym("g_object_ref");
    if (!rc_get_style || !style_attach || !set_style || !obj_ref) return;

    void* proto = rc_get_style(widget);
    if (proto) {
        obj_ref(proto);
        e->proto_gtk_style = proto;
        // gtk_style_attach consumes one reference on proto and returns a reference to the realized GtkStyle
        // with attach_count incremented by 1 so kgtk_container_clear never drops attach_count to 0!
        obj_ref(proto);
        e->pinned_gtk_style = style_attach(proto, g_root_gdk_window);
        set_style(widget, proto);
    }
}

static void kgtk_apply_rc_style_key(KWidgetRef widget, uint32_t new_key, uint32_t old_key) {
    if (!widget || new_key == old_key) return;

    fn_g_object_set_data_full set_data = (fn_g_object_set_data_full)resolve_sym("g_object_set_data_full");
    fn_gtk_rc_style_new rc_style_new = (fn_gtk_rc_style_new)resolve_sym("gtk_rc_style_new");
    fn_gtk_widget_modify_style mod_style = (fn_gtk_widget_modify_style)resolve_sym("gtk_widget_modify_style");
    fn_gtk_widget_get_modifier_style get_mod_style = (fn_gtk_widget_get_modifier_style)resolve_sym("gtk_widget_get_modifier_style");
    fn_gtk_widget_set_style set_style = (fn_gtk_widget_set_style)resolve_sym("gtk_widget_set_style");
    fn_g_object_ref obj_ref = (fn_g_object_ref)resolve_sym("g_object_ref");
    fn_g_object_unref obj_unref = (fn_g_object_unref)resolve_sym("g_object_unref");
    if (set_data) {
        set_data(widget, "k-rc-key", (void*)(uintptr_t)new_key, NULL);
    }

    uint32_t hash = (new_key * 2654435761u);
    uint32_t mask = KGTK_RC_STYLE_CACHE_SIZE - 1;
    uint32_t idx = (hash >> 16) & mask;

    if (mod_style && get_mod_style && obj_ref) {
        for (uint32_t probes = 0; probes < KGTK_RC_STYLE_CACHE_SIZE; ++probes) {
            KRcStyleCacheEntry* e = &g_rc_style_cache[idx];
            if (!e->style_key) break;
            if (e->style_key == new_key && e->rc_style) {
                if (e->proto_gtk_style && set_style) {
                    set_style(widget, e->proto_gtk_style);
                } else {
                    mod_style(widget, e->rc_style);
                    kgtk_pin_cache_entry_style(e, widget);
                }
                return;
            }
            idx = (idx + 1) & mask;
        }
        // Attach a fresh unshared GtkRcStyle before populating fields on this widget
        if (rc_style_new) {
            void* fresh_rc = rc_style_new();
            if (fresh_rc) {
                if (set_style) set_style(widget, NULL);
                mod_style(widget, fresh_rc);
                if (obj_unref) obj_unref(fresh_rc);
            }
        }
    }

    uint32_t font_idx = new_key & 0x3Fu;
    if (font_idx < 63u && g_font_cache[font_idx].desc) {
        fn_gtk_widget_modify_font mod_font = (fn_gtk_widget_modify_font)resolve_sym("gtk_widget_modify_font");
        if (mod_font) mod_font(widget, g_font_cache[font_idx].desc);
    }
    if (new_key & (1u << 6)) {
        fn_gtk_widget_modify_fg mod_fg = (fn_gtk_widget_modify_fg)resolve_sym("gtk_widget_modify_fg");
        if (mod_fg) {
            uint8_t fg_gray = (uint8_t)((new_key >> 8) & 0xFFu);
            uint16_t c16 = ((uint16_t)fg_gray << 8) | fg_gray;
            KGdkColor color = { 0, c16, c16, c16 };
            mod_fg(widget, 0, &color);
            mod_fg(widget, 1, &color);
            mod_fg(widget, 2, &color);
        }
    }
    if (new_key & (1u << 7)) {
        fn_gtk_widget_modify_bg mod_bg = (fn_gtk_widget_modify_bg)resolve_sym("gtk_widget_modify_bg");
        if (mod_bg) {
            uint8_t bg_gray = (uint8_t)((new_key >> 16) & 0xFFu);
            uint16_t c16 = ((uint16_t)bg_gray << 8) | bg_gray;
            KGdkColor color = { 0, c16, c16, c16 };
            mod_bg(widget, 0, &color);
            mod_bg(widget, 2, &color);
            uint8_t active_gray = kgtk_quantize_eink_gray(bg_gray > 128 ? (bg_gray - 34) : (bg_gray + 34));
            uint16_t ac16 = ((uint16_t)active_gray << 8) | active_gray;
            KGdkColor active_color = { 0, ac16, ac16, ac16 };
            mod_bg(widget, 1, &active_color);
        }
    }

    if (mod_style && get_mod_style && obj_ref) {
        void* rc_style = get_mod_style(widget);
        if (rc_style) {
            idx = (hash >> 16) & mask;
            for (uint32_t probes = 0; probes < KGTK_RC_STYLE_CACHE_SIZE; ++probes) {
                KRcStyleCacheEntry* e = &g_rc_style_cache[idx];
                if (!e->style_key) {
                    obj_ref(rc_style);
                    e->style_key = new_key;
                    e->rc_style = rc_style;
                    e->proto_gtk_style = NULL;
                    e->pinned_gtk_style = NULL;
                    kgtk_pin_cache_entry_style(e, widget);
                    break;
                }
                idx = (idx + 1) & mask;
            }
        }
    }
}

static uint32_t kgtk_get_widget_rc_key(KWidgetRef widget) {
    fn_g_object_get_data get_data = (fn_g_object_get_data)resolve_sym("g_object_get_data");
    uint32_t k = get_data ? (uint32_t)(uintptr_t)get_data(widget, "k-rc-key") : 0u;
    return k ? k : ((1u << 31) | 63u);
}

void kgtk_widget_modify_bg_gray(KWidgetRef widget, int state, uint8_t gray_level) {
    if (!widget) return;
    gray_level = kgtk_quantize_eink_gray(gray_level);
    if (state == 0) {
        uint32_t old_key = kgtk_get_widget_rc_key(widget);
        uint32_t new_key = (old_key & ~(0xFFu << 16)) | (1u << 7) | ((uint32_t)gray_level << 16);
        kgtk_apply_rc_style_key(widget, new_key, old_key);
        return;
    }
    fn_gtk_widget_modify_bg fn = (fn_gtk_widget_modify_bg)resolve_sym("gtk_widget_modify_bg");
    if (fn) {
        uint16_t c16 = ((uint16_t)gray_level << 8) | gray_level;
        KGdkColor color = { 0, c16, c16, c16 };
        fn(widget, state, &color);
    }
}

void kgtk_widget_modify_fg_gray(KWidgetRef widget, int state, uint8_t gray_level) {
    if (!widget) return;
    gray_level = kgtk_quantize_eink_gray(gray_level);
    if (state == 0) {
        uint32_t old_key = kgtk_get_widget_rc_key(widget);
        uint32_t new_key = (old_key & ~(0xFFu << 8)) | (1u << 6) | ((uint32_t)gray_level << 8);
        kgtk_apply_rc_style_key(widget, new_key, old_key);
        return;
    }
    fn_gtk_widget_modify_fg fn = (fn_gtk_widget_modify_fg)resolve_sym("gtk_widget_modify_fg");
    if (fn) {
        uint16_t c16 = ((uint16_t)gray_level << 8) | gray_level;
        KGdkColor color = { 0, c16, c16, c16 };
        fn(widget, state, &color);
    }
}

void kgtk_widget_modify_font_string(KWidgetRef widget, const char* font_desc_str) {
    if (!widget || !font_desc_str) return;
    uint32_t font_idx = 63u;
    void* desc = kgtk_lookup_or_create_font_desc(font_desc_str, &font_idx);
    if (!desc) return;
    if (font_idx < 63u) {
        uint32_t old_key = kgtk_get_widget_rc_key(widget);
        uint32_t new_key = (old_key & ~0x3Fu) | (font_idx & 0x3Fu);
        kgtk_apply_rc_style_key(widget, new_key, old_key);
        return;
    }
    fn_gtk_widget_modify_font modify_fn = (fn_gtk_widget_modify_font)resolve_sym("gtk_widget_modify_font");
    if (modify_fn) modify_fn(widget, desc);
}

void kgtk_widget_set_font_and_fg(KWidgetRef widget, const char* font_desc_str, bool has_fg, uint8_t fg_gray) {
    if (!widget) return;
    uint32_t old_key = kgtk_get_widget_rc_key(widget);
    uint32_t new_key = old_key;
    if (font_desc_str) {
        uint32_t font_idx = 63u;
        void* desc = kgtk_lookup_or_create_font_desc(font_desc_str, &font_idx);
        if (desc && font_idx < 63u) {
            new_key = (new_key & ~0x3Fu) | (font_idx & 0x3Fu);
        }
    }
    if (has_fg) {
        uint8_t q_fg = kgtk_quantize_eink_gray(fg_gray);
        new_key = (new_key & ~(0xFFu << 8)) | (1u << 6) | ((uint32_t)q_fg << 8);
    }
    kgtk_apply_rc_style_key(widget, new_key, old_key);
}

unsigned long kgtk_signal_connect(KWidgetRef instance, const char* detailed_signal, KSignalCallback callback, void* user_data) {
    fn_g_signal_connect_data fn = (fn_g_signal_connect_data)resolve_sym("g_signal_connect_data");
    if (fn && instance && detailed_signal && callback) {
        return fn(instance, detailed_signal, (void*)callback, user_data, NULL, 0);
    }
    return 0;
}

// --- Cairo-Rendered Modern E-Ink Components ---

typedef struct {
    int initialized;
    fn_gtk_widget_get_window get_window;
    fn_gtk_widget_get_allocation get_allocation;
    fn_gdk_cairo_create gdk_create;
    fn_cairo_destroy destroy;
    fn_cairo_save save;
    fn_cairo_restore restore;
    fn_cairo_translate translate;
    fn_cairo_scale scale;
    fn_cairo_set_source_rgb set_source_rgb;
    fn_cairo_set_source_rgba set_source_rgba;
    fn_cairo_set_line_width set_line_width;
    fn_cairo_set_line_cap set_line_cap;
    fn_cairo_set_line_join set_line_join;
    fn_cairo_new_path new_path;
    fn_cairo_close_path close_path;
    fn_cairo_move_to move_to;
    fn_cairo_line_to line_to;
    fn_cairo_arc arc;
    fn_cairo_rectangle rectangle;
    fn_cairo_clip clip;
    fn_cairo_fill fill;
    fn_cairo_stroke stroke;
} KCairoFuncTable;

static KCairoFuncTable g_cairo = {0};

static inline void kcairo_ensure_resolved(void) {
    if (__builtin_expect(g_cairo.initialized != 0, 1)) return;
    g_cairo.get_window = (fn_gtk_widget_get_window)resolve_sym("gtk_widget_get_window");
    g_cairo.get_allocation = (fn_gtk_widget_get_allocation)resolve_sym("gtk_widget_get_allocation");
    g_cairo.gdk_create = (fn_gdk_cairo_create)resolve_sym("gdk_cairo_create");
    g_cairo.destroy = (fn_cairo_destroy)resolve_sym("cairo_destroy");
    g_cairo.save = (fn_cairo_save)resolve_sym("cairo_save");
    g_cairo.restore = (fn_cairo_restore)resolve_sym("cairo_restore");
    g_cairo.translate = (fn_cairo_translate)resolve_sym("cairo_translate");
    g_cairo.scale = (fn_cairo_scale)resolve_sym("cairo_scale");
    g_cairo.set_source_rgb = (fn_cairo_set_source_rgb)resolve_sym("cairo_set_source_rgb");
    g_cairo.set_source_rgba = (fn_cairo_set_source_rgba)resolve_sym("cairo_set_source_rgba");
    g_cairo.set_line_width = (fn_cairo_set_line_width)resolve_sym("cairo_set_line_width");
    g_cairo.set_line_cap = (fn_cairo_set_line_cap)resolve_sym("cairo_set_line_cap");
    g_cairo.set_line_join = (fn_cairo_set_line_join)resolve_sym("cairo_set_line_join");
    g_cairo.new_path = (fn_cairo_new_path)resolve_sym("cairo_new_path");
    g_cairo.close_path = (fn_cairo_close_path)resolve_sym("cairo_close_path");
    g_cairo.move_to = (fn_cairo_move_to)resolve_sym("cairo_move_to");
    g_cairo.line_to = (fn_cairo_line_to)resolve_sym("cairo_line_to");
    g_cairo.arc = (fn_cairo_arc)resolve_sym("cairo_arc");
    g_cairo.rectangle = (fn_cairo_rectangle)resolve_sym("cairo_rectangle");
    g_cairo.clip = (fn_cairo_clip)resolve_sym("cairo_clip");
    g_cairo.fill = (fn_cairo_fill)resolve_sym("cairo_fill");
    g_cairo.stroke = (fn_cairo_stroke)resolve_sym("cairo_stroke");
    g_cairo.initialized = 1;
}

static void kcairo_clip_to_expose(void* cr, void* event) {
    if (!cr || !event) return;
    kcairo_ensure_resolved();
    if (g_cairo.new_path && g_cairo.rectangle && g_cairo.clip) {
        KGdkEventExpose* ev = (KGdkEventExpose*)event;
        if (ev->area.width > 0 && ev->area.height > 0) {
            g_cairo.new_path(cr);
            g_cairo.rectangle(cr, (double)ev->area.x, (double)ev->area.y, (double)ev->area.width, (double)ev->area.height);
            g_cairo.clip(cr);
        }
    }
}

typedef struct {
    KCairoExposeCallback on_expose;
    void* user_data;
    KIdleCallback on_destroy;
    uint64_t cache_key;
    uint8_t clear_bg_gray;
} KCairoExposeBinding;

#define KGTK_CAIRO_PIXMAP_CACHE_SIZE 128
typedef struct {
    uint64_t key;
    void* pixmap;
} KCairoPixmapCacheEntry;
static KCairoPixmapCacheEntry g_cairo_pixmap_cache[KGTK_CAIRO_PIXMAP_CACHE_SIZE];
static void* g_cached_blit_gc = NULL;
static void* g_cached_blit_win = NULL;

typedef void* (KGTK_ABI *fn_gdk_pixmap_new)(void*, int, int, int);
typedef void (KGTK_ABI *fn_gdk_draw_drawable)(void*, void*, void*, int, int, int, int, int, int);

static void c_cairo_binding_destroy(void* data) {
    KCairoExposeBinding* b = (KCairoExposeBinding*)data;
    if (!b) return;
    if (b->on_destroy && b->user_data) {
        b->on_destroy(b->user_data);
    }
    free(b);
}

static int c_cairo_expose_trampoline(KWidgetRef widget, void* event, void* data) {
    KCairoExposeBinding* b = (KCairoExposeBinding*)data;
    if (!b || !b->on_expose || !widget) return 0;

    kcairo_ensure_resolved();
    if (!g_cairo.get_window || !g_cairo.get_allocation || !g_cairo.gdk_create || !g_cairo.destroy) return 0;

    void* gdk_win = g_cairo.get_window(widget);
    if (!gdk_win) return 0;

    KGtkAllocation alloc = { 0, 0, 0, 0 };
    g_cairo.get_allocation(widget, &alloc);
    if (alloc.width <= 0 || alloc.height <= 0) return 0;

    if (b->cache_key != 0 && alloc.width <= 256 && alloc.height <= 256) {
        fn_gdk_pixmap_new pixmap_new = (fn_gdk_pixmap_new)resolve_sym("gdk_pixmap_new");
        fn_gdk_draw_drawable draw_drawable = (fn_gdk_draw_drawable)resolve_sym("gdk_draw_drawable");
        fn_gdk_gc_new gc_new = (fn_gdk_gc_new)resolve_sym("gdk_gc_new");
        fn_g_object_unref unref = (fn_g_object_unref)resolve_sym("g_object_unref");
        if (pixmap_new && draw_drawable && gc_new && g_cairo.new_path && g_cairo.rectangle && g_cairo.fill) {
            uint8_t q_bg = kgtk_quantize_eink_gray(b->clear_bg_gray);
            uint64_t full_key = b->cache_key
                ^ ((uint64_t)(uint32_t)alloc.width << 48)
                ^ ((uint64_t)(uint32_t)alloc.height << 36)
                ^ ((uint64_t)q_bg << 28);
            if (full_key == 0) full_key = 1;

            uint32_t mask = KGTK_CAIRO_PIXMAP_CACHE_SIZE - 1;
            uint32_t idx = (uint32_t)((full_key ^ (full_key >> 27)) * 2654435761u) & mask;
            void* pixmap = NULL;
            for (uint32_t probes = 0; probes < 8; ++probes) {
                KCairoPixmapCacheEntry* e = &g_cairo_pixmap_cache[(idx + probes) & mask];
                if (!e->key) break;
                if (e->key == full_key && e->pixmap) {
                    pixmap = e->pixmap;
                    break;
                }
            }

            if (!pixmap) {
                pixmap = pixmap_new(gdk_win, alloc.width, alloc.height, -1);
                if (pixmap) {
                    void* pcr = g_cairo.gdk_create(pixmap);
                    if (pcr) {
                        kcairo_set_gray(pcr, q_bg);
                        g_cairo.new_path(pcr);
                        g_cairo.rectangle(pcr, 0.0, 0.0, (double)alloc.width, (double)alloc.height);
                        g_cairo.fill(pcr);
                        b->on_expose(widget, pcr, 0.0, 0.0, (double)alloc.width, (double)alloc.height, b->user_data);
                        g_cairo.destroy(pcr);

                        uint32_t store_slot = idx;
                        for (uint32_t probes = 0; probes < 8; ++probes) {
                            uint32_t s = (idx + probes) & mask;
                            if (!g_cairo_pixmap_cache[s].key) {
                                store_slot = s;
                                break;
                            }
                        }
                        if (g_cairo_pixmap_cache[store_slot].pixmap && unref) {
                            unref(g_cairo_pixmap_cache[store_slot].pixmap);
                        }
                        g_cairo_pixmap_cache[store_slot].key = full_key;
                        g_cairo_pixmap_cache[store_slot].pixmap = pixmap;
                    } else {
                        if (unref) unref(pixmap);
                        pixmap = NULL;
                    }
                }
            }

            if (pixmap) {
                if (g_cached_blit_win != gdk_win || !g_cached_blit_gc) {
                    if (g_cached_blit_gc && unref) unref(g_cached_blit_gc);
                    g_cached_blit_gc = gc_new(gdk_win);
                    g_cached_blit_win = gdk_win;
                }
                if (g_cached_blit_gc) {
                    int x0 = alloc.x;
                    int y0 = alloc.y;
                    int x1 = alloc.x + alloc.width;
                    int y1 = alloc.y + alloc.height;
                    if (event) {
                        KGdkEventExpose* ev = (KGdkEventExpose*)event;
                        if (ev->area.width > 0 && ev->area.height > 0) {
                            if (ev->area.x > x0) x0 = ev->area.x;
                            if (ev->area.y > y0) y0 = ev->area.y;
                            if (ev->area.x + ev->area.width < x1) x1 = ev->area.x + ev->area.width;
                            if (ev->area.y + ev->area.height < y1) y1 = ev->area.y + ev->area.height;
                        }
                    }
                    if (x1 > x0 && y1 > y0) {
                        draw_drawable(gdk_win, g_cached_blit_gc, pixmap, x0 - alloc.x, y0 - alloc.y, x0, y0, x1 - x0, y1 - y0);
                    }
                    return 0;
                }
            }
        }
    }

    void* cr = g_cairo.gdk_create(gdk_win);
    if (!cr) return 0;
    kcairo_clip_to_expose(cr, event);
    b->on_expose(widget, cr, (double)alloc.x, (double)alloc.y, (double)alloc.width, (double)alloc.height, b->user_data);
    g_cairo.destroy(cr);
    return 0;
}

void kgtk_connect_cairo_expose_cached(
    KWidgetRef widget,
    uint64_t cache_key,
    uint8_t clear_bg_gray,
    KCairoExposeCallback on_expose,
    void* user_data,
    KIdleCallback on_destroy
) {
    fn_g_signal_connect_data conn = (fn_g_signal_connect_data)resolve_sym("g_signal_connect_data");
    fn_g_object_set_data_full set_data = (fn_g_object_set_data_full)resolve_sym("g_object_set_data_full");
    if (!widget || !on_expose || !conn) {
        if (on_destroy && user_data) on_destroy(user_data);
        return;
    }
    KCairoExposeBinding* b = (KCairoExposeBinding*)malloc(sizeof(KCairoExposeBinding));
    if (!b) {
        if (on_destroy && user_data) on_destroy(user_data);
        return;
    }
    b->on_expose = on_expose;
    b->user_data = user_data;
    b->on_destroy = on_destroy;
    b->cache_key = cache_key;
    b->clear_bg_gray = clear_bg_gray;
    if (set_data) {
        set_data(widget, "kindle-cairo-expose-binding", b, c_cairo_binding_destroy);
    }
    conn(widget, "expose-event", (void*)c_cairo_expose_trampoline, b, NULL, 0);
}

void kgtk_connect_cairo_expose(
    KWidgetRef widget,
    KCairoExposeCallback on_expose,
    void* user_data,
    KIdleCallback on_destroy
) {
    kgtk_connect_cairo_expose_cached(widget, 0, 0xFF, on_expose, user_data, on_destroy);
}

void kcairo_rounded_rect(KCairoRef cr, double x, double y, double w, double h, double r) {
    kcairo_ensure_resolved();
    if (!cr || !g_cairo.new_path || !g_cairo.rectangle || w <= 0 || h <= 0) return;

    double max_r = (w < h ? w : h) * 0.5;
    if (r > max_r) r = max_r;
    if (r <= 0.5 || !g_cairo.arc || !g_cairo.close_path) {
        g_cairo.new_path(cr);
        g_cairo.rectangle(cr, x, y, w, h);
        return;
    }
    const double pi = 3.14159265358979323846;
    g_cairo.new_path(cr);
    g_cairo.arc(cr, x + w - r, y + r,     r, -0.5 * pi, 0.0);
    g_cairo.arc(cr, x + w - r, y + h - r, r, 0.0,       0.5 * pi);
    g_cairo.arc(cr, x + r,     y + h - r, r, 0.5 * pi,  pi);
    g_cairo.arc(cr, x + r,     y + r,     r, pi,        1.5 * pi);
    g_cairo.close_path(cr);
}

void kcairo_set_gray(KCairoRef cr, uint8_t gray) {
    kcairo_ensure_resolved();
    if (cr && g_cairo.set_source_rgb) {
        uint8_t q = kgtk_quantize_eink_gray(gray);
        double g = (double)q / 255.0;
        g_cairo.set_source_rgb(cr, g, g, g);
    }
}

void kcairo_set_gray_alpha(KCairoRef cr, uint8_t gray, double alpha) {
    kcairo_ensure_resolved();
    if (cr && g_cairo.set_source_rgba) {
        double g = (double)gray / 255.0;
        g_cairo.set_source_rgba(cr, g, g, g, alpha);
    }
}

void kcairo_set_line_width(KCairoRef cr, double width) {
    kcairo_ensure_resolved();
    if (cr && g_cairo.set_line_width) g_cairo.set_line_width(cr, width);
}

void kcairo_set_line_round(KCairoRef cr) {
    kcairo_ensure_resolved();
    if (cr && g_cairo.set_line_cap) g_cairo.set_line_cap(cr, 1);
    if (cr && g_cairo.set_line_join) g_cairo.set_line_join(cr, 1);
}

void kcairo_new_path(KCairoRef cr) {
    kcairo_ensure_resolved();
    if (cr && g_cairo.new_path) g_cairo.new_path(cr);
}

void kcairo_close_path(KCairoRef cr) {
    kcairo_ensure_resolved();
    if (cr && g_cairo.close_path) g_cairo.close_path(cr);
}

void kcairo_move_to(KCairoRef cr, double x, double y) {
    kcairo_ensure_resolved();
    if (cr && g_cairo.move_to) g_cairo.move_to(cr, x, y);
}

void kcairo_line_to(KCairoRef cr, double x, double y) {
    kcairo_ensure_resolved();
    if (cr && g_cairo.line_to) g_cairo.line_to(cr, x, y);
}

void kcairo_arc(KCairoRef cr, double xc, double yc, double radius, double angle1, double angle2) {
    kcairo_ensure_resolved();
    if (cr && g_cairo.arc) g_cairo.arc(cr, xc, yc, radius, angle1, angle2);
}

void kcairo_rectangle(KCairoRef cr, double x, double y, double width, double height) {
    kcairo_ensure_resolved();
    if (cr && g_cairo.rectangle) g_cairo.rectangle(cr, x, y, width, height);
}

void kcairo_fill(KCairoRef cr) {
    kcairo_ensure_resolved();
    if (cr && g_cairo.fill) g_cairo.fill(cr);
}

void kcairo_stroke(KCairoRef cr) {
    kcairo_ensure_resolved();
    if (cr && g_cairo.stroke) g_cairo.stroke(cr);
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

static inline int kcairo_corner_inset_px(int r, int dy) {
    if (r <= 1 || dy < 0 || dy >= r) return 0;
    int cy = r - dy;
    int limit = r * r + r;
    int cy2 = cy * cy;
    int dx = r;
    while (dx > 0 && (dx * dx + cy2 > limit)) {
        dx--;
    }
    return r - dx;
}

static void kcairo_box_corner_radii(const KStyledBoxState* st, int iw, int ih, int* out_tl, int* out_tr, int* out_br, int* out_bl) {
    int max_r = (iw < ih ? iw : ih) / 2;
    int tl = 0, tr = 0, br = 0, bl = 0;
    if (st->is_ellipse) {
        tl = tr = br = bl = max_r;
    } else if (st->has_uneven_corners) {
        tl = st->corner_tl;
        tr = st->corner_tr;
        br = st->corner_br;
        bl = st->corner_bl;
    } else {
        tl = tr = br = bl = st->corner_radius;
    }
    if (tl < 0) tl = 0; if (tl > max_r) tl = max_r;
    if (tr < 0) tr = 0; if (tr > max_r) tr = max_r;
    if (br < 0) br = 0; if (br > max_r) br = max_r;
    if (bl < 0) bl = 0; if (bl > max_r) bl = max_r;
    *out_tl = tl;
    *out_tr = tr;
    *out_br = br;
    *out_bl = bl;
}

/* Emits 100% integer-aligned axis-aligned cairo_rectangle subpaths for a rounded box
 * so Cairo's Xlib backend uses XFillRectangles directly without XGetImage/XPutImage fallbacks. */
static void kcairo_rectilinear_rounded_box_path(void* cr, int ix, int iy, int iw, int ih, int rtl, int rtr, int rbr, int rbl) {
    if (!g_cairo.new_path || !g_cairo.rectangle || iw <= 0 || ih <= 0) return;
    g_cairo.new_path(cr);
    int r_top = rtl > rtr ? rtl : rtr;
    int r_bot = rbl > rbr ? rbl : rbr;
    if (r_top + r_bot > ih) {
        r_top = ih / 2;
        r_bot = ih - r_top;
    }
    if (r_top <= 1 && r_bot <= 1) {
        g_cairo.rectangle(cr, (double)ix, (double)iy, (double)iw, (double)ih);
        return;
    }

    int run_y = -1, run_l = 0, run_w = 0, run_h = 0;
    for (int dy = 0; dy < r_top; ++dy) {
        int l = (dy < rtl) ? kcairo_corner_inset_px(rtl, dy) : 0;
        int r = (dy < rtr) ? kcairo_corner_inset_px(rtr, dy) : 0;
        int rw = iw - l - r;
        if (rw <= 0) continue;
        if (run_h > 0 && l == run_l && rw == run_w && (iy + dy) == (run_y + run_h)) {
            run_h++;
        } else {
            if (run_h > 0) g_cairo.rectangle(cr, (double)(ix + run_l), (double)run_y, (double)run_w, (double)run_h);
            run_y = iy + dy;
            run_l = l;
            run_w = rw;
            run_h = 1;
        }
    }
    if (run_h > 0) {
        g_cairo.rectangle(cr, (double)(ix + run_l), (double)run_y, (double)run_w, (double)run_h);
        run_h = 0;
    }

    int mid_h = ih - r_top - r_bot;
    if (mid_h > 0) {
        g_cairo.rectangle(cr, (double)ix, (double)(iy + r_top), (double)iw, (double)mid_h);
    }

    for (int dy = r_bot - 1; dy >= 0; --dy) {
        int row_y = iy + ih - 1 - dy;
        int l = (dy < rbl) ? kcairo_corner_inset_px(rbl, dy) : 0;
        int r = (dy < rbr) ? kcairo_corner_inset_px(rbr, dy) : 0;
        int rw = iw - l - r;
        if (rw <= 0) continue;
        if (run_h > 0 && l == run_l && rw == run_w && row_y == (run_y + run_h)) {
            run_h++;
        } else {
            if (run_h > 0) g_cairo.rectangle(cr, (double)(ix + run_l), (double)run_y, (double)run_w, (double)run_h);
            run_y = row_y;
            run_l = l;
            run_w = rw;
            run_h = 1;
        }
    }
    if (run_h > 0) {
        g_cairo.rectangle(cr, (double)(ix + run_l), (double)run_y, (double)run_w, (double)run_h);
    }
}

/* Emits 100% integer-aligned axis-aligned cairo_rectangle subpaths for a rounded border of width bw
 * (outer rounded box minus inner rounded box) so Cairo uses XFillRectangles with zero XGetImage/XPutImage. */
static void kcairo_rectilinear_rounded_border_path(void* cr, int ix, int iy, int iw, int ih, int rtl, int rtr, int rbr, int rbl, int bw) {
    if (!g_cairo.new_path || !g_cairo.rectangle || iw <= 0 || ih <= 0 || bw <= 0) return;
    if (bw * 2 >= iw || bw * 2 >= ih) {
        kcairo_rectilinear_rounded_box_path(cr, ix, iy, iw, ih, rtl, rtr, rbr, rbl);
        return;
    }
    g_cairo.new_path(cr);
    int r_top = rtl > rtr ? rtl : rtr;
    int r_bot = rbl > rbr ? rbl : rbr;
    if (r_top < bw) r_top = bw;
    if (r_bot < bw) r_bot = bw;
    if (r_top + r_bot > ih) {
        r_top = ih / 2;
        r_bot = ih - r_top;
    }

    int itl = rtl > bw ? (rtl - bw) : 0;
    int itr = rtr > bw ? (rtr - bw) : 0;
    int ibr = rbr > bw ? (rbr - bw) : 0;
    int ibl = rbl > bw ? (rbl - bw) : 0;

    for (int ry = 0; ry < r_top; ++ry) {
        int out_l = (ry < rtl) ? kcairo_corner_inset_px(rtl, ry) : 0;
        int out_r = (ry < rtr) ? kcairo_corner_inset_px(rtr, ry) : 0;
        if (ry < bw) {
            int rw = iw - out_l - out_r;
            if (rw > 0) g_cairo.rectangle(cr, (double)(ix + out_l), (double)(iy + ry), (double)rw, 1.0);
        } else {
            int iry = ry - bw;
            int in_l = bw + ((iry < itl) ? kcairo_corner_inset_px(itl, iry) : 0);
            int in_r = bw + ((iry < itr) ? kcairo_corner_inset_px(itr, iry) : 0);
            int lw = in_l - out_l;
            int rw = in_r - out_r;
            if (lw > 0) g_cairo.rectangle(cr, (double)(ix + out_l), (double)(iy + ry), (double)lw, 1.0);
            if (rw > 0) g_cairo.rectangle(cr, (double)(ix + iw - in_r), (double)(iy + ry), (double)rw, 1.0);
        }
    }

    int mid_h = ih - r_top - r_bot;
    if (mid_h > 0) {
        g_cairo.rectangle(cr, (double)ix, (double)(iy + r_top), (double)bw, (double)mid_h);
        g_cairo.rectangle(cr, (double)(ix + iw - bw), (double)(iy + r_top), (double)bw, (double)mid_h);
    }

    for (int dy = r_bot - 1; dy >= 0; --dy) {
        int row_y = iy + ih - 1 - dy;
        int out_l = (dy < rbl) ? kcairo_corner_inset_px(rbl, dy) : 0;
        int out_r = (dy < rbr) ? kcairo_corner_inset_px(rbr, dy) : 0;
        if (dy < bw) {
            int rw = iw - out_l - out_r;
            if (rw > 0) g_cairo.rectangle(cr, (double)(ix + out_l), (double)row_y, (double)rw, 1.0);
        } else {
            int idy = dy - bw;
            int in_l = bw + ((idy < ibl) ? kcairo_corner_inset_px(ibl, idy) : 0);
            int in_r = bw + ((idy < ibr) ? kcairo_corner_inset_px(ibr, idy) : 0);
            int lw = in_l - out_l;
            int rw = in_r - out_r;
            if (lw > 0) g_cairo.rectangle(cr, (double)(ix + out_l), (double)row_y, (double)lw, 1.0);
            if (rw > 0) g_cairo.rectangle(cr, (double)(ix + iw - in_r), (double)row_y, (double)rw, 1.0);
        }
    }
}

static int c_styled_box_expose(KWidgetRef widget, void* event, void* data) {
    KStyledBoxState* st = (KStyledBoxState*)data;
    if (!st || !widget) return 0;

    kcairo_ensure_resolved();
    if (!g_cairo.get_window || !g_cairo.gdk_create || !g_cairo.destroy || !g_cairo.fill) return 0;

    void* gdk_win = g_cairo.get_window(widget);
    if (!gdk_win) return 0;

    KGtkAllocation alloc = { 0, 0, 0, 0 };
    kgtk_widget_get_size(widget, &alloc.width, &alloc.height);
    if (g_cairo.get_allocation) {
        g_cairo.get_allocation(widget, &alloc);
    }
    if (alloc.width <= 1 || alloc.height <= 1) return 0;

    void* cr = g_cairo.gdk_create(gdk_win);
    if (!cr) return 0;
    kcairo_clip_to_expose(cr, event);

    int abs_sx = st->shadow_x < 0 ? -st->shadow_x : st->shadow_x;
    int abs_sy = st->shadow_y < 0 ? -st->shadow_y : st->shadow_y;
    int box_w = alloc.width - abs_sx;
    int box_h = alloc.height - abs_sy;
    int box_x = alloc.x + (st->shadow_x < 0 ? abs_sx : 0);
    int box_y = alloc.y + (st->shadow_y < 0 ? abs_sy : 0);

    int rtl = 0, rtr = 0, rbr = 0, rbl = 0;
    kcairo_box_corner_radii(st, box_w, box_h, &rtl, &rtr, &rbr, &rbl);

    if ((abs_sx > 0 || abs_sy > 0) && box_w > 2 && box_h > 2) {
        kcairo_rectilinear_rounded_box_path(cr, box_x + st->shadow_x, box_y + st->shadow_y, box_w, box_h, rtl, rtr, rbr, rbl);
        kcairo_set_gray(cr, st->shadow_gray);
        g_cairo.fill(cr);
    }

    if (st->is_interactive && st->is_pressed && (abs_sx > 0 || abs_sy > 0)) {
        // Tactile shift toward the shadow when pressed
        box_x += (st->shadow_x > 0 ? 1 : 0);
        box_y += (st->shadow_y > 0 ? 1 : 0);
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
        kcairo_rectilinear_rounded_box_path(cr, box_x, box_y, box_w, box_h, rtl, rtr, rbr, rbl);
        kcairo_set_gray(cr, effective_bg);
        g_cairo.fill(cr);
    }

    if (st->border_width > 0) {
        int bw = st->border_width + (st->is_interactive && st->is_pressed ? 1 : 0);
        kcairo_rectilinear_rounded_border_path(cr, box_x, box_y, box_w, box_h, rtl, rtr, rbr, rbl, bw);
        kcairo_set_gray(cr, st->border_gray);
        g_cairo.fill(cr);
    }

    g_cairo.destroy(cr);
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
    return 1;
}

static int c_styled_button_motion(KWidgetRef widget, void* event, void* data) {
    (void)widget;
    KStyledBoxState* st = (KStyledBoxState*)data;
    if (!st || !st->is_interactive || !event) return 0;
    if (!c_event_has_button1_mask(event)) {
        st->dragged_scroll = false;
        st->is_pressed = false;
        c_scroll_drag_end();
        return 0;
    }
    if (c_scroll_drag_update(event)) {
        st->dragged_scroll = true;
        st->is_pressed = false;
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

    typedef void (KGTK_ABI *fn_gtk_widget_set_redraw_on_allocate)(KWidgetRef, int);
    fn_gtk_widget_set_redraw_on_allocate set_redraw = (fn_gtk_widget_set_redraw_on_allocate)resolve_sym("gtk_widget_set_redraw_on_allocate");

    KWidgetRef align = kgtk_alignment_new(xalign, yalign, xscale, yscale);
    if (!align) return child;
    if (set_redraw) set_redraw(align, 1);
    kgtk_alignment_set_padding(align, eff_top, eff_bottom, eff_left, eff_right);
    if (child) kgtk_container_add(align, child);

    KWidgetRef host = align;
    if (is_interactive) {
        KWidgetRef eb = kgtk_event_box_new();
        if (eb) {
            if (set_vis) set_vis(eb, 0);
            if (set_above) set_above(eb, 1);
            if (set_redraw) set_redraw(eb, 1);
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
    return create_styled_box_internal(
        child, has_bg, bg_gray, border_width, border_gray, corner_radius,
        shadow_x, shadow_y, shadow_gray, pad_top, pad_bottom, pad_left, pad_right,
        xalign, yalign, xscale, yscale, false, false, NULL, NULL
    );
}

void kgtk_styled_box_set_shape(
    KWidgetRef widget,
    int tl,
    int tr,
    int br,
    int bl,
    bool is_ellipse
) {
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
    return create_styled_box_internal(
        child, has_bg, bg_gray, border_width, border_gray, corner_radius,
        shadow_x, shadow_y, shadow_gray, pad_top, pad_bottom, pad_left, pad_right,
        xalign, yalign, xscale, yscale, true, is_enabled, on_click, user_data
    );
}

// --- Custom Cairo E-Ink Slider ---

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
}

double kgtk_custom_slider_get_value(KWidgetRef slider) {
    typedef void* (*fn_g_object_get_data)(void*, const char*);
    fn_g_object_get_data get_data = (fn_g_object_get_data)resolve_sym("g_object_get_data");
    if (get_data && slider) {
        KCustomSliderState* st = (KCustomSliderState*)get_data(slider, "kindle-custom-slider-state");
        if (st) return st->value;
    }
    return 0.0;
}

// --- Multi-Line TextEditor and Gesture Event Box ---

#include <sys/time.h>

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

KWidgetRef kgtk_gesture_box_new(
    KWidgetRef child,
    int long_press_ms,
    int swipe_threshold_px,
    KGestureCallback on_gesture,
    void* user_data
) {
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
}

char* kgtk_text_editor_get_text(KWidgetRef editor) {
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
}

void kgtk_free_string(char* str) {
    if (!str) return;
    fn_g_free gfree = (fn_g_free)resolve_sym("g_free");
    if (gfree) {
        gfree(str);
    } else {
        free(str);
    }
}

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

bool klipc_is_available(void) {
    if (!g_lipc_lib) {
        g_lipc_lib = dlopen("liblipc.so", RTLD_LAZY | RTLD_GLOBAL);
    }
    return g_lipc_lib != NULL;
}

int klipc_get_int_property(const char* service, const char* prop, int* out_val) {
    pthread_mutex_lock(&g_lipc_mutex);
    void* handle = c_get_lipc_handle_locked();
    if (!handle || !g_lipc_get_int_fn) {
        pthread_mutex_unlock(&g_lipc_mutex);
        return -1;
    }
    int res = g_lipc_get_int_fn(handle, service, prop, out_val);
    pthread_mutex_unlock(&g_lipc_mutex);
    return res;
}

int klipc_set_int_property(const char* service, const char* prop, int val) {
    pthread_mutex_lock(&g_lipc_mutex);
    void* handle = c_get_lipc_handle_locked();
    if (!handle || !g_lipc_set_int_fn) {
        pthread_mutex_unlock(&g_lipc_mutex);
        return -1;
    }
    int res = g_lipc_set_int_fn(handle, service, prop, val);
    pthread_mutex_unlock(&g_lipc_mutex);
    return res;
}

int klipc_get_string_property(const char* service, const char* prop, char* out_buf, int buf_len) {
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
}

int klipc_set_string_property(const char* service, const char* prop, const char* val) {
    pthread_mutex_lock(&g_lipc_mutex);
    void* handle = c_get_lipc_handle_locked();
    if (!handle || !g_lipc_set_str_fn) {
        pthread_mutex_unlock(&g_lipc_mutex);
        return -1;
    }
    int res = g_lipc_set_str_fn(handle, service, prop, val);
    pthread_mutex_unlock(&g_lipc_mutex);
    return res;
}

// --- Embedded WebKitGTK 1.0 WebView (libwebkitgtk-1.0.so.0) ---

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

bool kgtk_webkit_available(void) {
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
}

void kgtk_webview_load_uri(const char* view_id, const char* uri) {
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
}

void kgtk_webview_load_html(const char* view_id, const char* html, const char* base_uri) {
    KWebViewSlot* slot = kgtk_find_webview_slot(view_id);
    if (!slot || !slot->web_view || !html) return;
    if (slot->last_html) free(slot->last_html);
    slot->last_html = strdup(html);
    if (slot->last_url) {
        free(slot->last_url);
        slot->last_url = NULL;
    }
    kgtk_webview_write_and_load_html(slot->web_view, html, base_uri);
}

void kgtk_webview_reload(const char* view_id) {
    KWebViewSlot* slot = kgtk_find_webview_slot(view_id);
    if (!slot || !slot->web_view) return;
    fn_webkit_web_view_reload fn = (fn_webkit_web_view_reload)resolve_sym("webkit_web_view_reload");
    if (fn) fn(slot->web_view);
}

void kgtk_webview_stop_loading(const char* view_id) {
    KWebViewSlot* slot = kgtk_find_webview_slot(view_id);
    if (!slot || !slot->web_view) return;
    fn_webkit_web_view_stop_loading fn = (fn_webkit_web_view_stop_loading)resolve_sym("webkit_web_view_stop_loading");
    if (fn) fn(slot->web_view);
}

void kgtk_webview_go_back(const char* view_id) {
    KWebViewSlot* slot = kgtk_find_webview_slot(view_id);
    if (!slot || !slot->web_view) return;
    fn_webkit_web_view_go_back fn = (fn_webkit_web_view_go_back)resolve_sym("webkit_web_view_go_back");
    if (fn) fn(slot->web_view);
}

void kgtk_webview_go_forward(const char* view_id) {
    KWebViewSlot* slot = kgtk_find_webview_slot(view_id);
    if (!slot || !slot->web_view) return;
    fn_webkit_web_view_go_forward fn = (fn_webkit_web_view_go_forward)resolve_sym("webkit_web_view_go_forward");
    if (fn) fn(slot->web_view);
}

bool kgtk_webview_can_go_back(const char* view_id) {
    KWebViewSlot* slot = kgtk_find_webview_slot(view_id);
    if (!slot || !slot->web_view) return false;
    fn_webkit_web_view_can_go_back fn = (fn_webkit_web_view_can_go_back)resolve_sym("webkit_web_view_can_go_back");
    return fn ? (fn(slot->web_view) != 0) : false;
}

bool kgtk_webview_can_go_forward(const char* view_id) {
    KWebViewSlot* slot = kgtk_find_webview_slot(view_id);
    if (!slot || !slot->web_view) return false;
    fn_webkit_web_view_can_go_forward fn = (fn_webkit_web_view_can_go_forward)resolve_sym("webkit_web_view_can_go_forward");
    return fn ? (fn(slot->web_view) != 0) : false;
}

void kgtk_webview_execute_script(const char* view_id, const char* script) {
    KWebViewSlot* slot = kgtk_find_webview_slot(view_id);
    if (!slot || !slot->web_view || !script) return;
    fn_webkit_web_view_execute_script fn = (fn_webkit_web_view_execute_script)resolve_sym("webkit_web_view_execute_script");
    if (fn) {
        fn(slot->web_view, script);
        kgtk_widget_queue_draw(slot->web_view);
    }
}

const char* kgtk_webview_get_uri(const char* view_id) {
    KWebViewSlot* slot = kgtk_find_webview_slot(view_id);
    if (!slot || !slot->web_view) return "";
    fn_webkit_web_view_get_uri fn = (fn_webkit_web_view_get_uri)resolve_sym("webkit_web_view_get_uri");
    const char* res = fn ? fn(slot->web_view) : NULL;
    if (res && res[0]) return res;
    return slot->last_url ? slot->last_url : "";
}

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
        "return String(s).replace(/[\\r\\n|\\t]+/g,' ').replace(/\\s+/g,' ').replace(/^\\s+|\\s+$/g,'');"
        "}"
        "function resolveLbl(el){"
        "return cleanLbl(el.getAttribute('aria-label')||el.getAttribute('placeholder')||el.name||el.id||'');"
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

void kgtk_set_webview_input_focus_handler(KWebViewInputFocusCallback handler, void* user_data) {
    g_webview_input_focus_handler = handler;
    g_webview_input_focus_user_data = user_data;
}

void kgtk_webview_set_input_text(const char* view_id, const char* text) {
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
}

void kgtk_webview_submit_input(const char* view_id) {
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
}

// --- Fast Asynchronous IPv4 HTTPS Client (libcurl with Connection/TLS/DNS Pooling) ---

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
    if (g_curl.share_handle) {
        easy_setopt(curl, 10100 /* CURLOPT_SHARE */, g_curl.share_handle);
    }
    const char* env_dns = getenv("KINDLEUI_DNS_SERVERS");
    if (env_dns && env_dns[0]) {
        easy_setopt(curl, 10211 /* CURLOPT_DNS_SERVERS */, env_dns);
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


bool khttp_get_async(
    const char* url,
    int timeout_seconds,
    KHttpCallback callback,
    void* user_data
) {
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
}

