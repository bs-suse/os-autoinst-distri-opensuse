use base "shutdown";
use testapi;

sub trigger_shutdown_gnome_button() {
    wait_idle;
    send_key "alt-f1"; # applicationsmenu
    my $selected = check_screen 'shutdown_button', 0;
    if (!$selected) {
        key_round 'shutdown_button', 'tab'; # press tab till is shutdown button selected
    }
    send_key "ret"; # press shutdown button
}

1;
# vim: set sw=4 et:

