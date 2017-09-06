# Base class for all x11regression test
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

## no critic (RequireFilenameMatchesPackage);
package x11regressiontest;
use base "x11test";
use strict;
use warnings;
use LWP::Simple;
use Config::Tiny;
use testapi;
use utils;
use POSIX 'strftime';

# Start shotwell and handle the welcome screen, if there
sub start_shotwell {
    x11_start_program("shotwell");
    assert_screen [qw(shotwell-first-launch shotwell-launched)];
    if (match_has_tag "shotwell-first-launch") {
        wait_screen_change { send_key "ret" };
    }
}

# import_pictures helps shotwell to import test pictures into shotwell's library.
sub import_pictures {
    my ($self, $pictures) = @_;

    # Fetch test pictures to ~/Documents
    foreach my $picture (@$pictures) {
        x11_start_program("wget " . autoinst_url . "/data/x11regressions/$picture -O /home/$username/Documents/$picture");
    }

    # Open the dialog 'Import From Folder'
    wait_screen_change {
        send_key "ctrl-i";
    };
    assert_screen 'shotwell-importing';
    send_key "ctrl-l";
    type_string "/home/$username/Documents\n";
    send_key "ret";

    # Choose 'Import in Place'
    if (check_screen 'shotwell-import-prompt') {
        send_key "alt-i";
    }
    assert_screen 'shotwell-imported-tip';
    send_key "ret";
    assert_screen 'shotwell-imported';
}

# clean_shotwell helps to clean shotwell's library then remove the test picture.
sub clean_shotwell {
    # Clean shotwell's database
    x11_start_program("rm -rf /home/$username/.local/share/shotwell");
    # Clean shotwell cache files
    x11_start_program("rm -rf /home/$username/.cache/shotwell");
    # Remove test pictures
    x11_start_program("rm /home/$username/Documents/shotwell_test.*");
}

# upload libreoffice specified file into /home/$username/Documents
sub upload_libreoffice_specified_file {

    x11_start_program("xterm");
    assert_script_run("wget " . autoinst_url . "/data/x11regressions/ooo-test-doc-types.tar.bz2 -O /home/$username/Documents/ooo-test-doc-types.tar.bz2");
    wait_still_screen;
    type_string("cd /home/$username/Documents && ls -l");
    send_key "ret";
    wait_screen_change {
        assert_screen("libreoffice-find-tar-file");
        type_string("tar -xjvf ooo-test-doc-types.tar.bz2");
        send_key "ret";
    };
    wait_still_screen;
    send_key "alt-f4";

}

# cleanup libreoffcie specified file from test vm
sub cleanup_libreoffice_specified_file {

    x11_start_program("xterm");
    assert_script_run("rm -rf /home/$username/Documents/ooo-test-doc-types*");
    wait_still_screen;
    type_string_slow "ls -l /home/$username/Documents";
    send_key "ret";
    wait_screen_change {
        assert_screen("libreoffice-find-no-tar-file");
    };
    wait_still_screen;
    send_key "alt-f4";

}

# cleanup libreoffice recent open file to make sure libreoffice clean
sub cleanup_libreoffice_recent_file {

    x11_start_program("libreoffice");
    wait_still_screen 3;
    send_key "alt-f";
    if (is_tumbleweed) {
        send_key 'down';
        wait_still_screen 3;
        send_key 'u';
    }
    else {
        send_key "alt-u";
    }
    assert_screen("libreoffice-recent-documents");
    send_key_until_needlematch("libreoffice-clear-list", "down");
    send_key "ret";
    assert_screen("welcome-to-libreoffice");
    send_key "ctrl-q";

}

sub open_libreoffice_options {
    if (is_tumbleweed) {
        send_key 'alt-f12';
    }
    else {
        send_key "alt-t";
        wait_still_screen 3;
        send_key "alt-o";
    }
}

# check libreoffice dialog windows setting- "gnome dialog" or "libreoffice dialog"
sub check_libreoffice_dialogs {
    my ($self) = shift;

    # make sure libreoffice dialog option is disabled status
    $self->open_libreoffice_options;

    assert_screen("ooffice-tools-options");
    send_key_until_needlematch('libreoffice-options-general', 'down');
    assert_screen("libreoffice-general-dialogs-disabled");
    send_key "alt-o";
    wait_still_screen 3;
    send_key "alt-o";
    assert_screen("libreoffice-gnome-dialogs");
    send_key "alt-c";
    wait_still_screen 3;

    # enable libreoffice dialog
    $self->open_libreoffice_options;
    assert_screen("libreoffice-options-general");
    send_key "alt-u";
    assert_screen("libreoffice-general-dialogs-enabled");
    send_key "alt-o";
    wait_still_screen 3;
    send_key "alt-o";
    assert_screen("libreoffice-specific-dialogs");
    send_key "alt-c";
    wait_still_screen 3;

    # restore the default setting
    $self->open_libreoffice_options;
    assert_screen("libreoffice-options-general");
    send_key "alt-u";
    wait_still_screen 3;
    send_key "alt-o";

}

# get email account information for Evolution test cases
sub getconfig_emailaccount {
    my ($self) = @_;
    my $local_config = << 'END_LOCAL_CONFIG';
[internal_account_A]
user = admin 
mailbox = admin@localhost
passwd = password123
recvport =995
imapport =993
recvServer = localhost
sendServer = localhost
sendport =25

[internal_account_B]
user = nimda
mailbox = nimda@localhost
passwd = password123
recvport =995
imapport =993
recvServer = localhost
sendServer = localhost
sendport =25 
END_LOCAL_CONFIG

    my $config = Config::Tiny->new;
    $config = Config::Tiny->read_string($local_config);

    return $config;

}

# check and new mail or meeting for Evolution test cases
# It need define seraching key words to serach mail box.

sub check_new_mail_evolution {
    my ($self, $mail_search, $i, $protocol) = @_;
    my $config      = $self->getconfig_emailaccount;
    my $mail_passwd = $config->{$i}->{passwd};
    assert_screen "evolution_mail-online", 240;
    if (check_screen "evolution_mail-auth") {
        if (sle_version_at_least('12-SP2')) {
            send_key "alt-p";
        }
        type_password $mail_passwd;
        send_key "ret";
    }
    send_key "alt-w";
    send_key "ret";
    wait_still_screen 3;
    send_key_until_needlematch "evolution_mail_show-all", "down", 5, 3;
    send_key "ret";
    send_key "alt-n";
    send_key "ret";
    send_key_until_needlematch "evolution_mail_show-allcount", "down", 5, 3;
    send_key "ret";
    send_key "alt-c";
    type_string "$mail_search";
    send_key "ret";
    assert_and_click "evolution_meeting-view-new";
    send_key "ret";
    assert_screen "evolution_mail_open_mail";
    send_key "ctrl-w";    # close the mail
    save_screenshot();

    # Delete the message and expunge the deleted item if not used POP3
    if ($protocol != "POP") {
        send_key "ctrl-e";
        if (check_screen "evolution_mail-expunge") {
            send_key "alt-e";
        }
        assert_screen "evolution_mail-ready";
    }
}

# get a random string with followed by date, it used in evolution case to get a unique email title.
sub get_dated_random_string {
    my ($self, $length) = @_;
    my $ret_string = (strftime "%F", localtime) . "-";
    return $ret_string .= random_string($length);
}

#send meeting request by Evolution test cases
sub send_meeting_request {

    my ($self, $sender, $receiver, $mail_subject) = @_;
    my $config      = $self->getconfig_emailaccount;
    my $mail_box    = $config->{$receiver}->{mailbox};
    my $mail_passwd = $config->{$sender}->{passwd};

    #create new meeting
    send_key "shift-ctrl-e";
    assert_screen "evolution_mail-compse_meeting", 30;
    wait_screen_change { send_key 'alt-a' };
    type_string "$mail_box";
    send_key "alt-s";
    if (sle_version_at_least('12-SP2')) {
        send_key "alt-s";    #only need in sp2
    }
    type_string "$mail_subject this is a evolution test meeting";
    send_key "alt-l";
    type_string "the location of this meetinng is conference room";
    assert_screen "evolution_mail-compse_meeting", 60;
    send_key "ctrl-s";
    assert_screen "evolution_mail-sendinvite_meeting", 60;
    send_key "ret";
    if (check_screen "evolution_mail-auth") {
        if (sle_version_at_least('12-SP2')) {
            send_key "alt-a";    #disable keyring option, only need in SP2 or later
            send_key "alt-p";
        }
        type_password $mail_passwd;
        send_key "ret";
    }
    assert_screen "evolution_mail-compse_meeting", 60;
    send_key "ctrl-w";
    assert_screen [qw(evolution_mail-save_meeting_dialog evolution_mail-send_meeting_dialog evolution_mail-meeting_error_handle evolution_mail-max-window)];
    if (match_has_tag "evolution_mail-save_meeting_dialog") {
        send_key "ret";
    }
    if (match_has_tag "evolution_mail-send_meeting_dialog") {
        send_key "ret";
    }
    if (match_has_tag "evolution_mail-meeting_error_handle") {
        send_key "alt-t";
    }
}

