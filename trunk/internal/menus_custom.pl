# This script is not included as a module, but read from pirana.pl
# as in-line script. This is to make it for developers easier to
# include extra functionality

sub menu_bar_add_custom {
### Purpose : Create the menu bar
### Compat  : W++

    # Example:
    # my $mbar_custom = $mbar -> cascade(-label=>"Custom", -font=>$font, -background=>$bgcol,-underline=>0, -tearoff => 0);
    # $mbar_custom -> command(-label => "Command 1", -font=>$font, -background=>$bgcol,-underline=>0, -command=>sub {
    # 	message ("Command 1 activated");
    #  });
    # $mbar_custom -> command(-label => "Command 1", -font=>$font, -background=>$bgcol,-underline=>0, -command=>sub {
    # 	message ("Command 2 activated");
    #  });

    return();
}

