public class Verminal.App : Gtk.Application {
    public App () {
        Object (
            application_id: "io.github.supercamel.Verminal",
            flags: ApplicationFlags.DEFAULT_FLAGS
        );
    }

    protected override void activate () {
        var win = active_window as Verminal.Window;
        if (win == null) {
            win = new Verminal.Window (this);
        }

        win.present ();
    }
}

public int main (string[] args) {
    return new Verminal.App ().run (args);
}
