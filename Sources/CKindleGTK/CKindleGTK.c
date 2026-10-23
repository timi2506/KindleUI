#include "CKindleGTK.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#if !defined(_WIN32)
#include <dlfcn.h>
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

#if !defined(_WIN32)
static void* g_gtk_lib = NULL;
static void* g_gdk_lib = NULL;
static void* g_gobj_lib = NULL;
static void* g_glib_lib = NULL;
static void* g_pango_lib = NULL;
static void* g_lipc_lib = NULL;

// Function pointer typedefs
typedef bool (*fn_gtk_init_check)(int*, char***);
typedef void (*fn_gtk_main)(void);
typedef void (*fn_gtk_main_quit)(void);
typedef int (*fn_gtk_events_pending)(void);
typedef int (*fn_gtk_main_iteration_do)(int);

typedef KWidgetRef (*fn_gtk_window_new)(int);
typedef void (*fn_gtk_window_set_title)(KWidgetRef, const char*);
typedef void (*fn_gtk_window_set_default_size)(KWidgetRef, int, int);
typedef void (*fn_gtk_window_set_position)(KWidgetRef, int);
typedef void (*fn_gtk_window_fullscreen)(KWidgetRef);

typedef KWidgetRef (*fn_gtk_box_new_2)(int, int);
typedef void (*fn_gtk_box_pack_start)(KWidgetRef, KWidgetRef, int, int, unsigned int);
typedef void (*fn_gtk_container_add)(KWidgetRef, KWidgetRef);
typedef void (*fn_gtk_container_remove)(KWidgetRef, KWidgetRef);
typedef KGList* (*fn_gtk_container_get_children)(KWidgetRef);
typedef void (*fn_gtk_container_set_border_width)(KWidgetRef, unsigned int);
typedef void (*fn_g_list_free)(KGList*);

typedef KWidgetRef (*fn_gtk_alignment_new)(float, float, float, float);
typedef void (*fn_gtk_alignment_set_padding)(KWidgetRef, unsigned int, unsigned int, unsigned int, unsigned int);
typedef KWidgetRef (*fn_gtk_frame_new)(const char*);
typedef void (*fn_gtk_frame_set_shadow_type)(KWidgetRef, int);
typedef KWidgetRef (*fn_gtk_scrolled_window_new)(void*, void*);
typedef void (*fn_gtk_scrolled_window_set_policy)(KWidgetRef, int, int);
typedef void (*fn_gtk_scrolled_window_add_with_viewport)(KWidgetRef, KWidgetRef);
typedef KWidgetRef (*fn_gtk_event_box_new)(void);

typedef KWidgetRef (*fn_gtk_label_new)(const char*);
typedef void (*fn_gtk_label_set_text)(KWidgetRef, const char*);
typedef void (*fn_gtk_label_set_markup)(KWidgetRef, const char*);
typedef void (*fn_gtk_label_set_line_wrap)(KWidgetRef, int);
typedef void (*fn_gtk_misc_set_alignment)(KWidgetRef, float, float);

typedef KWidgetRef (*fn_gtk_button_new_with_label)(const char*);
typedef void (*fn_gtk_button_set_label)(KWidgetRef, const char*);

typedef KWidgetRef (*fn_gtk_check_button_new_with_label)(const char*);
typedef int (*fn_gtk_toggle_button_get_active)(KWidgetRef);
typedef void (*fn_gtk_toggle_button_set_active)(KWidgetRef, int);

typedef KWidgetRef (*fn_gtk_entry_new)(void);
typedef void (*fn_gtk_entry_set_text)(KWidgetRef, const char*);
typedef const char* (*fn_gtk_entry_get_text)(KWidgetRef);

typedef KWidgetRef (*fn_gtk_progress_bar_new)(void);
typedef void (*fn_gtk_progress_bar_set_fraction)(KWidgetRef, double);
typedef void (*fn_gtk_progress_bar_set_text)(KWidgetRef, const char*);

