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

int main (string[] args) {
#if X11
  X.init_threads();
#endif
#if VIDEO
  Gst.init (ref args);
#endif

  // Setup gettext
  GLib.Intl.setlocale (GLib.LocaleCategory.ALL, "");
  if (Config.LOCALEDIR != null) {
    GLib.Intl.bindtextdomain (Config.GETTEXT_PACKAGE, Config.LOCALEDIR);
  }
  else {
    GLib.Intl.bindtextdomain (Config.GETTEXT_PACKAGE, GLib.Environment.get_variable("PWD") + "/po/");
  }
  GLib.Intl.bind_textdomain_codeset (Config.GETTEXT_PACKAGE, "UTF-8");
  GLib.Intl.textdomain (Config.GETTEXT_PACKAGE);

  //no initialisation of static fields :(
  Settings.init ();
  var cawbird = new Cawbird ();
  int ret = cawbird.run (args);

#if DEBUG
  var list = Gtk.Window.list_toplevels ();
  debug ("Toplevels Left: %u", list.length ());
  foreach (var w in list) {
    debug ("Toplevel: %s", __class_name (w));
    w.destroy ();
  }
#endif

  return ret;
}
