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
public struct UserInfo {
  int64 id;
  string name;
  string screen_name;
  string description;
  string avatar_url;
  string? banner_url;
  string website;
}

public class Twitter : GLib.Object {
  private static Twitter twitter;

  private Twitter () {}
  public static new Twitter get () {
    if (twitter == null)
      twitter = new Twitter ();

    return twitter;
  }

  [Signal (detailed = true)]
  private signal void avatar_downloaded (Cairo.Surface avatar);

  // Limit was once 3MB for GIFs and 5MB for images and Corebird used 3MB throughout.
  // In 2020 it's 5MB image, 15MB GIF and video - https://developer.twitter.com/en/docs/media/upload-media/overview
  public const int MAX_BYTES_PER_IMAGE    = 1024 * 1024 * 5;
  public const int MAX_BYTES_PER_GIF      = 1024 * 1024 * 15;
  public const int MAX_BYTES_PER_VIDEO    = 1024 * 1024 * 15;
  public const int short_url_length       = 23;
  public const int max_media_per_upload   = 4;
  public static Cairo.Surface no_avatar;
  public static Gdk.Pixbuf no_banner;
  private Cb.AvatarCache avatar_cache;
  private GLib.HashTable<int64?, Json.Node> user_json_cache;

  public void init () {
    try {
      Twitter.no_avatar = Gdk.cairo_surface_create_from_pixbuf (
                               new Gdk.Pixbuf.from_resource ("/uk/co/ibboard/cawbird/data/no_avatar.png"),
                               1,
                               null);
      Twitter.no_banner = new Gdk.Pixbuf.from_resource ("/uk/co/ibboard/cawbird/data/no_banner.png");
    } catch (GLib.Error e) {
      error ("Error while loading assets: %s", e.message);
    }

    this.avatar_cache = new Cb.AvatarCache ();
    this.user_json_cache = new HashTable<int64?, Json.Node>(GLib.int_hash, GLib.int_equal);
  }

  public void ref_avatar (Cairo.Surface surface) {
    this.avatar_cache.increase_refcount_for_surface (surface);
  }

  public void unref_avatar (Cairo.Surface surface) {
    this.avatar_cache.decrease_refcount_for_surface (surface);
  }

  public bool has_avatar (int64 user_id) {
    return (get_cached_avatar (user_id) != Twitter.no_avatar);
  }

  public Cairo.Surface get_cached_avatar (int64 user_id) {
    bool found;
    Cairo.Surface? surface = this.avatar_cache.get_surface_for_id (user_id, out found);
    if (surface == null)
      return Twitter.no_avatar;
    else
      return surface;
  }

  /* This is a get_avatar version for times where we don't have an at least
     relatively recent avatar_url for the given account.

     This will first query the account details of the given account,
     then use the avatar_url to download the avatar and insert it
     into the avatar cache */
  public async Cairo.Surface? load_avatar_for_user_id (Account account,
                                                       int64   user_id,
                                                       int     size) {
    Cairo.Surface? s;
    bool found = false;

    s = avatar_cache.get_surface_for_id (user_id, out found);

    if (s != null) {
      assert (found);
      return s;
    }

    if (s == null && found) {
      ulong handler_id = 0;
      handler_id = this.avatar_downloaded[user_id.to_string ()].connect ((ava) => {
        s = ava;
        this.disconnect (handler_id);
        this.load_avatar_for_user_id.callback ();
      });
      yield;

      assert (s != null);
      return s;
    }

    this.avatar_cache.add (user_id, null, null);

    string avatar_url = yield this.get_user_string_member (account, user_id, "profile_image_url_https");

    if (avatar_url == null) {
      return null;
    }

    this.avatar_cache.set_url (user_id, avatar_url);

    s = yield this.get_surface(user_id, avatar_url, size, true);

    if (s != null)
      return s;
    else
      yield;

    return s;
  }


  /**
   * Get the avatar with the given url. If the avatar exists on the
   * hard drive already, it is loaded and returned immediately. If
   * the avatar is in memory already, that version is returned.
   * If the avatar is neither on disk nor in memory, it will be downladed
   * first and set via the supplied `func`.
   */
  public async void get_avatar (int64        user_id,
                                string       url,
                                AvatarWidget dest_widget,
                                int          size = 48,
                                bool         force_download = false) {
    dest_widget.surface = yield this.get_surface (user_id, url, size, force_download);
  }

  private async Cairo.Surface? get_surface (int64  user_id,
                                            string url,
                                            int    size = 48,
                                            bool   force_download = false) {
    assert (user_id > 0);
    bool has_key = false;
    Cairo.Surface? a = this.avatar_cache.get_surface_for_id (user_id, out has_key);

    bool new_url = a == Twitter.no_avatar &&
                        url != this.avatar_cache.get_url_for_id (user_id);

    if (a != null && !new_url) {
      return a;
    }

    if (has_key && !new_url && !force_download) {
      // wait until the avatar has finished downloading
      ulong handler_id = 0;
      handler_id = this.avatar_downloaded[user_id.to_string ()].connect ((ava) => {
        this.disconnect (handler_id);
        a = ava;
        get_surface.callback ();
      });
      yield;
      return a;
    } else {
      // download the avatar
      this.avatar_cache.add (user_id, null, url);
      Gdk.Pixbuf? avatar = null;
      try {
        avatar = yield TweetUtils.download_avatar (url, size);
      } catch (GLib.Error e) {
        warning ("%s for %s", e.message, url);
      }

      Cairo.Surface s;
      // E.g. in the 404 case...
      if (avatar == null)
        s = Twitter.no_avatar;
      else
        s = Gdk.cairo_surface_create_from_pixbuf (avatar, 1, null);

      // a NULL surface is already in the cache
      this.avatar_cache.set_avatar (user_id, s, url);

      // signal all the other waiters in the queue
      avatar_downloaded[user_id.to_string ()](s);
      return s;
    }
  }

  public async string get_user_name (Account account, int64 user_id) {
    return yield get_user_string_member (account, user_id, "name");
  }

  public async string get_screen_name (Account account, int64 user_id) {
    return yield get_user_string_member (account, user_id, "screen_name");
  }

  public async string get_avatar_url (Account account, int64 user_id) {
    return yield get_user_string_member (account, user_id, "profile_image_url_https");
  }

  private async string get_user_string_member (Account account, int64 user_id, string field_name) {
    Json.Node? user_json = yield get_user_json_by_id (account.proxy, user_id);
    string username = null;
    if (user_json != null) {
      username = user_json.get_object ().get_string_member (field_name);
    }
    return username;
  }

  private async Json.Node? get_user_json_by_id (Rest.OAuthProxy proxy, int64 user_id) {
    if (this.user_json_cache.contains (user_id)) {
      return this.user_json_cache[user_id];
    }

    Json.Node? root = null;
    try {
      root = yield get_user_json (proxy, null, user_id);
      this.user_json_cache[user_id] = root;
    } catch (GLib.Error e) {
      warning (e.message);
    }

    return root;
  }

  private async Json.Node? get_user_json (Rest.OAuthProxy proxy, string? screen_name, int64 user_id) throws GLib.Error {
    var call = proxy.new_call ();
    call.set_function ("1.1/users/show.json");
    call.set_method ("GET");
    if (screen_name != null) {
      call.add_param ("screen_name", screen_name);
    } else {
      call.add_param ("user_id", user_id.to_string ());
    }

    return yield Cb.Utils.load_threaded_async (call, null);
  }
  
  public async UserInfo get_user_info_by_screen_name(Rest.OAuthProxy proxy, string screen_name) throws GLib.Error {
    return yield get_user_info (proxy, screen_name, -1);
  }
  
  public async UserInfo get_user_info_by_user_id(Rest.OAuthProxy proxy, int64 user_id) throws GLib.Error {
    return yield get_user_info (proxy, null, user_id);
  }

  private async UserInfo get_user_info(Rest.OAuthProxy proxy, string? screen_name, int64 user_id) throws GLib.Error {
    return parse_user_info (yield get_user_json(proxy, screen_name, user_id));
  }

  public async UserInfo get_own_user_info(Rest.OAuthProxy proxy) throws GLib.Error {
    var call = proxy.new_call ();
    call.set_function ("1.1/account/verify_credentials.json");
    call.set_method ("GET");
    call.add_param ("include_entities", "true");
    call.add_param ("skip_status", "true");
    return parse_user_info(yield Cb.Utils.load_threaded_async (call, null));
  }

  private UserInfo parse_user_info(Json.Node root_node) {
    var user_info = UserInfo();
    var root = root_node.get_object ();
    user_info.id = root.get_int_member ("id");
    user_info.name = root.get_string_member ("name");
    user_info.screen_name = root.get_string_member ("screen_name");
    Json.Array desc_urls = root.get_object_member ("entities").get_object_member ("description")
                                                              .get_array_member ("urls");
    var urls = new Cb.TextEntity[desc_urls.get_length ()];
    desc_urls.foreach_element ((arr, index, node) => {
      Json.Object obj = node.get_object ();
      Json.Array indices = obj.get_array_member ("indices");
      urls[index] = Cb.TextEntity () {
        from = (uint)indices.get_int_element (0),
        to   = (uint)indices.get_int_element (1),
        original_text = obj.get_string_member ("url"),
        display_text = obj.get_string_member ("expanded_url"),
        target = null
      };
    });
    user_info.description = Cb.TextTransform.text (root.get_string_member ("description"),
                                              urls,
                                              Cb.TransformFlags.EXPAND_LINKS,
                                              0, 0);


    if (root.has_member ("profile_banner_url"))
      user_info.banner_url = root.get_string_member ("profile_banner_url");

    /* Website URL */
    if (root.get_object_member ("entities").has_member ("url")) {
      user_info.website = root.get_object_member ("entities").get_object_member ("url")
                     .get_array_member ("urls").get_object_element (0).get_string_member ("expanded_url");
    } else {
      user_info.website = "";
    }

    user_info.avatar_url = root.get_string_member ("profile_image_url_https");

    return user_info;
  }
}