typedef KWidgetRef (*fn_gtk_hscale_new_with_range)(double, double, double);
typedef double (*fn_gtk_range_get_value)(KWidgetRef);
typedef void (*fn_gtk_range_set_value)(KWidgetRef, double);

typedef KWidgetRef (*fn_gtk_separator_new)(void);
typedef KWidgetRef (*fn_gtk_image_new_from_file)(const char*);

typedef void (*fn_gtk_widget_set_size_request)(KWidgetRef, int, int);
typedef void (*fn_gtk_widget_show)(KWidgetRef);
typedef void (*fn_gtk_widget_show_all)(KWidgetRef);
typedef void (*fn_gtk_widget_hide)(KWidgetRef);
typedef void (*fn_gtk_widget_destroy)(KWidgetRef);
typedef void (*fn_gtk_widget_queue_draw)(KWidgetRef);
typedef void (*fn_gtk_widget_modify_bg)(KWidgetRef, int, const KGdkColor*);
typedef void (*fn_gtk_widget_modify_fg)(KWidgetRef, int, const KGdkColor*);
typedef void (*fn_gtk_widget_modify_font)(KWidgetRef, void*);

typedef void* (*fn_pango_font_description_from_string)(const char*);
typedef void (*fn_pango_font_description_free)(void*);

typedef unsigned long (*fn_g_signal_connect_data)(void*, const char*, void*, void*, void*, int);

// LIPC functions on Kindle
typedef void* (*fn_LipcOpenNoName)(void);
typedef void (*fn_LipcClose)(void*);
typedef int (*fn_LipcGetIntProperty)(void*, const char*, const char*, int*);
typedef int (*fn_LipcSetIntProperty)(void*, const char*, const char*, int);
typedef int (*fn_LipcSetStringProperty)(void*, const char*, const char*, const char*);

static void* resolve_sym(const char* name) {
    void* sym = NULL;
    if (g_gtk_lib && (sym = dlsym(g_gtk_lib, name))) return sym;
    if (g_gdk_lib && (sym = dlsym(g_gdk_lib, name))) return sym;
    if (g_gobj_lib && (sym = dlsym(g_gobj_lib, name))) return sym;
    if (g_glib_lib && (sym = dlsym(g_glib_lib, name))) return sym;
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
    g_gobj_lib = dlopen("libgobject-2.0.so.0", RTLD_LAZY | RTLD_GLOBAL);
    g_glib_lib = dlopen("libglib-2.0.so.0", RTLD_LAZY | RTLD_GLOBAL);
    g_pango_lib = dlopen("libpango-1.0.so.0", RTLD_LAZY | RTLD_GLOBAL);
    g_lipc_lib = dlopen("liblipc.so", RTLD_LAZY | RTLD_GLOBAL);

    fn_gtk_init_check init_fn = (fn_gtk_init_check)resolve_sym("gtk_init_check");
    if (!init_fn) return false;
    int argc = 0;
    char** argv = NULL;
    return init_fn(&argc, &argv);
#endif
}

void kgtk_main(void) {
#if !defined(_WIN32)
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
        while (pending()) {
            iter(0);
        }
    }
#endif
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

void kgtk_window_set_default_size(KWidgetRef window, int width, int height) {
#if !defined(_WIN32)
    fn_gtk_window_set_default_size fn = (fn_gtk_window_set_default_size)resolve_sym("gtk_window_set_default_size");
    if (fn && window) fn(window, width, height);
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

KWidgetRef kgtk_vbox_new(bool homogeneous, int spacing) {
#if !defined(_WIN32)
    fn_gtk_box_new_2 fn = (fn_gtk_box_new_2)resolve_sym("gtk_vbox_new");
    if (fn) return fn(homogeneous ? 1 : 0, spacing);
#endif
    return NULL;
}

KWidgetRef kgtk_hbox_new(bool homogeneous, int spacing) {
#if !defined(_WIN32)
    fn_gtk_box_new_2 fn = (fn_gtk_box_new_2)resolve_sym("gtk_hbox_new");
    if (fn) return fn(homogeneous ? 1 : 0, spacing);
#endif
    return NULL;
}

void kgtk_box_pack_start(KWidgetRef box, KWidgetRef child, bool expand, bool fill, int padding) {
#if !defined(_WIN32)
    fn_gtk_box_pack_start fn = (fn_gtk_box_pack_start)resolve_sym("gtk_box_pack_start");
    if (fn && box && child) fn(box, child, expand ? 1 : 0, fill ? 1 : 0, (unsigned int)padding);
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
    if (fn && container) fn(container, (unsigned int)border_width);
#endif
}

KWidgetRef kgtk_alignment_new(float xalign, float yalign, float xscale, float yscale) {
#if !defined(_WIN32)
    fn_gtk_alignment_new fn = (fn_gtk_alignment_new)resolve_sym("gtk_alignment_new");
    if (fn) return fn(xalign, yalign, xscale, yscale);
#endif
    return NULL;
}

void kgtk_alignment_set_padding(KWidgetRef alignment, int top, int bottom, int left, int right) {
#if !defined(_WIN32)
    fn_gtk_alignment_set_padding fn = (fn_gtk_alignment_set_padding)resolve_sym("gtk_alignment_set_padding");
    if (fn && alignment) fn(alignment, (unsigned int)top, (unsigned int)bottom, (unsigned int)left, (unsigned int)right);
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

KWidgetRef kgtk_scrolled_window_new(void) {
#if !defined(_WIN32)
    fn_gtk_scrolled_window_new fn = (fn_gtk_scrolled_window_new)resolve_sym("gtk_scrolled_window_new");
    fn_gtk_scrolled_window_set_policy policy_fn = (fn_gtk_scrolled_window_set_policy)resolve_sym("gtk_scrolled_window_set_policy");
    if (fn) {
        KWidgetRef sw = fn(NULL, NULL);
        if (policy_fn && sw) {
            // GTK_POLICY_AUTOMATIC = 1
            policy_fn(sw, 1, 1);
        }
        return sw;
    }
#endif
    return NULL;
}

void kgtk_scrolled_window_add_with_viewport(KWidgetRef scrolled_window, KWidgetRef child) {
#if !defined(_WIN32)
    fn_gtk_scrolled_window_add_with_viewport fn = (fn_gtk_scrolled_window_add_with_viewport)resolve_sym("gtk_scrolled_window_add_with_viewport");
    if (fn && scrolled_window && child) fn(scrolled_window, child);
#endif
}

KWidgetRef kgtk_event_box_new(void) {
#if !defined(_WIN32)
    fn_gtk_event_box_new fn = (fn_gtk_event_box_new)resolve_sym("gtk_event_box_new");
    if (fn) return fn();
#endif
    return NULL;
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

void kgtk_label_set_line_wrap(KWidgetRef label, bool wrap) {
#if !defined(_WIN32)
    fn_gtk_label_set_line_wrap fn = (fn_gtk_label_set_line_wrap)resolve_sym("gtk_label_set_line_wrap");
    if (fn && label) fn(label, wrap ? 1 : 0);
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

KWidgetRef kgtk_image_new_from_file(const char* filename) {
#if !defined(_WIN32)
    fn_gtk_image_new_from_file fn = (fn_gtk_image_new_from_file)resolve_sym("gtk_image_new_from_file");
    if (fn && filename) return fn(filename);
#endif
    return NULL;
}

void kgtk_widget_set_size_request(KWidgetRef widget, int width, int height) {
#if !defined(_WIN32)
    fn_gtk_widget_set_size_request fn = (fn_gtk_widget_set_size_request)resolve_sym("gtk_widget_set_size_request");
    if (fn && widget) fn(widget, width, height);
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

void kgtk_widget_modify_bg_gray(KWidgetRef widget, int state, uint8_t gray_level) {
#if !defined(_WIN32)
    fn_gtk_widget_modify_bg fn = (fn_gtk_widget_modify_bg)resolve_sym("gtk_widget_modify_bg");
    if (fn && widget) {
        uint16_t c16 = ((uint16_t)gray_level << 8) | gray_level;
        KGdkColor color = { 0, c16, c16, c16 };
        fn(widget, state, &color);
    }
#endif
}

void kgtk_widget_modify_fg_gray(KWidgetRef widget, int state, uint8_t gray_level) {
#if !defined(_WIN32)
    fn_gtk_widget_modify_fg fn = (fn_gtk_widget_modify_fg)resolve_sym("gtk_widget_modify_fg");
    if (fn && widget) {
        uint16_t c16 = ((uint16_t)gray_level << 8) | gray_level;
        KGdkColor color = { 0, c16, c16, c16 };
        fn(widget, state, &color);
    }
#endif
}

void kgtk_widget_modify_font_string(KWidgetRef widget, const char* font_desc_str) {
#if !defined(_WIN32)
    fn_gtk_widget_modify_font modify_fn = (fn_gtk_widget_modify_font)resolve_sym("gtk_widget_modify_font");
    fn_pango_font_description_from_string from_str = (fn_pango_font_description_from_string)resolve_sym("pango_font_description_from_string");
    fn_pango_font_description_free free_fn = (fn_pango_font_description_free)resolve_sym("pango_font_description_free");
    if (modify_fn && from_str && widget && font_desc_str) {
        void* desc = from_str(font_desc_str);
        if (desc) {
            modify_fn(widget, desc);
            if (free_fn) free_fn(desc);
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
    if (!klipc_is_available()) return -1;
    fn_LipcOpenNoName open_fn = (fn_LipcOpenNoName)dlsym(g_lipc_lib, "LipcOpenNoName");
    fn_LipcClose close_fn = (fn_LipcClose)dlsym(g_lipc_lib, "LipcClose");
    fn_LipcGetIntProperty get_fn = (fn_LipcGetIntProperty)dlsym(g_lipc_lib, "LipcGetIntProperty");
    if (!open_fn || !close_fn || !get_fn) return -1;
    void* handle = open_fn();
    if (!handle) return -1;
    int res = get_fn(handle, service, prop, out_val);
    close_fn(handle);
    return res;
#else
    return -1;
#endif
}

int klipc_set_int_property(const char* service, const char* prop, int val) {
#if !defined(_WIN32)
    if (!klipc_is_available()) return -1;
    fn_LipcOpenNoName open_fn = (fn_LipcOpenNoName)dlsym(g_lipc_lib, "LipcOpenNoName");
    fn_LipcClose close_fn = (fn_LipcClose)dlsym(g_lipc_lib, "LipcClose");
    fn_LipcSetIntProperty set_fn = (fn_LipcSetIntProperty)dlsym(g_lipc_lib, "LipcSetIntProperty");
    if (!open_fn || !close_fn || !set_fn) return -1;
    void* handle = open_fn();
    if (!handle) return -1;
    int res = set_fn(handle, service, prop, val);
    close_fn(handle);
    return res;
#else
    return -1;
#endif
}

int klipc_set_string_property(const char* service, const char* prop, const char* val) {
#if !defined(_WIN32)
    if (!klipc_is_available()) return -1;
    fn_LipcOpenNoName open_fn = (fn_LipcOpenNoName)dlsym(g_lipc_lib, "LipcOpenNoName");
    fn_LipcClose close_fn = (fn_LipcClose)dlsym(g_lipc_lib, "LipcClose");
    fn_LipcSetStringProperty set_fn = (fn_LipcSetStringProperty)dlsym(g_lipc_lib, "LipcSetStringProperty");
    if (!open_fn || !close_fn || !set_fn) return -1;
    void* handle = open_fn();
    if (!handle) return -1;
    int res = set_fn(handle, service, prop, val);
    close_fn(handle);
    return res;
#else
    return -1;
#endif
}
