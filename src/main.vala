public class Verminal.App : Gtk.Application {
    public const string APP_ID = "io.github.supercamel.Verminal";
    public const string APP_NAME = "Verminal";
    public const string APP_ICON_NAME = APP_ID;
    private const string DESKTOP_RELAUNCH_ENV = "VERMINAL_DESKTOP_RELAUNCHED";

    public App () {
        Object (
            application_id: APP_ID,
            flags: ApplicationFlags.DEFAULT_FLAGS
        );
    }

    protected override void activate () {
        register_app_icon ();

        var win = active_window as Verminal.Window;
        if (win == null) {
            win = new Verminal.Window (this);
        }

        win.present ();
    }

    private void register_app_icon () {
        var display = Gdk.Display.get_default ();
        if (display == null) {
            return;
        }

        var theme = Gtk.IconTheme.get_for_display (display);
        add_icon_search_path (theme, Path.build_filename (Environment.get_current_dir (), "images"));
        add_icon_search_path (theme, Path.build_filename (Environment.get_current_dir (), "share", "icons"));
        add_icon_search_path (theme, Path.build_filename (Environment.get_current_dir (), "usr", "share", "icons"));

        var appdir = Environment.get_variable ("SQGI_APPDIR");
        if (appdir != null && appdir != "") {
            add_icon_search_path (theme, Path.build_filename (appdir, "share", "icons"));
            add_icon_search_path (theme, Path.build_filename (appdir, "usr", "share", "icons"));
        }
    }

    private void add_icon_search_path (Gtk.IconTheme theme, string path) {
        if (FileUtils.test (path, FileTest.IS_DIR)) {
            theme.add_search_path (path);
        }
    }

    public static string? install_appimage_desktop_entry () {
        var appimage = Environment.get_variable ("APPIMAGE");
        var appdir = Environment.get_variable ("SQGI_APPDIR");
        if (appimage == null || appimage == "" || appdir == null || appdir == "") {
            return null;
        }

        try {
            var desktop_dir = Path.build_filename (Environment.get_user_data_dir (), "applications");
            var icon_dir = Path.build_filename (
                Environment.get_user_data_dir (),
                "icons",
                "hicolor",
                "256x256",
                "apps"
            );
            DirUtils.create_with_parents (desktop_dir, 0755);
            DirUtils.create_with_parents (icon_dir, 0755);

            var desktop_path = Path.build_filename (desktop_dir, APP_ID + ".desktop");
            var icon_path = Path.build_filename (icon_dir, APP_ICON_NAME + ".png");
            var desktop_icon = APP_ICON_NAME;

            remove_owned_desktop_file (Path.build_filename (desktop_dir, "verminal.desktop"));

            string[] icon_candidates = {
                Path.build_filename (appdir, "usr", "share", "icons", "hicolor", "256x256", "apps", APP_ICON_NAME + ".png"),
                Path.build_filename (appdir, APP_ICON_NAME + ".png"),
                Path.build_filename (appdir, "images", APP_ICON_NAME + ".png"),
                Path.build_filename (Environment.get_current_dir (), "images", APP_ICON_NAME + ".png")
            };

            foreach (var src_path in icon_candidates) {
                if (!FileUtils.test (src_path, FileTest.EXISTS)) {
                    continue;
                }

                File.new_for_path (src_path).copy (
                    File.new_for_path (icon_path),
                    FileCopyFlags.OVERWRITE
                );
                desktop_icon = icon_path;
                break;
            }

            var desktop =
                "[Desktop Entry]\n" +
                "Type=Application\n" +
                "Name=" + APP_NAME + "\n" +
                "Exec=" + desktop_launch_exec (appimage) + "\n" +
                "Icon=" + desktop_icon + "\n" +
                "Categories=Development;Utility;GTK;\n" +
                "Terminal=false\n" +
                "StartupNotify=true\n" +
                "StartupWMClass=" + APP_ID + "\n" +
                "X-Verminal-AppImage=true\n";

            FileUtils.set_contents (desktop_path, desktop);
            FileUtils.chmod (desktop_path, 0755);

            return desktop_path;
        } catch (Error e) {
            stderr.printf ("desktop integration warning: %s\n", e.message);
        }

        return null;
    }

    public static bool maybe_relaunch_from_desktop (string desktop_path) {
        if (Environment.get_variable ("APPIMAGE") == null) {
            return false;
        }
        if (Environment.get_variable (DESKTOP_RELAUNCH_ENV) == "1") {
            return false;
        }
        if (Environment.get_variable ("VERMINAL_DISABLE_DESKTOP_RELAUNCH") == "1") {
            return false;
        }

        if (spawn_checked ({"gtk-launch", APP_ID}, false)) {
            return true;
        }

        return spawn_checked ({"gio", "launch", desktop_path}, true);
    }

    private static bool spawn_checked (string[] argv, bool warn_on_error) {
        try {
            int wait_status = 0;
            Process.spawn_sync (
                null,
                argv,
                null,
                SpawnFlags.SEARCH_PATH,
                null,
                null,
                null,
                out wait_status
            );
            Process.check_wait_status (wait_status);
            return true;
        } catch (Error e) {
            if (warn_on_error) {
                stderr.printf ("desktop relaunch warning: %s\n", e.message);
            }
        }

        return false;
    }

    private static void remove_owned_desktop_file (string path) {
        if (!FileUtils.test (path, FileTest.EXISTS)) {
            return;
        }

        try {
            string text;
            FileUtils.get_contents (path, out text);
            if (!text.contains ("Verminal")) {
                return;
            }
            if (!text.contains ("X-Verminal-AppImage=true") &&
                !text.contains ("Icon=verminal") &&
                !text.contains ("StartupWMClass=verminal")) {
                return;
            }

            FileUtils.remove (path);
        } catch (Error e) {
            stderr.printf ("desktop cleanup warning: %s\n", e.message);
        }
    }

    private static string desktop_launch_exec (string appimage) {
        return "env " + DESKTOP_RELAUNCH_ENV + "=1 " + desktop_exec_quote (appimage) + " %U";
    }

    private static string desktop_exec_quote (string value) {
        var quoted = new StringBuilder ("\"");
        for (var i = 0; i < value.length; i++) {
            switch (value[i]) {
            case '%':
                quoted.append ("%%");
                break;
            case '\\':
            case '"':
            case '$':
            case '`':
                quoted.append_c ('\\');
                quoted.append_c (value[i]);
                break;
            default:
                quoted.append_c (value[i]);
                break;
            }
        }
        quoted.append_c ('"');
        return quoted.str;
    }
}

public int main (string[] args) {
    Environment.set_prgname (Verminal.App.APP_ID);
    Environment.set_application_name (Verminal.App.APP_NAME);
    Gtk.Window.set_default_icon_name (Verminal.App.APP_ICON_NAME);

    var desktop_path = Verminal.App.install_appimage_desktop_entry ();
    if (desktop_path != null && Verminal.App.maybe_relaunch_from_desktop (desktop_path)) {
        return 0;
    }

    return new Verminal.App ().run (args);
}
