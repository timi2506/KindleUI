#pragma once
#include <gtk-2.0/gtk/gtk.h>
#include <string>
#include <functional>
#include <vector>

namespace kindleui {

inline void apply_font(GtkWidget* widget, const char* font_desc_str) {
    if (!widget || !font_desc_str) return;
    PangoFontDescription* desc = pango_font_description_from_string(font_desc_str);
    if (desc) {
        gtk_widget_modify_font(widget, desc);
        pango_font_description_free(desc);
    }
}

inline void apply_gray_bg(GtkWidget* widget, guint8 gray) {
    if (!widget) return;
    guint16 c16 = (static_cast<guint16>(gray) << 8) | gray;
    GdkColor color = { 0, c16, c16, c16 };
    gtk_widget_modify_bg(widget, GTK_STATE_NORMAL, &color);
}

inline void apply_gray_fg(GtkWidget* widget, guint8 gray) {
    if (!widget) return;
    guint16 c16 = (static_cast<guint16>(gray) << 8) | gray;
    GdkColor color = { 0, c16, c16, c16 };
    gtk_widget_modify_fg(widget, GTK_STATE_NORMAL, &color);
}

inline GtkWidget* wrap_padding(GtkWidget* child, guint top, guint bottom, guint left, guint right) {
    GtkWidget* align = gtk_alignment_new(0.0f, 0.0f, 1.0f, 1.0f);
    gtk_alignment_set_padding(GTK_ALIGNMENT(align), top, bottom, left, right);
    gtk_container_add(GTK_CONTAINER(align), child);
    return align;
}

} // namespace kindleui