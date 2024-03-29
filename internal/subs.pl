#    ----------------------------------------------------------------------
#    Pira�a
#    Copyright Ron Keizer, Coen van Hasselt, 2007-2011, Uppsala/Amsterdam
#    ----------------------------------------------------------------------
#
#    This file is part of Pira�a.
#
#    Pira�a is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    Pira�a is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with Pira�a.  If not, see <http://www.gnu.org/licenses/>.
#

# Subroutines for pirana
# These are mainly the subs that build parts of the GUI and dialogs.
# As much as possible, subs are located in separate module

sub smart_nm_search_dialog {
### Purpose : Do a smart search for NM installations on the local system
### Compat  : W+L+
    my ($nm_local_hlist, $nm_remote_hlist) = @_;
    my $smart_nm_search_dialog = $mw -> Toplevel(-title=>'Quick search for NONMEM installations on local system');
    no_resize ($smart_nm_search_dialog);  
    my $smart_nm_search_frame = $smart_nm_search_dialog -> Frame () -> grid(-ipadx=>'10',-ipady=>'10');
 
    $nm_found_hlist = $smart_nm_search_frame -> Scrolled('HList',
        -head       => 1, -selectmode => "single",
        -highlightthickness => 0,
        -columns    => 2,
        -scrollbars => 'se', -width => 80, -height => 10, -border => 1,
        -background => '#ffffff', -selectbackground => $pirana_orange,
        -font       => $font,
        -command    => sub {
	    my $nm_sel = $nm_found_hlist -> selectionGet ();
        }
     )->grid(-column => 1, -columnspan=>4, -row => 2, -rowspan=>1, -sticky=>'nswe', -ipady=>0);

    $nm_found_hlist -> header('create', 0, -text=> "Nmfe scripts found:", -headerbackground => 'gray');
    $nm_found_hlist -> columnWidth(0, 350);
    $nm_found_hlist -> header('create', 1, -text=> "Suggested name in Pirana:", -headerbackground => 'gray');
    $nm_found_hlist -> columnWidth(1, 200);

    my $nm_found_ref = nm_smart_search();
    my $i = 0;
    foreach my $loc (@$nm_found_ref) {
	$nm_found_hlist -> add($i);
	$nm_found_hlist -> itemCreate($i, 0, -text => $loc, -style=>$style);
	$nm_found_hlist -> itemCreate($i, 1, -text => extract_name_from_nm_loc ($loc), -style=>$style);
	$i++;
    }
    
    my $text = "From the NONMEM installations that were found below, select those that you would like to be\navailable from within Pirana. Double-click on a NONMEM installation to change the name\nto be used in Pirana.";
    $smart_nm_search_frame -> Label (-text=> $text, -font=>$font, -justify=>"left", -background=>$bgcol
	)-> grid (-row=>0, -column=>1, -columnspan=>4, -sticky => "nsw");
    $smart_nm_search_frame -> Button (-text=>"Add selected to Pirana", -font=>$font, -background=>$button, -activebackground=>$abutton, -border=>$bbw, -command => sub {
	my $nm_sel = $nm_found_hlist -> selectionGet ();
	if (@$nm_sel == 0) {
	    message ("Please select at least one NONMEM installation to be added.");
	} else {
	    foreach my $sel (@$nm_sel) {
		my $nm = $nm_found_hlist -> itemCget($sel, 1, "text");
		my $dir = $nm_found_hlist -> itemCget($sel, 0, "text");
		$nm_vers{$nm} = detect_nm_version($dir);
		$nm_dirs{$nm} = $dir;
	    }
	    save_ini ($home_dir."/ini/nm_inst_local.ini", \%nm_dirs, \%nm_vers, $base_dir."/ini_defaults/nm_inst_local.ini", 1);
	    populate_manage_nm_hlist ($nm_local_hlist, $nm_remote_hlist);	
	    $smart_nm_search_dialog -> destroy();
	    return(\%nm_new_dirs);
	}
    }
    )-> grid (-row=>4, -column=>4, -sticky => "nwse");
    $smart_nm_search_frame -> Button (-text=>"Cancel", -font=>$font, -background=>$button, -activebackground=>$abutton, -border=>$bbw, -command => sub {
	$smart_nm_search_dialog -> destroy();
	return (0);
    }
    )-> grid (-row=>4, -column=>3, -sticky => "nwse");
    center_window($smart_nm_search_dialog, $setting{center_window}); # center after adding frame 
    
}

sub wizard_window {
### Purpose : Wizard Dialog 
### Compat  : W+L+
    my $wizard_dialog = $mw -> Toplevel(-title=>'Wizards');
    no_resize ($wizard_dialog);  
    my $wizard_frame = $wizard_dialog -> Frame () -> grid(-ipadx=>'10',-ipady=>'10');
    $wizard_frame -> Label (-text=>'Wizards: ',  -font=>$font_normal)-> grid(-column=>1, -row=>1,-sticky=>'ne');
    my $wizard_listbox = $wizard_frame -> Scrolled('Listbox',
        -selectmode => "single", -highlightthickness => 0,
        -scrollbars => 'se', -width => 26, -height     => 6,
        -border     => 1, -background => "#FFFFFF", -selectbackground => $pirana_orange,
        -font       => $font_normal
	)->grid(-column => 2, -columnspan=>2, -row => 1, -sticky=>'nswe', -ipady=>0);
    my @wizards = dir( $base_dir."/wizards/", "pwiz");
    my @wiz_descr;
    foreach my $pwiz_file (@wizards) {
	my $pwiz_descr = get_pwiz_description ($base_dir."/wizards/".$pwiz_file);
	chomp ($pwiz_descr);
	push (@wiz_descr, $pwiz_descr);
    }
    $wizard_listbox -> insert(0, @wiz_descr);
    $wizard_frame -> Button (-text=>'Run wizard',  -font=>$font, -border=>$bbw, -background=>$button,-activebackground=>$abutton, -command=>sub{
	my @sel = $wizard_listbox -> curselection ();
	my $sel_wizard = @wizards[@sel[0]];
	my $mod_no = @ctl_show[@$sel_ref[0]];
	my $mod_file = @ctl_show[@$sel_ref[0]].".".$setting{ext_ctl};
	my @args = ($^O, $cwd, $mod_no, $mod_file);
	my $variables_ref = wizard_read_pwiz_file ($base_dir."/wizards/".$sel_wizard, \@args);
	my $wizard_run_dialog = $mw -> Toplevel(-title=>'Wizard');
	wizard_build_dialog ($wizard_run_dialog, $variables_ref);
	center_window($wizard_run_dialog, $setting{center_window}); 
	$wizard_run_dialog -> raise;
	$wizard_dialog -> destroy();
     }) -> grid(-row=> 3, -column=>3, -sticky=>"nwse");
    $wizard_frame -> Button (-text=>'Cancel',  -font=>$font, -border=>$bbw, -background=>$button,-activebackground=>$abutton, -command=>sub{
	$wizard_dialog -> destroy();
     }) -> grid(-row=> 3, -column=>2, -sticky=>"nwse");
    center_window($wizard_dialog, $setting{center_window}); # center after adding frame 

}

sub get_pwiz_description {
    my $pwiz_file = shift;
    open (WIZ, "<".$pwiz_file);
    my @wiz_all = <WIZ>;
    close WIZ;
    my $descr;
    foreach (@wiz_all) {
	if ($_ =~ m/\[TYPE\]/) {
	    $descr = $_;
	    $descr =~ s/\[TYPE\]//;
	    $descr =~ s/\[\/TYPE\]//;
	}
    }
    return ($descr);
}

sub wizard_build_dialog {
    my ($window, $variables_ref, $entry_values_ref) = @_;
    my %var = %$variables_ref;

    # put all variables in correct hashes and arrays again;
    my @screens = @{$var{screens}};
    my %screen_questions = %{$var{screen_questions}};
    my %messages =  %{$var{messages}};
    my %arg_values =  %{$var{arg_values}};
    my %questions = %{$var{questions}};
    my @question_keys = @{$var{question_keys}};
    my %question_answers = %{$var{question_answers}};
    my %answers = %{$var{answers}};
    my @answer_keys = @{$var{answer_keys}};
    my %file_entries = %{$var{file_entries}};
    my %answer_widths = %{$var{answer_widths}};
    my %answer_defaults = %{$var{answer_defaults}};
    my %optionmenu_options = %{$var{optionmenu_options}};
    my %checkboxes = %{$var{checkboxes}};
    my $out_text_ref = $var{out_text};
    my %optionmenu_answers = %{$var{optionmenu_answers}};

    # create new hashes to collect the information entered
    my %entry_values = %$entry_values_ref;

    my $i_row = 0;
    if ($var{i_screen} == 0 ) {
	$var{i_screen} = 0;
    }
    my $button_text = "Finish";
    if (@screens > 1) {
	$button_text = "Next";
    }
    my $frame = $window -> Frame (-background => $bgcol, -width=>580, -height=>400) -> grid(-ipadx => 10, -ipady => 10, -row=>1, -column=>1,-sticky=>"wes"); 
    for ($i = 0; $i < 16; $i++) {
	$frame -> Label (-background=>$bgcol, -font=>$font_normal, -width=>80, -text=> "  "
	    ) -> grid (-row=>$i, -column=>1, -rowspan=>1, -columnspan=>2);
    }
    $frame -> Label (-text=> "Step ".($var{i_screen} + 1)." of ".$var{total_screens}.": ".@screens[$var{i_screen}], -background => $bgcol, -font=>$font_bold
	) -> grid(-row=>1, -column=>1,-sticky=>"nws"); 

    my @curr_questions = @{$screen_questions{@screens[$var{i_screen}]}};
    my $types = [
	['CSV files','.csv'],
	['TAB files','.tab'],
	['All Files','*',  ], ];
    foreach my $q_key (@curr_questions) {
	if (exists $messages{$q_key}) {
	   $frame -> Label (-text=> $messages{$q_key}, -font=>$font_normal, -background=>$bgcol, -justify=>"left"
	    ) -> grid (-row=> (3+($i_row*2)), -column=>1, -columnspan=>2, -rowspan=>1, -sticky=> "nw");	       
	} else {
	$frame -> Label (-text => $questions{$q_key}, -justify=> "right", -font=>$font_normal, -background=>$bgcol
	    ) -> grid (-row=> (3+($i_row*2)), -column=>1, -sticky => "nes");
	$frame -> Label (-text => " ", -font=>$font_normal, -background=>$bgcol  # SPACER
	    ) -> grid (-row=> (4+($i_row*2)), -column=>1, -sticky => "nws");
	my @curr_answers = @{$question_answers{$q_key}};
	foreach my $a (@curr_answers) {
	    $entry_values{$a} = $answer_defaults{$a};
	    unless ($answer_widths{$a} eq "") { # test, if no value here, than the key does not refer to an entry
		$frame -> Entry (-width=> $answer_widths{$a}, -font=>$font_normal, -textvariable => \$entry_values{$a}, -border=>$bbw, -background=>$white
		    ) -> grid (-row=> (3+($i_row*2)), -column=>2, -sticky => "nw");	       
	    };
	    unless ($file_entries{$a} eq "") { # test, if no value here, than the key does not refer to an entry
		$frame -> Button (-image=> $gif{browse}, -font=>$font_normal, -border=>$bbw, -background=>$button, -activebackground=>$abutton, -command=> sub {
		    $entry_values{$a} = extract_file_name ($mw-> getOpenFile(-defaultextension => "*", -initialdir=> $cwd , -filetypes=> $types));
		    $window -> raise();
                }) -> grid (-row=> (3+($i_row*2)), -column=>2, -sticky => "ne");	       
	    };
	    unless ($optionmenu_options{$a} eq "") { # test, if options specified, implement optionmenu
		my @opt = quotewords(",", 0, $optionmenu_options{$a});
		foreach (@opt) {$_ = substr($_, 0, 32)}
		$entry_values{$a} = int($entry_values{$a});
		$optionmenu_answers{$a} = @opt[$entry_values{$a}];
		$var{optionmenu_answers} = \%optionmenu_answers;
		my $optionmenu = $frame -> Optionmenu (-font=>$font_small, -background=>$darkblue, -activebackground=>$darkblue2, -foreground=>$white, -activeforeground=>$white, -options => \@opt, -justify=>"left", -font=>$font_normal, -border=>$bbw
		    ) -> grid (-row=> (3+($i_row*2)), -column=>2, -sticky => "nw"); 
		$optionmenu -> configure (-variable => \$optionmenu_answers{$a}, -command => sub {
		      $var{optionmenu_answers} = \%optionmenu_answers;
		    });
	    }
	    unless ($checkboxes{$a} eq "") { # test, if options specified, implement checkbox
		my @chkboxes = quotewords (",", 0, $checkboxes{$a});
		my %checkbox_checked;
		my $j = 1;
		foreach my $box (@chkboxes) {
		    my $ref = $a."_".$j;
		    $entry_values{$ref} = $answer_defaults{$ref};
		    $frame ->  Checkbutton (-background=>$bgcol, -text => $box, -variable=> \$entry_values{$ref}, -font=>$font_normal, -justify=>"left", -border=>1, -command => sub{
                    }
		    ) -> grid (-row=> (2+($i_row*2)+$j), -column=>2, -sticky => "nw");
		    $j++;
		}
		$i_row = $i_row + rnd(($j/2), 0) ;
	    } 
	}
	}
	$i_row++;
    }

    my $button_frame = $frame -> Frame (-background=>$bgcol) -> grid (-row => 25, -column => 2, -columnspan=>2, -sticky=>"se");
    my $prv_button = $button_frame -> Button (-text=> "Previous", -background => $bgcol, -font=>$font_normal,  -command => sub {
	$var{i_screen} = $var{i_screen} - 1;    
	$frame -> destroy();
	wizard_build_dialog($window, \%var, \%entry_values);
					      }) -> grid(-row=>1, -column=>1,-sticky=>"nwse"); 
    my $next_button = $button_frame -> Button (-text=> "Next", -background => $bgcol, -font=>$font_normal,  -command => sub {
	$var{i_screen}++;
	$frame -> destroy();
	wizard_build_dialog($window, \%var, \%entry_values);
					       }) -> grid(-row=>1, -column=>2,-sticky=>"nwse"); 
    my $finish_button = $button_frame -> Button (-text=> "Finish", -background => $bgcol, -font=>$font_normal, -state=>'disabled', -command => sub {
	my @keys = keys(%entry_values);
	my %values = %entry_values;
	foreach my $a (keys (%optionmenu_answers)) {
	    $values{$a} = $optionmenu_answers{$a};    
	}
	foreach my $a (keys (%arg_values) ) { # Arguments passed by Pirana
	    $values{$a} = $arg_values{$a};
	}
	$values{output_file} = rm_spaces($values{output_file});
	wizard_write_output ($out_text_ref, \%values);
	if ($values{output_file} =~ m/\.[Rr]$/) {
	    my $r_gui_command = get_R_gui_command (\%software);
	    unless ($r_gui_command eq "") {
		start_command ($r_gui_command, $cwd."/".$values{output_file});
	    } else {
		edit_model (os_specific_path($cwd."/".$values{output_file}));
	    }
	} else {
	    edit_model (os_specific_path($cwd."/".$values{output_file}));
	}
	$window -> destroy();
						 }) -> grid(-row=>1, -column=>3,-sticky=>"nwse"); 
    if ($var{i_screen} == 0) {
	$prv_button -> configure (-state=>'disabled');
    }
    if ($var{i_screen} >= ($var{total_screens}-1)) {
	$finish_button -> configure (-state=>'normal');
	$next_button -> configure (-state=>'disabled');
    }
    return(1);
}

sub new_scm_file {
### Purpose : Dialog for creating a new scm config file
### Compat  : W+L+
    my $new_scm_name = shift;
    my $overwrite_bool=1;
    my $new_scm_dialog = $mw -> Toplevel(-title=>'New scm config file');
    no_resize ($new_scm_dialog);  
    my $new_scm_frame = $new_scm_dialog -> Frame () -> grid(-ipadx=>'10',-ipady=>'10');
    center_window($new_scm_dialog, $setting{center_window}); # center after adding frame (redhat)
    $new_scm_frame -> Label (-text=>'scm config file: ',  -font=>$font_normal)-> grid(-column=>1, -row=>1,-sticky=>'nse');
    $new_scm_frame -> Entry ( -background=>$white,-width=>10, -border=>2, -relief=>'groove', -textvariable=>\$new_scm_name)->grid(-column=>2,-row=>1, -sticky=>'w');

    chdir($base_dir."/templates");
    my @templates = <*.scm> ; my @templates_descr = ();
    my %template_file;
    $i=0; foreach (@templates) {
	open (IN,$_); @lines=<IN>; close IN;
	my $descr = @lines[0];
	$descr =~ s/\;//;
	$descr =~ s/\n//;
	push (@templates_descr,$descr);
	$template_file{$descr} = $_;
	$i++;
    };
    $new_scm_frame -> Label (-text=>'Template: ', -font=>$font)-> grid(-column=>1, -row=>2, -sticky=>'nse');
    $new_scm_frame -> Label (-text=>'  ', -font=>$font)-> grid(-column=>1, -row=>3, -sticky=>'nse');
    $menu = $new_scm_frame -> Optionmenu(-options => [@templates_descr], -border=>$bbw,
					 -variable=>\$template_chosen,-background=>$lightblue,-activebackground=>$darkblue,-foreground=>$white, -activeforeground=>$white, -justify=>'left', -border=>$bbw
        )-> grid(-column=>2,-row=>2);
    $new_scm_frame -> Button (-text=>'Create file',  -font=>$font, -border=>$bbw, -background=>$button,-activebackground=>$abutton, -command=>sub{
	if (-e $cwd."/".$new_scm_name.".".$setting{ext_ctl}) {  # check if control stream already exists;
	    $overwrite_bool = message_yesno ("SCM file with name ".$new_scm_name.".".$setting{ext_ctl}." already exists.\n Do you want to overwrite?", $mw, $bgcol, $font_normal);
	}
	if ($new_scm_name eq "") {
	    message ("Please specify a valid filename.");
	    $overwrite_bool = 0;
	}
	if ($overwrite_bool==1) {
	    copy ($base_dir."/templates/".$template_file{$template_chosen}, $cwd."/".$new_scm_name);
	    destroy $new_scm_dialog;
	    edit_model (unix_path($cwd."/".$new_scm_name));
	}
			      }
	)-> grid(-column=>2,-row=>4, -sticky=>'w');
}


sub retrieve_nm_help_window {
    my $nm_help_window = $mw -> Toplevel (-title => "Import / update NONMEM help files", -background=> $bgcol);
    my $nm_help_frame = $nm_help_window -> Frame (-background=>$bgcol) -> grid(-ipadx => 10, -ipady => 10);
    
    my $info = "Pirana offers a search interface to the NM help files. For this, the NM help files must first be imported into Pirana.".
	"\nPlease point out below where a NM version is located, either local or on a remote cluster.\n";

    $nm_help_frame -> Label (-text=>$info, -font=> $font_normal, -justify=>"left", -background=>$bgcol
    ) -> grid(-row=>0,-column=>1,-columnspan=>4,-sticky=>"nw");
    $nm_help_frame -> Label (-text=>"Import help files from local NONMEM installation", -font=> $font_bold, -background=>$bgcol
    ) -> grid(-row=>1,-column=>1,-columnspan=>4,-sticky=>"nsw");
    $nm_help_frame -> Label (-text=>"Local location:", -font=> $font_normal, -background=>$bgcol
    ) -> grid(-row=>2,-column=>1,-columnspan=>1,-sticky=>"nsw");
    $nm_help_frame -> Label (-text=>" ", -font=> $font_normal, -background=>$bgcol
    ) -> grid(-row=>4,-column=>1,-columnspan=>1,-sticky=>"nsw");
    $nm_help_frame -> Label (-text=>"Import help files from remote cluster over SSH", -font=> $font_bold, -background=>$bgcol
    ) -> grid(-row=>5,-column=>1,-columnspan=>4,-sticky=>"nsw");
    $nm_help_frame -> Label (-text=>"Remote location:", -font=> $font_normal, -background=>$bgcol
    ) -> grid(-row=>6,-column=>1,-columnspan=>1,-sticky=>"nsw");
   
    my $nm_local_location = "/opt/NONMEM/nm7";
    if ($^O =~ /MSWin/i) {
	$nm_local_location = 'C:\NONMEM\nm7';
    }
    my $nm_remote_location = "/opt/NONMEM/nm7";
    $nm_help_frame -> Entry (-border=>1, -relief=>'groove',-textvariable=> \$nm_local_location, -width=>50, -font=>$font_normal, -background=>"#FFFFFF"
    ) -> grid(-row=>2,-column=>2,-columnspan=>3,-sticky=>"nwe");
    $nm_help_frame -> Entry (-border=>1, -relief=>'groove',-textvariable=> \$nm_remote_location, -width=>50, -font=>$font_normal, -background=>"#FFFFFF"
    ) -> grid(-row=>6,-column=>2,-columnspan=>3,-sticky=>"nwe");
    $nm_help_frame -> Button(-image=>$gif{browse}, -width=>28, -border=>0, -command=> sub{
	$nm_local_location = $nm_help_window-> chooseDirectory();
	$nm_help_window -> focus();
    })->grid(-row=>2, -column=>5, -rowspan=>1, -sticky => 'nse');
    $nm_help_frame -> Button(-text=>"Import help files",  -font=>$font_normal, -command=> sub{
	$nm_help_window -> destroy();
	retrieve_nm_help ("local", $nm_local_location);
    })->grid(-row=>3, -column=>2, -rowspan=>1, -sticky => 'nswe');
    $nm_help_frame -> Button(-text=>"Import help files", -font=>$font_normal,-command=> sub{
	$nm_help_window -> destroy();
	retrieve_nm_help ("remote", $nm_remote_location);
    })->grid(-row=>7, -column=>2, -rowspan=>1, -sticky => 'nswe');
    $nm_help_frame -> Button(-text=>"SSH settings",  -font=>$font_normal,-command=> sub{
	ssh_setup_window();
    })->grid(-row=>9, -column=>1, -rowspan=>1, -sticky => 'nsw');
    $nm_help_frame -> Label (-text=>"                 ", -font=> $font_normal, -background=>$bgcol
    ) -> grid(-row=>8,-column=>4,-columnspan=>1,-sticky=>"ne");
    $nm_help_frame -> Button(-text=>"Cancel",  -font=>$font_normal,-command=> sub{
	$nm_help_window -> destroy ();
    })->grid(-row=>9, -column=>2, -rowspan=>1, -sticky => 'nswe');
}

sub retrieve_nm_help {
    my ($where, $location) = @_;
    unless (-d $base_dir."/doc/nm") {
	mkdir ($base_dir."/doc/nm");
    }
    if (-e $base_dir."/doc/nm/nm_help.sqlite") {unlink ($base_dir."/doc/nm/nm_help.sqlite")};
    my $rtv_nm_window = $mw -> Toplevel (-title => "Importing Nm info/help files", -background=> $bgcol);
    my $rtv_nm_frame = $rtv_nm_window -> Frame (-background=>$bgcol) -> grid(-ipadx => 10, -ipady => 10);
    my $text = "";
    my $text_scrollbar = $rtv_nm_frame -> Scrollbar()->grid(-column=>2,-row=>1,-sticky=>'nws');
    my $rtv_nm_text = $rtv_nm_frame -> Text (
	-width=>50, -height=>18, -yscrollcommand => ['set' => $text_scrollbar],
	-background=>"#ffffff", -exportselection => 0, -wrap=>'word',
	-relief=>'groove', -border=>2,
	-selectbackground=>'#606060',-font=>$font_normal, -highlightthickness =>0
	)-> grid(-column=>1, -row=>1, -columnspan=>1,-sticky=>'nwes');
    $rtv_nm_text -> insert ("end", "Starting import of NM help... \n");
    my $close_button = $rtv_nm_frame -> Button(-text=>"Close", -font=>$font_normal, -state=>'disabled', -command=> sub{
	$rtv_nm_window -> destroy ();
    })->grid(-row=>2, -column=>1, -rowspan=>1, -sticky => 'nse');
    no_resize ($rtv_nm_window);
    $rtv_nm_window -> update();
    
    if ((($where eq "local")&&(-e $location."/html/index.htm"))||($where eq "remote")) { # quick check locally that help files are available
	my $table = ("CREATE TABLE IF NOT EXISTS nm_help (nm_key VARCHAR(50), nm_help TEXT) ");
	my $db = DBI->connect("dbi:SQLite:dbname=".unix_path($base_dir)."/doc/nm/nm_help.sqlite","","", {AutoCommit => 0, PrintError => 1});
	$db -> do ($table);
	$db -> commit();
	my $cwd = fastgetcwd();
	my @lines;
	if ($where eq "local") {
	    chdir ($location."/html");
	    my $cat = "cat"; 
	    if ($^O =~ m/MSWin/i) {
		$cat = "type";
	    }
	    open (NM, $cat." *.htm |");
	} else {
	    my $ssh_pre; my $ssh_post;
	    $ssh_pre = $ssh{login}.' ';	
	    if ($ssh{parameters} ne "") {
		$ssh_pre .= $ssh{parameters}.' ';
	    }
	    $ssh_pre .= "'";
	    if ($ssh{execute_before} ne "") {
		$ssh_pre .= $ssh{execute_before}.'; ';
	    }
	    $ssh_post = "'";
	    open (NM, $ssh_pre."cat ".$location."/html/*.htm ".$ssh_post." |");
#	    print $ssh_pre."cat ".$location."/html/*.htm ".$ssh_post." |";
	}
	my $header = "";
	my $header_flag = 0;
	my $cnt = 0;
	my $nm_help = "";
	my @lines = <NM>;
	my $i = 0;
	foreach my $line (@lines) {
	    my $write_to_db = 0;
	    if (((@lines[$i] =~ m/\-\-\-\-/)||(@lines[$i] =~ m/____/))&&(@lines[($i+1)] =~ m/\|/)){
		$write_to_db = 1;
	    }
	    if ($write_to_db == 1) {
		$nm_help =~ s/\"/\'/g;
		$header =~ s/\|//g;
		$header =~ s/^\s+//; # leading spaces
		$header =~ s/\s+$//; # trailing space
                chomp($header);
                my $sql_command = 'INSERT INTO nm_help (nm_key, nm_help) VALUES ("'.$header.'", "'.$nm_help.'")';
		$db -> do($sql_command);
		$nm_help = "";
		$header = "";
    	    } 
	    if (((@lines[$i] =~ m/\-\-\-\-/)||(@lines[$i] =~ m/____/))&&(@lines[($i+1)] =~ m/\|/)){
		$header_flag = 1;
		$header = @lines[($i + 2)];
	    }
	    if ($header_flag == 0) {
		unless( $line =~ m/(\<HTML|\<BODY|\<PRE|\<\/BODY|\<I\>|\<\/I>|\<HR)/i  ) {
		    $nm_help .= $line;
		}	
	    }
	    if (((@lines[$i] =~ m/\-\-\-\-/)||(@lines[$i] =~ m/____/))&&!(@lines[($i+1)] =~ m/\|/)){	# not the header anymore	
		$header_flag = 0;
	    }
	    $i++;
	}
	chdir ($cwd);
       	$db -> commit();
	$db -> disconnect ();
    }
    if (-s $base_dir."/doc/nm/nm_help.sqlite" > 500000) { # quick 'n dirty check if db is filled with NM help now
	# Read NM help files
	my $nm_help_ref = get_nm_help_keywords ($base_dir."/doc/nm/nm_help.sqlite");
	our @nm_help_keywords = ();
	unless ($nm_help_ref == 0) {
	    my @nm_help_keywords_arr = @$nm_help_ref;
	    foreach (@nm_help_keywords_arr) {
		my @temp = @$_;
		push (@nm_help_keywords, @temp[0]);
	    }
	}
	$rtv_nm_text -> insert ("end", "\nImport seems succesful!.\n");
	$rtv_nm_text -> yview (moveto=>1);
    } else {
	$rtv_nm_text -> insert ("end", "Import seems to have failed!\n\nPlease check that you provided the correct NONMEM\nfolder, that your NM help HTML files are available (in /html),\nand that you have write permissions to the Pirana folder!\n");
	$rtv_nm_text -> yview (moveto=>1);
    }
    $close_button -> configure(-state=>'normal');
}

sub retrieve_psn_info_window {
    my $rtv_psn_info_window = $mw -> Toplevel (-title => "Update PsN info/help files", -background=> $bgcol);
    my $rtv_psn_info_frame = $rtv_psn_info_window -> Frame (-background=>$bgcol) -> grid(-ipadx => 10, -ipady => 10);
  
    my $info = "Pirana comes supplied with the PsN help information, which is shown in the PsN-toolkit dialog in Pirana. As the\n".
	"help files may become out of date with updates to PsN, updated help files can be imported from PsN.\n".
	"Please choose below if you want to import help files from a local or a remote PsN installation\n".
	"\nNote: It is necessary that PsN is installed properly, and the PsN binaries are included in the PATH.\n";

    $rtv_psn_info_frame -> Label (-text=>$info, -font=> $font_normal, -justify=>"left", -background=>$bgcol
    ) -> grid(-row=>0,-column=>1,-columnspan=>4,-sticky=>"nw");
    $rtv_psn_info_frame -> Label (-text=>"Import help information from:", -font=> $font_normal, -justify=>"left", -background=>$bgcol
    ) -> grid(-row=>2,-column=>1,-columnspan=>1,-sticky=>"nsw");
   
    my $psn_local_location = "";
    my $psn_remote_location = "/opt/perl/lib/site_perl/5.8.8/PsN_3_2_7";
    if ($^O =~ /MSWin/i) {
	$psn_local_location = 'C:\perl\site\lib\PsN_3_2_7';
    }
    $rtv_psn_info_frame -> Button(-text=>"Local PsN",  -font=>$font_normal, -command=> sub{
	$rtv_psn_info_window -> destroy();
	retrieve_psn_info ("local");
    })->grid(-row=>2, -column=>2,  -sticky => 'we');
    $rtv_psn_info_frame -> Button(-text=>"Remote PsN", -font=>$font_normal,-command=> sub{
	$rtv_psn_info_window -> destroy();
	retrieve_psn_info ("remote");
    })->grid(-row=>2, -column=>3,  -sticky => 'we');
    $rtv_psn_info_frame -> Button(-text=>"SSH settings",  -font=>$font_normal,-command=> sub{
	ssh_setup_window();
    })->grid(-row=>9, -column=>2, -rowspan=>1, -sticky => 'nswe');
    $rtv_psn_info_frame -> Label (-text=>"                 ", -font=> $font_normal, -background=>$bgcol
    ) -> grid(-row=>8,-column=>4,-columnspan=>1,-sticky=>"ne");
    $rtv_psn_info_frame -> Button(-text=>"Cancel",  -font=>$font_normal,-command=> sub{
	$rtv_psn_info_window -> destroy ();
    })->grid(-row=>9, -column=>3, -rowspan=>1, -sticky => 'nswe');
    no_resize ($rtv_psn_info_window);
}

sub retrieve_psn_info {
    my $where = shift;
    my @psn_commands = qw /execute vpc npc bootstrap cdd llp sse scm sumo/;
    unless (-d $base_dir."/doc/psn") {
	mkdir ($base_dir."/doc/psn");
    }

    my $rtv_psn_window = $mw -> Toplevel (-title => "Importing PsN info/help files", -background=> $bgcol);
    my $rtv_psn_frame = $rtv_psn_window -> Frame (-background=>$bgcol) -> grid(-ipadx => 10, -ipady => 10);
    my $text = "";
    my $text_scrollbar = $rtv_psn_frame -> Scrollbar()->grid(-column=>2,-row=>1,-sticky=>'nws');
    my $rtv_psn_text = $rtv_psn_frame -> Text (
      -width=>50, -height=>18, -yscrollcommand => ['set' => $text_scrollbar],
      -background=>"#ffffff", -exportselection => 0, -wrap=>'word',
      -relief=>'groove', -border=>2,
      -selectbackground=>'#606060',-font=>$font_normal, -highlightthickness =>0
    )-> grid(-column=>1, -row=>1, -columnspan=>1,-sticky=>'nwes');
    $rtv_psn_text -> insert ("end", "Note: for local installations this should not take more than 20 seconds. On remote systems with slow connections this may take a few minutes.\n\n" );
    my $close_button = $rtv_psn_frame -> Button(-text=>"Close", -font=>$font_normal, -state=>'disabled', -command=> sub{
	$rtv_psn_window -> destroy ();
    })->grid(-row=>2, -column=>1, -rowspan=>1, -sticky => 'nse');
    no_resize($rtv_psn_window);

    my %ssh_copy = %ssh; 
    if ($where eq "remote" ) {
	$ssh_copy{connect_ssh} = 1;
    } else {
	$ssh_copy{connect_ssh} = 0;
    }

    $rtv_psn_window -> update();
    foreach my $command (@psn_commands) {	
	$rtv_psn_text -> insert ("end", "Importing info for '".$command."' command... " );
	$rtv_psn_window -> update();
	my $psn_text = get_psn_info ($command, "", \%ssh_copy, "h");
	my $psn_text_help = get_psn_info ($command, "", \%ssh_copy, "help");
	my $cnt_success = 0; $cnt_failed;
	if ((length($psn_text) >250)&&(length($psn_text_help)>250)) { # quick 'n dirty test if output is likely to be PsN info
	    text_to_file (\$psn_text, $base_dir."/doc/psn/".$command."_h.txt");
	    text_to_file (\$psn_text_help, $base_dir."/doc/psn/".$command."_help.txt");
	    $rtv_psn_text -> insert ("end", "Done\n");
	    $cnt_success++;
	} else {
	    $rtv_psn_text -> insert ("end", "Failed\n");
	    $cnt_failed++;
	}
	$rtv_psn_window -> update();
    }
    if ($cnt_failed == 0 ) {
	$rtv_psn_text -> insert ("end", "\nPsN help files successfully imported in Pirana.");
    } else {
	$rtv_psn_text -> insert ("end", "\nImporting PsN help files did not succeed. (Failed ".$cnt_failed."/".(length(@psn_commands)*2).")");
    }
    $close_button -> configure(-state=>'normal');
}

sub sge_setup_window {
    my $sge_setup_window = $mw -> Toplevel (-title => "SGE setup", -background=> $bgcol);
    my $sge_setup_frame = $sge_setup_window -> Frame (-background=>$bgcol) -> grid(-ipadx => 10, -ipady => 10);

    my ($sge_ref, $sge_descr_ref) = read_ini($home_dir."/ini/sge.ini");
    our %sge = %$sge_ref;
    my %sge_new = %sge;
    my %sge_descr = %$sge_descr_ref;
    if (($sge_new{cluster_connect} eq "")||($sge_new{cluster_connect} eq " ")) {
	$sge_new{cluster_conncet} = "None (local)";
    }
    
   $sge_setup_frame -> Label (-text=>"Run on SGE by default", -font=> $font_normal, -background=>$bgcol
    ) -> grid(-row=>1,-column=>1,-columnspan=>1,-sticky=>"ne");
    my $sge_submit_entry = $sge_setup_frame -> Checkbutton (-text => "", -variable=> \$sge_new{sge_default}, -background=>$bgcol, -selectcolor=>$selectcol, -activebackground=>$bgcol
    ) -> grid(-row=>1,-column=>2,-columnspan=>2,-sticky=>"nw");
  
    $sge_setup_frame -> Label (-text=>"Connect to cluster: ", -font=> $font_normal, -background=>$bgcol
    ) -> grid(-row=>2,-column=>1,-columnspan=>1,-sticky=>"ne");
    my @ssh_names = keys (%ssh_all);
    unshift (@ssh_names, "None (local)");
    my $sge_submit_entry = $sge_setup_frame -> Optionmenu(
	-background=>$lightblue, -activebackground=>$darkblue,-foreground=>$white, -activeforeground=>$white, -width=>16, -border=>$bbw, -font=>$font_normal, 
	-options=>\@ssh_names, -textvariable => \$sge_new{connect_cluster},-width=>28,
	-command=>sub{
	})->grid(-row=>2,-column=>2,-sticky=>'wens');
    
    $sge_setup_frame -> Label (-text=>"Submit command ", -font=> $font_normal, -background=>$bgcol
    ) -> grid(-row=>3,-column=>1,-columnspan=>1,-sticky=>"ne");
    my $sge_submit_entry = $sge_setup_frame -> Entry (-border=>1, -relief=>'groove',-textvariable=> \$sge_new{submit_command}, -width=>10, -font=>$font_normal, -background=>"#FFFFFF"
    ) -> grid(-row=>3,-column=>2,-columnspan=>2,-sticky=>"nw");
  
    $sge_setup_frame -> Label (-text=>"Run priority ", -font=> $font_normal, -background=>$bgcol
    ) -> grid(-row=>4,-column=>1,-sticky=>"ne");
    my $sge_priority_entry = $sge_setup_frame -> Entry (-border=>1, -relief=>'groove',-textvariable=> \$sge_new{priority}, -width=>4, -font=>$font_normal, -background=>"#FFFFFF"
    ) -> grid(-row=>4,-column=>2,-columnspan=>2,-sticky=>"nw");
  
    $sge_setup_frame -> Label (-text=>"Additional parameters ", -font=>$font_normal, -background=>$bgcol
    ) -> grid(-row=>5,-column=>1,-sticky=>"ne");
    my $sge_parameters_entry = $sge_setup_frame -> Entry (-border=>1, -relief=>'groove',-textvariable=> \$sge_new{parameters}, -width=>20, -font=>$font_normal, -background=>"#FFFFFF"
    ) -> grid(-row=>5,-column=>2,-columnspan=>2,-sticky=>"nw");
  
    $sge_setup_frame -> Label (-text=>"\n\n", -font=>$font_normal, -background=>$bgcol
    ) -> grid(-row=>6,-column=>1,-sticky=>"nw");
    $sge_setup_frame -> Label (-text=>"Use project/model-name as job-name ", -font=>$font_normal, -background=>$bgcol
    ) -> grid(-row=>6,-column=>1,-sticky=>"ne");
    $sge_setup_frame -> Checkbutton (-text=>"", -variable=> \$sge_new{model_as_jobname}, -font=>$font_normal, -background=>$bgcol, -selectcolor=>$selectcol, -activebackground=>$bgcol
    ) -> grid(-row=>7,-column=>2,-columnspan=>2,-sticky=>"nw");

    $sge_setup_frame -> Button (-text=>"Cancel", -width=>8, -font=>$font_normal, -border=>0, -background=>$button, -activebackground=>$abutton, -command => sub{
	$sge_setup_window -> destroy();
    }) -> grid(-row=>8, -column=>1, -sticky=>"e");
    $sge_setup_frame -> Button (-text=>"Save",-width=>8,  -font=>$font_normal, -border=>0, -background=>$button, -activebackground=>$abutton, -command => sub{
	our %sge = %sge_new;
        save_ini ($home_dir."/ini/sge.ini", \%sge, \%sge_descr, $base_dir."/ini_defaults/sge.ini");
	$sge_setup_window -> destroy();
    }) -> grid(-row=>8, -column=>2, -sticky=>"w");
 
    $sge_setup_window -> focus ();
    $sge_setup_window -> waitWindow; # wait until destroyed
    return();
}


sub get_ssh_settings_and_default {
    my $ssh_ref; my $ssh_chosen;
    if (exists ($ssh_all{$setting_internal{cluster_default}})) {
	$ssh_chosen = $setting_internal{cluster_default};
    } else {
	my @keys = keys(%ssh_all);
	$ssh_chosen = @keys[0]
    }
    $ssh_ref = $ssh_all{$ssh_chosen};
    if (int(keys (%ssh_all)) == 0) {
	$ssh_chosen = "No clusters defined!";
    }
    my %ssh_new = %$ssh_ref;
    return (\%ssh_new, $ssh_chosen);
}

sub ssh_setup_window {
    my $ssh_connection_window = $mw -> Toplevel (-title => "Cluster connections setup", -background=> $bgcol);
    my $ssh_connection_frame = $ssh_connection_window -> Frame (-background=>$bgcol) -> grid(-ipadx => 10, -ipady => 10);

    # $ssh_connection_frame -> Label (-text=> "Use SSH-mode by default ", -font=>$font_normal, -background=>$bgcol) -> grid(-row=>1, -column=>1, -columnspan => 1, -sticky=>"nes");
    my ($ssh_ref, $ssh_chosen) = get_ssh_settings_and_default();
    my %ssh_new = %$ssh_ref;
    my @ssh_names = keys (%ssh_all);

#    $ssh_connection_frame -> Label (-text=> " ", -font=>$font_normal, -background=>$bgcol) -> grid(-row=>2, -column=>1, -columnspan => 1, -sticky=>"nes");
    my $ssh_optionmenu = $ssh_connection_frame -> Optionmenu(
	-background=>$lightblue, -activebackground=>$darkblue,-foreground=>$white, -activeforeground=>$white, -width=>16, -border=>$bbw, -font=>$font_normal, 
	-options=>\@ssh_names, -textvariable => \$ssh_chosen,-width=>28,
	-command=>sub{
	    my $ssh_ref = $ssh_all{$ssh_chosen};
	    my %ssh = %$ssh_ref;
	    foreach my $key (%ssh) {
		$ssh_new{$key} = $ssh{$key};
	    }
	})->grid(-row=>3,-column=>2,-sticky=>'wens');
    my $add_new_cluster_button = $ssh_connection_frame -> Button (
	-image=>$gif{plus}, -font=>$font, -border=>$bbw, 
	-background=>$button, -activebackground=>$abutton, -command=> sub{
	foreach my $key (keys (%ssh_new)) {
	    $ssh_new{$key} = "";
	}
	$ssh_chosen = "New_cluster";
	$ssh_new{remote_folder} = "/home/user";
	$ssh_new{local_folder} = "/home/user";
	if ($^O =~ m/MSWin/i) { $ssh_new{local_folder} = "X:";}
	if ($^O =~ m/darwin/i) { $ssh_new{local_folder} = "/Users/name";}
	$ssh_new{name} = "New_cluster";
	$ssh_new{login} = "ssh user@cluster.net";
	if ($^O =~ m/MSWin/i) { $ssh_new{login} = "plink -l user -pw passw cluster.net";}
	my $num = get_highest_file_number($home_dir."/ini/clusters", "ssh");
	$ssh_new{ini_file} = "ssh".($num+1)."\.ini";
    })-> grid(-row=>3,-column=>3,-sticky=>"wns");
    $help->attach($add_new_cluster_button, -msg => "Add new cluster");
    $ssh_connection_frame -> Button (-image=>$gif{trash}, -font=>$font, -border=>$bbw, -background=>$button, -activebackground=>$abutton, -command=> sub{
	my $ssh_ref = $ssh_all{$ssh_chosen};
	my %ssh = %$ssh_ref;
	unlink ($home_dir."/ini/clusters/".$ssh{ini_file});
	delete ($ssh_all{$ssh_chosen});
	my ($ssh_ref_tmp, $ssh_chosen_tmp) = get_ssh_settings_and_default();
	$ssh_chosen = $ssh_chosen_tmp; 
	@ssh_names = keys (%ssh_all);
	$ssh_optionmenu -> configure (-options => \@ssh_names);
	my $ssh_ref = $ssh_all{$ssh_chosen_tmp};
	my %ssh = %$ssh_ref;
	foreach my $key (keys(%ssh)) {
	    $ssh_new{$key} = $ssh{$key};
	}
    })-> grid(-row=>3,-column=>4,-sticky=>"wns");
    
    $ssh_connection_frame -> Label (-text=> "Cluster ", -font=>$font_normal, -background=>$bgcol) -> grid(-row=>3, -column=>1, -columnspan => 1, -sticky=>"nes");
    $ssh_connection_frame -> Label (-text=> "Clustername ", -font=>$font_normal, -background=>$bgcol) -> grid(-row=>4, -column=>1, -columnspan => 1, -sticky=>"nes");
    $ssh_connection_frame -> Label (-text=> "SSH login ", -font=>$font_normal, -background=>$bgcol) -> grid(-row=>5, -column=>1, -columnspan => 1, -sticky=>"nes");
    $ssh_connection_frame -> Label (-text=> "Additional parameters for SSH ", -font=>$font_normal, -background=>$bgcol) -> grid(-row=>8, -column=>1, -columnspan => 1, -sticky=>"nes");
    $ssh_connection_frame -> Label (-text=> "Execute remote command before ", -font=>$font_normal, -background=>$bgcol) -> grid(-row=>9, -column=>1, -columnspan => 1, -sticky=>"nes");
    $ssh_connection_frame -> Label (-text=> "Grid submit command for PsN ", -font=>$font_normal, -background=>$bgcol) -> grid(-row=>10, -column=>1, -columnspan => 1, -sticky=>"nes");
    for ($i = 1; $i <= 3; $i++) {
	$ssh_connection_frame -> Label (-text=> "[Optional]", -font=>$font_normal, -background=>$bgcol) -> grid(-row=>7+$i, -column=>3, -columnspan => 1, -sticky=>"nws");
    }
    $ssh_connection_frame -> Label (-text=> "Remote mount location ", -font=>$font_normal, -background=>$bgcol) -> grid(-row=>6, -column=>1, -columnspan => 1, -sticky=>"nes");
    $ssh_connection_frame -> Label (-text=> "Local mount location ", -font=>$font_normal, -background=>$bgcol) -> grid(-row=>7, -column=>1, -columnspan => 1, -sticky=>"nes");
    $ssh_connection_frame -> Label (-text=> " ", -font=>$font_normal, -background=>$bgcol) -> grid(-row=>10, -column=>1, -columnspan => 1, -sticky=>"nes");

#    $ssh_connection_frame -> Checkbutton (-text=>"", -variable=> \$ssh_new{default}, -background=>$bgcol, -selectcolor=>$selectcol, -activebackground=>$bgcol) -> grid(-row=>1, -column=>2, -sticky=>"w");
    $ssh_connection_frame -> Entry (-textvariable=> \$ssh_new{name}, -width=>12, -font=>$font_normal, -background=>'#ffffff') -> grid(-row=>4, -column=>2, -columnspan=>3, -sticky=>"wns");
    $ssh_connection_frame -> Entry (-textvariable=> \$ssh_new{login}, -width=>40, -font=>$font_normal, -background=>'#ffffff') -> grid(-row=>5, -column=>2, -columnspan=>3, -sticky=>"wnse");
    $ssh_connection_frame -> Entry (-textvariable=> \$ssh_new{parameters}, -width=>20,-font=>$font_normal, -background=>'#ffffff') -> grid(-row=>8, -column=>2, -sticky=>"wens");
    $ssh_connection_frame -> Entry (-textvariable=> \$ssh_new{execute_before}, -width=>20, -font=>$font_normal, -background=>'#ffffff') -> grid(-row=>9, -column=>2,  -columnspan=>1,-sticky=>"wens");
    $ssh_connection_frame -> Entry (-textvariable=> \$ssh_new{submit_cmd}, -width=>20, -font=>$font_normal, -background=>'#ffffff') -> grid(-row=>10, -column=>2,  -columnspan=>1,-sticky=>"wens");
    $ssh_connection_frame -> Entry (-textvariable=> \$ssh_new{remote_folder}, -width=>40, -font=>$font_normal, -background=>'#ffffff') -> grid(-row=>6, -column=>2, -columnspan=>3, -sticky=>"wnse");
    $ssh_connection_frame -> Entry (-textvariable=> \$ssh_new{local_folder}, -width=>40, -font=>$font_normal, -background=>'#ffffff') -> grid(-row=>7, -column=>2, -columnspan=>3, -sticky=>"wnse");
#    $ssh_connection_frame -> Entry (-textvariable=> \$ssh_new{psn_dir}, -width=>32, -font=>$font_normal, -background=>'#ffffff') -> grid(-row=>7, -column=>2, -sticky=>"w");
 
    $ssh_connection_frame -> Button (-text=>"Cancel", -width=>8, -font=>$font_normal, -border=>0, -background=>$button, -activebackground=>$abutton, -command => sub{
	$ssh_connection_window -> destroy();
    }) -> grid(-row=>11, -column=>1, -sticky=>"e");
    $ssh_connection_frame -> Button (-text=>"Save",-width=>8,  -font=>$font_normal, -border=>0, -background=>$button, -activebackground=>$abutton, -command => sub{
	my %ssh = %ssh_new;
	delete ($ssh_all{$ssh_chosen});
	$ssh_all{$ssh_new{name}} = \%ssh_new;
        save_ini ($home_dir."/ini/clusters/".$ssh_new{ini_file}, \%ssh, \%ssh_descr, $base_dir."/ini_defaults/ssh.ini");
	$ssh_connection_window -> destroy();
    }) -> grid(-row=>11, -column=>2, -sticky=>"w");
    $ssh_connection_window -> focus ();
    $ssh_connection_window -> waitWindow; # wait until destroyed

    return();
}

sub translate_des_window {
    my ($sel_ref, $lang) = @_;
    my $mod_file = @ctl_show[@$sel_ref[0]].".".$setting{ext_ctl};
    my $lst_file = @ctl_show[@$sel_ref[0]].".".$setting{ext_res};
    my $des_block  = extract_nm_block ($mod_file, "DES");
    if ($des_block eq "") { message ("No \$DES block found in model file."); return(); };
    my $pk_block   = extract_nm_block ($mod_file, "PK");
    my $th_block   = extract_nm_block ($mod_file, "THETA");
    my ($des_rh_ref, $des_descr_ref, $vars_decl_ref, $vars_decl_dum_ref, $vars_not_decl_ref, $vars_not_decl_dum_ref) = interpret_des($des_block);
    my ($vars_pk_decl_ref, $vars_pk_order_ref) = interpret_pk_block_for_ode ($pk_block, $vars_not_decl_ref); # try to extract variable declarations not made in $DES but in $PK

    if (keys(%$des_rh_ref)==0) { message ("No system of ODEs found in \$DES. Please check control stream."); return();}

# get estimates
    my ($methods_ref, $est_ref, $se_est_ref, $term_ref) = get_estimates_from_lst ($lst_file);
    my @methods = @$methods_ref;
    my %est = %$est_ref;
    my $last_method = @methods[-1] ;  # take results from the last estimation method
    my $est_ref = $est{$last_method};
    unless ($est_ref =~ m/ARRAY/) { # no estimates in lst-file or no lst-file
	my $mod_ref = extract_from_model ($mod_file, @$sel_ref[0], "all");
	my %mod = %$mod_ref;
	my @est = ($mod{th_init}, $mod{om_init}, $mod{si_init});
	$est_ref = \@est;
    }    

    my $code;
    if ($lang eq "R") {
	$code .= "### Pirana-generated deSolve code \n";
	$code .= "### Number of ODEs in system : ".keys(%$des_rh_ref)."\n";
	$code .= "### Number of parameters     : ".keys(%$vars_not_decl_ref)."\n\n";
	$code .= "library (deSolve)\nlibrary (MASS)\nlibrary (lattice)\n\n";
	$code .= translate_des_to_R ($des_rh_ref, $des_descr_ref, $vars_decl_ref, $vars_decl_dum_ref, $vars_pk_decl_ref, $vars_pk_order_ref, $est_ref ) ;
	unless (-d $cwd."/pirana_temp") {mkdir ($cwd."/pirana_temp")};
	open(RCODE, ">".$cwd."/pirana_temp/".@ctl_show[@$sel_ref[0]]."_desolve.R");
	print RCODE $code;
	close RCODE;
	open_script_in_Rgui (unix_path($cwd."/pirana_temp/".@ctl_show[@$sel_ref[0]]."_desolve.R"));
    } else {
	$code = translate_des_to_BM ($des_rh_ref, $des_descr_ref, $vars_decl_ref, $vars_decl_dum_ref, $vars_pk_decl_ref, $vars_pk_order_ref, $est_ref ) ;
	text_window ($mw, $code, "BM code");
    }
    return ();
}

sub sge_kill_jobs_window {
    my $bool = 0;
    my $message_box = $mw -> Toplevel (-title => "Kill all jobs from user?", -background=> $bgcol);    
    my $command = "qdel -u ".$setting{name_researcher};
    my $message_frame = $message_box -> Frame (-background=>$bgcol) -> grid(-ipadx => 10, -ipady => 10);
    center_window($message_box, $setting{center_window}); # center after adding frame (redhat)
    $message_frame -> Label (-text=> "Are you sure you want to kill all your running and pending jobs?\n ", -font=>$font_normal, -background=>$bgcol) -> grid(-row=>1, -column=>1, -columnspan => 2);
    $message_frame -> Label (-text=> "Command:", -font=>$font_normal, -background=>$bgcol) -> grid(-row=>2, -column=>1);
    $message_frame -> Entry (-textvariable=> \$command, -font=>$font_normal, -background=>'#ffffff') -> grid(-row=>2, -column=>2, -sticky=>"we");
    $message_frame -> Label (-text=> " ", -font=>$font_normal, -background=>$bgcol) -> grid(-row=>3, -column=>1);	
    $message_frame -> Button (-text=>"No", -width=>8, -font=>$font_normal, -border=>0, -background=>$button, -activebackground=>$abutton, -command => sub{
	$message_box -> destroy();
    }) -> grid(-row=>4, -column=>1, -sticky=>"e");
    $message_frame -> Button (-text=>"Yes",-width=>8,  -font=>$font_normal, -border=>0, -background=>$button, -activebackground=>$abutton, -command => sub{
	system ($command);
	$message_box -> destroy();
    }) -> grid(-row=>4, -column=>2, -sticky=>"w");
    $message_box -> focus ();
    $message_box -> waitWindow; # wait until destroyed
    return();
}

sub refresh_sge_monitor_ssh {
    my ($ssh_ref, $nodes_hlist, $jobs_hlist_running, $jobs_hlist_scheduled, $jobs_hlist_finished, $use_hlist) = @_;
    my %ssh = %$ssh_ref;
    my ($ssh_pre, $ssh_post) = ssh_get_pre_post ($ssh_ref); 
    # faster if all commands are performed in one SSH-call
    my $get_info_cmd = $ssh_pre.
        'echo :P:running_jobs:; qstat -u *,* -s r;'.
        'echo :P:scheduled_jobs:; qstat -u *,* -s p;'.
        'echo :P:finished_jobs:; qstat -u *,* -s z;'.
        'echo :P:node_info:; qhost;'.
        'echo :P:node_use:; qstat -g c;echo :P:end:;'. $ssh_post;
    open (OUT, $get_info_cmd." |");
    my $data;
    my $info_cat;
    my %sge_data;
    while (my $line = <OUT>) {
	if ($line =~ m/:P:/) {	     
             unless ($info_cat eq "") {
                 $sge_data{$info_cat} = $data;
             }
             $info_cat = $line;
             $info_cat =~ s/:P\://;
             $info_cat =~ s/://g;
             chomp($info_cat);
             $data = "";   
         } else {
             $data .= $line;
         }
    }    
    close OUT;
    my $node_info_ref = qstat_process_nodes_info ($sge_data{node_info});
    unless ( @$node_info_ref[0] =~ m/ARRAY/ ) {return (0) };
    my $node_use_ref = qstat_process_nodes_info ($sge_data{node_use});
    my $job_info_running_ref = qstat_process_nodes_info ($sge_data{running_jobs});
    my $job_info_scheduled_ref = qstat_process_nodes_info ($sge_data{scheduled_jobs});
    my $job_info_finished_ref = qstat_process_nodes_info ($sge_data{finished_jobs});
    $job_info_running_ref = sort_table ($job_info_running_ref, 3, 0); # order based on username
    $job_info_scheduled_ref = sort_table ($job_info_scheduled_ref, 3, 0); # order based on username
    $job_info_finished_ref = sort_table ($job_info_finished_ref, 3, 0); # order based on username
    populate_nodes_hlist ($nodes_hlist, $node_info_ref);
    populate_nodes_hlist ($use_hlist, $node_use_ref);
    populate_jobs_hlist ($jobs_hlist_running, $job_info_running_ref);
    populate_jobs_hlist ($jobs_hlist_scheduled, $job_info_scheduled_ref);
    populate_jobs_hlist ($jobs_hlist_finished, $job_info_finished_ref);
    return(1);
}

sub refresh_sge_monitor {
    my ($ssh_ref, $nodes_hlist, $jobs_hlist_running, $jobs_hlist_scheduled, $jobs_hlist_finished, $use_hlist) = @_;
    my ($job_info_running_ref, $job_info_scheduled_ref, $job_info_finished_ref, $node_info_ref, $node_use_ref);
    my @dum = [];
    my %ssh = %$ssh_ref;
    $nodes_hlist -> delete("all");
    $use_hlist -> delete("all");
    $jobs_hlist_running -> delete("all");
    $jobs_hlist_scheduled -> delete("all");
    $jobs_hlist_finished -> delete("all");
    if ($ssh{connect_ssh}==1) {
        my $res = refresh_sge_monitor_ssh(@_);
        return($res);
    } else {
        unless (($os =~ m/MSWin/i)&&($ssh{connect_ssh}==0)) {
	    $node_info_ref = qstat_get_nodes_info ("qhost |", $ssh_ref);
	    unless ( @$node_info_ref[0] =~ m/ARRAY/ ) {return (0) }; # SGE probably not installed, don't waste precious time
	    $job_info_running_ref = qstat_get_nodes_info ("qstat -u '*' -s r |", $ssh_ref);
	    $job_info_scheduled_ref = qstat_get_nodes_info ("qstat -u '*' -s p |", $ssh_ref);
	    $job_info_finished_ref = qstat_get_nodes_info ("qstat -u '*' -s z |", $ssh_ref);
	    $node_info_ref = qstat_get_nodes_info ("qhost |", $ssh_ref);
	    $node_use_ref = qstat_get_nodes_info ("qstat -g c |", $ssh_ref);
        } else {
	    $job_info_running_ref = \@dum;
	    $job_info_scheduled_ref = \@dum;
	    $job_info_finished_ref  = \@dum;
	    $node_info_ref = \@dum;
	    $node_info_ref = \@dum;
        }
        populate_nodes_hlist ($nodes_hlist, $node_info_ref);
        populate_nodes_hlist ($use_hlist, $node_use_ref);
        populate_jobs_hlist ($jobs_hlist_running, $job_info_running_ref);
        populate_jobs_hlist ($jobs_hlist_scheduled, $job_info_scheduled_ref);
        populate_jobs_hlist ($jobs_hlist_finished, $job_info_finished_ref);
    }
    return(1);
}

sub tk_table_from_model_output {
    my ($filter, $sge_notebook_frame) = @_;

    my $jobs_hlist;
    my @jobs_headers = qw/ID Priority Name User State Submit\/Start Queue Slots Ja-task-ID/;
    $jobs_hlist = $sge_notebook_frame -> Scrolled('HList',
        -head       => 1, -selectmode => "single",
        -highlightthickness => 0,
        -columns    => int(@jobs_headers), # int(@models_hlist_headers),
        -scrollbars => 'se', -width => 80, -height => 20, -border => 1,
        -background => '#ffffff', -selectbackground => $pirana_orange,
        -font       => $font,
        -command    => sub {
	    my $jobsel = $jobs_hlist -> selectionGet ();
	    my $job_n = @$jobsel[0];
	    $job_n =~ s/job\_//;
	    job_specific_information_window($job_n);
        }
     )->grid(-column => 2, -columnspan=>6, -row => 3, -rowspan=>1, -sticky=>'nswe', -ipady=>0);

    foreach my $x ( 0 .. $#jobs_headers ) {
        $jobs_hlist -> header('create', $x, -text=> @jobs_headers[$x], -headerbackground => 'gray');
	# $cluster_monitor_grid -> columnWidth($x, @widths[$i]);
    }

  #  my $job_info_ref = qstat_get_jobs_info ($filter);
  #  populate_jobs_hlist ($jobs_hlist, $job_info_ref);

    if ($filter =~ m/\-s r/) {
	my $job_menu = $jobs_hlist -> Menu(-tearoff => 0,-title=>'None', -background=>$bgcol, -menuitems=> [
        [Button => " Job info", -background=>$bgcol,-font=>$font_normal,  -command => sub{
	    my $tabsel = $jobs_hlist -> selectionGet ();
	    my $job_n = @$tabsel[0];
	    $job_n =~ s/job\_//;
	    job_specific_information_window($job_n, \%ssh);
        }],
        [Button => " Go to folder", -background=>$bgcol,-font=>$font_normal,  -command => sub{
	    my $tabsel = $jobs_hlist -> selectionGet ();
	    my $job_n = @$tabsel[0];
	    $job_n =~ s/job\_//;
	    my $folder = sge_get_job_cwd($job_n, \%ssh);
	    if (chdir ($folder)) {
		$cwd = $folder;
		refresh_pirana($cwd);
	    } else {message ("Couldn't change to folder. Check permissions.")}
        }],
        [Button => " Intermediate results", -background=>$bgcol,-font=>$font_normal,  -command => sub{
	    my $tabsel = $jobs_hlist -> selectionGet ();
	    my $job_n = @$tabsel[0];
	    $job_n =~ s/job\_//;
	    my $folder = sge_get_job_cwd($job_n, \%ssh);
	    if (chdir ($folder)) {
		show_inter_window ($folder);
	    } else {message ("Couldn't read folder. Check permissions.")}
	    chdir ($cwd);
        }],
        [Button => " Stop job", -background=>$bgcol, -font=>$font_normal, -command => sub{
	    my $tabsel = $jobs_hlist -> selectionGet ();
	    my $job_n = @$tabsel[0];
	    $job_n =~ s/job\_//;
	    my $kill = message_yesno ("Are you sure you want to kill this job?", $mw, $bgcol, $font_normal);
	    if ($kill == 1) {
		stop_job ($job_n, \%ssh);
		sleep (1); # short delay to wait for SGE to kill the job (sometimes not enough...);
		my $job_info_running_ref  = qstat_get_jobs_info ($ssh_add1."qstat -u '*' -s r ".$ssh_add2."|");
		populate_jobs_hlist ($jobs_hlist, $job_info_running_ref);

	    }
	 }],
	] );
	$jobs_hlist -> bind("<Button-3>" => [ sub {
	    $jobs_hlist -> focus; # focus on listbox widget
	    my($w, $x, $y) = @_;
	    our $jobsel = $jobs_hlist -> selectionGet ();
	    if (@$jobsel >0) { $job_menu -> post($x, $y) } else {
		message("Please select a job first...");
	    }
        }, Ev('X'), Ev('Y') ] );
    }
    if ($filter =~ m/\-s p/) {
	my $job_menu = $jobs_hlist -> Menu(-tearoff => 0,-title=>'None', -background=>$bgcol, -menuitems=> [
        [Button => " Job info", -background=>$bgcol,-font=>$font_normal,  -command => sub{
	    my $tabsel = $jobs_hlist -> selectionGet ();
	    my $job_n = @$tabsel[0];
	    $job_n =~ s/job\_//;
	    job_specific_information_window($job_n);
        }],
        [Button => " Go to folder", -background=>$bgcol,-font=>$font_normal,  -command => sub{
	    my $tabsel = $jobs_hlist -> selectionGet ();
	    my $job_n = @$tabsel[0];
	    $job_n =~ s/job\_//;
	    my $folder = sge_get_job_cwd($job_n);
	    if (chdir ($folder)) {
		$cwd = $folder;
		refresh_pirana($cwd);
	    } else {message ("Couldn't change to folder. Check permissions.")}
        }],
        [Button => " Remove scheduled job", -background=>$bgcol, -font=>$font_normal, -command => sub{
	    my $tabsel = $jobs_hlist -> selectionGet ();
	    my $job_n = @$tabsel[0];
	    $job_n =~ s/job\_//;
	    my $kill = message_yesno ("Are you sure you want to remove this job from the queue?", $mw, $bgcol, $font_normal);
	    if ($kill == 1) {
		stop_job ($job_n, \%ssh);
		sleep (1); # short delay to wait for SGE to kill the job (sometimes not enough...);
		my $job_info_running_ref  = qstat_get_jobs_info ($ssh_add1."qstat -s r ".$ssh_add2."|");
		populate_jobs_hlist ($jobs_hlist, $job_info_running_ref);
	    }
	 }],
	] );
	$jobs_hlist -> bind("<Button-3>" => [ sub {
	    $jobs_hlist -> focus; # focus on listbox widget
	    my($w, $x, $y) = @_;
	    our $jobsel = $jobs_hlist -> selectionGet ();
	    if (@$jobsel >0) { $job_menu -> post($x, $y) } else {
		message("Please select a job first...");
	    }
        }, Ev('X'), Ev('Y') ] );
    }
    return ($jobs_hlist);
}

sub job_specific_information_window {
    my ($job_n, $ssh_ref) = @_;
    my $arr_ref = qstat_get_specific_job_info ($job_n, $ssh_ref);
    text_window($mw, join ("\n", @$arr_ref), "Job: ".$job_n, $font_fixed);
    return();
}

sub populate_nodes_hlist {
    my ($nodes_hlist, $node_info_ref) = @_;
    my @node_info = @$node_info_ref;
    my $i=0;
    if ($nodes_hlist ) {
	$nodes_hlist -> delete("all");
	foreach my $node (@node_info) {
	    $nodes_hlist -> add("node_".$i);
	    $nodes_hlist -> itemCreate("node_".$i, 0, -text => @$node[0], -style=>$align_right);
	    $nodes_hlist -> itemCreate("node_".$i, 1, -text => @$node[1], -style=>$align_right);
	    $nodes_hlist -> itemCreate("node_".$i, 2, -text => @$node[2], -style=>$align_right);
	    $nodes_hlist -> itemCreate("node_".$i, 3, -text => @$node[3], -style=>$align_right);
	    $nodes_hlist -> itemCreate("node_".$i, 4, -text => @$node[4], -style=>$align_right);
	    $nodes_hlist -> itemCreate("node_".$i, 5, -text => @$node[5], -style=>$align_right);
	    $i++;
	}
    }
    return();
}

sub populate_jobs_hlist {
    my ($jobs_hlist, $job_info_ref) = @_;
    my @job_info = @$job_info_ref;
    my $i=0;
    $jobs_hlist -> delete("all");
    foreach my $job (@job_info) {
        $jobs_hlist -> add("job_".@$job[0]);
        $jobs_hlist -> itemCreate("job_".@$job[0], 0, -text => @$job[0], -style=>$align_right);
        $jobs_hlist -> itemCreate("job_".@$job[0], 1, -text => @$job[1], -style=>$align_right);
        $jobs_hlist -> itemCreate("job_".@$job[0], 2, -text => @$job[2], -style=>$align_right);
        $jobs_hlist -> itemCreate("job_".@$job[0], 3, -text => @$job[3], -style=>$align_right);
        $jobs_hlist -> itemCreate("job_".@$job[0], 4, -text => @$job[4], -style=>$align_right);
        $jobs_hlist -> itemCreate("job_".@$job[0], 5, -text => @$job[5], -style=>$align_right);
        $jobs_hlist -> itemCreate("job_".@$job[0], 6, -text => @$job[6], -style=>$align_right);
        $jobs_hlist -> itemCreate("job_".@$job[0], 7, -text => @$job[7], -style=>$align_right);
        $jobs_hlist -> itemCreate("job_".@$job[0], 8, -text => @$job[8], -style=>$align_right);
	$i++;
    }
    return();
}

sub sge_monitor_window {
# build dialog
    my $sge_monitor_window = $mw -> Toplevel (-title=>"SGE monitor", -background=>$bgcol);
    my $sge_monitor_window_frame = $sge_monitor_window -> Frame (-background=>$bgcol)->grid(-column=>1, -row=>1,-ipadx=>10, -ipady=>10);
    my $sge_notebook = $sge_monitor_window_frame -> NoteBook(-tabpadx=>5, -font=>$font, -backpagecolor=>$bgcol,-inactivebackground=>$bgcol, -background=>'#FFFFFF') -> grid(-row=>1, -column=>1, -columnspan=>10);
    my $sge_running = $sge_notebook -> add("running", -label=>"Running");
    my $sge_scheduled = $sge_notebook -> add("scheduled", -label=>"Scheduled");
    my $sge_finished = $sge_notebook -> add("finished", -label=>"Finished");
    my $sge_nodes = $sge_notebook -> add("nodes", -label=>"Nodes");
    my $sge_use = $sge_notebook -> add("use", -label=>"Usage");
  #  my $sge_ssh = $sge_notebook -> add("ssh", -label=>"SSH");

# set up ssh if needed
    my ($ssh_pre, $ssh_post); 
    my %ssh;
    if (($sge{connect_cluster} ne "None (local)")&&($sge{connect_cluster} ne "")&&($sge{connect_cluster} ne " ")) {
	my $ssh_ref = $ssh_all{$sge{connect_cluster}};
	%ssh = %$ssh_ref;
	$ssh{connect_ssh} = 1;
	($ssh_pre, $ssh_post) = ssh_get_pre_post (\%ssh); 
    } else {
	$ssh{connect_ssh} = 0;
    }

### Build running Jobs tab
    my $jobs_hlist_running = tk_table_from_model_output ($ssh_pre."qstat -s r |".$ssh_post, $sge_running);
    my $jobs_hlist_scheduled = tk_table_from_model_output ($ssh_pre."qstat -s p |".$ssh_post, $sge_scheduled);
    my $jobs_hlist_finished = tk_table_from_model_output ($ssh_pre."qstat -s z |".$ssh_post, $sge_finished);

# nodes
 #   my $node_info_ref = qstat_get_nodes_info ($ssh_pre."qhost |".$ssh_post);
 #   my $use_info_ref = qstat_get_nodes_info ($ssh_pre."qstat -g c |".$ssh_post);

### Nodes tab:
    my @nodes_headers = qw/hostname architecture ncpu load memtot memuse swapto swapuse/;
    my $nodes_hlist;
    $nodes_hlist = $sge_nodes ->Scrolled('HList',
        -head       => 1,
        -selectmode => "single",
        -highlightthickness => 0,
        -columns    => int(@nodes_headers), # int(@models_hlist_headers),
        -scrollbars => 'se',
        -width      => 80,
        -height     => 20,
        -border     => 1,
        -pady       => 0,
        -padx       => 0,
        -background => '#ffffff',
        -selectbackground => $pirana_orange,
        -font       => $font,
        -browsecmd   => sub{
            my $node_sel = $nodes_hlist -> selectionGet ();
        }
      )->grid(-column => 2, -columnspan=>6, -row => 1, -rowspan=>1, -sticky=>'nswe', -ipady=>0);
    foreach my $x ( 0 .. $#nodes_headers ) {
        $nodes_hlist -> header('create', $x, -text=> @nodes_headers[$x], -headerbackground => 'gray');
       # $cluster_monitor_grid -> columnWidth($x, @widths[$i]);
    }
    my @use_headers = qw/queue cqload used res avail total aoacds cdsue/;
    my $use_hlist;
    
    $use_hlist = $sge_use ->Scrolled('HList',
        -head       => 1,
        -selectmode => "single",
        -highlightthickness => 0,
        -columns    => int(@use_headers), # int(@models_hlist_headers),
        -scrollbars => 'se',
        -width      => 80,
        -height     => 20,
        -border     => 1,
        -pady       => 0,
        -padx       => 0,
        -background => '#ffffff',
        -selectbackground => $pirana_orange,
        -font       => $font,
        -browsecmd   => sub{
            my $use_sel = $use_hlist -> selectionGet ();
        }
      )->grid(-column => 2, -columnspan=>6, -row => 1, -rowspan=>1, -sticky=>'nswe', -ipady=>0);
    foreach my $x ( 0 .. $#use_headers ) {
        $use_hlist -> header('create', $x, -text=> @use_headers[$x], -headerbackground => 'gray');
       # $cluster_monitor_grid -> columnWidth($x, @widths[$i]);
    }
    
    my $res = refresh_sge_monitor (\%ssh, $nodes_hlist, $jobs_hlist_running, $jobs_hlist_scheduled, $jobs_hlist_finished, $use_hlist);
#    print $res;
    if ($res == 0) {
#	$sge_monitor_window -> destroy();
	message ("Pirana can't start SGE commands. SGE is probably not installed, or environment variables\nare not set properly. Please check your SGE installation.\n\nNote: If you connect to an SGE cluster over SSH, please switch on 'SSH-mode'.");
#	return(0);
    }

# main buttons
    my $ssh_connect_button = $sge_monitor_window_frame -> Checkbutton (-text => "SSH-mode", -variable=> \$ssh{connect_ssh}, -font=>$font_normal, -background=>$bgcol, -selectcolor=>$selectcol, -activebackground=>$bgcol, -command=> sub {
        refresh_sge_monitor (\%ssh, $nodes_hlist, $jobs_hlist_running, $jobs_hlist_scheduled, $jobs_hlist_finished, $use_hlist);
    }) -> grid(-row=>8,-column=>1,-sticky=>"nws");
    $sge_monitor_window_frame -> Button (-text => "Refresh", -font=>$font, -width=>12, -border=>$bbw, -background=>$button, -activebackground=>$abutton, -command => sub{
	refresh_sge_monitor (\%ssh, $nodes_hlist, $jobs_hlist_running, $jobs_hlist_scheduled, $jobs_hlist_finished, $use_hlist);
    })-> grid(-column=>2, -row=>8,-sticky=>"nwe");
    $sge_monitor_window_frame -> Button (-text => "Kill all jobs", -font=>$font, -width=>12, -border=>$bbw, -background=>$button, -activebackground=>$abutton, -command => sub{
	sge_kill_jobs_window();
	refresh_sge_monitor (\%ssh, $nodes_hlist, $jobs_hlist_running, $jobs_hlist_scheduled, $jobs_hlist_finished, $use_hlist);
    })-> grid(-column=>3, -row=>8,-sticky=>"nwe");
    $sge_monitor_window_frame -> Button (-text => "Start Qmon", -font=>$font, -width=>12, -border=>$bbw, -background=>$button, -activebackground=>$abutton, -command => sub{
	my $ssh_add1 = "";
	my $ssh_add2 = "";
	if ($ssh{connect_ssh} == 1) {
	    $ssh_add1 = $ssh{login}." ".$ssh{parameters}." ";
	    unless ($ssh{login} =~ m/plink/g) { # plink (PuTTY) doesn't like the quotes
		$ssh_add1 .= "'";
		$ssh_add2 = "'";
	    }
	}
	system ($ssh_add1."qmon ".$ssh_add2."&");
    })-> grid(-column=>4, -row=>8,-sticky=>"nwe");

    $sge_monitor_window_frame -> Button (-text => "Close", -font=>$font, -width=>12, -border=>$bbw, -background=>$button, -activebackground=>$abutton, -command => sub{
	$sge_monitor_window -> destroy();
    })-> grid(-column=>4,
-row=>8,-sticky=>"nwe");
    $sge_monitor_window -> transient($mw);
}

sub dark_row_color {
    my $col = shift;
    $col =~ s/#//;
    my $red   = hex (substr($col,0,2)) * 0.95;
    my $green = hex (substr($col,2,2)) * 0.95;
    my $blue  = hex (substr($col,4,2)) * 0.95;
    my $new_col = "#".sprintf("%x", $red).sprintf("%x", $green).sprintf("%x", $blue);
    return ($new_col);
};

sub even {
    my $n = shift;
    my $even = 0;
    if (($n/2) == int($n/2)) {
	$even = 1;
    }
    return ($even);
}

sub create_nm_start_script {
### Purpose : Create a script (bat or sh) to start
### Compat  : W+L+
  my ($script_file, $nm_version, $run_dir, $mod_ref, $run_in_new_dir, $new_dirs_ref, $clusters_ref, $ssh_ref, $parallelization_text) = @_;
  my %clusters = %$clusters_ref;
  my %ssh = %$ssh_ref;
  my $nmfe_file;
  my $ext;
  my $nm_start_script;
  my @mod = @$mod_ref;
  @new_dirs = @$new_dirs_ref;
  my $drive = "";
  my $qsub;
  my $qsub_base = "";

  if ($clusters{run_on_sge} == 1) {
      $qsub_base = $sge{submit_command}." ".$sge{parameters}." ";
      if ($sge{priority} ne "") {
	  $qsub_base .= "-p ".$sge{priority}." ";
      }
  }
  if (($os =~ m/MSWin/i)&&($ssh{connect_ssh} == 0)) {
    if ($run_dir =~ m/:/) {$drive = substr($run_dir, 0,2)."\n";}
    $ext = "bat";
    $nmfe_file = "nmfe".$nm_vers{$nm_version}.".bat";
  } else {
    $ext = "sh";
    $nmfe_file = "nmfe".$nm_vers{$nm_version};
    $nmfe_file =~ s/\r//g;
  }
  if ($ssh{connect_ssh}==1) {
    $ext = "sh";
    $nmfe_file = "nmfe".$nm_vers_cluster{$nm_version};
    $nmfe_file =~ s/\r//g;
  }
  unless (-d $base_dir."/temp") {mkdir $base_dir."/temp"};
  my $nm_command;
  my $add_base_drive = "";
  if ($^O =~ m/MSWin/i) {
      unless (substr($nm_dirs{$nm_version}, 0, 2) =~ m/.:/i )  {
	  $add_base_drive = $base_drive."/"; # if no drive is specified, add the base_drive (from which pirana is started)
      }
  }
  my $nm_start_script;
  if ($ssh{connect_ssh}==1) {
      $nm_command = unix_path($nm_dirs_cluster{$nm_version}."/util/".$nmfe_file);
     # $run_dir =~ m///;
  } else {
      $nm_command = unix_path($add_base_drive.$nm_dirs{$nm_version}."/util/".$nmfe_file);
  }
  if ($clusters{run_on_pcluster}==1) {
      $nm_command = unix_path($add_base_drive.$nm_dirs{$nm_version}."/util/pirana_nmfe".$nm_vers{$nm_version}."_compile.bat");
  }
  if (($os =~ m/MSWin/i)&&({$connect_ssh}==0)) {
      $nm_start_script = os_specific_path ($nm_command);  # only if on Win and no SSH, use Windows format
  } else {
      $nm_start_script = unix_path ($nm_command);
  }
  my @script;

  # read commands to be executed before and after NM runs
  open (INI1, "<".$home_dir."/ini/commands_before.txt");
  my @before = <INI1>;
  close (INI1);
  open (INI2, "<".$home_dir."/ini/commands_after.txt");
  my @after = <INI2>;
  close (INI2);

  push (@script, @before);
  push (@script,"\n");

  #  Environement variables for NMQual
  my @nmq = split('/', unix_path($nm_dirs{$nm_version}));
  my $nmq_script = unix_path($add_base_drive.$nm_dirs{$nm_version}."/test/".pop(@nmq).".pl");
  if (-e unix_path($nmq_script)) {
      if ($^O =~ m/MSWin/i) {
	  push (@script,"SET PATH=".$setting{nmq_env_path}.";%PATH%; \n");
	  push (@script,"SET LIBRARY_PATH=".$setting{nmq_env_libpath}.";%LIBRARY_PATH% \n");
      } else {
	  push (@script,"PATH=\$PATH:".$setting{nmq_env_path}."\n");
	  push (@script,"LIBRARY_PATH=\$LIBRARY_PATH:".$setting{nmq_env_libpath}." \n");
      }
  }

  push (@script, $drive);
  if ($ssh{connect_ssh}==1) {
      my $loc = unix_path($ssh{local_folder});
      my $rem = unix_path($ssh{remote_folder});
      $run_dir = unix_path($run_dir);
      unless ( $run_dir =~ s/$loc/$rem/i ){
          $run_dir .= "\n"."echo *** Error: Current folder not located at remote cluster. Check preferences!";
      }
  }
  push (@script, "cd '".$run_dir."'\n");
  foreach my $model (@mod) {
      if (($clusters{run_on_sge})&&($sge{model_as_jobname} == 1)) {
	  $active_project =~ s/\s/\_/g;
	  $qsub = $qsub_base."-b y -N ".substr($active_project,0,3)."_".substr($model,0,6)." ";
      } else {$qsub = $qsub_base};
      if($run_in_new_dir == 1) {
	  my $new_dir = shift(@new_dirs);
	  push (@script, "cd ".$new_dir."\n");
      }

      # start using NMQUAL
      if (-e unix_path($nmq_script)) {
	  push (@script, "perl -S ".$nmq_script." ".$model.".".$setting{ext_ctl}." ".$model.".".$setting{ext_res}."\n");
      } else {
      # or normal nmfe NONMEM
	  if (($os =~ m/MSWin/i)&&($ssh{connect_ssh} == 0)) {
	      push (@script,"CALL ".$nm_start_script." ".$model.".".$setting{ext_ctl}." ".$model.".".$setting{ext_res}." ".$parallelization_text." \n");
	  } else {
	      push (@script, $qsub.$nm_start_script." ".$model.".".$setting{ext_ctl}." ".$model.".".$setting{ext_res}." ".$parallelization_text." \n");
	  }
      }

      if (($clusters{run_on_sge} == 0)&&($clusters{run_on_pcluster} == 0)) {
	  push (@script, "echo Run for model ".$model." finished.\n");
      }
      if ($clusters{run_on_sge} == 1) {
	  push (@script, "echo Run for model ".$model." submitted.\n");
      }
      if ($clusters{run_on_pcluster} == 1) {
	  push (@script, "echo Run for model ".$model." compiled for execution on PCluster.\n");
      }
      if ($run_in_new_dir == 1) {push(@script, "cd ..\n");}
  }
  push (@script, "echo All runs finished / submitted.\n");
  push (@script, @after);
  return ($script_file, \@script);
}

sub write_nm_start_script {
    my ( $script_file, $script_text_ref ) = @_;
    my $script_text = $$script_text_ref;
    open (SCR,">".$script_file);
    print SCR $script_text;
    close (SCR);
    chmod (0744, $script_file);
}

sub nmfe_command {
### Purpose : Action when run (nmfe) is clicked
### Compat  : W+L+
    my @sel = $models_hlist -> selectionGet ();
    if (@sel == 0) { message("First select a model."); return(); }
    nmfe_run_window ();
}
sub psn_command {
### Purpose : Action when a PsN function is clicked
### Compat  : W+L+
    my $command = shift;
    my @sel = $models_hlist -> selectionGet ();
    if (@sel == 0) { message("First select a model."); return(); }
    my @mods;
    foreach (@sel) {
	push (@mods, @ctl_show[$_]);
    }
    psn_run_window (\@mods, $command);
}
sub wfn_command {
### Purpose : Action when NMGO/NMBS is clicked
### Compat  : W+L+
    my $command = shift;
    my @sel = $models_hlist -> selectionGet ();
    if (@sel == 0) { message("First select a model."); return(); }
    my $model_id = @ctl_show[@sel[0]];
    wfn_run_window ($model_id, $command);
}
sub properties_command {
    my @sel = $models_hlist -> selectionGet ();
    if (@sel == 0) { message("First select a model."); return(); }
    my $model_id = @ctl_show[@sel[0]];
    model_properties_window($model_id, @sel[0]);
}
sub edit_model_command {
    my @sel = $models_hlist -> selectionGet ();
    if (@sel == 0) { message("First select a model."); return(); }
    foreach (@sel) {
	my $model_id = @ctl_show[$_];
	edit_model(unix_path($cwd."/".$model_id.".".$setting{ext_ctl}));
    }
}
sub rename_model_command {
    my @sel = $models_hlist -> selectionGet ();
    if (@sel == 0) { message("First select a model."); return(); }
    my $model_id = @ctl_show[@sel[0]];
    rename_ctl($model_id);
}
sub duplicate_model_command {
    my @sel = $models_hlist -> selectionGet ();
    if (@sel == 0) { message("First select a model."); return(); }
    duplicate_model_window(\@sel);
}
sub duplicate_msf_command {
    my @sel = $models_hlist -> selectionGet ();
    if (@sel == 0) { message("First select a model."); return(); }
    if ( @file_type_copy[@sel[0]]==2) {
	my $model_id = @ctl_show[@sel[0]];
	restart_msf($model_id);
    }
}
sub translate_des_command {
    my $lang = shift;
    my @sel = $models_hlist -> selectionGet ();
    if (@sel == 0) { message("First select a model."); return(); }
    translate_des_window(\@sel, $lang);
}
sub delete_models_command {
    my @sel = $models_hlist -> selectionGet ();
    if (@sel == 0) { message("First select a model."); return(); }
    delete_models_window(\@sel);
}
sub copy_results_from_folder_command {
    $cwd = $dir_entry -> get();
    $test_dirs = 0;
    foreach (@file_type_copy[$models_hlist -> selectionGet()]) {
        if ($_ != 1) {$test_dirs = 1}
    }
    if ($test_dirs == 0 ) {
        @dirs = @ctl_show[$models_hlist -> selectionGet ()];
	foreach (@dirs) {
	    $_ =~ s/dir\-//g;
	}
        copy_dir_res($cwd, \@dirs);
    } else {
        message ("Please select one or more valid folders.");
    }
}

sub generate_report_command {
    my $run_reports_ref = shift;
    @run = @ctl_show[$models_hlist -> selectionGet];
    if (@run == 0) { message("First select a model / result file."); return(); }
    my $i = 0;
    my $mod0 = @run[0];
    my $final = 0;
    foreach (@run) {
	my $pirana_notes = $models_notes{$_};
	my $add_to = 1;
	if ($i == 0) { $add_to = 0; }
	if ($i == (int(@run)-1)) { $final = 1; }
	output_results_HTML($_ . ".".$setting{ext_res}, \%setting, $pirana_notes, $run_reports_ref, $add_to, $mod0, \@run, \%models_descr);
	$i++;
    }
    start_command($software{browser}, '"file:///'.unix_path($cwd).'/pirana_temp/pirana_sum_'.$mod0.'.html"');
}

sub generate_LaTeX_command {
    my $run_reports_ref = shift;
    my @run;
    @run[0] = shift;
    if (@run[0] = "") {
	@run = @ctl_show[$models_hlist -> selectionGet];
	if (@run == 0) { message("First select a model / result file."); return(); }
    }
    foreach (@run) {
	my $mod = $_;
	my $pirana_notes = $models_notes{$_};
	$_ .= ".".$setting{ext_res};
	my $latex = output_results_LaTeX($_, \%setting, $pirana_notes, $run_reports_ref);
	unless(-d "pirana_temp") {
	    mkdir ("pirana_temp")
	}
	open (TEX, ">pirana_temp/".$mod."_tables.tex");
	print TEX $latex;
	close (TEX);
	edit_model ("pirana_temp/".$mod."_tables.tex");
	if ($setting{pdflatex}==1) {
	    if (chdir ("pirana_temp/")) {
		system ("pdflatex -interaction batchmode ".$mod."_tables.tex > pdflatex.log");
		chdir ("..")
	    }
	    sleep (2);
	    if (-e "pirana_temp/".$mod."_tables.pdf" ) {
		if ($^O =~ m/MSWin/i) {
		    system '"'.$software{pdf_viewer}.'" pirana_temp/'.$mod.'_tables.pdf';
		} else {
		    system $software{pdf_viewer}.' "pirana_temp/'.$mod.'_tables.pdf" &';
		}
	    }
	}
   }
}

sub send_model_info_to_R_command {
      my @sel = $models_hlist -> selectionGet ();
      if (@sel == 0) { message("First select a model."); return(); }
      my @models_sel = @ctl_show[@sel];
      send_object_to_piranaR (\@models_sel);
}

sub view_outputfile_command {
  my @sel = $models_hlist -> selectionGet ();
  if (@sel == 0) { message("First select a model / result file."); return(); }
  my $model_id = @ctl_show[@sel[0]];
  edit_model(unix_path($cwd."\\".$model_id.".".$setting{ext_res}));
}

sub show_param_estim_command {
    my @lst = @ctl_show[$models_hlist -> selectionGet ()];
    if (int(@lst) > 1) { 
	show_estim_multiple (\@lst); 
    } else {
	show_estim_window (\@lst);
    }
    $estim_window -> raise();
}

sub generate_HTML_from_images {
    my ($dir, $html_file) = @_;
    open (HTML, ">".$dir."/".$html_file);
    print HTML "<HTML>\n<BODY>\n";
    print HTML "</TABLE>\n";
    my @png = dir($dir, ".png");
    foreach $png_file (@png) {
	print HTML "<TR><TD>";
	print HTML "<IMG src='".$png_file."'></IMG>";
	print HTML "</TD></TR>";
    }
    print HTML "</TABLE>\n";
    print HTML "<BODY>\n<HTML>\n";
    close(HTML);
    return(1);
}

sub new_script_dialog {
    my $folder = shift;
    my $script_name = "script.R";
    $full_script_name = unix_path($base_dir."/scripts/".$script_name);
    my $ext = get_file_extension ($script_name);
    $template = unix_path($base_dir."/scripts/Template.".$ext);
    my $from_template = 1;
    my $new_script_window = $mw -> Toplevel (-title=>"Create new script", -background=>$bgcol);
    my $new_script_window_frame = $new_script_window -> Frame (-background=>$bgcol)->grid(-column=>1, -row=>1,-ipadx=>10, -ipady=>10);
    $new_script_window_frame -> Label (-text => "Location:", -font=>$font) -> grid (-column=>1, -row=>1,-sticky=>"ne");
    $new_script_window_frame -> Label (-text => "Script filename:", -font=>$font) -> grid (-column=>1, -row=>2,-sticky=>"ne");
    $new_script_window_frame -> Label (-text => "Filename:", -font=>$font) -> grid (-column=>1, -row=>3,-sticky=>"ne");
    my $full_script_name_label = $new_script_window_frame -> Label (-text => $full_script_name, -foreground=>'#777777' ) -> grid (-column=>2, -row=>3,-sticky=>"nw");
    my $script_template;
    $script_template = $new_script_window_frame -> Checkbutton (-text => "From template (".$template.")", -font=>$font, -variable=> \$from_template,  -selectcolor=>$selectcol, -activebackground=>$bgcol, -command=>sub{
	my $ext = get_file_extension ($script_name);
	$template = unix_path($base_dir."/scripts/Template.".$ext);
	$script_template -> configure (-text => "From template (".$template.")");
    })-> grid(-column=>2, -row=>4,-sticky=>"nw");
    my $script_filename_entry = $new_script_window_frame -> Entry (-textvariable => \$script_name, -font=>$font, -background=>$white, -width=>32) -> grid (-column=>2, -row=>2,-sticky=>"nw");
    $script_filename_entry -> bind('<KeyPress>', sub {
	    if ($location eq "Pirana folder") {
		$full_script_name = unix_path($base_dir."/scripts/".$script_name);
	    } else {
		$full_script_name = unix_path($home_dir."/scripts/".$script_name);
	    }
	    $full_script_name_label -> configure(-text => $full_script_name);
	    if ($from_template==1) {
		my $ext = get_file_extension ($script_name);
		$template = unix_path($base_dir."/scripts/Template.".$ext);
		$script_template -> configure (-text => "From template (".$template.")");
	    }
    });
    $new_script_optionmenu = $new_script_window_frame -> Optionmenu ( -options=> ["Pirana folder","User folder"], -font=>$font, -width=>16, -variable=>\$location, -border=>$bbw,
        -font=>$font_normal, -background=>$lightblue, -activebackground=>$darkblue, -foreground=>$white,-activeforeground=>$white, -command=>sub{
	    if ($location eq "Pirana folder") {
		$full_script_name = unix_path($base_dir."/scripts/".$script_name);
	    } else {
		$full_script_name = unix_path($home_dir."/scripts/".$script_name);
	    }
	    $full_script_name_label -> configure(-text => $full_script_name);
     })->grid(-column=>2,-row=>1,-sticky=>"nw");

    $new_script_window_frame -> Label (-text => "\nNotes:", -font=>$font, -background=>$bgcol,-justify=>"left") -> grid (-column=>1, -row=>7,-sticky=>"ne");
   $new_script_window_frame -> Label (-text => "\nAfter creating and saving your script, please restart Pirana to be able to use the script \nfrom the menu.\n\nTo remove the script from the menu, manually delete the script file from the scripts directory\n(See manual for more information)\n", -font=>$font, -background=>$bgcol,-justify=>"left") -> grid (-column=>2, -row=>7,-sticky=>"nw");
    $new_script_window_frame -> Button (-text => "Create and open", -font=>$font, -width=>15, -border=>$bbw, -background=>$button, -activebackground=>$abutton, -command => sub{
	my $ext = get_file_extension($script_name);
	if (-e $base_dir."/scripts/Template.".$ext) {
	    copy ($base_dir."/scripts/Template.".$ext, $full_script_name);
	}
	edit_model ($full_script_name);
	$new_script_window -> destroy();
    })-> grid(-column=>2, -row=>8,-sticky=>"nw");
    no_resize ( $new_script_window);
    return($new_script_window);
}

sub create_scripts_menu {
    my ($menu_parent, $icon, $children, $folder, $title, $edit) = @_;
    # edit: 0 = no, run in console
    #       1 = yes, open template in code editor
    #       2 = yes, open created script in RGui on Windows
    my $mbar_scripts;
    if ($icon ne "") {
	$mbar_scripts = $menu_parent -> cascade(-image=> $gif{$icon}, -font=>$font, -label =>$title, -compound=>'left', -background=>$bgcol, -tearoff => 0);
    } else {
	$mbar_scripts = $menu_parent -> cascade(-label => $title, -font=>$font, -background=>$bgcol, -tearoff => 0);
    }
    my @scripts;
    if ($children == 1) {
	my @dirs = read_dirs ($folder, "");
	foreach my $dir_full (@dirs) {
	    my @dir_spl = split("/",$dir_full) ;
	    my $dir = pop (@dir_spl);
	    my $dir_name = $dir;
	    $dir_name =~ s/_/ /g;
 	    create_scripts_menu ($mbar_scripts, 0, 1, $folder."/".$dir, $dir_name, $edit);
	}
    }
    my @script_types = "R";
    foreach my $type (@script_types) {
	push (@scripts, dir($folder, '\.'.$type));
    }
    foreach my $scriptfile (@scripts) {
	my $script = $scriptfile;
	@script_spl = split ('\.', $script);
	$script_ext = pop (@script_spl);
	$script = join (".", @script_spl);
	$script =~ s/_/ /g;
	unless ((-d $scriptfile)||($script_ext =~ m/\~/)||($scriptfile =~ m/template/i)) {
	    if (($edit == 0)||($edit==2)) {
		$mbar_scripts -> command (-label => $script, -font=>$font, -background=>$bgcol, -command => sub{
		    my @sel = $models_hlist -> selectionGet ();
		    if (@sel == 0) { message("First select a model."); return(); }
		    my @models_sel = @ctl_show[@sel];
		    foreach (@models_sel) {$_ =~ s/dir-// ;}
		    run_script ($folder."/".$scriptfile, \@models_sel, $edit);
   	        });
	    }
	    if ($edit == 1) {
		$mbar_scripts -> command (-label => $script, -font=>$font,  -background=>$bgcol, -command => sub{
		    my @sel = $models_hlist -> selectionGet ();
		    foreach (@models_sel) {$_ =~ s/dir-// ;}
		    edit_model ($folder."/".$scriptfile);
		});
	    }
	}
    }
    return ($mbar_scripts);
}

sub check_out_dataset {
### Purpose : Create an HTML table from a CSV dataset. Color coded event types.
### Compat  : W+L+
  $file=shift;
  if ((substr($file,-3,3) =~ m/$setting{ext_tab}/i )||($file =~ m/..tab/i)) {status("Converting tab-file to suitable format...");tab2csv($file, $file."_pirana.csv"); $file .= "_pirana.csv"};
  status("Reading datafile...");
  $html_out = "checkout.html";
  open (CSV, "<".$file);
  @lines = <CSV>;
  close CSV;

  open (HTML,">".$html_out);
  print HTML "<HTML>\n<HEAD>\n<STYLE>\n";
  print HTML "TD {
     font-family:Verdana,arial; font-size:0.7em}\n
    .head {background-color: #000000; color:#FFFFFF; text-align:right; font-size:0.8em; font-weight:bold}
    .newid {background-color: #FFD8D8; text-align:right; font-size:0.8em}
    .newid_odd {background-color: #FFDBDB; text-align:right; font-size:0.8em}
    .obs {background-color: #F3F3F3; text-align:right; font-size:0.8em}
    .obs_odd {background-color: #FAFAFA; text-align:right; font-size:0.8em}
    .dose {background-color: #D8D8FF; text-align:right; font-size:0.8em}
    .dose_odd {background-color: #DBDBFF; text-align:right; font-size:0.8em}
    .evid2 {background-color: #D6FFD6; text-align:right; font-size:0.8em}
    .evid2_odd {background-color: #DBFFDB; text-align:right; font-size:0.8em}
    .evid3 {background-color: #D6FFFF; text-align:right; font-size:0.8em}
    .evid3_odd {background-color: #DBFFFF; text-align:right; font-size:0.8em}
    .evid4 {background-color: #FFFFD6; text-align:right; font-size:0.8em}
    .evid4_odd {background-color: #FFFFDB; text-align:right; font-size:0.8em}
    }
    A {font-family:Verdana,arial; font-size:0.8em}\n";
  print HTML "</STYLE>\n</HEAD>\n<BODY>\n&nbsp;<BR><CENTER>\n";
  print HTML "<TABLE border=0 cellpadding=2 cellspacing=0 CLASS='stats'>\n";
  unless (@lines[0] =~ m/EVID/gi) {print HTML "<TR><TD colspan=7><B>Note:</B> For the dataset to be displayed properly, an EVID column is needed in the dataset,<BR>indicating observation, dose and other events<BR>&nbsp;<BR></TD></TR>\n";}
  print HTML "<TR CLASS='head'><TD><B>ID</B></TD><TD><B>TIME</B></TD><TD><B>&#916;T</B></TD><TD><B>TAD</B></TD><TD><B>DV</B></TD><TD><B>CMT</B></TD><TD><B>Type</B></TD><TD><B></B></TD><TR>";
  @head = split (",",@lines[0]);
  shift (@lines); my $lastid=-1; my $lastt=0; my $tdiff=0; my $lastt_dos =0; my $tad=0;
  foreach (@lines) {
    @dat = split (",", $_);
    my %data; $i=0;
    foreach (@dat) {
      $data{@head[$i]} = $_;
      $i++;
    }
    if ($data{EVID} == 4) {print HTML "<TR CLASS='evid4'>"; $odd="evid4_odd"} ;
    if ($data{EVID} == 3) {print HTML "<TR CLASS='evid3'>"; $odd="evid3_odd"} ;
    if ($data{EVID} == 2) {print HTML "<TR CLASS='evid2'>"; $odd="evid2_odd"} ;
    if ($data{EVID} == 1) {print HTML "<TR CLASS='dose'>"; $odd="dose_odd" } ;
    if ($data{EVID} == 0) {print HTML "<TR CLASS='obs'>"; $odd="obs_odd"};
    if ($data{ID} != $lastid) {print HTML "<TR CLASS='newid'>"; $tdiff=0; $lastt_dos=0; $tad=0; $odd="new_odd";} else { $tdiff=sprintf("%.2f",($data{TIME}-$lastt,2)); $tad=sprintf("%.2f",($data{TIME}-$lastt_dos,2));  }
    print HTML "<TD>".$data{ID}."</TD><TD CLASS='".$odd."'>".$data{TIME}."</TD><TD>".$tdiff."</TD><TD CLASS='".$odd."'>".$tad."</TD><TD>".$data{DV}."</TD>";
    if ($data{CMT} ne "") {print HTML "<TD>".$data{CMT}."</TD>";};
    if ($data{EVID} == 2) {print HTML "<TD>EVID=2 event</TD>";} ;
    if ($data{EVID} == 3) {print HTML "<TD>EVID=3 event</TD>";} ;
    if ($data{EVID} == 4) {print HTML "<TD>EVID=4 event</TD>";} ;
    my $dose="";
    if ($data{DOSE} ne "") {$dose = $data{DOSE}};
    if ($data{AMT} ne "") {$dose = $data{AMT}};
    if ($dose ==0) {$dose=""};
    if ($data{EVID} == 1) {print HTML "<TD>Dose:</TD>"; $lastt_dos = $data{TIME};} ;
    if ($data{EVID} == 4) {print HTML "<TD>Dose:</TD>"; $lastt_dos = $data{TIME};} ;
    if ($data{EVID} == 0) {print HTML "<TD CLASS='".$odd."'>Observation</TD>";};
    if ($data{ID} != $lastid) {print HTML "<TD CLASS='".$odd."'>New ID</TD>";} else {print HTML "<TD CLASS='".$odd."'><B>".$dose."</B></TD>"} ;
    print HTML "</TR>";
    $lastid = $data{ID};
    $lastt = $data{TIME};
  }
  print HTML "</TABLE></CENTER></BODY></HTML>\n";
  close HTML;
  status();
  return ($html_out);
}

sub cov_calc_window {
### Purpose : Open a dialog window in which covariance can be re-calulated to correlation no an SD scale
### Compat  : W+L+
  my $cov_calc_dialog = $mw -> Toplevel(-title=>'Cov Calculator');
  no_resize($cov_calc_dialog);
  my $cov_calc_frame = $cov_calc_dialog-> Frame(-background=>$bgcol)->grid(-ipadx=>'10',-ipady=>'10',-sticky=>'n');
  $cov_calc_frame -> Label (-text=>"Covariance block:",-background=>$bgcol, -font=>$font_normal) -> grid(-row=>1, -column=>1);
  my $var1=1; my $covar=1; my $var2=1;
  $var1_entry  = $cov_calc_frame -> Entry (-width=>6, -background=>'white',-textvariable=>\$var1, -justify=>"right", -font=>$font_normal) -> grid(-row=>1, -column=>2);
  $covar_entry = $cov_calc_frame -> Entry (-width=>6, -background=>'white', -textvariable=>\$covar,-justify=>"right", -font=>$font_normal) -> grid(-row=>2, -column=>2);
  $var2_entry  = $cov_calc_frame -> Entry (-width=>6, -background=>'white', -textvariable=>\$var2,-justify=>"right", -font=>$font_normal) -> grid(-row=>2, -column=>3);
  $var1_entry -> bind('<Any-KeyPress>' => sub { recalc_cov($var1,$var2,$covar)});
  $var2_entry -> bind('<Any-KeyPress>' => sub { recalc_cov($var1,$var2,$covar)});
  $covar_entry -> bind('<Any-KeyPress>' => sub {recalc_cov($var1,$var2,$covar)});
  $cov_calc_frame -> Label (-text=>" ",-background=>$bgcol) -> grid(-row=>3, -column=>1);
  $cov_calc_frame -> Label (-text=>"SD1:", -foreground=>"#666666",-background=>$bgcol, -font=>$font_normal) -> grid(-row=>4, -column=>1,-sticky=>'e');
  $cov_calc_frame -> Label (-text=>"SD2:", -foreground=>"#666666",-background=>$bgcol, -font=>$font_normal) -> grid(-row=>5, -column=>1,,-sticky=>'e');
  $cov_calc_frame -> Label (-text=>"Correlation:", -foreground=>"#666666",-background=>$bgcol, -font=>$font_normal) -> grid(-row=>6, -column=>1,,-sticky=>'e');
  our $var1_sd=rnd(sqrt($var1),3); our $var2_sd=rnd(sqrt($var1),3); our $covar_sd=rnd(sqrt($covar/($var1_sd*$var2_sd)),3);
  $var1_sd_entr = $cov_calc_frame -> Entry (-width=>6, -textvariable=>\$var1_sd, -justify=>"right", -background=>$bgcol, -foreground=>'#666666', -font=>$font_normal) -> grid(-row=>4, -column=>2);
  $var2_sd_entr = $cov_calc_frame -> Entry (-width=>6, -textvariable=>\$covar_sd,-justify=>"right", -background=>$bgcol, -foreground=>'#666666', -font=>$font_normal) -> grid(-row=>6, -column=>2);
  $covar_sd_entr = $cov_calc_frame -> Entry (-width=>6, -textvariable=>\$var2_sd,-justify=>"right", -background=>$bgcol, -foreground=>'#666666', -font=>$font_normal) -> grid(-row=>5, -column=>2);
  center_window($cov_calc_dialog, $setting{center_window});
}

sub recalc_cov {
### Purpose : Does the actual calculation used in cov_calc_window
### Compat  : W+L+
  my ($var1,$var2,$covar) = @_;
  my $neg_flag = 0;
  if ($var1!=0) {$var1_sd=rnd(sqrt($var1),3);}
  if ($var2!=0) {$var2_sd=rnd(sqrt($var2),3);}
  if ($covar<0) {$covar = -$covar; $neg_flag = 1;}
  if ($covar!=0) {$covar_sd = rnd($covar/($var1_sd*$var2_sd),3)};
  if ($neg_flag == 1 ) {$covar_sd = -$covar_sd};
  $var1_sd_entr -> update();
  $var2_sd_entr -> update();
  $covar_sd_entr -> update();
}

sub plot_corr_matrix_old {
### Purpose : create a csv file with the correlation matrix, feed it to R+ellipse and create a PDF.
### Compat  : W+L-
  unless (-d $software{r_dir}."/library/ellipse") {message ("You need to have the R-package 'ellipse' installed\nto use this function."); return();};
  unlink ("matrix_corr.csv"); unlink ("matrix_corr.pdf");
  my @sel = @ctl_show[$models_hlist -> selectionGet()];
  my $lst_file = @sel[0].".".$setting{ext_res};
  if (-e $lst_file) {
    my ($cov_ref, $inv_cov_ref, $corr_ref, $r_ref, $s_ref, $labels_ref) = get_cov_mat ($lst_file);
    my $available = output_matrix ($corr_ref, $labels_ref, "matrix_corr.csv");
    if ($available == -1) {message ("Correlation matrix was not found in results file ".$lst_file)} else {
      copy ($base_dir."/internal/plot_corr_matrix.R", "pirana_plot_corr_matrix.R");
      run_script ('"'.$software{r_dir}.'\bin\R" --vanilla <pirana_plot_corr_matrix.R |');
      if (-e "matrix_corr.pdf") {system ("start matrix_corr.pdf")} else {message ("PDF file not created. Please check that\nthe result file contains a correlation matrix.")};
    }
  } else {message ("Please select a model of which a result file exists (*.".$setting{ext_res}.")")}
  return();
}

sub save_matrices {
### Purpose : Start extraction of all matrices from a results file.
### Compat  : W+L+
  my $stat ="";
  my @sel = @ctl_show[$models_hlist -> selectionGet()];
  my $runno = @sel[0];
  my $lst_file = $runno.".".$setting{ext_res};
  my ($cov_ref, $inv_cov_ref, $corr_ref, $r_ref, $s_ref, $labels_ref) = get_cov_mat ($lst_file);
  my $a1 = output_matrix ($cov_ref, $labels_ref, $runno."_matrix_cov.csv");
  my $a2 = output_matrix ($inv_cov_ref, $labels_ref, $runno."_matrix_inv_cov.csv");
  my $a3 = output_matrix ($corr_ref, $labels_ref, $runno."_matrix_corr.csv");
  my $a4 = output_matrix ($r_ref, $labels_ref, $runno."_matrix_r.csv");
  my $a5 = output_matrix ($s_ref, $labels_ref, $runno."_matrix_s.csv");
  my $message = $a1.$a2.$a3.$a4.$a5;
  if (length($message) == 0) {
    message ("No matrices were found, or error creating csv files.");
    } else {
    message ($message);
  }
}

sub output_matrix {
### Purpose : Converts a referenced matrix obtained from a result-file to a CSV file
### Compat  : W+L+
  my ($cov_ref, $labels_ref, $csv_file) = @_;
  my @cov = @$cov_ref;
  my @labels = @$labels_ref;
  if (@cov ==0) {return};
#  print "Writing ".$csv_file."\n";
  open (MAT, ">".$csv_file);
  $j=0;
  foreach (@cov) {
    @cov_line = @$_;
    $i=0;
    foreach(@cov_line) {
      @{@cov[$i]}[$j] = $_ ;
      $i++;
    }
    $j++;
  }
  $i=0;
  if (@labels[-1] eq "") {pop @labels};
  print MAT '"'.join('","',@labels).'"'."\n";
  foreach (@cov) {
    @cov_line = @$_;
    print MAT join(",", @cov_line)."\n";
    $i++;
  }
  close MAT;
  return ($csv_file." saved\n");
}

sub run_script {
### Purpose : Run an R / perl (or other type of) script an capture the console output
    my ($scriptfile, $models_ref, $edit) = @_;
    unless (-d "pirana_temp") {mkdir ("pirana_temp")}
    my @spl = split (/\//, $scriptfile);
    my $scriptfile_nopath = "tmp_".generate_random_string(4)."_".pop(@spl);
    copy ($scriptfile, "pirana_temp/".$scriptfile_nopath);
    update_script_with_parameters ("pirana_temp/".$scriptfile_nopath, $models_ref);
    my @spl = split (/\./, $scriptfile);
    my $ext = pop (@spl);
    open (SCR, "<pirana_temp/".$scriptfile_nopath);
    my @lines = <SCR>;
    my $script = join ("", @lines);
    close SCR;
    if (($ext eq "R")||($ext eq "r")) {
	if ($edit == 2) {
	    open_script_in_Rgui (unix_path($cwd."/pirana_temp/".$scriptfile_nopath));
	} else {
	    if ($^O =~ m/MSWin/) {
		run_command_in_console ('"'.$software{r_dir}.'/bin/r.exe" --vanilla <"'.unix_path($cwd."/pirana_temp/".$scriptfile_nopath.'"'));
	    } else {
		run_command_in_console ('"'.$software{r_exec}.'" --vanilla <"'.unix_path($cwd."/pirana_temp/".$scriptfile_nopath.'"'));
	    }
	}
    } else {
	run_command_in_console ($assoc_command{$ext}.' "'.unix_path($cwd."/pirana_temp/".$scriptfile_nopath.'"'));
    }
}

sub create_R_object_from_models {
    my ($models_ref) = @_;
    my @models = @$models_ref;
    my $model_text = "list ( \n";
    my $i = 0;
    foreach my $model_id (@models) {
	my $mfile = $model_id.".".$setting{ext_ctl};
	my $mod_ref = extract_from_model ($mfile, $model_id, "all");
	my %mod = %$mod_ref;
	$model_text .= '  "'.$model_id.'" = list ( '."\n";
	$model_text .= '    "modelfile"       = "'.$mfile.'",'."\n";
	$model_text .= '    "description"     = "'.$mod{description}.'",'."\n";
	$mod{refmod} .= s/\\/\//g;
	$model_text .= '    "reference_model" = "'.$mod{refmod}.'",'."\n";
	$model_text .= '    "working_dir"     = "'.$cwd.'",'."\n";
	$mod{dataset} .= s/\\/\//g;
	$model_text .= '    "data_file"       = "'.$mod{dataset}.'",'."\n";
	$model_text .= '    "output_file"     = "'.$model_id.".".$setting{ext_res}.'",'."\n";
	$tab_ref = $mod{tab_files};
	$tables = '"'.join ('","', @$tab_ref).'"';
	$mod{tables} .= s/\\/\//g;
	$model_text .= '    "tables"          = c('.$tables.")\n  )";
	$i++;
	unless (@models == $i) {
	    $model_text .= ",\n";
	} else {
	    $model_text .= "\n";
	}
    }
    $model_text .= ")\n" ;
    return($model_text);
}

sub update_script_with_parameters {
    my ($file, $models_ref) = @_;
    my $model_text = create_R_object_from_models ($models_ref);
    $model_text .= "\nsetwd('".unix_path($cwd)."')";
    open (SCR, "<".$file);
    my @lines = <SCR>;
    close (SCR);
    foreach my $line (@lines) {
	$line =~ s/\#PIRANA_IN/$model_text/i ;
#	$line =~ s/#MODEL#/$model_id/g;
#	 $line =~ s/#DESCRIPTION#/$mod{description}/g;
#	$line =~ s/#REFMOD#/$mod{refmod}/g;
#	if ($line =~ m/#TABLES#/g) {
#	    $line =~ s/#TABLES#/$tables/g
#	}
#	$line =~ s/#MFILE#/$mfile/g;
#	$line =~ s/#DATA#/$mod{dataset}/g;
#	$line =~ s/#RES#/$model_id\.$setting{ext_res}/g;
    }
    open (SCR, ">".$file);
    print SCR @lines;
    close (SCR);
}

sub open_script_in_Rgui {
    $scriptfile = shift;
    open (R, "<$scriptfile");
    my @lines = <R>;
    open (R_OUT, ">$scriptfile");
    foreach my $line (@lines) {
	unless ($line =~ m/quit|PIRANA_OUT/) {
	    print R_OUT $line;
	}
    }
    close R_OUT;
    unlink (".Rprofile");
    my $r_gui_command = get_R_gui_command (\%software);
    if ($r_gui_command =~ m/rgui/i) { # good old RGUI is used. do workaround to load file
	my $text = 'utils::file.edit("'.$scriptfile.'")'."\n";
	text_to_file (\$text, ".Rprofile");
	$scriptfile = "";
    }
    unless ($r_gui_command eq "") {
	start_command ($r_gui_command, $scriptfile);
    } else {
	edit_model ($scriptfile);
#	message ("R GUI not found. Please check software settings!");   
    }
}

sub run_command_in_console {
### Purpose : Run a command and capture the console output
### Compat  : W+L?
    my $command = shift;
    my $console;
    if ($show_console == 1) {
	$console = show_console_output("");
        $console -> tagConfigure ("comment", -foreground=>"#888888");
        $console -> tagConfigure ("r", -foreground=>"#3344ee", -font=>$font_fixed." bold");
        $console -> tagConfigure ("command", -foreground=>"#000000");
	$console -> tagConfigure ("pirana", -foreground=>"#cc6611", -font=>$font_fixed." bold");
	$console -> tagConfigure ("error", -foreground=>"#880000", -font=>$font_fixed." bold");
    }
    open (OUT, "$command 2>&1 |"); # redirect STDERR to STDOUT
    if ((defined $console)||($show_console==0)) {
	while (my $line = <OUT>) {
	    if ($show_console == 1 ) {
		my $pos = $console -> index('end');
		my $response = $line;
		my $comment;
		my $command_line = 0;
		my $rest = $line;
		if ($line =~ m/\#/) {
		    $comment = substr($line, length($`));
		    $rest    = substr($line, 0, length($`));
		}
		if ((substr($line,0,2) eq "> ")||(substr($line,0,2) eq "+ ")) {
		    $console -> insert("end", $rest, "command");
		    $console -> insert("end", $comment, "comment");
		} else {
		    if (($rest =~ m/Error/i)||($rest =~ m/Warning/i)) {
			$console -> insert("end", $rest, "error");
		    } else {
			$console -> insert("end", $rest, "r");
		    }
		    $console -> insert("end", $comment, "comment");
		}
		$mw -> update;
		$console -> yview (moveto=>1);
	    }
	    if ($line =~ m/#PIRANA_OUT/) {
		my $script_output = $line;
		$script_output =~ s/#PIRANA_OUT//;
		$script_output = substr ($script_output, length($`), -1) ;
		$script_output =~ s/\>//; #remove >
		$script_output =~ s/\"//; #remove quotes
		$script_output =~ s/^\s+//; #remove leading spaces
		chomp ($script_output);
		my $viewer = "";
		if ($script_output =~ m/\.pdf/ ) {
		    $viewer = $software{pdf_viewer}
		}
		if ($script_output =~ m/\.(gif|png|eps|ps|jpg|jpeg|tiff|tif)/ ) {
		    $viewer = $software{img_viewer}
		}
		if ($script_output =~ m/\.html/i ) {
		    $viewer = $software{browser}
		}
		if (-e $script_output) {
		    start_command ($viewer, $script_output.$add_fork);
		}
		if (defined($console)) {
		    $console -> insert('end', "Pirana: Trying to load file ".$script_output."\n", "pirana");
		}
	    };
	}
    }
    close OUT;
    return(1);
}

sub restart_msf {
### Purpose : Create a NM model file from a previous one, and alter it so that it restart with the MSF-file that was created
### Compat  : W+L?
  my $model = shift;
  my $modelfile = $model.".".$setting{ext_ctl};
  my $mod_ref = extract_from_model ($modelfile, $modelno, "all");
  my %mod = %$mod_ref;
  my $msf = $mod{msf_file};
  my $new_msf = new_model_name($msf);
  open (MOD, "<".$model.".".$setting{ext_ctl});
  my @lines = <MOD>;
  close MOD;
  my $new_ctl_name = new_model_name($model);
  $msf_dialog = $mw -> Toplevel(-title=>'Restart using MSF');
  no_resize ($msf_dialog);
  $msf_dialog_frame = $msf_dialog-> Frame(-background=>$bgcol)->grid(-ipadx=>'10',-ipady=>'10',-sticky=>'n');
  center_window($msf_dialog, $setting{center_window});  # center after adding frame (redhat)
  $msf_dialog_frame -> Label (-background=>$bgcol, -font=>$font, -text=>'New model number (without '.$setting{ext_ctl}.'):')->grid(-row=>1,-column=>1,-sticky=>"e");
  $msf_dialog_frame -> Entry (-width=>8, -border=>2, -relief=>'groove', -background=>$white,
     -textvariable=>\$new_ctl_name)->grid(-row=>1,-column=>2,-sticky=>"w");
  $msf_dialog_frame -> Label (-background=>$bgcol,  -font=>$font,-text=>'Restart using MSF file:')->grid(-row=>2,-column=>1,-sticky=>"e");
  my $restart_msf_entry = $msf_dialog_frame -> Entry (-width=>12, -border=>2, -relief=>'groove', -text=>$msf,  -background=>$white,
     -textvariable=>\$msf)->grid(-row=>2,-column=>2,-sticky=>"w");
  $msf_dialog_frame -> Label (-background=>$bgcol, -text=>'New MSF file:')->grid(-row=>3,-column=>1,-sticky=>"e");
  my $new_msf_entry = $msf_dialog_frame -> Entry ( -font=>$font,-width=>12, -border=>2, -relief=>'groove', -text=>$new_msf,  -background=>$white,
     -textvariable=>\$new_msf)->grid(-row=>3,-column=>2,-sticky=>"w");
  $msf_dialog_frame -> Label (-background=>$bgcol, -font=>$font, -text=>"\nNB. Parameter estimates will be commented out.\n", -foreground=>"#444444",-justify=>"left")->grid(-row=>5,-column=>1,-columnspan=>2,-sticky=>"w");
  $msf_dialog_frame -> Button (-text=>'Create',  -font=>$font, -width=>12, -border=>$bbw, -background=>$button, -activebackground=>$abutton,-command=>sub {
    my $overwrite_bool=1;
    if (-e $cwd."/".$new_ctl_name.".".$setting{ext_ctl}) {  # check if control stream already exists;
	$overwrite_bool = message_yesno ("Control stream with name ".$new_ctl_name.".".$setting{ext_ctl}." already exists.\n Do you want to overwrite?", $mw, $bgcol, $font_normal);
    } else {$overwrite_bool=1};
    if ($overwrite_bool==1) {
      my $file = $cwd."/".@ctl_show[@runs[0]].".".$setting{ext_ctl};
      my $new_file = $cwd."/".$new_ctl_name.".".$setting{ext_ctl};
      open (OUT, ">".$new_file);
      my $theta_area=0; my $omega_area=0; my $sigma_area=0;
      foreach $line (@lines) {
        if (substr($line,0,1) eq "\$") {
          if ($theta_area==1) {$theta_area=0} ;
          if ($omega_area==1) {$omega_area=0} ;
          if ($sigma_area==1) {$sigma_area=0} ;
        }
        if (substr ($line,0,6) eq "\$THETA") {$theta_area = 1 }
        if (substr ($line,0,6) eq "\$OMEGA") {$omega_area = 1 }
        if (substr ($line,0,6) eq "\$SIGMA") {$sigma_area = 1 }
        if (substr($line,0,5) eq "\$DATA") {
          print OUT $line."\n\$MSFI ".$msf."\n";
        } else {
          $line =~ s/MSF\=$msf/MSF\=$new_msf/ ;
          if ($theta_area+$omega_area+$sigma_area > 0) {$line = "; ".$line}
          print OUT $line;
        }
      }
      close OUT;
      destroy $msf_dialog;
      sleep(1); # to make sure the file is ready for reading
      refresh_pirana($cwd);
    }
  }) -> grid(-row=>7,-column=>2,-sticky=>"wens");
  $msf_dialog_frame -> Button (-text=>'Cancel',  -border=>$bbw, -width=>12, -justify=>'center', -background=>$button, -activebackground=>$abutton, -command=>sub{
    destroy $msf_dialog
  })->grid(-column=>1,-row=>7,-sticky=>"ens");
};

sub edit_model {
### Purpose : Edit a modelfile, choose to invoke the built-in editor or a user-specified one
### Compat  : W+L?
    my $modelfile = shift;
    if ($^O =~ m/MSWin/) {
	$modelfile = win_path($modelfile);
    } else {
	$modelfile = unix_path($modelfile);
    }
    if ($^O =~ m/darwin/i) {
      	start_command($software{editor}, '"'.$modelfile.'"');
	return();
    }
    unless (-e $software{editor}) {
	open (IN, "<".$modelfile);
	my @lines = <IN>;
	close IN;
	my $text = join ("",@lines);
	text_edit_window ($text, $modelfile, \$mw, $font_fixed);
    } else {
	start_command($software{editor}, '"'.$modelfile.'"');
    }
}

sub tree_models_add_parent {
### Purppose: Recursive function to add parents to model
    my ($model, $parent_ref) = @_;
    my %parent = %$parent_ref;
    my $mod_line;
    if ($parent{$model} ne "") {
	$mod_line = $parent{$model}."::".$model;
    } else {
	$mod_line = $model;
    }
    if ($parent{$parent{$model}} ne "") {
	$mod_line = tree_models_add_parent ($parent{$model}, $parent_ref) . "::" . $mod_line;
    }
    return($mod_line);
}

sub tree_models {
### Purpose : Generate a tree structure and return them as array and text
### Compat  : W+L?
  my @ctl_copy_order; my @tr_unsort; my @tr; my @tr_sorted;
  my %tree; my %model_indent; my @tr;
  my $i=0;
  foreach (@ctl_copy) {
    if ($file_type{@ctl_copy[$i]}==2) {
	$tree{$_} = tree_models_add_parent ($_, \%models_refmod);
    } else {
	push(@tr, $_); # directories
    }
    $i++;
  }
  foreach (@ctl_copy) {
      if ($file_type{$_}==2) {
	  push(@tr_unsort, $tree{$_});
      }
  }
  my @tr_sorted = sort(@tr_unsort);
  push (@tr, @tr_sorted);
  $i = 0;
  foreach (@tr) {
    #print $_." (".$models_refmod{$ctl_copy[$i]}.")\n";
    @spl = split ("\:\:",@tr[$i]);
    @ctl_copy_order[$i] = @spl[@spl-1];
    $model_indent{@ctl_copy_order[$i]} = @spl-1;
    $i++;
  }
  my $tree = tree_models_text (\@tr_sorted);
  return (\@ctl_copy_order, \%model_indent);
}

sub tree_models_text {
    my $tr_sorted_ref = @_;
    my @tr_sorted = @$tr_sorted_ref;
    # generate a tree in text format
    my %lastchild;
    foreach(@tr_sorted) { # get the lastchild's number
	@line = split (/\:\:/, $_);
	$lastchild {@line[-2]} = @line[-1];
    }
    my$last_root_child = @line[0];
    $tree = "";
    my @flags ; my $ofv;
    foreach (@tr_sorted) {
	my @line = split (/\:\:/, $_);
	for ($i=1; $i<=@line; $i++) {
	    $tree .= "  ";
	    if (($lastchild{@line[$i-2]} eq @line[$i-1])||(@line[$i-1] eq $last_root_child)) {@flags[$i] = 1} else {@flags[$i] = 0};
	    #if (@flags[$i] == 0) {$tree .= chr(179)} else {$tree .= " "};
	    if (@flags[$i] == 0) {$tree .= "|"} else {$tree .= " "};
	};
	if (($lastchild{@line[-2]} eq @line[-1])||(@line[-1] eq $last_root_child)) {
	    #chop($tree); $tree .= chr(192).chr(196);
	    chop($tree); $tree .= "`--";
	}
	else {
	    #chop ($tree); $tree .= chr(195).chr(196);
	    $tree .= "--";
	}
	if ($models_ofv{@line[-2]} ne "") {
	    $dofv = rnd($models_ofv{@line[-2]} - $models_ofv{@line[-1]},3);
	} else {
	    $dofv = "";
	}
	if ($models_ofv{@line[-1]} ne "") { $ofv = $models_ofv{@line[-1]}."\t" } else {$ofv ="\t"}
	if (@line>1) {$space="\t"} else {$space="\t\t"}; # try to keep things in line
	if (@line>3) {chop($space);};
	my $info = $models_suc{@line[-1]}.$models_cov{@line[-1]}.$models_bnd{@line[-1]}."\t".$models_sig{@line[-1]};
	$tree .=  @line[-1].$space."\t".$ofv." (".$dofv.") \t".$info."\n";
    }
    return ($tree);
}

sub project_info_window {
### Purpose : Create a dialog shown info for the current project
### Compat  : W+L+
### Note    : save functionality not implemented yet

  # Get project info from database
  my %proj_record;
  my @sql_fields = ("proj_name","descr","modeler","collaborators","start_date","end_date");
  my $db_results = db_get_project_info("pirana.dir");
  if ($db_results eq "") {
      message ("Error opening Pirana database for this folder.");
      return();
  }
  my $row = @{$db_results}[0];
  my @values = @$row;
  my $i=0;
  foreach (@sql_fields) {
    $proj_record{@sql_fields[$i]} = @values[$i];
    $i++;
  }
  $proj_record{"notes"} = @values[$i];
  # Build window
  unless ($project_window) {
    our $project_window = $mw -> Toplevel(-title=>'Project Information');
    $project_window -> OnDestroy ( sub{
       undef $project_window; undef $project_window_frame;
    });
    no_resize ($project_window);
  }
  our $project_window_frame = $project_window -> Frame(-background=>$bgcol)->grid(-ipadx=>10,-ipady=>10)->grid(-row=>1,-column=>1, -sticky=>'nwse');
  my @labels  = ("Project name: ","Description: ","Modeler: ","Collaborators: ","Start date: ","End date: ");
  my @widths  = (20, 40, 20, 40, 20, 20);
  my %proj_rec_entry;
  for ($i=0; $i<@labels; $i++) {
    $project_window_frame -> Label(-text=> @labels[$i], -font=>$font) ->grid(-row=>($i*2)+1,-column=>1,-sticky=>'e');
    $proj_rec_entry{@sql_fields[$i]} = $project_window_frame -> Entry(-text=> $proj_record{@sql_fields[$i]}, -font=>$font_normal, -relief=>'sunken',-border=>$bbw, -width=>@widths[$i],  -background=>$white) -> grid(-row=>($i*2)+1,-column=>2,-sticky=>'w');
    $project_window_frame -> Label(-text=> " ", -font=>$font) ->grid(-row=>($i*2)+2,-column=>1);
  }
  $i++;
  $project_window_frame -> Label(-text=> "Notes:", -font=>$font) ->grid(-row=>($i*2)+1,-column=>1,-sticky=>'e');
  my $proj_notes_text = $project_window_frame ->Scrolled('Text',
      -width=>40, -relief=>'sunken',
      -border=>$bbw,-height=>10,
      -font=>$font_normal, -background=>'white',
      -state=>'normal',-scrollbars=>'e'
  )->grid(-column=>2, -row=>($i*2)+1,-rowspan=>10,-sticky=>'nw');
  $proj_notes_text -> insert("0.0", $proj_record{"notes"});
  $project_window_frame -> Label (-text=>'  ',-font=>$font)->grid(-column=>2, -row=>30,-rowspan=>1);
  $project_window_frame -> Button (-text=>'Save',-font=>$font,  -width=>12, -background=>$button, -activebackground=>$abutton, -border=>$bbw, -command=>sub{
    foreach (keys(%proj_rec_entry)) {
      $proj_record{$_} = $proj_rec_entry{$_} -> get();
    }
    $proj_record{"notes"} = $proj_notes_text -> get("0.0", "end");
    db_insert_project_info (\%proj_record, "pirana.dir"); #print fastgetcwd();
    $project_window -> destroy();
  })->grid(-column=>2, -row=>31,-rowspan=>1, -sticky=>"w");
  $project_window_frame -> Button (-text=>'Cancel', -font=>$font, -width=>12, -background=>$button, -activebackground=>$abutton, -border=>$bbw, -command=>sub{
    $project_window -> destroy();
  })->grid(-column=>1, -row=>31,-rowspan=>1, -sticky=>"e");
}

sub show_estim_window {
### Purpose : Show window with final parameter estimates
### Compat  : W+L+
    my $lst_ref = shift;
    my @lst = @$lst_ref;
    my $modelno = @lst[0]; 
    my $lstfile = @lst[0].".".$setting{ext_res};
    my $modelfile = $lstfile;
    $modelfile =~ s/$setting{ext_res}/$setting{ext_ctl}/i;

    my ($methods_ref, $est_ref, $se_est_ref, $term_ref, $ofv_ref) = get_estimates_from_lst ($lstfile);
    my @methods = @$methods_ref;
    my %est = %$est_ref;
    my %se_est = %$se_est_ref;

    my $last_method = @methods[-1] ;  # take results from the last estimation method
    my $res_ref = $est{$last_method};
    my @res = @$res_ref;
    my $theta_ref = @res[0];  my @th = @$theta_ref;
    my $omega_ref = @res[1];  my @om = @$omega_ref;
    my $sigma_ref = @res[2];  my @si = @$sigma_ref;
    my %ofv = %$ofv_ref;
    my $ofv_val = $ofv{$last_method};

    # do the same for RSE%
    my $se_ref = $se_est{$last_method};
    my @se_est= @$se_ref;
    my @th_se; my @om_se; my @si_se;
    if ($se_ref =~ m/ARRAY/) {
	@se_est = @$se_ref;
	if (@se_est>1) {
	    my $th_se_ref = @se_est[0];  @th_se = @$th_se_ref;
	    my $om_se_ref = @se_est[1];  @om_se = @$om_se_ref;
	    my $si_se_ref = @se_est[2];  @si_se = @$si_se_ref;
	}
    } 

    # and get information from NM model file
    my $modelno = $modelfile;
    my $modelno =~ s/\.$setting{ext_ctl}//;
    my $mod_ref = extract_from_model ($modelfile, $modelno, "all");
    my %mod = %$mod_ref;
    my $theta_names_ref = $mod{th_descr}; my @theta_names = @$theta_names_ref;
    my $omega_names_ref = $mod{om_descr}; my @omega_names = @$omega_names_ref;
    my $sigma_names_ref = $mod{si_descr}; my @sigma_names = @$sigma_names_ref;

    my $cols = ((floor(@theta/10)+1)*3)-1; # calculate no of columns in window
    if (int(@om) > $cols) {$cols = int(@om+1)};
    if (int(@si) > $cols) {$cols = int(@si+1)};
    my $prerows = 2;

    unless ($estim_window) {
	our $estim_window = $mw -> Toplevel();
	$estim_window -> OnDestroy ( sub{
	    undef $estim_window; undef $estim_window_frame; undef @estim_grid; undef @estim_headers;
				     });
	no_resize ($estim_window);
    }
    our $estim_window_frame = $estim_window -> Frame(-background=>$bgcol)->grid(-ipadx=>10,-ipady=>10)->grid(-row=>1,-column=>1, -sticky=>'nwse');

    @estim_grid_headers = ("Parameter", "Description", "Value", "RSE");
    our $estim_grid = $estim_window_frame ->Scrolled('HList', -head => 1,
						     -columns    => 40, -scrollbars => 'se',-highlightthickness => 0,
						     -height     => 25, -width      => 90,
						     -border     => 0, -indicator=>0,
						     -selectborderwidth => 0, -padx=>0, -pady=>0,
						     -background => 'white',
						     -selectbackground => $pirana_orange,
	)->grid(-column => 1, -columnspan=>7,-row => 2,-sticky=>'nwse');
    $estim_grid -> columnWidth(1, 160);

    my $headerstyle = $models_hlist->ItemStyle('window', -padx => 0, -pady=>0);
    foreach my $x ( 0 .. $#estim_grid_headers ) {
        @estim_headers[$x] = $estim_grid -> HdrResizeButton(
	    -text => $estim_grid_headers[$x], -relief => 'flat', -font=>$font_normal,
	    -background=>$button, -activebackground=>$abutton, -foreground=>'black',
	    -border=> 0, -pady => $header_pad, -command => sub {; }, -resizerwidth => 2,
	    -column => $x
	    );
        $estim_grid ->header('create', $x,
			     -itemtype => 'window', -style => $headerstyle,
			     -widget => @estim_headers[$x]
	    );
    }
    $estim_grid -> update();
    $estim_window_frame -> Button (-text=>"Export as CSV", -font=>$font_normal, -background=>$button, -border=>$bbw, -activebackground=>$abutton, -command=> sub{
	my $types = [
	    ['CSV files','.csv'],
	    ['All Files','*',  ], ];
	my $csv_file_choose = $mw-> getSaveFile(-defaultextension => "*.csv", -initialdir=> $cwd ,-filetypes=> $types);
	unless ($csv_file_choose eq "") {
	    grid_to_csv($estim_grid, $csv_file_choose, \@estim_grid_headers, (int(@th)+int(@om)+int(@si)+2), $cols );
	}
    })->grid(-column=>1, -row=>3, -sticky=>"nwse");
    $estim_window_frame -> Button (-text=>"Export as LaTeX", -font=>$font_normal, -background=>$button, -border=>$bbw, -activebackground=>$abutton, -command=> sub{
	grid_to_latex ($estim_grid, $csv_file_choose, \@estim_grid_headers, (int(@th)+int(@om)+int(@si)+2), $cols );
    })->grid(-column=>2, -row=>3, -sticky=>"nwse");
    $estim_window_frame -> Button (-text=>"HTML report", -font=>$font_normal, -background=>$button, -border=>$bbw, -activebackground=>$abutton, -command=> sub{
	my $pirana_notes = $models_notes{$modelno}; 
  	output_results_HTML($lstfile, \%setting, $pirana_notes, \%$run_reports, 0, $lstfile, 1);
	start_command($software{browser}, '"file:///'.unix_path($cwd).'/pirana_sum_'.$_.'.html"');
    })->grid(-column=>3, -row=>3, -sticky=>"nwse");
    my $i = 1; my $j=1; my $max_i = 1;
    if (@th>0) {
	$estim_window ->configure (-title=>$lstfile." (".$last_method.")");
	$estim_grid -> delete("all");

# OFV
	$estim_grid -> add(1);
	$estim_grid -> itemCreate(1, 0, -text => "OFV", -style=>$header_right2);
	$estim_grid -> itemCreate(1, 1, -text => "Objective function value", -style=>$align_left);
	$estim_grid -> itemCreate(1, 2, -text => $ofv_val, -style=>$estim_style_red);
	$estim_grid -> add(2);
	$estim_grid -> itemCreate(2, 0, -text => " ", -style=>$header_right2);

	foreach my $th (@th) {
	    $estim_grid -> add($i+$prerows);
	    $estim_grid -> itemCreate($i+$prerows, 0, -text => "TH ".$i, -style=>$header_right2);
	    my $th_text = rnd($th,4);
	    my $th_rse = "";
	    if (($th!=0)&&(@th_se[$i-1]!=0)) {
		$th_rse = " (".rnd((@th_se[$i-1]/$th*100),3)."%)";
	    }
	    $estim_grid -> itemCreate($i+$prerows, 2, -text => $th_text, -style=>$estim_style);
	    $estim_grid -> itemCreate($i+$prerows, 3, -text => $th_rse, -style=>$estim_style_light);
	    $estim_grid -> itemCreate($i+$prerows, 1, -text => @theta_names[$i-1], -style=>$align_left);
	    $i++;
	}
	if ($max_i > $i) {$i = $max_i};
	$estim_grid -> add($i+$prerows);
	$estim_grid -> itemCreate($i+$prerows, 0, -text => " ", -style=>$header_right2);
	$i++; my $flag=$i; $cnt=1;
	foreach my $om (@om) {
	    @om_x = @$om; $j = 1;
	    $estim_grid -> add($i+$prerows);
	    $estim_grid -> itemCreate($i+$prerows, 0, -text => "OM ".$cnt, -style=>$header_right2);
	    $estim_grid -> itemCreate($i+$prerows, 1, -text => @omega_names[$cnt-1], -style=>$align_left);
	    foreach $om_cov (@om_x) {
		if ($om_cov == 0) {$style = $estim_style_light} else {$style = $estim_style};
		my $om_text = rnd ($om_cov,4);
		if ($j == $cnt) {
		    my $om_se_x = @om_se[$cnt-1];
		    my @om_cov_se = @$om_se_x;
		    if (($om_cov!=0)&&(@om_cov_se[$cnt-1]!=0)) {
			$om_text .= " (".rnd((@om_cov_se[$cnt-1]/$om_cov*100),3)."%)";
#              $estim_grid -> itemCreate($i, $j+2, -text => "(".rnd((@om_cov_se[$cnt-1]/$om_cov*100),3)."%)", -style=>$estim_style_se);
		    }
		}
		$estim_grid -> itemCreate($i+$prerows, $j+1, -text => $om_text, -style=>$style);
		$j++;
	    }
	    $i++; $cnt++;
	}
	$estim_grid -> add($i+$prerows);
	$estim_grid -> itemCreate($i+$prerows, 0, -text => " ", -style=>$header_right2);
	$i++; my $flag=$i; $cnt=1;
	foreach my $si (@si) {
	    @si_x = @$si; $j = 1;
	    $estim_grid -> add($i+$prerows);
	    $estim_grid -> itemCreate($i+$prerows, 0, -text => "SI ".$cnt, -style=>$header_right2);
	    $estim_grid -> itemCreate($i+$prerows, 1, -text => @sigma_names[$cnt-1], -style=>$align_left);
	    foreach $si_cov (@si_x) {
		if ($si_cov == 0) {$style = $estim_style_light} else {$style = $estim_style};
		my $si_text = rnd($si_cov,4);
		if ($j == $cnt) {
		    my $si_se_x = @si_se[$cnt-1];
		    my @si_cov_se = @$si_se_x;
		    if (($si_cov!=0)&&(@si_cov_se[$cnt-1]!=0)) {
			$si_text .= "(".rnd((@si_cov_se[$cnt-1]/$si_cov*100),3)."%)";
		    }
		}
		$estim_grid -> itemCreate($i+$prerows, $j+1, -text => $si_text, -style=>$estim_style);
		$j++;
	    }
	    $i++; $cnt++;
	}
    }
}

sub grid_to_csv {
    my ($grid, $csv_file, $headers_ref, $nrow, $ncol) = @_;
    my @headers = @$headers_ref;
    open (OUT, ">".$csv_file);
    print OUT join(",", @headers)."\n";
    for ($j = 1; $j <= $nrow; $j++) {
	if ($grid -> infoExists($j)) {
	    for ($i = 0; $i < $ncol; $i++) {
		if ($grid -> itemExists($j, $i)) {
		    my $value = $grid -> itemCget($j, $i, "text");
		    chomp($value);
		    $value =~ s/\,/;/g;
		    $value =~ s/[\(\)]//g;
		    print OUT $value;
		} 
		unless(($ncol-$i) ==1) {
		    print OUT ",";
		}
	    }
	    print OUT "\n";
	}
    }
    close OUT;
    if (-e $csv_file) {
	if ((-e $software{spreadsheet})||($^O =~ m/darwin/i)) {
	    start_command($software{spreadsheet},'"'.$csv_file.'"');
	} else {message("Spreadsheet application not found. Please check settings.")};
    }
}

sub grid_to_latex {
    my ($grid, $csv_file, $headers_ref, $nrow, $ncol) = @_;
    my @headers = @$headers_ref;
    pop (@headers);
    my $tex = "\\begin{tabular}[t]{*{".$ncol."}{l}}\n";
    
    for (my $i = 0; $i < int(@headers); $i++) {
	$tex .= @headers[$i];
	unless ($i == (@headers-1)) {
	    $tex .= " & ";
	}
    } 
    $tex .= " \\\\ \n";
    for (my $j = 1; $j <= $nrow; $j++) {
	if ($grid -> infoExists($j)) {
	    for ($i = 0; $i < $ncol; $i++) {
		if ($grid -> itemExists($j, $i)) {
		    my $value = $grid -> itemCget($j, $i, "text");
		    chomp($value);
		    $value =~ s/\,/;/g;
		    $value =~ s/[\(\)]//g;
		    $tex .= $value;
		} 
		unless(($ncol-$i) <= 1) {
		    $tex .= " & ";
		}
	    }
	    $tex .= " \\\\ \n";
	}
    }
    $tex .= "\\end{tabular}\n";
    unless (-d $cwd."/pirana_temp") { mkdir ($cwd."/pirana_temp") };
    text_to_file (\$tex, $cwd."/par_estimates.tmp");
    if (-e $cwd."/par_estimates.tmp") {
	edit_model ($cwd."/par_estimates.tmp");
    }    
}

sub show_estim_multiple {
### Purpose : Show window with final parameter estimates
### Compat  : W+L+
    my $lst_ref = shift;
    my @lst = @$lst_ref;
    my $lstfile = @lst[@lst].".".$setting{ext_res};
    my $modelfile = $lstfile;
    $modelfile =~ s/$setting{ext_res}/$setting{ext_ctl}/i;

    # get estimates for all models
    my (@th_all, @om_all, @si_all, @ofv_vals);
    my ($max_th, $max_om, $max_si);
    foreach my $lst_temp (@lst) {
	$lst_temp .= ".".$setting{ext_res};
	my ($methods_ref, $est_ref, $se_est_ref, $term_ref, $ofv_ref) = get_estimates_from_lst ($lst_temp);
	my @methods = @$methods_ref;
	my %est = %$est_ref;
	my %se_est = %$se_est_ref;
	my %ofv = %$ofv_ref;
	
	my $last_method = @methods[-1] ;  # take results from the last estimation method
	my $res_ref = $est{$last_method};
	my @res = @$res_ref;
	my $theta_ref = @res[0];  
	my $omega_ref = @res[1];  
	my $sigma_ref = @res[2];  
	push(@th_all, $theta_ref);
	push(@om_all, $omega_ref);
	push(@si_all, $sigma_ref);
	if (int(@$theta_ref)>$max_th) {$max_th = int(@$theta_ref) }
	if (int(@$omega_ref)>$max_om) {$max_om = int(@$omega_ref) }
	if (int(@$sigma_ref)>$max_si) {$max_si = int(@$sigma_ref) }
	push (@ofv_vals, $ofv{$last_method});
    }

    # and get information from NM model file, only for first one
    my $modelno = $modelfile;
    my $modelno =~ s/\.$setting{ext_ctl}//;
    my $mod_ref = extract_from_model ($modelfile, $modelno, "all");
    my %mod = %$mod_ref;
    my $theta_names_ref = $mod{th_descr}; my @theta_names = @$theta_names_ref;
    my $omega_names_ref = $mod{om_descr}; my @omega_names = @$omega_names_ref;
    my $sigma_names_ref = $mod{si_descr}; my @sigma_names = @$sigma_names_ref;
    my $max_th_names = int(@theta_names);

    my $cols = int(@lst) + 2; # calculate no of columns in window

    unless ($estim_window) {
	our $estim_window = $mw -> Toplevel();
	$estim_window -> OnDestroy ( sub{
	    undef $estim_window; undef $estim_window_frame; undef @estim_grid; undef @estim_headers;
				     });
	no_resize ($estim_window);
    }
    our $estim_window_frame = $estim_window -> Frame(-background=>$bgcol)->grid(-ipadx=>10,-ipady=>10)->grid(-row=>1,-column=>1, -sticky=>'nwse');
    $estim_window ->configure (-title=>"Comparison of multiple runs");

    @estim_grid_headers = ("Parameter", "Description");
    foreach (@lst) {
	$_ =~ s/\.$setting{ext_res}//i;
	push (@estim_grid_headers, $_);
    }
    push (@estim_grid_headers, " ");
    our $estim_grid = $estim_window_frame ->Scrolled('HList', -head => 1,
						     -columns    => 40, -scrollbars => 'se',-highlightthickness => 0,
						     -height     => 40, -width      => 90,
						     -border     => 0, -indicator=>0,
						     -selectborderwidth => 0, -padx=>0, -pady=>0,
						     -background => 'white',
						     -selectbackground => $pirana_orange,
	)->grid(-column => 1, -columnspan=>7,-row => 2,-sticky=>'nwse');
    $estim_grid -> columnWidth(1, 160);

    my $headerstyle = $models_hlist->ItemStyle('window', -padx => 0, -pady=>0);
    foreach my $x ( 0 .. $#estim_grid_headers ) {
        @estim_headers[$x] = $estim_grid -> HdrResizeButton(
	    -text => $estim_grid_headers[$x], -relief => 'flat', -font=>$font_normal,
	    -background=>$button, -activebackground=>$abutton, -foreground=>'black',
	    -border=> 0, -pady => $header_pad, -command => sub {; }, -resizerwidth => 2,
	    -column => $x
	    );
        $estim_grid ->header('create', $x,
			     -itemtype => 'window', -style => $headerstyle,
			     -widget => @estim_headers[$x]
	    );
    }
    $estim_grid -> update();
    $estim_window_frame -> Button (-text=>"Export as CSV", -font=>$font_normal, -background=>$button, -border=>$bbw, -activebackground=>$abutton, -command=> sub{
	my $types = [
	    ['CSV files','.csv'],
	    ['All Files','*',  ], ];
	my $csv_file_choose = $mw-> getSaveFile(-defaultextension => "*.csv", -initialdir=> $cwd ,-filetypes=> $types);
	unless ($csv_file_choose eq "") {
	    grid_to_csv($estim_grid, $csv_file_choose, \@estim_grid_headers, ($max_th+$max_om+$max_si+2+2), $cols );
	}
    })->grid(-column=>1, -row=>3, -sticky=>"nwse");
    $estim_window_frame -> Button (-text=>"Export as LaTeX", -font=>$font_normal, -background=>$button, -border=>$bbw, -activebackground=>$abutton, -command=> sub{
	grid_to_latex ($estim_grid, $csv_file_choose, \@estim_grid_headers, (int($max_th)+int($max_om)+int($max_si)+2+2), $cols);
    })->grid(-column=>2, -row=>3, -sticky=>"nwse");
    
# First create the correct number of entries for theta/om/si
# create CSV
     $i = 1; $j=1; my $max_i = 1;
    my $max_all = max(($max_th_names, $max_th)) ;
    my $prerows = 2;
    if ($max_th > 0) {
 	$estim_grid -> delete("all");
	$estim_grid -> add(1);
	$estim_grid -> itemCreate(1, 0, -text => "OFV", -style=>$header_right2);
	$estim_grid -> add(2);
	$estim_grid -> itemCreate(2, 0, -text => " ", -style=>$header_right2);
	for($i = 1; $i <= $max_all; $i++) {
	    $estim_grid -> add(($i+$prerows));
	    $estim_grid -> itemCreate(($i+$prerows), 0, -text => "TH ".$i, -style=>$header_right2);
	    $estim_grid -> itemCreate(($i+$prerows), 1, -text => @theta_names[($i-1)], -style=>$align_left);
	}
	$estim_grid -> add($max_th+$prerows+1);
	$estim_grid -> itemCreate($max_th+$prerows+1, 0, -text => " ", -style=>$header_right2);
	for($i = 1; $i <= $max_om; $i++) {
	    $estim_grid -> add($max_th+1+$i+$prerows);
	    $estim_grid -> itemCreate(($max_th+1+$i+$prerows), 0, -text => "OM ".$i, -style=>$header_right2);
	    $estim_grid -> itemCreate(($max_th+1+$i+$prerows), 1, -text => @omega_names[($i-1)], -style=>$align_left);
	}
	$estim_grid -> add($max_th+$max_om+$prerows+2);
	$estim_grid -> itemCreate($max_th+$max_om+$prerows+2, 0, -text => " ", -style=>$header_right2);
	for($i = 1; $i <= $max_si; $i++) {
	    $estim_grid -> add($max_th+$max_om+2+$prerows+$i);
	    $estim_grid -> itemCreate(($max_th+$max_om+2+$i+$prerows), 0, -text => "SI ".$i, -style=>$header_right2);
	    $estim_grid -> itemCreate(($max_th+$max_om+2+$i+$prerows), 1, -text => @sigma_names[($i-1)], -style=>$align_left);
	}
     }
    $total_rows = $max_th+$max_om+2+$i+$prerows;
    my $col = 2;
    foreach my $lst_temp (@lst) {
	my $th_ref = shift(@th_all);
	my $om_ref = shift(@om_all);
	my $si_ref = shift(@si_all);
	my $ofv_val = shift (@ofv_vals);
	my @th = @$th_ref;
	my @om = @$om_ref;
	my @si = @$si_ref;
	my $i = 1;
	$estim_grid -> itemCreate(1, 1, -text => "Objective function value", -style=>$align_left);
	$estim_grid -> itemCreate(1, $col, -text => $ofv_val, -style=>$estim_style_red);
	foreach (@th) {
	    my $th_text = rnd($_,4);
	    $estim_grid -> itemCreate(($i+$prerows, $col), -text => $th_text, -style=>$estim_style);
	    $i++;
	}
	my $i = 1;
	foreach (@om) {
	    my @om_tmp = @$_;
	    my $om_text = rnd(@om_tmp[(int(@om_tmp)-1)],4);
	    $estim_grid -> itemCreate(($max_th+$prerows+1+$i), $col, -text => $om_text, -style=>$estim_style);
	    $i++;
	}
	my $i = 1;
	foreach (@si) {
	    my @si_tmp = @$_;
	    my $si_text = rnd(@si_tmp[(int(@si_tmp)-1)],4);
	    $estim_grid -> itemCreate(($max_th+$max_om+$prerows+2+$i), $col, -text => $si_text, -style=>$estim_style);
	    $i++;
	}
	$col++;
    }
     
}

sub read_log {
### Purpose : Read Pirana log file
### Compat  : W+L?
    if (-e "<".$home_dir."/log/pirana.log") {
      open (NM_LOG, "<".$home_dir."/log/pirana.log");
      @lines = <NM_LOG>;
      $nm_inst_chosen = @lines[0];
      if ($nm_dirs{$nm_inst_chosen} eq "") {$nm_inst_chosen=""};
      $active_project = @lines[1];
      $cwd = $project_dir{@lines[1]};
      close NM_LOG;
    }
}

sub save_log {
### Purpose : Save pirana log file
### Compat  : W+L?
    if (-e "<".$home_dir."/log/pirana.log") {
      open (NM_LOG, ">".$home_dir."/log/pirana.log");
      print NM_LOG $nm_inst_chosen."\n";
      print NM_LOG $active_project;
      close NM_LOG;
    }
}

sub add_nm_inst {
### Purpose : Add a local NM installation to Pirana
### Compat  : W+L+
    my ($nm_locality, $nm_local_hlist, $nm_remote_hlist) = @_;
    my $nm_inst_w = $mw -> Toplevel(-title=>"Manually add NONMEM installation to Pira�a");
    no_resize ( $nm_inst_w ) ;
    my $nm_inst_frame = $nm_inst_w -> Frame(-background=>$bgcol)->grid(-ipadx=>'10',-ipady=>'10',-sticky=>'n');
    center_window($nm_inst_w, $setting{center_window}); # center after adding frame (redhat)

    $nm_inst_frame -> Label (-text=>"Name in Pira�a: ",-font=>$font,-background=>$bgcol)->grid(-row=>2,-column=>1,-sticky=>"e");
    $nm_inst_frame -> Label (-text=>"NM Location: ",-font=>$font,-background=>$bgcol)->grid(-row=>3,-column=>1,-sticky=>"e");
    if ($nm_locality ne "local"){$nm_inst_frame -> Label (-text=>"NM version: ",-font=>$font,-background=>$bgcol)->grid(-row=>4,-column=>1,-sticky=>"e")};

    my $nm_name = "nm7";
    my $nm_dir  = "C:\\NONMEM\\nm7";
    unless ($os =~ m/MSWin/i) {
	$nm_dir = "/opt/NONMEM/nm7";
    }

    my $nm_type = "regular";
    $nm_inst_frame -> Entry (-textvariable=>\$nm_name,  -background=>$white, -border=>$bbw,-width=>16,-border=>2, -relief=>'groove')
	->grid(-column=>2,-row=>2,-sticky=>"w");
    $nm_inst_frame -> Entry (-textvariable=>\$nm_dir, -background=>$white, -border=>$bbw,-width=>40,-border=>2, -relief=>'groove')
	->grid(-column=>2,-row=>3, -columnspan=>2, -sticky=>"w");
    my $browse_button = $nm_inst_frame -> Button(-image=>$gif{browse}, -width=>28, -border=>0, -command=> sub{
	$nm_dir = $mw-> chooseDirectory();
	if($nm_dir eq "") {$nm_dir = "C:\\nmvi"};
	$nm_inst_w -> focus();
						 })->grid(-row=>3, -column=>3, -rowspan=>1, -sticky => 'nse');
    $help -> attach($browse_button, -msg => "Browse filesystem");
	 if($nm_locality ne "local"){$nm_inst_frame -> Optionmenu (-options=>["5","6","7", "7.2"],-variable=>\$nm_ver,-border=>$bbw,-font=>$font_normal,
				  -background=>$lightblue, -activebackground=>$darkblue,-foreground=>$white,-activeforeground=>$white)
	->grid(-column=>2,-row=>4,-sticky=>"w")};
    $nm_inst_frame -> Label (-text=>" ",-background=>$bgcol)->grid(-row=>5,-column=>1,-sticky=>"e");
    my $nm_ini_file;
    $nm_inst_frame -> Button (-text=>"Add",-font=>$font, -width=>12, -background=>$button, -border=>$bbw, -activebackground=>$abutton, -command=> sub{

	my $exists = 0;
	if ($nm_locality eq "local") {
	    if ($nm_dirs{$nm_name}) {
		$exists = 1;
	    }
	} else {
	    if ($nm_dirs_cluster{$nm_name}) {
		$exists = 1;
	    }
	}
	if ($exists == 1) {
	    message("A NONMEM installation with that name already exists in Pira�a.\nPlease choose another name.")
	} else {
	    if ($nm_locality eq "local") {
		$nm_ver = detect_nm_version($nm_dir);
	    }
	    $nm_ver =~ s/7\.2/72/; # the command is nmfe72
	    $valid_nm = 0;
	    if ($nm_locality eq "local") {
		my $add_base_drive = "";
		if (($^O =~ m/MSWin/g)&!(substr($nm_dir, 0, 2) =~ m/.:/))  {
		    $add_base_drive = $base_drive."/"; # if no drive is specified, add the base_drive (from which pirana is started)
		}
		$nm_ini_file = "nm_inst_local.ini";
		# look if it is maybe an NMQual NM isntallation
		$nmq_name = get_nmq_name($nm_dir);
		if (-e unix_path($add_base_drive.$nm_dir."/test/".$nmq_name.".pl")) {
		    $nm_type = "nmqual";
		    $valid_nm = 1;
		}
		# regular installation
#		print($nm_dir."/util/nmfe".$nm_ver);
		if ((-e unix_path($add_base_drive.$nm_dir."/util/nmfe".$nm_ver).".bat")||(-e unix_path($nm_dir."/util/nmfe".$nm_ver))||(-e unix_path($add_base_drive.$nm_dir."/util/nmfe".$nm_ver."original.bat"))) {
#		    print('test');
		    $nm_type = "regular";
		    $valid_nm = 1;
		}
	    } else { # SSH, just assume it is the correct location and regular installation
		$nm_ini_file = "nm_inst_cluster.ini";
		$valid_nm = 1;
		$nm_type = "regular";
	    }
    }
	if ($valid_nm==1) {
	    if ($nm_locality eq "local") {
		$nm_dirs{$nm_name} = $nm_dir;
		my $nm_ver = detect_nm_version($nm_dir);
		$nm_vers{$nm_name} = $nm_ver;
		$nm_types{$nm_name} = $nm_type;
		save_ini ($home_dir."/ini/".$nm_ini_file, \%nm_dirs, \%nm_vers, $base_dir."/ini_defaults/".$nm_ini_file, 1);
		unless ($nm_type eq "regular") {
		    nmqual_compile_script ($nm_dir, $nmq_name);
		};
	    } else {
		$nm_dirs_cluster{$nm_name} = $nm_dir;
		$nm_vers_cluster{$nm_name} = $nm_ver;
		$nm_types_cluster{$nm_name} = $nm_type;
		save_ini ($home_dir."/ini/".$nm_ini_file, \%nm_dirs_cluster, \%nm_vers_cluster, $base_dir."/ini_defaults/".$nm_ini_file, 1);
	    }
	    undef $nm_versions_menu;
	    $nm_inst_w -> destroy;
	    populate_manage_nm_hlist ($nm_local_hlist, $nm_remote_hlist);	
	    return();
	} else {
	    message("Cannot find nmfe".$nm_ver.".bat (regular installation) or Perl-file (NMQual).\n Check if installation is valid.")
	};
			      })-> grid(-row=>6,-column=>2,-sticky=>"nwse");
    # my $quick_search_button = $nm_inst_frame -> Button (-text=>"Quick search",  -font=>$font,-width=>20, -background=>$button, -border=>$bbw, -activebackground=>$abutton, -command=> sub{
    #     $nm_inst_w -> destroy();
    #     smart_nm_search_dialog();
    # })-> grid(-row=>6,-column=>3,-sticky=>"nwse");
#  $help -> attach($quick_search_button, -msg => "Perform a quick search for NM installations on the local system");

    $nm_inst_frame -> Button (-text=>"Cancel", -font=>$font, -width=>12, -background=>$button, -border=>$bbw, -activebackground=>$abutton, -command=> sub{
	$nm_inst_w -> destroy;
	return();
     })-> grid(-row=>6,-column=>1,-sticky=>"nwse");
}


sub save_ini {
### Purpose : Save Pirana settings contained in a hash to ini-file.
### Compat  : W+L?
    ($ini_file, $ref_ini, $ref_ini_descr, $ini_def, $add_to_ini) = @_;
    my %ini = %$ref_ini;
    my %ini_descr = %$ref_ini_descr;
    my %ini_add_1;
    if ($ref_add_1 ne "") { %ini_add_1 = %$ref_add_1 };
    my %cat;
    if ($cat_ref ne "") { %cat = %$cat_ref };

    open (INI, "<".unix_path($ini_def));
    my @lines=<INI>;
    close INI;
    open (INI, ">".unix_path($ini_file));
    foreach (@lines) {
	if ((substr($_,0,1) eq "#")||(substr($_,0,1) eq "[")) {
	    print INI $_;
	} else {
	    chomp($_);
	    my ($key, $value, $descr) = split (/,/, $_);
	    #      chomp ($ini_descr{$key}) ;# =~ s/\n/\\
	    if (exists $ini{$key}) {
		print INI $key.",".$ini{$key}.",".$ini_descr{$key};
		delete $ini{key};
	    } else {
		print INI $_; # use line from default ini file
	    }
	    print INI "\n";    
	}
    }
    if ($add_to_ini == 1) { # used e.g. for nm_inst_local.ini.
	foreach my $key (keys(%ini)) {
	    print INI $key.",".$ini{$key}.",".$ini_descr{$key};
	    print INI "\n";    
	}
    }
    close INI;
}


sub show_script_params {
### Purpose : In the interface for scripts (currently discontinued function) show the script parameters
### Compat  : W+L?
    $script = shift ;
    if ($edit_scripts_params) {
	$edit_scripts_params->destroy();
	our $edit_scripts_params = $edit_scripts_w -> Frame(-background=>$bgcol)->grid(-ipadx=>'10',-ipady=>'10',-sticky=>'n',-column=>2,-row=>1);
	$edit_scripts_params -> Label (-text=>"Description: ", -font=>$font_bold)->grid(-column=>1,-row=>1,-sticky=>"w");
	$edit_scripts_params -> Label (-text=>"Parameters: ",-font=>$font_bold)->grid(-column=>1,-row=>3,-sticky=>"w");
	$edit_scripts_params -> Label (-text=>" ", -width=>"60")->grid(-column=>2,-row=>1,-sticky=>"w");
    }
    ($descr_ref, $defaults_ref, $script_desc) = read_scripts($script);
    $descr_label = $edit_scripts_params -> Label (-text=>substr($script_desc,0,65), -font=>$font_normal)->grid(-column=>1,-row=>2,-columnspan=>2,-sticky=>"w");
    $help -> attach($descr_label, -msg => $script_desc);
    %defaults = %$defaults_ref;
    our %descr = %$descr_ref;
    $i=0; %p_entry;
    foreach (keys (%descr)) {
	$edit_scripts_params -> Label (-text=>substr($_,0,15), -justify=>'left')->grid(-column=>1,-row=>$i+4,-sticky=>"w");
	if (exists $vars{$_}) {$defaults{$_} = $vars{$_}};         # you can use internal pirana variables for your scripts
	if (exists $setting{$_}) {$defaults{$_} = $setting{$_}};   # dito for settings
	if (exists $software{$_}) {$defaults{$_} = $software{$_}}; # dito for software settings
	$width = length($defaults{$_});
	if($width < 10) {$width=20} else {$width=40};
	$p_entry{$_} = $edit_scripts_params -> Entry ( -background=>$white, -textvariable=>\$defaults{$_}, -width=>$width, -border=>2, -relief=>'groove')->grid(-column=>2,-row=>$i+4,-sticky=>"w");
	$help -> attach($p_entry{$_}  , -msg => $descr{$_});
	$i++;
    }
}

sub read_scripts {
### Purpose : Read the scripts in the current directory
### Compat  : W+L?
    $script = shift;
    open (SCRIPT, "<".$base_dir."/scripts/".$script);
    @lines = <SCRIPT>;
    close (SCRIPT);
    $arg_flag=0; $descr_flag=0; $script_descr="";
    my %arguments_descr, my %arguments_default;
    foreach (@lines) {
	if ($_ =~ m/<\/description>/i) {$descr_flag=0};
	if ($_ =~ m/<\/arguments>/i) {$arg_flag=0};
	if ($arg_flag==1) {
	    ($key,$descr,$default) = split(/,/,$_);
	    $key =~ s/\#//g;
	    $key =~ s/ //g;
	    $key =~ s/-//;
	    chomp($default);
	    $arguments_descr{$key} = $descr;
	    $arguments_default{$key} = $default;
	}
	if ($descr_flag==1) {
	    $script_descr = $_;
	    chomp($script_descr);
	    $script_descr =~ s/\#//;
	}
	if ($_ =~ m/<arguments>/i) {$arg_flag=1};
	if ($_ =~ m/<description>/i) {$descr_flag=1};
    }
    return \%arguments_descr, \%arguments_default, $script_descr;
}

sub edit_ini_window {
### Purpose : Open a window to edit preferences/software settings
### Compat  : W+L?
  my ($ini_file, $ref_ini, $ref_ini_descr, $title, $software) = @_;
  my %ini = %$ref_ini;
  my %ini_descr = %$ref_ini_descr;
  open (INI, "<".unix_path($home_dir."/ini/".$ini_file));
  my @lines=<INI>;
  close INI;
  my @keys;
  my @sections; my @sections_cnt;
  my $i=0;
  foreach(@lines) {
    unless ((substr($_,0,1) eq "#")||(substr($_,0,1) eq "[")) {
       ($key,$value)=split(/,/,$_);
       push (@keys, $key);
       $i++;
    }
    if (substr($_,0,1) eq "[") {
      my $sect = $_;
      $sect =~ s/\[//;
      $sect =~ s/\]//;
      chomp($sect);
      push (@sections, $sect);
      push (@sections_cnt, $i);
    }
  }
  close INI;
  my $edit_ini_w = $mw -> Toplevel(-title=>$title);
  no_resize ($edit_ini_w);
  my $edit_ini_frame = $edit_ini_w -> Frame(-background=>$bgcol)->grid(-ipadx=>'10',-ipady=>'10',-sticky=>'n');
  center_window($edit_ini_w, $setting{center_window}); # center after adding frame (redhat)
  # $edit_ini_frame -> Label (-text=>"Pira�a settings: ")->grid(-column=>1, -row=>1);
  my $row=2; my $col=1;
  my $i=0; my $j=0;
  my @ini_value;
  foreach (@keys) {
       if (length($ini{$_})<10) {$length=10} else {$length=40};
       if ((@sections_cnt[$j]==$i)&&(@sections_cnt>0)) {
         $edit_ini_frame -> Label (-text=>@sections[$j], -font=>$font_bold, -background=>$bgcol)->grid(-column=>$col,-row=>$row, -sticky=>"w"); # spacer
         $row++;
         $j++;
       }
       if($row==int(((@keys+@sections)/2)-0.1)+3) {$row=2; $col=$col+3};
       $edit_ini_frame -> Label (-text=>$_, -background=>$bgcol, -font=>$font_normal)->grid(-column=>$col,-row=>$row,-sticky=>"e",-ipadx=>'8');
       $edit_ini_frame -> Label (-text=>"  ", -background=>$bgcol)->grid(-column=>$col+2,-row=>$row); # spacer
       @ini_value[$i]=$ini{$_};
       $entry_color=$white;
       if (($software==1)&&(!($^O =~ m/darwin/i))) {
         if ((-d @ini_value[$i])||(-e @ini_value[$i])) {$entry_color=$lightgreen} else {$entry_color=$lightred};
       };
       @edit_ini_entry[$i] = $edit_ini_frame -> Entry (-textvariable=>\@ini_value[$i],-border=>2, -relief=>'groove',-background=>$entry_color,-width=>$length)
         ->grid(-column=>$col+1,-row=>$row,-sticky=>"w");
       $help -> attach(@edit_ini_entry[$i], -msg => $ini_descr{$_});
       $row++;
       $i++;
       if($row==int(((@keys+@sections)/2)-0.1)+3) {$row=2; $col=$col+3};
  }  
  if ($title =~ m/preferences/i) {
      $edit_ini_frame -> Label (-text=>"\nNote: Some settings may require a restart of Pirana to take effect.\n", -font=>$font, -background=>$bgcol)->grid(-column=>1, -row=>int((@keys+@sections)/2)+3,-columnspan=>4,-sticky=>"nws");
  } else {
      $edit_ini_frame -> Label (-text=>" ", -font=>$font, -background=>$bgcol)->grid(-column=>1, -row=>int((@keys+@sections)/2)+3,-columnspan=>4,-sticky=>"e");
  }  
  $edit_ini_frame -> Button (-text=>'Save', -width=>12, -font=>$font_normal, -background=>$button, -activebackground=>$abutton, -border=>$bbw, -command=>sub{
    $i=0;
    foreach(@keys) {  # update %settings
	if (@ini_value[$i] eq "" ) { @ini_value[$i] = " "};
	$ini{$_} = @ini_value[$i];
	$i++;
    }
    save_ini ($home_dir."/ini/".$ini_file, \%ini, \%ini_descr, $base_dir."/ini_defaults/".$ini_file);
    chdir($base_dir);
    my $software_ini = "software_linux.ini";
    if ($os =~ m/darwin/i) {$software_ini = "software_osx.ini";}
    if ($os =~ m/MSWin/i) {$software_ini = "software_win.ini";}
    ($software_ref,$software_descr_ref) = read_ini($home_dir."/ini/".$software_ini);
    %software = %$software_ref; %software_descr = %$software_descr_ref;
    ($setting_ref,$setting_descr_ref) = read_ini($home_dir."/ini/settings.ini");
    %setting = %$setting_ref; %setting_descr = %$setting_descr_ref;
    ($psn_commands_ref, $psn_commands_descr_ref) = read_ini($home_dir."/ini/psn.ini");
    %psn_commands = %$psn_commands_ref; our %psn_commands_descr = %$psn_commands_descr_ref;
    $psn_parameters = $psn_commands{$psn_option};
    if ($psn_command_entry) {$psn_command_entry -> update();}
    $edit_ini_w->destroy;
    refresh_pirana($cwd,$filter,1);
  })->grid(-row=>int((@keys+@sections)/2)+4,-column=>5,-sticky=>"w");
  $edit_ini_frame -> Button (-text=>"Cancel", -width=>12, -font=>$font_normal, -background=>$button, -border=>$bbw, -activebackground=>$abutton, -command=> sub{
    $edit_ini_w->destroy;
  })-> grid(-row=>int((@keys+@sections)/2)+4,-column=>4,-sticky=>"e");
}

sub read_sizes {
### Purpose : Read the SIZES file (NM6) and return them in an array
### Compat  : W+
  my $nm_dir = shift;
  if (-e unix_path($nm_dir)."/SIZES") {
    open (SIZES, "<".unix_path($nm_dir)."/SIZES");
    @lines = <SIZES>;
    close SIZES;
    my %setting;
    $i=0; $line=0;
    foreach(@lines) {
      unless (substr($_,0,2) eq "C ") {
        if ($_ =~ m/PARAMETER/) {
          @line = split(/\((.*)\)/,$_);
          @line_split = split (/=/,@line[1]);
          @sizes_key[$i] = @line_split[0];
          @sizes_value[$i] = @line_split[1];
          chomp($comments);
          @sizes_comment[$i] = $comments;
          $comments="";
          $i++;
        }
      } else {if (($line>8)&($_ ne "")) {$_ = substr($_,2,length($_)-2); $comments .= $_ ;}}
      $line++;
    }
  }
  return \@sizes_key, \@sizes_value, \@sizes_comment;
}

sub refresh_sizes {
### Purpose : Refresh the sizes values in the dialog
### Compat  : W+L+
    my ($nm_type_chosen, $nm_vers_chosen, $nm_dir_chosen, $nm_chosen, $nm_manage_frame) = @_;
    if ($nm_type_chosen ne "SSH") {
       my $sizes_frame = $nm_manage_frame ->  Frame(-background=>$bgcol) -> grid(-ipadx=>'10',-ipady=>'10',-sticky=>'nws',-column=>1,-row=>6,-columnspan=>3);
       my @sizes; my @sizes_key; my @sizes_value; my @sizes_comment;
       my @sizes_refs = read_sizes($nm_dir_chosen);
       my ($sizes_key_ref,$sizes_value_ref,$sizes_comment_ref) = @sizes_refs;
       @sizes_key = @$sizes_key_ref;
       @sizes_value = @$sizes_value_ref;
       @sizes_comment = @$sizes_comment_ref;
       $row=0; $col=1; $i=0;
       foreach (@sizes_key) {
          $sizes_frame -> Label (-text=>@sizes_key[$i], -font=>$font, -background=>$bgcol)->grid(-column=>$col,-row=>$row,-sticky=>"e",-ipadx=>'8');
          $sizes_frame -> Label (-text=>"  ", -background=>$bgcol)->grid(-column=>$col+2,-row=>$row); # spacer
          if ($nm_type_chosen =~ m/SSH/i) {@sizes_value[$i] = ""};
		    if (($nm_type_chosen =~ m/nmq/i)||($nm_type_chosen =~ m/SSH/i)) {$state='disabled'} else {$state='normal'};
          @sizes_entry[$i] = $sizes_frame -> Entry (-textvariable=>\@sizes_value[$i],  -background=>$white, -state=>$state,-border=>2, -relief=>'groove')->grid(-column=>$col+1,-row=>$row);
          $help->attach(@sizes_entry[$i], -msg => @sizes_comment[$i] );
          $row++; $i++;
          if($row==18&&$col==1) {$row=0; $col=4};
          if($row==18&&$col==4) {$row=0; $col=7};
       }
    } else {
      my $na = "NA";
      foreach (@sizes_entry) {
        $_ -> configure(-textvariable => \$na) ;
      }
      if ($sizes_frame) {$sizes_frame -> destroy(); undef $sizes_frame;}
      $nm_manage_frame -> update();
    };
}

sub save_sizes {
### Purpose : Save SIZES file (NM6)
### Compat  : W+
  ($dir_ref, $keys_ref, $values_ref) = @_;
  my @key = @$keys_ref;
  my @value = @$values_ref;
  open (SIZ_OLD, "<".unix_path($nm_dirs{$dir_ref})."/SIZES");
  @lines = <SIZ_OLD>;
  close (SIZ_OLD);
  open (SIZ_NEW, ">".unix_path($nm_dirs{$dir_ref})."/SIZES");
  $i=0; $j=0;
  foreach(@lines) {
    unless (substr($_,0,2) eq "C ") {
      if (@lines[$i] =~ m/PARAMETER \(/) {
        if (@lines[$i] =~ m/@key[$j]=/) {
          print SIZ_NEW "      PARAMETER (".@key[$j]."=".@value[$j].")\n";
          $j++;
        } else {
          print SIZ_NEW @lines[$i];
        }
      } else {print SIZ_NEW @lines[$i];}
    } else {print SIZ_NEW @lines[$i];}
    $i++;
  }
  close SIZ_NEW;
}

sub create_nmfe_compile_bat_files {
### Purpose : Create bat-file for compilation of a NM run. Bat file is adapted from nmfe6.bat or nmfe7.bat
### Compat  : W+L-
    my $nm = @_;
    $i=1; foreach (keys(%nm_dirs)) {
	my $ver=$nm_vers{$_};
	my $dir=$nm_dirs{$_};
	my $type=$nm_types{$_};
	if ($^O =~ m/MSWin/i) {
	    unless (substr($dir, 0, 2) =~ m/.:/i )  {
		$dir = unix_path ($base_drive."/".$dir); # if no drive is specified, add the base_drive (from which pirana is started)
	    }
	}
	unless ($dir eq "") {
	    unless ((-e $dir."/util/pirana_nmfe".$ver."_compile.bat")||(-d $dir."/test/")) {
		unless (copy ($dir."/util/nmfe".$ver.".bat", $dir."/util/pirana_nmfe".$ver."_compile.bat")) {
		    print LOG "Compile batch file could not be created.\n"; close LOG;
		    intro_msg(1)
		};
		open (COMP,"<".$dir."/util/pirana_nmfe".$ver."_compile.bat");
		@lines=<COMP>; close COMP;
		open (OUT,">".$dir."/util/pirana_nmfe".$ver."_compile.bat");
		$k=0; $flag=0;
		foreach(@lines) {
		    if (@lines[$k] =~ m/Starting/ && $flag==0) {
			for ($j=-1;$j<=9;$j++) {
			    @lines[$k+$j] = "rem ".@lines[$k+$j];
			}
			$flag=1;
		    }
		    print OUT @lines[$k];
		    $k++;
		}
		close OUT;
	    }
	}
	$i++;
    }
    close LOG;
}


sub nmqual_xml {
### Purpose : Read an NMQual XML file, and return the NM target directory and the NM version
### Compat  : W+L+
  my $nmq_xml = shift;
  open (XML, "<".$nmq_xml);
  my @lines = <XML>;
  close XML;
  my $target_flag=0; my $version_flag=0;
  foreach (@lines) {
    if (($_ =~ m/directory id='target'/)&&($target_flag==0)) {$target = $_; $target_flag=1};
    if (($_ =~ m/\<nonmem version=/)&&($versino_flag==0)) {$version = $_; $version_flag=1};
  }
  $target =~ s/\<directory id='target'\>//i ;
  $target =~ s/\<\/directory\>//i;
  chomp($target);
  $version =~ s/<nonmem version='//i;
  $version = substr($version,0,1);
  return ($target,$version);
}

sub install_nonmem_nmq_window {
### Purpose : Create dialog for installing NONMEM through NMQual
### Compat  : W+
  $install_nm_nmq_w = $mw -> Toplevel(-title=>'Install NONMEM VI using NMQual');
  no_resize ($install_nm_nmq_w);
  $install_nm_nmq_frame = $install_nm_nmq_w -> Frame(-background=>$bgcol)->grid(-ipadx=>'10',-ipady=>'10',-sticky=>'n');
  center_window($install_nm_nmq_w, $setting{center_window}); # center after adding frame (redhat)
  $install_text = "This will perform a new installation of NONMEM VI using\n".
    "predefined NMQual XML files. Please refer to the documentation\n of NMQual for further information on this subject.\n\n".
    "The location of the NMQual XML files can be specified under 'File --> Software'.\nOnly XML-files prefixed with 'config.' are shown in the optionmenu.\n".
    "Since Perl is needed for NMQual, it is assumed that it's location is in the PATH.\n\n";
  $install_nm_nmq_frame -> Label (-text=>$install_text, -font=>$font,-justify=>"left")
    ->grid(-row=>1,-column=>1, -columnspan=>3,-sticky=>"w");
  $install_nm_nmq_frame -> Label (-text=>"Name in Pira�a:", -font=>$font,-justify=>"left")
    ->grid(-row=>2,-column=>1, -columnspan=>1,-sticky=>"w");
  $install_nm_nmq_frame -> Label (-text=>"Installation", -font=>$font,-justify=>"left")
    ->grid(-row=>3,-column=>1, -columnspan=>1,-sticky=>"w");
  $install_nm_nmq_frame -> Entry (-textvariable=>\$nm_name,  -font=>$font, -background=>$white, -border=>$bbw, -width=>16, -border=>2, -relief=>'groove')
    -> grid(-row=>2,-column=>2,-columnspan=>2,-sticky=>"news");

  $install_nm_nmq_frame -> Label (-text=>"Installation directory:", -font=>$font,-justify=>"left")
    ->grid(-row=>4,-column=>1, -columnspan=>1,-sticky=>"w");
  $nmq_to = $install_nm_nmq_frame -> Entry (-state=>'disabled', -font=>$font,  -background=>$white, -border=>$bbw, -width=>16, -border=>2, -relief=>'groove')
    -> grid(-row=>4,-column=>2,-columnspan=>2,-sticky=>"news");
  $install_nm_nmq_frame -> Label (-text=>"NONMEM version:", -font=>$font,-justify=>"left")
    ->grid(-row=>5,-column=>1, -columnspan=>1,-sticky=>"w");
  $nmq_nmver = $install_nm_nmq_frame -> Entry (-state=>'disabled', -font=>$font, -background=>$white, -border=>$bbw, -width=>16, -border=>2, -relief=>'groove')
    -> grid(-row=>5,-column=>2,-columnspan=>2,-sticky=>"news");
  chdir ($software{nmq_path});
  @xml = <config.*.xml>;
  ($target, $version) = nmqual_xml(win_path($software{nmq_path}."/".@xml[0]));
  $nmq_to -> configure(-textvariable=>$target);
  $nmq_nmver -> configure(-textvariable=>$version);
  $install_nm_nmq_frame -> Optionmenu (-options=>[@xml], -variable=> \$nmq_xml, -border=>$bbw, -width=>5, -font=>$font_normal, -background=>$lightblue, -activebackground=>$darkblue,-foreground=>$white,-activeforeground=>$white, -command=> sub{
    ($target, $version) = nmqual_xml(win_path($software{nmq_path}."/".$nmq_xml));
    $nmq_to -> configure(-textvariable=>$target);
    $nmq_nmver -> configure(-textvariable=>$version);
  }) -> grid(-row=>3,-column=>2,-columnspan=>2,-sticky=>"we");
  $install_nm_nmq_frame -> Button (-image=>$gif{notepad}, -font=>$font, -background=>$button, -border=>$bbw, -activebackground=>$abutton, -command=> sub {
        edit_model(unix_path($nmq_xml));
  })->grid(-row=>3,-column=>4,-sticky=>"w");
  $install_nm_nmq_frame -> Label (-text=>" ",-justify=>"left")
    ->grid(-row=>6,-column=>1, -columnspan=>3,-sticky=>"w");  
  $install_nm_nmq_frame -> Button (-text=>"Proceed", -width=>12, -font=>$font, -background=>$button, -border=>$bbw, -activebackground=>$abutton, -command=> sub {
    if ($nm_dirs{$nm_name}) {message("A NONMEM installation with that name already exists in Pira�a.\nPlease choose another name.")} else {
       open (BAT,">".unix_path($base_dir."/internal/nmq_install_nm.bat"));
       print BAT "SET PATH=".$setting{nmq_env_path}.";%PATH%; \n";
       print BAT "SET LIBRARY_PATH=".$setting{nmq_env_libpath}.";%LIBRARY_PATH% \n";
       print BAT win_path("perl.exe nmqual.pl ".$nmq_xml)."\n";
       close BAT;

       system("start /wait ".win_path($base_dir."/internal/nmq_install_nm.bat"));
       # check if the perl file in the /test directory exists
       $perl_file = get_nmq_name ($target);
       if (-e $target."/test/".$perl_file.".pl") {
	   my $add_to_pirana = message_yesno ("NONMEM installations seems valid.\n Do you want to add this installation to Pira�a?", $mw, $bgcol, $font_normal);
           if ($add_to_pirana == 1) {
	       $nm_dirs{$nm_name} = $target;
	       $nm_vers{$nm_name} = $version;
	       save_ini ($home_dir."/ini/nm_inst_local.ini", \%nm_dirs, \%nm_vers, $base_dir."/ini_defaults/nm_inst_local.ini");
	       chdir($cwd);
	       $method_nmq_button -> configure(-state=>'normal');
	       refresh_pirana($cwd);
	       project_buttons_show();
         }
       } else {message("Cannot find Perl startup file (".$target."/test/".$perl_file.".pl).\nNMQual NONMEM installation failed.")
       }
       $install_nm_nmq_w -> destroy;
    }
  })->grid(-row=>7,-column=>2,-sticky=>"w");
  $install_nm_nmq_frame -> Button (-text=>"Cancel", -font=>$font, -width=>12, -background=>$button, -border=>$bbw, -activebackground=>$abutton, -command=> sub {
    $install_nm_nmq_w -> destroy;
  })->grid(-row=>7,-column=>1,-sticky=>"e");
}

sub install_nonmem_window {
### Purpose : Create dialog for installing NONMEM
### Compat  : W+L-
  $install_nm_w = $mw -> Toplevel(-title=>'Install NONMEM VI / VII');
  no_resize ($install_nm_w);  
  my $install_nm_frame = $install_nm_w -> Frame(-background=>$bgcol)->grid(-ipadx=>'10',-ipady=>'10',-sticky=>'n');
  center_window($install_nm_w, $setting{center_window}); # center after adding frame (redhat)
  $install_text = "This will perform a new installation of NONMEM VI or VII from CD\n";
  $install_nm_frame -> Label (-text=>$install_text, -font=>$font,-justify=>"left")
    ->grid(-column=>1, -columnspan=>2,-sticky=>"w");
  $install_nm_frame -> Label (-text=>"Installation name", -font=>$font)->grid(-column=>1, -row=>2,-sticky=>"e");
  $install_nm_frame -> Label (-text=>"NONMEM Install CD", -font=>$font)->grid(-column=>1, -row=>3,-sticky=>"e");
  $install_nm_frame -> Label (-text=>"Install to", -font=>$font)->grid(-column=>1, -row=>4,-sticky=>"e");
  $install_nm_frame -> Label (-text=>"Default compiler optimization", -font=>$font)->grid(-column=>1, -row=>5,-sticky=>"e");

  $nm_install_name = "nmvi";
  $install_nm_frame -> Entry (-textvariable=>\$nm_install_name, -font=>$font, -background=>$white, -border=>$bbw, -width=>12, -border=>2, -relief=>'groove') -> grid(-row=>2,-column=>2,-sticky=>"nws");
  my @drives;
  my $nm_install_to;
  if ($^O =~ m/MSWin/i) {
      @drives = Win32::DriveInfo::DrivesInUse();
      foreach (@drives) {$_ .= ":"};
      $nm_install_to = "c:\\".$nm_install_name;
  } else {
      my @media = dir ("/media");
      foreach (@media) {
	  if (substr($_,0,1) ne '.') {
	      push (@drives, $_);
	  }
      }
      $nm_install_to = "/opt/nonmem/".$nm_install_name;
  }
  $install_nm_frame -> Optionmenu (-options=>[@drives], -variable=> \$nm_install_drive, -border=>$bbw, -width=>5, -font=>$font_normal, -background=>$lightblue, -activebackground=>$darkblue, -foreground=>$white,-activeforeground=>$white)
    -> grid(-row=>3,-column=>2,-sticky=>"w");
  $install_nm_to_entry = $install_nm_frame -> Entry (-textvariable=>\$nm_install_to, -background=>$white, -border=>$bbw, -width=>36, -border=>2, -relief=>'groove') -> grid(-row=>4,-column=>2,-sticky=>"news");
  $def_optimize = 1;
  $install_nm_frame -> Checkbutton(-text=>"", -font=>$font,-variable=>\$def_optimize,-selectcolor=>$selectcol, -activebackground=>$bgcol,)
    ->grid(-row=>5,-column=>2,-sticky=>'w');
  $do_bugfixes = 1;  
  $install_nm_frame -> Label (-text=>"  ", -font=>$font)->grid(-column=>1, -row=>8,-columnspan=>2,-sticky=>"e");  
  $install_nm_frame -> Button(-image=>$gif{browse_small}, -font=>$font, -border=>0, -command=> sub{
      $nm_install_to = $mw-> chooseDirectory();
      if($cwd eq "") {$install_nm_to_entry -> configure(-textvariable=>\$nm_install_to) };
      $install_nm_w -> focus;
  })
  ->grid(-column=>3, -row=>4, -sticky => 'we');

  $install_nm_frame -> Button (-text=>"Proceed", -font=>$font, -width=>12, -background=>$button, -border=>$bbw, -activebackground=>$abutton, -command=> sub {
         if (-d $nm_install_to) {message ("Target folder already exists.\nPlease choose another destination.")} else {
        ($nm_to_drive,$nm_to_dir) = split (/:/,$nm_install_to);
        $nm_to_drive =~ s/://;
        $nm_install_drive =~ s/://;
        $nm_to_dir = substr($nm_to_dir,1,length($nm_to_dir)-1);
        if ($def_optimize==1) {$def_optimize="y"} else {$def_optimize="n"};
        chdir($nm_install_drive.":\\");
        system "start /wait cdsetup6.bat ".$nm_install_drive." ".$nm_to_drive." ".$nm_to_dir." ".$setting{compiler}." ".$def_optimize." link";
        if (-e unix_path($nm_install_to."/util/nmfe6.bat")) {
           my $add_to_pirana = message_yesno ("NONMEM installation seems successful.\nDo you want to add this installation to Pira�a?", $mw, $bgcol, $font_normal);
           if( $add_to_pirana == 1) {
              $nm_dirs{$nm_install_name} = $nm_install_to;
              $nm_vers{$nm_install_name} = 6;
              save_ini ($home_dir."/ini/nm_inst_local.ini", \%nm_dirs, \%nm_vers, $base_dir."/ini_defaults/nm_inst_local.ini");
              chdir($cwd);
              refresh_pirana($cwd);
           }
        $method_nmfe_button -> configure(-state=>'normal');
        } else {message("Installation of NONMEM failed...")}
        $install_nm_w -> destroy;
      }
  })->grid(-row=>9,-column=>2,-sticky=>"w");
  $install_nm_frame -> Button (-text=>"Cancel", -font=>$font, -width=>12, -background=>$button, -border=>$bbw, -activebackground=>$abutton, -command=> sub {
    $install_nm_w -> destroy;
  })->grid(-row=>9,-column=>1,-sticky=>"e");
}

sub nm_env_var_window {
### Purpose : Create the dialog for editing the NM sizes file
### Compat  : W+L+
  $nm_env_var_w = $mw -> Toplevel(-title=>'Update environment variables');
  no_resize($nm_env_var_w);
  my $nm_env_var_frame = $nm_env_var_w ->
  Frame(-background=>$bgcol)->grid(-ipadx=>'10',-ipady=>'10',-sticky=>'n');
  my $text = "NONMEM and the FORTRAN compiler that is used require the environment variables\nset correctly. Especially with the Intel compiler environment this can be troublesome,\nas numerous variables should be included. A detailed explanation for the relevance\nof this issue (on Windows) for running NONMEM can be found here:\nhttp://www.cognigencorp.com/nonmem/current/2009-October/2077.html.
  \nUsing the functionality below, commands can be specified that are executed before\na NONMEM run is started. This way, environment variables will be set each time a run is\nexecuted, and the variables do not need to be set globally.
  \nOf course, other commands to be executed before or after a NONMEM run may be\nspecified as well.\n";
  $nm_env_var_frame -> Label ( -text =>$text , -font=>$font, -justify=>"l", -background=>$bgcol)->grid(-column=>1, -row=>1,-sticky=>"nws");
  $nm_env_var_frame -> Label ( -text =>"Before NONMEM execution:" , -font=>$font_bold, -justify=>"l", -background=>$bgcol)->grid(-column=>1, -row=>2,-sticky=>"nws");
  $nm_env_var_frame -> Label ( -text =>"After NONMEM execution:" , -font=>$font_bold, -justify=>"l", -background=>$bgcol)->grid(-column=>1, -row=>4,-sticky=>"nws");

  my $before_text = $nm_env_var_frame -> Text ( -font=>$font, -background=>$white, -border=>$bbw, -width=>72, -height=>5, -border=>2, -relief=>'groove') -> grid(-row=>3,-column=>1,-sticky=>"wn");
  my $after_text = $nm_env_var_frame -> Text ( -font=>$font, -background=>$white, -border=>$bbw, -width=>72, -height=>5, -border=>2, -relief=>'groove') -> grid(-row=>5,-column=>1,-sticky=>"wn");

  $nm_env_button_frame = $nm_env_var_frame -> Frame (-background=>$bgcol) -> grid(-row=>7, -column=>1, -sticky=>"nse");

  # read before and after texts
  open (INI1, "<".$home_dir."/ini/commands_before.txt");
  my @before = <INI1>;
  close (INI1);
  open (INI2, "<".$home_dir."/ini/commands_after.txt");
  my @after = <INI2>;
  close (INI2);
  $before_text -> insert("0.0", join("", @before));
  $after_text -> insert("0.0", join("", @after));

  $nm_env_button_frame -> Button (-text=>"Save", -font=>$font, -width=>16, -background=>$button, -border=>$bbw, -activebackground=>$abutton, -command=> sub {
      $before_text_get = $before_text -> get("0.0","end");
      chomp ($before_text_get);
      open (INI1, ">".$home_dir."/ini/commands_before.txt");
      print INI1 $before_text_get;
      close INI1;
      $after_text_get = $after_text -> get("0.0","end");
      chomp ($after_text_get);
      open (INI2, ">".$home_dir."/ini/commands_after.txt");
      print INI2 $after_text_get;
      close INI2;
      $nm_env_var_w -> destroy;
  }) -> grid(-row=>1, -column=>2, -sticky=>"nwse");
  $nm_env_button_frame -> Button (-text=>"Cancel", -font=>$font, -width=>16, -background=>$button, -border=>$bbw, -activebackground=>$abutton, -command=> sub {
      $nm_env_var_w -> destroy;
  }) -> grid(-row=>1, -column=>1, -sticky=>"nwse");
  center_window($nm_env_var_w, $setting{center_window});
}

sub manage_nm_window {
### Purpose : Do a smart search for NM installations on the local system
### Compat  : W+L+
    my $manage_nm_dialog = $mw -> Toplevel(-title=>'Manage NONMEM installations (for nmfe)');
    no_resize ($manage_nm_dialog);  
    my $manage_nm_frame = $manage_nm_dialog -> Frame () -> grid(-ipadx=>'10',-ipady=>'10');
    $manage_nm_frame -> Label (-text => "Local NONMEM installations:", -font=>$font, -background=>$bgcol)->grid (-row=>1, -column=>1, -sticky=>"nws");
    $manage_nm_frame -> Label (-text => "  ")->grid (-row=>3, -column=>1, -sticky=>"nws");
    $manage_nm_frame -> Label (-text => "Remote NONMEM installations:", -font=>$font, -background=>$bgcol)->grid (-row=>4, -column=>1, -sticky=>"nws");
    $nm_local_hlist = $manage_nm_frame -> Scrolled('HList',
        -head       => 1, -selectmode => "single",
        -highlightthickness => 0,
        -columns    => 4,
        -scrollbars => 'se', -width => 80, -height => 6, -border => 1,
        -background => '#ffffff', -selectbackground => $pirana_orange,
        -font       => $font,
        -command    => sub {
	    my $nm_sel = $nm_local_hlist -> selectionGet ();
        }
     )->grid(-column => 1, -columnspan=>3, -row => 2, -rowspan=>1, -sticky=>'nswe', -ipady=>0);
    $nm_remote_hlist = $manage_nm_frame -> Scrolled('HList',
        -head       => 1, -selectmode => "single",
        -highlightthickness => 0,
        -columns    => 4,
        -scrollbars => 'se', -width => 80, -height => 6, -border => 1,
        -background => '#ffffff', -selectbackground => $pirana_orange,
        -font       => $font,
        -command    => sub {
	    my $nm_sel = $nm_remote_hlist -> selectionGet ();
        }
     )->grid(-column => 1, -columnspan=>3, -row => 5, -rowspan=>1, -sticky=>'nswe', -ipady=>0);

    my @headers = ("Name", "Location", "Version");
    my @header_widths = (100, 300, 50);
    for ($i = 0; $i < 3; $i++) {
	$nm_local_hlist -> header('create', $i, -text=> @headers[$i], -headerbackground => 'gray');
	$nm_local_hlist -> columnWidth($i, @header_widths[$i]);
	$nm_remote_hlist -> header('create', $i, -text=> @headers[$i], -headerbackground => 'gray');
	$nm_remote_hlist -> columnWidth($i, @header_widths[$i]);
    }

    populate_manage_nm_hlist ($nm_local_hlist, $nm_remote_hlist);

    my $local_button_frame = $manage_nm_frame -> Frame (-background=>$bgcol)->grid(-row=> 2, -column=>4, -sticky=>"nw");
    my $remote_button_frame = $manage_nm_frame -> Frame (-background=>$bgcol)->grid(-row=> 5, -column=>4, -sticky=>"nw");

    $new_nm_local_button = $local_button_frame -> Button (-image=>$gif{plus}, -font=>$font, -border=>$bbw, -background=>$button, -activebackground=>$abutton, -command=> sub{
	add_nm_inst("local", $nm_local_hlist, $nm_remote_hlist);
    })-> grid(-row=>2,-column=>1,-sticky=>"wns");
    $help->attach($new_nm_local_button, -msg => "Manually add local NONMEM installation");

    $new_nm_remote_button = $remote_button_frame -> Button (-image=>$gif{plus}, -font=>$font, -border=>$bbw, -background=>$button, -activebackground=>$abutton, -command=> sub{
	add_nm_inst("remote", $nm_local_hlist, $nm_remote_hlist);
    })-> grid(-row=>1,-column=>1,-sticky=>"wns");
    $help->attach($new_nm_remote_button, -msg => "Manually add remote NONMEM installation");
    
    $del_nm_local_button = $local_button_frame -> Button (-image=>$gif{trash},  -font=>$font, -border=>$bbw, -background=>$button, -activebackground=>$abutton, -width=>22, -command=> sub{
	my $nm_sel = $nm_local_hlist -> selectionGet ();
	if (@$nm_sel>0) {
	    my $nm_name = $nm_local_hlist -> itemCget(@$nm_sel[0], 0, "text");
	    my $delete = message_yesno ("Do you really want to remove this NONMEM installation from Pirana?\nNB. The actual installation will not be removed, only the link from Pira�a.", $mw, $bgcol, $font_normal);
	    if( $delete == 1) {
		delete $nm_dirs{$nm_name};
		delete $nm_vers{$nm_name};
		save_ini ($home_dir."/ini/nm_inst_local.ini", \%nm_dirs, \%nm_vers,  $base_dir."/ini_defaults/nm_inst_local.ini", 1);
		populate_manage_nm_hlist ($nm_local_hlist, $nm_remote_hlist);
	    }
	} else {message ("Please select a NONMEM installation to remove from Pirana.")}
    })-> grid(-row=>3,-column=>1,-sticky=>"wns");
    $help->attach($del_nm_local_button, -msg => "Remove NM installation");

    $del_nm_remote_button = $remote_button_frame -> Button (-image=>$gif{trash},  -font=>$font, -border=>$bbw, -background=>$button, -activebackground=>$abutton, -width=>22, -command=> sub{
	my $nm_sel = $nm_remote_hlist -> selectionGet ();
	if (@$nm_sel>0) {
	    my $nm_name = $nm_remote_hlist -> itemCget(@$nm_sel[0], 0, "text");
	    my $delete = message_yesno ("Do you really want to remove this NONMEM installation from Pirana?\nNB. The actual installation will not be removed, only the link from Pira�a.", $mw, $bgcol, $font_normal);
	    if( $delete == 1) {
		delete $nm_dirs_cluster{$nm_name};
		delete $nm_vers_cluster{$nm_name};
		save_ini ($home_dir."/ini/nm_inst_cluster.ini", \%nm_dirs_cluster, \%nm_vers_cluster, $base_dir."/ini_defaults/nm_inst_cluster.ini", 1);
		populate_manage_nm_hlist ($nm_local_hlist, $nm_remote_hlist);
	    }
	} else {message ("Please select a NONMEM installation to remove from Pirana.")}
    })-> grid(-row=>2,-column=>1,-sticky=>"wns");
    $help->attach($del_nm_remote_button, -msg => "Remove NM installation");

    our $quick_search_button = $local_button_frame -> Button (
	-image=>$gif{binocular}, -background => $button, -border=>$bbw, -activebackground=>$abutton,
	-width=>26, -height=>22, -command=>sub{
	    smart_nm_search_dialog($nm_local_hlist, $nm_remote_hlist);
    })->grid(-row=>1,-column=>1,-sticky=>'wens');
    $help->attach($quick_search_button, -msg => "Quick search for NONMEM installations on local system");

    $manage_nm_frame -> Button (-text=>"Close", -font=>$font, -background=>$button, -activebackground=>$abutton, -border=>$bbw, -command => sub {
	$manage_nm_dialog -> destroy();
    center_window($manage_nm_dialog, $setting{center_window}); # center after adding frame
    })-> grid (-row=>6, -column=>3, -sticky => "nse");

}

sub populate_manage_nm_hlist {
    my ($nm_local_hlist, $nm_remote_hlist) = @_;
    $nm_local_hlist -> delete ("all");
    $nm_remote_hlist -> delete ("all");
    my $i=0;
    # get NM installations and fill in Optionmenu
    my ($nm_dirs_ref, $nm_vers_ref) = read_ini($home_dir."/ini/nm_inst_local.ini");
    my %nm_dirs = %$nm_dirs_ref; my %nm_vers = %$nm_vers_ref; my %nm_types;
    foreach my $nm (keys(%nm_dirs)) {
	$nm_local_hlist -> add($i);
	$nm_local_hlist -> itemCreate($i, 0, -text => $nm, -style=>$align_left);
	$nm_local_hlist -> itemCreate($i, 1, -text => $nm_dirs{$nm}, -style=>$align_left);
	$nm_local_hlist -> itemCreate($i, 2, -text => $nm_vers{$nm}, -style=>$align_left);
	$i++;
    }
    
    # remote NM versions
    my $i=0;
    my ($nm_dirs_remote_ref, $nm_vers_remote_ref) = read_ini($home_dir."/ini/nm_inst_cluster.ini");
    my %nm_dirs_remote = %$nm_dirs_remote_ref; my %nm_vers_remote = %$nm_vers_remote_ref;
    foreach my $nm (keys(%nm_dirs_remote)) {
	$nm_remote_hlist -> add($i);
	$nm_remote_hlist -> itemCreate($i, 0, -text => $nm, -style=>$align_left);
	$nm_remote_hlist -> itemCreate($i, 1, -text => $nm_dirs_remote{$nm}, -style=>$align_left);
	$nm_remote_hlist -> itemCreate($i, 2, -text => $nm_vers_remote{$nm}, -style=>$align_left);
	$i++;
    }
}

sub csv_tab_window {
### Purpose : Create the dialog for converting a csv-file into a tab file or viceversa
### Compat  : W+L?
   my $file = shift;
   $new_file = $file;
   if ($file =~ m/.$setting{ext_csv}/i) {$new_file=~ s/.$setting{ext_csv}/.$setting{ext_tab}/i};
   if ($file =~ m/.$setting{ext_tab}/i) {$new_file=~ s/.$setting{ext_tab}/.$setting{ext_csv}/i};
   $csv_tab_w = $mw -> Toplevel(-title=>'Convert datafile');
   no_resize ($csv_tab_w); 
   
   $csv_tab_frame = $csv_tab_w -> Frame(-background=>$bgcol)->grid(-ipadx=>'20',-ipady=>'10',-sticky=>'nws');
   $csv_tab_frame -> Label(-text=> "Convert file: ", -font=>$font, -justify=>"left")->grid(-column=>1, -row=>1,-sticky=>"wns");
   $csv_tab_frame -> Label(-text=> $file,-font=>$font,-justify=>"left")->grid(-column=>2, -row=>1,-sticky=>"wns");
   $csv_tab_frame -> Label(-text=> "to: ",-font=>$font,-justify=>"left")->grid(-column=>1, -row=>2,-sticky=>"wns");
   my $length = length($file); if($length<32) {$length=32};
   $csv_tab_frame -> Entry(-textvariable=> \$new_file, -font=>$font, -background=>$white,
      -border=>1, -relief=>'groove', -width=>$length)->grid(-column=>2, -row=>2,-sticky=>"wns");
   $csv_tab_frame -> Button(-text=> "Convert", -font=>$font,-background=>$button, -border=>$bbw, -activebackground=>$abutton, -command=> sub {
     my $overwrite_bool = 1;
     if (-e $new_file) {
	 $overwrite_bool = message_yesno ("Datafile ".$new_file." already exists.\n Do you want to overwrite?", $mw, $bgcol, $font_normal);
     }
     if ($overwrite_bool==1) {
       if (substr($new_file,length($new_file)-4,4) =~ m/.$setting{ext_csv}/i) {tab2csv($file,$new_file)} ;
       if (substr($new_file,length($new_file)-4,4) =~ m/.$setting{ext_tab}/i) {csv2tab($file,$new_file)} ;
     }
     $csv_tab_w -> destroy;
   })->grid(-column=>2, -row=>3, -sticky=>'w');
   center_window($csv_tab_w, $setting{center_window}); # center after adding frame (redhat) 
   return();
}

sub frame_statusbar {
### Purpose : Create frame+label with status text
### Compat  : W+L+
    our $status_bar = $mw -> Label (-text=>"Status: Idle", -anchor=>"w", -font=>$font_small, -background=>$bgcol, -foreground=>"#757575")->grid(-column=>1,-row=>5,-sticky=>"w");
}

sub status {
### Purpose : Change the statusbar text
### Compat  : W+L+
    $status_text = shift;
    if ($status_text eq "") {
	$status_text = "Idle";
    } else {
    }
    $status_bar -> configure (-text=>"Status: ".$status_text);
    $mw->update();
}

sub setup_ini_dir {
### Purpose : Create directories /ini en /log in home folder
### Compat  : W+L+
    my ($user, $home_dir) = @_;
    unless (-d $home_dir) {mkdir $home_dir};
    unless (-d $home_dir."/ini") {mkdir $home_dir."/ini"};
    unless (-d $home_dir."/ini/clusters") {mkdir $home_dir."/ini/clusters"};
    unless (-d $home_dir."/log") {mkdir $home_dir."/log"};
    my @dir = dir ($base_dir."/ini_defaults", ".ini");

    # check if all settings are in place
    my @check_inis = ("settings.ini", "software_win.ini", "software_linux.ini", "software_osx.ini", "psn.ini", 
		      "sge.ini", "run_reports.ini", "internal.ini"
		     );
    my @dir = @check_inis;
    push (@dir, ("nm_inst_local.ini", "nm_inst_cluster.ini", "projects.ini"));
    @txt_comm = ("commands_before.txt", "commands_after.txt");
    foreach my $ini (@dir) {
	unless (-e $home_dir."/ini/".$ini) {
	    if (-e $base_dir."/ini/".$ini) { # check if ini files from portable use are present.
		copy ($base_dir."/ini/".$ini, $home_dir."/ini/".$ini);
	    } else {
		copy ($base_dir."/ini_defaults/".$ini, $home_dir."/ini/".$ini);
	    }
	}
    }
    foreach my $ini (@check_inis) {
        check_ini_file ($home_dir."/ini/".$ini, $base_dir."/ini_defaults/".$ini)
    }
    if (-e $home_dir."/ini/ssh.ini") { # remnant from Pirana <2.4.0
	my $num = get_highest_file_number($home_dir."/ini/clusters", "ssh");
	move ($home_dir."/ini/ssh.ini",$home_dir."/ini/clusters/ssh".($num+1)."\.ini");
    }
    my @ssh_ini = dir ($home_dir."/ini/clusters", "ssh");
    foreach my $ini (@ssh_ini) {
        check_ini_file ($home_dir."/ini/clusters/".$ini, $base_dir."/ini_defaults/ssh.ini");
    }
    foreach my $txt (@txt_comm) {
	unless (-e $home_dir."/ini/".$txt) {
	    copy ($base_dir."/ini_defaults/".$txt, $home_dir."/ini/".$txt);
	}
    }
};

sub check_ini_file {
### Purpose : check the ini-files at startup and rewrite if incomplete or erroneous
### Compat  : W+L+
    my ($user_ini_file, $def_ini_file) = @_;
    my ($user_ini_ref, $user_ini_descr_ref, $drop, $user_cat_ref, $lines_ref) = read_ini($user_ini_file); #user ini file
    my ($def_ini_ref, $def_ini_descr_ref, $drop, $def_cat_ref, $lines_ref) = read_ini($def_ini_file); # default ini file

    my %def_ini = %$def_ini_ref;
    my %def_ini_descr = %$def_ini_descr_ref;
    my %def_cat = %$def_cat_ref; # key category
    my %user_ini = %$user_ini_ref;
    my %user_ini_descr = %$user_ini_descr_ref;
    my %user_cat = %$user_cat_ref;
 
    foreach my $key (keys(%def_ini)) { # add keys that are not in the user ini file yet
	unless (exists $user_ini{$key}) {
	    $user_ini{$key} = $def_ini{$key};
	    $user_ini_descr{$key} = $def_ini_descr{$key};
	    $user_ini_descr{$key} = $def_ini_descr{$key};
	    $user_cat {$key} = $def_cat{$key};
	}
    }
    save_ini ($user_ini_file, \%user_ini, \%user_ini_descr, $def_ini_file);
}

sub renew_pirana {
### Purpose : To reload the main part of the GUI
### Compat  : W+L+
    if($frame2) {$frame2->gridForget()};
    if($run_frame) {$run_frame -> gridForget()};
    if ($frame_status) {$frame_status -> gridForget()};
    frame_models_show(1);
    show_run_frame();
    frame_statusbar(1);
    frame_tab_show(1);
    project_buttons_show();
    our $project_optionmenu = project_optionmenu ();
    refresh_pirana ($cwd, $filter, 1);
    $project_optionmenu -> configure(-state=>'normal');
    status();
}

sub auto_refresh_pirana {
    my $num = shift;
    while ($num!=0) {
	sleep ($num);
	refresh_pirana($cwd);
    }
    return($num);
}

sub refresh_pirana {
### Purpose : To refresh the interface
### Compat  : W+
  # if directory does not exist, switch to C:\\
  unless (-d @_[0] ) {
    if ($os =~ m/MSWin/i) {$cwd = "C:\\";} else {$cwd = "/"}
    $dir_entry -> configure(-textvariable=>$cwd);
  }
  $dir_entry -> configure(-textvariable=>$cwd);
  $dir_entry -> update;
  read_curr_dir (@_[0], $filter, 1);
  status ("Reading table files...");
  tab_dir(@_[0]);
  show_links ();
  populate_tab_hlist ($tab_hlist);
  status ();
}

sub show_console_output {
### Purpose : Create (or destroy) a text-box that show the output of several commands
### Compat  : W+L+
#  open (FILE, $base_dir."/temp/process_log");
#  my @lines = <FILE>;
#  close (FILE);
    my $text = shift;
    my $console = text_window($mw, $text, "Script / command output");
    return($console);
}

sub message {
### Purpose : Show a small window with a text and an OK button
### Compat  : W+L+
    my $text = shift;
    my $message_box = $mw -> Toplevel (-title => "Pirana message", -background=> $bgcol);    
    my $message_frame = $message_box -> Frame (-background=>$bgcol) -> grid(-ipadx => 10, -ipady => 10);
    $message_frame -> Label (-text=> $text."\n", -font=>$font_normal, -background=>$bgcol, -justify=>"left") -> grid(-row=>1, -column=>1);		
    $message_frame -> Button (-text=>"OK", -font=>$font_normal, -border=>$bbw, -background=>$button, -activebackground=>$abutton, -width=>5, -command => sub{
	$message_box -> destroy();
	return(1);
    }) -> grid(-row=>2, -column=>1);
    center_window($message_box, $setting{center_window}); # center after adding frame (redhat) 
    $message_box -> focus (); 
    $message_box -> raise();
}

sub intro_msg {
### Purpose : Issue a message-window showing startup errors
### Compat  : W+L+
  $kill = shift;
  if ($kill == 1) {$kill_text = "\nClick OK to exit Pira�a.\n"} else {$kill_text=""};
  our $mw2 = MainWindow -> new (-title => "Pira�a",-width=>740, -height=>410);
  open (LOG, "<".$home_dir."/log/startup.log");
  @lines=<LOG>;
  close LOG;
  $all = join("",@lines);
  $mw2 -> messageBox(-type=>'ok',
    	-message=>"Errors were found when starting Pira�a.\n Startup log:\n\n**************\n".$all."**************\n".$kill_text);
  $mw2->destroy();
  if ($kill==1) {die;};
}

sub read_ini {
### Purpose : Reads pirana ini-files
### Compat  : W+L+
    my $ini_file = shift;
    unless (open (INI,"<".$ini_file)) {print LOG "File not found: ".@_[0]."\n"};
    my %setting;
    my %descr;
    my %add_1;
    @ini=<INI>;
    close INI; my $cat;
    my %setting_cat;
    foreach (@ini) {
	if (substr($_,0,1) eq "[") {
	    $cat = $_;
	    $cat =~ s/\[//;
	    $cat =~ s/\]//;
	}
	unless (($_=~ m/\#/)||(substr($_,0,1) eq "[")) {
	    chomp ($_);
	    @a = split(/,/,$_);
	    # @a[0] =~ s/\s//g;  # strip spaces from keys
	    $setting{@a[0]} = @a[1];
	    $descr{@a[0]} = @a[2];
	    $add_1{@a[0]} = @a[3];
	    $setting_cat{@a[0]} = $cat;
	}
     }
    return (\%setting, \%descr, \%add_1, \%setting_cat, \@ini);
}

sub nmqual_compile_script {
### Purpose : create a new perl-script from NMQUal run-script, to allow compilation of nonmem.exe, but not executing it.
### Compat  : W+L+
    ($dir, $script) = @_;
    open (IN, "<".$dir."/test/".$script.".pl");
    @lines = <IN>;
    close IN;
    open (OUT, ">".$dir."/test/".$script."_compile.pl");
    $comment_lines = 0;

    foreach $line (@lines) {
	$line_done = 0;
	if  ($line =~ m/usr\/bin\/env perl/) {
	    print OUT $line;
	    print OUT "# Changed by Pira�a to allow compiling of nonmem.exe, without executing NONMEM\n";
	    $line_done=1;
	};
	if ($line =~ m/my \$outfile/i) {
	    print OUT $line;
	    print OUT '$outfile .= "_tmp1";'." # Added by Pira�a \n";
	    $line_done=1;
	}
	if ($line =~ m/\#restore invoking directory/) {
	    print OUT 'close OUTFILE or die;                                                   # added by Pirana'."\n";
	    print OUT '$outfile =~ s/tmp1/tmp2/;                                               # added by Pira�a'."\n";
	    print OUT 'open (OUTFILE,">".$outfile) or die "$nm cant open ".$outfile."_tmp\n";  # added by Pira�a'."\n";
	    print OUT "\n".$line;
	    $line_done=1;
	}
	if ($line =~ m/\#execute nonmem/gi ) {
	    $comment_lines = 18;
	}
	if ($line =~ m/open \(INFILE, "\<OUTPUT"\) or \&dieSmart/) {
	    $comment_lines = 5;
	};
	if ($comment_lines>0) { $comment_lines--; print OUT "# Pira�a change # ".$line } else {
	    if ($line_done==0) {print OUT $line }
	}
    }
    close OUT;
}

sub first_time_dialog {
### Purpose : Present a dialog the first time Pirana is started
### Compat  : W+L+
  my $user = shift;
  my $first_time_dialog_window = $mw -> Toplevel(-title=>'Welcome to Pira�a!');
  my $first_time_dialog_frame = $first_time_dialog_window -> Frame(-background=>$bgcol) -> grid(-ipadx=>10, -ipady=>10);
  $first_time_dialog_frame -> Label (-font=>$font_normal, -background=>$bgcol, -justify=>"left",
    -text=> "Welcome to Pira�a!\n\nSince this is the first time you start Pira�a, please check the preferences and software\nsettings under 'File' in the menu.\n\nNONMEM installations may be added under 'NONMEM' -> 'Manage Installations'\n\n"
  )->grid(-row=>1, -column=>1, -columnspan=>2);
  $first_time_dialog_frame -> Label (-font=>$font_normal, -background=>$bgcol, -justify=>"left",
    -text=> "Please specify your username: \n(no spaces)"
  )->grid(-row=>2, -column=>1, -sticky=>"nse");
  $first_time_dialog_frame -> Entry (-font=>$font_normal, -background=>$white, -justify=>"left",
    -textvariable => \$user
  )->grid(-row=>2, -column=>2, -sticky=>"wn");
  $first_time_dialog_frame -> Label (-font=>$font_normal, -background=>$bgcol, -justify=>"left",
    -text=> " "
  )->grid(-row=>3, -column=>1);
  $first_time_dialog_frame -> Button (-text=>'OK', -width=>12, -background=>$button, -activebackground=>$abutton, -border=>0, -command=>sub{
    $user =~ s/\s//g;
    our ($setting_ref,$setting_descr_ref) = read_ini($home_dir."/ini/settings.ini");
    our %setting = %$setting_ref; %setting_descr = %$setting_descr_ref;
    $setting{username} = $user;
    save_ini ($home_dir."/ini/settings.ini", \%setting, \%setting_descr, $base_dir."/ini_defaults/settings.ini");
    $first_time_dialog_window -> destroy();
  })->grid(-row=>4, -column=>2, -sticky=>"wns");
  center_window($first_time_dialog_window, $setting{center_window});
}

sub initialize {
### Purpose : Initialize pirana: read ini-files and update settings-hashes
### Compat  : W+L?

    # check if it's the first time to start pirana
    my $user    = getlogin();
    my $first_time_flag = 0;
    if (-e $home_dir."/log/startup.log") {
        open (LOG, $home_dir."/log/startup.log");
        my @log = <LOG>;
        my $vers_log = shift (@log);
        chomp($vers_log);
        $vers_log =~ s/Pira�a //i;
        if ($vers_log ne $version) {};
        close LOG;
    } else {
	$first_time_flag = 1;
    } 
    setup_ini_dir ($user, $home_dir);

    open (LOG,">".$home_dir."/log/startup.log");
    my $error=0;
    print LOG "Pira�a ".$version."\n";
    print LOG "Startup time: ".localtime()."\n\n";
    print LOG "Checking pirana installation...\n";

    unless (-d $base_dir."/internal") {$error++; print LOG "Error: Pirana could not find dir containing internal subroutines. Program halted.\n"};
    unless (-d $base_dir."/images") {$error++; print LOG "Error: Pirana could not find images. Program halted.\n"; };
    if ($error>0) {print LOG "Errors were found. Check installation of pirana.\n"; close LOG; intro_msg(1)} else {print LOG "Done\n"};

    print LOG "Reading Pirana settings...\n";
    my ($setting_ref,$setting_descr_ref) = read_ini($home_dir."/ini/settings.ini");
    our %setting = %$setting_ref; %setting_descr = %$setting_descr_ref;
    my ($setting_internal_ref,$setting_internal_descr_ref) = read_ini($home_dir."/ini/internal.ini");
    our %setting_internal = %$setting_internal_ref; %setting_internal_descr = %$setting_internal_descr_ref;
    #if ($setting{username}) {print LOG "Done\n";} else {print LOG "Error. Settings file might be corrupted. Check ini/settings.ini\n"; close LOG; intro_msg( )};
   
    # check header widths, if not correct number then read from default settings
    our @models_hlist_widths = split (";", $setting_internal{header_widths});
    if (int(@models_hlist_widths) < 12) {
	my ($def_setting_internal_ref, $def_setting_internal_descr_ref) = read_ini($base_dir."/ini_defaults/internal.ini");
	my %def_setting_internal = %$def_setting_internal_ref;
	$setting_internal{header_widths} = $def_setting_internal{header_widths};
	save_ini ($home_dir."/ini/internal.ini", \%setting_internal, \%setting_internal_descr, $base_dir."/ini_defaults/internal.ini");
    }
    foreach (@models_hlist_widths) {
	if ($_ < 5) {$_ = 5};
    }
    unshift (@models_hlist_widths, 0);

    print LOG "Deleting temporary files...\n";
    if(chdir ($base_dir."/temp")){
	my @temp_files = <*>;
	unlink (@temp_files);
	chdir ($base_dir);
    }

    print LOG "Reading software settings...\n";
    my $software_ini = "software_linux.ini";
    if ($os =~ m/MSWin/i) {$software_ini = "software_win.ini";}
    if ($os =~ m/darwin/i) {$software_ini = "software_osx.ini";}
    ($software_ref,$software_descr_ref) = read_ini($home_dir."/ini/".$software_ini);
    %software = %$software_ref; %software_descr = %$software_descr_ref;

    # at first startup, find latest R version, and update software settings
    if ($first_time_flag == 1) {
	my $R_dir;
	if ($^O =~ m/MSWin/ ) {
	    my @prog_dir = ("C:/Program Files/R", "C:/Program Files (x86)/R");
	    $R_dir = find_R (\@prog_dir);
	}
	if (-e $R_dir) {
	    $software{r_dir} = win_path ($R_dir);
	    save_ini ($home_dir."/ini/software_win.ini", \%software, \%software_descr, $base_dir."/ini_defaults/software_win.ini");
	}
	print LOG "R found. Software settings updated...\n"
    }

    # put Fortran in environment path;
    if ($ENV{PATH} =~ m/$nm_dir/) {;} else { $ENV{PATH}="$nm_dir/util;".$ENV{PATH}} ;
    unless ($ENV{'PATH'} =~ m/$software{f77_dir}/) {
	$ENV{'PATH'} = $software{f77_dir}.";".$ENV{'PATH'};
    }

    # check if XML:XPath is present, if NMQual will be used.
    if ($setting{use_nmq}==1) {
	print LOG "Checking XML::XPath availability (NMQual)...\n";
	system ('perl "'.win_path($base_dir.'/internal/test_xpath.pl" >"'.$home_dir.'/log/xpath.log"'));
	if (-s $home_dir."/log/xpath.log" > 2) {
	    our $xpath=1;
	} else {our $xpath = 0; print LOG "Perl module XML::XPath required for NMQual support was not found.\nIf you prefer not to work with NMQual,\ndisable use of NMQual under 'File->Preferences'.\n"; intro_msg(0)
	};
    }
    if ($setting{use_psn}==1) {
	print LOG "Reading PsN commands default parameters...\n";
	my ($psn_commands_ref, $psn_commands_descr_ref) = read_ini($home_dir."/ini/psn.ini");
	our %psn_commands = %$psn_commands_ref; our %psn_commands_descr = %$psn_commands_descr_ref;
	foreach(keys(%psn_commands_descr)) {
	    $psn_commands_descr{$_} =~ s/\\n/\n/g;
	}
    }

    print LOG "Reading Projects...\n";
    ($project_dir_ref,$project_descr_ref) = read_ini($home_dir."/ini/projects.ini");
    %project_dir = %$project_dir_ref; %project_descr = %$project_descr_ref;
    $pr_dir_err=0;
    while(($key, $value) = each(%project_dir)) {
	rm_spaces ($value);
	unless (-d $value) {$pr_dir_err++; print LOG "Error: folder for project ".$value." not found!\n"};
    }
    unless ($pr_dir_err==0) {print LOG $pr_dir_err." project(s) not found. Check projects.ini!\n"; close LOG;
			     # intro_msg(0)
    };

    print LOG "Reading SSH settings\n";
    my @ssh_ini = dir ($home_dir."/ini/clusters", "ssh");
    our %ssh_all; my $i = 0;
    foreach my $ini (@ssh_ini) {
	my ($ssh_ref, $ssh_descr) = read_ini($home_dir."/ini/clusters/".$ini);
	my %ssh = %$ssh_ref;
	$ssh{ini_file} = $ini;
        $ssh_all{$ssh{name}} = \%ssh;
	if ($i == 0) {
	    $setting_internal{cluster_default} = $ssh{name};
	};
	$i++;
    }

    print LOG "Reading Sun Grid Engine settings\n";
    my ($sge_ref, $sge_descr_ref) = read_ini($home_dir."/ini/sge.ini");
    our %sge = %$sge_ref;
    our %sge_descr = %$sge_descr_ref;
    
    print LOG "Reading NM versions...\n";
    $pr_dir_err=0;
    ($nm_dirs_ref, $nm_vers_ref) = read_ini($home_dir."/ini/nm_inst_local.ini");
    our %nm_dirs = %$nm_dirs_ref; our %nm_vers = %$nm_vers_ref;
    while(($key, $value) = each(%nm_dirs)) {
	unless (-d $value) {$pr_dir_err++; print LOG "Error: NM installation ".$value." not found!\n"};
	if ($nm_types{$key} =~ m/nmq/i ) {
	    my @dirs = split (/\\/,win_path($nm_dirs{$key}));
	    $nmq_name = @dirs[@dirs-1];
	    unless (-e $nm_dirs{$key}."/test/".$nmq_name."_compile.pl") {nmqual_compile_script ($nm_dirs{$key}, $nmq_name) }
	    unless (-e $nm_dirs{$key}."/test/".$nmq_name."_compile.pl") {$pr_dir_err++; print LOG "Compile perl-script for NMQual NONMEM installation\nlocated at ".$nm_dirs{$key}." could not be created."}
	}
    }
    if (exists($nm_dirs{""})) {  # remove empty entries
	delete ($nm_dirs{""});
#	save_ini ($home_dir."/ini/nm_inst_local.ini", \%nm_dirs, \%nm_vers, $base_dir."/ini_defaults/nm_inst_local.ini");
    }

    ($nm_dirs_cluster_ref,$nm_vers_cluster_ref,$nm_types_cluster_ref) = read_ini($home_dir."/ini/nm_inst_cluster.ini");
    our %nm_dirs_cluster = %$nm_dirs_cluster_ref;
    our %nm_vers_cluster = %$nm_vers_cluster_ref;

    # create bat-files for compiling a NM run (PCluster)
    if (($setting{use_pcluster}==1)&&($^O =~ m/MSWin/i)) {
	create_nmfe_compile_bat_files();
    }

    # Read NM help files
    my $nm_help_ref = get_nm_help_keywords ($base_dir."/doc/nm/nm_help.sqlite");
    our @nm_help_keywords = ();
    unless ($nm_help_ref == 0) {
	my @nm_help_keywords_arr = @$nm_help_ref;
	foreach (@nm_help_keywords_arr) {
	    my @temp = @$_;
	    push (@nm_help_keywords, @temp[0]);
	}
    }
    
    # create scripts directory if not exists
    unless (-d $home_dir."/scripts") {
	mkdir ($home_dir."/scripts")
    }
    unless (-e $home_dir."/scripts/template.R") {
	copy ($base_dir."/scripts/template.R", $home_dir."/scripts/template.R")
    }

    # Read settings for run reports
    my ($run_reports_ref, $run_reports_descr_ref) = read_ini ($home_dir."/ini/run_reports.ini");
    our %run_reports = %$run_reports_ref;
    our %run_reports_descr = %$run_reports_descr_ref;

    close (LOG);
}

sub cluster_monitor {
### Purpose : Create a window showing the active nodes in the PCluster
### Compat  :
    unless ($cluster_view) {
	our $cluster_view = $mw -> Toplevel(-title=>'PCluster monitor');
	$cluster_view -> OnDestroy ( sub{
	    undef $cluster_view; undef $cluster_view_frame;
	    undef $cluster_monitor_grid;
				     });
	no_resize ($cluster_view);
	our $cluster_view_frame = $cluster_view -> Frame(-background=>$bgcol)->grid(-ipadx=>5,-ipady=>5);
	our $cluster_monitor_grid = $cluster_view_frame ->Scrolled('HList',
								   -head       => 1, -columns    => 5, -scrollbars => 'e',-highlightthickness => 0,
								   -width      => 32, -height => 16, -border => 1, -background => 'white',
	    )->grid(-column => 1, -columnspan=>2,-row => 1);
	center_window($cluster_view, $setting{center_window}); # center after adding frame (redhat)
    }
    populate_cluster_monitor();
    $cluster_view_frame -> Button (-text=>'Refresh',  -width=>10, -border=>$bbw,-background=>$button, -activebackground=>$abutton,-command=>sub{
	$cluster_monitor_grid -> delete("all");
	populate_cluster_monitor();
				   }) -> grid(-column => 1, -columnspan=>2, -row=>2, -sticky=>"we");
}

sub populate_cluster_monitor {
### Purpose : Show the active nodes in the cluster overview window
### Compat  : W+L+
    my ($total_cpus_ref, $busy_cpus_ref, $pc_names_ref) = get_active_nodes($setting{cluster_drive}, \%clients);
    my %total_cpus = %$total_cpus_ref;
    my %busy_cpus = %$busy_cpus_ref;
    my %pc_names = %$pc_names_ref;
    my @active = sort { $a <=> $b } keys (%total_cpus);
    my $capacity = 0; my $in_use = 0;
   ($capacity += $_) for values (%total_cpus);
   ($in_use += $_) for values (%busy_cpus);
    #undef $cluster_monitor_grid;
    our $available_label = $cluster_view_frame -> Label (
      -text=>"Total CPUs: ".$capacity."  In use: ".$in_use,
      -font=>$font_bold
    ) -> grid(-column =>1, -columnspan=>5, -row=>0, -sticky=>"w");
    my @widths  = (25, 100, 30, 30,5);
    my @headers = ( "Client", "Owner", "CPUs", "In use"," ");
    my $i=0;
    $cluster_monitor_grid -> delete("all");
    foreach my $x ( 0 .. $#headers ) {
        $cluster_monitor_grid -> header('create', $x, -text=> $headers[$x], -headerbackground => 'gray');
        $cluster_monitor_grid -> columnWidth($x, @widths[$i]);
        $i++;
    }
    foreach my $i ( 0 .. @active-1 ) {
        $cluster_monitor_grid->add("computer".@active[$i]);
        $cluster_monitor_grid->itemCreate("computer".@active[$i], 0, -text => @active[$i], -style=>$align_right);
        $cluster_monitor_grid->itemCreate("computer".@active[$i], 1, -text => $pc_names{@active[$i]},-style=>$align_left );
        $cluster_monitor_grid->itemCreate("computer".@active[$i], 2, -text => $total_cpus{@active[$i]}, -style=>$align_right);
        $cluster_monitor_grid->itemCreate("computer".@active[$i], 3, -text => $busy_cpus{@active[$i]},-style=>$align_left);
    }
}

sub quit{
### Purpose : Save current settings and exit
### Compat  : W+L+?
  open (SETTINGS, "<$base_dir/internal/settings.inc");
  @settings_lines=<SETTINGS>; close SETTINGS;
  $i=0; while (@settings_lines[$i]) {
    if (@settings_lines[$i] =~ m/data_start_dir/) {@settings_lines[$i]="our \$data_start_dir = '$cwd';\n";} ;
    $i++;}
  open (SETTINGS, ">$base_dir/internal/settings.inc");
  print SETTINGS @settings_lines;
  close SETTINGS;
  exit;
}

sub save_project {
### Purpose : Save project link into projects.ini
### Compat  : W+L+?
    $new_dir = @_[0];
    $save_dialog = $mw -> Toplevel(-title=>'Save project folder');
    no_resize ($save_dialog); 
    $save_proj_frame = $save_dialog -> Frame(-background=>$bgcol) -> grid(-ipadx=>10, -ipady=>10);
    $save_proj_frame->Label(-text=>"folder:" ,-background=>$bgcol, -font=>$font)->grid(-row=>1,-column=>1,-columnspan=>2,-sticky=>'w');
    $save_proj_frame->Label(-text=>@_[0],-background=>$bgcol, -font=>$font)->grid(-row=>1,-column=>2,-columnspan=>2,-sticky=>'w');
    $save_proj_frame->Label(-text=>"Overwrite project: ", -font=>$font, -background=>$bgcol,-activebackground=>$bgcol)->grid(-row=>2,-column=>1,-sticky=>'w');
    $new_project_name = "New project";
    my $proj_entry = $save_proj_frame->Entry(-width=>30, -background=>$white, -textvariable=>\$new_project_name,-background=>'#FFFFEE', -border=>2, -relief=>'groove') ->grid(-row=>3,-column=>2,-sticky=>'w');
    $save_proj_frame->Optionmenu(-background=>$lightblue, -activebackground=>$darkblue,-foreground=>$white, -activeforeground=>$white, -width=>25,-border=>$bbw,
				 -options=>["New project",keys(%project_dir)], -font=>$font, -textvariable => \$project_chosen,
				 -command=>sub{
				     $new_project_name = $project_chosen;
				     $proj_entry -> update();
				     ;} )
	->grid(-row=>2,-column=>2,-sticky=>'w');
    $save_proj_frame->Label(-text=>"Project name: ", -font=>$font, -background=>$bgcol) ->grid(-row=>3,-column=>1,-sticky=>'w');
    $save_proj_frame->Label(-text=>"  ",-font=>$font, -background=>$bgcol)->grid(-row=>4,-column=>1,-columnspan=>2,-sticky=>'w');
    $save_proj_frame->Button(-text=>"Save",-width=>16, -font=>$font, -background=>$button,-activebackground=>$abutton,-border=>$bbw, -command=>sub{
	# rewrite the hash:
	unless ($project_chosen eq "New project") {
	    delete $project_dir{$project_chosen};
	}
	$project_dir{$new_project_name} = $cwd;
	rewrite_projects_ini();
	$active_project = $new_project_name;
	our $project_optionmenu = project_optionmenu();
	$project_optionmenu -> configure(-state=>"normal");
	destroy $save_dialog;
			     })
	->grid(-row=>5,-column=>2,-sticky=>'w');
    $save_proj_frame -> Button (-text=>'Cancel ', -font=>$font, -background=>$button, -activebackground=>$abutton, -border=>0, -command=>sub{destroy $save_dialog})->grid(-column=>1,-row=>5,-sticky=>"nwse");
    center_window($save_dialog, $setting{center_window}); # center after adding frame (redhat)
}

sub rewrite_projects_ini {
### Purpose : Rewrite the projects.ini file after updates have been made
### Compat  : W+L+?
     open (INI, ">".$home_dir."/ini/projects.ini");
     $i=0;
     foreach (keys %project_dir) {
       print INI $_.",".$project_dir{$_}."\n";
     }
     close INI;
}

sub del_project {
### Purpose : Delete a project quick-link (which are shown upper left in the main window)
### Compat  : W+L+
  $delproj_dialog = $mw -> Toplevel(-title=>'Delete project');
  $delproj_frame = $delproj_dialog -> Frame (-background=>$bgcol)->grid(-ipadx=>10, -ipady=>10);
  no_resize($delproj_dialog);
  $delproj_frame -> Label (-text=>"Really delete project $active_project?\n (folder will not be deleted, only shortcut in Pira�a.)\n",-font=>$font, -justify=>'left')->grid(-row=>1,-column=>1,-columnspan=>2);
  $delproj_frame -> Button (-text=>'Delete ', -font=>$font, -background=>$button, -activebackground=>$abutton, -border=>0, -command=>sub{
    delete $project_dir{$active_project};
    rewrite_projects_ini();
    ($active_project,@rest) = keys(%project_dir);
    project_optionmenu();
    $project_optionmenu -> configure(-state=>"normal");
    refresh_pirana($cwd,$filter,1);
    destroy $delproj_dialog;
  })->grid(-row=>2,-column=>2,-sticky=>"nwse");
  $delproj_frame -> Button (-text=>'Cancel ',-font=>$font,  -background=>$button, -activebackground=>$abutton, -border=>0, -command=>sub{destroy $delproj_dialog})->grid(-column=>1,-row=>2,-sticky=>"nwse");
  $delproj_dialog -> focus;
}


sub niy {
### Purpose : Issue a message window showing that the functionality is not implemented yet
### Compat  : W+L+
  $mw -> messageBox(-type=>'ok',
    	-message=>"Sorry, not implemented yet!");
}

sub populate_delete_models {
### Purpose : insert models and files to be deleted into window's listboxes
### Compat  : W+L+
  my ($del_folders_check, $del_models_check, $del_results_check, $del_tables_check, $delete_models_listbox_ref, $delete_files_listbox_ref, $runs_ref, $folders_ref) = @_;
  my @runs = @$runs_ref;
  my @folders = @$folders_ref;
  my @mod_files;
  my @lst_files;
  my @tab_files;
  foreach my $run (@runs) {
#    if (-d $run.".".$setting{ext_res}) { push (@lst_files, $run.".".$setting{ext_res}); };
    if (-e $run.".".$setting{ext_res}) { push (@lst_files, $run.".".$setting{ext_res}); };
    if (-e $run.".ext") { push (@lst_files, $run.".ext" ); };
    if (-e $run.".phi") { push (@lst_files, $run.".phi" ); };
    if (-e $run.".cor") { push (@lst_files, $run.".cor" ); };
    if (-e $run.".coi") { push (@lst_files, $run.".coi" ); };
    if (-e $run.".cov") { push (@lst_files, $run.".cov" ); };
    if (-e $run.".".$setting{ext_ctl}) { push (@mod_files, $run.".".$setting{ext_ctl}); };
    if ($del_tables_check==1) {
      my $mod_ref = extract_from_model ($run.".".$setting{ext_ctl}, $run, "all");
      my $tables_ref = $$mod_ref{tab_files};
      my @tables = ();
      foreach my $tab ( @$tables_ref ) {     # check if tables exist:
	  if (-e $tab) {
	      push (@tables, $tab);
	  }
      };
      push (@tab_files, @tables);
    }
  }
  my @files = ();

  if ($del_models_check == 1) {push (@files, @mod_files); };
  if ($del_results_check == 1) {push (@files, @lst_files); };
  if ($del_tables_check == 1) {push (@files, @tab_files); };
  $$delete_models_listbox_ref -> configure (-state=>'normal');
  $$delete_files_listbox_ref -> configure (-state=>'normal');
  $$delete_models_listbox_ref -> delete("0", "end");
  $$delete_files_listbox_ref -> delete("0", "end");

  $$delete_models_listbox_ref -> insert(0, @runs);
  foreach my $folder (@folders) {$folder .= "/ (entire folder!)"};
  if ($del_folders_check == 1) {$$delete_files_listbox_ref -> insert(0, @folders);};
  $$delete_files_listbox_ref -> insert("end", @files);
  $$delete_models_listbox_ref -> configure (-state=>'disabled');
  $$delete_files_listbox_ref -> configure (-state=>'disabled');
  return(\@files);
}

sub delete_models_window {
### Purpose : Create dialog for deleting NM models/results
### Compat  : W+L+
  my $sel_ref = shift;
  my @del_files = @ctl_show; # make copy, since @ctl_file can change during delete process!
  my @runs = @del_files[@$sel_ref];
  foreach (@runs) {$_ =~ s/dir-//}
  my $del_dialog = $mw -> Toplevel( -title=>"Delete models, results and/or tables");
  no_resize ($del_dialog);  
  my $del_dialog_frame = $del_dialog-> Frame(-background=>$bgcol)->grid(-ipadx=>'10',-ipady=>'10',-sticky=>'n');
  my $type = @file_type_copy[@runs];

  my $del_folders_check = 1;
  my $del_models_check = 1;
  my $del_results_check = 1;
  my $del_tables_check = 1;

  $del_dialog_frame -> Label (-text=>"Selected:",  -font=>$font,-background=>$bgcol) -> grid(-row=>0, -column=>1,-sticky=>"nws"); # spacer
  $del_dialog_frame -> Label (-text=>"Files / folders to delete:", -font=>$font, -background=>$bgcol) -> grid(-row=>0, -column=>2, -columnspan=>2,-sticky=>"nws"); # spacer
  my $delete_models_listbox = $del_dialog_frame -> Scrolled('Listbox',
        -selectmode => "single", -highlightthickness => 0,
        -scrollbars => 'se', -width => 16, -height     => 16,
        -border     => 1, -background => $tab_hlist_color, -selectbackground => $pirana_orange,
        -font       => $font_normal
  )->grid(-column => 1, -columnspan=>1, -row => 1, -sticky=>'nswe', -ipady=>0);
  my $delete_files_listbox = $del_dialog_frame -> Scrolled('Listbox',
        -selectmode => "single", -highlightthickness => 0,
        -scrollbars => 'se', -width => 30, -height     => 16,
        -border     => 1, -background => $tab_hlist_color, -selectbackground => $pirana_orange,
        -font       => $font_normal
  )->grid(-column => 2, -columnspan=>2, -row => 1, -sticky=>'nswe', -ipady=>0);

  $del_dialog_frame -> Label (-text=>"", -background=>$bgcol) -> grid(-row=>3, -column=>1, -sticky=>"nse"); # spacer
  $del_dialog_frame -> Label (-text=>"Delete:", -background=>$bgcol) -> grid(-row=>4, -column=>1, -sticky=>"nse"); # spacer
  $del_dialog_frame -> Checkbutton (-variable=>\$del_models_check, -font=>$font, -text => " Models", -selectcolor=>$selectcol, -activebackground=>$bgcol, -command=>sub{
    populate_delete_models($del_folders_check, $del_models_check, $del_results_check, $del_tables_check, \$delete_models_listbox, \$delete_files_listbox, \@runs, \@folders );
  })-> grid(-row=> 4, -column=>2, -sticky=>"nws");
  $del_dialog_frame -> Checkbutton (-variable=>\$del_results_check, -font=>$font, -text => " Results",-selectcolor=>$selectcol, -activebackground=>$bgcol, -command=>sub{
    populate_delete_models($del_folders_check, $del_models_check, $del_results_check, $del_tables_check, \$delete_models_listbox, \$delete_files_listbox, \@runs, \@folders);
  })-> grid(-row=> 5, -column=>2, -sticky=>"nws");
  $del_dialog_frame -> Checkbutton (-variable=>\$del_tables_check, -font=>$font, -text => " Table files", -selectcolor=>$selectcol, -activebackground=>$bgcol, -command=>sub{
    populate_delete_models($del_folders_check, $del_models_check, $del_results_check, $del_tables_check, \$delete_models_listbox, \$delete_files_listbox, \@runs, \@folders);
  })-> grid(-row=> 6, -column=>2,-sticky=>"nws");
  $del_dialog_frame -> Checkbutton (-variable=>\$del_folders_check, -font=>$font, -text => " Folders",  -selectcolor=>$selectcol, -activebackground=>$bgcol, -command=>sub{
    populate_delete_models($del_folders_check, $del_models_check, $del_results_check, $del_tables_check, \$delete_models_listbox, \$delete_files_listbox, \@runs, \@folders );
  })-> grid(-row=> 7, -column=>2, -sticky=>"nws");

  center_window($del_dialog, $setting{center_window}); # center after adding frame (redhat)
  $del_dialog -> raise();

# filter out folders
  my @folders;
  foreach my $num (@$sel_ref) {
    if ((@file_type_copy[$num] == 1)&&(@del_files[$num] ne "..")) {
	@del_files[$num] =~ s/dir-//;
	push (@folders, @del_files[$num])
    };
  }

  my $files_ref = populate_delete_models($del_folders_check, $del_models_check, $del_results_check, $del_tables_check, \$delete_models_listbox, \$delete_files_listbox, \@runs, \@folders);

  $del_dialog_frame -> Label (-text=>' ',  -font=>$font, -background=>$bgcol) -> grid(-row=>8, -column=>2); # spacer
  my $del_button = $del_dialog_frame -> Button (-text=>'Delete ',  -font=>$font, -width=>12, -background=>$button, -activebackground=>$abutton, -border=>$bbw);
  $del_button -> configure ( -command=>sub{
     # first, delete folders
      $del_button -> configure (-state => 'disabled');
     if ($del_folders_check == 1) {
       foreach my $folder (@folders) {
         if($folder ne "..") {   # for safety...
           status ("Deleting complete folder ".$folder);
           rmtree ($cwd."/".$folder,1,1);
        }
      }
     }
     # next, the selected files
     my $files_ref = populate_delete_models($del_folders_check, $del_models_check, $del_results_check, $del_tables_check, \$delete_models_listbox, \$delete_files_listbox, \@runs, \@folders);
     foreach my $del_file (@$files_ref) {
       unlink (unix_path($cwd."/".$del_file));
     }
     # remove model info from database
     foreach my $mod (@runs) {
	 $mod .= s/\.$setting{ext_ctl}//;
	 db_remove_model_info ($mod, "pirana.dir");
     }
     status ();
     $del_dialog -> destroy();
     read_curr_dir($cwd,$filter, 1);
  });
  $del_button -> grid(-row=>9,-column=>3,-sticky=>"nwse");
  $del_dialog_frame -> Button (-text=>'Cancel ',  -font=>$font,-width=>12, -border=>$bbw, -background=>$button, -activebackground=>$abutton, -command=>sub{
    destroy $del_dialog
  })->grid(-column=>2,-row=>9, -sticky=>"nwse");
}

sub populate_cleanup {
### Purpose : insert models and files to be deleted into window's listboxes
### Compat  : W+L+
  my ($del_runtime_check, $del_msf_check, $del_results_check, $delete_files_listbox_ref) = @_;
  my @files;
  my @runtime_files;
  my @runtime = qw /fort.2002 FILE07 nul PRDERR FCON FCON2 FREPORT FSTREAM LINK.LNK FDATA FMSG ERMSG FSUBS FSUBS2 FSUBS.f90 INTER OUTPUT fsubs.for FSUBS_MU.F90 nmprd4p.mod OFV.TXT df.txt nwprior.txt tnprior.txt nonmem nonmem.exe/;
  @msf_files = dir($cwd, "msf");
  @results_files = <*.$setting{ext_res}>;
  if ($del_runtime_check == 1) {
      for ($i = 1; $i<40; $i++) {
	  push (@runtime, "FILE".$i);
      }
      foreach (@runtime) {
	  if (-e $_) {push (@runtime_files, $_)};
      }
      push (@files, @runtime_files);
  };
  if ($del_msf_check == 1) {push (@files, @msf_files); };
  if ($del_results_check == 1) {push (@files, @results_files); };
  $$delete_files_listbox_ref -> configure (-state=>'normal');
  $$delete_files_listbox_ref -> delete("0", "end");
  $$delete_files_listbox_ref -> insert("end", @files);
  $$delete_files_listbox_ref -> configure (-state=>'disabled');
  return(\@files);
}

sub cleanup_runtime_files_window {
### Purpose : Create dialog for deleting NM models/results
### Compat  : W+L+
  my $del_dialog = $mw -> Toplevel( -title=>"Clean up folder");
  no_resize ($del_dialog);  
  my $del_dialog_frame = $del_dialog-> Frame(-background=>$bgcol)->grid(-ipadx=>'10',-ipady=>'10',-sticky=>'n');
  my $type = @file_type_copy[@runs];

  $del_dialog_frame -> Label (-text=>"Files / folders to delete:", -font=>$font, -background=>$bgcol) -> grid(-row=>0, -column=>2, -columnspan=>2,-sticky=>"nws"); # spacer
  my $delete_files_listbox = $del_dialog_frame -> Scrolled('Listbox',
        -selectmode => "single", -highlightthickness => 0,
        -scrollbars => 'se', -width => 30, -height     => 16,
        -border     => 1, -background => $tab_hlist_color, -selectbackground => $pirana_orange,
        -font       => $font_normal
  )->grid(-column => 2, -columnspan=>2, -row => 1, -sticky=>'nswe', -ipady=>0);

  my $del_runtime_check = 1;
  my $del_msf_check= 1;
  my $del_results_check = 0;

  # filter out folders
  my @folders;
  foreach my $num (@$sel_ref) {
    if ((@file_type_copy[$num] == 1)&&(@del_files[$num] ne "..")) {push (@folders, @del_files[$num])};
  }
  $del_dialog_frame -> Label (-text=>"", -font=>$font,  -background=>$bgcol) -> grid(-row=>3, -column=>1, -sticky=>"nse"); # spacer
  $del_dialog_frame -> Label (-text=>"Delete:",  -font=>$font, -background=>$bgcol) -> grid(-row=>4, -column=>1, -sticky=>"nse"); # spacer
  $del_dialog_frame -> Checkbutton (-variable=>\$del_runtime_check, -font=>$font,  -text => " NONMEM runtime files", -selectcolor=>$selectcol, -activebackground=>$bgcol, -command=>sub{
    populate_cleanup ($del_runtime_check, $del_msf_check, $del_results_check, \$delete_files_listbox);
  })-> grid(-row=> 4, -column=>2, -sticky=>"nws");
  $del_dialog_frame -> Checkbutton (-variable=>\$del_msf_check,  -font=>$font, -text => " MSF files",-selectcolor=>$selectcol, -activebackground=>$bgcol, -command=>sub{
    populate_cleanup ($del_runtime_check, $del_msf_check, $del_results_check, \$delete_files_listbox);
  })-> grid(-row=> 5, -column=>2, -sticky=>"nws");
  $del_dialog_frame -> Checkbutton (-variable=>\$del_results_check,  -font=>$font, -text => " Results files", -selectcolor=>$selectcol, -activebackground=>$bgcol, -command=>sub{
    populate_cleanup ($del_runtime_check, $del_msf_check, $del_results_check, \$delete_files_listbox);
  })-> grid(-row=> 6, -column=>2,-sticky=>"nws");

  $del_dialog_frame -> Label (-text=>' ',  -font=>$font, -background=>$bgcol) -> grid(-row=>8, -column=>2); # spacer
  $del_dialog_frame -> Button (-text=>'Delete ', -width=>12, -font=>$font,  -background=>$button, -activebackground=>$abutton, -border=>$bbw, -command=>sub{
      my $files_ref = populate_cleanup ($del_runtime_check, $del_msf_check, $del_results_check, \$delete_files_listbox);
      foreach my $del_file (@$files_ref) {
	  unlink (unix_path($cwd."/".$del_file));
      }
      $del_dialog -> destroy();
      read_curr_dir($cwd,$filter, 1);
  })->grid(-row=>9,-column=>3,-sticky=>"nwse");
  $del_dialog_frame -> Button (-text=>'Cancel ',  -font=>$font,-width=>12, -font=>$font,  -border=>$bbw, -background=>$button, -activebackground=>$abutton, -command=>sub{
    destroy $del_dialog
  })->grid(-column=>2,-row=>9, -sticky=>"nwse");
  center_window($del_dialog, $setting{center_window}); # center after adding frame (redhat)
  $del_dialog -> raise();

  # put in the files
  populate_cleanup ($del_runtime_check, $del_msf_check, $del_results_check, \$delete_files_listbox);

}

sub duplicate_model_window {
### Purpose : Creates a dialog window for duplicating a model file
### Compat  : W+L+
  my $sel_ref = shift;
  chdir ($cwd);
  my $overwrite_bool=1;
  @runs = @$sel_ref;
  my $runno = @ctl_show[@runs[0]];
  $new_ctl_name = new_model_name($runno);
  $new_ctl_name =~ s/dir\-//;
  $dupl_dialog = $mw -> Toplevel(-title=>'Duplicate');
  no_resize ($dupl_dialog);  
  $dupl_dialog_frame = $dupl_dialog-> Frame(-background=>$bgcol)->grid(-ipadx=>'10',-ipady=>'10',-sticky=>'n');
  center_window($dupl_dialog, $setting{center_window}); # center after adding frame (redhat)
  $dupl_dialog_frame -> Label (-background=>$bgcol,  -font=>$font,-text=>'New model number (without '.$setting{ext_ctl}.'):')->grid(-row=>1,-column=>1,-sticky=>"we");
  $dupl_dialog_frame -> Entry (-width=>8, -border=>2, -relief=>'groove',  -background=>$white,
     -textvariable=>\$new_ctl_name)->grid(-row=>1,-column=>2,-sticky=>"w");
  $dupl_dialog_frame -> Label (-background=>$bgcol, -font=>$font, -text=>'Reference model:')->grid(-row=>2,-column=>1,-sticky=>"e");
  my $new_ctl_ref = @ctl_show[@runs[0]];
  $new_ctl_ref =~ s/dir-//;
  my $ref_mod_entry = $dupl_dialog_frame -> Entry (-width=>8, -border=>2, -relief=>'groove', 
    -textvariable=> \$new_ctl_ref, -background=>$white)->grid(-row=>2,-column=>2,-sticky=>"w");

  my $modelfile = @ctl_show[@runs[0]].".".$setting{ext_ctl};
  my $modelno = $modelfile;
  $modelno =~ s/\.$setting{ext_ctl}//;
  my $mod_ref = extract_from_model ($modelfile, $modelno);
  my %mod = %$mod_ref;
  $new_ctl_descr = $mod{description};
  $new_ctl_descr =~ s/[\r\n]//g;

  $dupl_dialog_frame -> Label (-background=>$bgcol, -font=>$font, -text=>'Model description:')->grid(-row=>3,-column=>1,-sticky=>"we");
  $dupl_dialog_frame -> Label (-background=>$bgcol, -font=>$font, -justify=>"left", -text=>"\nAutomatically changing of table files only works if in the table name the exact filename of\nthe model is incorporated. E.g. if your model file is name 005.mod, then your tables should\nbe named sdtab005, tab005.tab, 005.tab, etc in the control stream\n\n."
    )->grid(-row=>7,-column=>1,-columnspan=>2,-sticky=>"w");
  $dupl_dialog_frame -> Entry (-width=>40, -border=>2, -relief=>'groove', -background=>$white,
     -textvariable=>\$new_ctl_descr)->grid(-row=>3,-column=>2,-sticky=>"w");

  $dupl_dialog_frame -> Checkbutton (-background=>$bgcol, -font=>$font, -text=>"Change model name in \$PROB / \$TABLE / \$EST / \$MSF sections?",  -selectcolor=>$selectcol, -activebackground=>$bgcol,-variable=>\$change_run_nos)->grid(-row=>4,-column=>2,-columnspan=>2,-sticky=>'w');
  my $dupl_est_state = "disabled";
  if (-e $runno.".".$setting{ext_res}) {
      my ($methods_ref, @rest) = get_estimates_from_lst ($runno.".".$setting{ext_res});
      my @methods = @$methods_ref;
      if (@methods > 0) { # only if results are available provide option
	  $dupl_est_state = "normal";
      }
  }
  $dupl_dialog_frame -> Checkbutton (-background=>$bgcol, -font=>$font, -state=>$dupl_est_state,-text=>"Use final parameter estimates from reference model?",  -selectcolor=>$selectcol, -activebackground=>$bgcol, -variable=>\$est_as_init)->grid(-row=>5,-column=>2,-columnspan=>2,-sticky=>'w');
  $dupl_dialog_frame -> Checkbutton (-background=>$bgcol, -font=>$font, -text=>"Fix estimates?", -selectcolor=>$selectcol, -activebackground=>$bgcol, -variable=>\$fix_est)->grid(-row=>6,-column=>2,-columnspan=>2,-sticky=>'w');

  #$dupl_dialog_frame -> Label (-text=>'')->grid(-row=>7,-column=>1,-sticky=>"e");
  $dupl_dialog_frame -> Label (-background=>$bgcol, -font=>$font, -text=>'')->grid(-row=>8,-column=>1,-sticky=>"e");

  $dupl_dialog_frame -> Button (-text=>'Duplicate', -font=>$font, -width=>12, -border=>$bbw, -background=>$button, -activebackground=>$abutton,-command=>sub {
    if (-e $cwd."/".$new_ctl_name.".".$setting{ext_ctl}) {  # check if control stream already exists;
      $overwrite_bool = message_yesno ("Control stream with name ".$new_ctl_name.".".$setting{ext_ctl}." already exists.\n Do you want to overwrite?", $mw, $bgcol, $font_normal);
    } else {$overwrite_bool=1};
    if ($new_ctl_name eq "") {
	message ("Please specify a valid model name.");
	$overwrite_bool = 0;
    }
    if ($new_ctl_descr eq "") {$descr_bool=0; $mw -> messageBox(-type=>'ok', -message=>"You have to provide a description of the model");} else {$descr_bool=1};
    if (($overwrite_bool==1)&&($descr_bool==1)) {
      my $new_ctl_ref = $ref_mod_entry -> get();
      $new_ctl_ref =~ s/dir\-//;
      duplicate_model ($runno, $new_ctl_name, $new_ctl_descr, $new_ctl_ref, $change_run_nos, $est_as_init, $fix_est, \%setting);
      destroy $dupl_dialog;
      sleep(1); # to make sure the file is ready for reading
      #start_command ($software{editor}, win_path($cwd)."\\".$new_ctl_name.".".$setting{ext_ctl});
      edit_model ( unix_path($cwd)."\\".$new_ctl_name.".".$setting{ext_ctl});
      refresh_pirana($cwd);
    }
  }) -> grid(-row=>8,-column=>2,-sticky=>"w");
  $dupl_dialog_frame -> Button (-text=>'Cancel ',  -font=>$font,-width=>12, -border=>$bbw, -background=>$button, -activebackground=>$abutton, -command=>sub{destroy $dupl_dialog})->grid(-column=>1,-row=>8,-sticky=>"e");
}

sub new_ctl {
### Purpose : Dialog for creating a new model file, either blank or from a template (dialog + creation of model file)
### Compat  : W+L+
  my $overwrite_bool=1;
  $new_ctl_dialog = $mw -> Toplevel(-title=>'New model file');
  no_resize ($new_ctl_dialog);  
  $new_ctl_frame = $new_ctl_dialog -> Frame () -> grid(-ipadx=>'10',-ipady=>'10');
  $new_ctl_frame -> Label (-text=>'Model number (without .'.$setting{ext_ctl}.'):',  -font=>$font)-> grid(-column=>1, -row=>1,-sticky=>'nse');
  $new_ctl_frame -> Entry ( -background=>$white,-width=>10, -border=>2, -relief=>'groove', -textvariable=>\$new_ctl_name)->grid(-column=>2,-row=>1, -sticky=>'w');
  chdir($base_dir."/templates");
  @templates = <*.mod> ;
  $i=0; foreach (@templates) {
     open (IN,$_); @lines=<IN>; close IN;
     @firstline[$i] = @lines[0];
     @firstline[$i] =~ s/model desc://i;
     @firstline[$i] =~ s/\$problem//i;
     @firstline[$i] =~ s/\;//;
     @firstline[$i] =~ s/\n//;
     @templates_descr[$i] = @firstline[$i];
     $template_file{@templates_descr[$i]} = @templates[$i];
     $i++;
  };
  $new_ctl_frame -> Label (-text=>'Template: ', -font=>$font)-> grid(-column=>1, -row=>2, -sticky=>'nse');
  $new_ctl_frame -> Label (-text=>'  ', -font=>$font)-> grid(-column=>1, -row=>3, -sticky=>'nse');
  $menu = $new_ctl_frame -> Optionmenu(-options => [@templates_descr], -border=>$bbw,
      -variable=>\$template_chosen,-background=>$lightblue,-activebackground=>$darkblue,-foreground=>$white, -activeforeground=>$white, -justify=>'left', -border=>$bbw
        )-> grid(-column=>2,-row=>2);

  $new_ctl_frame -> Button (-text=>'Create model',  -font=>$font, -border=>$bbw, -background=>$button,-activebackground=>$abutton, -command=>sub{
    if (-e $cwd."/".$new_ctl_name.".".$setting{ext_ctl}) {  # check if control stream already exists;
        $overwrite_bool = message_yesno ("Control stream with name ".$new_ctl_name.".".$setting{ext_ctl}." already exists.\n Do you want to overwrite?", $mw, $bgcol, $font_normal);
      }
    if ($new_ctl_name eq "") {
	message ("Please specify a valid model name.");
	$overwrite_bool = 0;
    }
    if ($overwrite_bool==1) {
	copy ($base_dir."/templates/".$template_file{$template_chosen}, $cwd."/".$new_ctl_name.".".$setting{ext_ctl});
	read_curr_dir($cwd, $filter,1);
	destroy $new_ctl_frame;
	destroy $new_ctl_dialog;
	edit_model (unix_path($cwd."/".$new_ctl_name.".".$setting{ext_ctl}));
    }
  }
  )-> grid(-column=>2,-row=>4, -sticky=>'w');

  center_window($new_ctl_dialog, $setting{center_window}); 

}

sub new_dir {
### Purpose : Create a new folder (dialog + create new dir)
### Compat  : W+L+
  my $overwrite_bool=1;
  $newdir_dialog = $mw -> Toplevel(-title=>'New folder');
  no_resize ($newdir_dialog);  
  $newdir_dialog_frame = $newdir_dialog-> Frame(-background=>$bgcol)->grid(-ipadx=>'10',-ipady=>'10',-sticky=>'n');
  $newdir_dialog_frame -> Label (-text=>"Folder name: \n", -font=>$font)->grid(-column=>1,-row=>1,-sticky=>"ne");
  $newdir_dialog_frame -> Entry ( -background=>$white, -width=>20, -border=>2, -relief=>'groove', -textvariable=>\$new_dir_name)->grid(-column=>2,-row=>1,-sticky=>"ne");
  $newdir_dialog_frame -> Button (-text=>'Create folder', -font=>$font,  -width=>12, -border=>$bbw, -background=>$button,-activebackground=>$abutton, -command=>sub{
    if (-d $cwd."/".$new_dir_name) {  # check if dir already exists;
        message ("Folder ".$new_dir_name." already exists.", $mw, $bgcol, $font_normal);
    } else {
	if ($new_dir_name eq "") {
	    message ("Please specify a valid folder name.");
	} else {
	    mkdir ($cwd."/".$new_dir_name);
	}
    }
    refresh_pirana($cwd);
    destroy $newdir_dialog;
  })->grid(-column=>2,-row=>2,-sticky=>"w");
  $newdir_dialog_frame -> Button (-text=>'Cancel', -font=>$font, -width=>12, -border=>$bbw,-background=>$button,-activebackground=>$abutton,-command=>sub{
    destroy $newdir_dialog;
  })->grid(-column=>1,-row=>2,-sticky=>"e");
  center_window($newdir_dialog, $setting{center_window}); # center after adding frame (redhat)

}

sub rename_ctl {
### Purpose : Rename a NM model file (create dialog and perform the renaming)
### Compat  : W+L+
  my $overwrite_bool=1;
  $old = @_[0];
  $ren_dialog = $mw -> Toplevel(-title=>'Rename model file');
  no_resize ($ren_dialog) ;  
  $ren_dialog_frame = $ren_dialog-> Frame(-background=>$bgcol)->grid(-ipadx=>'10',-ipady=>'10',-sticky=>'n');
  $ren_dialog_frame -> Label (-background=>$bgcol,-text=>'New model (without .'.$setting{ext_ctl}.'): '."\n",-font=>$font_normal)->grid(-column=>1,-row=>1,-sticky=>"ne");
  $ren_dialog_frame -> Label (-background=>$bgcol,-text=>"\nNB. Both model files and result file and will be renamed.\nOther files (e.g. table files) will not be modified.\n", -foreground=>'#777777', -justify=>"l", -font=>$font_normal)->grid(-column=>2,-row=>4,-sticky=>"nw",-columnspan=>1);
  $ren_dialog_frame -> Entry ( -background=>$white, -width=>10, -border=>2, -relief=>'groove', -textvariable=>\$ren_ctl_name)->grid(-column=>2,-row=>1,-sticky=>"nw");
  my $change_run_nos = 1;
  my $rename_results_files = 1;
  $ren_dialog_frame -> Checkbutton (-variable=>\$rename_results_files, -background=>$bgcol, -text=>"Also rename associated results files (.".$setting{ext_res}."/.ext/.phi)?", -font=>$font_normal, -selectcolor=>$selectcol, -activebackground=>$bgcol)->grid(-row=>2,-column=>2,-columnspan=>1,-sticky=>'w');
  $ren_dialog_frame -> Checkbutton (-background=>$bgcol, -text=>"Change model name in \$PROB / \$TABLE / \$EST sections?", -font=>$font_normal, -selectcolor=>$selectcol, -activebackground=>$bgcol,-variable=>\$change_run_nos)->grid(-row=>3,-column=>2,-columnspan=>1,-sticky=>'w');
  $ren_dialog_frame -> Button (-text=>"Rename", -font=>$font_normal, -width=>12, -border=>$bbw,-background=>$button,-activebackground=>$abutton,-command=>sub{
    if ((-e $cwd."/".$ren_ctl_name.".".$setting{ext_ctl})||((-e $cwd."/".$ren_ctl_name.".".$setting{ext_res}))) {  # check if control stream already exists;
	$overwrite_bool = message_yesno ("Model- or result-file(s) for ".$ren_ctl_name." already exists.\n Do you want to overwrite?", $mw, $bgcol, $font_normal);
    }
    if ($overwrite_bool==1) {
	if ($change_run_nos == 0) {
	    move ($old.".".$setting{ext_ctl}, $ren_ctl_name.".".$setting{ext_ctl});
	} else {
	    my $mod_ref = extract_from_model ($old.".".$setting{ext_ctl}, $old);
	    my %mod = %$mod_ref;
	    duplicate_model ($old, $ren_ctl_name, $mod{description}, $mod{refmod}, 1, 0, 0, \%setting);
	    if (-e $ren_ctl_name.".".$setting{ext_ctl}) {
		unlink ($old.".".$setting{ext_ctl});
	    }
	}
	db_rename_model ($old, $ren_ctl_name, "pirana.dir");
	if ($rename_results_files==1) {
	    if (-e $old.".".$setting{ext_res}) {
		move ($old.".".$setting{ext_res}, $ren_ctl_name.".".$setting{ext_res});
	    }
	    if (-e $old.".ext") {
		move ($old.".ext", $ren_ctl_name.".ext");
	    }
	    if (-e $old.".phi") {
		move ($old.".phi", $ren_ctl_name.".phi");
	    }
	}
    }
    read_curr_dir($cwd, $filter, 1);
    destroy $ren_dialog;
  })->grid(-column=>2,-row=>5,-sticky=>"w");
  $ren_dialog_frame -> Button (-text=>'Cancel', -font=>$font_normal, -width=>12, -border=>$bbw,-background=>$button,-activebackground=>$abutton,-command=>sub{
    destroy $ren_dialog;
  })->grid(-column=>1,-row=>5,-sticky=>"e");
  center_window($ren_dialog, $setting{center_window}); # center after adding frame (redhat)
}

sub update_model_descr {
### Purpose : Updata model description (extracted from NM model file)
### Compat  : W+L+
  my $mod_nr = shift;
  my $mod_ref = extract_from_model ($mod_nr.".".$setting{ext_ctl}, $mod_nr, "all");
  #print $mod_nr.": ".$mod{refmod}."\n";
  my %mod = %$mod_ref;
  my $sql_command = "UPDATE model_db SET date_mod='".$mod{date_mod}."', descr='".$mod{description}.
        "', ref_mod='".$mod{refmod}."', method='".$mod{method}."', dataset='".$mod{dataset}."' WHERE model_id='".$mod_nr."'";
  status ("Gathering data for model ".$mod_nr);
  return ($sql_command);
}

sub update_run_results {
### Purpose : Get updated run results from the NM results file, and update the database
### Compat  : W+L+
  my $mod = shift;
  my $res_ref = extract_from_lst ($mod.".".$setting{ext_res});
  my %res = %$res_ref;
  my $sql_command = "UPDATE model_db SET ".
        "date_res='".$res{resdat}."', suc='".$res{suc}."', ofv='".$res{ofv}."', sig='".$res{sig}."', ".
        "bnd='".$res{bnd}."', cov='".$res{cov}."' ".
        "WHERE model_id='".$mod."'";
  status ("Gathering data for model ".$mod);
  return($sql_command);
}

sub read_curr_dir {
### Purpose : Get all model files and all directories in curr dir and put them in arrays
### Compat  : W+
### Notes   : sub could be somewhat more refined

    # remove superfluous batch files
    status ("Checking db file...");
    check_db_file_correct ("pirana.dir");

    status ("Reading all files...");
    my @files1 = dir ($cwd, "");
    my ($ctl_files_ref, $all_files_ref) = sort_model_files (\@files1, '\.'.$setting{ext_ctl});
    our @ctl_files = @$ctl_files_ref;
    our @all_files = @$all_files_ref;

    my @bat_remove = @{filter_array(\@all_files, 'pirana_start')} ;
    foreach(@bat_remove) {unlink ($_)};

    # arguments (dir, filter, reload?)
    $load_dir = @_[0];
    $filter = @_[1];
    $reload = @_[2];

    # file types: 0=[..] , 1=directory, 2=mod file
    if ($reload==1) {
	chdir @_[$load_dir];

	status ("Reading output files...");
	our %models_descr = {}; our %models_refmod = {};
	our %file_type = {}; our %models_notes = {};  our %models_colors = {};
	our %models_dates = {}; our %models_dates_db = {}; our %models_resdates_db = {}; our %models_resdates = {};
	our %models_ofv = {}; our %models_suc = {}; our %models_bnd = {}; our %models_cov = {}; our %models_sig = {};

	status ("Looking for new model files and results...");
	undef @dirs; my @firstline; undef @dirs2; undef @dir_files;
	undef @ctl_copy; undef @ctl_descr_copy;
	undef @file_type; undef @file_type_copy;  undef @ctl_descr;

	$i=0; if (@ctl_files>0) {
	    foreach (@ctl_files) {
		@ctl_files[$i] =~ s/\.$setting{ext_ctl}//i;
		if (-e $_.".".$setting{ext_ctl}) {
		    $models_dates{$_} = stat($_.".".$setting{ext_ctl})->mtime;
		}
		if (-e $_.".".$setting{ext_res}) {
		    $models_resdates{$_} = stat($_.".".$setting{ext_res})->mtime;
		}
		@ctl_descr[$i] = $models_descr{$_};
		@file_type[$i] = 2;
		$file_type{@ctl_files[$i]} = 2;
		$i++;
	    };
	}
	# Db
	status ("Loading model information from database...");
	if (@ctl_files>0) {
	    status ("Creating tables in database if they do not exist...");
	    db_create_tables("pirana.dir");
	    status ("Gathering available model information from database...");
	    update_model_info(db_read_all_model_data("pirana.dir"), "pirana.dir"); # get all the models and info from the db if any present
	    status ("Gathering update information..."); # and update the hashes containing the info
	    my @sql_commands;
	    # check all the runs in the directory with the Db
	    foreach my $mod (@ctl_files) {
		if ($file_type{$mod} == 2) {
		    $mod =~ s/\.$setting{ext_ctl}//i;
		    if (exists $models_dates_db{$mod}) { # if already exists in db-hash then do nothing
			# check if newer model or results file. if so, update db
			if ($models_dates{$mod} != $models_dates_db{$mod}) {
			    push(@sql_commands, update_model_descr ($mod));
			}
			if ($models_resdates{$mod} != $models_resdates_db{$mod}) {
			    push(@sql_commands, update_run_results ($mod));
			}
		    } else { # add to db
			unless ($mod =~ m/HASH/) {
			    db_execute ("INSERT INTO model_db (model_id) VALUES ('".$mod."') ", "pirana.dir");
			    push(@sql_commands, update_model_descr ($mod));
			    push(@sql_commands, update_run_results ($mod));
			}
		    }
		}
	    }
	    status ("Updating database...");
	    db_execute_multiple(\@sql_commands, "pirana.dir");
	    status ("Updating Pirana hashes...");
	    update_model_info(db_read_all_model_data("pirana,dir"), "pirana.dir"); # update hashes
	}

	# Get directories in the current folder
	status ("Reading folders...");
	our @dirs;
#    our @dir_files = dir ("."); # is faster than a regular <*>  ?
	@all_files = sort (@all_files);
	foreach(@all_files) {
	    if (-d $_) {
#		unless ($_ =~ /\./) {
		    push (@dirs, "dir-".$_);
		    push (@dirs2, "/".$_);
#		}
	    }
	}
	unshift (@ctl_descr, @dirs2);
	unshift (@ctl_files, @dirs);
	foreach (@dirs) {
	    unshift (@file_type,1);
	}

	if(length($cwd)>3) {  # if not in root, show "[..]"
	    unshift (@ctl_descr,"/..");
	    unshift (@ctl_files,"..");
	    unshift (@dirs2,"/..");
	    unshift (@dirs,"..");
	    unshift (@file_type,0)
	}
    }

    # Filter
    if (($filter eq "")&&($psn_dir_filter==1)) {
	@ctl_descr_copy = @ctl_descr;
	@ctl_copy = @ctl_files;
	@file_type_copy = @file_type;
    } else {
	$i=0;
	undef @ctl_copy; undef @ctl_descr_copy; undef @file_type_copy;
	foreach (@ctl_descr) {   # filter
	    $filter =~ s/[\*,\\,\/,\[,\]]//g;
	    if (((@ctl_files[$i] =~ m/$filter/i) || ($models_notes{@ctl_files[$i]} =~ m/$filter/i) || ($models_descr{@ctl_files[$i]} =~ m/$filter/i)) || ($filter eq "")) {
		unless ( ( ( @file_type[$i]<2) && ( (@ctl_descr[$i] =~ m/\.dir/i) || (@ctl_descr[$i] =~ m/scm/i) || (@ctl_descr[$i] =~ m/cdd/i) || (@ctl_descr[$i] =~ m/mcmp/i) || (@ctl_descr[$i] =~ m/modelfit/i) || (@ctl_descr[$i] =~ m/run/i) || (@ctl_descr[$i] =~ m/npc/i) || (@ctl_descr[$i] =~ m/bootstrap/i) || (@ctl_descr[$i] =~ m/sse/i) || (@ctl_descr[$i] =~ m/llp/i)) && ($psn_dir_filter==0) ) || ( (@file_type[$i]<2) && (@ctl_descr[$i] =~ m/nmfe_/i) && ($psn_dir_filter==0) ) || ( (@ctl_files[$i] =~ m/nmprd4p/i) || (@ctl_descr[$i] =~ m/worker*/i) ) ) {
		    push (@ctl_descr_copy, @ctl_descr[$i]);
		    push (@ctl_copy, @ctl_files[$i]);
		    push (@file_type_copy, @file_type[$i]);
		}
	    }
	    $i++;
	}
    }
    status ("Updating Pirana model view...");
    populate_models_hlist ($setting_internal{models_view}, $condensed_model_list);
    status ();
}

sub update_model_info {
### Purpose : Read model info and update the hash
### Compat  : W+L?
    my @model_refs = db_read_all_model_data ("pirana.dir");
    our %models_dates_db    = %{@model_refs[0]};  # and update the global information hashes
    our %models_resdates_db = %{@model_refs[1]};
    our %models_refmod      = %{@model_refs[2]};
    our %models_descr       = %{@model_refs[3]};
    our %models_method      = %{@model_refs[4]};
    our %models_ofv         = %{@model_refs[5]};
    our %models_suc         = %{@model_refs[6]};
    our %models_bnd         = %{@model_refs[7]};
    our %models_cov         = %{@model_refs[8]};
    our %models_sig         = %{@model_refs[9]};
    our %models_notes       = %{@model_refs[10]};
    our %models_colors      = %{@model_refs[11]};
    our %models_dataset     = %{@model_refs[12]};
}


sub calc_ofv_diff {
    my ($ref_ofv, $ref_method, $ofv, $method) = @_ ;
    my @ref_methods = split (",", $ref_method);
    my @methods = split (",", $method);
    my @ofvs = split (",", $ofv);
    my @ref_ofvs = split (",", $ref_ofv);
    my %ofv_c; my %ref_ofv_c; my @dofv;
    my $i = 0;
    foreach my $meth (@ref_methods) {
	$ref_ofv_c{$meth} = @ref_ofvs[$i];
	$i++;
    }
    my $i = 0;
    foreach my $meth (@methods) {
	$ofv_c{$meth} = @ofvs[$i];
	if ($ref_ofv_c{$meth} ne "") {
	    push (@dofv, rnd(($ofv_c{$meth} - $ref_ofv_c{$meth}),3) );
	}
	$i++;
    }
    my $d = join (",", @dofv);
    return ($d);
};

sub return_last {
# Purpose: Return only last value in a comma-separated string
    my $all_str = shift;
    my @all = split (",", $all_str);
    return (@all[-1]);
}

sub populate_models_hlist {
### Purpose : To put all the NM model files and directories found in the current working directory in the main overview table
### Compat  : W+
  my ($order, $condensed) = @_;
  my $add_condensed = "";
  if ($condensed == 0 ) {
      $add_condensed = "\n\n";
  }
  our @ctl_show;
  my %model_indent;
  if ($order eq "tree") {
    my ($ctl_show_ref, $model_indent_ref) = tree_models();
    our @ctl_show = @$ctl_show_ref;
    %model_indent = %$model_indent_ref;
    $models_hlist->columnWidth(0, 0);
    $models_hlist->columnWidth(1, (@models_hlist_widths[1]+@models_hlist_widths[2]));
    $models_hlist->columnWidth(2, 0);
  } else {
    our @ctl_show = @ctl_copy;
    $models_hlist->columnWidth(0, 0); # Dummy column, needed to remove whitespace between columns (bug in Tk?)
    $models_hlist->columnWidth(1, @models_hlist_widths[1]);
    $models_hlist->columnWidth(2, @models_hlist_widths[2]);
  }
  if ($models_hlist) {
    $models_hlist -> delete("all");
    for ($i=0; $i<int(@ctl_show);$i++) {
      $models_hlist -> add($i);
      my $ofv_diff;
      unless ((@file_type_copy[$i] < 2)&&(length(@ctl_descr_copy[$i]) == 0)) {
#	  print @ctl_show[$i]. "  ".@file_type_copy[$i] ."\n";
        if (@file_type_copy[$i] < 2) {
          $runno = "<DIR>";
	  $style = $dirstyle;
          $models_hlist -> itemCreate($i, 0, -text => "", -style=>$style);
          $models_hlist -> itemCreate($i, 1, -text => $runno, -style=>$style);
          $models_hlist -> itemCreate($i, 2, -text => "", -style=>$style);
          $models_hlist -> itemCreate($i, 3, -text => @ctl_descr_copy[$i], -style=>$style );
          for ($j=4; $j<=12; $j++) {$models_hlist -> itemCreate($i, $j, -text => " ", -style=>$dirstyle);}  
        } else {
           $runno = @ctl_show[$i];
	   my $mod_background = "#FFFFFF";
           unless ($models_colors{$runno} eq "") {
             $mod_background = $models_colors{$runno};
           }
	   if (even($i)) {$mod_background = dark_row_color($mod_background)};
           our $style_ofv   = $models_hlist -> ItemStyle( 'text', -anchor => 'ne', -justify=>'l', -padx => 5, -pady=>$hlist_pady, -background=>$mod_background, -font => $font_small, -foreground=>"#000000");
           our $style       = $models_hlist -> ItemStyle( 'text', -anchor => 'nw',-padx => 5, -pady=>$hlist_pady,-background=>$mod_background, -font => $font_normal);
           our $style_small = $models_hlist -> ItemStyle( 'text', -anchor => 'nw', -padx => 5, -pady=>$hlist_pady, -background=>$mod_background, -font => $font_normal);
           our $style_green = $models_hlist -> ItemStyle( 'text', -padx => 5, -pady=>$hlist_pady,-anchor => 'ne', -background=>$mod_background, -foreground=>'#008800',-font => $font_small);
           our $style_red   = $models_hlist -> ItemStyle( 'text', -padx => 5, -pady=>$hlist_pady,-anchor => 'ne', -background=>$mod_background, -foreground=>'#990000', -font => $font_small);
           if (($models_ofv{$runno} ne "")&&($models_ofv{$models_refmod{$runno}} ne "")) {
	       $ofv_diff = calc_ofv_diff ($models_ofv{$models_refmod{$runno}}, $models_method{$models_refmod{$runno}}, $models_ofv{$runno}, $models_method{$runno}) ;
             #if ($ofv_diff >= $setting{ofv_sign}) { $style_ofv = $style_green; }
             #if ($ofv_diff < 0) { $style_ofv = $style_red; }
             #if (($ofv_diff >= 0)&&($ofv_diff < $setting{ofv_sign})) {
             #  $style_ofv = $models_hlist->ItemStyle( 'text', -anchor => 'ne',-padx => 5, -foreground=>'#A0A000', -background=>$mod_background,-font => $font_small);
             #}
             #$ofv_diff = rnd(-$ofv_diff,3); # round before printing
	   } else {
	       $ofv_diff=""; 
	       $style_ofv = $models_hlist->ItemStyle( 'text', -anchor => 'ne',-padx => 5, -pady=>$hlist_pady, -foreground=>'#000000', -background=>$mod_background,-font => $font_small);
	   }
	   my $runno_text = "";
	   for ($sp=0; $sp<$model_indent{$runno}; $sp++) {$runno_text .= "   "};
	   if ($model_indent{$runno}>0) {$runno_text .= "� ";}
	   $runno_text .= $runno;
	   $runno_text =~ s/run//i;
	   my $runno_ref_text = $models_refmod{$runno};
	   $runno_ref_text =~ s/run//i;
	   my $method_temp = $models_method{$runno};
	   my $dataset_temp = extract_file_name ($models_dataset{$runno});
	   my $ofv_temp    = $models_ofv{$runno};
	   my $dofv_temp   = $ofv_diff;
	   my $succ_temp; my $cov_temp; my $bnd_temp; my $sig_temp;
	   my @meth = split (",",$method_temp);
	   my $descr = $models_descr{$runno};
	   chomp($descr);
	   if ($condensed == 0) {
	       foreach (@meth) { # put the SUUCCESSFUL MINIMIZATION from FO methods on the correct line
		   if ($_ =~ m/FO/) {
		       $succ_temp = add_item($succ_temp, $models_suc{$runno});
		       $cov_temp = add_item($cov_temp, $models_cov{$runno});
		       $bnd_temp = add_item($bnd_temp, $models_bnd{$runno});
		       $sig_temp = add_item($sig_temp, $models_sig{$runno});
		   } else {
		       $succ_temp = add_item($cov_temp, " ");
		       $cov_temp = add_item($cov_temp, " ");
		       $bnd_temp = add_item($bnd_temp, " ");
		       $sig_temp = add_item($sig_temp, " ");
		   }
	       };
	       $succ_temp =~ s/\,/\n/g;
	       $cov_temp =~ s/\,/\n/g;
	       $bnd_temp =~ s/\,/\n/g;
	       $sig_temp =~ s/\,/\n/g;
	       $method_temp =~ s/\,/\n/g;
	       $ofv_temp =~ s/\,/\n/g;
	       $dofv_temp =~ s/\,/\n/g;
 	   } else {
	       $descr =~ s/[\r\n]/, /g; 
	       $method_temp = return_last ($method_temp);
	       $ofv_temp = return_last ($ofv_temp);
	       $dofv_temp = return_last ($dofv_temp);
	       $succ_temp   = $models_suc{$runno};
	       $cov_temp   = $models_cov{$runno};
	       $bnd_temp   = $models_bnd{$runno};
	       $sig_temp   = $models_sig{$runno};
	   }
	   if (($models_ofv{$runno} eq "")||($models_ofv{$models_refmod{$runno}} eq "")) {
	       $models_dofv{$runno} = "";
	   }
          $models_hlist -> itemCreate($i, 0, -text => "", -style=>$style);
          $models_hlist -> itemCreate($i, 1, -text => $runno_text.$add_condensed, -style=>$style);
          $models_hlist -> itemCreate($i, 2, -text => $runno_ref_text, -style=>$style);
          $models_hlist -> itemCreate($i, 3, -text => $descr, -style=>$style );
          $models_hlist -> itemCreate($i, 4, -text => $method_temp, -style=>$style);
          $models_hlist -> itemCreate($i, 5, -text => $dataset_temp, -style=>$style);
          $models_hlist -> itemCreate($i, 6, -text => $ofv_temp, -style=>$style);
          $models_hlist -> itemCreate($i, 7, -text => $dofv_temp, -style=>$style);
          $models_hlist -> itemCreate($i, 8, -text => $succ_temp, -style=>$style);
          $models_hlist -> itemCreate($i, 9, -text => $cov_temp, -style=>$style);
          $models_hlist -> itemCreate($i, 10, -text => $bnd_temp, -style=>$style);
          $models_hlist -> itemCreate($i, 11, -text => $sig_temp, -style=>$style);
          my $note = $models_notes{$runno};
	  if ($condensed == 1) {$note =~ s/\n/\ /g;}
          $models_hlist -> itemCreate($i, 12, -text => $note, -style=>$style);
        };
      }
    }
    $models_hlist -> update();
  }
}

sub read_tab_files {
### Purpose : Read in all table/csv files in a directory
### Compat  : W+
    my @tabcsv_files = (); my @tab_files; my @tabcsv_files_loc; my @csv_files = (), my @xp_tabs = (); my @xp_tabsnos = (); my @split=(); my @split2=();
    if (! -d @_[0]) {return ;};
    my $dir = shift;
    chdir ($cwd);
    if ($dir =~ m/\.\./) {
	@split = split (/\\/, win_path($dir));
	for ($i=0; $i<@split; $i++) {
	    if (@split[$i] eq "..") {
		pop (@split2);
	    } else {push (@split2, @split[$i]); }
	}
	$dir = join ("\/", @split2);
    }
    my $flag = 0;
    if (chdir ($dir)) {
	my @tab_all = @all_files;
	if ($show_data eq "tab") {
	    my @tab_files = @{filter_array(\@tab_all, '\.'.$setting{ext_tab})} ;
	    my @xp_tabs1  = @{filter_array(\@tab_all, 'sdtab')} ;
	    push (@xp_tabs1, @{filter_array(\@tab_all, 'patab')}) ;
	    push (@xp_tabs1, @{filter_array(\@tab_all, 'catab')}) ;
	    push (@xp_tabs1, @{filter_array(\@tab_all, 'cotab')}) ;
	    push (@xp_tabs1, @{filter_array(\@tab_all, 'vpctab')}) ;
	    push (@xp_tabs1, @{filter_array(\@tab_all, 'npctab')}) ;
	    for ($i=0; $i<@xp_tabs1; $i++) {
		unless (grep {$_ eq @xp_tabs1[$i]} @tab_files) {
		    push (@xp_tabs, @xp_tabs1[$i] );
		}
	    }
	    my @tab_files = sort (@tab_files);
	    foreach (@tab_files) {
		my ($drop, $ext) = split (/\./, $_);
		unless ($_=~ m/.$setting{ext_csv}/i) {
		    push (@tabcsv_files, $_);
		    push (@tabcsv_files_loc, $dir.'/'.$_);
		}
	    }
	    foreach (@xp_tabs) {
		unless ($_=~ m/.$setting{ext_csv}/i) {
		    push (@tabcsv_files, $_) ;
		    push (@tabcsv_files_loc, $dir.'/'.$_);
		}
	    }
	    $flag = 1;
	}
	if ($show_data eq "csv") {
	    my @csv_files = @{filter_array(\@all_files, '\.'.$setting{ext_csv})} ;
	    @tabcsv_files = @csv_files;
	    @tabcsv_files_loc = @csv_files;
	    $flag = 1;
	}
	if ($show_data eq "xpose") {
	    my @xp_tabs  = @{filter_array(\@all_files, "..tab")} ;
	    my @xp_tabsnos = ();
	    foreach(@xp_tabs) {
		$no = $_;
		$no =~ s/sdtab//i;
		$no =~ s/patab//i;
		$no =~ s/catab//i;
		$no =~ s/cotab//i;
		$no =~ s/cwtab//i;
		@test = grep (/$no/, @xp_tabsnos);
		unless (int(@test)>0) {
		    unless (($no =~ m/.$setting{ext_tab}/ig)||($no =~ m/\.csv/ig)||($no =~ m/\.deriv/ig)||($no =~ m/\.est/ig)) {
			push (@xp_tabsnos, $no);
		    }
		}
	    }
	    @tabcsv_files = sort (@xp_tabsnos);
	    $flag = 1;
	}
	if ($show_data eq "R") {
	    my @R_files  = @{filter_array(\@all_files, '\.[RSrs]$')} ;
	    @tabcsv_files = @R_files;
	    @tabcsv_files_loc = @R_files;
	    $flag = 1;
	}
	if ($show_data eq "*") {
	    foreach (@all_files) {
		unless (-d $_) {
		    push(@tabcsv_files, $_);
		    push(@tabcsv_files_loc, $_);
		}
	    }
	    $flag = 1;
	}
	if ($flag == 0) { # not the default file-types, but user supplied
	    my @all_files = @{filter_array(\@all_files, $show_data)};
	    foreach (@all_files) {
		unless (-d $_) {
		    push(@tabcsv_files, $_);
		    push(@tabcsv_files_loc, $_);
		}
	    }
	    $flag = 1;
	} 
	# get table/file info from databases and put in hash
	chdir($cwd);
	$db_table_info = db_read_table_info ("pirana.dir");
	our %table_descr={}; our %table_creator ={}; our %table_note ={};
	my $i=0;
	foreach my $row (@$db_table_info) {
	    my ($file, $descr, $note, $creator) = @$row;
	    $table_descr{$file} = $descr;
	    $table_creator{$file} = $creator;
	    $table_note{$file} = $note;
	}

	return (\@tabcsv_files, \@tabcsv_files_loc); # these are also global variables
    }
}

sub tab_dir {
### Purpose : Read tab/csv/r files for the current dir
### Compat  : W+
  my $tabdir = shift;
  if ($tab_hlist) {
  ($tabcsv_files_ref, $tabcsv_loc_ref) = read_tab_files ($tabdir);
  $tab_hlist -> delete("all");
  $tab_hlist -> update();
  our @tabcsv_files = @$tabcsv_files_ref;
  our @tabcsv_loc = @$tabcsv_loc_ref;
  if ($setting{alt_data_dir} ne "") {
      ($alt_files_ref, $alt_loc_ref) = read_tab_files (unix_path($tabdir."\/".$setting{alt_data_dir}));
      @alt_files = @$alt_files_ref;
      @alt_loc = @$alt_loc_ref;
      if ($setting{alt_data_dir} =~ m/\.\./) {
        $dir_up = one_dir_up($cwd);
        $alt_dir = $setting{alt_data_dir};
        $alt_dir =~ s/\.\./$dir_up/i;
        foreach (@alt_loc) {$_ = unix_path($alt_dir."/".$_ ); };
      } else {
        $alt_dir = $setting{alt_data_dir};
        foreach (@alt_loc) {$_ = unix_path($_ ); };
      }
      foreach (@alt_files) {$_ = unix_path($setting{alt_data_dir}."/".$_ )};
      push (@tabcsv_files, @alt_files);
      push (@tabcsv_loc, @alt_loc);
  }
  }
}

sub populate_tab_hlist {
### Purpose : Put the tables/files in the current (and data-)dir in the listbox that was created earlier
### Compat  : W+
  my $hlist = shift;
  $style = $align_left;
  my $i=0;
  $hlist -> delete ("all");
  foreach (@tabcsv_files) {
    if($hlist) {
      $hlist -> add($i);
      my $style = $hlist-> ItemStyle('text', -anchor => 'nw',-padx => 3, -pady=>$hlist_pady, -background=>$tab_hlist_color, -font => $font_normal);
      $hlist -> itemCreate($i, 0, -text => $_, -style=>$style);
      $i++;
    }
  }
}

sub print_note {
### Purpose : Print a note saying that the model was executed from Pira�a
### Compat  : W+L+?
  open (NOTE,">note.txt");
  print NOTE "*********************************************************\n";
  print NOTE "Compiled by Pirana v".$version." using NONMEM version: ".$nm_inst_chosen."\n";
  print NOTE "Run started locally by ".$setting{username}."\n";
  print NOTE "at ".localtime().".\n";
  print NOTE "*********************************************************\n";
  my %sizes = read_sizes($nm_dirs{@_[0]});
  @sizes_refs = read_sizes($nm_dirs{$nm_chosen});
  ($sizes_key_ref,$sizes_value_ref) = @sizes_refs;
  @sizes_key = @$sizes_key_ref;
  @sizes_value = @$sizes_value_ref;
  $sizes_string = "";
  $i=0; foreach(@sizes_key) {$sizes_string .= @sizes_key[$i]."=".@sizes_value[$i].","; $i++};
  print NOTE "SIZES: ".$sizes_string."\n";
  print NOTE "*********************************************************\n";
  close (NOTE);
}

sub update_nmfe_run_script_area {
    my ( $command_area, $script_file, $model_list, $nm_version_chosen, $method_chosen, $run_in_new_dir, $new_dirs_ref, $run_in_background, $clusters_ref, $ssh_ref, $nm_versions_menu, $parallelization_text) = @_;
#    build_nmfe_run_command ($script_file, $model_list, $nm_version_chosen, $method_chosen, $run_in_new_dir, $new_dirs_ref, $run_in_background, $clusters_ref);
     my ($run_script, $script_ref) = create_nm_start_script ($script_file, $nm_version_chosen, os_specific_path($cwd), $model_list, $run_in_new_dir, $new_dirs_ref, $clusters_ref, $ssh_ref, $parallelization_text);
    my @script = @$script_ref;
    if ($command_area) {
	$command_area -> delete("0.0", "end");
	$command_area -> insert("0.0", join ("", @script));
    }
    if ($ssh {connect_ssh} == 1 ) {
	my ($nm_dirs_cluster_ref, $nm_vers_cluster_ref) = read_ini($home_dir."/ini/nm_inst_cluster.ini");
	my @nm_installations; 
	my %nm_dirs_cluster = %$nm_dirs_cluster_ref;
	foreach(keys(%nm_dirs_cluster)) {   # filter only non-blank NM installations;
	    if ($nm_dirs_cluster{$_} ne "") {
		push (@nm_installations, $_)
	    };
	};	
        if (int(@nm_installations) == 0) {@nm_installations = ("")};
	if ($nm_versions_menu =~ m/OPTION/i) {
	    $nm_versions_menu -> configure (-options=> [@nm_installations]);
	}
    } else {
	my ($nm_dirs_ref, $nm_vers_ref) = read_ini($home_dir."/ini/nm_inst_local.ini");
	my @nm_installations; 
	my %nm_dirs = %$nm_dirs_ref;
	foreach(keys(%nm_dirs)) {   # filter only existing NM installations
	    if (-e $nm_dirs{$_}) {
		push (@nm_installations, $_)
	    };
	};
        if (int(@nm_installations) == 0) {@nm_installations = ("")};
 	if ($nm_versions_menu =~ m/OPTION/i) {
 	    $nm_versions_menu -> configure (-options=> [@nm_installations]);
	}
    }

    # workaround
    if (($os =~ m/MSWin/i)&&($ssh{connect_ssh}==0)) {
        $nmfe_run_command =~ s/\.sh/\.bat/; # make sure it creates batch file;
    } else {
        $nmfe_run_command =~ s/\.bat/\.sh/; # make sure it creates a shell-script;
    }

    # update global settings
    my %clusters = %$clusters_ref;
    return();
}

sub update_psn_run_script_area {
    my ( $psn_command_line_entry, $psn_command_line, $clusters_ref, $ssh_ref) = @_;
    if ($psn_command_line_entry) {
	$psn_command_line_entry -> delete("0.0", "end");
        $psn_command_line_entry -> insert("0.0", join ("", $psn_command_line));
    }
    # update global settings
    my %clusters = %$clusters_ref;
    return();
}

sub build_nmfe_run_command {
    ($script_file, $model_list_ref, $nm_inst, $method, $run_in_new_dir, $new_dirs_ref, $run_in_background, $clusters_ref, $ssh_ref) = @_;
    my %ssh = %$ssh_ref;
    my @files = @$model_list_ref;
    my @nm_installations;
    if ($ssh{connect_ssh} == 1) {
        @nm_installations = keys(%nm_dirs_cluster);
    } else {
        @nm_installations = keys(%nm_dirs);
    }
    my ($run_script, $script_ref) = create_nm_start_script ($script_file, $nm_inst, os_specific_path($cwd), \@files, $run_in_new_dir, $new_dirs_ref, $clusters_ref, $ssh_ref);
    if (@nm_installations > 0) {
	my $command;
	my $ssh_com;
	my ($ssh_pre, $ssh_post);
	($ssh_pre, $ssh_post) = build_ssh_connection (\%ssh, $cwd, \%setting);	
	$command = $ssh_pre ; #. $ssh_com;
	if (($os =~ m/MSWin/i)&&($ssh{connect_ssh}==0)) {
	    if ($run_in_background == 1) {
		$command .= $run_script;
	    } else {
		$command .= $run_script;
	    }
	} else {
            if (($os =~ m/MSWin/i)&&($ssh{connect_ssh}==1)) {
                $command .= 'dos2unix '.$run_script.'; chmod 755 '.$run_script.'; ';  #only on Win+SSH-->Linux
            }
            $command .= './'.$run_script; #only on linux
        }
	$command .= $ssh_post;
	unless (($os =~ m/MSWin/ )||($run_in_background==0)) {$command .= " &"}
	return ($run_script, $command, $script_ref);
    } else {
	return ("Error: First add NM installation(s) to Pirana", "Error: First add NM installation(s) to Pirana", "")
    }
}

sub exec_run_nmfe {
### Purpose : Run a model using the nmfe command
### Compat  : W+L?
    my ($command, $text) = @_;
    status ($text);
    chdir ($cwd);
    system $command;
    status ();
}

sub exec_run_pcluster { # (nm_inst, client)
### Purpose : Run a model on PCluster (using nmfe-method)
### Compat  : W+L-
    my ($command, $jobname, $new_dirs_ref, $files_ref, $text) = @_;
    my @new_dirs = @$new_dirs_ref;
    my @files = @$files_ref;
    status ($text);
    my $i=0;
    foreach (@new_dirs) {
#	pcluster_create_bat_file ($_, $command, @files[$i]);
#	generate_zink_file ($setting{zink_host}, $setting{cluster_drive}, $jobname, 1, win_path($cwd."/".$_), win_path($cwd."/".$_."/".$command));
	generate_zink_file ($setting{zink_host}, $setting{cluster_drive}, $jobname, 1, win_path($cwd."/".$_), $command);
	$i++;
    }
    status ();
}

sub pcluster_create_bat_file {
    my ($dir, $command, $file) = @_;
    $file .= ".".$setting{ext_res};
    open (BAT, ">".$dir."/".$command );
#    print BAT "copy ".$file." ".$file.".tmp1\n";
    my $drive = substr($cwd,0,1);
    print BAT $drive.":\n";
    print BAT "cd ".win_path($cwd."\\".$dir)."\n";
    print BAT "start /b /low nonmem.exe\n";
    print BAT "copy ".$file." + OUTPUT ".$file."\n";
#    print BAT "copy ".$file.".".$setting{ext_res}.".tmp1 + ".$file.".".$setting{ext_res}.".tmp1 ".$file.".".$setting{ext_res}."\n";
#    print BAT "del "$file.".".$setting{ext_res}."_tmp\n";
    print BAT "echo Stop Time: >>".$file."\n";
    print BAT "date /t >>".$file."\n";
    print BAT "time /t >>".$file."\n";
    print BAT "del OUTPUT\n";
    close (BAT);
}

sub exec_run_psn {
    my ($psn_command_line, $ssh_ref, $model, $model_description, $pre, $post) = @_;
    my %ssh = %$ssh_ref;
    status ("Starting run(s) locally using PsN");
    print $pre.$psn_command_line.$post;
    system ($pre.$psn_command_line.$post);
    $psn_command_line =~ s/\'//g;
    db_log_execution ($model, $model_description, "PsN", "local", $psn_command_line, $setting{name_researcher}, "pirana.dir");
    status ();
}

sub update_psn_run_command {
#update one specific parameter in the psn_command line
    my ($command_line_ref, $parameter, $value, $add, $ssh_ref, $clusters_ref) = @_;
    my $command_line = $$command_line_ref; # if not passed as reference, e.g. "Program Files" may be considered as an array
    my @com = split (" ",$command_line);
    my $parameter_found=0;
    my $eq="=";
    my %ssh = %$ssh_ref;
    if ($value eq "") {$eq = ""};
    foreach (@com) {
	if ($_ =~ m/$parameter/g) {
	    $_ = $parameter.$eq.$value; 
	    $parameter_found=1;
	};
    };
    my $psn_command_line;
    if ($parameter_found==0&&$add==1) {
	my $model = pop (@com);
	$psn_command_line = join(" ", @com);
	$psn_command_line .= " ".$parameter.$eq.$value." ".$model;
    } else {
	$psn_command_line = join(" ", @com);
    }
#    my $psn_command = os_specific_path($software{psn_toolkit})."/".$psn_command_line;
    return($psn_command_line);
}

sub build_psn_run_command {
    my ($psn_command, $psn_parameters, $model, $ssh_ref, $clusters_ref, $psn_background) = @_;
    my %ssh = %$ssh_ref;
    my @models = @$model;
    my $model = @models[0];
    foreach (@models) {
	$_ .= '.'.$setting{ext_ctl}
    };
    my $psn_command_line;
    unless ($psn_command eq "custom") {
        $psn_command_line = $psn_command." ".$psn_parameters." ";
    } else {
	$psn_command_line = $psn_parameters." ";
    }
    unless ($psn_command eq "scm") { # usually specified using config file
	if ($sge{sge_default} == 1) {
	    unless ($psn_command_line =~ m/\-run_on_sge/i) {
		$psn_command_line .= "-run_on_sge ";
	    }
	}
	$psn_command_line .= join(" ", @models);
    } else {
	$psn_command_line = update_psn_run_command (\$psn_command_line, "-model", $model.".".$setting{ext_ctl}, 1, %ssh, %clusters);
    }
    if (($psn_command eq "sumo")||($psn_command eq "update_inits")) {
	$psn_command_line .= " ".$outputfile;
    } else {
	$psn_command_line = update_psn_run_command (\$psn_command_line, "-nm_version", "default", 0, \%ssh, \%clusters);
	$psn_command_line .= " ".$modelfile;
    }
#    $psn_command_line = $ssh_add.$psn_command_line.$ssh_add2 ;
#    print $psn_command_line."\n";
    return( $psn_command_line);
}

sub build_ssh_connection {
    my ($ssh_ref, $dir, $setting_ref) = @_;
    my %ssh = %$ssh_ref;
    my %setting = %$setting_ref;
    my $ssh_add; my $ssh_add2;
    # connection using SSH
    if ($ssh{connect_ssh}==1) {
	$ssh_add = $ssh{login}." ";
	if ($ssh{parameters} ne "") {
	    $ssh_add .= $ssh{parameters}.' ';
	}
	$dir =~ s/$ssh{local_folder}//gi;
	unless ($ssh{login} =~ m/(plink|putty)/i) { # plink (PuTTY) doesn't like the quotes
	    $ssh_add .= "'";
	}
	if ($ssh{execute_before} ne "") {
	    $ssh_add .= $ssh{execute_before}."; ";
	}
        $ssh_add .= "cd ".unix_path($ssh{remote_folder}."/".$dir)."; ";
	unless ($ssh{login} =~ m/(plink|putty)/i) {
	    $ssh_add2 = "'";
	}
	my $l = length($dir);
	unless (lcase(substr($dir,0,$l)) eq lcase($setting{cluster_drive})) {
	    message ("Your current working directory is not located on the cluster.\nChange to your cluster-drive or change your preferences.");
	    return();
	}
    }
    return ($ssh_add, $ssh_add2);
}

sub update_psn_background {
    my ($psn_background, $ssh_ref, $dir, $setting_ref) = @_;
    my %ssh = %$ssh_ref;
    my %setting = %$setting_ref;
    my ($text_pre, $text_post);
    if (!($os =~ m/MSWin/ )) {
	if ($psn_background == 0) {
	    if ($setting{terminal} ne "") {
		if (($setting{quit_shell}==0)||($psn_option eq "sumo")) { # don't close terminal window after completion
		    if ($setting{terminal} =~ m/gnome-terminal/) { # for gnome-terminal
			$text_post .= '|less';		   
		    } else { # this works for xterm and maybe some other terminals
			$text_post .= ';read -n1';
		    }
		}
		$text_pre = $setting{terminal}.' -e "';
		$text_post .= '" &';
	    }
	} else {
	    $text_post .= " &";
	}
    } else {
	if (($ssh{connect_ssh}==0)&&($psn_background == 0)) {
	    $text_pre = "start ";
	} 
	if (($ssh{connect_ssh}==0)&&($psn_background == 1)) {
	    $text_pre = "start /b ";
	}
	if (($ssh{connect_ssh}==1)&&($psn_background == 0)) {
	    $text_pre = "start ";
	}
	if (($ssh{connect_ssh}==1)&&($psn_background == 1)) {
	    $text_pre = "start ";
	    $text_post = " &";
	}
    } 
    return ($text_pre, $text_post);
}

sub text_window_nm_help {
### Purpose : Show a window with a text-widget containing the specified text
### Compat  : W+L+
    my ($keywords_ref, $title, $font) = @_;
    my @keywords = @$keywords_ref;
    if ($font eq "" ) {$font = $font_fixed};
    my $doc_loc = $base_dir."/doc/nm/nm_help.sqlite";
    our ($text_window_keywords, $text_window_nm_help);
    unless ($text_window_keywords) {
	our $text_window_keywords = $mw -> Toplevel(-title=>$title);
	$text_window_keywords -> OnDestroy ( sub{
	    undef $text_window_keywords; undef $text_window__keywords_frame;
	});
	no_resize($text_window_keywords);
    }

    my $text_no_help = "The NONMEM helpfiles can be searched with this interface.\n\nThe help files first need to be imported into Pirana. Please go to:\n    Tools --> NONMEM --> Import / update NM help files" ;

    my $text_window_keywords_frame = $text_window_keywords -> Frame(-background=>$bgcol)->grid(-ipadx=>10,-ipady=>10)->grid(-row=>1,-column=>1, -sticky=>'nwse');
    $text_window_keywords_frame -> Label (-text=> "Keyword:", -font=>$font_normal) -> grid(-row=>0, -column=>1, -sticky=>"nw");
    $nm_help_filename = $text_window_keywords_frame -> Label (-text=> "", -font=>$font_bold) -> grid(-row=>0, -column=>3, -sticky=>"nw");
    our $keywords_list = $text_window_keywords_frame -> Scrolled ("Listbox", -scrollbars=>'e',
	-width=>24, -height=>30, -activestyle=> 'none', -exportselection => 0, 
        -relief=>'groove', -border=>2, -selectmode=>'single',
	-selectbackground=>'#CCCCCC', -highlightthickness =>0, -background=>'#ffffff', -font=> $font_normal
    ) -> grid(-column=>1,-row=>1, -columnspan=>2, -sticky=>'nwe');
    my $text_text = $text_window_keywords_frame -> Scrolled ('Text',
        -scrollbars=>'e', -width=>80, -height=>32,
        -background=>"#FFFFFF", -exportselection => 0,
        -relief=>'groove', -border=>2,
        -font=>$font,
        -selectbackground=>'#606060', -highlightthickness =>0
    ) -> grid(-column=>3, -row=>1, -sticky=>'nwes');
    $text_window_keywords_frame -> Button (-text=> "Close", -border=>$bbw, -background=>$button, -activebackground=>$abutton, -font=>$font_normal, -command=> sub{
	$text_window_keywords -> destroy();
    })-> grid (-column=>3, -row=>2, -sticky=>'nes');
    
    if (-s $doc_loc>500000) { # quick check if db seems valid
	my @nm = values (%nm_dirs);
	$keywords_list -> bind('<Button>', sub{
	    my @x_sel = $keywords_list -> curselection;
	    if (@x_sel >0) {
		my $keyword = ($keywords_list -> get (@x_sel[0]));
		my $nm_help_text_ref = get_nm_help_text ($doc_loc, $keyword);
		my $nm_help_text = $$nm_help_text_ref;
		$text_text -> delete("0.0", "end");
		$text_text -> insert("0.0", $nm_help_text);
		$nm_help_filename -> configure (-text => $keyword);
	    } });
	$keywords_list -> bind('<Down>', sub{
	    my @x_sel = $keywords_list -> curselection;
	    if (@x_sel >0) {
		my $keyword = ($keywords_list -> get (@x_sel[0]));
		my $nm_help_text = get_nm_help_text ($doc_loc, $keyword);
		my $nm_help_text = $$nm_help_text_ref;
		$text_text -> delete("0.0", "end");
		$text_text -> insert("0.0", $nm_help_text);
		$nm_help_filename -> configure (-text => $keyword);
	    } });
	$keywords_list->bind('<Up>', sub{
	    my @x_sel = $keywords_list -> curselection;
	    if (@x_sel >0) {
		my $keyword = ($keywords_list -> get (@x_sel[0]));
		my $nm_help_text = get_nm_help_text ($doc_loc, $keyword);
		my $nm_help_text = $$nm_help_text_ref;
		$text_text -> delete("0.0", "end");
		$text_text -> insert("0.0", $nm_help_text);
		$nm_help_filename -> configure (-text => $keyword);
	    } });
	shift (@keywords);
	$keywords_list -> insert(0, @keywords);
	my $nm_help_search_keys = "";
	my $nm_help_entry = $text_window_keywords_frame -> Entry(-width=>12,-textvariable=>\$nm_help_search_keys, -background=>$white,-border=>2, -relief=>'groove' )
	    -> grid(-row=>0,-column=>2,-columnspan=>1, -sticky => 'we',-ipadx=>1);
	$nm_help_entry -> bind('<Any-KeyPress>' => sub {
	    if (length($nm_help_search_keys)>0) {
		$filtered_keywords_ref = nm_help_filter_keywords ($nm_help_search_keys, \@keywords);
		my @filtered_keywords = @$filtered_keywords_ref;
		unless ($text_window_keywords) {
		    text_window_nm_help ( \@filtered_keywords, "NONMEM help files");
		    $keywords_list -> delete(0,"end");
		    $keywords_list -> insert(0, @filtered_keywords);
		} else {
		    $keywords_list -> delete(0,"end");
		    $keywords_list -> insert(0, @filtered_keywords);
		}
	    } 
        });
    } else {
	$text_text -> insert ("end", $text_no_help);
    }
}

sub pcluster_get_available_nodes {
    my @available;
    $i = 0;
    my ($total_cpus_ref, $busy_cpus_ref, $pc_names_ref) = get_active_nodes ($setting{cluster_drive}, \%clients);
    my %total_cpus = %$total_cpus_ref;
    my %busy_cpus = %$busy_cpus_ref;
    my %pc_names = %$pc_names_ref;
    my %clients_status; my %clients_status_text;
    my @clients = keys(%total_cpus);
    my @available;
    my @available_text;
    foreach (@clients) {
	if ($busy_cpus{$_} < $total_cpus{$_}) {$clients_status{$_} = ($total-$runs); $clients_status_text {$_} = ($total_cpus{$_}-$busy_cpus{$_})." of ".$total_cpus{$_}." CPU(s) available" };
	if ($busy_cpus{$_} == $total_cpus{$_}) {$clients_status{$_} = 0; $clients_status_text{$_} = "All busy: ".$busy_cpus{$_}." CPU(s)" };
    }
    foreach (@clients) {
	if (($clients_status{$_} == 0)&&($clients_status_text{$_}) ne "") {
	    push (@available, $_." - ".$pc_names{$_}." - ".$clients_status_text{$_});
	    push (@available_text, $_." - ".$pc_names{$_}." - ".$clients_status_text{$_});
	    # print $_." - ".$clients{$_}." - ".$clients_status_text{$_};
	}
	$i++;
    }
    @available = sort { $a <=> $b } @available;
    return (\@available, \@available_text)
}

sub cluster_report {
### Purpose : Show a messagewindow displaying a message that n runs were successfully copied to cluster
### Compat  : W+L?
    $successfull_comps=@_[0];
    $used_clients = @_[1];
    my $see_comp_log = message_yesno ($successfull_comps." runs were succesfully copied to cluster\nClient(s):\n".$used_clients."\n There were ".$comp_errors." unsuccesful compilations.\n Do you want to view the compilation log?", $mw, $bgcol, $font_normal);
    if ( $see_comp_log == 1) {
	chdir ($base_dir);
	edit_model (unix_path("log\\compilation.txt"));
	chdir ($cwd);
    }
}

sub move_nm_files {
### Purpose : move nonmem files to a new directory for compilation or running in new dir
### Compat  : W+L?
  my ($file, $new_dir) = @_;
  open (ctl,"<".$file);
  @S=<ctl>;
  close ctl;
  ### get csv file(s)) and fortran routines from ctl file.
  foreach $line(@S) {
    #if ($line =~ /IGNORE/) {$data=$line;}
    if ($line =~ /OTHER=/) {$fortran1=$line;}
    if ($line =~ /MSFI/) {$msfi=$line;}
    if (substr($line,0,5) =~ /\$DATA/) {$data=$line;}
    if ($line =~ m/INCLUDE/) {$include=$line; }
  }
  chomp($data); chomp($fortran1); chomp($msfi);
  @data = split (" ", $data);

  @fortran1 = split (" ", $fortran1);
  $fortran2 = pop (@fortran1);
  @fortran2 = split ("=", $fortran2);
  $fortran3 = pop (@fortran2);
  @fortran3 = split (/\./, $fortran3);
  @msfi = split (" ", $msfi);
  @include = split ("=", $include);
  @include_files = split(",", @include[1]);

  mkdir ($new_dir);
  my $new_file = $cwd."/".$new_dir."/".$file;
  unless (copy($cwd."/".$file, $new_file)) {print OUT "Error: Unable to copy control stream.\n"; $error_flag=1;}

  my $up_one = one_dir_up($cwd);
  my $data_file = unix_path(@data[1]);
  $data_file =~ s/\.\./$up_one/;
  my $csv_file = extract_file_name ($data_file);
  if (-e $data_file) {
      unless (copy($data_file, $new_dir."/".$csv_file)) {print OUT "echo Error: Unable to copy dataset. \n"; $error_flag=1;}
      @data[1] = $csv_file;
      push (my @batch, $new_file);
      replace_block (\@batch, '$DATA', join(" ",@data));
  } else {print OUT "echo Error: Unable to find dataset. \n"; $error_flag=1;}

  $for="FOR";
  if (@fortran3[1] =~ $for) {
    copy ($cwd."/".@fortran3[0].".for",$cwd."/".$new_dir."/".@fortran3[0].".for");
    copy ($cwd."/".@fortran3[0].".csv",$cwd."/".$new_dir."/".@fortran3[0].".csv");
  }
  copy ($cwd."/".@fortran3[0].".for",$new_dir."/".@fortran3[0].".for");
  if (@msfi[1]=~MSF) {copy ($cwd."/".@msfi[1],$cwd."/".$new_dir."/".@msfi[1]); }
  # include misc files (such as csv files mentioned in included .for files)

  foreach(@include_files) {
    if (-e $_) {
      copy ($cwd."/".$_, $cwd."/".$new_dir."/".$_);
      # print $_;
    }
  }
  return($new_dir);
}

sub get_nmq_name {
### Purpose : Return the name of an NMQual installation of NONMEM when supplied with the full path
### Compat  : W+L+
  my $dir = shift;
  my @dirs = split (/\\/,win_path($dir));
  my $nmq_name = @dirs[@dirs-1];
  $nmq_name =~ s/\\//g;
  return $nmq_name;
}

sub copy_dir_res {
### Purpose : The dialog window to copy results and tab_files from selected dir ( calls copy_dir_res_function()  )
### Compat  : W+L+
  ($cwd, $dirs_ref) = @_;
  my @dirs = @$dirs_ref;
#x  print @dirs[0]."\n";
  my @lst_all; my @tab_all ; my @tab_all_loc; my @lst_all_loc ;
  my @lst_loc; my @tab_loc;
  foreach my $sub (@dirs) {
    my ($tab_all_ref, $tab_all_loc_ref, $lst_all_ref, $lst_all_loc_ref) = copy_dir_res_function($sub);
    push (@lst_all, @$lst_all_ref);
    push (@lst_all_loc, @$lst_all_loc_ref);
    push (@tab_all, @$tab_all_ref);
    push (@tab_all_loc, @$tab_all_loc_ref);
  }
  chdir ($cwd);
  if ((@lst_all+@tab_all)>0) {
    my $lst_files = join("\n",@lst_all_loc);
    my $tab_files = join("\n",@tab_all_loc);
    our $copy_dir_res_window = $mw -> Toplevel(-title=>'Copy results from directory');;
    no_resize ($copy_dir_res_window);    
    $copy_dir_res_frame = $copy_dir_res_window->Frame(-background=>$bgcol)->grid(-ipadx=>8, -ipady=>8);
    $copy_dir_res_frame -> Label (-text=>"Copy files:",-font=>$font_normal,)->grid(-row=>1, -column=>1, -sticky=>"ne");
    $copy_dir_res_text = $copy_dir_res_frame -> Scrolled ('Text', -font=>$font_normal,-width=>32, -height=>8, -scrollbars=>'e')
      -> grid (-row=>1, -column=>2, -ipady=>5, -columnspan=>2);
    $copy_dir_res_text -> insert ("0.0", $lst_files."\n".$tab_files);
    $copy_dir_res_text -> configure(state=>'disabled');
    $copy_res_to = $cwd;
    $copy_dir_res_frame -> Label (-text=>" ",-font=>$font_normal,)->grid(-row=>2, -column=>1, -sticky=>"ne");
    $copy_dir_res_frame -> Label (-text=>"To folder:",-font=>$font_normal,)->grid(-row=>3, -column=>1, -sticky=>"ne");
    $copy_dir_res_text = $copy_dir_res_frame -> Entry ( -background=>$white, -textvariable => \$copy_res_to, -font=>$font_normal, -width=>32)
      -> grid (-row=>3, -column=>2, -sticky=>'wns', -columnspan=>2);
    $copy_dir_res_frame -> Label (-text=>" ",-font=>$font_normal,)->grid(-row=>4, -column=>1, -sticky=>"ne");
    $copy_dir_res_frame -> Label (-justify=>'left',-text=>"NB: Copying will overwrite existing files\nin the destination folder",-font=>$font_normal,)->grid(-row=>5, -column=>2, -columnspan=>2,-sticky=>"nw");
    $copy_dir_res_frame -> Label (-text=>" ",-font=>$font_normal,)->grid(-row=>6, -column=>1, -sticky=>"ne");

    $copy_dir_res_frame -> Button (-text=>"Copy", -width=>10, -background=>$button, -border=>$bbw, -activebackground=>$abutton, -command=> sub {
      $i = 0;
      my $to_dir = $copy_dir_res_text -> get();
      foreach (@lst_all) {
        if ($_ ne "") {
          copy ($cwd."/".@lst_all_loc[$i], $to_dir."/".@lst_all[$i]);
#          print $cwd."/".@lst_all_loc[$i]." ".$to_dir."/".@lst_all[$i]."\n";
        }
        $i++;
      }
      $i = 0;
      foreach (@tab_all) {
        if ($_ ne "") {
          copy ($cwd."/".@tab_all_loc[$i], $to_dir."/".@tab_all[$i]);
#          print $cwd."/".@tab_all_loc[$i].$to_dir."/".@tab_all[$i]."\n";
        }
        $i++;
      }
      $copy_dir_res_window -> destroy;
      read_curr_dir($cwd, $filter, 1);
      return();
    })->grid(-row=>7,-column=>3,-sticky=>'nwse');
    $copy_dir_res_frame -> Button (-text=>"Cancel", -width=>10, -background=>$button, -border=>$bbw, -activebackground=>$abutton, -command=> sub {
      $copy_dir_res_window -> destroy;
      return();
    })->grid(-row=>7,-column=>2,-sticky=>'nwse');
  } else {message ("No result or \$TABLE files were found in this directory.")}
  center_window($copy_dir_res_window, $setting{center_window}); # center after adding frame (redhat)
}

sub copy_dir_res_function {
### Purpose : The function to copy results and tab_files from selected dir
### Compat  : W+
  $sub = shift;
  my @lst; my @tab;
  my @lst_all; my @tab_all;
  my @tab_all_loc; my @lst_all_loc;
  my @lst_loc;  my @tab_loc;
  if (-d $sub) {
    chdir ($sub);
    my @all = <*>;
    foreach(@all) {
	my $tab_flag = 0;
	if ($_ =~ m/\.$setting{ext_res}/i) {push(@lst, $_); push (@lst_loc, $sub."/".$_)}
	if ($_ =~ m/\.$setting{ext_tab}/i) {push(@tab, $_); push (@tab_loc, $sub."/".$_); $tab_flag=1}
	if (($_ =~ m/.tab./i)&&($tab_flag==0)) {push(@tab, $_); push (@tab_loc, $sub."/".$_); $tab_flag=1}
	if ($_ =~ m/\.cor/i) {push(@tab, $_); push (@tab_loc, $sub."/".$_); }
	if ($_ =~ m/\.coi/i) {push(@tab, $_); push (@tab_loc, $sub."/".$_); }
	if ($_ =~ m/\.cov/i) {push(@tab, $_); push (@tab_loc, $sub."/".$_); }
	if ($_ =~ m/\.ext/i) {push(@tab, $_); push (@tab_loc, $sub."/".$_); }
	if ($_ =~ m/\.phi/i) {push(@tab, $_); push (@tab_loc, $sub."/".$_); }
    };
    push (@lst_all, @lst);
    push (@tab_all, @tab);
    push (@lst_all_loc, @lst_loc);
    push (@tab_all_loc, @tab_loc);
    chdir ("..");
  }
  return (\@tab_all, \@tab_all_loc, \@lst_all, \@lst_all_loc);
}

sub frame_tab_show {
### Purpose : Construct the frame showing the table/csv files
### Compat  : W+L+
  if (@_[0]==1) {
  our $summary1, $summary2, $dvvspred, $wresvspred, $other;
  our $show_res = "all_output";

 # result files

  if ($make_listbox eq "yes") {
    if($res_listbox)  {$res_listbox->gridForget()};
    if($res_scrollbar) {$res_scrollbar->gridForget()};
    if (@res_files_ofv > $nrows) {$cspan_res = 2} else {$cspan_res = 2};
    $tab_frame -> Label(-text=>"    ") -> grid(-row=>4,-column=>4);
    our $res_listbox = $frame2 -> Listbox(-border=>2, -relief=>'groove',-activestyle=> 'none',-selectmode=>'extended',-height=>$nrows,-width=>20,
      -background=>'#FFFFFF',-selectbackground=>'#606060', -foreground=>"#000000", -selectforeground=>"#FFFFFF", -font=>$font_normal, -highlightthickness=>0)
      -> grid(-row=>4,-column=>2, -columnspan=>$cspan_res, -sticky => 'w');
    $res_listbox -> insert(0, @res_files_ofv);

    $help->attach($res_listbox, -msg => "Output files\n  ()=objective function value\n  s=minimization successful\n  c=covariance step successful\n  b=boundaries");
    #$res_listbox->activate(0);
    $res_listbox->bind('<Button>', sub{
      $res_listbox->focus;
    });
    $res_listbox->bind('<Return>', sub{
      if ($models_hlist -> selectionGet > 0) {
        edit_model (unix_path(@res_files_loc_copy[$models_hlist -> selectionGet]));
        $res_listbox->focus;
      }
    });
    $res_listbox->bind('<Down>', sub{
      ($res_idx, $rest)  = $models_hlist -> selectionGet;
      $res_size = $res_listbox->size;
      if ($res_idx < $res_size) {
        $res_listbox->selectionClear(0,100);
        $res_listbox->selectionSet($res_idx+1,$res_idx+1);
        $res_listbox->activate($res_idx+1);
      }
    });
    $res_listbox->bind('<Up>', sub{
      ($res_idx, $rest)  = $models_hlist -> selectionGet;
      if ($res_idx>0) {
        $res_listbox->selectionClear(0,100);
        $res_listbox->selectionSet($res_idx-1,$res_idx-1);
        $res_listbox->activate($res_idx-1);
      }
    });
  }
  
  #table file listbox
  #our $tab_hlist_color = "#f5FAFF";
 # our $tab_frame = $mw -> Frame(-background=>"#000000", -padx=>0, -pady=>0
 #  ) ->grid(-row=>3, -column=>3, -columnspan=>1, -rowspan=>1, -ipadx=>0,-ipady=>0,-sticky=>'wnse');
  our $tab_hlist = $mw -> Scrolled('HList',
        -head       => 0,
        -selectmode => "extended",
        -highlightthickness => 0,
	-selectborderwidth => 0,
        -columns    => 1, # int(@models_hlist_headers),
        -scrollbars => 'se',
        -width      => 20,
        -height     => $nrows+4,
        -border     => 1,
   #     -pady       => $hlist_pady,
   #     -padx       => 0,
        -background => $tab_hlist_color,
        -selectbackground => $pirana_orange,
        -font       => $font_normal,
        -command    => sub {
           my $tabsel = $tab_hlist -> selectionGet ();
           my $tab_file = os_specific_path(@tabcsv_loc[@$tabsel[0]]);
#           if (($tab_file ne "")&&(-e $tab_file)) {
#	         edit_model(unix_path($tab_file));
#           }
	   if ($^O =~ m/MSWin/i) {
	       system ($tab_file);
	   }
	   if ($^O =~ m/darwin/i) {
	       system ("open ".$tab_file);
	   }
	   if ($^O =~ m/linux/i) {
	       system ($setting{xdg_open}." ".$tab_file);
	   }
        },
        -browsecmd   => sub{
            my $tabsel = $tab_hlist -> selectionGet ();
            my $tab_file = win_path(@tabcsv_files[@$tabsel[0]]);
            my $mod_time;
            if (-e $cwd."/".$tab_file) {$mod_time = localtime(@{stat $cwd."/".$tab_file}[9])};
            my $note = $table_note{$tab_file};
            $note =~ s/\n/ /g;
	    my $update_text = (-s $tab_file)." kB\n";
	    $update_text .= substr($mod_time,4)."\n";
	    $update_text .= $note;
            update_text_box(\$tab_file_info, $update_text);
#            update_text_box(\$tab_file_info, (-s $tab_file)." kB");
#            update_text_box(\$tab_file_mod, $mod_time);
        }
      )->grid(-column => 3, -columnspan=>2, -row => 3, -rowspan=>1, -sticky=>'nswe', -ipadx=>0, -ipady=>0);
    $help->attach($tab_hlist, -msg => "Data files\n*\\ = in alternate directory");
    my @tab_menu_enabled = qw(normal normal normal normal disabled normal normal disabled normal disabled normal);
    bind_tab_menu(\@tab_menu_enabled);
  
  our $show_data="tab";

  $tab_frame_info = $mw -> Frame(-background=>$bgcol, -padx=>0,-pady=>0
   )->grid(-row=>4, -column=>3, -rowspan=>1, -columnspan=>1, -ipady=>0,-sticky=>"nwse");
  my $width = 24; if ($^O =~ m/(darwin)/i) {$width = 21};
  our $tab_file_info = $tab_frame_info -> Text (
      -width=>$width, -relief=>'groove', -border=>2, -height=>5,
      -font=>$font_small, -background=>$entry_color, -state=>'disabled'
      )->grid(-column=>1, -row=>1, -sticky=>'nwes', -rowspan=>2, -ipadx=>0, -ipady=>0);
  our $edit_tab_info_button = $tab_frame_info -> Button(-image=>$gif{edit_info_green}, -border=>$bbw, -background=>$button,-activebackground=>$abutton, -width=>22, -height=>22, -command=> sub{
       my $tabsel = $tab_hlist -> selectionGet ();
       my $tab_file = unix_path(@tabcsv_files[@$tabsel[0]]);
       if (-e $tab_file) {
   	  table_info_window($tab_file);
       }
  })->grid(-column=>2,-row=>1, -sticky => 'wen');
  $help->attach($edit_tab_info_button, -msg => "File properties");
  $show_ofv=0;
  $show_successful=0;
  $show_covar=0;
  }
}

sub tab_browse_entry_update {
    my $selected_file = shift;
    tab_dir($cwd);
    populate_tab_hlist($tab_hlist);
    my @tab_menu_enabled = qw(normal normal disabled normal disabled disabled disabled disabled normal normal disabled);
    if($selected_file eq "tab") {@tab_menu_enabled = qw(normal normal normal normal normal normal normal disabled normal disabled normal)};
    if($selected_file eq "dta") {@tab_menu_enabled = qw(normal normal normal normal normal normal normal disabled normal disabled normal)};
    if($selected_file eq "csv") {@tab_menu_enabled = qw(normal normal normal normal normal normal normal disabled normal disabled normal)};
    if($selected_file eq "xpose") {@tab_menu_enabled = qw(disabled disabled disabled disabled disabled normal disabled disabled normal disabled disabled)};
    if($selected_file eq "R") {@tab_menu_enabled = qw(disabled normal disabled normal disabled normal disabled disabled normal disabled disabled)};
    if($selected_file eq "*") {@tab_menu_enabled = qw(normal normal disabled normal disabled disabled normal disabled normal normal disabled)};
    bind_tab_menu(\@tab_menu_enabled);
}

sub bind_models_menu {
  my $models_menu = $models_hlist -> Menu(-tearoff => 0, -background=>$bgcol, -title=>'None');
  if ($setting{use_nmfe}==1) {
      my @mod_menu_enabled = @$mod_menu_enabled_ref;
      $models_menu -> command (-label=> " Run (nmfe)", -font=>$font, -compound => 'left',-image=>$gif{run}, -background=>$bgcol, -command => sub{
	  nmfe_command();
      });
  }
  my $models_menu_psn;
  if ($setting{use_psn}==1) {
    $models_menu_psn = $models_menu -> cascade (-label=>" PsN", -font=>$font,-compound => 'left',-image=>$gif{psn_logo}, -background=>$bgcol, -tearoff=>0);
    $models_menu_psn -> command (-label=> " execute",-font=>$font, -compound => 'left',-image=>$gif{run}, -background=>$bgcol, -command => sub{
       psn_command("execute");
    });
    $models_menu_psn -> command (-label=> " vpc",-font=>$font, -compound => 'left',-image=>$gif{run}, -background=>$bgcol, -command => sub{
       psn_command("vpc");
    });
    $models_menu_psn -> command (-label=> " npc", -font=>$font,-compound => 'left',-image=>$gif{run}, -background=>$bgcol, -command => sub{
       psn_command("npc");
    });
    $models_menu_psn -> command (-label=> " bootstrap",-font=>$font, -compound => 'left',-image=>$gif{run}, -background=>$bgcol, -command => sub{
       psn_command("bootstrap");
    });
    $models_menu_psn -> command (-label=> " cdd", -font=>$font,-compound => 'left',-image=>$gif{run}, -background=>$bgcol, -command => sub{
       psn_command("cdd");
    });
    $models_menu_psn -> command (-label=> " llp",-font=>$font, -compound => 'left',-image=>$gif{run}, -background=>$bgcol, -command => sub{
       psn_command("llp");
    });
    $models_menu_psn -> command (-label=> " sse",-font=>$font, -compound => 'left',-image=>$gif{run}, -background=>$bgcol, -command => sub{
       psn_command("sse");
    });
    $models_menu_psn -> command (-label=> " mcmp",-font=>$font, -compound => 'left',-image=>$gif{run}, -background=>$bgcol, -command => sub{
       psn_command("mcmp");
    });
    $models_menu_psn -> command (-label=> " scm",-font=>$font, -compound => 'left',-image=>$gif{run}, -background=>$bgcol, -command => sub{
       psn_command("scm");
    });
    $models_menu_psn -> command (-label=> " custom...",-font=>$font, -compound => 'left',-image=>$gif{run}, -background=>$bgcol, -command => sub{
       psn_command("custom");
    });
    $models_menu_psn -> command (-label=> " sumo", -font=>$font,-compound => 'left',-image=>$gif{edit_info}, -background=>$bgcol, -command => sub{
       psn_command("sumo");
    });
    $models_menu_psn -> command (-label=> " update_inits", -font=>$font,-compound => 'left',-image=>$gif{msf}, -background=>$bgcol, -command => sub{
       psn_command("update_inits");
    });
  }
  my $models_menu_wfn;
  if ($setting{use_wfn}==1) {
    if ($os =~ m/MSWin/i) {
      $models_menu_wfn = $models_menu -> cascade (-label=> " WFN", -font=>$font,-compound => 'left',-image=>$gif{run}, -background=>$bgcol, -tearoff=>0);
      $models_menu_wfn -> command (-label=> " nmgo", -font=>$font,-compound => 'left',-image=>$gif{run}, -background=>$bgcol, -command => sub{
           wfn_command("NMGO");
         });
      $models_menu_wfn -> command (-label=> " nmbs", -font=>$font,-compound => 'left',-image=>$gif{run}, -background=>$bgcol, -command => sub{
           wfn_command("NMBS");
         });
    }
  }
    $models_menu -> separator (-background=>$bgcol) ;
    $models_menu -> command (-label=>" Model properties...",-font=>$font,-compound => 'left',-image=>$gif{edit_info}, -background=>$bgcol, -command => sub{
           properties_command ();
         });
    my $models_menu_misc = $models_menu -> cascade (-label=> " Model actions", -font=>$font,-compound => 'left',-image=>$gif{rename}, -background=>$bgcol, -tearoff=>0);
    $models_menu_misc -> command (-label=>" Edit model", -font=>$font,-image=>$gif{notepad}, -compound=>'left',  -background=>$bgcol, -command => sub{
           edit_model_command();
         });
     $models_menu_misc -> command (-label=> " Rename model", -font=>$font, -image=>$gif{rename}, -compound=>'left', -background=>$bgcol, -command => sub{
           rename_model_command();
         });
    $models_menu_misc -> command (-label=> " Duplicate model",-font=>$font, -image=>$gif{duplicate}, -compound=>'left', -background=>$bgcol, -command => sub{
           duplicate_model_command();
         });
    $models_menu_misc -> command (-label=> " Duplicate model for MSF restart", -font=>$font, -image=>$gif{msf}, -compound=>'left', -background=>$bgcol, -command => sub{
           duplicate_msf_command();
          });
    $models_menu_des = $models_menu -> cascade (-label=> " Translate \$DES", -font=>$font, -image=>$gif{desolve}, -compound=>'left', -background=>$bgcol, -tearoff=>0);
    $models_menu_des -> command (-label=> " To R", -font=>$font, -background=>$bgcol, -command => sub{
           translate_des_command("R");
          });
    $models_menu_des -> command (-label=> " To Berkely Madonna", -font=>$font, -background=>$bgcol, -command => sub{
           translate_des_command("BM");
          });
    $models_menu -> command (-label=> " Delete model(s) / result(s)", -font=>$font, -image=>$gif{trash}, -compound=>'left', -background=>$bgcol, -command => sub{
           delete_models_command();
         });
    $models_menu -> command (-label=> " Copy results from folder", -image=>$gif{folderout}, -compound=>'left', -font=>$font, -background=>$bgcol, -command=>sub{
           copy_results_from_folder_command();
         });
    $models_menu -> separator ( -background=>$bgcol) ;

  if($use_scripts == 1) { # possibility to be switched off, since unstable on Mac (memory issue)
    my $models_menu_scripts = create_scripts_menu ($models_menu, "r", 1, $base_dir."/scripts", " Run script", 0);
    create_scripts_menu ($models_menu_scripts, "", 1, $home_dir."/scripts", "My scripts");

    my $edit_script_text = " Output script to R GUI";
    my $icon = "r";
    if ($software{r_gui} =~ m/rstudio/i) {
	$icon = "rgui";
    }
    my $models_menu_scripts = create_scripts_menu ($models_menu, $icon, 1, $base_dir."/scripts", $edit_script_text, 2);
    create_scripts_menu ($models_menu_scripts, "", 1, $home_dir."/scripts", "My scripts");
  }

  my $models_menu_reports = $models_menu -> cascade (-label=>" Reports", -font=>$font,-compound => 'left',-image=>$gif{notepad}, -background=>$bgcol, -tearoff=>0);
  $models_menu_reports -> command (-label=> " Generate HTML report(s)", -image=>$gif{HTML}, -font=>$font,-compound=>'left', -background=>$bgcol, -command => sub{
      generate_report_command(\%run_reports);
  });

  $models_menu_reports -> command (-label=> " LaTeX tables of parameter estimates", -image=>$gif{latex},-font=>$font, -compound=>'left', -background=>$bgcol, -command => sub{
      generate_LaTeX_command(\%run_reports);
  });
  $models_menu_reports -> command (-label=> " View NM output file",  -image=>$gif{notepad},-font=>$font, -compound=>'left', -background=>$bgcol, -command => sub{
      view_outputfile_command();
  });

    $models_menu -> separator ( -background=>$bgcol) ;
    $models_menu -> command (-label=> " Close this menu", -font=>$font, -image=>$gif{close},-font=>$font, -compound=>'left', -background=>$bgcol, -command => sub{
       $models_menu -> unpost();
    });
  $models_hlist -> bind("<Button-3>" => [ sub {
      $models_hlist -> focus;
      my($w, $x, $y) = @_;
      our $modsel = $models_hlist -> selectionGet ();
      if ((@$modsel >0)&&($models_menu)) { $models_menu -> post($x, $y) } else {
	  message("Please select a model to show options...");
      }
   }, Ev('X'), Ev('Y') ] );
}

sub bind_tab_menu {
  my $tab_menu_enabled_ref = shift;
  my @tab_menu_enabled = @$tab_menu_enabled_ref;
  my $icon = "r";
  if ($software{r_gui} =~ m/rstudio/i) {
      $icon = "rgui";
  }
  our $tab_menu = $tab_hlist -> Menu(-tearoff => 0,-title=>'None', -background=>$bgcol, -menuitems=> [
        [Button => " Open in DataInspector", -background=>$bgcol,-font=>$font_normal,  -image=>$gif{plots}, -compound=>"left", -state=>@tab_menu_enabled[6], -command => sub{
           my $tabsel = $tab_hlist -> selectionGet ();
           my $tab_file = unix_path(@tabcsv_loc[@$tabsel[0]]);
           if (-e $tab_file) {
	       my $fsize = (-s $tab_file);
	       my $open_bool = 1;
	       if ($fsize > 5000000 ) { # if larger than 5 MB ask
	          $open_bool = message_yesno ($tab_file." is quite large (".rnd(($fsize/(1024*1024)),1)." Mb)\nAre you sure you want to open this file?\n(DataInspector may become really slow...)", $mw, $bgcol, $font_normal);
	       }
	       if ($open_bool == 1 ) {
		   unless($show_data eq "xpose") {create_plot_window($mw, $tab_file, $show_data, \%software, \%gif );}
	       }
	   }
        }],
       [Button => " Open in spreadsheet", -background=>$bgcol, -font=>$font_normal, -image=>$gif{spreadsheet},-compound=>"left", -state=>@tab_menu_enabled[0],-command => sub{
         if ((-e $software{spreadsheet})||($^O =~ m/darwin/i)) {
	     my $tabsel = $tab_hlist -> selectionGet ();
	     my $tab_file = unix_path(@tabcsv_loc[@$tabsel[0]]);
	     if ($^O =~ m/MSWin/i) {
		 $tab_file = win_path(@tabcsv_loc[@$tabsel[0]]);
	     }
	     if (($^O =~ m/MSWin/i)&&($tab_file =~ m/.$setting{ext_tab}/i)&&($software{spreadsheet} =~ m/(excel|gnumeric)/i)) {  # Excel / gnumeric on Windows is not able to read the table files correctly
		 tab2csv ($tab_file, $tab_file."_pirana.".$setting{ext_csv});
		 start_command($software{spreadsheet}, '"'.$tab_file.'_pirana.'.$setting{ext_csv}.'"');
	     } else {
		 start_command($software{spreadsheet}, '"'.unix_path($tab_file).'"');
 	     }
         } else {message("Spreadsheet application not found. Please check settings.")};
       }],
       [Button => "  Open in RGUI", -background=>$bgcol,-font=>$font_normal,  -image=>$gif{$icon},-compound=>"left", -state=>@tab_menu_enabled[5], -command => sub{
	   my $scriptsel = $tab_hlist -> selectionGet ();
	   my $script_file = unix_path(@tabcsv_loc[@$scriptsel[0]]);   
	   my $r_gui_command = get_R_gui_command (\%software);
	   my $r_script;
	   my $script;
	   unless (-d "pirana_temp") {mkdir "pirana_temp";}
	   if ($r_gui_command ne "") {
	       if ($show_data eq "R") {
		   $r_script = $script_file;
	       }
	       if ($show_data eq "csv") {   
		   $script .= "setwd('".unix_path($cwd)."')\n";
		   $script .= "csv <- data.frame(read.csv (file='".unix_path($cwd."/".$script_file)."'))\n";
		   $script .= "head(csv)\n";
		   $r_script = "pirana_temp/tmp_" . generate_random_string(5) . "\.R";
		   text_to_file (\$script, $r_script);
	       }
	       if ($show_data eq "tab") {
		   open (DATA, "<".$script_file);
		   my @dat = <DATA>;
		   close DATA;
		   $script .= "setwd('".unix_path($cwd)."')\n";
		   if (@dat[0] =~ m/TABLE.NO/) {
		       $script .= "tab <- data.frame(read.table (file='".unix_path($script_file)."',\n\t\t skip=1, header=T))\n";
		   } else {
		       $script .= "tab <- data.frame(read.table (file='".unix_path($script_file)."',\n\t\t skip=0, header=F))\n";
		   };
		   $script .= "head(tab)\n";
		   $r_script = "pirana_temp/tmp_" . generate_random_string(5) . "\.R";
		   text_to_file (\$script, $r_script);
	       }
	       if ($show_data eq "xpose") {
		   my $xpdb = @tabcsv_files[@$scriptsel[0]];
		   $script .= "setwd('".unix_path($cwd)."')\n";
		   $script .= "# Load Xpose from Pirana\n".
		       "library(grDevices) \nlibrary(utils) \nlibrary(xpose4)\n".
		       "new.runno <- '".$xpdb."' \n".
		       "newdb <- xpose.data(new.runno)\n".
		       "if (is.null(newdb)) {\n".
		       "    cat('No new database read')\n".
		       "    return()\n".
		       "} else {\n".
		       "    newnam <- paste('xpdb', new.runno, sep = '')\n".
		       "    assign(pos = 1, newnam, newdb)\n".
		       "    assign(pos = 1, '.cur.db', newdb)\n".
		       "}\n".
		       "main.menu()";
		   $r_script = "pirana_temp/tmp_" . generate_random_string(5) . "\.R";
		   text_to_file (\$script, $r_script);
	       }
	       if ($r_gui_command =~ m/rgui/i) { # good old RGUI is used. do workaround to load file
		   my $text = 'utils::file.edit("'.$r_script.'")'."\n";
		   text_to_file (\$text, ".Rprofile");
		   $r_script = "";
	       }
	       start_command($r_gui_command, $r_script);
	   }
	}],
       [Button => " Open in code editor",  -background=>$bgcol,-font=>$font_normal, -image=>$gif{notepad},-compound=>"left", -state=>@tab_menu_enabled[1], -command => sub{
	   my $tabsel = $tab_hlist -> selectionGet ();
	   my $tab_file = unix_path(@tabcsv_loc[@$tabsel[0]]);
	   if ($^O =~ m/MSWin/i) {
	       $tab_file = win_path(@tabcsv_loc[@$tabsel[0]]);
	   }
	   edit_model(unix_path(win_path($tab_file)));
       }],
      [Button => " Open in PDF Reader", -background=>$bgcol, -font=>$font_normal, -image=>$gif{pdf_viewer}, -compound=>"left", , -state=>@tab_menu_enabled[9], -command => sub{
         if ((-e $software{pdf_viewer})||$^O =~ m/darwin/i) {
             my $tabsel = $tab_hlist -> selectionGet ();
             my $pdf_file = unix_path(@tabcsv_loc[@$tabsel[0]]);
             if ($^O =~ m/MSWin/i) {
                 $tab_file = win_path(@tabcsv_loc[@$tabsel[0]]);
                 } else {
                 $tab_file = unix_path(@tabcsv_loc[@$tabsel[0]]);
             }
             start_command($software{pdf_viewer}, '"'.$tab_file.'"');
          } else {
            message("PDF Viewer application not found. Please check settings.")
          };
       }]
				     ]);
 
  my $psn_data_menu = $tab_menu -> Cascade (-label => " PsN data functions", -background=>$bgcol, -font=>$font_normal, -image=>$gif{psn_logo}, -compound=>"left", -tearoff=>0 , -state=> @tab_menu_enabled[10]);
  my @psn_data_commands = qw/data_stats create_subsets create_cont_data unwrap_data single_valued_columns/;
  foreach my $psn_command (@psn_data_commands) {
      $psn_data_menu -> command (
	  -label => $psn_command, -background=>$bgcol, -font=>$font_normal, -command => sub {
	      my $tabsel = $tab_hlist -> selectionGet ();
	      my $tab_file = unix_path(@tabcsv_loc[@$tabsel[0]]);
#	      run_command($psn_command . " " . $tab_file);
	      psn_run_window ($tab_file, $psn_command, 1);
	  });
  }

  $tab_menu -> Button (
      -label => " Convert CSV <--> TAB",  -background=>$bgcol,-font=>$font_normal, -image=>$gif{convert},-compound=>"left", -state=>@tab_menu_enabled[2],-command => sub{
	  my $tabsel = $tab_hlist -> selectionGet ();
	  my $tab_file = unix_path(@tabcsv_loc[@$tabsel[0]]);
	  if ($^O =~ m/MSWin/i) {
	      $tab_file = win_path(@tabcsv_loc[@$tabsel[0]]);
	  }
	  csv_tab_window ($tab_file);
      }
      );
  $tab_menu -> Button (
      -label => " Delete file",  -background=>$bgcol,-font=>$font_normal, -image=>$gif{trash},-compound=>"left", -state=>@tab_menu_enabled[3], -command => sub{
	  my $tabsel = $tab_hlist -> selectionGet ();
	  my $tab_file = unix_path(@tabcsv_loc[@$tabsel[0]]);
	  my $tab_id = @tabcsv_files[@$tabsel[0]];
	  if ($^O =~ m/MSWin/i) {
	      $tab_file = win_path(@tabcsv_loc[@$tabsel[0]]);
	  }
	   my $delete = message_yesno ( "Do you really want to delete ".$tab_file."?", $mw, $bgcol, $font_normal);
	  if( $delete ==1 ) {
	      unless( unlink ( os_specific_path ($tab_file) )) {
		  message("For some reason, ".$tab_id." could not be deleted.\nCheck file/folder permissions.");
	      } else {
		  db_remove_table_info ($tab_id, "pirana.dir");
		  refresh_pirana($cwd, $filter,1)
	      }
	  };
      });
  $tab_menu -> Button (-label => " Check dataset", -background=>$bgcol, -font=>$font_normal, -image=>$gif{check},-compound=>"left", -state=>@tab_menu_enabled[4], -command => sub{
	   my $tabsel = $tab_hlist -> selectionGet ();
	   my $tab_file = unix_path(@tabcsv_loc[@$tabsel[0]]);
	   my $html = check_out_dataset($tab_file);
	   start_command ($software{browser}, '"file:///'.unix_path($cwd).'/'.$html.'"');
		       });
### Functionality removed temporarily, due to problems with Statistics::R
#        [Button => " Load in PiranaR", -background=>$bgcol,-font=>$font_normal,  -image=>$gif{pirana_r},-compound=>"left", -state=>@tab_menu_enabled[5], -command => sub{
# 	   my $scriptsel = $tab_hlist -> selectionGet ();
# 	   my $script_file = unix_path(@tabcsv_loc[@$scriptsel[0]]);
# 	   if (-e $script_file) {
# 	       if ($show_data eq "R") {
# #		   open ()
# 	       }
# 	       if ($show_data eq "csv") {
# 		   my $script = "library(utils)\n".
# 				"csv <- data.frame(read.csv (file='".unix_path($cwd."/".$script_file)."'))\n";
# 		   $script .= "head(tab)\n";
# 		   create_window_piranaR ($mw, $script, 1, "temp");
# 	       }
# 	       if ($show_data eq "tab") {
# 		   open (DATA, "<".$script_file);
# 		   my @dat = <DATA>;
# 		   close DATA;
# 		   my $script = "library(utils)\n";
# 		   if (@dat[0] =~ m/TABLE.NO/) {
# 		       $script .= "tab <- data.frame(read.table (file='".unix_path($script_file)."', skip=1, header=T))\n";
# 		   } else {
# 		       $script .= "tab <- data.frame(read.table (file='".unix_path($script_file)."', skip=0, header=F))\n";
# 		   };
# 		   $script .= "head(tab)\n";
# 		   create_window_piranaR ($mw, $script, 1);
# 	       }
# 	   }
#         }],
        # [Button => " Show/edit table or file info", -background=>$bgcol, -font=>$font_normal, -image=>$gif{edit_info_green},-compound=>"left", -state=>@tab_menu_enabled[8],-command => sub{
	#     my $tabsel = $tab_hlist -> selectionGet ();
	#     my $tab_file = unix_path(@tabcsv_files[@$tabsel[0]]);
	#     if (-e $tab_file) {
	# 	table_info_window($tab_file);
	#     }
        # }],
    $tab_menu -> separator ( -background=>$bgcol) ;
    $tab_menu -> command (-label=> " Close this menu", -font=>$font, -image=>$gif{close}, -compound=>'left', -background=>$bgcol, -command => sub{
       $tab_menu -> unpost();
    });

    # tab menu when no file is selected
    our $tab_menu_no_sel = $tab_hlist -> Menu(-tearoff => 0,-title=>'None', -background=>$bgcol);
    $tab_menu_no_sel -> command (-label=> " Create new file..", -background=>$bgcol,-font=>$font_normal,  -image=>$gif{new}, -compound=>"left", -command => sub{
	new_data_file_window ($show_data);
    });
    $tab_menu_no_sel -> separator ( -background=>$bgcol) ;
    $tab_menu_no_sel -> command (-label=> " Close this menu", -font=>$font, -image=>$gif{close}, -compound=>'left', -background=>$bgcol, -command => sub{
       $tab_menu_no_sel -> unpost();
    });

    # bind to right mouse button
    $tab_hlist -> bind("<Delete>" => [ sub {
	   my $tabsel = $tab_hlist -> selectionGet ();
	   my $tab_file = unix_path(@tabcsv_loc[@$tabsel[0]]);
	   my $tab_id = @tabcsv_files[@$tabsel[0]];
	   if ($^O =~ m/MSWin/i) {
	       $tab_file = win_path(@tabcsv_loc[@$tabsel[0]]);
	   }
	   my $delete = message_yesno ( "Do you really want to delete ".$tab_file."?", $mw, $bgcol, $font_normal);
	   if( $delete ==1 ) {
	       unless( unlink ( os_specific_path ($tab_file) )) {
		   message("For some reason, ".$tab_id." could not be deleted.\nCheck file/folder permissions.");
	       } else {
		   db_remove_table_info ($tab_id, "pirana.dir");
		   refresh_pirana($cwd, $filter,1)
	       }
	   };
       } ]);

    $tab_hlist -> bind("<Button-3>" => [ sub {
       $tab_hlist -> focus; # focus on listbox widget
       my($w, $x, $y) = @_;
       our $tabsel = $tab_hlist -> selectionGet ();
       if (@$tabsel >0) {
	   $tab_menu -> post($x, $y)
       } else {
	   $tab_menu_no_sel -> post($x, $y)
#         message("Please select a file first...");
       }
    }, Ev('X'), Ev('Y') ] );
}

sub new_data_file_window {
### Purpose : Create a new data file
### Compat  : W+L+
    my $type = shift;
    my $overwrite_bool=1;
    my $new_datfile_name = "untitled";
    if ($type eq "tab") { $new_datfile_name .= ".tab" }
    if ($type eq "csv") { $new_datfile_name .= ".csv" }
    if ($type eq "xpose") { $new_datfile_name .= ".tab" }
    if ($type eq "R") { $new_datfile_name .= ".R" }
    if ($type eq "*") { $new_datfile_name .= ".txt" }
    $newdatfile_dialog = $mw -> Toplevel(-title=>'New folder');
    no_resize ($newdatfile_dialog);    
    $newdatfile_dialog_frame = $newdatfile_dialog-> Frame(-background=>$bgcol)->grid(-ipadx=>'10',-ipady=>'10',-sticky=>'n');
    $newdatfile_dialog_frame -> Label (-text=>"File name: \n", -font=>$font)->grid(-column=>1,-row=>1,-sticky=>"ne");
    $newdatfile_dialog_frame -> Entry ( -background=>$white, -width=>20, -border=>2, -relief=>'groove', -textvariable=>\$new_datfile_name)->grid(-column=>2,-row=>1,-sticky=>"ne");
    $newdatfile_dialog_frame -> Button (-text=>'Create file', -font=>$font,  -width=>12, -border=>$bbw, -background=>$button,-activebackground=>$abutton, -command=>sub{
	if (-e $cwd."/".$new_datfile_name.".".$setting{ext_ctl}) {  # check if control stream already exists;
	    $overwrite_bool = message_yesno ("File ".$new_ctl_name.".".$setting{ext_ctl}." already exists.\n Do you want to overwrite?", $mw, $bgcol, $font_normal);
	}
	if ($new_datfile_name eq "") {
	    message ("Please specify a valid model name.");
	    $overwrite_bool = 0;
	}
	if ($overwrite_bool == 1) {
	    open (DAT, ">".$cwd."/".$new_datfile_name);
	    close (DAT);
	    edit_model (unix_path($cwd."/".$new_datfile_name));
	}
	refresh_pirana($cwd);
	destroy $newdatfile_dialog;
    })->grid(-column=>2,-row=>2,-sticky=>"w");
    $newdatfile_dialog_frame -> Button (-text=>'Cancel', -font=>$font, -width=>12, -border=>$bbw,-background=>$button,-activebackground=>$abutton,-command=>sub{
        destroy $newdatfile_dialog;
    })->grid(-column=>1,-row=>2,-sticky=>"e");
    center_window($newdatfile_dialog, $setting{center_window}); # center after adding frame (redhat)
}

sub nm_help_filter_keywords {
    my ($search, $keywords_ref) = @_;
    my @keywords = @$keywords_ref;
    my @keywords2;
    foreach my $keyword (@keywords) {
	if ($keyword =~ m/$search/i) {
	    push (@keywords2, $keyword);
	}
    }
    return (\@keywords2);
}

sub show_links {
  my $links_height = 24;
  our $frame_command = $mw -> Frame(-background=>$bgcol) ->grid(-row=>1, -column=>2, -columnspan=>1, -rowspan=>1, -ipadx=>'0',-ipady=>'0',-sticky=>'nes');
  our $frame_links = $mw  -> Frame(-background=>$bgcol) ->grid(-row=>1, -column=>3, -columnspan=>1, -rowspan=>1, -ipadx=>'0',-ipady=>'0',-sticky=>'nes');
#  our $frame_command = $mw -> Frame(-background=>$bgcol) ->grid(-row=>1, -column=>3, -columnspan=>1, -rowspan=>1, -ipadx=>'0',-ipady=>'0',-sticky=>'wns');

  our $missing = 0;
  $frame_command -> Label(-text=>'    Cmd:', -font=>$font_normal, -background=>$bgcol)->grid(-row=>1, -column=>1, -sticky => 'ws');
  $frame_command -> Label(-text=>"     ", -font=>$font_normal, -background=>$bgcol)->grid (-row=>1,-column=>10, -columnspan=>1, -sticky=>'ws');

  if ($os =~ m/MSWin/i) {
    $frame_command -> Label(-text=>'', -font=>'Arial 1', -width=>40, -background=>$bgcol)->grid(-row=>1, -column=>15, -sticky => 'ens');
  }
  # Filter
  our $filter = "";
  $frame_command -> Label(-text=>"   Filter:", -font=>$font_normal, -background=>$bgcol)->grid (-row=>1,-column=>4, -sticky=>'ews');
  $filter_entry = $frame_command -> Entry(-width=>12, -textvariable=>\$filter, -background=>$white, -border=>2, -relief=>'groove' )
    -> grid(-row=>1,-column=>6,-columnspan=>2, -sticky => 'we',-ipadx=>1);
  $filter_entry -> bind('<Any-KeyPress>' => sub {
     if (length($filter)>0) {$filter_entry -> configure(-background=>$lightyellow )} else {$filter_entry -> configure(-background=>$white)};
     read_curr_dir($cwd, $filter, 0);
  });
  $help->attach($filter_entry, -msg => "Filter model files");
  my %autofind;
  $autofind{-enable} = 1;
  $autofind{-complete} = 1;
#  $autofind{-select} = 0;
  our $tab_browse_entry = $mw -> JComboBox(-background => $white, -font=>$font_normal, -mode=>"editable", -autofind=> \%autofind,
#					   -validate=>"match",
					   -selectbackground=>'#A0A0A0', -highlightthickness =>0,
						-arrowimage => $gif{down}, -borderwidth=>2, -relief=>"groove", -width=>20,
						-choices => [ qw/tab csv R * pdf phi ext cov cor pnm xpose sdtab mod lst org/ ],
						-textvariable => \$show_data, -browsecmd => sub{ 
						    tab_browse_entry_update($show_data);  
  }) -> grid(-row=>2, -column=>3, -columnspan => 10, -sticky=>"swe");
  $tab_browse_entry -> bind('<Return>', sub{
    tab_browse_entry_update($show_data);  
  });


  $i=1;
  $software{tty} =~ m/\.exe/i;
  my $pos = length $`;
  if (-e $software{calc}) {
    our $calc_button = $frame_links -> Button(
	-image=>$gif{calc}, -border=>$bbw,-width=>20,-height=>$links_height, -border=>$bbw,
	-background=>$button,-activebackground=>$abutton,-command=> sub{
	    start_command($software{calc});
	})->grid(-row=>2,-column=>$i,-sticky=>'news');
    $i++;
    $help->attach($calc_button, -msg => "Open system calculator");
  }

#  if (-e substr($software{tty}, 0, $pos+4)) {
    our $putty_button = $frame_links -> Button(-image=>$gif{putty},-border=>$bbw, -width=>20,-height=>$links_height, -border=>$bbw,-background=>$button,-activebackground=>$abutton,-command=> sub{
      start_command(substr($software{tty}, 0, $pos+4), substr($software{tty},$pos+5, length($software{tty})-($pos+4)));
    }) ->grid(-row=>2,-column=>$i,-sticky=>'news');
    $help->attach($putty_button, -msg => $software_descr{tty});
    $i++;
#  }
  my $r_start = get_R_gui_command (\%software);
  unless ($r_start eq "") {
      my $icon = "r";
      if ($r_start =~ m/rstudio/i) {
	  $icon = "rgui";
      }
      our $r_button = $frame_links -> Button(-image=>$gif{$icon}, -width=>20, -height=>$links_height, -border=>$bbw, -background=>$button,-activebackground=>$abutton,-command=> sub{
	  chdir ($cwd);
	  unlink ($cwd."/.Rprofile");
	  start_command($r_start);
       })->grid(-row=>2,-column=>$i,-sticky=>'news');
      $i++;
      $help->attach($r_button, -msg => "Open the R-GUI / R command line");
  }

  if (-e $software{splus}) {
    $splus_button = $frame_links -> Button(-image=>$gif{splus}, -width=>20, -height=>$links_height, -border=>$bbw, -background=>$button,-activebackground=>$abutton,-command=> sub{
    chdir ($cwd);
    start_command($software{splus});
    })->grid(-row=>2,-column=>$i,-sticky=>'news');
    $i++;
    $help->attach($splus_button, -msg => "Open S-Plus");
  }
  if (-e $software{sas}) {
    $sas_button = $frame_links -> Button(-image=>$gif{sas}, -width=>20, -height=>$links_height, -border=>$bbw, -background=>$button,-activebackground=>$abutton,-command=> sub{
    chdir ($cwd);
    start_command($software{sas});
    })->grid(-row=>2,-column=>$i,-sticky=>'news');
    $i++;
    $help->attach($sas_button, -msg => "Open SAS");
  }
  if (-e $software{spreadsheet}) {
    our $spreadsheet_button = $frame_links -> Button(-image=>$gif{spreadsheet},-border=>$bbw, -width=>20,-height=>$links_height, -border=>$bbw, -background=>$button,-activebackground=>$abutton,-command=> sub{
    start_command($software{spreadsheet});
    })->grid(-row=>2,-column=>$i,-sticky=>'news');
    $i++;
    $help->attach($spreadsheet_button, -msg => "Open spreadsheet application");
  }
  if (-e $software{editor}) {
    our $notepad_button = $frame_links -> Button(-image=>$gif{notepad},-border=>$bbw, -width=>20,-height=>$links_height, -border=>$bbw,-background=>$button,-activebackground=>$abutton,-command=> sub{
    start_command($software{editor});
    }) ->grid(-row=>2,-column=>$i,-sticky=>'news');
    $help->attach($notepad_button, -msg => "Open text-editor");
    $i++;
  }
  if (-e $software{madonna}) {
    $madonna_button = $frame_links -> Button(-image=>$gif{madonna}, -height=>$links_height, -border=>$bbw, -background=>$button,-activebackground=>$abutton,-command=> sub{
      start_command($software{madonna});
    })->grid(-row=>2,-column=>$i,-sticky=>'news');
    $help->attach($madonna_button, -msg => "Start Berkeley Madonna");
    $i++;
  }
  if (-e $software{extra1}) {
    our $extra1_button = $frame_links -> Button(-image=>$gif{extra1},-border=>$bbw, -width=>20,-height=>$links_height, -border=>$bbw,-background=>$button,-activebackground=>$abutton,-command=> sub{
    start_command($software{extra1});
    }) ->grid(-row=>2,-column=>$i,-sticky=>'news');
    $help->attach($extra1_button, -msg => $software_descr{extra1});
    $i++;
  }
  if (-e $software{extra2}) {
    our $extra2_button = $frame_links -> Button(-image=>$gif{extra2},-border=>$bbw, -width=>20,-height=>$links_height, -border=>$bbw,-background=>$button,-activebackground=>$abutton,-command=> sub{
    start_command($software{extra2});
    }) ->grid(-row=>2,-column=>$i,-sticky=>'news');
    $help->attach($extra2_button, -msg => $software_descr{extra2});
    $i++;
  }

  #$frame_command -> Label(-text=>"Command: ",-font => $font_normal)
  #  ->grid(-row=>2,-column=>1,-sticky=>'nse');
  $command_entry = $frame_command -> Entry(-textvariable=>\$run_command, -border=>2, -relief=>"groove", -width=>24, -font => $font_normal,-background=>$white)
   ->grid(-row=>1,-columnspan=>1,-column=>2,-sticky=>'we');  #i-3
  if (($cluster_active==1)&&($setting{cluster_type}!=0)) {$gif_shell=$gif{shell_linux}} else {$gif_shell=$gif{shell}};
  $command_button = $frame_command -> Button(-image=> $gif_shell,-border=>$bbw,-background=>$button,-activebackground=>$abutton, -command=> sub{
     if(($command_entry -> get()) eq "") {
	 if ($^O =~ m/MSWin/) {
	     system ("start");
	 } else {
	     system ($setting{terminal}." &");
	 }
     } else {
        run_command($command_entry -> get())
     }
  })->grid(-row=>1,-columnspan=>1,-column=>3,-sticky=>'e'); # i-1
  $command_entry -> bind("<Return>", sub {
     if (($command_entry -> get()) eq "") {
  	 if ($^O =~ m/MSWin/) {
  	     system ("start");
  	 } else {
  	     system ($setting{terminal}." &");
  	 }
     } else {
         run_command($command_entry -> get())
     }
  });
 if ($os =~ m/MSWin/i) {
   $help -> attach($command_button, -msg => "Run command in a command-console");
 } else {
   $help -> attach($command_button, -msg => "Run command in a command-shell");
 }
  
}

sub run_command {
### Purpose : Run a command, either using CMD.exe in windows, or using ssh on the cluster (when using the linux-cluster functionality and when the cluster is enabled)
### Compat  : W+L?
    my $com = shift;
    if ($^O =~ m/MSWin/i) {
	open (RUN, ">pirana_run_command.bat");
	print RUN $com."\n";
	close RUN;
	if ($stdout) {$stdout -> insert('end', "\n".$com);}
	system ("start pirana_run_command.bat");
	sleep 1;
	unlink ("pirana_run_command.bat");
    } else {  # on Linux
	$com = $setting{terminal}." -e '".$com."; bash' &";
	print $com;
	system ($com);
  }
}

sub new_model_name {
### Purpose : Return a new model name when supplied with a previous one (eg. 001 -> 001A)
### Compat  : W+L+
  my $old=@_[0];
  my $success=0;
  my $last_char=substr($old,-1,1);
  my $num = ord($last_char);
  my $new_num = $last_char;
  my $new;
  if ($last_char =~ m/\d/) { # numeric
      for($i = 0 ; $i < length($old); $i++) {
	  my $t = substr($length, length($old)-$i, (length($old)-$i+1));
	  if ($t =~ m/\d/) {
	      $new_num = $t.$new_num;
	  }
      }
      $plus_one = $new_num + 1;
      $new = $old;
      $new =~ s/$new_num/$plus_one/;
      $success=1
  }
  if (($num>64 && $num<90) || ($num>96 && $num<122)) {  # A..Y or a..y
    $suffix=chr($num+1);
    $new=substr($old,-length($old),(length($old)-1)).$suffix;
    $success=1;
  };
  if (($num==90) || ($num==122)) {  # Z or z
    $suffix=chr(122).chr($num-25);
    $new=substr($old,-length($old),(length($old)-1)).$suffix;
    $success=1;
  }
  unless ($success==1) {
    return ($old);
  } else {return $new};
}

sub save_header_widths {
### Purpose : Save the columnwidths of the main Listbox
### Compat  : W+L+
  my $x=0;
  foreach(@main_headers) {
    @models_hlist_widths[$x] = $models_hlist->columnWidth($x);
    if (@models_hlist_widths[$x] < 10) {@models_hlist_widths[$x] = 10};
    $x++;
  }
  shift(@models_hlist_widths);
  $new_models_hlist_widths = join (";",@models_hlist_widths);
  if ($setting_internal{header_widths} ne $new_models_hlist_widths) {
    $setting_internal{header_widths} = join (";",@models_hlist_widths);
    save_ini ($home_dir."/ini/internal.ini", \%setting_internal, \%setting_internal_descr, $base_dir."/ini_defaults/internal.ini");
  }
  unshift(@models_hlist_widths, 0);

}

sub nmfe_run_window {
### Purpose : Create dialog window for running a model
### Compat  : W+L+
    # get basic information on models and build command
    my @runs = $models_hlist -> selectionGet ();
    my @files = @ctl_show[@runs];
    my $file_string = join (', ',@files);
    my $font_bold = $font_normal;

    unless (%clusters) {
	our %clusters;
    }
    $clusters{run_on_sge} = $sge{sge_default};
    $clusters{run_on_pcluster} = 0;

    my $len = length($ssh{local_folder}); 
    unless (substr($cwd, 0, $len) =~ m/$ssh{local_folder}/i ) { # if not on mounted cluster location, switch to local mode
	$ssh{connect_ssh} = 0;
    };

# ssh
    my $local_run = "None (local)";
    my $ssh_ref = $ssh_all{$setting_internal{cluster_default}};
    our %ssh = %$ssh_ref;
    my %ssh_new = %ssh;
    my %ssh_descr = %$ssh_descr_ref;
    my @ssh_names = keys (%ssh_all);
    unshift (@ssh_names, $local_run);
    my $ssh_chosen = $setting_internal{cluster_default};
    if ($ssh_chosen eq $local_run) {
	$ssh{connect_ssh} = 0;
    } else {
	$ssh{connect_ssh} = 1;
    }
    my $loc = unix_path($ssh{local_folder});
    my $rem = unix_path($ssh{remote_folder});
    if ((!( $run_dir =~ s/$loc/$rem/i )) && (!($ssh_chosen eq $local_run))) {
	$ssh{connect_ssh} = 0;
	$ssh_chosen = $local_run;
    }

    # build dialog window
    my $run_in_new_dir = 0;
    my $title = 'Run model using nmfe ' ;
    my $nmfe_run_window = $mw -> Toplevel(-title=>$title);    
    $nmfe_run_window -> OnDestroy ( sub{
	undef $unmfe_run_window; undef $nmfe_run_frame;
    });

    # Already create new folder names and script file name
    my $ext = "sh";
    if (($^O =~ m/MSWin/i)&&($ssh{connect_ssh}==0)) {
	$ext = "bat";
    }
    my $rand_str = generate_random_string(4);
    my $script_file = "pirana_start_".$rand_str.".".$ext;
    my @new_dirs;
    foreach my $model (@files) {
#	my $new_dir = "nmfe_".$model."_".generate_random_string(5);
	my $new_dir = "nmfe_".$model."_".get_nmfe_number($model);
	push (@new_dirs, $new_dir);
    }

    # build notebook
    my $nmfe_run_frame = $nmfe_run_window -> Frame (-background=>$bgcol)-> grid(-ipadx=>8, -ipady=>8);
   # my $nmfe_notebook = $nmfe_frame ->NoteBook(-tabpadx=>5, -font=>$font, -border=>1, -backpagecolor=>$bgcol,-inactivebackground=>$bgcol, -background=>'#FFFFFF') -> grid(-row=>1, -column=>1, -columnspan=>4,-ipadx=>10, -ipady=>10, -sticky=>"nw");
   # my $nmfe_run_frame = $nmfe_notebook -> add("general", -label=>"General");
    my $command_area = $nmfe_run_frame -> Scrolled ("Text", -scrollbars=>'se',
      -width=>72, -height=>8, 
      -background=>"#FFFFFF", -exportselection => 0, -wrap=>'none', 
      -border=>1, -font=>$font_normal, -relief=>'groove',
      -selectbackground=>'#606060', -highlightthickness =>0
    ) -> grid(-row=>16,-column=>2,-columnspan=>3,-sticky=>"nwe");

    my $parallelization = 0;
    my $nm_version_chosen;
    my $pnm_file_chosen = "off";
    my $pnm_nodes_chosen;
    my @pnm_nodes = (2,3,4,5,6,7,8,10,12,16,24);

    my $pnm_menu = $nmfe_run_frame -> Optionmenu( -options=> ["off"],
      -border=>$bbw, -variable=> \$pnm_file_chosen,
      -background=>$run_color,-activebackground=>$arun_color,
      -font=>$font_normal, -background=>"#c0c0c0",
      -activebackground=>"#a0a0a0", -command=> sub{
	$parallelization = 1;
	$parallelization_text = '"-parafile='.$pnm_file_chosen.'"';
	my $pnm_nodes_chosen_clean = $pnm_nodes_chosen;
	$pnm_nodes_chosen_clean =~ s/\snodes//;
	unless ($pnm_file_chosen eq "off") {
	    $parallelization_text .= ' "[nodes]='.$pnm_nodes_chosen_clean.'"' ;
	}
	update_nmfe_run_script_area ($command_area, $script_file, \@files, $nm_version_chosen, $method_chosen, $run_in_new_dir, \@new_dirs, $run_in_background, \%clusters, \%ssh, $nm_versions_menu, $parallelization_text);
    }) -> grid(-row=>11,-column=>3,-columnspan=>1,-sticky => 'wnse');
    foreach (@pnm_nodes) {$_ .= " nodes"};
    my $pnm_nodes_menu = $nmfe_run_frame -> Optionmenu(-options=> [@pnm_nodes],
      -border=>$bbw, -variable=> \$pnm_nodes_chosen, 
      -background=>$run_color,-activebackground=>$arun_color,
      -font=>$font_normal, -background=>"#c0c0c0",
      -activebackground=>"#a0a0a0", -command=> sub{
	my $pnm_nodes_chosen_clean = $pnm_nodes_chosen;
	$pnm_nodes_chosen_clean =~ s/\snodes//;
	$parallelization_text = '"-parafile='.$pnm_file_chosen.'"';
	unless ($pnm_file_chosen eq "off") {
	    $parallelization_text .= ' "[nodes]='.$pnm_nodes_chosen_clean.'"' ;
	}
	update_nmfe_run_script_area ($command_area, $script_file, \@files, $nm_version_chosen, $method_chosen, $run_in_new_dir, \@new_dirs, $run_in_background, \%clusters, \%ssh, $nm_versions_menu, $parallelization_text);
    }) -> grid(-row=>12,-column=>3,-columnspan=>1,-sticky => 'wnse');
    my $para_label = $nmfe_run_frame -> Label (-foreground=>$grey,
	-text=>"Parafile: ", -font=>$font_normal, -background=>$bgcol
	) -> grid(-row=>11,-column=>2,-sticky=>"nes");
    my $nodes_label = $nmfe_run_frame -> Label (-foreground=>$grey,
	-text=>"Nodes: ", -font=>$font_normal, -background=>$bgcol
	) -> grid(-row=>12,-column=>2,-sticky=>"nes");
    my $pnm_choose = $nmfe_run_frame -> Checkbutton (-text=>"Parallelization:", -variable=> \$parallelization, -font=>$font_normal,  -selectcolor=>$selectcol, -activebackground=>$bgcol, -command=>sub{
	if ($parallelization == 1) {
	    $parallelization_text = '"-parafile='.$pnm_file_chosen.'" "[nodes]=2"' ;   
	    $pnm_menu -> configure (-state=>"normal");
	    $pnm_nodes_menu -> configure (-state=>"normal");
	    $para_label -> configure (-foreground=>"#000000");
	    $nodes_label -> configure (-foreground=>"#000000");
	} else {
	    $parallelization_text = "";
	    $pnm_menu -> configure (-state=>"disabled");
	    $pnm_nodes_menu -> configure (-state=>"disabled");
	    $para_label -> configure (-foreground=>$grey);
	    $nodes_label -> configure (-foreground=>$grey);
	}
	update_nmfe_run_script_area ($command_area, $script_file, \@files, $nm_version_chosen, $method_chosen, $run_in_new_dir, \@new_dirs, $run_in_background, \%clusters, \%ssh, $nm_versions_menu, $parallelization_text);
    }) -> grid(-row=>11,-column=>2,-columnspan=>1,-sticky=>"nws");

    my $nm_versions_menu = $nmfe_run_frame -> Optionmenu(
	-options=>[],
	-variable => \$nm_version_chosen,
	-border=>$bbw,-width=>32,
#      -background=>$run_color,-activebackground=>$arun_color,   -activebackground=>"#a0a0a0", -background=>"#c0c0c0",
	-background=>$lightblue, -activebackground=>$darkblue, -foreground=>$white, -activeforeground=>$white, 
	-font=>$font_normal, 
	-command=> sub{
        if (-e unix_path($nm_dirs{$nm_version_chosen}."/test/runtest.pl")) {
          $run_method_nm_type="NMQual";
        } else {$run_method_nm_type="nmfe"};
	if ($parallelization == 1) {
	    $parallelization_text = "-parafile=".$pnm_file_chosen;
	} else {	
	    $parallelization_text = "";
	}
	update_nmfe_run_script_area ($command_area, $script_file, \@files, $nm_version_chosen, $method_chosen, $run_in_new_dir, \@new_dirs, $run_in_background, \%clusters, \%ssh, $nm_versions_menu, $parallelization_text);
	my $nm_ver;
	if ($ssh{connect_ssh} == 0) {
	    $nm_ver = $nm_vers{$nm_version_chosen};
	} else {
	    $nm_ver = $nm_vers_cluster{$nm_version_chosen};
	}
	if ($nm_ver >= 72) {
	    if ($parallelization == 1) {
		$pnm_menu -> configure (-state=>"normal");
		$pnm_nodes_menu -> configure (-state=>"normal");
	    }
	    $pnm_choose -> configure (-state=>"normal");
	} else {
	    $pnm_menu -> configure (-state=>"disabled");
	    $pnm_nodes_menu -> configure (-state=>"disabled");
	    $pnm_choose -> configure (-state=>"disabled");
	}
	@pnm_files = ("off");
	push (@pnm_files, dir($cwd, "\.pnm")) ;  # pnm files in current folder
	if (-d $nm_dirs{$nm_version_chosen}) {
	    push (@pnm_files, dir($nm_dirs{$nm_version_chosen}."/run", "\.pnm")) ;  # pnm files in Nonmem folder
	};
	$pnm_menu -> configure (-options => [@pnm_files]);
    }) -> grid(-row=>3,-column=>2,-columnspan=>1,-sticky => 'wens');

    if ($nm_ver >= 72) {
	if ($parallelization == 1) {
	    $pnm_menu -> configure (-state=>"normal");
	    $pnm_nodes_menu -> configure (-state=>"normal");
	}
	$pnm_choose -> configure (-state=>"normal");
    } else {
	$pnm_menu -> configure (-state=>"disabled");
	$pnm_nodes_menu -> configure (-state=>"disabled");
	$pnm_choose -> configure (-state=>"disabled");
    }

    $nmfe_run_frame -> Label (
	-text=>"Model file(s):", -font=>$font_bold,-background=>$bgcol
	) -> grid(-row=>1,-column=>1,-sticky=>"e");
    $nmfe_run_frame -> Label (
	-text=>$file_string, -font=>$font_normal,-background=>$bgcol, -foreground => $grey,
	) -> grid(-row=>1,-column=>2,-columnspan=>2,-sticky=>"w");

    $nmfe_run_frame -> Label (
	-text=>"Run directory:",-font=>$font_bold, -background=>$bgcol) -> grid(-row=>4,-column=>1,-sticky=>"e");
    my $dir = $cwd;
    my $run_directory = $nmfe_run_frame -> Entry (
	-textvariable=>\$dir, -font=>$font_normal,-background=>$white, -state=>'disabled', -width=>50
	) -> grid(-row=>4,-column=>2,-columnspan=>3,-sticky=>"w");
    if ($clusters{run_on_sge} == 1) {
         $run_in_new_dir = 1;
    }
    $nmfe_run_frame -> Checkbutton (
	-text=>"Run in separate folder(s)", -selectcolor=>$selectcol, -activebackground=>$bgcol, -variable=>\$run_in_new_dir, -font=>$font_normal,  -selectcolor=>$selectcol, -activebackground=>$bgcol, -command=> 
	sub{
	    update_nmfe_run_script_area ($command_area, $script_file,\@files, $nm_version_chosen, $method_chosen, $run_in_new_dir, \@new_dirs, $run_in_background, \%clusters, \%ssh, $nm_versions_menu);
	}) -> grid(-row=>5,-column=>2,-columnspan=>2,-sticky=>"w");
    if (($clusters{run_on_pcluster} == 1)||($clusters{run_on_sge}==1)) {
	$run_in_new_dir = 1;
    }

    ### Run command and start script
    $nmfe_run_frame -> Label (
	-text=>"Script contents:\n", -font=>$font_bold, -background=>$bgcol
    ) -> grid(-row=>16,-column=>1,-sticky=>"ne");
    my $nmfe_run_script = $nmfe_run_frame -> Entry (
	-textvariable=> \$nmfe_run_command,
	-background=>'#ffffff', -width=>32, -border=>1, -relief=>'groove', -font=>$font_normal
	) -> grid(-row=>14,-column=>2,-columnspan=>3,-sticky=>"nwe");
    $nmfe_run_frame -> Label (
	-text=>"Start script:", -font=>$font_bold, -background=>$bgcol
    ) -> grid(-row=>14,-column=>1,-sticky=>"ne");

    $nmfe_run_frame -> Checkbutton (
	-text=>"Run in background",-font=>$font_normal,  -selectcolor=>$selectcol, -activebackground=>$bgcol, -variable=>\$run_in_background,  -selectcolor=>$selectcol, -activebackground=>$bgcol, -command=> sub{
	 my ($script_file, $run_command, $script_ref) = build_nmfe_run_command ($script_file, \@files, $nm_version_chosen, $method_chosen, $run_in_new_dir, \@new_dirs, $run_in_background, \%clusters, \%ssh);
	 $nmfe_run_command = $run_command;
	}) -> grid(-row=>6,-column=>2,-columnspan=>2,-sticky=>"w");

    $nmfe_run_frame -> Label (
	-text=>"NB. If runs are started in the background, execution will continue\nwhen Pirana is closed, or when logging out from a cluster.",
	-font=>$font_normal, -background=>$bgcol, -justify=>"left"
	) -> grid(-row=>7,-column=>2,-columnspan=>2,-sticky=>"w");
    $nmfe_run_frame -> Label (
	-text=>" ",-font=>$font_normal, -background=>$bgcol) -> grid(-row=>8,-column=>1,-sticky=>"w");

    # NM installations
    my $nm_text = "NONMEM";
    $nmfe_run_frame -> Label (-text=>$nm_text.":", -font=>$font_bold, -background=>$bgcol
	) -> grid(-row=>3,-column=>1,-sticky=>"e");
    my $new_nm_button = $nmfe_run_frame -> Button (-image=>$gif{plus}, -font=>$font, -border=>$bbw, -background=>$button, -activebackground=>$abutton, -command=> sub{
        manage_nm_window();
        $nmfe_run_window -> destroy();
    })-> grid(-row=>3,-column=>3,-sticky=>"wns");
    $nmfe_run_frame -> Label (-text=>" ", -width=>40, -font=>$font_normal, -background=>$bgcol	) -> grid(-row=>1,-column=>3,-sticky=>"e");
    
    delete $nm_dirs{""};
    my $nm_dirs_ref; my $nm_vers_ref ; my @nm_vers;
    my @nm_installations; my @nm_installations_checked;
    if ($ssh{connect_ssh} == 0) {
	@nm_installations = keys(%nm_dirs);
	@nm_vers = keys (%nm_vers);
    } else {
	@nm_installations = keys(%nm_dirs_cluster);
	@nm_vers = keys (%nm_vers_cluster);
    }
    if ($nm_versions_menu) { 
	$nm_versions_menu -> configure (-options => [@nm_installations] );
    } ;

    my @pnm_files = ("off");
    push (@pnm_files, dir($cwd, "\.pnm")) ;  # pnm files in current folder
    if (-d $nm_dirs{$nm_version_chosen}) {
	push (@pnm_files, dir($nm_dirs{$nm_version_chosen}."/run", "\.pnm")) ;  # pnm files in Nonmem folder
    }
    $pnm_menu -> configure (-options => [@pnm_files] );

    my @params = ($command_area, $script_file, \@files, $nm_version_chosen, $method_chosen, $run_in_new_dir, \@new_dirs, $run_in_background, \%clusters, \%ssh, $nm_versions_menu);
 
    $nmfe_run_frame -> Label (
	-text=>"Clusters: ", -font=>$font_bold, -background=>$bgcol
	) -> grid(-row=>9,-column=>1,-sticky=>"nes");
    $nmfe_run_frame -> Label (
	-text=>"Connect to: ", -font=>$font_normal, -background=>$bgcol
	) -> grid(-row=>9,-column=>2,-sticky=>"nes");

    my $ssh_cluster_optionmenu = $nmfe_run_frame -> Optionmenu (
	-options=> \@ssh_names, -textvariable => \$ssh_chosen, 
#	-background=>"#c0c0c0", -activebackground=>"#a0a0a0", 
	-background=>$lightblue, -activebackground=>$darkblue, -foreground=>$white, -activeforeground=>$white, 
	-width=>32, -border=>$bbw, -font=>$font_normal, 
	-command=>
	sub{
	    # update
	    my $ssh_ref = $ssh_all{$ssh_chosen};
	    our %ssh = %$ssh_ref;
	    my $loc = unix_path($ssh{local_folder});
	    my $rem = unix_path($ssh{remote_folder});
	    $run_dir = unix_path($cwd);
	    if ((!( $run_dir =~ s/$loc/$rem/i )) && (!($ssh_chosen eq $local_run))) {
		message ("Current folder not located on cluster, can't use SSH connect mode.\nPlease check settings.");
		$ssh{connect_ssh} = 0;
		$ssh_chosen = $local_run;
		@nm_installations = keys(%nm_dirs);
	    } else {
		$ssh{connect_ssh} = 1;
	    }
#	    if ($ssh_chosen eq $local_run) {
	    if ($ssh_chosen =~ m/none/ig) {
		$ssh{connect_ssh} = 0;
	    }
	    
	    $setting_internal{ssh_connect} = $ssh{connect_ssh};
	    save_ini ($home_dir."/ini/internal.ini", \%setting_internal, \%setting_internal_descr, $base_dir."/ini_defaults/internal.ini");
	    
	    # update
	    my $ext = "sh";
	    if (($^O =~ m/MSWin/i)&&($ssh{connect_ssh}==0)) {
		$ext = "bat";
	    }
	    my $script_file = "pirana_start_".$rand_str.".".$ext;
	    @nm_installations = keys(%nm_dirs_cluster);
	    my ($script_file, $run_command, $script_ref) = build_nmfe_run_command ($script_file, \@files, $nm_version_chosen, $method_chosen, $run_in_new_dir, \@new_dirs, $run_in_background, \%clusters, \%ssh);
	    $nmfe_run_command = $run_command;
	    update_nmfe_run_script_area ($command_area, $script_file, \@files, $nm_version_chosen, $method_chosen, $run_in_new_dir, \@new_dirs, $run_in_background, \%clusters, \%ssh, $nm_versions_menu);    
	} 
	) -> grid (-row=>9,-column=>3,-columnspan=>1,-sticky=>"nwes");
    # $nmfe_run_frame -> Label (
    # 	-text=>"Submit to:", -font=>$font_normal, -background=>$bgcol
    # 	) -> grid(-row=>10,-column=>1,-sticky=>"ne");
    my $sun_grid_engine = "Submit to SGE";
#    if ($^O =~ m/MSWin/i){
#	$sun_grid_engine .= " (connect to SGE using SSH)"
#    }
    $nmfe_run_frame -> Checkbutton (-text=>$sun_grid_engine, -variable=> \$clusters{run_on_sge}, -font=>$font_normal,  -selectcolor=>$selectcol, -activebackground=>$bgcol,  -command=>sub{
	if ($clusters{run_on_sge} == 1) {
	    $run_in_new_dir = 1;
	    $clusters{run_on_pcluster} = 0;
#	    $nmfe_run_script -> configure (-state=>'normal');
	}
	update_nmfe_run_script_area ($command_area, $script_file, \@files, $nm_version_chosen, $method_chosen, $run_in_new_dir, \@new_dirs, $run_in_background, \%clusters, \%ssh, $nm_versions_menu );
    }) -> grid(-row=>9,-column=>2,-columnspan=>1,-sticky=>"nws");

    if (($setting{use_pcluster}==1)&&($^O =~ m/MSWin/i)) {
	$nmfe_run_frame -> Checkbutton (-text=>"PCluster", -variable=> \$clusters{run_on_pcluster}, -font=>$font_normal,  -selectcolor=>$selectcol, -activebackground=>$bgcol, -command=>sub{
	    if ($clusters{run_on_pcluster} == 1) {
		$run_in_new_dir = 1;
		$clusters{run_on_sge} = 0;
#	    $nmfe_run_script -> configure (-state=>'disabled');
#	    $command_area -> configure (-state=>'disabled');
	    } else {
#	    $nmfe_run_script -> configure (-state=>'normal');
#	    $command_area -> configure (-state=>'normal');
	    }
	    update_nmfe_run_script_area ($command_area, $script_file, \@files, $nm_version_chosen, $method_chosen, $run_in_new_dir, \@new_dirs, $run_in_background, \%clusters, \%ssh, $nm_versions_menu );
        }) -> grid(-row=>11,-column=>2,-columnspan=>2,-sticky=>"nw");
    }

    $nmfe_run_frame -> Label (-text=>" ",-font=>$font_normal, -background=>$bgcol) -> grid(-row=>13,-column=>1,-sticky=>"w");
    $nmfe_run_frame -> Label (-text=>" ",-font=>$font_normal, -background=>$bgcol) -> grid(-row=>15,-column=>1,-sticky=>"w");
    $nmfe_run_frame -> Label (-text=>" ",-font=>$font_normal, -background=>$bgcol) -> grid(-row=>17,-column=>1,-sticky=>"w");

    $close_prv = $setting_internal{quit_dialog};
    $nmfe_run_frame -> Checkbutton (-text=>"Close this dialog window after starting run", -variable=> \$setting_internal{quit_dialog}, -font=>$font_normal,  -selectcolor=>$selectcol, -activebackground=>$bgcol,  -command=>sub{
	if ($setting_internal{quit_dialog} != $close_prv) { #update internal settings
	    save_ini ($home_dir."/ini/internal.ini", \%setting_internal, \%setting_internal_descr, $base_dir."/ini_defaults/internal.ini");
	}
    }) -> grid(-row=>18,-column=>2,-columnspan=>2,-sticky=>"nw");

     my $nmfe_run_button = $nmfe_run_frame -> Button (-image=> $gif{run}, -background=>$button, -width=>40,-height=>40, -activebackground=>$abutton, -border=>$bbw, -command=> sub {
	 my $nmfe_run_command_out = $nmfe_run_command;
	 unless (@nm_installations == 0) { #NM installed?
	    my $script_text = $command_area -> get("0.0", "end");
#	    my ($script_file, $script_text_ref) = create_nm_start_script ($script_file, $nm_version_chosen, os_specific_path($cwd), \@files, $run_in_new_dir, \@new_dirs, \%$clusters, \%ssh); 
            my $ext = "sh";
            if (($^O =~ m/MSWin/i)&&($ssh{connect_ssh}==0)) {
                $ext = "bat";
            }
            my $script_file = "pirana_start_".$rand_str.".".$ext;

            write_nm_start_script ($script_file, \$script_text);
            
	    my @dirs_copy = @new_dirs;
	    if ($run_in_new_dir == 1) {
		foreach my $file (@files) {
		    my $new_dir = shift (@dirs_copy);
		    unless ($new_dir eq "") {
			move_nm_files ($file.".".$setting{ext_ctl}, $new_dir) ;
			db_log_execution ($file.".".$setting{ext_ctl}, $models_descr{$file}, "nmfe", $run_method, $nmfe_run_command_out, $setting{name_researcher}, "pirana.dir");
		    }
		}
	    }
	    if (($run_in_background == 0)) {
		if ($os =~ m/MSWin/i) {
		    $nmfe_run_command_out = "start ".$nmfe_run_command ;
		} else {
		    if ($setting{quit_shell}==0) { # don't close terminal window after completion
			if ($setting{terminal} =~ m/gnome-terminal/) { # for gnome-terminal
			    $nmfe_run_command_out .= '|less';		   
			} else { # this works for xterm and maybe some other terminals
			    $nmfe_run_command_out .= ';read -n1';
			}
		    }
		    $nmfe_run_command_out = $setting{terminal}.' -e "'.$nmfe_run_command_out.'" &';
		}
	    } else {
		if ($os =~ m/MSWin/i) {
		    $nmfe_run_command_out = "start /b ".$nmfe_run_command_out;
		} 
	    }
	    if ($clusters{run_on_pcluster} == 1) {
		my $batfile = $nmfe_run_command_out;
		$batfile =~ s/start //i;
		exec_run_nmfe ($nmfe_run_command_out, "Starting compilation"); # do compilation
		exec_run_pcluster ("nonmem.exe", "NM@Pcluster", \@new_dirs, \@files, "Submitting runs to PCluster");
	    } else {
		exec_run_nmfe ($nmfe_run_command_out, "Starting run");
	    }
	    save_ini ($home_dir."/ini/settings.ini", \%setting, \%setting_descr, $base_dir."/ini_defaults/settings.ini");
	} else {message ("First add NM installations to Pirana")}
	if ($setting_internal{quit_dialog} == 1) {
	    $nmfe_run_window -> destroy();
	}
    })-> grid(-row=>19, -column=>2,-columnspan=>2,-sticky=>"wns");
    if (keys(%nm_dirs)+keys(%nm_dirs_cluster) == 0) {
	$nmfe_run_button -> configure (-state => "disabled");
    }
    $help -> attach($nmfe_run_button, -msg => "Start run");

    center_window($nmfe_run_window, $setting{center_window}); # center after adding frame (redhat)

    # update
    $parallelization = 0;
    my ($script_file, $run_command, $script_ref) = build_nmfe_run_command ($script_file, \@files, $nm_version_chosen, $method_chosen, $run_in_new_dir, \@new_dirs, $run_in_background, \%clusters, \%ssh);
    $nmfe_run_command = $run_command;
    update_nmfe_run_script_area ($command_area, $script_file, \@files, $nm_version_chosen, $method_chosen, $run_in_new_dir, \@new_dirs, $run_in_background, \%clusters, \%ssh, $nm_versions_menu);

    unless($^O =~ m/darwin/i) {
	no_resize ($nmfe_run_window);
	$nmfe_run_window -> raise();
	$nmfe_run_window -> update();
    }
}

sub pcluster_select_node_window {
    return ($node_selected);
}

sub ssh_notebook_tab {
    my ($nmfe_ssh_frame, $bind_subroutine, $params_ref) = @_;
    my @params = @$params_ref;
 #   my $ssh_ref = @params[5];
 #   my %ssh = %$ssh_ref;
    ### SSH options
    $nmfe_ssh_frame -> Label (-text=>"Note: To enable passwordless access, make sure you have an SSH-keypair installed,\nor supply the SSH password as extra parameter.\n",
       -font=>$font_normal, -background=>$bgcol, -justify=>"left"
    ) -> grid(-row=>0,-column=>1,-columnspan=>2, -sticky=>"ne");

    $nmfe_ssh_frame -> Label (-text=>"Connect to cluster through SSH", -font=>$font_normal, -background=>$bgcol
    ) -> grid(-row=>1,-column=>1,-sticky=>"ne");

    $nmfe_ssh_frame -> Label (-text=>"SSH login", -font=> $font_normal, -background=>$bgcol
    ) -> grid(-row=>3,-column=>1,-sticky=>"ne");
    my $ssh_login_entry = $nmfe_ssh_frame -> Entry (-border=>1, -relief=>'groove',-textvariable=> \$ssh{login}, -width=>20, -font=>$font_normal, -background=>"#FFFFFF"
    ) -> grid(-row=>3,-column=>2,-sticky=>"nw");

    $nmfe_ssh_frame -> Label (-text=>"Additional parameters", -justify=>'right', -font=> $font_normal, -background=>$bgcol
    ) -> grid(-row=>4,-column=>1,-sticky=>"ne");
    my $ssh_parameters_entry = $nmfe_ssh_frame -> Entry (-textvariable=> \$ssh{parameters}, -width=>20, -font=>$font_normal, -background=>"#FFFFFF"
    ) -> grid(-row=>4,-column=>2,-sticky=>"nw");

    $nmfe_ssh_frame -> Label (-text=>"Remote folder", -font=> $font_normal, -background=>$bgcol
    ) -> grid(-row=>5,-column=>1,-sticky=>"ne");
    my $ssh_remote_folder_entry = $nmfe_ssh_frame -> Entry (-border=>1, -relief=>'groove',-textvariable=> \$ssh{remote_folder}, -width=>44, -font=>$font_normal, -background=>"#FFFFFF"
    ) -> grid(-row=>5,-column=>2,-sticky=>"nw");

    $nmfe_ssh_frame -> Label (-text=>"Local folder equivalent", -font=> $font_normal, -background=>$bgcol
    ) -> grid(-row=>6,-column=>1,-sticky=>"ne");
    my $ssh_local_folder_entry = $nmfe_ssh_frame -> Entry (-border=>1, -relief=>'groove',-textvariable=> \$ssh{local_folder}, -width=>44, -font=>$font_normal, -background=>"#FFFFFF"
    ) -> grid(-row=>6,-column=>2,-sticky=>"nw");

    my $nmfe_connect_ssh_checkbox = $nmfe_ssh_frame -> Checkbutton (-text=>"", -variable=> \$ssh{connect_ssh}, -font=>$font_normal, -background=>$bgcol, -command=>sub{
    }) -> grid(-row=>1,-column=>2,-sticky=>"nw");

    return ();
}

sub psn_run_window {
    my ($model, $psn_option, $psn_type) = @_;
    #psn_type: 0 = model
    #          1 = dataset

    my @models = @$model;
    my $modelfile;
    foreach my $mod (@models) {
        $modelfile .= $mod.".".$setting{ext_ctl}." ";
    }
    my $model_description = $models_descr{$model};
    my $psn_parameters = $psn_commands{$psn_option};
    my $run_in_new_dir = 0;
    my $psn_run_window = $mw -> Toplevel(-title=>'PsN Toolkit ('.$psn_option.")");
    my $psn_help_not_found = "PsN help information not imported into Pirana. Please go to: \n    Tools --> PsN --> Update PsN help files. \n\n";
    my $local_run = "None (local)";
    my $font_bold = $font_normal;
    
    $psn_run_window -> OnDestroy ( sub{
        undef $unmfe_run_window; undef $nmfe_run_frame;
                                   });
    $ssh{connect_ssh} = $setting_internal{ssh_connect};

    my $len = length($ssh{local_folder}); 
    unless (substr($cwd, 0, $len) =~ m/$ssh{local_folder}/i ) { # if not on mounted cluster location, switch to local mode
	$ssh{connect_ssh} = 0;
    };

    # build notebook
    my $psn_run_frame = $psn_run_window -> Frame (-background=>$bgcol)-> grid(-ipadx=>8, -ipady=>8);
    my $psn_help_buttons_frame = $psn_run_frame -> Frame(-background=>$bgcol) -> grid (-column=>4, -columnspan=>3, -row=> 0, -sticky=>"nwe");
    my $psn_run_text = $psn_run_frame -> Scrolled ("Text", -scrollbars=>'e', 
                                                   -width=>72, -height=>16, -highlightthickness => 0, -wrap=> "none",
                                                   -exportselection => 0, -border=>1, -relief=>'groove',
                                                   -font=>$font, -background=>"#f5f5f5", -state=>'normal'
        )->grid(-column=>1, -row=>0, -columnspan=>3, -sticky=>'nwe');
 
   # Get PsN help information 
    my $psn_text_ref = file_to_text ($base_dir."/doc/psn/".$psn_option."_h.txt" );
    if ($$psn_text_ref eq "") {
	    $psn_run_text -> insert("1.0", $psn_help_not_found);
    } else {
	$psn_run_text -> insert("1.0", "PsN command information: \n");
	$psn_run_text -> update();
	#          my $psn_text = get_psn_info($psn_option, $software{psn_toolkit}, \%ssh, "h");
	psn_info_update_text ($psn_run_text, $$psn_text_ref, $psn_run_button);
    }
 
    $psn_help_buttons_frame -> Button(-text=>"Options", -font=>$font, -border=>$bbw, -background=>$button, -activebackground=>$abutton, -command=> sub {
        my $psn_text_ref = file_to_text ($base_dir."/doc/psn/".$psn_option."_h.txt");
	if ($$psn_text_ref eq "") {
	    $psn_run_text -> insert("1.0", $psn_help_not_found);
	} else {
	    $psn_run_text -> insert("1.0", "PsN command information: \n");
	    $psn_run_text -> update();
  #          my $psn_text = get_psn_info($psn_option, $software{psn_toolkit}, \%ssh, "h");
	    psn_info_update_text ($psn_run_text, $$psn_text_ref, $psn_run_button);
	}
	}) -> grid (-column=>1, -row=> 1, -columnspan=>1, -sticky=>"nswe");
       
    $psn_help_buttons_frame -> Button(-text=>"Help", -font=>$font, -border=>$bbw, -background=>$button, -activebackground=>$abutton, -command=> sub {
	my $psn_text_ref = file_to_text ($base_dir."/doc/psn/".$psn_option."_help.txt");
	if ($$psn_text_ref eq "") {
	    $psn_run_text -> insert("1.0", $psn_help_not_found);
	} else {
          $psn_run_text -> insert("1.0", "PsN help file: \n");
	  $psn_run_text -> update();
#        my $psn_text = get_psn_info($psn_option, $software{psn_toolkit}, \%ssh, "help");
	    psn_info_update_text ($psn_run_text, $$psn_text_ref, $psn_run_button);
	}
	}) -> grid (-column=>1, -row=> 2, -columnspan=>1, -sticky=>"nswe");
	
    $psn_run_frame -> Label (-text=>" ",-font=>$font_normal, -background=>$bgcol) -> grid(-row=>1,-column=>1,-sticky=>"w");
    $psn_run_frame -> Label (-text=>"Model file(s):", -font=>$font_bold,-background=>$bgcol
	) -> grid(-row=>2,-column=>1,-sticky=>"ens");
    $psn_run_frame -> Label (-text => $modelfile, -font=>$font_normal, -background=>$bgcol, -foreground=>$grey) -> grid(-row=>2,-column=>2,-sticky=>"w");
    $psn_run_frame -> Label (-text=>" ",-font=>$font_normal, -background=>$bgcol) -> grid(-row=>6,-column=>1,-sticky=>"w");

# ssh
    my $ssh_ref = $ssh_all{$setting_internal{cluster_default}};
    our %ssh = %$ssh_ref;
    my %ssh_new = %ssh;
    my %ssh_descr = %$ssh_descr_ref;
    my @ssh_names = keys (%ssh_all);
    unshift (@ssh_names, $local_run);
    my $ssh_chosen = $setting_internal{cluster_default};

    if ($ssh_chosen eq $local_run) {
	$ssh{connect_ssh} = 0;
    } else {
	$ssh{connect_ssh} = 1;
    }
    my $loc = unix_path($ssh{local_folder});
    my $rem = unix_path($ssh{remote_folder});
    my $run_dir = unix_path ($cwd);
    unless ( $run_dir =~ s/$loc/$rem/i ) {
	$ssh{connect_ssh} = 0;
	$ssh_chosen = $local_run;
    }

    my $psn_background = 0;
    my $psn_command_line;
    if ($psn_type == 0) {
	$psn_command_line = build_psn_run_command ($psn_option, $psn_parameters, $model, \%ssh, \%clusters, $psn_background);
    } else {
	$psn_command_line = $psn_option . " " . $model;
    }
    my $dir = $dir_entry -> get();
    my ($ssh_add, $ssh_add2) = build_ssh_connection (\%ssh, $dir, \%setting);
    my ($text_pre, $text_post) = update_psn_background($psn_background, \%ssh, $dir, \%setting);
    my $pre_text_formatted = $text_pre.$ssh_add;
    if (length($text_pre.$ssh_add)>66) {$pre_text_formatted = substr($text_pre.$ssh_add, 0, 66)."..."} else {};
    my $ssh_label_pre = $psn_run_frame -> Label (-text=>$pre_text_formatted, -font=>$font_fixed_small, -foreground=>$grey
	)->grid(-column=>2, -row=>11, -sticky=>'nws');
    my $ssh_label_post = $psn_run_frame -> Label (-text=>$ssh_add2.$text_post, -font=>$font_fixed_small, -foreground=>$grey
	)->grid(-column=>2, -row=>14, -sticky=>'nws');
    $psn_run_frame -> Label (-text=>" "
	)->grid(-column=>2, -row=>15, -sticky=>'nws');

    my $psn_command_line_entry = $psn_run_frame -> Text (
        -width=>72, -relief=>'sunken', -border=>0, -height=>4, -highlightthickness=>0,
        -font=>$font_fixed_small, -background=>"#FFFFFF", -state=>'normal', -wrap=> 'word'
        )->grid(-column=>2, -row=>12, -columnspan=>1, -rowspan=>2, -sticky=>'nwes', -ipadx=>0);

    $psn_run_button = $psn_run_frame -> Button (-image=> $gif{run}, -state=>'disabled',-background=>$button, -width=>50,-height=>40, -activebackground=>$abutton, -border=>$bbw)
        -> grid(-row=>12, -column=>3, -rowspan=>2, -columnspan=>2, -sticky=>"wens");
    $help -> attach($psn_run_button, "Start run");

    my $nm_text = "NONMEM";
    $psn_run_frame -> Label (-text=>$nm_text.":", -font=>$font_bold, -background=>$bgcol
	) -> grid(-row=>7,-column=>1,-sticky=>"ens");

    my $scm_file;
    if ($psn_option eq "scm") {
	$psn_run_frame -> Label (-text=>" ",-font=>$font_normal, -background=>$bgcol) -> grid(-row=>10,-column=>1,-sticky=>"w");
	$psn_run_frame -> Label (-text=>"SCM config file:", -font=>$font_normal, -background=>$bgcol) -> grid(-row=>9,-column=>1,-sticky=>"w");
	$scm_file = @models[0].".scm";
	# try to guess name of intended scm file
	my @scm = <*.scm>;
	if (@scm > 0) { # use the name of the first available file
	    $scm_file = @scm[0];
	}
	foreach (@scm) { # and if there is one with the run name in it, pick that one 
	    if ($_ =~ m/@models[0]/i) {$scm_file = $_};
	}
	my $types = [
	    ['SCM files','.scm'],
	    ['All Files','*',  ], ];
	my $scm_entry =  $psn_run_frame -> Entry (-textvariable => \$scm_file, -font=>$font_normal,-background=>$white, -state=>'normal', -width=>32,-border=>1, -relief=>'groove',) -> grid(-row=>9,-column=>2,-sticky=>"wens");
	
	$scm_entry -> bind ('<KeyPress>' => sub{
	    $psn_command_line = update_psn_run_command (\$psn_command_line, "-config_file", $scm_file, 1, \%ssh, \%clusters);				
            $psn_command_line_entry -> delete("1.0","end");
            $psn_command_line_entry =~ s/\n//g;
            $psn_command_line_entry -> insert("1.0", $psn_command_line);
	 });
	my $browse_button = $psn_run_frame -> Button(-image=>$gif{browse}, -width=>28, -border=>0,-background=>$button, -activebackground=>$abutton, -command=> sub{
	    my $scm_file_choose = $mw-> getOpenFile(-defaultextension => "*.scm", -initialdir=> $cwd ,-filetypes=> $types);
	    unless ($scm_file_choose eq "") {
		$scm_file = extract_file_name ($scm_file_choose);  # assume it is in the current folder
		$psn_command_line = update_psn_run_command (\$psn_command_line, "-config_file", $scm_file, 1, \%ssh, \%clusters);				
		$psn_command_line_entry -> delete("1.0","end");
		$psn_command_line_entry =~ s/\n//g;
		$psn_command_line_entry -> insert("1.0", $psn_command_line);
		$psn_run_window -> raise();
	    };
	}) -> grid(-row=>9, -column=>3, -rowspan=>1, -sticky => 'nwes');
	$help -> attach ($browse_button, "Browse for scm file"); 
	my $edit_button = $psn_run_frame -> Button(-image=>$gif{notepad}, -width=>26,  -height=>22, -border=>$bbw,-background=>$button,-activebackground=>$abutton,-command=> sub{
	    edit_model($scm_file);
	}) -> grid(-row=>9,-column=>4, -sticky=>'wens');
	$help -> attach ($edit_button, "Edit scm file"); 
	my $new_button = $psn_run_frame -> Button(-image=>$gif{new}, -width=>26,  -height=>22, -border=>$bbw,-background=>$button,-activebackground=>$abutton,-command=> sub{
	    new_scm_file($scm_file);
	}) -> grid(-row=>9,-column=>5, -sticky=>'wens');
	$help -> attach ($new_button, "New scm file"); 
     }

#  my $psn_background = 0;
    $psn_run_frame -> Label (-text=>"Run in background: ", -font=>$font_bold, -background=>$bgcol
	) -> grid(-row=>8,-column=>1,-sticky=>"ens");
    $psn_run_frame -> Checkbutton (-text=>"(without console window)", -variable=> \$psn_background, -font=>$font_normal,  -selectcolor=>$selectcol, -activebackground=>$bgcol, -selectcolor=>$selectcol, -command=> sub{
	($ssh_add, $ssh_add2) = build_ssh_connection (\%ssh, $dir, \%setting);
	($text_pre, $text_post) = update_psn_background($psn_background, \%ssh, $dir, \%setting);

	$pre_text_formatted = $text_pre.$ssh_add;
	if (length($text_pre.$ssh_add)>66) {$pre_text_formatted = substr($text_pre.$ssh_add, 0, 66)."..."};
	$ssh_label_pre -> configure (-text=>$pre_text_formatted);
	$ssh_label_post -> configure (-text=>$ssh_add2.$text_post);
    }) -> grid(-row=>8,-column=>2,-sticky=>"w");
    $psn_run_frame -> Label (-text=>"Cluster:", -font=>$font_bold, -background=>$bgcol
    ) -> grid(-row=>6,-column=>1,-sticky=>"ens");
     $psn_run_frame -> Label (-text=>" ", -font=>$font_normal, -background=>$bgcol
    ) -> grid(-row=>9,-column=>1,-sticky=>"ne");

    $psn_run_frame -> Checkbutton (-text=>"Close this dialog window after starting run", -variable=> \$setting_internal{quit_dialog}, -font=>$font_normal,  -selectcolor=>$selectcol, -activebackground=>$bgcol,  -command=>sub{
	if ($setting_internal{quit_dialog} != $close_prv) { #update internal settings
	    save_ini ($home_dir."/ini/internal.ini", \%setting_internal, \%setting_internal_descr, $base_dir."/ini_defaults/internal.ini");
	}
    }) -> grid(-row=>16,-column=>2,-columnspan=>2,-sticky=>"nw");

    $psn_run_frame -> Label (-text=>"Command prefix:",-font=>$font_small, -background=>$bgcol, -foreground=>$grey
	) -> grid(-row=>11,-column=>1,-sticky=>"nes");
    $psn_run_frame -> Label (-text=>"Command suffix:",-font=>$font_small, -background=>$bgcol, -foreground=>$grey
	) -> grid(-row=>14,-column=>1,-sticky=>"nes");
    $psn_run_frame -> Label (-text=>"PsN command line:\n",-font=>$font_bold, -background=>$bgcol
	) -> grid(-row=>12,-column=>1,-sticky=>"ens");
    # $psn_run_frame -> Label (-text=>" ",-font=>$font_normal, -background=>$bgcol) -> grid(-row=>10,-column=>1,-sticky=>"w");

    $psn_run_frame -> Button (-text=>"History", -background=>$button, -activebackground=>$abutton, -border=>$bbw, -font=>$font_normal , -command=> sub {
        psn_command_history_window ($psn_command_line_entry);
                              }) -> grid(-row=>13,-column=>1,-sticky=>"se");

    my $nm_versions_menu = $psn_run_frame -> Optionmenu(
        -border=>$bbw, -width=>32, -font=>$font_normal, 
	-background=>$lightblue, -activebackground=>$darkblue, -foreground=>$white, -activeforeground=>$white, 
#	-background=>"#c0c0c0", -activebackground=>"#a0a0a0", 
	-command=> sub{
	    unless ($psn_option eq "sumo") { # no need for building the PsN statement
                $psn_command_line = build_psn_run_command ($psn_option, $psn_parameters, $model, \%ssh, \%clusters, $psn_background);
                $psn_command_line = update_psn_run_command (\$psn_command_line, "-nm_version", $nm_version_chosen, 1, \%ssh, \%clusters);				
            }  
	    # update scm config file in run command if necessary
	    if ($psn_option eq "scm") {
		$psn_command_line = update_psn_run_command (\$psn_command_line, "-config_file", $scm_file, 1, \%ssh, \%clusters);				
	    }
	    if ($psn_type == 0) {
		$psn_command_line = build_psn_run_command ($psn_option, $psn_parameters, $model, \%ssh, \%clusters, $psn_background);
	    } else {
		$psn_command_line = $psn_option . " " . $model;
	    }    
            $psn_command_line_entry -> delete("1.0","end");
            $psn_command_line_entry =~ s/\n//g;
            $psn_command_line_entry -> insert("1.0", $psn_command_line);
        })-> grid(-row=>7,-column=>2,-sticky => 'wns');
    $nm_versions_menu -> configure (-options => ["Loading..."], -variable => \$nm_version_chosen,);   

    center_window($psn_run_window, $setting{center_window}); # center after adding frame (redhat)

    # update NM installations
    my $psn_nm_versions_ref = get_psn_nm_versions(\%setting, \%software, \%ssh);
    %psn_nm_versions = %$psn_nm_versions_ref;
    # bit of a workaround to get "default" option as first option...
    my %psn_nm_versions_copy = %psn_nm_versions;
    delete ($psn_nm_versions_copy {"default"});
    my @psn_nm_installations = keys(%psn_nm_versions_copy);
    unshift (@psn_nm_installations, "default");
    $nm_versions_menu -> configure (-options => [@psn_nm_installations], -variable => \$nm_version_chosen,);

    my $ssh_cluster_optionmenu = $psn_run_frame -> Optionmenu(
	-background=>$lightblue, -activebackground=>$darkblue, -foreground=>$white, -activeforeground=>$white, 
	-width=>16, -border=>$bbw, -font=>$font_normal, 
	-options=>\@ssh_names, -textvariable => \$ssh_chosen, -width=>32, -state=>"normal",
	-command=>
    sub{
        # update
	$nm_versions_menu -> configure (-options => ["Loading..."], -variable => \$nm_version_chosen,);   
	$nm_versions_menu -> update();
	my $ssh_ref = $ssh_all{$ssh_chosen};
	our %ssh = %$ssh_ref;
	if ($ssh_chosen eq $local_run) {
	    	$ssh{connect_ssh} = 0;
	} else {
	    	$ssh{connect_ssh} = 1;
	}
	$setting_internal{ssh_connect} = $ssh{connect_ssh};
	$setting_internal{cluster_default} = $ssh_chosen;

	my $loc = unix_path($ssh{local_folder});
	my $rem = unix_path($ssh{remote_folder});
	my $run_dir = unix_path($cwd);
	if ((!( $run_dir =~ s/$loc/$rem/i )) && (!($ssh_chosen eq $local_run))) {
	    print $run_dir ."-". $loc ."-". $rem."\n";
	    message ("Current folder not located on cluster, can't use SSH connect mode.\nPlease check settings.");
	    $ssh{connect_ssh} = 0;
	    $ssh_chosen = $local_run;
	    # update NM installations
	    my $psn_nm_versions_ref = get_psn_nm_versions(\%setting, \%software, \%ssh);
	    %psn_nm_versions = %$psn_nm_versions_ref;
	    # bit of a workaround to get "default" option as first option...
	    my %psn_nm_versions_copy = %psn_nm_versions;
	    delete ($psn_nm_versions_copy {"default"});
	    my @psn_nm_installations = keys(%psn_nm_versions_copy);
	    unshift (@psn_nm_installations, "default");
	    $nm_versions_menu -> configure (-options => [@psn_nm_installations], -variable => \$nm_version_chosen,);
	} else {
	    save_ini ($home_dir."/ini/internal.ini", \%setting_internal, \%setting_internal_descr, $base_dir."/ini_defaults/internal.ini");
	    ($ssh_add, $ssh_add2) = build_ssh_connection (\%ssh, $dir, \%setting);

	    $pre_text_formatted = $text_pre . $ssh_add;
	    if (($ssh{connect_ssh} == 1)&&(($ssh{submit_cmd} ne "")&&($ssh{submit_cmd} ne " "))) {
		$pre_text_formatted = $pre_text_formatted. " " . $ssh{submit_cmd};
	    }

	    if (length($text_pre.$ssh_add)>66) {$pre_text_formatted = substr($text_pre.$ssh_add, 0, 66)."..."};
	    $ssh_label_pre -> configure (-text=>$pre_text_formatted);
	    $ssh_label_post -> configure (-text=>$ssh_add2.$text_post);

	    $psn_command_line = update_psn_run_command (\$psn_command_line, "-nm_version", $nm_version_chosen, 1, \%ssh, \%clusters);
	    $psn_command_line_entry -> delete("1.0","end");
	    $psn_command_line_entry =~ s/\n//g;
	    $psn_command_line_entry -> insert("1.0", $psn_command_line);

	    # update NM installations
	    my $psn_nm_versions_ref = get_psn_nm_versions(\%setting, \%software, \%ssh);
	    %psn_nm_versions = %$psn_nm_versions_ref;
	    # bit of a workaround to get "default" option as first option...
	    my %psn_nm_versions_copy = %psn_nm_versions;
	    delete ($psn_nm_versions_copy {"default"});
	    my @psn_nm_installations = keys(%psn_nm_versions_copy);
	    unshift (@psn_nm_installations, "default");
	    $nm_versions_menu -> configure (-options => [@psn_nm_installations], -variable => \$nm_version_chosen,);
	    	    
	}
	})->grid(-row=>6,-column=>2,-sticky=>'wns');

    $psn_run_button -> configure ( -border=>$bbw, -state=> "normal",-command=> sub {
        my $files = "";
	$psn_run_button -> configure (-state=>'disabled');

        # store the parameter options
        $psn_command_line = $psn_command_line_entry -> get("1.0","end");
        $psn_command_line =~ s/\n//g;
        $psn_params = $psn_command_line;
        $psn_params =~ s/$psn_option//;
        my @models = @$model;
        foreach (@models) {
            $psn_params =~ s/\s$_//;
        }
        $psn_params =~ s/$ssh_login//;
        $psn_params =~ s/$ssh_parameters//;
        $psn_params =~ s/\"+$//;  #remove trailing spaces
        my $psn_nm_version = "";
        @runs = $models_hlist -> selectionGet ();

        psn_history_save_to_log ($psn_command_line);
        exec_run_psn ($psn_command_line, \%ssh, $modelfile, $model_description, $text_pre.$ssh_add, $ssh_add2.$text_post);

        status ();
        #if ($stdout) {$stdout -> yview (scroll=>1, units);}
        chdir ($cwd);

	if ($setting_internal{quit_dialog} == 1) {
	    $help -> detach($psn_run_button);
	    $psn_run_window -> destroy();
	} else {
	    $psn_run_button -> configure (-state=>'normal');
	}

     });
    status ();
}

sub update_psn_conf_window {
    # psn.conf tab
    my $text; my $conf_file = unix_path($software{psn_dir}."/psn.conf");
    if ($ssh{connect_ssh} == 0) { # local
        open (PSN, $software{psn_dir}."/psn.conf");
        my @lines = <PSN>;
        $text = join("", @lines);
        close (PSN);
    } else {
        open (OUT, $ssh{login}.' '.$ssh{parameters}.' "cat '.$ssh{psn_dir}.'/psn.conf'.'" |' );
        while (my $line = <OUT>) {
            $text .= $line;
        }
        close OUT;
        $conf_file = $ssh{psn_dir}.'/psn.conf';
    }  
    return ($text, $conf_file);
}

sub psn_command_history_window {
### Purpose : Show history of PsN commands
### Compat  : W+L+
    my $psn_command_line_entry = shift;
    my $psn_history_window = $mw -> Toplevel(-title=>'PsN command history');
    no_resize ( $psn_history_window );
    $psn_history_window -> OnDestroy ( sub{
      undef $psn_history_window; undef $psn_history_window_frame;
    });
    $psn_history_window_frame = $psn_history_window -> Frame(-background=>$bgcol)->grid(-column=>1, -row=>1, -ipadx=>10,-ipady=>10);
    my $psn_history_hlist;
    $psn_history_hlist = $psn_history_window_frame -> Scrolled('HList', -head => 1,
        -columns    => 1, -scrollbars => 'se', -highlightthickness => 1,
        -height     => 30, -border     => 0, -pady=>2, 
        -width      => 100, -background => 'white',
        -selectbackground => $pirana_orange
    )->grid(-column => 1, -columnspan=>7,-row => 1, -sticky=>"wens");
    my @headers = ( "Command" );
    my @headers_widths = (2000);
    my $headerstyle = $models_hlist -> ItemStyle('window', -padx => 0);
    foreach my $x ( 0 .. $#headers ) {
        @psn_history_headers[$x] = $psn_history_hlist -> HdrResizeButton(
          -text=> $headers[$x], -relief=>'groove', -column=>$x, -font=>$font,
          -background=>$button, -activebackground=>$abutton, -activeforeground=>'black',
          -border=>0, -pady =>$header_pad, -resizerwidth => 2);
        $psn_history_hlist -> header('create', $x,
          -itemtype => 'window', -style=> $headerstyle,
          -widget => @psn_history_headers[$x]
        );
        $psn_history_hlist -> columnWidth($x, @headers_widths[$x]);
    }
    my $log_ref = populate_psn_history($psn_history_hlist);
    my @log = @$log_ref;
    $psn_history_window_frame -> Button(-text=>'Delete history',-font=>$font, -width=>4, -border=>$bbw,-background=>$button,-activebackground=>$abutton,-command=> sub{
	unlink ($home_dir."/log/psn_history.log");
	populate_psn_history($psn_history_hlist);
    })->grid(-row=>2,-column=>1,-sticky=>'news');
    $psn_history_window_frame -> Button(-text=>'Use command',-font=>$font, -width=>4, -border=>$bbw,-background=>$button,-activebackground=>$abutton,-command=> sub{
        my $new_command = @log[$psn_history_hlist -> selectionGet ()];
	unless ($new_command eq "") {
	    $psn_command_line_entry -> delete ("1.0", "end");
	    $psn_command_line_entry -> insert ("1.0", $new_command);
	}
	$psn_history_window -> destroy;
    })->grid(-row=>2,-column=>2,-sticky=>'news');
    $psn_history_hlist -> configure (-command=> sub {
          my $new_command = @log[$psn_history_hlist -> selectionGet ()];
	  unless ($new_command eq "") {
	      $psn_command_line_entry -> delete ("1.0", "end");
	      $psn_command_line_entry -> insert ("1.0", $new_command);
	  }
	  $psn_history_window -> destroy;
     });
    $psn_history_window_frame -> Button(-text=>'Close',-font=>$font, -width=>4, -border=>$bbw,-background=>$button,-activebackground=>$abutton,-command=> sub{
	$psn_history_window -> destroy;
    })->grid(-row=>2,-column=>3,-sticky=>'news');
    return ();
}

sub get_psn_history_chosen();

sub populate_psn_history {
    my $psn_history_hlist = shift;
    my $log_ref = psn_history_read_log();
    my @log = reverse(@$log_ref);
    my $i = 0;
    $psn_history_hlist -> delete("all");
    foreach my $psn_command (@log) {
	chomp($psn_command);
	$psn_history_hlist -> add($i);
	$psn_history_hlist -> itemCreate($i, 0, -text => $psn_command, -style=>$align_left);
	$i++;
    }
    return (\@log);
}

sub psn_history_save_to_log {
    my $command = shift;
    open (LOG, ">>".$home_dir."/log/psn_history.log");
    print LOG $command."\n";
    close LOG;
}

sub psn_history_read_log {
    open (LOG, "<".$home_dir."/log/psn_history.log");
    my @log = <LOG>;
    close LOG;
    return (\@log);
}

sub psn_info_update_text {
    my ($psn_run_text, $psn_text, $psn_run_button) = @_;
    my $psn_localiz = "Local installation of ";
    if ($ssh{connect_ssh} == 1) {
        $psn_localiz = "Remote installation of ";
    }
    if ($psn_text eq "") {
	$psn_text = $psn_localiz."PsN was not found. Please check your settings!";
	$psn_run_button -> configure(-state=>'disabled');
    }
    $psn_run_text -> delete ("0.0",end);
    $psn_run_text -> insert("0.0", $psn_text);
}

sub models_hlist_action {
    @sel = $models_hlist -> selectionGet ();
    foreach (@sel) {
	if ( @file_type_copy[$_] == 2) {
	    edit_model(unix_path($cwd."\\".@ctl_show[$_].".".$setting{ext_ctl}));
	} else {  # change directory
	    $cwd .= @ctl_descr_copy[$_];
	    chdir ($cwd);
	    $cwd = fastgetcwd();
	    refresh_pirana($cwd,$filter,1);
	}
    }
}

sub reload_styles {
  our $dirstyle = $models_hlist->ItemStyle( 'text', -anchor => 'nw',-padx => 3, -pady=> $hlist_pady, -background=>$dir_bgcol, -font => $font_normal);
  our $align_right = $models_hlist->ItemStyle( 'text', -anchor => 'ne',-padx => 3, -pady => $hlist_pady,-background=>'white', -font => $font_normal);
  our $align_right_red = $models_hlist->ItemStyle( 'text', -anchor => 'ne',-padx => 3, -pady => $hlist_pady,-background=>'darkred', -foreground=>'white', -font => $font_normal);
  our $align_left = $models_hlist-> ItemStyle( 'text', -anchor => 'nw',-padx => 3, -pady => 0,-background=>'white', -font => $font_normal );
  our $header_left = $models_hlist->ItemStyle('text',-background=>'gray', -anchor => 'nw', -pady => $hlist_pady, -padx => 2, -font => $font_normal );
  our $header_right = $models_hlist->ItemStyle('text',-background=>'gray', -anchor => 'ne', -pady => $hlist_pady, -padx => 2, -font => $font_normal );
  our $header_right2 = $models_hlist->ItemStyle('text',-background=>"#f5f5f5", -anchor => 'ne', -pady => $hlist_pady, -padx => 2, -font => $font_normal );
  our $green_ofv = $models_hlist->ItemStyle( 'text', -anchor => 'ne',-padx => 3, -pady => $hlist_pady,-foreground=>'#008800', -background=>'white',-font => $font_fixed);
  our $red_ofv = $models_hlist->ItemStyle( 'text', -anchor => 'ne',-padx => 3, -pady => $hlist_pady,-foreground=>'#990000', -background=>'white',-font => $font_fixed);
  our $yellow_ofv = $models_hlist->ItemStyle( 'text', -anchor => 'ne',-padx => 3, -pady => $hlist_pady,-foreground=>'#888800', -background=>'white',-font => $font_fixed);
  our $black_ofv = $models_hlist->ItemStyle( 'text', -anchor => 'ne',-padx => 3,-pady => $hlist_pady, -foreground=>'#000000', -background=>'white',-font => $font_fixed);
  our $bold_left = $models_hlist->ItemStyle( 'text', -anchor => 'nw',-padx => 3,-pady => $hlist_pady, -foreground=>'#000000', -background=>'white',-font => $font_fixed);
  our $bold_right = $models_hlist->ItemStyle( 'text', -anchor => 'ne',-padx => 3, -pady => $hlist_pady,-foreground=>'#000000', -background=>'white',-font => $font_fixed);
  our $estim_style = $models_hlist-> ItemStyle( 'text', -anchor => 'ne', -padx => 3, -pady => $hlist_pady,-background=>'#d0e0f3', -font => $font_normal);
  our $estim_style_red = $models_hlist-> ItemStyle( 'text', -anchor => 'ne', -padx => 3, -pady => $hlist_pady,-background=>'#f3e0d0', -font => $font_normal);
  our $estim_style_left = $models_hlist-> ItemStyle( 'text', -anchor => 'nw', -padx => 3, -pady => $hlist_pady,-background=>'#d0e0f3', -font => $font_normal);
  our $estim_style_light = $models_hlist-> ItemStyle( 'text', -anchor => 'ne', -padx => 3, -pady => $hlist_pady,-background=>'#d5e5ff', -font => $font_normal);
  our $estim_style_se = $models_hlist-> ItemStyle( 'text', -anchor => 'ne',-padx => 3, -pady => $hlist_pady, -background=>'#ffffe5', -font => $font_normal);
}

sub reload_font_sizes {
    my $font_small_size = ($setting{font_size} - 1);
    our $font = $font_family.' '.$setting{font_size};
    our $font_normal =  $font_family.' '.$setting{font_size};
    our $font_small =  $font_family.' '.$font_small_size;
    our $font_fixed = $font_fixed_family.' '.$setting{font_size};
    our $font_fixed_small = $font_fixed_family.' '.$font_small_size;
    our $font_bold =  $font_family.' '.$setting{font_size}.' bold';
}

sub frame_models_show {
### Purpose : Create the frame and the HList object that show the models
### Compat  : W+L+
### Notes   : needs some os-specifics to make the HList look okay.
  if (@_[0]==1) {
#  our $model_hlist_frame = $mw-> Frame(-background=>"$bgcol")->grid(-row=>3,-column=>1,-columnspan=>2,-sticky=>'nswe',-ipadx=>5,-ipady=>0);
  ### Status bar: 
  @models_hlist_headers = ("", " #", "Ref#","Description", "Method","Dataset","OFV","dOFV","S","C","B","Sig","Notes");
  my $sel_type = "";
  our $models_hlist = $mw -> Scrolled('HList',
        -head       => 1,
        -relief     => 'groove',
        -highlightthickness => 0,
        -selectmode => "extended",
	-selectborderwidth => 0,
        -columns    => int(@models_hlist_headers),
        -scrollbars => 'se',
        -height     => $nrows,
        -width      => 105,
        -pady       => 0,
        -padx       => 0,
#        -background => '#',
        -selectbackground => $pirana_orange,
#        -font       => $font_normal,
        -command    => sub { models_hlist_action () },
         -browsecmd   => sub{
           my @sel = $models_hlist -> selectionGet ();
          # get note from SQL
	   if (@file_type_copy[@sel[0]] < 2) {
	       $save_note_button -> configure (-state=>'disabled');
	   }
	   if (@file_type_copy[@sel[0]] == 1) {
	       my $dir = @ctl_show[@sel[0]];
	       $dir =~ s/dir-//;
	       my $notes_text_new = "";
	       if (-e $dir."/command.txt") { 
		   my $psn_text_ref = file_to_text ($dir."/command.txt");
		   $notes_text_new .= "PsN command:\n".$$psn_text_ref;
	       }
	       if (-e $dir."/NM_run1/psn_nonmem_error_messages.txt") { 
		   my $psn_text_ref = file_to_text ($dir."/NM_run1/psn_nonmem_error_messages.txt");
		   $notes_text_new .= "--- NONMEM error messages (NM_run1) -----------\n".$$psn_text_ref;
	       } 	       
	       if (-e $dir."/NM_run2/psn_nonmem_error_messages.txt") { 
		   my $psn_text_ref = file_to_text ($dir."/NM_run2/psn_nonmem_error_messages.txt");
		   $notes_text_new .= "--- NONMEM error messages (NM_run2) -----------\n".$$psn_text_ref;
	       } 	       
	       update_text_box(\$notes_text, $notes_text_new);
	   }
	   if (@file_type_copy[@sel[0]] == 2) {
	       my $mod_file = @ctl_show[@sel[0]].".".$setting{ext_ctl};
	       update_text_box(\$notes_text, $models_notes{@ctl_show[@sel[0]]});
	       $save_note_button -> configure (-state=>'normal');
	       if ($estim_window) {
		   my @lst = @ctl_show[$models_hlist -> selectionGet ()];
		   if (int(@lst) > 1) { 
		       show_estim_multiple (\@lst); 
		   } else {
		       show_estim_window (\@lst);
		   }
		   $estim_window -> raise();
	       }
	   } else {
	       if ($show_model_info==1) { $notes_text -> configure(-state=>"disabled") }
	   }
         }) -> grid(-column => 1, -row => 3, -rowspan=>1, -columnspan=>2, -sticky=>'nswe', -ipady=>0);
  unless ($os =~ m/MSWin/i) {
     $models_hlist -> bind ('<Button-1>' => sub {
        if ($hires_time) { # workaround, on Linux double-click doesn't work due to headers in listbox.
          if ((Time::HiRes::time - $hires_time)<0.25) {
            models_hlist_action();
          }
        }
        our $hires_time = Time::HiRes::time;
      })  ;
  }

# take care of resizing
  my $tab_width = 180;
  if ($^O =~ m/MSWin/) {$tab_width = 150}
  $mw -> gridColumnconfigure(1, -weight => 1, -minsize=>400);
  $mw -> gridColumnconfigure(2, -weight => 100, -minsize=>530);
  $mw -> gridColumnconfigure(3, -weight => 1, -minsize=> $tab_width);
  $mw -> gridRowconfigure(1, -weight => 1, -minsize=>20);
  $mw -> gridRowconfigure(2, -weight => 1, -minsize=>20);
  $mw -> gridRowconfigure(3, -weight => 100, -minsize=>400);
  $mw -> gridRowconfigure(4, -weight => 1, -minsize=>20);

#    if ($os =~ m/darwin/i) {
      $models_hlist -> bind ('<Button-1>' => sub {
        if ($hires_time) {
          if ((Time::HiRes::time - $hires_time)<0.25) {
            models_hlist_action();
          }
        }
        our $hires_time = Time::HiRes::time;
      })  ;
#    }

    $models_hlist -> bind ('<Control-r>' => sub {
	nmfe_command();
    });
    $models_hlist -> bind ('<Control-R>' => sub {
	nmfe_command();
    });
    $models_hlist -> bind ('<Control-e>' => sub {
	psn_command("execute");
    });
    $models_hlist -> bind ('<Control-E>' => sub {
	psn_command("execute");
    });
    $models_hlist -> bind ('<Control-v>' => sub {
	psn_command("vpc");
    });
    $models_hlist -> bind ('<Control-V>' => sub {
	psn_command("vpc");
    });
    $models_hlist -> bind ('<Control-b>' => sub {
	psn_command("bootstrap");
    });
    $models_hlist -> bind ('<Control-B>' => sub {
	psn_command("bootstrap");
    });
    $models_hlist -> bind ('<Control-t>' => sub {
        generate_report_command(\%run_reports);
    });
    $models_hlist -> bind ('<Control-T>' => sub {
        generate_report_command(\%run_reports);
    });
    $models_hlist -> bind ('<Control-d>' => sub {
        duplicate_model_command();
    });
    $models_hlist -> bind ('<Control-D>' => sub {
        duplicate_model_command();
    });
    $models_hlist -> bind ('<Control-l>' => sub {
        view_outputfile_command();
    });
    $models_hlist -> bind ('<Control-L>' => sub {
        view_outputfile_command();
    });
    $models_hlist -> bind ('<Control-p>' => sub {
        show_param_estim_command();
    });
    $models_hlist -> bind ('<Control-P>' => sub {
        show_param_estim_command();
    });
    $models_hlist -> bind ('<Control-plus>' => sub {
	$setting{font_size}++;
	reload_font_sizes();
	reload_styles();
	populate_models_hlist ($setting_internal{models_view}, $condensed_model_list);
	populate_tab_hlist($tab_hlist);
    });
    $models_hlist -> bind ('<Control-minus>' => sub {
	$setting{font_size} =  $setting{font_size} - 1;
	reload_font_sizes();
	reload_styles();
	populate_models_hlist ($setting_internal{models_view}, $condensed_model_list);
	populate_tab_hlist($tab_hlist);
    });
    $models_hlist -> bind ('<Delete>' => sub {
	delete_models_command();
    });

  bind_models_menu($sel_type);

  reload_styles();

  # headers of model list
  our @main_headers;
  if ($os =~ m/MSWin/i) {
    our $header_pad = 0;
  } else {
    our $header_pad = 2;
  }
  my $headerstyle = $models_hlist->ItemStyle('window', -padx => 0, -pady=>0);
  my $font = $font_small;
  if ($os =~ m/MSWin32/i) {$font = $font_normal};
  foreach my $x ( 0 .. $#models_hlist_headers ) {
        if (($x == 3)||($x == 7)) {$style = $header_right} else {$style = $header_left};
        @main_headers[$x] = $models_hlist-> HdrResizeButton(
          -text => $models_hlist_headers[$x], -relief => 'flat', -font=>$font,
          -background=>$button, -activebackground=>$abutton, -activeforeground=>'black',
          -border=> 0, -pady => $header_pad, -resizerwidth => 2, -minwidth=>1,
          -column => $x
        );
        $models_hlist -> header('create', $x,
          -itemtype => 'window', -style => $headerstyle,
          -widget => @main_headers[$x]
        );
        $models_hlist -> columnWidth($x, @models_hlist_widths[$x]);
  }
  $models_hlist -> bind('<Leave>' => sub {
      if ( $setting_internal{models_view} eq "list") {
	  save_header_widths();
      }
  });
  $models_hlist -> update();

#   my $frame_command = $mw -> Frame(-background=>"#000000") ->grid(-row=>1, -column=>3, -columnspan=>4, -ipadx=>'0',-ipady=>'0',-sticky=>'wne');
#   my $show_buttons = $frame_dir -> Frame(-background=>"#880000") ->grid(-row=>2,-column=>7,-rowspan=>1,-ipadx=>'0', -ipady=>'0',-sticky=>'nes');
  my $show_buttons = $mw -> Frame(-background=>$bgcol) ->grid(-row=>2,-column=>2,-rowspan=>1,-ipadx=>'0', -ipady=>'0',-sticky=>'nes');
  our $psn_dir_filter = 0;
  $show_buttons -> Label(-text=>"   ", -font=>$font_normal, -background=>$bgcol)->grid (-row=>1,-column=>1, -columnspan=>1, -sticky=>'ws');
  $show_buttons -> Label(-text=>"          ", -font=>$font_normal, -background=>$bgcol)->grid (-row=>1,-column=>3, -columnspan=>1, -sticky=>'es');
  $filter_psn_button = $show_buttons ->Checkbutton(-text=>"PsN / nmfe folders  ", -background=>$bgcol, -font=>$font_normal, -variable=>\$psn_dir_filter, -selectcolor=>$selectcol, -activebackground=>$bgcol, -command=>sub{
     read_curr_dir($cwd, $filter, 1);
     status();
  })->grid(-row=>1,-column=>2,-sticky=>'wn', -ipady=>0, -ipadx=>0);
  $help->attach($filter_psn_button, -msg => "Filter out PsN-generated directories");

  my $show_buttons_sub = $show_buttons -> Frame(-background=>$bgcol) ->grid(-row=>1,-column=>4,-rowspan=>2,-ipadx=>'0', -ipady=>'0',-sticky=>'ne');
  $show_buttons_sub -> Label(-text=>"     ", -font=>$font_normal, -background=>$bgcol)->grid (-row=>1,-column=>10, -columnspan=>1, -sticky=>'ws');
  
  my $condensed_view_button = $show_buttons_sub -> Button (
       -image=>$gif{binocular}, -background => $button, -border=>$bbw, -activebackground=>$abutton,
       -width=>26, -height=>22,
       -command=>sub{
           $condensed_model_list = 1 - $condensed_model_list;
  	   populate_models_hlist ($setting_internal{models_view}, $condensed_model_list);
      })->grid(-row=>1,-column=>1,-sticky=>'wens');
  $help->attach($condensed_view_button, -msg => "Show condensed or expanded view of models");

  if ($setting_internal{models_view} eq "tree") {$listimage = $gif{treeview}} else {$listimage = $gif{listview}};
  our $sort_button = $show_buttons_sub->Button(-image=>$listimage, -width=>26, -height=>22, -border=>$bbw,-background=>$button,-activebackground=>$abutton,-command=> sub{
    if ($setting_internal{models_view} eq "tree") {
       $setting_internal{models_view} = "list";
       $listimage = $gif{listview};
    } else {
       $setting_internal{models_view} = "tree";
       $listimage = $gif{treeview};
    }
    $sort_button -> configure (-image=>$listimage);
    populate_models_hlist($setting_internal{models_view}, $condensed_model_list);
  })->grid(-row=>1,-column=>2,-sticky=>'wens');
  $help->attach($sort_button, -msg => "Show models as list or as tree structure, based on their reference model");

  my $show_execution_log = $show_buttons_sub -> Button (-image=>$gif{log}, -background=>$button,-activebackground=>$abutton, -border=>0,
	  -command=>sub {
      show_exec_runs_window();
    })->grid(-row=>1,-column=>3,-sticky=>'wens');
  $help->attach($show_execution_log, -msg => "Show model execution log");

  our $sge_monitor_button = $show_buttons_sub -> Button(-image=>$gif{cluster}, -state=>'normal', -border=>$bbw, -background=>$button,-activebackground=>$abutton, -command=>sub {sge_monitor_window();
      })->grid(-row=>1,-column=>4,-columnspan=>1,-sticky=>'wens');
  $help->attach($sge_monitor_button, -msg => "SGE montitor");
#  if ($^O =~ m/MSWin/) { $sge_monitor_button -> configure(-state=>'disabled');}

  our $show_inter_button = $show_buttons_sub->Button(-image=>$gif{edit_inter},-width=>26, -height=>24, -border=>$bbw,-background=>$button, -activebackground=>$abutton,-command=>sub{
      $cwd = $dir_entry -> get();
      chdir($cwd);
      show_inter_window($cwd);
      if ($inter_window) {$inter_window -> focus();}
      })->grid(-row=>1,-column=>5,-sticky=>'wens');
  $help->attach($show_inter_button, -msg => "Show intermediate results for models\ncurrently running in this directory");

  our $show_estim_button = $show_buttons_sub->Button(-image=>$gif{estim},-width=>26, -height=>24, -border=>$bbw,-background=>$button, -activebackground=>$abutton,-command=>sub{
      show_param_estim_command ();
      })->grid(-row=>1,-column=>6,-sticky=>'wens');
  $help->attach($show_estim_button, -msg => "Show/compare parameter estimates from runs");

}

sub create_mod_buttons {
  our $mod_buttons = $run_frame -> Frame(-background=>$bgcol) ->grid(-row=>1,-column=>1,-rowspan=>1,-ipadx=>'0', -ipady=>'0',-sticky=>'nw');

  our $new_button = $mod_buttons->Button(-image=>$gif{newfolder}, -width=>26,  -height=>22, -border=>$bbw,-background=>$button,-activebackground=>$abutton,-command=> sub{
    new_dir();})
    ->grid(-row=>1,-column=>1,-sticky=>'wens');
  $help->attach($new_button, -msg => "New folder");

  our $new_button = $mod_buttons->Button(-image=>$gif{new}, -width=>26,  -height=>22, -border=>$bbw,-background=>$button,-activebackground=>$abutton,-command=> sub{
    new_ctl();})
    ->grid(-row=>1,-column=>2,-sticky=>'wens');
  $help->attach($new_button, -msg => "New model");

  our $wizard_button = $mod_buttons->Button(-image=>$gif{wizard},-width=>26, -height=>24, -border=>$bbw,-background=>$button, -activebackground=>$abutton,-command=>sub{
      wizard_window();
  })->grid(-row=>1,-column=>3,-sticky=>'wens');
  $help->attach($wizard_button, -msg => "Wizards...");

  our $sum_list_button = $mod_buttons -> Button(-image=>$gif{compare}, -state=>'normal', -width=>26, -height=>24, -border=>$bbw, -background=>$button,-activebackground=>$abutton,-command=>sub{
#      my $save_file = $mw -> getSaveFile (-defaultextension=>".csv", -filetypes=>$types, -title=>"Save R script as", -initialdir => $cwd);
      create_output_summary_csv ("pirana_run_summary.csv", \%setting, \%models_notes, \%models_descr, $mw);
      if (-e $software{spreadsheet}) {
	  start_command($software{spreadsheet},'"pirana_run_summary.csv"');
      } else {message("Spreadsheet application not found. Please check settings.")};
      status ();
  }) ->grid(-row=>2,-column=>1,-columnspan=>1,-sticky=>'wens');
  $help->attach($sum_list_button, -msg => "Generate summary (csv-file) of all NONMEM output files");

  our $cleanup_dir_button = $mod_buttons->Button(-image=>$gif{clean_dir},-width=>26, -height=>24, -border=>$bbw,-background=>$button, -activebackground=>$abutton,-command=>sub{
      cleanup_runtime_files_window();
  })->grid(-row=>2,-column=>2,-sticky=>'wens');
  $help->attach($cleanup_dir_button, -msg => "Clean up runtime files in current folder");

  our $cov_calc_button = $mod_buttons->Button(-image=>$gif{calc_cov},-width=>26, -height=>24, -border=>$bbw,-background=>$button, -activebackground=>$abutton,-command=>sub{
      cov_calc_window();
  })->grid(-row=>2,-column=>3,-sticky=>'wens');
  $help->attach($cov_calc_button, -msg => "Covariance / correlation calculator");

### removed temporarily. Probably not very much-used functionality.
#  our $tree_txt_button = $mod_buttons -> Button(-image=>$gif{treeview2}, -state=>'normal', -width=>26, -height=>24, -border=>$bbw, -background=>$button,-activebackground=>$abutton,-command=>sub{
#    my($tree_models_ref, $tree_text) = tree_models();
#    text_window($mw, $tree_text, "Model tree");
#  }) ->grid(-row=>1,-column=>10,-columnspan=>1,-sticky=>'wens');
#  $help->attach($tree_txt_button, -msg => "Generate run record as tree");

#  $mod_buttons -> Label (-text=>"Models: ", -font=>$font_normal, -background=>$bgcol)
#   ->grid(-row=>1,-column=>1,-sticky=>'wens');
#  $mod_buttons -> Label (-text=>"       Runs: ", -font=>$font_normal, -background=>$bgcol)
#   ->grid(-row=>2,-column=>1,-sticky=>'wens');

### functionality removed temporarily. Too unstable, due to buggy Statistics::R module
#  our $piranaR_button = $mod_buttons -> Button(-image=>$gif{pirana_r}, -state=>'normal', -width=>26, -height=>24, -border=>$bbw, -background=>$button,-activebackground=>$abutton,-command=>sub{
#      create_window_piranaR ($mw, "", 0);
#  }) ->grid(-row=>1,-column=>13,-columnspan=>1,-sticky=>'wens');
#  $help->attach($piranaR_button, -msg => "Open PiranaR interface");

}

sub show_run_frame {
  ($nm_dirs_ref, $nm_vers_ref) = read_ini($home_dir."/ini/nm_inst_local.ini");
  %nm_dirs = %$nm_dirs_ref; %nm_vers = %$nm_vers_ref;
  if (-e $home_dir."/log/pirana.log") {  # read last used NM installation
          read_log();
  }

  # spacer
  our $run_color=$lightblue; our $arun_color=$darkblue;

  if ($setting{default_method} =~ m/nmq/gi) {$run_method = "NONMEM"};
  if ($setting{default_method} =~ m/psn/gi) {$run_method = "PsN"; $nm_version_chosen = "default"};
  if ($setting{default_method} =~ m/wfn/gi) {$run_method = "WFN"};
  if ($setting{default_method} =~ m/nmfe/gi) {$run_method = "NONMEM"};

  # Notes
  my $spacer = 0;
#  if ($os =~ m/MSWin/i) {$spacer = 14; };
  $run_frame = $mw -> Frame(-background=>$bgcol)->grid(-row=>4,-column=>1,-columnspan=>2, -rowspan=>1, -sticky => 'wens', -ipady=>0);
  $run_frame -> Label(-text=>" ", -width=>$spacer, -font=>"Courier 1", -background=>$bgcol)->grid(-column=>6, -row=>1);  #spacer
  create_mod_buttons(); 
  $run_frame -> gridColumnconfigure(1, -weight => 1, -minsize=>30);
  $run_frame -> gridColumnconfigure(2, -weight => 100, -minsize=>100);
  $run_frame -> gridColumnconfigure(4, -weight => 1, -minsize=>30);

  if ($setting{font_size} == 2) {$note_width=40} else {$note_width = 29};
  if ($full_screen==0) {$entry_width = 72};
  our $notes_text = $run_frame -> Scrolled ('Text', -scrollbars=>'e',
      -width=>$entry_width, -relief=>'groove', -border=>2, -height=>5,
      -font=>$font_small, -background=>$entry_color, -state=>'normal'
  )->grid(-column=>2, -row=>1, -rowspan=>2, -columnspan=>2, -sticky=>'nwse', -ipadx=>0, -ipady=>0);

  my $colorbox_width = 1; my $colorbox_height=0;
  if($os =~ m/MSWin/i) { $colorbox_width = 4; $colorbox_height=2};
  $colors_frame = $run_frame -> Frame (-background=>$bgcol)->grid(-column=>4, -row=>1, -rowspan=>1,-sticky=>'wns', -ipady=>0);
  $colors_frame -> Button (-text=>'', -border=>0,-width=>$colorbox_width, -height=>$colorbox_height, -background=>$darkred, -activebackground=>$lightred, -font=>'Arial 5', -command=> sub {
    status("Saving color information...");
    note_color ($lightred);
    status();
  })->grid(-column=>2, -row=>2,-rowspan=>1,-sticky=>'nwse');
  $colors_frame -> Button (-text=>'', -border=>0,-width=>$colorbox_width, -height=>$colorbox_height, -background=>$darkgreen, -activebackground=>$lightgreen, -font=>'Arial 5', -command=> sub {
    status("Saving color information...");
    note_color ($lightgreen);
    status();
  })->grid(-column=>3, -row=>2,-rowspan=>1,-sticky=>'nwes');
  $colors_frame -> Button (-text=>'', -border=>0,-width=>$colorbox_width, -height=>$colorbox_height, -background=>$lighterblue, -activebackground=>$lightestblue, -font=>'Arial 5', -command=> sub {
    status("Saving color information...");
    note_color ($lighterblue);
    status();
  })->grid(-column=>4, -row=>2,-rowspan=>1,-sticky=>'nwse');
  $colors_frame -> Button (-text=>'', -border=>0,-width=>$colorbox_width, -height=>$colorbox_height, -background=>'white', -activebackground=>'white', -font=>'Arial 5', -command=> sub {
    status("Saving color information...");
    note_color ("#FFFFFF");
    status();
  })->grid(-column=>2, -row=>3,-rowspan=>1,-sticky=>'nwse');
  $colors_frame -> Button (-text=>'', -border=>0,-width=>$colorbox_width, -height=>$colorbox_height, -background=>$darkyellow, -activebackground=>$lightyellow, -font=>'Arial 5', -command=> sub {
    status("Saving color information...");
    note_color ($lightyellow);
    status();
  })->grid(-column=>3, -row=>3,-rowspan=>1,-sticky=>'nwes');
  $colors_frame -> Button (-text=>'',-border=>0,-width=>$colorbox_width, -height=>$colorbox_height,-background=>$abutton, -activebackground=>$button, -font=>'Arial 5', -command=> sub {
    status("Saving color information...");
    note_color ($button);
    status();
  })->grid(-column=>4, -row=>3,-rowspan=>1,-sticky=>'nwse');
  our $save_note_button = $colors_frame -> Button (-text => "Save note", -border=>$bbw, -background=>$button,
    -activebackground=>$abutton, -font=>$font_normal, -command=> sub{
	my @sel = $models_hlist -> selectionGet ();
	my $model_id = @ctl_show[@sel[0]];
	my $model_info_db = db_read_model_info ($model_id, "pirana.dir");
	my $row = @{$model_info_db}[0];
	my ($model_id, $ref_mod, $descr, $note_small, $note) = @$row;
	$descr_new = $descr;
	my $model_notes = $notes_text -> get("0.0", "end");
	chomp ($model_notes);
	$model_notes =~ s/\'//g; # strip '
	$model_notes =~ s/\"//g; # strip "
	db_insert_model_info ($model_id, $descr, $model_notes, "pirana.dir");
	if ($descr_new ne $descr) {change_model_description($model_id, $descr_new)};
	$models_notes{$model_id} = $model_notes;
	my $note_strip = $model_notes;
	if ($condensed_model_list == 1) {$note_strip =~ s/\n/\ /g;}
	$models_hlist -> itemConfigure(@sel[0], 12, -text => $note_strip);
	$models_hlist -> update();
	return(1);
  }) -> grid (-column=>2, -columnspan=>3,-row=>1, -sticky=>"news");

  }
}

sub table_info_window {
### Purpose : Open a dialog window in which table/file info (size / notes) are shown and can be edited
### Compat  : W+L+?
  my $file = shift; my $mod; my $file_descr=$table_descr{$file};
  my $file_notes = $table_note{$file}; my $creator=$table_creator{$file};
  my $table_info_window = $mw -> Toplevel(-title=>'File properties');
  no_resize ($table_info_window);
  my $table_info_frame = $table_info_window -> Frame(-relief=>'groove', -border=>0, -padx=>7, -pady=>7)->grid(-ipadx=>'10',-ipady=>'10',-sticky=>'n');
  $table_info_frame -> Label (-text=>"Filename:\n",-font=>$font) -> grid(-row=>2, -column=>1,-sticky=>"en");
  $table_info_frame -> Entry (-background=>$white,-font=>$font, -text=>unix_path($cwd."/".$file),-font=>$font_normal, -relief=>'sunken', -background=>$button, -border=>0, -width=>60, -state=>'disabled') -> grid(-row=>2, -column=>2,-sticky=>"wn");
  $table_info_frame -> Label (-text=>"Last modified:\n",-font=>$font) -> grid(-row=>3, -column=>1, -sticky=>"en");
  if (-e $file) {$mod_time = localtime(@{stat $file}[9])};
  $table_info_frame -> Entry (-background=>$white,-font=>$font, -text=> $mod_time, -font=>$font_normal, -width=>24, -state=>'disabled',-relief=>'sunken', -border=>0, -background=>$button) -> grid(-row=>3, -column=>2,-sticky=>"wn");
  $table_info_frame -> Label (-text=>"Creator:\n",-font=>$font) -> grid(-row=>4, -column=>1, -sticky=>"en");
  $table_info_frame -> Entry (-background=>$white,-font=>$font, -textvariable=> \$creator, -font=>$font_normal, -width=>45, -state=>'normal',-relief=>'sunken', -border=>0, -background=>'white') -> grid(-row=>4, -column=>2,-sticky=>"wn");

  $table_info_frame -> Label (-text=>"Description:\n",-font=>$font) -> grid(-row=>5, -column=>1, -sticky=>"en");
  $table_info_frame -> Entry (-background=>$white,-font=>$font, -textvariable=> \$file_descr, -font=>$font_normal, -width=>45, -state=>'normal',-relief=>'sunken', -border=>0, -background=>'white') -> grid(-row=>5, -column=>2,-sticky=>"wn");

  $table_info_frame -> Label (-text=>"Notes:\n",-font=>$font) -> grid(-row=>8, -column=>1, -sticky=>"en");
  $table_info_notes = $table_info_frame -> Text (-width=>45,-font=>$font, -font=>$font_normal, -height=>10, -state=>'normal',-relief=>'sunken', -border=>0, -background=>'white') -> grid(-row=>8, -column=>2,-sticky=>"wn");
  $table_info_notes -> insert('end', $file_notes);
  $table_info_frame -> Label (-text=>" ",-font=>$font) -> grid(-row=>9, -column=>3, -sticky=>"en");

  $table_info_frame -> Button (-text=>"Save and close",-font=>$font, -width=>15, -background=>$button, -border=>$bbw, -activebackground=>$abutton, -command=> sub {
    $file_notes = $table_info_notes -> get("0.0", "end");
    my $update = 0;
    if(grep $_ eq $file, keys(%table_descr)) {$update=1};
    db_insert_table_info ($file, $file_descr, $creator, $file_notes, $update, "pirana.dir");
    $table_descr{$file} = $file_descr;
    $table_creator{$file} = $creator;
    $table_note{$file} = $file_notes;
    my $mod_time;
    if (-e $cwd."/".$file) {$mod_time = localtime(@{stat $cwd."/".$tab_file}[9])};
    my $note = $table_note{$file};
    $note =~ s/\n/ /g;
    my $update_text = (-s $file)." kB\n";
    $update_text .= substr($mod_time,4)."\n";
    $update_text .= $note;
    update_text_box(\$tab_file_info, $update_text);
    $table_info_window -> destroy();
    return();
  }) -> grid(-row=>10, -column=>2, -sticky=>"wn");
  $table_info_frame -> Button (-text=>"Cancel",-font=>$font, -width=>15, -background=>$button, -border=>$bbw, -activebackground=>$abutton, -command=> sub {
    $table_info_window -> destroy();
    return();
  }) -> grid(-row=>10, -column=>1, -sticky=>"en");
  #$model_prop_frame -> Label (-text=>" ") -> grid(-row=>20, -column=>3, -sticky=>"en");
  center_window($table_info_window, $setting{center_window}); # center after adding frame (redhat)
}

sub model_properties_window {
### Purpose : Open a dialog window in which model properties are shown and can be edited
### Compat  : W+L+?
  my ($model_id, $idx) = @_;
  my $model_info_db = db_read_model_info ($model_id, "pirana.dir");
  my $row = @{$model_info_db}[0];
  my ($model_id, $ref_mod, $descr, $note_small, $note) = @$row;
  $descr_new = $descr;
  my $model_prop_window = $mw -> Toplevel(-title=>'Model properties');
  no_resize ($model_prop_window);
  my $model_prop_frame = $model_prop_window -> Frame(-relief=>'groove', -background=>$bgcol, -border=>0, -padx=>7, -pady=>7)->grid(-ipadx=>'10',-ipady=>'10',-sticky=>'n');
  $model_prop_frame -> Label (-text=>"Model no:\n",-font=>$font,-background=>$bgcol) -> grid(-row=>1, -column=>1,-sticky=>"en");
  $model_prop_frame -> Entry (-text=>$model_id,-font=>$font, -background=>$bgcol, -font=>$font_normal, -width=>15, -state=>'disabled', -disabledforeground=>'#727272',-relief=>'sunken', -border=>0, -background=>$button) -> grid(-row=>1, -column=>2,-sticky=>"wn");
  $model_prop_frame -> Label (-text=>"Filename:\n",-font=>$font, -background=>$bgcol) -> grid(-row=>2, -column=>1,-sticky=>"en");
  $model_prop_frame -> Entry (-text=>unix_path($cwd."/".$model_id.".".$setting{ext_ctl}),-background=>$bgcol,-font=>$font_normal, -disabledforeground=>'#727272', -relief=>'sunken', -background=>$button,-font=>$font, -border=>0, -width=>50, -state=>'disabled') -> grid(-row=>2, -column=>2,-sticky=>"wn");
  $model_prop_frame -> Label (-text=>"Last modified:\n",-font=>$font, -background=>$bgcol) -> grid(-row=>3, -column=>1, -sticky=>"en");
  my $mod = localtime($models_dates_db{$model_id});
  $model_prop_frame -> Entry (-text=> $mod,-font=>$font,-background=>$bgcol, -font=>$font_normal, -width=>24, -state=>'disabled',-disabledforeground=>'#727272',-relief=>'sunken', -border=>0, -background=>$button) -> grid(-row=>3, -column=>2,-sticky=>"wn");
  $model_prop_frame -> Label (-text=>"Dataset:\n",-font=>$font, -background=>$bgcol) -> grid(-row=>4, -column=>1, -sticky=>"en");
  $model_prop_frame -> Entry (-text=> $models_dataset{$model_id},-font=>$font, -background=>$bgcol, -font=>$font_normal, -width=>24, -state=>'disabled',-disabledforeground=>'#727272',-relief=>'sunken', -border=>0, -background=>$button) -> grid(-row=>4, -column=>2,-sticky=>"wn");
  $model_prop_frame -> Label (-text=>"Description:\n",-font=>$font, -background=>$bgcol) -> grid(-row=>5, -column=>1, -sticky=>"en");
  $model_prop_frame -> Entry (-text=> $descr_new,-font=>$font, -background=>$bgcol, -font=>$font_normal, -width=>45, -state=>'disabled', -disabledforeground=>'#727272', -relief=>'sunken', -border=>0, -background=>'white') -> grid(-row=>5, -column=>2,-sticky=>"wn");
  $model_prop_frame -> Label (-text=>"Reference model:\n",-font=>$font, -background=>$bgcol) -> grid(-row=>6, -column=>1, -sticky=>"en");
  $model_prop_frame -> Entry (-text=> $ref_mod,-font=>$font, -background=>$bgcol, -font=>$font_normal, -width=>10, -state=>'disabled',-disabledforeground=>'#727272',-relief=>'sunken', -border=>0, -background=>'white') -> grid(-row=>6, -column=>2,-sticky=>"wn");
  $model_prop_frame -> Label (-text=>"Notes:\n",-font=>$font,-background=>$bgcol) -> grid(-row=>8, -column=>1, -sticky=>"en");
  $model_prop_notes = $model_prop_frame -> Text (-background=>$bgcol,-font=>$font,-width=>45, -font=>$font_normal, -height=>10, -state=>'normal',-relief=>'sunken', -border=>0, -background=>'white') -> grid(-row=>8, -column=>2,-sticky=>"wn");
  $model_prop_frame -> Label (-text=>" ",-font=>$font,-background=>$bgcol) -> grid(-row=>9, -column=>3, -sticky=>"en");
  $model_prop_notes -> insert("end", $note);

  $model_prop_frame -> Button (-text=>"Save",-font=>$font, -width=>15, -background=>$button, -border=>$bbw, -activebackground=>$abutton, -command=> sub {
      $model_notes = $model_prop_notes -> get("0.0", "end");
      chomp ($model_notes);
      $model_notes =~ s/\'//g; # strip '
      $model_notes =~ s/\"//g; # strip "
      db_insert_model_info ($model_id, $descr, $model_notes, "pirana.dir");
      if ($descr_new ne $descr) {change_model_description($model_id, $descr_new)};
      $models_notes{$model_id} = $model_notes;
      my $note_strip = $model_notes;
      if ($condensed_model_list == 1) {$note_strip =~ s/\n/\ /g;}
      $models_hlist -> itemConfigure($idx, 12, -text => $note_strip);
      $models_hlist -> update();
      $model_prop_window -> destroy();
      return(1);
    }) -> grid(-row=>10, -column=>2, -sticky=>"wn");
  $model_prop_frame -> Button (-text=>"Cancel",-font=>$font, -width=>15, -background=>$button, -border=>$bbw, -activebackground=>$abutton, -command=> sub {
    $model_prop_window -> destroy();
    return(1);
  }) -> grid(-row=>10, -column=>1, -sticky=>"en");
  center_window($model_prop_window, $setting{center_window}); # center after adding frame (redhat)
}

sub update_text_box {
### Purpose : Update the specified text-box with text (used for updating information boxes about model / table-file info)
### Compat  : W+L+
  my($obj_ref, $text) = @_;
  $obj = $$obj_ref;
  if ($show_model_info == 1) {
      $obj -> configure(-state=>"normal");
      $obj -> delete("0.0","end");
      $obj -> insert ("0.0", $text);
#      $obj -> configure(-state=>"disabled");
  }
}

sub note_color {
### Purpose : Give the selected model/result a color
### Compat  : W+L+
  my $color = shift;

  my @sel = $models_hlist -> selectionGet ();
  foreach my $no (@sel) {
    if ($file_type{@ctl_show[$no]} == 2) {
      $models_colors {$no} = $color;
      # determine style colors
      $runno = @ctl_show[$no];
      my $mod_background = "#FFFFFF";
      if ($color ne "#FFFFFF") {
         $mod_background = $color;
      }
      if (even($no)) {$mod_background = dark_row_color($mod_background)};
      my $style_color = $models_hlist->ItemStyle( 'text', -anchor=>'nw', -padx => 5, -background=>$mod_background, -font=>$font_normal);
      my $style_color_small = $models_hlist->ItemStyle( 'text', -anchor=>'nw',-padx => 5, -background=>$mod_background, -font=>$font_small);
      our $style        = $models_hlist-> ItemStyle( 'text', -anchor => 'nw',-padx => 5, -background=>$mod_background, -font => $font_normal);
 #      if (($res_ofv{$runno} ne "")&&($res_ofv{$models_refmod{$runno}} ne "")) {
 #       my $ofv_diff = $res_ofv{$models_refmod{$runno}} - $res_ofv{$runno} ;
 #       if ($ofv_diff >= $setting{ofv_sign}) { $style_ofv = $style_green; }
 #       if ($ofv_diff < 0) { $style_ofv = $style_red; }
 #       if (($ofv_diff >= 0)&&($ofv_diff < $setting{ofv_sign})) {
 #         $style_ofv = $models_hlist->ItemStyle( 'text', -anchor => 'ne',-padx => 5, -foreground=>'#A0A000', -background=>$mod_background,-font => $font_bold);
 #       }
 #     } else {$style_ofv = $models_hlist->ItemStyle( 'text', -anchor => 'ne',-padx => 5, -foreground=>'#000000', -background=>$mod_background,-font => "Courier 9 bold");}
      if ($models_suc{$runno} eq "S") {$style_success = $style_green} else {$style_success = $style_red};
      if ($res_cov{$runno} eq "C") {$style_cov = $style_green} else {$style_cov = $style_red};
      $models_hlist -> itemConfigure($no, 0, -style => $style_color);
      $models_hlist -> itemConfigure($no, 1, -style => $style_color);
      $models_hlist -> itemConfigure($no, 2,-style => $style_color_small);
      $models_hlist -> itemConfigure($no, 3, -style => $style_color);
      $models_hlist -> itemConfigure($no, 4,-style => $style_color);
      $models_hlist -> itemConfigure($no, 5, -style => $style_color);
      $models_hlist -> itemConfigure($no, 6, -style => $style_color);
      $models_hlist -> itemConfigure($no, 7, -style => $style_color);
      $models_hlist -> itemConfigure($no, 8, -style => $style_color);
      $models_hlist -> itemConfigure($no, 9, -style => $style_color);
      $models_hlist -> itemConfigure($no, 10,-style => $style_color);
      $models_hlist -> itemConfigure($no, 11, -style => $style_color);
      $models_hlist -> itemConfigure($no, 12, -style => $style_color);
      db_add_color (@ctl_show[$no], $color, "pirana.dir")
    }
  }
}

sub wfn_run_window {
    (my $model, my $wfn_command) = @_;
    my $modelfile = $model.".".$setting{ext_ctl};
    my $wfn_run_window = $mw -> Toplevel(-title=>'Run '.$wfn_command.' ('.$model.")");
    my $wfn_run_frame  = $wfn_run_window -> Frame (-background=>$bgcol)-> grid(-ipadx=>8, -ipady=>8);
    $wfn_run_frame -> Label(-text=>"Model:", -font=>$font, -background=>$bgcol) -> grid (-row=>1, -column=>1, -sticky=>"ne");
    $wfn_run_frame -> Label(-text=>"WFN command line:", -font=>$font, -background=>$bgcol) -> grid (-row=>2, -column=>1, -sticky=>"ne");
    $wfn_run_frame -> Label(-text=>"Compiler argument:", -font=>$font, -background=>$bgcol) -> grid (-row=>3, -column=>1, -sticky=>"ne");
    $wfn_run_frame -> Label(-text=>" ", -font=>$font, -background=>$bgcol) -> grid (-row=>4, -column=>1, -sticky=>"nw");

    my $wfn_command_line = $wfn_command." ".$model;
    if ($wfn_command =~ m/NMBS/i) {
	$wfn_command_line .= " ".$setting{wfn_nmbs};
    }
    my $wfn_compiler_arg = $setting{wfn_param};
    $wfn_run_frame -> Entry(-textvariable=> \$model, -font=>$font, -border=>$bbw, -background=>"#FFFFFF") -> grid (-row=>1, -column=>2, -sticky=>"nw");
    $wfn_run_frame -> Entry(-textvariable=> \$wfn_command_line, -font=>$font,-border=>$bbw, -background=>"#FFFFFF") -> grid (-row=>2, -column=>2, -sticky=>"nw");
    $wfn_run_frame -> Entry(-textvariable=> \$wfn_compiler_arg, -font=>$font,-border=>$bbw, -background=>"#FFFFFF") -> grid (-row=>3, -column=>2, -sticky=>"nw");

    # remove prior wfn run bat-files

    my $wfn_run_button = $wfn_run_frame -> Button (-image=> $gif{run}, -background=>$button, -width=>50,-height=>40, -activebackground=>$abutton, -border=>$bbw, -command=> sub {
	# save compiler settings if changed
	if ($wfn_compiler_arg ne $software{wfn_param}) {
	    $setting{wfn_param} = $wfn_compiler_arg;
	    save_ini ($home_dir."/ini/settings.ini", \%setting, \%setting_descr, $base_dir."/ini_defaults/settings.ini");
	}
	my $wfn_start_file = "pirana_".$wfn_command."_".$model.".bat";
	open (WFN, ">".$wfn_start_file);
	print WFN "echo Initializing WFN...\n";
	print WFN "CALL ".win_path($software{wfn_dir}."\\bin\\wfn.bat")." ".$wfn_compiler_arg."\n";
	print WFN "echo Starting ".$wfn_command."...\n";
	print WFN "CALL ".$wfn_command_line."\n";
	close WFN;
	system ("start ".$wfn_start_file);
	$wfn_run_window -> destroy();
    }) -> grid(-row=>10, -column=>2,-sticky=>"wns");
#    $help -> attach($wfn_run_button, "Start run using WFN");
    center_window($wfn_run_window, $setting{center_window});
}

sub create_wfn_start_script {
    my ($file, $wfn_option, $setting_ref ) = @_;
    my %setting = %$setting_ref;
    $rand_filename = "pirana_wfn_".generate_random_string(4);
    if ($wfn_option =~ m/nmbs/i) {
        my $count =0;
        foreach (@idx) {
	    copy ($file.".".$setting{ext_ctl}, $file."_bs_".$_.".".$setting{ext_ctl});
	    open (BAT_RUN,">".$rand_filename."_".$_.".bat");
	    print BAT_RUN substr($cwd,0,2)."\ncd '".win_path(substr($cwd,2,(length($cwd)-2)))."'\n";
	    print BAT_RUN "CALL ".win_path($wfn_dir."/bin/wfn.bat ").$wfn_parameters."\n";
	    print BAT_RUN "CALL ".win_path($wfn_dir."/bin/".$wfn_option.".bat ".$file."_bs".$_." ".$_." ".($_ + $per_run -1)."\n");
	    print BAT_RUN "del ".win_path($cwd."\\".$file."_".$_.".".$setting{ext_ctl})."\n";
	    close BAT_RUN;
        }
    } else {
        open (BAT,">".$rand_filename.".bat");
        print BAT "CALL ".win_path($wfn_dir."/bin/wfn.bat ").$wfn_parameters."\n";
        print BAT "CALL ".win_path($wfn_dir."/bin/".$wfn_option.".bat ".$file." ".$wfn_run_parameters)."\n";
        close BAT;
    }
    my $command = "start /low /b ".$rand_filename."_".$_.".bat\n";
    return ($script_file, \@script, $command);
}

sub exec_run_wfn {
### Purpose : Execute a run using WFN
### Compat  : W+
    status ("Starting run using WFN");
    my ($wfn_dir, $wfn_option, $file, $wfn_run_parameters, $wfn_parameters, $no_threads) = @_;
    my @idx;
    if (($wfn_option =~ m/nmbs/i)) {   # calculate how to split up the bootstraps
        my ($start, $end) = split (/\s/,$wfn_run_parameters);
        $total = ($start + $end)-1;
        print $total;
        $per_run = $total / $no_threads;
        $i=0; while ($i < $no_threads) {
	    @idx[$i] = (1 + $per_run*$i);
	    $i++;
        }
    }
    @clean = <pirana_wfn_*>;
    foreach(@clean) {unlink $_};
    status ();
    db_log_execution ($file, @ctl_descr[$file], "WFN", "Local", win_path($wfn_dir."/bin/".$wfn_option.".bat ".$file." ".$wfn_run_parameters), $setting{username}, "pirana.dir" );

    unless ($cluster_active == 1) {
	return $rand_filename.".bat";
    } else {
	return ();
    }
}

sub get_nm_installations {
### Purpose : get the nm installations from the hash, filtered by NM-type
### Compat  : W+L+
    ($nm_nmfe_ref, $type_filter) = @_;
    %nm_nmfe = %$nm_nmfe_ref;
    foreach (keys(%nm_nmfe)) {
        unless ($nm_nmfe{$_} =~ m/$type_filter/ig) {delete ($nm_nmfe{$_}) };
    }
    return keys(%nm_nmfe);
}

sub update_new_dir {
### Purpose : generate a new dir number for nmfe-runs
### Compat  : W+L+
    my $file = shift;
    $rand_str = &generate_random_string(4);
    my $number = get_nmfe_number($file);
    $run_in_nm_dir = "nmfe_".$file."_".$number;
    return($run_in_nm_dir);
    #if ($nm_dir_entry) {$nm_dir_entry -> update()};
}

sub enable_run_new_dir_checkbox {
### Purpose : Set the checkbox for "start in new dir" to a state
### Compat  : W+L+
    $checked = shift;
    if ($checked==0) {
	$nm_dir_entry -> configure(-state=>'disabled');
    } else {
	$nm_dir_entry -> configure(-state=>'normal');
    }
}

sub update_psn_lst_param {
### Purpose : Update '-outputfile=xxx.lst' with current model number in the psn parameter entry
### Compat  : W+L+
    if ($psn_command_entry) {$psn_parameters = $psn_command_entry -> get();}
    update_psn_params_function ("outputfile");
    update_psn_params_function ("lst");
}

sub update_psn_params_function {
### Purpose : Update '-outputfile=xxx.lst' with current model number in the psn parameter entry
### Compat  : W+L+?
    my ($param) = @_[1];
    if ($psn_parameters =~ m/$param\=/i) {
	$pos1 = length $`;
	if (substr ($psn_parameters, $pos1, length()-$pos1) =~ m/\s-/) {
	    $pos2 = $pos1 + length $`;
	} else {$pos2 = length($psn_parameters)};
	# rebuild $psn_parameters
	@runs = $models_hlist -> selectionGet ();
	if ((@runs > 0)&&(@file_type_copy[@runs[0]] == 2)) {
	    $psn_parameters = substr($psn_parameters,0, $pos1+length($param)+1).@ctl_show[@runs[0]].".".
		$setting{ext_res}.substr($psn_parameters, $pos2, length($psn_parameters)-$pos2);
	    if ($psn_command_entry) {$psn_command_entry -> configure (-text=>$psn_parameters);}
	}
    }
}

sub project_optionmenu {
### Purpose : Create the optionmenu showing the different projects
### Compat  : W+L+
    @projects = keys(%project_dir);
    if ($project_optionmenu) {$project_optionmenu -> destroy();}
    our $project_optionmenu = $frame_dir -> Optionmenu(-options => [sort (@projects)], -width=>38, -border=>$bbw,
        -variable => \$active_project,-background=>$darkblue, -activebackground=>$darkblue2, -font=>$font_bold, -foreground=>$white, -activeforeground=>$white)
     -> grid(-row=>1,-column=>2,-columnspan=>1, -sticky=>'wens');
     $frame_dir -> update();
     $project_optionmenu -> configure (-command=>sub{
        $cwd = $project_dir{$active_project};
        $dir_entry -> configure(-text=>$cwd);
        save_log();
        $frame_dir -> update();
        refresh_pirana($cwd);
     });
    $cwd = $project_dir{$active_project};
    $dir_entry -> configure(-text=>$cwd);
    $project_optionmenu -> configure(-state=>'disabled');
    return($project_optionmenu);
}

sub project_buttons_show {
### Purpose : Show the buttons for saving/editing/info of the projects
### Compat  : W+L?
  $frame_dir -> Label(-text=>'Project:',-font => $font_normal, -background=>$bgcol)-> grid(-row=>1,-column=>1, -sticky => 'ens');
  $frame_dir -> Label(-text=>'Folder:',-font => $font_normal, -background=>$bgcol)-> grid(-row=>2,-column=>1, -sticky => 'ens');
#  $frame_dir -> Label(-text=>'   ', -background=>$bgcol)-> grid(-row=>3,-column=>1, -sticky => 'we');
  $dir_entry = $frame_dir -> Entry(-width=>44, -textvariable=>\$cwd, -border=>2, -relief=>'groove', -background=>$white,-font=>$font_normal)
    -> grid(-row=>2,-column=>2, -sticky => 'wens',-columnspan=>4);
  $dir_entry->bind("<Return>", sub {
     $cwd = $dir_entry -> get();
     if (substr($cwd,(length($cwd)-1),1) eq ":") {$cwd .= "/"}
     unless (-d $cwd) {
       $cwd = substr($cwd,0,2)."/";
     }
     refresh_pirana($cwd);
  });
  our $browse_button = $frame_dir -> Button(-image=>$gif{browse}, -width=>28, -border=>0,-background=>$button, -activebackground=>$abutton, -command=> sub{
      $dir_old = $cwd;
      $cwd = $mw-> chooseDirectory();
      if($cwd eq "") {$cwd=$dir_old};
      refresh_pirana($cwd);
    })->grid(-row=>2, -column=>6, -rowspan=>1, -sticky => 'nwse');
  $help->attach($browse_button, -msg => "Browse filesystem");

  our $save_button = $frame_dir -> Button(-image=>$gif{save}, -border=>$bbw, -background=>$button,-activebackground=>$abutton, -width=>22, -height=>22, -command=> sub{
    save_project($cwd) })
    ->grid(-row=>1,-column=>3, -sticky => 'wens');
  $help->attach($save_button, -msg => "Save this folder as project");
  our $edit_proj_button = $frame_dir -> Button(-image=>$gif{edit_info_blue}, -border=>$bbw, -background=>$button,-activebackground=>$abutton, -width=>22, -height=>22, -command=> sub{
      project_info_window();
    })->grid(-row=>1,-column=>4, -sticky => 'wens');
  $help->attach($edit_proj_button, -msg => "Edit project details");
  our $delete_button = $frame_dir -> Button(-image=>$gif{trash}, -border=>$bbw, -background=>$button, -activebackground=>$abutton, -width=>22, -height=>22, -command=> sub{
    del_project(); })
    ->grid(-row=>1,-column=>5, -rowspan=>1, -sticky => 'wens');
  $help->attach($delete_button, -msg => "Delete project");
  our $reload_button = $frame_dir -> Button(-image=>$gif{reload}, -border=>$bbw, -background=>$button, -activebackground=>$abutton, -width=>22, -height=>22, -command=> sub{
      refresh_pirana($cwd);
    })
    ->grid(-row=>1,-column=>6, -rowspan=>1, -sticky => 'wens');
  $help->attach($reload_button, -msg => "Refresh directory");
}

sub show_exec_runs_window {
### Purpose : Show a dialog that displays a log of executed runs
### Compat  : W+L?
    my $exec_runs_window = $mw -> Toplevel(-title=>'Execution log in '.$cwd);
    no_resize ($exec_runs_window);
    $exec_runs_window -> OnDestroy ( sub{
      undef $exec_runs_window; undef $exec_runs_window_frame;
    });
    $exec_runs_window_frame = $exec_runs_window -> Frame(-background=>$bgcol)->grid(-column=>1, -row=>1, -ipadx=>10,-ipady=>10);
    my $exec_runs_hlist = $exec_runs_window_frame ->Scrolled('HList', -head => 1,
        -columns    => 7, -scrollbars => 'e', -highlightthickness => 0,
        -height     => 30, -border     => 0,
        -width      => 140, -background => 'white',
        -selectbackground => $pirana_orange,
    )->grid(-column => 1, -columnspan=>7,-row => 1, -sticky=>"wens");
    my @headers = ( "Run", "Description", "Date/time", "NM", "Location", "Researcher", "Command");
    my @headers_widths = (80, 160, 130, 40, 40,50,600);
    my $headerstyle = $models_hlist -> ItemStyle('window', -padx => 0);
    foreach my $x ( 0 .. $#headers ) {
        @exec_runs_headers[$x] = $exec_runs_hlist -> HdrResizeButton(
          -text=> $headers[$x], -relief=>'groove', -column=>$x, -font=>$font,
          -background=>$button, -activebackground=>$abutton, -activeforeground=>'black',
          -border=>0, -pady =>$header_pad, -resizerwidth => 2);
        $exec_runs_hlist -> header('create', $x,
          -itemtype => 'window', -style=> $headerstyle,
          -widget => @exec_runs_headers[$x]
        );
        $exec_runs_hlist -> columnWidth($x, @headers_widths[$x]);
    }
    populate_run_log_hlist ($exec_runs_hlist);
    $exec_runs_window_frame -> Button(-text=>'Refresh',-font=>$font, -width=>4, -border=>$bbw,-background=>$button,-activebackground=>$abutton,-command=> sub{
	$exec_runs_hlist -> delete("all");
	populate_run_log_hlist ($exec_runs_hlist);
    })->grid(-row=>2,-column=>1,-sticky=>'news');
    $exec_runs_window_frame -> Button(-text=>'Delete log',-font=>$font, -width=>4, -border=>$bbw,-background=>$button,-activebackground=>$abutton,-command=> sub{
	db_execute ("DELETE FROM executed_runs", "pirana.dir");
	$exec_runs_hlist -> delete("all");
	$exec_runs_hlist -> update();
    })->grid(-row=>2,-column=>2,-sticky=>'news');
    $exec_runs_window_frame -> Button(-text=>'Export log as CSV',-font=>$font, -width=>4, -border=>$bbw,-background=>$button,-activebackground=>$abutton,-command=> sub{
	$exec_runs_hlist -> delete("all");
	my $log = populate_run_log_hlist ($exec_runs_hlist);
	my $types = [
	    ['CSV files',       ['.csv', '.CSV']],
	    ['All Files',        '*',       ],
	    ];
	my $save_file = $exec_runs_window_frame -> getSaveFile (-defaultextension=>".csv", -filetypes=>$types, -title=>"Save run log as", -initialdir => $cwd);
	open (CSV, ">".$save_file);
	foreach my $row (reverse @$log) {
	    print CSV '"'.join ('","',@$row).'"'."\n";
	}
	close (CSV);
    })->grid(-row=>2,-column=>3,-sticky=>'news');
}

sub populate_run_log_hlist {
    my ($exec_runs_hlist) = @_;
    $db_results = db_read_exec_runs("pirana.dir");
    if ($db_results =~ m/ARRAY/) {
	my $i=0;
	$style = $models_hlist-> ItemStyle( 'text', -anchor => 'nw',-padx => 5, -background=>'white', -font => $font);;
	foreach my $row (reverse @$db_results) {
	    my ($model, $descr, $date_execute, $name_modeler, $nm_version, $method,
		$exec_where, $command) = @$row;
	    $exec_runs_hlist -> add($i);
	    $exec_runs_hlist -> itemCreate($i, 0, -text => $model, -style=>$style);
	    $exec_runs_hlist -> itemCreate($i, 1, -text => $descr, -style=>$style);
	    $exec_runs_hlist -> itemCreate($i, 2, -text => $date_execute, -style=>$style);
	    $exec_runs_hlist -> itemCreate($i, 3, -text => $method, -style=>$style);
	    $exec_runs_hlist -> itemCreate($i, 4, -text => $exec_where, -style=>$style);
	    $exec_runs_hlist -> itemCreate($i, 5, -text => $name_modeler, -style=>$style);
	    $exec_runs_hlist -> itemCreate($i, 6, -text => $command, -style=>$style);
	    $i++;
	}
	$exec_runs_hlist -> update();
    }
    return ($db_results);
}

sub show_inter_window {
### Purpose : Show a dialog that displays intermediate OFVs, param.estims and gradients for runs in the current folder and below
### Compat  : W+
    my $wd = shift;
    unless (-d $wd) {$wd = $cwd}
    my @buttons;
    unless ($inter_window) { # build the dialog
      our $inter_window = $mw -> Toplevel(-title=>'Progress of runs in '.$wd, -background=>$bgcol);
      no_resize ($inter_window);
      $inter_window -> OnDestroy ( sub{
        undef $inter_window; undef $inter_window_frame;
      });
      $inter_window_frame = $inter_window -> Frame(-background=>$bgcol)->grid(-column=>0, -row=>0, -ipadx=>10,-ipady=>0, -sticky=>"nwse");
      our $inter_dirs;
#      $inter_frame_status = $inter_window -> Frame(-relief=>'sunken', -border=>0, -background=>$bgcol)->grid(-column=>0, -row=>4, -ipadx=>10, -sticky=>"nswe");
      $inter_status_bar = $inter_window_frame -> Label (-text=>"Status: Idle", -anchor=>"w", -font=>$font_normal, -background=>$bgcol)->grid(-column=>0,-row=>7,-columnspan=>7, -sticky=>"w");
      $inter_frame_buttons = $inter_window_frame -> Frame(-relief=>'sunken', -border=>0, -background=>$bgcol)->grid(-column=>0, -row=>2, -ipady=>0, -sticky=>"wns");
      $intermed_frame_buttons = $inter_window_frame -> Frame(-relief=>'sunken', -border=>0, -background=>$bgcol)->grid(-column=>0, -row=>5, -ipady=>0, -sticky=>"wnse");
      @buttons[0] = $inter_frame_buttons -> Button (-text=>'Rescan directories', -font=>$font, -width=>20, -border=>$bbw,-background=>$button, -activebackground=>$abutton,-command=>sub{
        $grid -> delete("all");
        inter_status ("Searching sub-directories for active runs...");
        @n = get_runs_in_progress($wd, \@buttons);
        if ( int(@n) == 1 ) {
          inter_status ("No active runs found");
        } else {inter_status()};
      }) -> grid(-column => 1, -row=>1, -sticky=>"wns");
      $inter_frame_buttons -> Button (-text=>'Intermediate files', -font=>$font,  -width=>20, -border=>$bbw,-background=>$button, -activebackground=>$abutton,-command=>sub{
         @info = $grid->infoSelection();
         foreach (@info) {
           my $dir = $_;
           if ($dir ne "") {
             if (-e $wd."/".$dir."/OUTPUT") {edit_model(unix_path($wd."/".$dir."/OUTPUT"));}
             if (-e $wd."/".$dir."/INTER") {edit_model(unix_path($wd."/".$dir."/INTER"));}
             if (-e $wd."/".$dir."/psn.lst") {edit_model(unix_path($wd."/".$dir."/psn.lst"))}
           }
         }
      }) -> grid(-column => 2, -row=>1, -sticky=>"w");
      $inter_frame_buttons -> Button (-text=>'Open .ext file', -font=>$font,  -width=>20, -border=>$bbw,-background=>$button, -activebackground=>$abutton,-command=>sub{
         @info = $grid->infoSelection();
         foreach my $dir (@info) {
	   my $ext_file = get_current_ext ($wd."/".$dir);
	   if ((-e $ext_file)&&(!(-d $ext_file))) { 
	       edit_model($ext_file); 
	   } else {
	       message ('No .ext file found')
	   }
         }
      }) -> grid(-column => 3, -row=>1, -sticky=>"w");
      $inter_frame_buttons -> Button (-text=>'Refresh estimates',  -font=>$font, -width=>20, -border=>$bbw,-background=>$button, -activebackground=>$abutton,-command=>sub{
       #get all
         @info = $grid->infoSelection();
	 my $chosen = @info[0];
         $grid_inter -> delete("all");
	 my ($sub_iter, $sub_ofv, $descr, $minimization_done, 
	     $gradients_ref, $all_gradients_ref, $all_ofv_ref, 
	     $all_iter_ref) = get_run_progress("", $cwd."/".$chosen);
	 my $mod_ref;
	 if (-e $wd."/".@info[0]."/psn.mod") {
	     $mod_ref = extract_from_model ($wd."/".@info[0]."/psn.mod", "psn", "all")
	 }
	 update_inter_results_dialog ($wd."/".@info[0], $gradients_ref, $mod_ref);
      }) -> grid(-column => 4, -row=>1, -sticky=>"w");
#      $inter_frame_buttons -> Button (-text=>'Plot OFV / gradients',  -font=>$font, -width=>17, -border=>$bbw,-background=>$button, -activebackground=>$abutton,-command=>sub{
 #        @info = $grid->infoSelection();
 #     }) -> grid(-column => 5, -row=>1, -sticky=>"w");

      ## Stop run functionality: not yet implemented (has issues)
      #$inter_frame_buttons -> Button (-text=>'Stop run', -width=>20, -border=>$bbw,-background=>$button, -activebackground=>$abutton,-command=>sub{
      #   @info = $grid->infoSelection();
      #   foreach (@info) {
      #     ;
      #   }
      #}) -> grid(-column => 3, -row=>1, -sticky=>"w");
      $inter_window_frame -> Label (-text=>' ',  -width=>9, -background=>$bgcol, -font=>"Arial 3") -> grid(-column => 1, -row=>0, -sticky=>"w");
      $inter_frame_buttons -> Label (-text=>' ',  -width=>9, -background=>$bgcol) -> grid(-column => 1, -row=>2, -sticky=>"w");
      $intermed_frame_buttons -> Label (
        -text=>"Note: to obtain intermediate estimates from runs, creation of an MSF file is\nrequired. To increase update frequency, use e.g. PRINT=1 in the \$EST block.",
        -font=>$font, -foreground=>"#666666", -justify=>'l',-background=>$bgcol) -> grid(-column => 3, -row=>3, -columnspan=>5, -ipadx=> 10, -sticky=>"w");
    } else {
	$inter_window -> focus
    };
    inter_status ("Searching sub-directories for active runs...");
    chdir ($wd);

    my @headers = ( "MSF", "Iterations","OFV");
    my @headers_widths = (60, 60, 60, 160,240);

    our $grid = $inter_window_frame ->Scrolled(
	'HList', 
        -head       => 1,
        -relief     => 'groove',
        -highlightthickness => 0,
        -selectmode => "extended",
	-selectborderwidth => 0,
        -columns    => 5,
        -scrollbars => 'se',
        -height     => 8,
        -pady       => 0,
        -padx       => 0,
	-selectbackground => $pirana_orange,
	-background => 'white',
        -width      => 60
    )->grid(-column => 0, -columnspan=>7,-row => 1, -sticky=>"wens");

    my @headers_inter = (" ","Parameter", "Estimate", "Gradient" , "Initial", "Min", "Max");
    my @headers_inter_widths = (50, 150, 60, 70, 60, 60, 60, 100, 100);
    our $grid_inter = $inter_window_frame ->Scrolled(
	'HList', 
        -head       => 1,
        -relief     => 'groove',
        -highlightthickness => 0,
        -selectmode => "extended",
	-selectborderwidth => 0,
        -columns    => 8,
        -scrollbars => 'se',
        -height     => 20,
        -pady       => 0,
        -padx       => 0,
	-selectbackground => $pirana_orange,
	-background => 'white',
        -width      => 60
    )->grid(-column => 0, -columnspan=>7, -row => 4, -sticky=>"wens");
    
    foreach my $x ( 0 .. $#headers ) {
        $grid -> header('create', $x, -text=> $headers[$x], -style=> $header_right, -headerbackground => 'gray');
        $grid -> columnWidth($x, @headers_widths[$x]);
    }
    $grid -> header('create', 3, -text=> "Folder", -style=> $header_left, -headerbackground => 'gray');
    $grid -> header('create', 4, -text=> "Description", -style=> $header_left, -headerbackground => 'gray');
    $grid -> columnWidth(3, @headers_widths[3]);
    $grid -> columnWidth(4, @headers_widths[4]);

    my @styles = ($header_left, $header_left, $header_right, $header_left, $header_right, $header_left, $header_left,  $header_right, $header_left, $header_left, $header_left, $header_left);
    $x=0; foreach (@headers_inter) {
      if ($x==5) {$style = $header_left} else {$style = $header_right};
      $grid_inter -> header('create', $x, -text=> $headers_inter[$x], -style=> @styles[$x], -headerbackground => 'gray');
      $grid_inter -> columnWidth($x, @headers_inter_widths[$x]);
      $x++;
    }

      $intermed_frame_buttons -> Button (
	  -text=>"Export as CSV", -font=>$font_normal, -background=>$button, -border=>$bbw, -activebackground=>$abutton, -command=> sub{
	      my $types = [
		  ['CSV files','.csv'],
		  ['All Files','*',  ], ];
	      my $csv_file_choose = $mw -> getSaveFile(-defaultextension => "*.csv", -initialdir=> $cwd ,-filetypes=> $types);
	      unless ($csv_file_choose eq "") {
		  grid_to_csv ($grid_inter, $csv_file_choose, \@headers_inter, 60, 7 );
	      }
	  })->grid(-column=>1, -row=>3, -sticky=>"nwe");
      $intermed_frame_buttons -> Button (
	  -text=>"Export as LaTeX", -font=>$font_normal, -background=>$button, -border=>$bbw, -activebackground=>$abutton, -command=> sub{
	      grid_to_latex ($grid_inter, $csv_file_choose, \@headers_inter, 60, 7 );
	  })->grid(-column=>2, -row=>3, -sticky=>"nwe");

   # # create the gradient plot
   # $plot_frame = $inter_intermed_frame -> Frame (-relief=>'groove', -background=>$bgcol, -border=>0, -height=>10) -> grid(-column=>2, -row=>1, -rowspan=>3, -sticky=>'nwe');
   # my @plot_title = ("",20);
   # @border = (8,55,40,52); # top, right, bottom, lef
   # our $gradients_plot = $plot_frame -> PlotDataset
   #  ( -width => 360, -height => 300,
   #    -background => $bgcol, -border=> \@border,
   #    -plotTitle => \@plot_title,
   #    -xlabel => "Iteration", -ylabel => "Gradient",
   #    -y1label => 'OFV', -xType => 'linear', -yType => 'linear',
   #    -y1TickFormat => "%d", -xTickFormat => "%g", -yTickFormat => "%d"
   #  ) -> grid(-column=>2, -row=>1);
   # $gradients_plot -> configure (-fonts =>
   #   ['Arial 7',   # axes ticks
   #    'Arial 8 italic', # axes labels
   #    'Arial 9 bold',  # title
   #    'Arial 7' # legend
   #    ]);
   # $grid_inter -> update();
    $grid -> configure(-browsecmd => sub{
	my $diff = str2time(localtime()) - $last_time;
	$last_time = str2time(localtime());
	my @info = $grid -> infoSelection();
	if (($diff > 0)||($last_chosen ne @info[0])) {
	    our $last_chosen = @info[0];
	    #chdir ("./".@info[0]);
	    my ($sub_iter, $sub_ofv, $descr, $minimization_done, 
		$gradients_ref, $all_gradients_ref, $all_ofv_ref, 
		$all_iter_ref) = get_run_progress("", $cwd."/".$last_chosen); # necessary for gradients
	    #chdir ($wd);

	    my $mod_ref;
	    if (-e $wd."/".@info[0]."/psn.mod") {
		$mod_ref = extract_from_model ($wd."/".@info[0]."/psn.mod", "psn", "all")
	    } else {
		if (@info[0] =~ m/nmfe/) {
		    my @mod = dir ($wd."/".@info[0], "\.".$setting{ext_res});
		    if (@mod[0] =~ m/nmprd4p.mod/) {
			shift (@mod); 
		    }
		    my $mod_no = @mod[0];
		    $mod_no =~ s//\.$setting{ext_res}/gi;
		    $mod_ref = extract_from_model ($wd."/".@info[0]."/".@mod[0], $mod_no, "all")
		}
	    }
	    #print %$mod_ref;
	    update_inter_results_dialog ($wd."/".@info[0], $gradients_ref, $mod_ref);
   #          $gradients_plot -> clearDatasets;
   #          my $lines_ref = update_gradient_plot($sub_iter, $gradients_ref, $all_gradients_ref, $all_iter_ref);
   #          my $gradient_info = $plot_frame -> Balloon();
   #          unless ($lines_ref == 0) {
   # 		my @lines = @$lines_ref;
   # 		foreach my $line (@lines) {
   # 		    if ($line =~ m/linegraph/i) { # test if correct Tk format
   # 			$gradients_plot -> addDatasets($line);
   # 		    }
   # 		}
   #          }
   #          my $ofv_line = update_ofv_plot($sub_iter, $all_ofv_ref, $all_iter_ref);
   #          unless ($ofv_line == 0) {
   # 		if ($ofv_line =~ m/linegraph/i) { # test if correct Tk format
   # 		    $gradients_plot -> addDatasets($ofv_line);
   # 		}
   #          }
   #          $gradients_plot -> plot;
	}	     
    });    
    center_window($inter_window, $setting{center_window});
    our @n = get_runs_in_progress($wd, \@buttons);
    if ( int(@n) == 1 ) {
	inter_status ("No active runs found");
    } else {inter_status()};
}

sub update_gradient_plot {
  my ($sub_iter, $gradients_ref, $all_gradients_ref, $all_iter_ref) = @_;
  my @all_gradients = @$all_gradients_ref;
  my @gradients = @$gradients_ref;
  my @all_iter = @$all_iter_ref;
  my @x_all;
  my @y_all;
  for (my $n_iter=0; $n_iter < int(@all_iter); $n_iter++) {
      for (my $n_grad=1; $n_grad <= @gradients; $n_grad++) {
	  my $gradient = shift (@all_gradients);
	  if ($gradient =~ /^-?\d+\.?\d*$/) {  # if real number
	      my $x_ref = @x_all[$n_grad];
	      my $y_ref = @y_all[$n_grad];
	      my @x = @$x_ref;
	      my @y = @$y_ref;
	      push (@x, @all_iter[$n_iter]);
	      push (@y, $gradient);
	      @x_all[$n_grad] = \@x;
	      @y_all[$n_grad] = \@y;
	  }
      }
  }
  my @lines;
  my $i=0;
  foreach (@x_all) {
      my $x_ref = @x_all[$i];
      my $y_ref = @y_all[$i];
      if (@$y_ref > 0) {
	  my $line = LineGraphDataset -> new (
	      -name => "Gradient ".($i+1),
	      -xData => $x_ref,
	      -yData => $y_ref,
	      -yAxis => 'Y',
	      -color => 'darkblue',
	      -lineStyle => 'normal',
	      -pointStyle => 'none'
	      );
	  push(@lines, $line);
      }
      $i++;
  }
  if(@lines>0) {
      return(\@lines)
  } else {return(0)};

}

sub update_ofv_plot {
  my ($sub_iter, $all_ofv_ref, $all_iter_ref) = @_;
  my @x = (1 .. $sub_iter);
  my $line = LineGraphDataset -> new (
        -name => "OFV",
        -xData => $all_iter_ref,
        -yData => $all_ofv_ref,
        -yAxis => 'Y1',
        -color => 'red',
        -lineStyle => 'normal',
        -pointStyle => 'none'
      );
  if (@x>1) {
    return($line);
  } else {
    return (0)
  }
}

sub inter_status {
### Purpose : Change the status text in the intermediate-results window
### Compat  : W+L+
  my $status_text_inter = shift;
  if ($status_text_inter eq "") {$status_text_inter = "Idle"};
  if ($inter_window) {
    $inter_status_bar -> configure (-text=>"Status: ".$status_text_inter);
    $inter_window -> update();
  }
}

sub inter_window_add_item {
### Purpose : Add item in the intermediate results window
### Compat  : W+L+
    my ($item, $minimization_done) = @_;
    my $dir1;
    my $i=1;
    my $align_right_style = $models_hlist->ItemStyle( 'text', -anchor => 'ne',-padx => 5, -background=>'white', -font => $font_normal);
    my $align_left_style = $models_hlist-> ItemStyle( 'text', -anchor => 'nw',-padx => 5, -background=>'white', -font => $font_normal);
    if ($minimization_done == 1) { # make green, probably busy doing the covariance step
      $align_right_style = $models_hlist->ItemStyle( 'text', -anchor => 'ne',-padx => 5, -background=>$lightgreen, -font => $font_normal);
      $align_left_style = $models_hlist-> ItemStyle( 'text', -anchor => 'nw',-padx => 5, -background=>$lightgreen, -font => $font_normal);
    }
    $res_descr{$item} =~ s/[\r\n]//g;
    unless (($item =~ m/HASH/)||($grid -> infoExists($item))) {  # for some reason this sometimes is necessary.
        $grid->add($item);
        $grid->itemCreate($item, 0, -text => $res_runno{$item}, -style=>$align_right_style);
        $grid->itemCreate($item, 1, -text => $res_iter{$item}, -style=>$align_right_style );
        $grid->itemCreate($item, 2, -text => $res_ofv{$item}, -style=>$align_right_style);
        if ($item eq "/") { $dir1 = $item} else { $dir1 = "/".$item }
        $res_dir{$item} = $dir1;
        $grid->itemCreate($item, 3, -text => $dir1, -style=>$align_left_style);
        $grid->itemCreate($item, 4, -text => $res_descr{$item}, -style=>$align_left_style);
        $i++;
    }
    $grid -> update();
    push (@inter_dirs, $item)
}

sub get_runs_in_progress {
### Purpose : return a hash of runs that are currently in progress in the current directory, or in PsN/nmfe directories below
### Compat  : W+L?
    my ($wd, $buttons_ref) = @_  ;
    my @buttons = @$buttons_ref;
    foreach (@buttons) {
	$_ -> configure (-state => "disabled");
    }

    unless (-d $wd) {$wd = $cwd}
    my $dir = fastgetcwd()."/";
    my @dirs = read_dirs($wd, "");
    my %dir_results = new ;
    our (%res_iter, %res_ofv, %res_runno,  %res_dir, %res_descr);
    # First check main directory
    inter_status ("Searching / for active runs...");
    if ((-e "nonmem.exe")||(-e "nonmem")) {  # check for nmfe runs
	#unless ((-e "nonmem.exe")&&(-w "nonmem.exe")) {
        if (-e "INTER") {
	    if ((-e "OUTPUT")&&(-s "OUTPUT" > 0)) {
		($res_iter {"/"}, $res_ofv {"/"}, $res_descr{"/"}, $minimization_done) = get_run_progress("OUTPUT");
	    }
	    inter_window_add_item("/", $minimization_done);
        }
    }
    # check directories
    foreach (@dirs) {
	chdir($_);
	my $sub = fastgetcwd();
	$sub =~ s/$dir//;
	inter_status ("Searching /".$sub." for active runs...");
	my @nm = glob ("nonmem*.exe");
	if ((-e @nm[0])||(-e "nonmem")) {  # check for nmfe runs
	    # unless ((-e "nonmem.exe")&&(-w "nonmem.exe")) {
	    if (-e "INTER") {
		if ((-e "OUTPUT")&&(-s "OUTPUT" > 0)) {
		    ($res_iter {$sub}, $res_ofv {$sub}, $res_descr{$sub}, $minimization_done) = get_run_progress("OUTPUT");
		}
		@msf = glob("*MSF*");
		@msf[0] =~ s/MSF//ig;
		$res_runno{$sub} = @msf[0];
		inter_window_add_item($sub, $minimization_done);
	    }
	    #}
	}
	# Check sub-directories
	if (($sub =~ m/_/)||($sub =~ /\.dir/)) { # only do this for PsN- or nmfe directories, to save speed
	    @dirs_sub = read_dirs (".", "NM_run"); # PsN directories
	    foreach $subdir (@dirs_sub) {
		chdir ($subdir);
		if ((-e "nonmem.exe")||(-e "nonmem")) {
		    if (-e "INTER") {
			$sub = fastgetcwd();
			$sub =~ s/$dir//; # relative dir
			inter_status ("Searching ".$sub." for active runs...");
			if (-e "OUTPUT") {
			    ($res_iter {$sub}, $res_ofv {$sub}, $res_descr{$sub}, $minimization_done) = get_run_progress("psn.lst");
			}
			if (-e "psn.lst") {
			    ($res_iter {$sub}, $res_ofv {$sub}, $res_descr{$sub}, $minimization_done) = get_run_progress("psn.lst");
			}
			@msf = glob("*MSF*");
			@msf[0] =~ s/MSF//ig;
			$res_runno{$sub} = @msf[0];
			inter_window_add_item($sub, $minimization_done);
		    }
		}
		chdir ("..")
	    }
	}
	chdir("..");
    }
    chdir($dir);
    foreach (@buttons) {
	$_ -> configure (-state => "normal");
    }
    return (keys (%res_iter));
}

sub get_run_progress {
### Purpose : Return the number of iterations and OFV of a currently running model
### Compat  : W+L+
  my ($output_file, $dir) = @_;
  if ($dir eq "") {$dir = "."}
  @l = dir ($dir, $setting{ext_res});
  if (int(@l)>0) {
    $output_file = unix_path($dir."/".@l[0]);
  }
  $dir .= "/";
  if ((-e $dir."OUTPUT")&&(-s $dir."OUTPUT" >0)) {$output_file = unix_path($dir."OUTPUT")};
  open (OUT,"<".unix_path($output_file));
  @lines = <OUT>;
  close OUT;
  my @gradients;
  my @all_gradients;
  my @all_ofv;
  my @all_iter = ();
  my $sub_iter;
  my $sub_ofv;
  my $minimization_done = 0;
  my $gradient_area = 0;
  foreach $line (@lines) {
     if($line =~ m/ITERATION/gi) {
	 $gradient_area == 0;
	 $sub_iter = substr($line,15,9);
	 $sub_iter =~ s/\s//g;
	 push (@all_iter, $sub_iter);
	 $sub_ofv = substr($line,30,20);
	 $sub_ofv =~ s/(\p{IsAlpha}|\:|=|\s)//g;
	 $sub_ofv = rnd($sub_ofv, 7); 
	 if ($line =~ m/EVALS/) {
	     push (@all_ofv, $sub_ofv);
	     $sub_eval = substr($line,76,3);
	     $sub_eval =~ s/\s//g;
	 }
     }
     if ($line =~ m/GRADIENT/) {
	 $gradient_area = 1;
	 @gradients = ();
     }
     if ($gradient_area == 1) {
	 unless (($line =~ m/GRADIENT/)||(substr($line,0,6) eq "      ")) {
	     $gradient_area = 0;
	     push (@all_gradients, @gradients);
	 };
     }
     if ($gradient_area == 1) {
	 $line =~ s/GRADIENT:// ;
	 my @gradients_line = split(" ",$line);
	 foreach (@gradients_line) {
	     if ($_ ne "") {
		 chomp($_);
		 $_ =~ s/\s//g;
		 push(@gradients, rnd($_,6));
	     }
	 }
     }
     if (($line =~ /MINIMIZATION/)||($line =~ m/OBJECTIVE FUNCTION IS TO BE EVALUATED/)) {
	 $minimization_done = 1;
     }
  }
  # try to get a description of the model
  @m = dir ($dir, $setting{ext_ctl});
  my $mod_ref;
  if ((@m == 1)||(@m[0] =~ m/psn/gi)) {
      my $modelfile = @m[0];
      my $modelno = @m[0];
      $modelno =~ s/\.$setting{ext_ctl}//;
      if (-e "psn.mod") {$modelno = "psn"; $modelfile = "psn.mod" };
      $mod_ref = extract_from_model ($modelfile, $modelno, "")
  }
  my %mod = %$mod_ref;
  return ($sub_iter, $sub_ofv, $mod{description}, $minimization_done, \@gradients, \@all_gradients, \@all_ofv, \@all_iter);
}

sub update_inter_results_dialog {
### Purpose : update dialog with intermediat results
### Compat  : W+L+
  my ($dir, $gradients_ref, $mod_ref) = @_;
  my @gradients = @$gradients_ref;
  my $n_grad = int(@gradients);
  my $ext_file = get_current_ext ($dir);
  if ((-e $ext_file)&&(-s $ext_file > 0)) { # sometimes in NM7 with the EM methods, .ext files is not updated; in that case fall back on OUTPUT/INTER
      # try to extract from .ext, if created (NONMEM7+)
#      ($thetas_ref, $omegas_ref, $sigmas_ref) = extract_inter_ext($ext_file);     
      ($thetas_ref, $omegas_ref, $sigmas_ref) = extract_inter($dir);
  } else {
      # try to extract from INTER, maybe NONMEM6 or earlier
      ($thetas_ref, $omegas_ref, $sigmas_ref) = extract_inter($dir);
  }
#  ($thetas_ref, $omegas_ref, $sigmas_ref) = extract_inter($dir);
  my %mod = %$mod_ref;
  my @thetas = @$thetas_ref;
  my @omegas = @$omegas_ref;
  my @sigmas = @$sigmas_ref;
  $inter_window -> update();
  my $i=1; my $n=0;
  $grid_inter -> delete("all");
  $grid_inter -> update();
#  my $th_descr_ref = $mod{th_descr};
  my @th_descr = @{$mod{th_descr}};
  my @th_fix = @{$mod{th_fix}};
  my @th_init = @{$mod{th_init}};
  my @th_bnd_low = @{$mod{th_bnd_low}};
  my @th_bnd_up  = @{$mod{th_bnd_up}};
  my $curr_grad = shift (@gradients);
  my $th_header = $models_hlist->ItemStyle( 'text', -anchor => 'nw',-padx => 5, -background=>'#cfcfcf', -font => $font_normal);
  my $th_left   = $models_hlist->ItemStyle( 'text', -anchor => 'nw',-padx => 5, -background=>'#ffffff', -font => $font_normal);
  my $th_right  = $models_hlist->ItemStyle( 'text', -anchor => 'ne',-padx => 5, -background=>'#ffffff', -font => $font_normal);
  foreach (@th_fix) {
      unless ($grid_inter -> infoExists($i)) {
	  $grid_inter->add($i);
      }
      $grid_inter->itemCreate($i, 0, -text => "TH".$i, -style=>$th_header);
      $grid_inter->itemCreate($i, 1, -text => @th_descr[($i-1)], -style=>$th_left);
      $grid_inter->itemCreate($i, 2, -text => @thetas[$i], -style=>$th_right);
      unless (@th_fix[($i-1)] eq "FIX") {
	  my $style;
	  if ($n_grad > 0) {
	      if (($curr_grad == 0)&&($n_grad > 0)) {$style = $align_right_red} else {$style = $th_right;}
	      $grid_inter->itemCreate($i, 3, -text => $curr_grad, -style=>$style);
	      $curr_grad = shift (@gradients);
	  }
      } else {
	  $grid_inter->itemCreate($i, 3, -text => "NA", -style=>$th_right);
      }
      $grid_inter->itemCreate($i, 4, -text => @th_init[($i-1)], -style=>$th_right);
      $grid_inter->itemCreate($i, 5, -text => @th_bnd_low[($i-1)], -style=>$th_right);
      $grid_inter->itemCreate($i, 6, -text => @th_bnd_up[($i-1)], -style=>$th_right);
      $i++;
  }
  $n = $i;
  my @om_descr = @{$mod{om_descr}};
  my @om_fix = @{$mod{om_fix}};
  my @om_same = @{$mod{om_same}}; 
  my @om_init = @{$mod{om_init}};
  my @om_struct =@{$mod{om_struct}};
#  print join (" ", @om_struct);
#  print int (@om_struct);
  my $om_header = $models_hlist->ItemStyle( 'text', -anchor => 'nw',-padx => 5, -background=>'#c0c0c0', -font => $font_small);
  my $om_left   = $models_hlist->ItemStyle( 'text', -anchor => 'nw',-padx => 5, -background=>'#f0f0f0', -font => $font_normal);
  my $om_right  = $models_hlist->ItemStyle( 'text', -anchor => 'ne',-padx => 5, -background=>'#f0f0f0', -font => $font_normal);
  my $iov_left  = $models_hlist->ItemStyle( 'text', -anchor => 'ne',-padx => 5, -background=>'#e0e0e0', -font => $font_normal);
  my $iov_right = $models_hlist->ItemStyle( 'text', -anchor => 'ne',-padx => 5, -background=>'#e0e0e0', -font => $font_normal);
  my @om_labels; my $j = 1;
  my $cnt_om = 0;
  my $cnt_no_same = 0;
  my $n_om = int(@om_struct); # number of omega blocks
  my $init = shift(@om_init);
  foreach(@om_struct) { if ($_ > 1) { $n_om = $n_om - ($_ - 1); } }
  if (int(@thetas) == 0) {$n_om = 0}; # don't print omegas if no thetas found
  for ($k = 0; $k < $n_om ; $k++ ) {
      my $diag = @om_struct[$k];
      my $block_size = block_size($diag);
      if ($diag == 0) { # e.g. SAME 
	  $block_size = 1;
      }
      my $row = 1;
      my $col = 1;
      my $cnt_om_last = $cnt_om;
      for ($p = 1; $p <= $block_size; $p++) {
	  my @omega_curr = @{@omegas[($cnt_om_last+$row-1)]};
	  my $om = @omega_curr[($cnt_om_last+$col-1)];
	  unless ($grid_inter -> infoExists($i)) {
	      $grid_inter->add($i);
	  }
	  unless (@om_same[$cnt_om] == 1) {
	      $style_right = $om_right;
	      $style_left = $om_left;
	      $grid_inter -> itemCreate($i, 4, -text => rnd ($init, 4) , -style=>$style_right);
	      $grid_inter->itemCreate($i, 2, -text => $om, -style=>$style_right);
	  } else {
	      $style_right = $iov_right;
	      $style_left = $iov_left;
	      $grid_inter -> itemCreate($i, 2, -text => "..." , -style=>$style_right);
	      $grid_inter -> itemCreate($i, 4, -text => "" , -style=>$style_right);
	  }
	  $grid_inter -> itemCreate($i, 0, -text => "OM".($cnt_om_last+$col).($cnt_om_last+$row), -style=>$om_header);
	  unless ((@om_fix[($cnt_om_last-1)] eq "FIX")||(@om_fix[($cnt_om_last-1)] == 1)) {
	      my $style;
	      my $text = $curr_grad;
	      if (@om_same[($cnt_om)] == 1) {
		  $text = "";
	      } 
	      if (($curr_grad == 0)&&(@om_same[$cnt_om] == 0)) {$style = $align_right_red} else {$style = $style_right;}
	      $grid_inter->itemCreate($i, 3, -text => $text, -style=>$style);
	  }  else {
	      my $text = "FIX";
	      if (@om_same[($cnt_om)] == 1) {
		  $text = "";
		  $style = $iov_right;
	      } 
	      $grid_inter -> itemCreate($i, 3, -text => $text, -style=>$style_right);
	  }
	  if ($col == $row) { # diag
	      $grid_inter -> itemCreate($i, 1, -text => @om_descr[$cnt_om], -style=>$style_left);
	      $cnt_om++;
	      $row++;
	      $col = 1;
	      unless (@om_same[($cnt_om)] == 1) {
		  $cnt_no_same++;
	      }
	  } else {
	      $grid_inter->itemCreate($i, 1, -text => "", -style=>$style_left);
	      $col++;
	  }
	  $grid_inter->itemCreate($i, 5, -text => "", -style=>$style_right);
	  $grid_inter->itemCreate($i, 6, -text => "", -style=>$style_right);
	  unless (@om_same[($cnt_om)] == 1) {
	      $init = shift (@om_init);
	      $curr_grad = shift (@gradients);
	  } 
	  $i++;
      }
  }
  $n = $i;
  my @si_descr = @{$mod{si_descr}};
  my @si_fix = @{$mod{si_fix}};
  my @si_init = @{$mod{si_init}};
  foreach (@si_fix) {
      my @sigma_curr = @{$sigmas[($i-$n)]};
      my $si = @sigma_curr[@sigma_curr-1];
      unless ($grid_inter -> infoExists($i)) {
	  $grid_inter->add($i);
      }
      $grid_inter->itemCreate($i, 0, -text => "SI".(($i-$n)+1), -style=>$th_header); 
      $grid_inter->itemCreate($i, 1, -text => @si_descr[($i-$n)], -style=>$th_left);
      $grid_inter->itemCreate($i, 2, -text => $si, -style=>$th_right);
      unless (@si_fix[($i-$n)] eq "FIX") {
	  my $style;
	  if ($n_grad > 0) {
	      if ($curr_grad == 0) {$style = $align_right_red} else {$style = $th_right;}
	      $grid_inter->itemCreate($i, 3, -text => $curr_grad, -style=>$style);
	      $curr_grad = shift (@gradients);
	  }
      } else {
	  my $text = "FIX";
	  $grid_inter->itemCreate($i, 3, -text => $text, -style=>$th_right);
      }
      $grid_inter->itemCreate($i, 4, -text => rnd(@si_init[($i-$n)], 4), -style=>$th_right);
      $grid_inter->itemCreate($i, 5, -text => "", -style=>$th_right);
      $grid_inter->itemCreate($i, 6, -text => "", -style=>$th_right);
      $i++;
  }
  # $i=1;
  # foreach (@gradients) {
  #   if ($i > $n) {
  #       $n = $i;
  #       $grid_inter -> add($i);
  # 	$grid_inter -> itemCreate($i, 0, -text => $i, -style=>$header_right);
  #   }
  #   $grid_inter->itemCreate($i, 7, -text => $_, -style=>$style);
  #   $i++;
  # }
}

sub extract_inter_ext {
    my $ext_file = shift;
    open (EXT, "<".$ext_file);
    my @inter = <EXT>; 
    my (@thetas, @omegas, @sigmas);
    my (@headers, @inter_line, $header_line, $inter_line_ref);
    foreach my $line (@inter) {
	if ($line =~ m/ITER/) {
	    $header_line = extract_from_ext_line ($line);
	    @headers = @$header_line;
	} else {
	    $inter_line_ref = extract_from_ext_line ($line);
	    @inter_line = @$inter_line_ref;
	}
    }
    close (EXT);
    my $iter = shift (@inter_line);
    foreach my $header (@headers) {
	if ($header =~ m/THETA/) {
	    push (@thetas, shift (@inter_line));
	}
	if ($header =~ m/OMEGA/) {
	    push (@omegas, shift (@inter_line));
	}
	if ($header =~ m/SIGMA/) {
	    push (@sigmas, shift (@inter_line));
	}
    }
    return (\@thetas, \@omegas, \@sigmas);
}

sub extract_from_ext_line {
    my $line = shift;
    my @vals = split (" ", $line);
    my @values;
    foreach my $val(@vals) {
	$val =~ s/\s//g;
	unless ($val eq "") {
	    push (@values, $val);
	}
    }
    return (\@values)
}

sub extract_inter {
### Purpose : extract intermediate results from files in a folder
### Compat  : W+
  my $dir = shift;
  my (@inter, @lst);
  if ((-e $dir."/INTER")&&(-s $dir."/INTER" > 100)) { # test for minimum file size
    open (INTER,"<".$dir."/INTER");
    @inter = <INTER>;
    close INTER;
  } else {
    @lst = dir (".", $setting{ext_res});
    if (int (@lst) >0) {
      open (INTER,"<".$dir."/".@lst[0]);
      @inter = <INTER>;
      close INTER;
    }
    return();
  }

  my $no_lines = int(@inter);
  if($no_lines>0) {
    my $last_iter=0;
    while (($no_lines>0) && ($last_iter<2)) {  # get last iteration line no
      $no_lines = $no_lines-1;
      if (@inter[$no_lines] =~ m/ITERATION/) {$last_iter++;}
    }

    ### Gather THETA's
    my $theta_line_no = 4;
    my $theta_line_extra = 0;
    if (@inter[$no_lines+$theta_line_no+1] =~ m/TH/g) { $theta_line_extra=1};
    my $theta_line = @inter[$no_lines+$theta_line_no+2+$theta_line_extra];
    if($theta_line_extra == 1) { # 2 lines of THETAs

      $theta_line .= @inter[$no_lines+$theta_line_no+2+$theta_line_extra*2];
    }
    my @theta_arr = split(/\s/,$theta_line);
    my @theta_arr = grep (/\S/, @theta_arr);
    foreach(@theta_arr) {
      $_ = rnd($_, 6)
    };
    my @thetas = @theta_arr;

    ### Gather OMEGA's
    my $omega_line_no = $theta_line_no+5;
    if ($inter[$no_lines+$omega_line_no+1]=~/ET/g) {$omega_line_no++};
    if ($inter[$no_lines+$omega_line_no+1]=~/ET/g) {$omega_line_no++};
    if ($inter[$no_lines+$omega_line_no+1]=~/ET/g) {$omega_line_no++};
    my $curr_lineno = $no_lines + $omega_line_no + 2;
    my @omegas = ();

    until ((@inter[$curr_lineno] =~ m/SIGMA/)||($curr_lineno>@inter)) {
      if ((@inter[$curr_lineno] =~ m/ET/) && (@inter[$curr_lineno+1] ne "")) { # read OMEGA from subsequent lines
        $omega_line = @inter[$curr_lineno+1];
        if(@inter[$curr_lineno+2] =~ m/\./) {
          $omega_line = @inter[$curr_lineno+2];
        };
        if(@inter[$curr_lineno+3] =~ m/\./) {
          $omega_line = @inter[$curr_lineno+3];
        };
        my @omega_arr = split(/\s/,$omega_line);
        @omega_arr = grep (/\S/, @omega_arr);
	foreach (@omega_arr ) { $_ = rnd($_,5);	}
        push (@omegas, \@omega_arr);
      }
      $curr_lineno++;
    }
    my @sigmas = ();
    if (@inter[$curr_lineno] =~ m/SIGMA/) {
      while (($curr_lineno < @inter)&&!(@inter[$curr_lineno] =~ m/ITERATION/gi)) {
        if (@inter[$curr_lineno] =~ m/\./) {
          $sigma_line = @inter[$curr_lineno];
          @sigma_arr = split(/\s/,$sigma_line);
          @sigma_arr = grep /\S/, @sigma_arr;
	  foreach (@sigma_arr ) { $_ = rnd($_,5);	}
	  push (@sigmas, \@sigma_arr);
        }
        $curr_lineno++;
      }
    }
    return \@thetas, \@omegas, \@sigmas;
  } else {return (0)}
}

sub create_duplicates_window {
### Purpose : Create dialog window for making n duplicates from model(s)
### Compat  : W+L+
    my @models = $models_hlist -> selectionGet ();
    my $no_changed = 0; my $prefix = "###"; my $no_duplicates = 100;
    if (@models == 0) {
      message("First select some model to apply this batch funcion on!");
      return() ;
    }
    our $duplicates_window = $mw -> Toplevel(-title=>'Create n duplicates from model(s)');;
    no_resize ($duplicates_window);
    $duplicates_frame = $duplicates_window->Frame(-background=>$bgcol)->grid(-ipadx=>8, -ipady=>8);
    $duplicates_frame -> Label (-background=>$bgcol, -text=>"This will create n copies from one or more model(s),\nadding a suffix (i.e. 'model_001', 'model_002' etc).",-font=>$font_normal,-justify=>"left")->grid(-row=>1, -column=>1, -columnspan=>2,-sticky=>"nw");
    $duplicates_frame -> Label (-background=>$bgcol, -justify=>'left',-text=>" ",-font=>$font_normal,)->grid(-row=>2, -column=>1, -columnspan=>2,-sticky=>"nw");
    $duplicates_frame -> Label (-background=>$bgcol, -text=>"Duplicate models:",-font=>$font_normal,)->grid(-row=>3, -column=>1, -sticky=>"ne");
    $duplicates_frame -> Label (-background=>$bgcol, -justify=>'left',-text=>" ",-font=>$font_normal,)->grid(-row=>4, -column=>1, -columnspan=>2,-sticky=>"nw");
    $duplicates_frame -> Label (-background=>$bgcol, -text=>"Number of duplicates:",-font=>$font_normal,)->grid(-row=>5, -column=>1, -sticky=>"ns");
    $duplicates_frame -> Entry (-textvariable=>\$no_duplicates,-font=>$font_normal,-width=>8, -background=>$white)->grid(-row=>5, -column=>2, -sticky=>"nws");
    $duplicates_frame -> Label (-background=>$bgcol, -justify=>'left',-text=>" ",-font=>$font_normal)->grid(-row=>6, -column=>1, -columnspan=>2,-sticky=>"nw");
    $duplicates_frame -> Checkbutton (-background=>$bgcol, -font=>$font_normal, -text=>"Change run-numbers in ouput/tables?",  -selectcolor=>$selectcol, -activebackground=>$bgcol, -variable=>\$change_run_nos)->grid(-row=>7,-column=>2,-sticky=>'w');
    $duplicates_frame -> Checkbutton (-background=>$bgcol, -font=>$font_normal,-text=>"Use final parameter estimates from reference model?", -selectcolor=>$selectcol, -activebackground=>$bgcol, -variable=>\$est_as_init)->grid(-row=>8,-column=>2,-sticky=>'w');
    $duplicates_frame -> Label (-background=>$bgcol, -justify=>'left',-text=>" ",-font=>$font_normal,)->grid(-row=>9, -column=>1, -columnspan=>2,-sticky=>"nw");
    $duplicates_text = $duplicates_frame -> Scrolled ('Text', -background=>'white', -font=>$font_normal,-width=>18, -height=>8, -scrollbars=>'e')
      -> grid(-row=>3, -column=>2, -ipady=>5, -columnspan=>2,-sticky=>"nws");
    my $models_text = "";
    foreach (@models) {
      if (@file_type_copy[$_] eq "2") {
        push (@batch, @ctl_show[$_]);
        $models_text .= @ctl_show[$_]."\n"
      }
    };
    $duplicates_text -> insert ("0.0", $models_text);
    $duplicates_text -> configure(state=>'disabled');
    my $format = "%01s";
    if($no_duplicates>9) {$format = "%02s"};
    if($no_duplicates>99) {$format = "%03s"};
    if($no_duplicates>999) {$format = "%04s"};
    $mod_nr =~ s/\.$setting{ext_ctl}//i;
    $duplicates_frame -> Button (-text=>"Do", -width=>16, -font=>$font_normal,-background=>$button, -border=>$bbw, -activebackground=>$abutton, -command=> sub {
      my $no_changed = 0;
      foreach my $mod (@batch) {
        for ($k=1; $k<=$no_duplicates; $k++) {
          duplicate_model ($mod, $mod."_".sprintf($format, $k), "", $mod, $change_run_nos, $est_as_init, 0, \%setting);
          $no_changed++;
        }
      }
      message("Duplicated ".$no_changed." models.");
      $duplicates_window -> destroy;
      refresh_pirana($cwd);
      return();
    })->grid(-row=>10,-column=>2,-sticky=>'nws');
    $duplicates_frame -> Button (-text=>"Cancel", -width=>16, -font=>$font_normal,-background=>$button, -border=>$bbw, -activebackground=>$abutton, -command=> sub {
      $duplicates_window -> destroy;
      return();
    })->grid(-row=>10, -column=>1,-sticky=>'nes');
    center_window($duplicates_window, $setting{center_window}); # center after adding frame (redhat)
}

sub batch_replace_block { # change block in models
### Purpose : Create dialog for replacing code in batch of files
### Compat  : W+L+
    my @models = $models_hlist -> selectionGet ();
    my $no_changed = 0;
    if (@models == 0) {
      message("First select some model to apply this batch funcion on!");
      return() ;
    }
    our $replace_block_window = $mw -> Toplevel(-title=>'Change block in models', -background=>$bgcol);;
    no_resize ($replace_block_window);    
    $replace_block_frame = $replace_block_window->Frame(-background=>$bgcol)->grid(-ipadx=>8, -ipady=>8);
    my $block = "\$TABLE";
    $replace_block_frame -> Label (-text=>"This will replace the specified block with a new one.\n",
        -font=>$font_normal,-justify=>"left", -background=>$bgcol)
      ->grid(-row=>1, -column=>1, -columnspan=>2,-sticky=>"nw");
    $replace_block_frame -> Label (-text=>"Find block:",-font=>$font_normal, -background=>$bgcol)
      ->grid(-row=>3, -column=>1, -sticky=>"ne");
    $replace_block_frame -> Entry (-textvariable=>\$block,-font=>$font_normal, -background=>$white)
      ->grid(-row=>3, -column=>2, -sticky=>"nws");
    $replace_block_frame -> Label (-text=>"and replace with:",-font=>$font_normal, -background=>$bgcol)
      ->grid(-row=>5, -column=>1, -sticky=>"ne");

    my $block_replace = $replace_block_frame -> Scrolled ('Text', -background=>'white', -font=>$font_normal, -width=>50, -height=>12, -scrollbars=>'e')
      -> grid(-row=>5, -column=>2, -ipady=>5, -columnspan=>1, -sticky=>"nwse");
    $replace_block_frame -> Label (-text=>"Models:",-font=>$font_normal, -background=>$bgcol)->grid(-row=>7, -column=>1, -sticky=>"ne");

    $replace_block_text = $replace_block_frame -> Scrolled ('Text', -background=>'white', -font=>$font_normal,-width=>18, -height=>8, -scrollbars=>'e')
      -> grid(-row=>7, -column=>2, -ipady=>5, -columnspan=>1, -sticky=>"nws");

    $replace_block_frame -> Label (-justify=>'left',-text=>" ",-font=>$font_normal, -background=>$bgcol)->grid(-row=>4, -column=>1, -columnspan=>2,-sticky=>"nw");
    $replace_block_frame -> Label (-justify=>'left',-text=>" ",-font=>$font_normal, -background=>$bgcol)->grid(-row=>6, -column=>1, -columnspan=>2,-sticky=>"nw");
    $replace_block_frame -> Label (-justify=>'left',-text=>" ",-font=>$font_normal, -background=>$bgcol)->grid(-row=>8, -column=>1, -columnspan=>2,-sticky=>"nw");
    my $models_text = "";
    my @batch;
    foreach (@models) {
      if (@file_type_copy[$_] eq "2") {
        push (@batch, @ctl_show[$_].".mod");
        $models_text .= @ctl_show[$_]."\n"
      }
    };
    $replace_block_text -> insert ("0.0", $models_text);
    $replace_block_text -> configure(state=>'disabled');
    $replace_block_frame -> Button (-text=>"Do", -width=>10, -font=>$font_normal, -background=>$button, -border=>$bbw, -activebackground=>$abutton, -command=> sub {
      my $replace_with = $block_replace -> get("0.0", "end");
      my $no_changed = replace_block(\@batch, $block, $replace_with);
      message($block." block changed in ".$no_changed." models.");
      $replace_block_window -> destroy;
      return();
    })->grid(-row=>10,-column=>2,-sticky=>'nws');
    $replace_block_frame -> Button (-text=>"Cancel", -width=>10, -font=>$font_normal, -background=>$button, -border=>$bbw, -activebackground=>$abutton, -command=> sub {
      $replace_block_window -> destroy;
      return();
    })->grid(-row=>10,-column=>1,-sticky=>'nes');
    center_window($replace_block_window, $setting{center_window}); # center after adding frame (redhat)
}

sub add_code {
### Purpose : Create dialog for adding code to files in batch mode
### Compat  : W+L+
    my @models = $models_hlist -> selectionGet ();
    my $no_changed = 0;
    if (@models == 0) {
      message("First select some model to apply this batch funcion on!");
      return() ;
    }
    our $add_code_window = $mw -> Toplevel(-title=>'Change block in models', -background=>$bgcol);;
    no_resize ($add_code_window);    
    $add_code_frame = $add_code_window->Frame(-background=>$bgcol)->grid(-ipadx=>8, -ipady=>8);
    my $block = "\$TABLE";
    $add_code_frame -> Label (-text=>"This will add the specified code at the end of the selected model files.\n",
        -font=>$font_normal,-justify=>"left", -background=>$bgcol)
      ->grid(-row=>1, -column=>1, -columnspan=>2,-sticky=>"nw");
    $add_code_frame -> Label (-text=>"Code:",-font=>$font_normal, -background=>$bgcol)
      ->grid(-row=>5, -column=>1, -sticky=>"ne");
    my $code_entry = $add_code_frame -> Scrolled ('Text', background=>'white', -font=>$font_normal, -width=>30, -height=>8, -scrollbars=>'e')
      -> grid(-row=>5, -column=>2, -ipady=>5, -columnspan=>2, -sticky=>"nwse");

    $add_code_frame -> Label (-text=>"Models:",-font=>$font_normal, -background=>$bgcol)->grid(-row=>7, -column=>1, -sticky=>"ne");
    $add_code_text = $add_code_frame -> Scrolled ('Text', background=>'white', -font=>$font_normal,-width=>18, -height=>8, -scrollbars=>'e')
      -> grid(-row=>7, -column=>2, -ipady=>5, -columnspan=>2, -sticky=>"nws");
    $add_code_frame -> Label (-justify=>'left',-text=>" ",-font=>$font_normal, -background=>$bgcol)->grid(-row=>6, -column=>1, -columnspan=>2,-sticky=>"nw");
    $add_code_frame -> Label (-justify=>'left',-text=>" ",-font=>$font_normal, -background=>$bgcol)->grid(-row=>8, -column=>1, -columnspan=>2,-sticky=>"nw");

    my $models_text = "";
    my @batch;
    foreach (@models) {
      if (@file_type_copy[$_] eq "2") {
        push (@batch, @ctl_show[$_].".mod");
        $models_text .= @ctl_show[$_]."\n"
      }
    };
    $add_code_text -> insert ("0.0", $models_text);
    $add_code_text -> configure(state=>'disabled');
    $add_code_frame -> Button (-text=>"Do", -width=>16, -font=>$font_normal, -background=>$button, -border=>$bbw, -activebackground=>$abutton, -command=> sub {
      my $code = $code_entry -> get("0.0", "end");
      my $no_changed = 0;
      foreach my $mod (@batch) {
        open (WMOD, ">>".$mod);
        print WMOD $code."\n";
        close WMOD;
        $no_changed++;
      }
      message("Code added to ".$no_changed." model files.");
      $add_code_window -> destroy;
      return();
    })->grid(-row=>10,-column=>2,-sticky=>'nws');
    $add_code_frame -> Button (-text=>"Cancel", -width=>16, -font=>$font_normal, -background=>$button, -border=>$bbw, -activebackground=>$abutton, -command=> sub {
      $add_code_window -> destroy;
      return();
    })->grid(-row=>10,-column=>1,-sticky=>'nes');
    center_window($add_code_window, $setting{center_window}); # center after adding frame (redhat)
}

sub random_sim_block_window {
### Purpose : Create a dialog to change the seed in SIM to a random number (invoke change seed)
### Compat  : W+L+
    my @models = $models_hlist -> selectionGet ();
    my $no_changed = 0;
    if (@models == 0) {
      message("First select some model to apply this batch funcion on!");
      return() ;
    }
    my $sim_seed_window = $mw -> Toplevel(-title=>'Change seeds in $SIM to random number');;
    $sim_seed_window -> OnDestroy ( sub{
        undef $sim_seed_window; undef $sim_seed_frame;
      });
    no_resize ($sim_seed_window);    
    my $sim_seed_frame = $sim_seed_window->Frame(-background=>$bgcol)->grid(-ipadx=>8, -ipady=>8);
    $sim_seed_frame -> Label (-text=>"This will change the seeds in the \$SIMULATION block\nto a random number. Other specifications such as\nUNIFORM/NEW/NONPARAMETRIC are kept.\n",
      -font=>$font_normal,-justify=>"left", -background=>$bgcol)->grid(-row=>1, -column=>1, -columnspan=>2,-sticky=>"nw");
    $sim_seed_frame -> Label (-text=>"Change seeds in:",-font=>$font_normal, -background=>$bgcol)->grid(-row=>2, -column=>1, -sticky=>"ne");
    my $sim_seed_text = $sim_seed_frame -> Scrolled ('Text', background=>'white', -font=>$font_normal,-width=>18, -height=>8, -scrollbars=>'e')
      -> grid(-row=>2, -column=>2, -ipady=>5, -columnspan=>2);
    my $models_text = "";
    my @batch;
    foreach (@models) {
      if (@file_type_copy[$_] eq "2") {
        push (@batch, @ctl_show[$_].".mod");
        $models_text .= @ctl_show[$_]."\n"
      }
    };
    $sim_seed_text -> insert ("0.0", $models_text);
    $sim_seed_text -> configure(state=>'disabled');
    $sim_seed_frame -> Label (-justify=>'left',-text=>" ",-font=>$font_normal, -background=>$bgcol)->grid(-row=>3, -column=>1, -columnspan=>2,-sticky=>"nw");
    $sim_seed_frame -> Button (-text=>"Do", -width=>10, -font=>$font_normal,-background=>$button, -border=>$bbw, -activebackground=>$abutton, -command=> sub {
      my $no_changed = 0;
      foreach my $mod (@batch) {
        change_seed($mod);
        $no_changed++;
      }
      message("\$SIM block changed in ".$no_changed." models.");
      #$sim_seed_window -> destroy;
      return();
    })->grid(-row=>7,-column=>2,-sticky=>'nws');
    $sim_seed_frame -> Button (-text=>"Cancel", -width=>10, -font=>$font_normal,-background=>$button, -border=>$bbw, -activebackground=>$abutton, -command=> sub {
      $sim_seed_window -> destroy;
      return();
    })->grid(-row=>7,-column=>1,-sticky=>'nes');
    center_window($sim_seed_window, $setting{center_window}); # center after adding frame (redhat)
}

