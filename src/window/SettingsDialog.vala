/*  This file is part of Cawbird, a Gtk+ linux Twitter client forked from Corebird.
 *  Copyright (C) 2013 Timm Bäder (Corebird)
 *
 *  Cawbird is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  Cawbird is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with cawbird.  If not, see <http://www.gnu.org/licenses/>.
 */

[GtkTemplate (ui = "/uk/co/ibboard/cawbird/ui/settings-dialog.ui")]
class SettingsDialog : Gtk.Window {
  [GtkChild]
  private Gtk.ComboBoxText shortcut_key_combobox;
  [GtkChild]
  private Gtk.Switch on_new_mentions_switch;
  [GtkChild]
  private Gtk.ComboBoxText tweet_scale_combobox;
  [GtkChild]
  private Gtk.Switch round_avatar_switch;
  [GtkChild]
  private Gtk.Switch on_new_dms_switch;
  [GtkChild]
  private Gtk.ComboBoxText on_new_tweets_combobox;
  [GtkChild]
  private Gtk.Switch auto_scroll_on_new_tweets_switch;
  [GtkChild]
  private Gtk.Stack main_stack;
  [GtkChild]
  private Gtk.Switch use_dark_theme_switch;
  [GtkChild]
  private Gtk.Switch double_click_activation_switch;
  [GtkChild]
  private Gtk.ListBox sample_tweet_list;
  [GtkChild]
  private Gtk.Switch remove_trailing_hashtags_switch;
  [GtkChild]
  private Gtk.Switch remove_media_links_switch;
  [GtkChild]
  private Gtk.Switch hide_nsfw_content_switch;
  [GtkChild]
  private Gtk.ListBox snippet_list_box;
  [GtkChild]
  private Gtk.ComboBoxText media_visibility_combobox;
  [GtkChild]
  private Gtk.ComboBoxText translation_service_combobox;
  [GtkChild]
  private Gtk.Entry custom_translation_entry;

  private TweetListEntry sample_tweet_entry;

  private bool block_flag_emission = false;

  public SettingsDialog (Cawbird application) {
    this.application = application;

    // Interface page
    auto_scroll_on_new_tweets_switch.notify["active"].connect (() => {
      on_new_tweets_combobox.sensitive = !auto_scroll_on_new_tweets_switch.active;
    });
    Settings.get ().bind ("shortcut-key", shortcut_key_combobox, "active-id", SettingsBindFlags.DEFAULT);
    Settings.get ().changed["shortcut-key"].connect(() => {
      ((Cawbird)get_application()).set_window_switching_accels();
    });
    Settings.get ().bind ("use-dark-theme", use_dark_theme_switch, "active", SettingsBindFlags.DEFAULT);
    use_dark_theme_switch.notify["active"].connect (() => {
      Gtk.Settings.get_default ().gtk_application_prefer_dark_theme = Settings.use_dark_theme();
    });
    Settings.get ().bind ("auto-scroll-on-new-tweets", auto_scroll_on_new_tweets_switch, "active",
                          SettingsBindFlags.DEFAULT);
    Settings.get ().bind ("double-click-activation", double_click_activation_switch,
                          "active", SettingsBindFlags.DEFAULT);
    Settings.get ().bind ("media-visibility", media_visibility_combobox, "active-id",
                          SettingsBindFlags.DEFAULT);
    Settings.get ().changed["media-visibility"].connect(() => {
      block_flag_emission = true;
      if (Settings.get_media_visiblity () == MediaVisibility.SHOW) {
        remove_media_links_switch.sensitive = true;
        remove_media_links_switch.active = (Cb.TransformFlags.REMOVE_MEDIA_LINKS in Settings.get_text_transform_flags ());
      }
      else {
        remove_media_links_switch.sensitive = false;
        remove_media_links_switch.active = false;
      }
      block_flag_emission = false;
    });
    Settings.get ().bind ("new-tweets-notify", on_new_tweets_combobox, "active-id",
        SettingsBindFlags.DEFAULT);
    Settings.get ().bind ("new-mentions-notify", on_new_mentions_switch, "active",
        SettingsBindFlags.DEFAULT);
    Settings.get ().bind ("new-dms-notify", on_new_dms_switch, "active",
        SettingsBindFlags.DEFAULT);

    // Tweets page
    Settings.get ().bind ("tweet-scale", tweet_scale_combobox, "active-id", SettingsBindFlags.DEFAULT);
    Settings.get ().bind ("round-avatars", round_avatar_switch, "active",
        SettingsBindFlags.DEFAULT);
    Settings.get ().bind ("translation-service", translation_service_combobox, "active-id", SettingsBindFlags.DEFAULT);
    Settings.get ().changed["translation-service"].connect(() => {
      set_custom_translation_sensitivity();
    });

    custom_translation_entry.text = Settings.get_custom_translation_service();
    custom_translation_entry.changed.connect(() => {
      var text = custom_translation_entry.text;
      var style_context = custom_translation_entry.get_style_context();

      if (!text.contains("{SOURCE_LANG}") || !text.contains("{TARGET_LANG}") || !text.contains("{CONTENT}")) {
        style_context.add_class("error");
      }
      else {
        style_context.remove_class("error");
        Settings.set_custom_translation_service (text);
      }
    });
    custom_translation_entry.focus_out_event.connect(() => {
      if (custom_translation_entry.get_style_context().has_class("error")) {
        var dialog = new Gtk.MessageDialog(this, Gtk.DialogFlags.MODAL, Gtk.MessageType.WARNING, Gtk.ButtonsType.OK,
                                            _("Translation URL must contain {SOURCE_LANG}, {TARGET_LANG} and {CONTENT} placeholders" + 
                                              "\n\nThe URL \"%s\" will be used instead").printf(Settings.get_custom_translation_service()));
        dialog.run();
        dialog.destroy();
        // Don't replace the text in case the user made a small typo
      }
      return Gdk.EVENT_PROPAGATE;
    });
    set_custom_translation_sensitivity();

    // Set up sample tweet {{{
    var sample_tweet = new Cb.Tweet ();
    // Not actually the same tweet, but it's our first one!
    sample_tweet.id = 1158028807959396353;
    sample_tweet.source_tweet = Cb.MiniTweet();
    sample_tweet.source_tweet.created_at = new GLib.DateTime.now_local().add_minutes(-42).to_unix();
    sample_tweet.source_tweet.author = Cb.UserIdentity() {
      id = 12,
      screen_name = "cawbirdclient",
      user_name = "Cawbird"
    };
    string sample_text = _("Hey, check out this new #Cawbird version! \\ (•◡•) / #cool #newisalwaysbetter");
    Cairo.Surface? avatar_surface = null;
    try {
      var a = Gtk.IconTheme.get_default ().load_icon ("uk.co.ibboard.cawbird",
                                                      48 * this.get_scale_factor (),
                                                      Gtk.IconLookupFlags.FORCE_SIZE);
      avatar_surface = Gdk.cairo_surface_create_from_pixbuf (a, this.get_scale_factor (), this.get_window ());
    } catch (GLib.Error e) {
      warning (e.message);
    }
    sample_tweet.source_tweet.text = sample_text;

    try {
      var regex = new GLib.Regex ("#\\w+");
      GLib.MatchInfo match_info;
      bool matched = regex.match (sample_text, 0, out match_info);
      assert (matched);

      Cb.TextEntity[] hashtags = {};

      int i = 0;
      while (match_info.matches ()) {
        assert (match_info.get_match_count () == 1);
        int from, to;
        match_info.fetch_pos (0, out from, out to);
        string match = match_info.fetch (0);
        hashtags += Cb.TextEntity () {
          from = sample_text.char_count (from),
          to   = sample_text.char_count (to),
          original_text = match,
          display_text = match,
          tooltip_text = match,
          // This should be null, but that adds a "Block #hashtag" menu item that we don't want
          // in the settings dialog
          target       = match
        };

        match_info.next ();
        i ++;
      }

      sample_tweet.source_tweet.entities = hashtags;
    } catch (GLib.RegexError e) {
      critical (e.message);
    }

    // Just to be sure
    TweetUtils.sort_entities (ref sample_tweet.source_tweet.entities);


    this.sample_tweet_entry = new TweetListEntry (sample_tweet, null,
                                                  new Account (10, "", ""));
    sample_tweet_entry.set_avatar (avatar_surface);
    sample_tweet_entry.activatable = false;
    sample_tweet_entry.read_only = true;
    sample_tweet_entry.show ();
    this.sample_tweet_list.add (sample_tweet_entry);
    // }}}

    var text_transform_flags = Settings.get_text_transform_flags ();

    block_flag_emission = true;
    remove_trailing_hashtags_switch.active = (Cb.TransformFlags.REMOVE_TRAILING_HASHTAGS in
                                              text_transform_flags);
    remove_media_links_switch.active = (Cb.TransformFlags.REMOVE_MEDIA_LINKS in text_transform_flags);
    block_flag_emission = false;

    Settings.get ().bind ("hide-nsfw-content", hide_nsfw_content_switch, "active",
                          SettingsBindFlags.DEFAULT);


    // Fill snippet list box
    Cawbird.snippet_manager.query_snippets ((key, value) => {
      var e = new SnippetListEntry ((string)key, (string)value);
      e.show_all ();
      snippet_list_box.add (e);
    });

    add_accels ();
    load_geometry ();
  }

  [GtkCallback]
  private bool window_destroy_cb () {
    save_geometry ();
    return Gdk.EVENT_PROPAGATE;
  }

  [GtkCallback]
  private void snippet_entry_activated_cb (Gtk.ListBoxRow row) {
    var snippet_row = (SnippetListEntry) row;
    var d = new ModifySnippetDialog (snippet_row.key,
                                     snippet_row.value);
    d.snippet_updated.connect (snippet_updated_func);
    d.set_transient_for (this);
    d.modal = true;
    d.show ();
  }

  [GtkCallback]
  private void add_snippet_button_clicked_cb () {
    var d = new ModifySnippetDialog ();
    d.snippet_updated.connect (snippet_updated_func);
    d.set_transient_for (this);
    d.modal = true;
    d.show ();
  }

  private void set_custom_translation_sensitivity() {
    custom_translation_entry.sensitive = Settings.get_translation_service() == TranslationService.CUSTOM;
  }

  private void snippet_updated_func (string? old_key, string? key, string? value) {
    if (old_key != null && key == null && value == null) {
      foreach (var _row in snippet_list_box.get_children ()) {
        var srow = (SnippetListEntry) _row;
        if (srow.key == old_key) {
          srow.reveal ();
          break;
        }
      }
      return;
    }

    if (old_key == null) {
      var e = new SnippetListEntry (key, value);
      e.show_all ();
      snippet_list_box.add (e);
    } else {
      foreach (var _row in snippet_list_box.get_children ()) {
        var srow = (SnippetListEntry) _row;
        if (srow.key == old_key) {
          srow.key = key;
          srow.value = value;
          break;
        }
      }
    }
  }

  private void load_geometry () {
    GLib.Variant geom = Settings.get ().get_value ("settings-geometry");
    int x = 0,
        y = 0,
        w = 0,
        h = 0;
    x = geom.get_child_value (0).get_int32 ();
    y = geom.get_child_value (1).get_int32 ();
    w = geom.get_child_value (2).get_int32 ();
    h = geom.get_child_value (3).get_int32 ();
    if (w == 0 || h == 0)
      return;

    this.move (x, y);
    this.set_default_size (w, h);
  }

  private void save_geometry () {
    var builder = new GLib.VariantBuilder (GLib.VariantType.TUPLE);
    int x = 0,
        y = 0,
        w = 0,
        h = 0;
    this.get_position (out x, out y);
    this.get_size (out w, out h);
    builder.add_value (new GLib.Variant.int32(x));
    builder.add_value (new GLib.Variant.int32(y));
    builder.add_value (new GLib.Variant.int32(w));
    builder.add_value (new GLib.Variant.int32(h));
    Settings.get ().set_value ("settings-geometry", builder.end ());
  }

  private void add_accels () {
    Gtk.AccelGroup ag = new Gtk.AccelGroup();

    ag.connect (Gdk.Key.Escape, 0, Gtk.AccelFlags.LOCKED,
        () => {this.close (); return true;});
    ag.connect (Gdk.Key.@1, Gdk.ModifierType.MOD1_MASK, Gtk.AccelFlags.LOCKED,
        () => {main_stack.visible_child_name = "interface"; return true;});
    ag.connect (Gdk.Key.@2, Gdk.ModifierType.MOD1_MASK, Gtk.AccelFlags.LOCKED,
        () => {main_stack.visible_child_name = "tweet"; return true;});
    ag.connect (Gdk.Key.@3, Gdk.ModifierType.MOD1_MASK, Gtk.AccelFlags.LOCKED,
        () => {main_stack.visible_child_name = "snippets"; return true;});


    this.add_accel_group(ag);
  }


  [GtkCallback]
  private void remove_trailing_hashtags_cb () {
    if (block_flag_emission)
      return;

    if (remove_trailing_hashtags_switch.active) {
      Settings.add_text_transform_flag (Cb.TransformFlags.REMOVE_TRAILING_HASHTAGS);
    } else {
      Settings.remove_text_transform_flag (Cb.TransformFlags.REMOVE_TRAILING_HASHTAGS);
    }
  }

  [GtkCallback]
  private void remove_media_links_cb () {
    if (block_flag_emission)
      return;

    if (remove_media_links_switch.active) {
      Settings.add_text_transform_flag (Cb.TransformFlags.REMOVE_MEDIA_LINKS);
    } else {
      Settings.remove_text_transform_flag (Cb.TransformFlags.REMOVE_MEDIA_LINKS);
    }
  }
}