sub setup_pop {
    my ($self, $account) = @_;
    $self->setup_mail_account('pop', $account);
}

sub setup_imap {
    my ($self, $account) = @_;
    $self->setup_mail_account('imap', $account);
}

sub start_evolution {
    my ($self, $mail_box) = @_;

    $self->{next} = "alt-o";
    if (sle_version_at_least('12-SP2')) {
        $self->{next} = "alt-n";
    }
    mouse_hide(1);
    # Clean and Start Evolution
    x11_start_program("xterm -e \"killall -9 evolution; find ~ -name evolution | xargs rm -rf;\"");
    x11_start_program("evolution");
    # Follow the wizard to setup mail account
    assert_screen [qw(evolution-default-client-ask test-evolution-1)];
    if (match_has_tag 'evolution-default-client-ask') {
        assert_and_click "evolution-default-client-agree";
        assert_screen "test-evolution-1";
    }
    send_key $self->{next};
    assert_screen "evolution_wizard-restore-backup";
    send_key $self->{next};
    assert_screen "evolution_wizard-identity";
    wait_screen_change {
        send_key "alt-e";
    };
    type_string "SUSE Test";
    wait_screen_change {
        send_key "alt-a";
    };
    wait_screen_change { type_string "$mail_box" };
    save_screenshot();

    # skip server look up for localhost email address
    if ($mail_box =~ /localhost/) {
        record_soft_failure 'bsc#1049387 - Evolution Skip lookup button sometimes doesn\'t work';
        assert_and_click "evolution-mail-skip-look-up-checkbox";
        save_screenshot();
    }
    send_key $self->{next};
}

sub evolution_add_self_signed_ca {
    my ($self, $account) = @_;
    # add self-signed CA with internal account
    if ($account =~ m/internal/) {
        assert_and_click "evolution_wizard-receiving-checkauthtype";
        assert_screen "evolution_mail_meeting_trust_ca";
        send_key "alt-a";
        wait_screen_change {
            send_key $self->{next};
            send_key "ret";
        }
    }
    else {
        send_key $self->{next};
    }
    if (sle_version_at_least('12-SP2')) {
        send_key "ret";    #only need in SP2 or later
    }
}

sub setup_mail_account {
    my ($self, $proto, $account) = @_;

    my $config          = $self->getconfig_emailaccount;
    my $mail_box        = $config->{$account}->{mailbox};
    my $mail_sendServer = $config->{$account}->{sendServer};
    my $mail_recvServer = $config->{$account}->{recvServer};
    my $mail_user       = $config->{$account}->{user};
    my $mail_passwd     = $config->{$account}->{passwd};
    my $mail_sendport   = $config->{$account}->{sendport};
    my $port_key        = $proto eq 'pop' ? 'recvport' : 'imapport';
    my $mail_recvport   = $config->{$account}->{$port_key};

    $self->start_evolution($mail_box);
    if (check_screen "evolution_wizard-skip-lookup") {
        send_key "alt-s";
    }

    assert_screen "evolution_wizard-receiving";
    wait_screen_change {
        send_key "alt-t";
    };
    send_key "ret";
    send_key_until_needlematch "evolution_wizard-receiving-$proto", "down", 10, 3;
    wait_screen_change {
        send_key "ret";
    };
    wait_screen_change {
        send_key "alt-s";
    };
    type_string "$mail_recvServer";
    if ($proto eq 'pop') {
        #No need set receive port with POP
    }
    elsif ($proto eq 'imap') {
        wait_screen_change {
            send_key "alt-p";
        };
        type_string "$mail_recvport";
    }
    else {
        die "Unsupported protocol: $proto";
    }
    wait_screen_change {
        send_key "alt-n";
    };
    type_string "$mail_user";
    wait_screen_change {
        send_key "alt-m";
    };
    send_key "ret";
    send_key_until_needlematch "evolution_wizard-receiving-ssl", "down", 5, 3;
    wait_screen_change {
        send_key "ret";
    };
    $self->evolution_add_self_signed_ca($account);
    save_screenshot;
    assert_screen "evolution_wizard-receiving-opts";
    send_key $self->{next};
    if (sle_version_at_least('12-SP2')) {
        send_key "ret";    #only need in SP2 or later
    }

    #setup sending protocol as smtp
    assert_screen "evolution_wizard-sending";
    wait_screen_change {
        send_key "alt-t";
    };
    send_key "ret";
    save_screenshot;
    send_key_until_needlematch "evolution_wizard-sending-smtp", "down", 5, 3;
    wait_screen_change {
        send_key "ret";
    };
    wait_screen_change {
        send_key "alt-s";
    };
    type_string "$mail_sendServer";
    wait_screen_change {
        send_key "alt-p";
    };
    type_string "$mail_sendport";
    wait_screen_change {
        send_key "alt-v";
    };
    wait_screen_change {
        send_key "alt-m";
    };
    send_key "ret";
    send_key_until_needlematch "evolution_wizard-sending-starttls", "down", 5, 3;
    send_key "ret";

    #Known issue: hot key 'alt-y' doesn't work
    #wait_screen_change {
    #   send_key "alt-y";
    #};
    #send_key "ret";
    #send_key_until_needlematch "evolution_wizard-sending-authtype", "down", 5, 3;
    #send_key "ret";
    #Workaround of above issue: click the 'Check' button
    assert_and_click "evolution_wizard-sending-setauthtype";
    send_key_until_needlematch "evolution_wizard-sending-authtype", "down", 5, 3;
    send_key "ret";
    wait_screen_change { send_key 'alt-n' };
    type_string "$mail_user";
    send_key $self->{next};
    send_key "ret";
    assert_screen "evolution_wizard-account-summary";
    send_key $self->{next};
    if (sle_version_at_least('12-SP2')) {
        send_key "alt-n";    #only in sp2
        send_key "ret";
    }
    assert_screen "evolution_wizard-done";
    send_key "alt-a";
    if (check_screen "evolution_mail-auth") {
        if (sle_version_at_least('12-SP2')) {
            send_key "alt-a";    #disable keyring option, only in SP2
            send_key "alt-p";
        }
        type_password $mail_passwd;
        send_key "ret";
    }
    if (check_screen "evolution_mail-init-window") {
        send_key "super-up";
    }
    if (check_screen "evolution_mail-auth") {
        if (sle_version_at_least('12-SP2')) {
            send_key "alt-p";
        }
        type_password $mail_passwd;
        send_key "ret";
    }
    assert_screen "evolution_mail-max-window";
}

sub post_fail_hook {
}

sub start_firefox {
    my ($self) = @_;
    mouse_hide(1);

    x11_start_program 'xterm';
    # Clean and Start Firefox
    type_string "killall -9 firefox;rm -rf .moz* .config/iced* .cache/iced* .local/share/gnome-shell/extensions/*; firefox > firefox.log 2>&1 &\n";
    $self->firefox_check_default;
    $self->firefox_check_popups;
    assert_screen 'firefox-launch', 90;
}

sub firefox_check_default {
    # Set firefox as default browser if asked
    assert_screen [qw(firefox_default_browser firefox_trackinfo firefox_readerview_window firefox_clean)], 120;
    if (match_has_tag('firefox_default_browser')) {
        wait_screen_change {
            assert_and_click 'firefox_default_browser_yes';
        };
    }
}

sub firefox_check_popups {
    # Check whether there are any pop up windows and handle them one by one
    for (1 .. 2) {
        wait_still_screen;
        assert_screen [qw(firefox_trackinfo firefox_readerview_window firefox_clean)], 60;
        # handle the tracking protection pop up
        if (match_has_tag('firefox_trackinfo')) {
            wait_screen_change { assert_and_click 'firefox_trackinfo'; };
        }
        # handle the reader view pop up
        elsif (match_has_tag('firefox_readerview_window')) {
            wait_screen_change { assert_and_click 'firefox_readerview_window'; };
        }

        if (match_has_tag('firefox_trackinfo') or match_has_tag('firefox_readerview_window')) {
            # bsc#1046005 does not seem to affect KDE and as the workaround sometimes results in
            # accidentially moving the firefox window around, skip it.
            if (!check_var("DESKTOP", "kde")) {
                # workaround for bsc#1046005
                wait_screen_change { assert_and_click 'firefox_titlebar' };
            }
        }
    }
}

sub exit_firefox {
    # Exit
    send_key_until_needlematch([qw(firefox-save-and-quit xterm-left-open xterm-without-focus)], "alt-f4", 3, 30);
    if (match_has_tag 'firefox-save-and-quit') {
        # confirm "save&quit"
        send_key "ret";
    }
    assert_screen [qw(xterm-left-open xterm-without-focus)];
    if (match_has_tag 'xterm-without-focus') {
        # focus it
        assert_and_click 'xterm-without-focus';
        assert_screen 'xterm-left-open';
    }
    script_run "cat firefox.log";
    save_screenshot;
    upload_logs "firefox.log";
    type_string "exit\n";
}

sub start_gnome_settings {
    my $is_sle_12_sp1          = (check_var('DISTRI', 'sle') && check_var('VERSION', '12-SP1'));
    my $workaround_repetitions = 5;
    my $i                      = $workaround_repetitions;
    my $settings_menu_loaded   = 0;

    # the loop is a workaround for SP1: bug in launcher. Sometimes it doesn't react to click
    # The bug will be NOT fixed for SP1.
    do {
        if ($is_sle_12_sp1) {
            if ($i < $workaround_repetitions) {
                record_soft_failure 'bsc#1041175 - The settings menu fails sporadically on SP1';
            }

            send_key 'super';    # if launcher is open, close it (search string will also be removed).
            send_key 'esc';      # close launcher, if it still open
        }
        send_key 'super';
        wait_still_screen;
        type_string 'settings';
        wait_still_screen(3);
        $settings_menu_loaded = check_screen('settings', 0);
        $i--;
    } while ($is_sle_12_sp1 && !$settings_menu_loaded && $i > 0);

    if (!$is_sle_12_sp1 || $settings_menu_loaded) {
        assert_and_click 'settings';
        assert_screen 'gnome-settings';
    }
}

sub unlock_user_settings {
    start_gnome_settings;
    type_string "users";
    assert_screen "settings-users-selected";
    send_key "ret";
    assert_screen "users-settings";
    assert_and_click "Unlock-user-settings";
    assert_screen "authentication-required-user-settings";
    type_password;
    assert_and_click "authenticate";
}

sub setup_evolution_for_ews {
    my ($self, $mailbox, $mail_passwd) = @_;

    mouse_hide(1);

    # Clean and Start Evolution
    x11_start_program("xterm -e \"killall -9 evolution; find ~ -name evolution | xargs rm -rf;\"");
    x11_start_program("evolution");
    assert_screen [qw(evolution-default-client-ask test-evolution-1)];
    if (match_has_tag "evolution-default-client-ask") {
        assert_and_click "evolution-default-client-agree";
        assert_screen 'test-evolution-1';
    }

    # Follow the wizard to setup mail account
    assert_screen "test-evolution-1";
    send_key "alt-o";
    assert_screen "evolution_wizard-restore-backup";
    send_key "alt-o";
    assert_screen "evolution_wizard-identity";
    wait_screen_change {
        send_key "alt-e";
    };
    type_string "SUSE Test";
    wait_screen_change {
        send_key "alt-a";
    };
    type_string "$mailbox";
    save_screenshot();

    send_key "alt-o";
    assert_screen [qw(evolution_wizard-skip-lookup evolution_wizard-receiving)];
    if (match_has_tag "evolution_wizard-skip-lookup") {
        send_key "alt-s";
        assert_screen 'evolution_wizard-receiving';
    }

    wait_screen_change {
        send_key "alt-t";
    };
    send_key "ret";
    send_key_until_needlematch "evolution_wizard-receiving-ews", "up", 10, 3;
    send_key "ret";
    assert_screen "evolution_wizard-ews-prefill";
    send_key "alt-u";
    assert_screen "evolution_mail-auth";
    type_string "$mail_passwd";
    send_key "ret";
    assert_screen "evolution_wizard-ews-oba", 300;
    send_key "alt-o";
    assert_screen "evolution_wizard-receiving-opts";
    assert_and_click "evolution_wizard-ews-enable-gal";
    assert_and_click "evolution_wizard-ews-fetch-abl";
    assert_screen [qw(evolution_wizard-ews-view-gal evolution_mail-auth)], 120;
    if (match_has_tag('evolution_mail-auth')) {
        type_string "$mail_passwd";
        send_key "ret";
        assert_screen "evolution_wizard-ews-view-gal", 120;
    }
    send_key "alt-o";
    assert_screen "evolution_wizard-account-summary";
    send_key "alt-o";
    assert_screen "evolution_wizard-done";
    send_key "alt-a";
    assert_screen "evolution_mail-auth";
    type_string "$mail_passwd";
    send_key "ret";
    if (check_screen "evolution_mail-init-window") {
        send_key "super-up";
    }
    assert_screen "evolution_mail-max-window";

    # Make all existing mails as read
    assert_screen "evolution_mail-online", 60;
    assert_and_click "evolution_mail-inbox";
    assert_screen "evolution_mail-ready", 60;
    send_key "ctrl-/";
    if (check_screen "evolution_mail-confirm-read") {
        send_key "alt-y";
    }
    assert_screen "evolution_mail-ready", 60;
}

sub evolution_send_message {
    my ($self, $account) = @_;

    my $config       = $self->getconfig_emailaccount;
    my $mailbox      = $config->{$account}->{mailbox};
    my $mail_passwd  = $config->{$account}->{passwd};
    my $mail_subject = $self->get_dated_random_string(4);

    send_key "shift-ctrl-m";
    assert_screen "evolution_mail-compose-message";
    assert_and_click "evolution_mail-message-to";
    type_string "$mailbox";
    wait_screen_change {
        send_key "alt-u";
    };
    wait_still_screen;
    type_string "$mail_subject this is a test mail";
    assert_and_click "evolution_mail-message-body";
    type_string "Test email send and receive.";
    send_key "ctrl-ret";
    if (sle_version_at_least('12-SP2')) {
        if (check_screen "evolution_mail_send_mail_dialog") {
            send_key "ret";
        }
    }
    if (check_screen "evolution_mail-auth") {
        if (sle_version_at_least('12-SP2')) {
            send_key "alt-a";    #disable keyring option, only in SP2
            send_key "alt-p";
        }
        type_string "$mail_passwd";
        send_key "ret";
    }

    return $mail_subject;
}

sub pidgin_remove_account {
    wait_screen_change { send_key "ctrl-a" };
    wait_screen_change { send_key "right" };
    wait_screen_change { send_key "ret" };
    wait_screen_change { send_key "alt-d" };
    send_key "alt-d";
}

sub tomboy_logout_and_login {
    wait_screen_change { send_key 'alt-f4' };

    # logout
    wait_screen_change { send_key "alt-f2" };
    type_string "gnome-session-quit --logout --force\n";
    wait_still_screen;

    # login
    send_key "ret";
    wait_still_screen;
    type_password();
    send_key "ret";
    assert_screen 'generic-desktop';

    # open start note again and take screenshot
    x11_start_program("tomboy note");
}

sub gnote_launch {
    x11_start_program("gnote");
    assert_screen "gnote-first-launched", 5;
    send_key_until_needlematch 'gnote-start-here-matched', 'down', 5;
}

sub gnote_search_and_close {
    my ($self, $string, $needle) = @_;

    send_key "ctrl-f";
    # The gnote interface is slow. So we can't start immediately searching. We need to wait
    wait_still_screen(2);
    type_string $string;
    assert_screen $needle, 5;

    send_key "ctrl-w";
}

# remove the created new note
sub cleanup_gnote {
    send_key 'esc';    #back to all notes interface
    send_key_until_needlematch 'gnote-new-note-matched', 'down', 6;
    wait_screen_change { send_key 'delete' };
    wait_screen_change { send_key 'tab' };
    wait_screen_change { send_key 'ret' };
    send_key 'ctrl-w';
}

sub gnote_start_with_new_note {
    x11_start_program("gnote");
    assert_screen 'gnote-first-launched', 10;
    send_key "ctrl-n";
    assert_screen 'gnote-new-note', 5;
}

# Configure static ip for NetworkManager on SLED or SLE+WE
sub configure_static_ip_nm {
    my ($self, $ip) = @_;

    x11_start_program 'xterm';
    assert_screen 'xterm';
    become_root;
    assert_script_run "nmcli connection add type ethernet con-name wired ifname eth0 ip4 '$ip' gw4 10.0.2.2";
    assert_script_run 'nmcli device disconnect eth0';
    assert_script_run 'nmcli connection up wired ifname eth0', 60;
    type_string "exit\n";
    wait_screen_change { send_key 'alt-f4' };
}

1;
# vim: set sw=4 et:
