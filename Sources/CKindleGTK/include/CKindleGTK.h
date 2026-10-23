#ifndef CKINDLE_GTK_H
#define CKINDLE_GTK_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef void* KWidgetRef;
typedef void (*KSignalCallback)(KWidgetRef widget, void* user_data);

/// Initializes GTK+-2.0 dynamically if available on the host/Kindle.
/// Returns true if GTK+-2.0 was loaded and initialized successfully.
bool kgtk_init(void);

/// Runs the GTK main event loop.
void kgtk_main(void);

/// Quits the GTK main event loop.
void kgtk_main_quit(void);

/// Processes pending GTK events without blocking.
void kgtk_drain_events(void);

// --- Window Management ---
KWidgetRef kgtk_window_new(int window_type);
void kgtk_window_set_title(KWidgetRef window, const char* title);
void kgtk_window_set_default_size(KWidgetRef window, int width, int height);
void kgtk_window_set_position(KWidgetRef window, int position);
void kgtk_window_fullscreen(KWidgetRef window);

// --- Containers & Layout ---
KWidgetRef kgtk_vbox_new(bool homogeneous, int spacing);
KWidgetRef kgtk_hbox_new(bool homogeneous, int spacing);
void kgtk_box_pack_start(KWidgetRef box, KWidgetRef child, bool expand, bool fill, int padding);
void kgtk_container_add(KWidgetRef container, KWidgetRef widget);
void kgtk_container_remove(KWidgetRef container, KWidgetRef widget);
void kgtk_container_clear(KWidgetRef container);
void kgtk_container_set_border_width(KWidgetRef container, int border_width);
KWidgetRef kgtk_alignment_new(float xalign, float yalign, float xscale, float yscale);
void kgtk_alignment_set_padding(KWidgetRef alignment, int top, int bottom, int left, int right);
KWidgetRef kgtk_frame_new(const char* label);
void kgtk_frame_set_shadow_type(KWidgetRef frame, int shadow_type);
KWidgetRef kgtk_scrolled_window_new(void);
void kgtk_scrolled_window_add_with_viewport(KWidgetRef scrolled_window, KWidgetRef child);
KWidgetRef kgtk_event_box_new(void);

// --- Widgets ---
KWidgetRef kgtk_label_new(const char* text);
void kgtk_label_set_text(KWidgetRef label, const char* text);
void kgtk_label_set_markup(KWidgetRef label, const char* markup);
void kgtk_label_set_line_wrap(KWidgetRef label, bool wrap);
void kgtk_misc_set_alignment(KWidgetRef misc, float xalign, float yalign);

KWidgetRef kgtk_button_new_with_label(const char* label);
void kgtk_button_set_label(KWidgetRef button, const char* label);

KWidgetRef kgtk_check_button_new_with_label(const char* label);
bool kgtk_toggle_button_get_active(KWidgetRef toggle_button);
void kgtk_toggle_button_set_active(KWidgetRef toggle_button, bool is_active);

KWidgetRef kgtk_entry_new(void);
void kgtk_entry_set_text(KWidgetRef entry, const char* text);
const char* kgtk_entry_get_text(KWidgetRef entry);

KWidgetRef kgtk_progress_bar_new(void);
void kgtk_progress_bar_set_fraction(KWidgetRef pbar, double fraction);
void kgtk_progress_bar_set_text(KWidgetRef pbar, const char* text);

KWidgetRef kgtk_hscale_new_with_range(double min, double max, double step);
double kgtk_range_get_value(KWidgetRef range);
void kgtk_range_set_value(KWidgetRef range, double value);

KWidgetRef kgtk_hseparator_new(void);
KWidgetRef kgtk_vseparator_new(void);
KWidgetRef kgtk_image_new_from_file(const char* filename);

// --- Styling & Geometry ---
void kgtk_widget_set_size_request(KWidgetRef widget, int width, int height);
void kgtk_widget_show(KWidgetRef widget);
void kgtk_widget_show_all(KWidgetRef widget);
void kgtk_widget_hide(KWidgetRef widget);
void kgtk_widget_destroy(KWidgetRef widget);
void kgtk_widget_queue_draw(KWidgetRef widget);
void kgtk_widget_modify_bg_gray(KWidgetRef widget, int state, uint8_t gray_level);
void kgtk_widget_modify_fg_gray(KWidgetRef widget, int state, uint8_t gray_level);
void kgtk_widget_modify_font_string(KWidgetRef widget, const char* font_desc_str);

// --- Signals ---
unsigned long kgtk_signal_connect(KWidgetRef instance, const char* detailed_signal, KSignalCallback callback, void* user_data);

// --- Kindle LIPC Hardware Integration ---
bool klipc_is_available(void);
int klipc_get_int_property(const char* service, const char* prop, int* out_val);
int klipc_set_int_property(const char* service, const char* prop, int val);
int klipc_set_string_property(const char* service, const char* prop, const char* val);

#ifdef __cplusplus
}
#endif

#endif // CKINDLE_GTK_H
