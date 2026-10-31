#ifndef CKINDLE_GTK_H
#define CKINDLE_GTK_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef void* KWidgetRef;
typedef void* KCairoRef;
typedef void (*KSignalCallback)(KWidgetRef widget, void* user_data);
typedef void (*KIdleCallback)(void* user_data);
typedef void (*KCanvasExposeCallback)(KWidgetRef widget, int width, int height, void* user_data);
typedef void (*KCanvasPointerCallback)(KWidgetRef widget, int phase, int x, int y, void* user_data);
typedef void (*KGestureCallback)(int gesture_type, int dx, int dy, void* user_data);
typedef void (*KCairoExposeCallback)(
    KWidgetRef widget,
    KCairoRef cr,
    double x,
    double y,
    double width,
    double height,
    void* user_data
);

/// Initializes GTK+-2.0 dynamically if available on the host/Kindle.
/// Returns true if GTK+-2.0 was loaded and initialized successfully.
bool kgtk_init(void);

/// Runs the GTK main event loop.
void kgtk_main(void);

/// Quits the GTK main event loop.
void kgtk_main_quit(void);

/// Synchronously runs pending container resizes, processes all GDK window expose updates, and flushes X11 output.
void kgtk_flush_updates(KWidgetRef window);

/// Freezes or thaws GDK window expose updates on the root window during atomic UI rebuilds.
void kgtk_window_freeze_updates(KWidgetRef window);
void kgtk_window_thaw_updates(KWidgetRef window);

/// Flushes container resizes and GDK window expose updates during a live slider drag without draining pending X11 motion events re-entrantly.
void kgtk_flush_live_drag(KWidgetRef window);

/// Returns (and clears) the interactive button whose post-click repaint was deferred because a UI update was pending.
/// A renderer that applies that update in place must redraw the returned widget itself; NULL if none.
KWidgetRef kgtk_take_suppressed_redraw_widget(void);

/// Resets the persisted vertical scroll position (e.g. when switching tabs or pushing/popping navigation).
void kgtk_reset_scroll_position(void);

/// Sets or queries the active vertical scroll offset (in pixels).
void kgtk_set_scroll_position(double y);
double kgtk_get_scroll_position(void);

/// Schedules a one-shot callback on the GLib/GTK main loop idle queue.
void kgtk_schedule_idle(KIdleCallback callback, void* user_data);

/// Returns true if the user is currently dragging a slider.
bool kgtk_is_slider_dragging(void);

/// Resets the slider dragging flag.
void kgtk_reset_slider_dragging(void);

/// Queries the default GDK screen dimensions (or defaults to simulated Paperwhite 5 1236x1648 if unavailable).
void kgtk_get_screen_size(int* out_width, int* out_height);

/// Overrides the simulated screen pixel dimensions when running outside X11/GDK (e.g. in KindlePreviewServer).
void kgtk_set_simulated_screen_size(int width, int height);

/// Returns the device UI scale factor relative to the 1860x2480 reference grid (e.g. 1.0 on Scribe, 0.58 on PW3/4, 0.41 on PW1/2, 0.32 on Touch).
double kgtk_get_ui_scale(void);

/// Scales a logical layout coordinate into physical screen pixels using kgtk_get_ui_scale().
int kgtk_scale_px(int val);

// --- Window Management ---
KWidgetRef kgtk_window_new(int window_type);
void kgtk_window_set_title(KWidgetRef window, const char* title);
void kgtk_window_set_default_size(KWidgetRef window, int width, int height);
void kgtk_window_set_position(KWidgetRef window, int position);
void kgtk_window_connect_quit_keys(KWidgetRef window, KIdleCallback on_quit, void* user_data);

// --- Containers & Layout ---
KWidgetRef kgtk_vbox_new(bool homogeneous, int spacing);
KWidgetRef kgtk_hbox_new(bool homogeneous, int spacing);
void kgtk_box_pack_start(KWidgetRef box, KWidgetRef child, bool expand, bool fill, int padding);
void kgtk_container_add(KWidgetRef container, KWidgetRef widget);
void kgtk_container_clear(KWidgetRef container);
KWidgetRef kgtk_alignment_new(float xalign, float yalign, float xscale, float yscale);
void kgtk_alignment_set_padding(KWidgetRef alignment, int top, int bottom, int left, int right);
KWidgetRef kgtk_scrolled_window_new(void);
void kgtk_scrolled_window_add_with_viewport(KWidgetRef scrolled_window, KWidgetRef child);
void kgtk_scrolled_window_set_bg_gray(KWidgetRef scrolled_window, uint8_t gray_level);
void kgtk_scrolled_window_set_show_indicators(KWidgetRef scrolled_window, bool show_indicators);
KWidgetRef kgtk_frozen_scrolled_view_new(uint8_t bg_gray);
void kgtk_frozen_scrolled_view_add(KWidgetRef frozen_view, KWidgetRef child);
KWidgetRef kgtk_nowindow_canvas_new(void);
KWidgetRef kgtk_event_box_new(void);
KWidgetRef kgtk_zstack_new(void);
void kgtk_zstack_add(KWidgetRef zstack, KWidgetRef child);
void kgtk_widget_set_sensitive(KWidgetRef widget, bool sensitive);

// --- Widgets ---
KWidgetRef kgtk_label_new(const char* text);
void kgtk_label_set_text(KWidgetRef label, const char* text);
void kgtk_label_set_markup(KWidgetRef label, const char* markup);
void kgtk_label_set_line_wrap(KWidgetRef label, bool wrap);
void kgtk_label_set_justify(KWidgetRef label, int justify);
void kgtk_misc_set_alignment(KWidgetRef misc, float xalign, float yalign);
KWidgetRef kgtk_entry_new(void);
void kgtk_entry_set_text(KWidgetRef entry, const char* text);
const char* kgtk_entry_get_text(KWidgetRef entry);
KWidgetRef kgtk_image_new_from_file_scaled(const char* filename, int max_width, int max_height);

// --- Cairo Drawing Primitives (Used by Swift E-Ink Widgets) ---
void kgtk_connect_cairo_expose(
    KWidgetRef widget,
    KCairoExposeCallback on_expose,
    void* user_data,
    KIdleCallback on_destroy
);
void kgtk_connect_cairo_expose_cached(
    KWidgetRef widget,
    uint64_t cache_key,
    uint8_t clear_bg_gray,
    KCairoExposeCallback on_expose,
    void* user_data,
    KIdleCallback on_destroy
);
void kcairo_set_gray(KCairoRef cr, uint8_t gray);
void kcairo_set_gray_alpha(KCairoRef cr, uint8_t gray, double alpha);
void kcairo_set_line_width(KCairoRef cr, double width);
void kcairo_set_line_round(KCairoRef cr);
void kcairo_new_path(KCairoRef cr);
void kcairo_close_path(KCairoRef cr);
void kcairo_move_to(KCairoRef cr, double x, double y);
void kcairo_line_to(KCairoRef cr, double x, double y);
void kcairo_arc(KCairoRef cr, double xc, double yc, double radius, double angle1, double angle2);
void kcairo_rectangle(KCairoRef cr, double x, double y, double width, double height);
void kcairo_rounded_rect(KCairoRef cr, double x, double y, double width, double height, double radius);
void kcairo_fill(KCairoRef cr);
void kcairo_stroke(KCairoRef cr);

// --- Interactive E-Ink Containers & Controls ---
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
);

void kgtk_styled_box_set_shape(
    KWidgetRef widget,
    int tl,
    int tr,
    int br,
    int bl,
    bool is_ellipse
);

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
);

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
);
double kgtk_custom_slider_get_value(KWidgetRef slider);

KWidgetRef kgtk_gesture_box_new(
    KWidgetRef child,
    int long_press_ms,
    int swipe_threshold_px,
    KGestureCallback on_gesture,
    void* user_data
);

KWidgetRef kgtk_text_editor_new(
    const char* text,
    int min_height,
    uint8_t fg_gray,
    uint8_t bg_gray,
    const char* font_desc,
    KSignalCallback on_changed,
    void* user_data
);
char* kgtk_text_editor_get_text(KWidgetRef editor);
void kgtk_free_string(char* str);

// --- Embedded WebKitGTK 1.0 WebView (libwebkitgtk-1.0.so.0) ---
bool kgtk_webkit_available(void);
KWidgetRef kgtk_webview_obtain(
    const char* view_id,
    const char* url,
    const char* html,
    const char* base_url,
    double zoom_level,
    int min_height,
    KIdleCallback on_load_finished,
    void* user_data
);
void kgtk_webview_load_uri(const char* view_id, const char* uri);
void kgtk_webview_load_html(const char* view_id, const char* html, const char* base_uri);
void kgtk_webview_reload(const char* view_id);
void kgtk_webview_stop_loading(const char* view_id);
void kgtk_webview_go_back(const char* view_id);
void kgtk_webview_go_forward(const char* view_id);
bool kgtk_webview_can_go_back(const char* view_id);
bool kgtk_webview_can_go_forward(const char* view_id);
void kgtk_webview_execute_script(const char* view_id, const char* script);
const char* kgtk_webview_get_uri(const char* view_id);

typedef void (*KWebViewInputFocusCallback)(
    const char* view_id,
    const char* label,
    const char* current_value,
    bool is_secure,
    bool is_multiline,
    bool is_numeric,
    void* user_data
);
void kgtk_set_webview_input_focus_handler(KWebViewInputFocusCallback handler, void* user_data);
void kgtk_webview_set_input_text(const char* view_id, const char* text);
void kgtk_webview_submit_input(const char* view_id);

// --- Interactive E-Ink Drawing Canvas (GtkDrawingArea) ---
KWidgetRef kgtk_drawing_area_new(void);
void kgtk_widget_get_size(KWidgetRef widget, int* out_width, int* out_height);
void kgtk_widget_queue_draw_rect(KWidgetRef widget, int x, int y, int width, int height);
void kgtk_draw_gray_pixels(KWidgetRef widget, const uint8_t* pixels, int width, int height, int stride);
void kgtk_drawing_area_connect(
    KWidgetRef widget,
    KCanvasExposeCallback on_expose,
    KCanvasPointerCallback on_pointer,
    void* user_data
);

// --- Styling & Geometry ---
void kgtk_widget_set_size_request(KWidgetRef widget, int width, int height);
void kgtk_widget_show_all(KWidgetRef widget);
void kgtk_widget_queue_draw(KWidgetRef widget);
void kgtk_widget_modify_bg_gray(KWidgetRef widget, int state, uint8_t gray_level);
void kgtk_widget_modify_fg_gray(KWidgetRef widget, int state, uint8_t gray_level);
void kgtk_widget_modify_font_string(KWidgetRef widget, const char* font_desc_str);
void kgtk_widget_set_font_and_fg(KWidgetRef widget, const char* font_desc_str, bool has_fg, uint8_t fg_gray);

// --- Signals ---
unsigned long kgtk_signal_connect(KWidgetRef instance, const char* detailed_signal, KSignalCallback callback, void* user_data);

// --- Kindle LIPC Hardware Integration ---
bool klipc_is_available(void);
int klipc_get_int_property(const char* service, const char* prop, int* out_val);
int klipc_set_int_property(const char* service, const char* prop, int val);
int klipc_get_string_property(const char* service, const char* prop, char* out_buf, int buf_len);
int klipc_set_string_property(const char* service, const char* prop, const char* val);

// --- Fast Asynchronous IPv4 HTTPS Client (libcurl) ---
typedef void (*KHttpCallback)(
    int status_code,
    const uint8_t* data,
    int data_len,
    const char* error_msg,
    void* user_data
);
bool khttp_get_async(
    const char* url,
    int timeout_seconds,
    KHttpCallback callback,
    void* user_data
);

// --- Global Key Handler Hook (for On-Screen / Hardware Keyboard routing) ---
typedef bool (*KWindowKeyCallback)(unsigned int keyval, void* user_data);
void kgtk_set_global_key_handler(KWindowKeyCallback handler, void* user_data);

#ifdef __cplusplus
}
#endif

#endif // CKINDLE_GTK_H
