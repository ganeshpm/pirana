#    ----------------------------------------------------------------------
#    Piraña
#    Copyright Ron Keizer, 2007-2009, Amsterdam, the Netherlands
#    ----------------------------------------------------------------------
#
#    This file is part of Piraña.
#
#    Piraña is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    Piraña is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with Piraña.  If not, see <http://www.gnu.org/licenses/>.
#

# Subroutines for pirana
# These are mainly the subs that build parts of the GUI and dialogs.
# As much as possible, subs are located in separate module

sub sge_get_job_cwd {
    my $job = shift;
    my $info_ref = qstat_get_specific_job_info ($job);
    my @info = @$info_ref;
    my $folder;
    foreach my $line (@info) {
	if (substr($line, 0, 3) eq "cwd") {
	    $folder = $line;
	    $folder =~ s/cwd://i;
	    $folder =~ s/^\s+//; #remove leading spaces
	}
    }
    return ($folder);
}

sub create_window_piranaR {
    my ($mw, $script, $start_script_bool, $script_file) = @_;
    my $message = "";
    unless ($R_proc) {
	our ($R_proc, $read) = R_start_process ();
    } else {
	$message = "R session continued from previous session.\n";
    }
    $window_piranaR = $mw -> Toplevel(-title=>"PiranaR");
    if ($^O =~ m/MSWin/) {
	$window_piranaR -> Icon (-image=> $icon);
    }
    $window_piranaR -> OnDestroy ( sub {
	R_stop_process ($R_proc);
	undef ($R_proc);
    });
    my $frame_piranaR  = $window_piranaR -> Frame() -> grid();
    if ($script_file eq "") {$script_file = "test_1.R"};
    my @R_commands; #history of R commands
    my $script_text_box_frame = $frame_piranaR -> Frame() -> grid(-row=> 1, -column=>1,-sticky=>"nwes");
    my $R_interface_box_frame = $frame_piranaR -> Frame() -> grid(-row=> 2, -column=>1,-sticky=>"nwes");
    my $R_interface_box = R_create_R_box ("", "Script text box", $R_interface_box_frame, $R_proc, \@R_commands);
    my $script_text_box = R_create_script_text_box ($script, "Script text box", $script_text_box_frame, $R_proc, $R_interface_box, \@R_commands, $cwd."/".$script_file);

    $window_piranaR -> update();
    
    $R_interface_box -> insert("end","Pirana is trying to start R...", "pirana");
    if ($read =~ m/Perl bridge started/i) {
	$R_interface_box -> insert("end", "Successful.\n", "pirana");
	$R_interface_box -> insert("end", $message, "pirana");				   
	$R_interface_box -> insert("end", "Note: on-screen plotting is not available in PiranaR.\n","pirana");
	$R_interface_box -> insert("end", "> ");
    } else {
	$R_interface_box -> insert("end", "Pirana was unable to start an R process\n","error");
    }
#    R_insert_line ($R_proc, $R_interface_box, "setwd('".$cwd."')", $R_commands_ref, 1);

    if ($start_script_bool == 1 ) {
	my $success = R_insert_multiple_lines ($R_proc, $R_interface_box, $script, $R_commands_ref, 1);
    }
    $window_piranaR -> resizable (0,0);
    $window_piranaR -> raise();
    $window_piranaR -> transient($mw);
}

sub refresh_sge_monitor {
    my ($ssh_ref, $nodes_hlist, $jobs_hlist_running, $jobs_hlist_scheduled, $jobs_hlist_finished, $use_hlist) = @_;
    my %ssh = %$ssh_ref;
    my $ssh_add1 = "";
    my $ssh_add2 = "";
    if ($ssh{connect_ssh} == 1) {
	$ssh_add1 = $ssh{login}." ".$ssh{parameters}." '";
	$ssh_add2 = "'";
    }
    my $job_info_running_ref = qstat_get_jobs_info ($ssh_add1."qstat -u '*' -s r ".$ssh_add2."|");
    my $job_info_scheduled_ref = qstat_get_jobs_info ($ssh_add1."qstat -u '*' -s p ".$ssh_add2."|");
    my $job_info_finished_ref = qstat_get_jobs_info ($ssh_add1."qstat -u '*' -s z ".$ssh_add2."|");
    my $node_info_ref = qstat_get_nodes_info ($ssh_add1."qhost ".$ssh_add2."|");
    my $node_use_ref = qstat_get_nodes_info ($ssh_add1."qstat -g c ".$ssh_add2."|");
    populate_nodes_hlist ($nodes_hlist, $node_info_ref);
    populate_nodes_hlist ($use_hlist, $node_use_ref);
    populate_jobs_hlist ($jobs_hlist_running, $job_info_running_ref);
    populate_jobs_hlist ($jobs_hlist_scheduled, $job_info_scheduled_ref);
    populate_jobs_hlist ($jobs_hlist_finished, $job_info_finished_ref);
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

    my $job_info_ref = qstat_get_jobs_info ($filter);
    populate_jobs_hlist ($jobs_hlist, $job_info_ref);

    if ($filter =~ m/\-s r/) {
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
        [Button => " Intermediate results", -background=>$bgcol,-font=>$font_normal,  -command => sub{
	    my $tabsel = $jobs_hlist -> selectionGet ();
	    my $job_n = @$tabsel[0];
	    $job_n =~ s/job\_//;
	    my $folder = sge_get_job_cwd($job_n);
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
		stop_job ($job_n);
		sleep (1); # short delay to wait for SGE to kill the job (sometimes not enough...);
		my $job_info_running_ref  = qstat_get_jobs_info ($ssh_add1."qstat -s r ".$ssh_add2."|");
		populate_jobs_hlist ($jobs_hlist, $job_info_running_ref);
#		refresh_sge_monitor (\%ssh, $nodes_hlist, $jobs_hlist_running, $jobs_hlist_scheduled, $jobs_hlist_finished);

	    }
	 }],
	] );
      $jobs_hlist -> bind("<Button-3>" => [ sub {
         $tab_hlist -> focus; # focus on listbox widget
         my($w, $x, $y) = @_;
         our $jobsel = $jobs_hlist -> selectionGet ();
         if (@$jobsel >0) { $job_menu -> post($x, $y) } else {
           message("Please select a file first...");
         }
        }, Ev('X'), Ev('Y') ] );
    }
    return ($jobs_hlist);
}

sub job_specific_information_window {
    $job_n = shift;
    my $arr_ref = qstat_get_specific_job_info ($job_n);
    text_window(join ("\n", @$arr_ref), "Job: ".$job_n, $font_fixed);
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
        $jobs_hlist -> itemCreate("job_".@$job[0], 6, -text => @$job[5], -style=>$align_right);
        $jobs_hlist -> itemCreate("job_".@$job[0], 7, -text => @$job[5], -style=>$align_right);
        $jobs_hlist -> itemCreate("job_".@$job[0], 8, -text => @$job[5], -style=>$align_right);
	$i++;
    }
    return();
}

sub sge_monitor_window {
    my $sge_monitor_window = $mw -> Toplevel (-title=>"SGE monitor", -background=>$bgcol);
    my $sge_monitor_window_frame = $sge_monitor_window -> Frame (-background=>$bgcol)->grid(-column=>1, -row=>1,-ipadx=>10, -ipady=>10);
    my $sge_notebook = $sge_monitor_window_frame -> NoteBook(-tabpadx=>5, -font=>$font, -backpagecolor=>$bgcol,-inactivebackground=>$bgcol, -background=>'#FFFFFF') -> grid(-row=>1, -column=>1, -columnspan=>10);
    my $sge_running = $sge_notebook -> add("running", -label=>"Running");
    my $sge_scheduled = $sge_notebook -> add("scheduled", -label=>"Scheduled");
    my $sge_finished = $sge_notebook -> add("finished", -label=>"Finished");
    my $sge_nodes = $sge_notebook -> add("nodes", -label=>"Nodes");
    my $sge_use = $sge_notebook -> add("use", -label=>"Usage");
    my $sge_ssh = $sge_notebook -> add("ssh", -label=>"SSH");

    unless (%ssh) {
	our %ssh ;
	$ssh{connect_ssh} = 0;
	$ssh{login} = $setting{ssh_login};
	$ssh{parameters} = $setting{ssh_parameters};
	$ssh{remote_folder} = $setting{ssh_cluster_mount};
	$ssh{local_folder} = $setting{ssh_local_mount};
    }
    ssh_notebook_tab ($sge_ssh, 3, "");

### Nodes tab:
    my @nodes_headers = qw/hostname architecture ncpu load memtot memuse swapto swapuse/;
    my $nodes_hlist;
    my $node_info_ref = qstat_get_nodes_info ("qhost |");
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
    my $use_info_ref = qstat_get_nodes_info ("qstat -g c |");
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

### Running Jobs tab
    $jobs_hlist_running = tk_table_from_model_output ("qstat -s r |", $sge_running);
    $jobs_hlist_scheduled = tk_table_from_model_output ("qstat -s p |", $sge_scheduled);
    $jobs_hlist_finished = tk_table_from_model_output ("qstat -s z |", $sge_finished);
    refresh_sge_monitor (\%ssh, $nodes_hlist, $jobs_hlist_running, $jobs_hlist_scheduled, $jobs_hlist_finished, $use_hlist);

# main buttons
    $sge_monitor_window_frame -> Button (-text => "Refresh", -font=>$font, -width=>12, -border=>$bbw, -background=>$button, -activebackground=>$abutton, -command => sub{
	refresh_sge_monitor (\%ssh, $nodes_hlist, $jobs_hlist_running, $jobs_hlist_scheduled, $jobs_hlist_finished);
    })-> grid(-column=>1, -row=>8,-sticky=>"nwe");
    $sge_monitor_window_frame -> Button (-text => "Start Qmon", -font=>$font, -width=>12, -border=>$bbw, -background=>$button, -activebackground=>$abutton, -command => sub{
	my $ssh_add1 = "";
	my $ssh_add2 = "";
	if ($ssh{connect_ssh} == 1) {
	    $ssh_add1 = $ssh{login}." ".$ssh{parameters}." '";
	    $ssh_add2 = "'";
	}
	system ($ssh_add1."qmon ".$ssh_add2."&");
    })-> grid(-column=>2, -row=>8,-sticky=>"nwe");

    $sge_monitor_window_frame -> Button (-text => "Close", -font=>$font, -width=>12, -border=>$bbw, -background=>$button, -activebackground=>$abutton, -command => sub{
	$sge_monitor_window -> destroy();
    })-> grid(-column=>3, -row=>8,-sticky=>"nwe");
    $sge_monitor_window -> transient($mw);
}

sub sge_monitor_window_old {
    my $sge_monitor_window = $mw -> Toplevel (-title=>"Create new script", -background=>$bgcol);
    my $sge_monitor_window_frame = $sge_monitor_window -> Frame (-background=>$bgcol)->grid(-column=>1, -row=>1,-ipadx=>10, -ipady=>10);
    $sge_monitor_window_frame -> Label (-text => "Nodes:") -> grid (-column=>1, -row=>1,-sticky=>"ne");
    $sge_monitor_window_frame -> Label (-text => "Jobs:") -> grid (-column=>1, -row=>3,-sticky=>"ne");
    $sge_monitor_window -> resizable (0,0);
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
  my ($script_file, $nm_version, $run_dir, $mod_ref, $run_in_new_dir, $new_dirs_ref, $clusters_ref, $ssh_ref) = @_;
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
      $qsub_base = $clusters{sge_submit_command}." ".$clusters{sge_parameters}." ";
      if ($clusters{sge_priority} ne "") {
	  $qsub_base .= "-p ".$clusters{sge_priority}." ";
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
  if ($ssh{connect_ssh}==1) {
      $nm_command = $nm_dirs_cluster{$nm_version}."/util/".$nmfe_file;
  } else {
      $nm_command = $nm_dirs{$nm_version}."/util/".$nmfe_file;
  }
  my $nm_start_script = os_specific_path ($nm_command);
  my @script;
  push (@script, $drive);
  push (@script, "cd ".$run_dir."\n");
  foreach my $model (@mod) {
      if (($clusters{run_on_sge})&&($clusters{sge_model_as_jobname} == 1)) {
	  $active_project =~ s/\s/\_/g;
	  $qsub = $qsub_base."-N ".substr($active_project."_".$model, 0, 10)." ";
      }
      if($run_in_new_dir == 1) {
	  my $new_dir = shift(@new_dirs);
	  push (@script, "cd ".$new_dir."\n");
      }
      if (($os =~ m/MSWin/i)&&($ssh{connect_ssh} == 0)) {
	  push (@script,"CALL ".$nm_start_script." ".$model.".".$setting{ext_ctl}." ".$model.".".$setting{ext_res}." \n");
      } else {
	  push (@script, $qsub.$nm_start_script." ".$model.".".$setting{ext_ctl}." ".$model.".".$setting{ext_res}." \n");
      }
      if (($clusters{run_on_sge} == 0)&&($clusters{run_on_pcluster} == 0)) {
	  push (@script, "echo Run for model ".$model." finished.\n");
      } else {
	  push (@script, "echo Run for model ".$model." submitted.\n");
     }
      if ($run_in_new_dir == 1) {push(@script, "cd ..\n");}
  }
  push (@script, "echo All runs finished or submitted.\n");
  return ($script_file, \@script);
}

sub write_nm_start_script {
    my ( $script_file, $script_text_ref ) = @_;
    my $script_text = $$script_text_ref;
    open (SCR,">".$script_file);
    print SCR $script_text;
    close (SCR);
}

sub redraw_screen {
### Purpose : Redraw the widgets on the canvas
### Compat  : W+L+
  my ($full_scr, $show_tabs) = @_;
  my $scr_mode;
  if ($full_scr==1) {
     my $width = ($mw->screenwidth)-5;
     my $height;
     if ($os =~ m/MSWin/i) {
       $height = ($mw->screenheight)-70;
       our $entry_width = int((($mw->screenwidth)-750)/5.7);
       our $nrows = int((($mw->screenheight)-240)/14.5);
     } else {
       $height = ($mw->screenheight)-100;
       our $entry_width = int((($mw->screenwidth)-750)/6.2);
       our $nrows = int((($mw->screenheight)-250)/17.8);
     }
     $mw -> geometry($width."x".$height."+0+0");
  } else {
     $mw->geometry($pirana_normal_width."x".$pirana_normal_height);
     center_window($mw);
     our $entry_width = 36;
     our $nrows = 27;
     #$mw -> resizable( 0, 0);
  }
  if ($os =~ m/MSWin/i) {
    $entry_width = $entry_width + (1-$show_tabs)*24;
  } else {
    $entry_width = $entry_width + (1-$show_tabs)*24;
  }
  $models_hlist -> destroy();
  if ($tab_hlist) {$tab_hlist -> destroy(); undef($tab_hlist)};
  if ($tab_frame) {$tab_frame -> destroy(); undef($tab_frame)};
  if ($tab_frame_info) {$tab_frame_info -> destroy(); undef($tab_frame_info)};
  #$models_hlist -> configure(-width=>$entry_width);
  $model_info_no -> configure(-width=>$entry_width );
  $model_info_dataset -> configure(-width=>$entry_width);
  $model_info_modified -> configure(-width=>$entry_width);
  if ($show_tabs == 1) {
    frame_tab_show(1);
    populate_tab_hlist ($tab_hlist);
  }
  frame_models_show(1);
  populate_models_hlist ($setting{models_view}, $condensed_model_list);
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
  my $model_id = @ctl_show[@sel[0]];
  psn_run_window ($model_id, $command);
}
sub wfn_command {
### Purpose : Action when NMGO/NMBS is clicked
### Compat  : W+L+
  my @sel = $models_hlist -> selectionGet ();
  if (@sel == 0) { message("First select a model."); return(); }
  my $model_id = @ctl_show[@sel[0]];
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
  my $model_id = @ctl_show[@sel[0]];
  edit_model(unix_path($cwd."/".$model_id.".".$setting{ext_ctl}));
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
sub delete_models_command {
  my @sel = $models_hlist -> selectionGet ();
  if (@sel == 0) { message("First select a model."); return(); }
  delete_models_window(\@sel);
}
sub generate_report_command {
    my $run_reports_ref = shift;
    @run = @ctl_show[$models_hlist -> selectionGet];
    if (@run == 0) { message("First select a model / result file."); return(); }
    foreach (@run) {
	my $pirana_notes = $models_notes{$_};
	$_ .= ".".$setting{ext_res};
	output_results_HTML($_, \%setting, $pirana_notes, $run_reports_ref);
	start_command($software{browser}, '"file:///'.unix_path($cwd).'/pirana_sum_'.$_.'.html"');
    }
}
sub generate_LaTeX_command {
  my @run;
  @run[0] = shift;
  if (@run[0] = "") {
    @run = @ctl_show[$models_hlist -> selectionGet];
    if (@run == 0) { message("First select a model / result file."); return(); }
  }
  foreach (@run) {$_ .= ".".$setting{ext_res}};
  my $latex = output_results_LaTeX(@run[0], \%setting);
  text_window ($latex, "Parameters for model ".@run[0]);
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
sub R_plot_etas_distribution_command {
  my @sel = $models_hlist -> selectionGet ();
  if (@sel == 0) { message("First select a model / result file."); return(); }
  my $model_id = @ctl_show[@sel[0]];
  my $eta_file = $cwd."/".$model_id.".ETA" ;
  unless (-e $eta_file) {
      message ($model_id.".ETA was not found.\nNote that this feature is only available\when using NM version 7 or higher.");
  };
  unless (-d "pirana_temp") {mkdir ("pirana_temp")};
  my $png = $cwd."/pirana_temp/model_id_etas.png" ;
  my @args = ($eta_file, $png);
  my $res = R_run_script ($R, $base_dir."/R/plot_etas.R", \@args);
  if (-e $png) {
      system ($png);
  } else {
      message ("For some reason, a plot could not be created. Please check R installation and Pirana settings.");
  }
}
sub R_correlation_plot_command {
### Purpose : create a csv file with the correlation matrix, feed it to R+ellipse and create a PDF.
### Compat  : W+L-
  unless (-d $software{r_dir}."/library/ellipse") {message ("You need to have the R-package 'ellipse' installed\nto use this function."); return();};
  my @sel = $models_hlist -> selectionGet();
  if (@sel == 0) { message("First select a model / result file."); return(); }
  my $model_id = @ctl_show[@sel[0]];
  make_clean_dir ($cwd."/pirana_temp");
  my @corr_files;
  if (-e $model_id.".cor") { # NM 7 or higher exports the corr.matrix to a file
      convert_nm_table_file ($model_id.".cor");
      @corr_files = dir ($cwd."/pirana_temp", $model_id.".cor");
  } else {                   # NM 6 or lower: read correlation matrix from results file
       my $lst_file = $model_id.".".$setting{ext_res};
       print $lst_file;
       if (-e $lst_file) {
	   my ($cov_ref, $inv_cov_ref, $corr_ref, $r_ref, $s_ref, $labels_ref) = get_cov_mat ($lst_file);
	   my $available = output_matrix ($corr_ref, $labels_ref, "pirana_temp/".$model_id."_matrix_corr.csv");
       } else {message ("Please select a model of which a result file exists (*.".$setting{ext_res}.")")}
       @corr_files = dir ("pirana_temp", $model_id.".cor");
  }
  if (@corr_files == 0) {
      message ("Error finding information for correlation matrix.")
  } else {
      my $png = $cwd."/pirana_temp/".$corr_file."matrix_corr.png";
      my @args = ($cwd."/pirana_temp/", $png, $model_id);
      my $res = R_run_script ($R, $base_dir."/R/plot_corr_matrix.R", \@args);
      generate_HTML_from_images ($cwd."/pirana_temp/", "correlation.html");
      start_command($software{browser}, '"file:///'.$cwd."/pirana_temp/correlation.html");
  }
  return();
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

sub create_menu_bar {
### Purpose : Create the menu bar
### Compat  : W+L+
  our $mbar = $mw -> Menu(-background=>$bgcol, -border=>0);
  our $mw -> configure(-menu => $mbar);

  our $mbar_file = $mbar -> cascade(-label=>"File", -font=>$font, -background=>$bgcol,-underline=>0, -tearoff => 0);
  $mbar_file -> command(-label => "Preferences...", -font=>$font, -background=>$bgcol,-underline=>0,
		  -command=>sub {
        edit_ini_window("settings.ini", \%setting, \%setting_descr, "Piraña preferences",0)});
  $mbar_file -> command(-label => "Software...", -font=>$font, -background=>$bgcol,-underline=>5,
		  -command=>sub {
		  my $software_ini = "software_linux.ini";
        if ($os =~ m/MSWin/i) {$software_ini = "software_win.ini";}
        edit_ini_window($software_ini, \%software, \%software_descr, "Software integration",1);
      });

  $mbar_file -> command(-label => "Exit",-font=>$font, -underline=>0,-background=>$bgcol,
		  -command=>sub { quit(); } );

  our $mbar_NM = $mbar -> cascade(-label =>"NONMEM", -font=>$font,-background=>$bgcol,-underline=>1, -tearoff => 0);
  $mbar_NM -> command(-label => "Manage NM installations",-font=>$font, -background=>$bgcol,-underline=>1,
		  -command=> sub { manage_nm_window();
     });
  $mbar_NM -> command(-label => "Install NM6/7 using NMQual", -font=>$font,-background=>$bgcol,-underline=>1,
		  -command=> sub { install_nonmem_nmq_window() });
  $mbar_NM -> command(-label => "Install NM6/7 from CD", -font=>$font,-background=>$bgcol,-underline=>0,
		  -command=> sub { install_nonmem_window() });

  if ($os =~ m/MSWin/i) {
    our $mbar_NM_priority = $mbar_NM -> cascade(-label => "Set priority active runs", -font=>$font,-background=>$bgcol,-underline=>1, -tearoff => 0);
    $mbar_NM_priority -> command(-label => "Low", -background=>$bgcol,-underline=>1, -command=> sub {
       my $m = nonmem_priority("low");
       message ($m);
    });
    $mbar_NM_priority -> command(-label => "Normal",-font=>$font, -background=>$bgcol,-underline=>1, -command=> sub {
       my $m = nonmem_priority("normal");
       message ($m);
    });
    $mbar_NM_priority -> command(-label => "High",-font=>$font, -background=>$bgcol,-underline=>1, -command=> sub {
       my $m = nonmem_priority("high");
       message ($m);
    });
  }
  our $mbar_model = $mbar -> cascade(-label =>"Model", -font=>$font,-background=>$bgcol,-underline=>0, -tearoff => 0);
  $mbar_model -> command(-label => "Run (nmfe)",-font=>$font, -image=>$gif{run}, -compound => 'left',-background=>$bgcol, -background=>$bgcol,-underline=>0,
		  -command=> sub { nmfe_command() });
  $mbar_model_psn = $mbar_model -> cascade(-label => "PsN", -font=>$font,-image=>$gif{run}, -compound => 'left',-background=>$bgcol, -background=>$bgcol, -tearoff=>0);
  $mbar_model_psn -> command (-label=> " execute", -font=>$font,-compound => 'left',-image=>$gif{run}, -background=>$bgcol, -command => sub{
       psn_command("execute");
    });
    $mbar_model_psn -> command (-label=> " vpc", -font=>$font,-compound => 'left',-image=>$gif{run}, -background=>$bgcol, -command => sub{
       psn_command("vpc");
    });
    $mbar_model_psn -> command (-label=> " npc",-font=>$font, -compound => 'left',-image=>$gif{run}, -background=>$bgcol, -command => sub{
       psn_command("npc");
    });
    $mbar_model_psn -> command (-label=> " bootstrap",-font=>$font, -compound => 'left',-image=>$gif{run}, -background=>$bgcol, -command => sub{
       psn_command("bootstrap");
    });
    $mbar_model_psn -> command (-label=> " cdd", -font=>$font,-compound => 'left',-image=>$gif{run}, -background=>$bgcol, -command => sub{
       psn_command("cdd");
    });
    $mbar_model_psn -> command (-label=> " llp", -font=>$font,-compound => 'left',-image=>$gif{run}, -background=>$bgcol, -command => sub{
       psn_command("llp");
    });
    $mbar_model_psn -> command (-label=> " sse",-font=>$font, -compound => 'left',-image=>$gif{run}, -background=>$bgcol, -command => sub{
       psn_command("sse");
    });
    $mbar_model_psn -> command (-label=> " sumo",-font=>$font, -compound => 'left',-image=>$gif{edit_info}, -background=>$bgcol, -command => sub{
       psn_command("sumo");
    });

  if ($os =~ m/MSWin/i) {
    $mbar_model_wfn = $mbar_model -> cascade(-label => "WFN", -font=>$font,-image=>$gif{run}, -compound => 'left',-background=>$bgcol, -background=>$bgcol,-underline=>0);
    $mbar_model_wfn -> command (-label=> " NMGO", -font=>$font,-compound => 'left',-image=>$gif{run}, -background=>$bgcol, -command => sub{
        wfn_command("NMGO");
    });
    $mbar_model_wfn -> command (-label=> " NMBS",-font=>$font, -compound => 'left',-image=>$gif{run}, -background=>$bgcol, -command => sub{
        wfn_command("NMBS");
    });
  }
  $mbar_model -> separator ;
  $mbar_model -> command(-label => "Properties", -font=>$font,-compound => 'left',-image=>$gif{edit_info}, -background=>$bgcol,-underline=>0,
		  -command=> sub { properties_command(); });
  $mbar_model -> command(-label => "Edit model", -font=>$font,-image=>$gif{notepad}, -compound=>'left', -background=>$bgcol,-underline=>0,
		  -command=> sub { edit_model_command(); });
  $mbar_model -> command(-label => "Rename model", -font=>$font, -image=>$gif{rename}, -compound=>'left',-background=>$bgcol,-underline=>0,
		  -command=> sub { rename_model_command(); });
  $mbar_model -> command(-label => "Duplicate model", -font=>$font, -image=>$gif{duplicate}, -compound=>'left',-background=>$bgcol,-underline=>0,
		  -command=> sub { duplicate_model_command(); });
  $mbar_model -> command(-label => "Duplicate model for MSF restart",-font=>$font,  -image=>$gif{msf}, -compound=>'left',-background=>$bgcol,-underline=>0,
		  -command=> sub { duplicate_msf_command(); });
  $mbar_model -> command(-label => "Delete model(s)",-font=>$font, -image=>$gif{trash}, -compound=>'left',-background=>$bgcol,-underline=>0,
		  -command=> sub { delete_models_command(); });

  our $mbar_results = $mbar -> cascade(-label =>"Results", -font=>$font,-background=>$bgcol,-underline=>0, -tearoff => 0);



# Run reports
  $mbar_results -> command (-label => "Generate HTML run report", -font=>$font,-background=>$bgcol,-underline=>0,  -image=>$gif{HTML}, -compound=>'left',
		  -command=> sub {
		      generate_report_command(\%run_reports);
      });
  $mbar_results -> command(-label => "LaTeX tables of parameter estimates",-font=>$font, -background=>$bgcol,-underline=>0,  -image=>$gif{latex}, -compound=>'left',
		  -command=> sub {
#           generate_LaTeX_command();
      });
  $mbar_results -> command(-label => "View NM output file", -font=>$font,-background=>$bgcol,-underline=>0,-image=>$gif{notepad}, -compound=>'left',
		  -command=> sub {
		     @run = @ctl_show[$models_hlist -> selectionGet];
         if (@run>0) {
           my @sel = $models_hlist -> selectionGet ();
           my $model_id = @ctl_show[@sel[0]];
           edit_model(unix_path($cwd."\\".$model_id.".".$setting{ext_res}));
         } else {message("Please select model first!")};
       });
  $mbar_results_html = $mbar_results -> cascade (-image=>$gif{question_doc},-font=>$font, -compound=>'left', -label => "Include in run reports", -background=>$bgcol, -tearoff => 0);
  $mbar_results_html -> checkbutton (-label => "Basic run info",-font=>$font, -variable=>\$run_reports{basic_run_info}, -command=> sub{
      save_ini ($home_dir."/ini/run_reports.ini", \%run_reports, \%run_reports_descr);
  });
  $mbar_results_html -> checkbutton (-label => "Notes and comments",-font=>$font, -variable=>\$run_reports{notes_and_comments}, -command => sub{
      save_ini ($home_dir."/ini/run_reports.ini", \%run_reports, \%run_reports_descr);
  });
  $mbar_results_html -> checkbutton (-label => "Model file",-font=>$font, -variable=>\$run_reports{model_file}, -command=>sub{
      save_ini ($home_dir."/ini/run_reports.ini", \%run_reports, \%run_reports_descr);
  });
  $mbar_results_html -> checkbutton (-label => "Parameter estimates of all estimation methods", -font=>$font,-variable=>\$run_reports{param_est_all}, -command => sub {
      if ($run_reports{param_est_all} == 1 ) {
	  $run_reports{param_est_last} = 0;
      }
      save_ini ($home_dir."/ini/run_reports.ini", \%run_reports, \%run_reports_descr);
  });
  $mbar_results_html -> checkbutton (-label => "Parameter estimates of last estimation methods",-font=>$font, -variable=>\$run_reports{param_est_last}, -command => sub {
      if ($run_reports{param_est_last} == 1 ) {
	  $run_reports{param_est_all} = 0;
      }
      save_ini ($home_dir."/ini/run_reports.ini", \%run_reports, \%run_reports_descr);
  });

  our @script_types = ("pl","R","S","py","awk","bat");
  our %assoc_command;
  $assoc_command {pl} = "perl";
  $assoc_command {py} = "python";
  $assoc_command {awk} = "awk";

  our $mbar_scripts = create_scripts_menu ($mbar, "", 1, $base_dir."/scripts", "Scripts", 0);
  $mbar_scripts -> separator;
  our $mbar_scripts_user = create_scripts_menu ($mbar_scripts, "", 1, $home_dir."/scripts", "My scripts", 0);
  $mbar_scripts -> separator;

  our $mbar_scripts_edit = create_scripts_menu ($mbar_scripts, "", 1, $base_dir."/scripts", "Edit script", 1);
  $mbar_scripts_edit -> command (-background=>$bgcol, -font=>$font,-label=> "New script...", -command => sub{
      my $dialog = new_script_dialog ($base_dir."/scripts");
      center_window($dialog);
      $dialog -> focus();
  });
  $mbar_scripts_edit -> separator;
  our $mbar_scripts_edit_user = create_scripts_menu ($mbar_scripts_edit, "", 1, $home_dir."/scripts", "My scripts", 1);
  $mbar_scripts_edit_user -> command (-background=>$bgcol, -font=>$font,-label=> "New script...", -command => sub {
      my $dialog = new_script_dialog ($home_dir."/scripts");
      center_window($dialog);
      $dialog -> focus();
  });

  our $show_console = 1;
  $mbar_scripts -> checkbutton (-label => "Show script console", -font=>$font, -variable => \$show_console);
  $mbar_scripts -> command (-background=>$bgcol, -font=>$font,-label=> "Send model info to PiranaR", -command => sub {
      send_model_info_to_R_command ();
  });
  our $mbar_tools = $mbar -> cascade(-label =>"Tools", -font=>$font, -background=>$bgcol,-underline=>0, -tearoff => 0);

  if ($setting{use_psn}==1) {
    our $mbar_psn = $mbar_tools -> cascade (-label => "PsN",-font=>$font,-background=>$bgcol, -underline=>0, -tearoff => 0);
    if (-e unix_path($software{psn_dir})."/psn.conf") {
      $mbar_psn -> command(-label => "Edit psn.conf (local)",-font=>$font, -background=>$bgcol,-underline=>0,
		    -command=> sub {
			edit_model (unix_path($software{psn_dir}."/psn.conf"));
      });
    }
      $mbar_psn -> command(-label => "Edit PsN default command parameters",-font=>$font, -background=>$bgcol,-underline=>1,
		    -command=> sub {
		      edit_ini_window("psn.ini", \%psn_commands, \%psn_commands_descr, "PsN commands default parameters", 0);
      })
  };
  if ((-e unix_path($software{wfn_dir})."/bin/wfn.bat")&&($os =~ m/MSWin/i)) {
    our $mbar_wfn = $mbar_tools -> cascade (-label => "WFN", -font=>$font,-background=>$bgcol, -underline=>0, -tearoff => 0);
    $mbar_wfn -> command(-label => "Edit wfn.bat", -background=>$bgcol,-underline=>0,
		  -command=> sub {start_command ($software{editor}, win_path($software{wfn_dir}."/bin/wfn.bat"));});
    $mbar_wfn -> command(-label => "Combine bootstrap results", -background=>$bgcol,-underline=>0,
		  -command=> sub {combine_wfn_bootstraps()} );
  };

  if (-d $software{r_dir}) {
    our $mbar_xpose = $mbar_tools -> cascade (-label => "Xpose",-font=>$font, -background=>$bgcol, -underline=>0, -tearoff => 0);
    $mbar_xpose -> command(-label => "xpose.VPC from npc_dir folder", -background=>$bgcol,-underline=>6,
		    -command=> sub {xpose_VPC_window();} );
  };

  our $mbar_tools_batch = $mbar_tools -> cascade(-label =>"Batch processing",-font=>$font, -background=>$bgcol, -tearoff => 0);
  $mbar_tools_batch -> command(-label => "Create n duplicates of model(s)", -font=>$font,-background=>$bgcol,
		  -command=> sub { create_duplicates_window()});
  $mbar_tools_batch -> command(-label => "Add code to models",-font=>$font, -background=>$bgcol,
		  -command=> sub { add_code() });
  $mbar_tools_batch -> command(-label => "Replace blocks", -font=>$font,-background=>$bgcol,
		  -command=> sub { batch_replace_block() });
  $mbar_tools_batch -> command(-label => "Random seeds in \$SIM", -font=>$font,-background=>$bgcol,
		  -command=> sub { random_sim_block_window() });

  $mbar_tools -> command(-label => "PiranaR interface",-image=>$gif{pirana_r}, -font=>$font,-compound=>'left', -background=>$bgcol,-underline=>0,
		  -command=>sub {create_window_piranaR ($mw, "", 0);});
  $mbar_tools -> command(-label => "Covariance calculator",-image=>$gif{calc_cov}, -font=>$font,-compound=>'left', -background=>$bgcol,-underline=>0,
		  -command=>sub {cov_calc_window()});
  $mbar_tools -> command(-label => "Generate summary (csv) of all output", -font=>$font, -image=>$gif{compare}, -compound=>'left',-background=>$bgcol,-underline=>1,
		  -command=> sub {
        create_output_summary ("pirana_output_list.csv");
        if (-e $software{spreadsheet}) {
          start_command($software{spreadsheet},'"'.win_path('pirana_output_list.csv').'"');
        } else {message("Spreadsheet application not found. Please check settings.")};
        status ();
    });
  our $full_screen = 0;
  our $show_tab_list = 1;
  our $mbar_view = $mbar -> cascade(-label =>"View", -font=>$font, -background=>$bgcol,-underline=>0, -tearoff => 0);
  if ($os =~ m/MSWin/i) {
    $mbar_view -> checkbutton (-variable=>\$full_screen, -font=>$font, -image=>$gif{full_screen}, -compound=>'left', -label => "    Full screen", -command=>sub{
      redraw_screen($full_screen, $show_tab_list);
    });
  }
#  $mbar_view -> checkbutton(-variable=>\$show_tab_list, -image=>$gif{split_vertical}, -label=>"    Show tables & files", -compound=>'left', -command=>sub{
#      redraw_screen($full_screen, $show_tab_list);
#  });
  our $show_model_info = 1;
#  $mbar_view -> checkbutton(-variable=>\$show_model_info, -image=>$gif{edit_info}, -label=>"    Show model info / coloring", -compound=>'left', -command=>sub{
#      $run_frame -> destroy();
#      $tab_frame_info -> destroy();
#      refresh_pirana();
#  });
  $mbar_view -> checkbutton (-variable=>\$condensed_model_list, -font=>$font,-image=>$gif{binocular}, -label => "    Condensed view", -compound=>'left',  -command=>sub{
      populate_models_hlist ($models_view, $condensed_model_list);
  });

  $mbar_view -> command (-label => "    Execution log", -font=>$font, -image=>$gif{log}, -compound=>'left',-background=>$bgcol,
	  -command=>sub {
      show_exec_runs_window();
    });
  $mbar_view -> command(-label => "PCluster monitor", -font=>$font, -image=>$gif{pcluster_active}, -compound=>'left',-background=>$bgcol,
		  -command=>sub {cluster_monitor()});

  our $process_monitor = 0;
 #$mbar_view -> checkbutton (-label => "Console output", -variable=> \$process_monitor, -background=>$bgcol,-underline=>1,
 #  -command=>sub {
 #     show_console_output();
 #   });
  $mbar_view -> command (-label => "    Show parameter estimates", -font=>$font,-image=>$gif{estim}, -compound=>'left', -background=>$bgcol,
	  -command=>sub {
        my @lst = @ctl_show[$models_hlist -> selectionGet ()];
        my $lst = @lst[0].".".$setting{ext_res};
        show_estim_window ($lst);
        $estim_window -> raise();
    });
  $mbar_view -> command (-label => "    Intermediate results of active runs", -font=>$font, -image=>$gif{edit_inter}, -compound=>'left',-background=>$bgcol,
	  -command=>sub {
    $cwd = $dir_entry -> get();
      chdir($cwd);
      show_inter_window($cwd);
      if ($inter_window) {$inter_window -> focus();}
   });

  our $mbar_help = $mbar -> cascade(-label =>"Help", -font=>$font, -background=>$bgcol,-underline=>0, -tearoff => 0);
  $mbar_help -> command(-label => "Piraña manual", -font=>$font, -background=>$bgcol,-underline=>0,-command=>sub {system("start ".win_path($base_dir.'\doc\Manual.pdf'))});
  $mbar_help -> command(-label => "Piraña website", -font=>$font, -background=>$bgcol,-underline=>0,-command=>sub {start_command($software{browser},"http://pirana.sf.net")});
  my @nm = values(%nm_dirs);
  our @nm_keys = keys(%nm_dirs);
  unless (@nm_keys == 0) {
    $mbar_help -> command(-label => "NONMEM Help files", -font=>$font, -background=>$bgcol,-underline=>0,-command=>sub {
	start_command($software{browser}, "file://".unix_path($nm_dirs{@nm_keys[0]}."/html/index.htm")) }
    );
  }
  $mbar_help -> command(-label => "NM UsersNet", -font=>$font, -background=>$bgcol,-command=>sub {start_command($software{browser},"http://www.cognigencorp.com/nonmem/sitesearch/index.html")});
  $mbar_help_psn = $mbar_help -> cascade(-label => "PsN", -font=>$font, -background=>$bgcol, -tearoff=>0);
  $mbar_help_psn -> command(-label => "PsN manual", -font=>$font, -background=>$bgcol,-command=>sub {system("start ".win_path($base_dir.'\doc\Manual.pdf'))});
  $mbar_help_psn -> command(-label => "execute", -font=>$font, -background=>$bgcol,-command=>sub { $psn_help_command = get_psn_help ("execute", $software{psn_toolkit}); text_window($psn_help_command, "PsN Help files"); });
  $mbar_help_psn -> command(-label => "vpc", -font=>$font, -background=>$bgcol,-command=>sub { $psn_help_command = get_psn_help ("vpc", $software{psn_toolkit}); text_window($psn_help_command, "PsN Help files"); });
  $mbar_help_psn -> command(-label => "npc", -font=>$font, -background=>$bgcol,-command=>sub { $psn_help_command = get_psn_help ("npc", $software{psn_toolkit}); text_window($psn_help_command, "PsN Help files"); });
  $mbar_help_psn -> command(-label => "bootstrap", -font=>$font, -background=>$bgcol,-command=>sub { $psn_help_command = get_psn_help ("bootstrap", $software{psn_toolkit}); text_window($psn_help_command, "PsN Help files"); });
  $mbar_help_psn -> command(-label => "llp", -font=>$font, -background=>$bgcol,-command=>sub { $psn_help_command = get_psn_help ("llp", $software{psn_toolkit}); text_window($psn_help_command, "PsN Help files"); });
  $mbar_help_psn -> command(-label => "sse", -font=>$font, -background=>$bgcol,-command=>sub { $psn_help_command = get_psn_help ("sse", $software{psn_toolkit}); text_window($psn_help_command, "PsN Help files"); });
  $mbar_help_psn -> command(-label => "sumo", -font=>$font, -background=>$bgcol,-command=>sub { $psn_help_command = get_psn_help ("sumo", $software{psn_toolkit}); text_window($psn_help_command, "PsN Help files"); });

  $mbar_help -> command(-label => "Xpose", -font=>$font, -background=>$bgcol,-command=>sub {start_command($software{browser},"http://xpose.sourceforge.net")});
  $mbar_help -> command(-label => "WFN", -font=>$font, -background=>$bgcol,-command=>sub {start_command($software{browser},"http://wfn.sourceforge.net")});
  $mbar_help -> command(-label => "About Piraña", -font=>$font, -background=>$bgcol, -command=>sub {
  $mw -> messageBox(-type=>'ok',	-message=>"Piraña (version ".$version.")\n   Created by Ron Keizer.\n   Department of Pharmacy & Pharmacology,\n   Slotervaart Hospital / The Netherlands Cancer Institute.\n\nAcknowledgments to the people in my modeling group for testing.\nValuable feedback was also provided by the Uppsala PM group,\nand several other modelers.\n\nhttp://pirana.sf.net\n");
  });
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
    $new_script_window_frame -> Label (-text => "Location:") -> grid (-column=>1, -row=>1,-sticky=>"ne");
    $new_script_window_frame -> Label (-text => "Script filename:") -> grid (-column=>1, -row=>2,-sticky=>"ne");
    $new_script_window_frame -> Label (-text => "Filename:") -> grid (-column=>1, -row=>3,-sticky=>"ne");
    my $full_script_name_label = $new_script_window_frame -> Label (-text => $full_script_name, -foreground=>'#777777' ) -> grid (-column=>2, -row=>3,-sticky=>"nw");
    my $script_template;
    $script_template = $new_script_window_frame -> Checkbutton (-text => "From template (".$template.")", -variable=> \$from_template,  -selectcolor=>$selectcol, -activebackground=>$bgcol, -command=>sub{
	my $ext = get_file_extension ($script_name);
	$template = unix_path($base_dir."/scripts/Template.".$ext);
	$script_template -> configure (-text => "From template (".$template.")");
    })-> grid(-column=>2, -row=>4,-sticky=>"nw");
    my $script_filename_entry = $new_script_window_frame -> Entry (-textvariable => \$script_name, -background=>$white, -width=>32) -> grid (-column=>2, -row=>2,-sticky=>"nw");
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

    $new_script_optionmenu = $new_script_window_frame -> Optionmenu ( -options=> ["Pirana folder","User folder"], -width=>16, -variable=>\$location, -border=>$bbw,
        -font=>$font_normal, -background=>$lightblue, -activebackground=>$darkblue,-command=>sub{
	    if ($location eq "Pirana folder") {
		$full_script_name = unix_path($base_dir."/scripts/".$script_name);
	    } else {
		$full_script_name = unix_path($home_dir."/scripts/".$script_name);
	    }
	    $full_script_name_label -> configure(-text => $full_script_name);
     })->grid(-column=>2,-row=>1,-sticky=>"nw");

    $new_script_window_frame -> Label (-text => "\nNotes:", -background=>$bgcol,-justify=>"left") -> grid (-column=>1, -row=>7,-sticky=>"ne");
   $new_script_window_frame -> Label (-text => "\nAfter creating and saving your script, please restart Pirana to be able to use the script \nfrom the menu.\n\nTo remove the script from the menu, manually delete the script file from the scripts directory\n(See manual for more information)\n", -background=>$bgcol,-justify=>"left") -> grid (-column=>2, -row=>7,-sticky=>"nw");
    $new_script_window_frame -> Button (-text => "Create and open", -width=>15, -border=>$bbw, -background=>$button, -activebackground=>$abutton, -command => sub{
	my $ext = get_file_extension($script_name);
	if (-e $base_dir."/scripts/Template.".$ext) {
	    copy ($base_dir."/scripts/Template.".$ext, $script_name);
	}
	edit_model ($script_name);
	$new_script_window -> destroy();
    })-> grid(-column=>2, -row=>8,-sticky=>"nw");
    $new_script_window -> resizable (0,0);
    return($new_script_window);
}

sub create_scripts_menu {
    my ($menu_parent, $icon, $children, $folder, $title, $edit) = @_;
    my $mbar_scripts;
    if ($icon ne "") {
	$mbar_scripts = $menu_parent -> cascade(-image=> $gif{$icon}, -font=>$font, -label =>$title, -compound=>'left', -background=>$bgcol, -tearoff => 0);
    } else {
	$mbar_scripts = $menu_parent -> cascade(-label => $title, -font=>$font, -background=>$bgcol, -tearoff => 0);
    }
    my @scripts;
    my @commands = ("perl", "R", "R", "python", "awk", "");

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
	    unless ($edit == 1) {
		$mbar_scripts -> command (-label => $script." (".$script_ext.")", -font=>$font, -background=>$bgcol, -command => sub{
		    my @sel = $models_hlist -> selectionGet ();
		    if (@sel == 0) { message("First select a model."); return(); }
		    my @models_sel = @ctl_show[@sel];
		    run_script ($folder."/".$scriptfile, \@models_sel);
   	        });
	    } else {
		$mbar_scripts -> command (-label => $script." (".$script_ext.")", -font=>$font,  -background=>$bgcol, -command => sub{
		    my @sel = $models_hlist -> selectionGet ();
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
  $cov_calc_dialog -> resizable( 0, 0 );
  center_window($cov_calc_dialog);
  my $cov_calc_frame = $cov_calc_dialog-> Frame(-background=>$bgcol)->grid(-ipadx=>'10',-ipady=>'10',-sticky=>'n');
  $cov_calc_frame -> Label (-text=>"Covariance block:",-background=>$bgcol) -> grid(-row=>1, -column=>1);
  my $var1=1; my $covar=1; my $var2=1;
  $var1_entry  = $cov_calc_frame -> Entry (-width=>6, -background=>'white',-textvariable=>\$var1, -justify=>"right") -> grid(-row=>1, -column=>2);
  $covar_entry = $cov_calc_frame -> Entry (-width=>6, -background=>'white', -textvariable=>\$covar,-justify=>"right") -> grid(-row=>2, -column=>2);
  $var2_entry  = $cov_calc_frame -> Entry (-width=>6, -background=>'white', -textvariable=>\$var2,-justify=>"right") -> grid(-row=>2, -column=>3);
  $var1_entry -> bind('<Any-KeyPress>' => sub { recalc_cov($var1,$var2,$covar)});
  $var2_entry -> bind('<Any-KeyPress>' => sub { recalc_cov($var1,$var2,$covar)});
  $covar_entry -> bind('<Any-KeyPress>' => sub {recalc_cov($var1,$var2,$covar)});
  $cov_calc_frame -> Label (-text=>" ",-background=>$bgcol) -> grid(-row=>3, -column=>1);
  $cov_calc_frame -> Label (-text=>"SD1:", -foreground=>"#666666",-background=>$bgcol) -> grid(-row=>4, -column=>1,-sticky=>'e');
  $cov_calc_frame -> Label (-text=>"SD2:", -foreground=>"#666666",-background=>$bgcol) -> grid(-row=>5, -column=>1,,-sticky=>'e');
  $cov_calc_frame -> Label (-text=>"Correlation:", -foreground=>"#666666",-background=>$bgcol) -> grid(-row=>6, -column=>1,,-sticky=>'e');
  our $var1_sd=rnd(sqrt($var1),3); our $var2_sd=rnd(sqrt($var1),3); our $covar_sd=rnd(sqrt($covar/($var1_sd*$var2_sd)),3);
  $var1_sd_entr = $cov_calc_frame -> Entry (-width=>6, -textvariable=>\$var1_sd, -justify=>"right", -background=>$bgcol, -foreground=>'#666666') -> grid(-row=>4, -column=>2);
  $var2_sd_entr = $cov_calc_frame -> Entry (-width=>6, -textvariable=>\$covar_sd,-justify=>"right", -background=>$bgcol, -foreground=>'#666666') -> grid(-row=>6, -column=>2);
  $covar_sd_entr = $cov_calc_frame -> Entry (-width=>6, -textvariable=>\$var2_sd,-justify=>"right", -background=>$bgcol, -foreground=>'#666666') -> grid(-row=>5, -column=>2);
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
  print "Writing ".$csv_file."\n";
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

sub xpose_VPC_window {
### Purpose : Create a dialog window for creating VPC with R/Xpose from a directory created with PsN
### Compat  : W+L?
  my @dirs = @ctl_show[$models_hlist -> selectionGet ()];
  my $dir = @dirs[0];
  my $pdf_file = $dir.".pdf";
  my $script_file = "pirana_xpose_VPC.R";
  if (-d $dir) {
  my @vpctab = <vpctab>;
  if (-e $dir."/vpc_results.csv") {
  my $vpc_dialog = $mw -> Toplevel(-title=>'Create VPC from PsN-generated VPC/NPC data');
  $vpc_dialog -> resizable( 0, 0 );
  center_window($vpc_dialog);
  my $vpc_dialog_frame = $vpc_dialog-> Frame(-background=>$bgcol)->grid(-ipadx=>'10',-ipady=>'10',-sticky=>'n');
  my $vpc_code_text = $vpc_dialog_frame -> Scrolled ("Text", -scrollbars=>'e',
   -width=>70, -height=>10, -relief=>groove, -exportselection => 0,
    -border=>1, -wrap=>'none'
  )->grid(-row=>1,-column=>1,-sticky=>"we");
  open (VPC, "<".$base_dir."/internal/pirana_xpose_VPC.R");
  my @lines = <VPC>; my $r_text;
  close VPC;
    $vpc_code_text -> insert ("end", join ("", @lines));
  $vpc_help = $vpc_dialog_frame -> Button (-image=>$gif{help}, -background=>$button, -activebackground=>$abutton,-command=>sub {
    if (-e $software{r_dir}."/library/xpose4specific/html/xpose.VPC.html") {
      start_command ($software{browser}, win_path($software{r_dir}.'/library/xpose4specific/html/xpose.VPC.html'));
    } else {message ("Xpose help file not found!")};
  })-> grid(-row=>7,-column=>1,-sticky=>"w");
  $help -> attach($vpc_help, -msg => "Open VPC help file");

  $vpc_dialog_frame -> Button (-text=>'Create VPC', -width=>12, -border=>$bbw, -background=>$button, -activebackground=>$abutton,-command=>sub {
    my $vpc_code = $vpc_code_text -> get("0.0", "end");
    open (TEMPL, ">".$base_dir."/internal/pirana_xpose_VPC.R"); # update template
    print TEMPL $vpc_code;
    close TEMPL;
    my $pre_code = "library(xpose4)\npdf(file='".$pdf_file."')\nnpc_dir <- '".$dir."'\n";
    my $end_code = "\ndev.off()\n";
    $vpc_code = $pre_code.$vpc_code.$end_code;
    open (VPC, ">".$script_file);
    print VPC $vpc_code;
    close VPC;

    $vpc_dialog -> destroy();
    run_script ('"'.$software{r_dir}.'\bin\R" --vanilla <'.$script_file.' |');
    if (-e $pdf_file) {system "start ".$pdf_file};
  }) -> grid(-row=>7,-column=>1,-sticky=>"e");
  } else {
    message ("VPC files not found in folder (".$dir.")!")
  }
  } else {message ("Please select a valid folder")}
}

sub send_object_to_piranaR {
    my ($models_ref, $script_add) = @_;
    my $object = "models <- ".create_R_object_from_models ($models_ref);
    create_window_piranaR ($mw, $object.$script_add, 1, "temp");
}

sub run_script {
### Purpose : Run an R / perl (or other type of) script an capture the console output
    my ($scriptfile, $models_ref) = @_;
    unless (-d "pirana_temp") {mkdir ("pirana_temp")}
    my @spl = split (/\//, $scriptfile);
    my $scriptfile_nopath = pop(@spl) ;
    copy ($scriptfile, "pirana_temp/".$scriptfile_nopath);
    update_script_with_parameters ("pirana_temp/".$scriptfile_nopath, $models_ref);
    my @spl = split (/\./, $scriptfile);
    my $ext = pop (@spl);
    open (SCR, "<pirana_temp/".$scriptfile_nopath);
    my @lines = <SCR>;
    my $script = join ("", @lines);
    close SCR;
    if ($ext eq "R") {
	if ($^O =~ m/MSWin/) {
	    run_command_in_console ('"'.$software{r_dir}.'\bin\R" --vanilla <"'.unix_path($cwd."/pirana_temp/".$scriptfile_nopath.'"'));
	} else {
	    run_command_in_console ('"'.$software{r_exec}.'" --vanilla <"'.unix_path($cwd."/pirana_temp/".$scriptfile_nopath.'"'));
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

sub run_command_in_console {
### Purpose : Run a command and capture the console output
### Compat  : W+L?
    $command = shift;
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
		$console -> insert('end', "Pirana: Trying to load file ".$script_output."\n", "pirana");
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
  $msf_dialog -> resizable( 0, 0 );
  center_window($msf_dialog);
  $msf_dialog_frame = $msf_dialog-> Frame(-background=>$bgcol)->grid(-ipadx=>'10',-ipady=>'10',-sticky=>'n');

  $msf_dialog_frame -> Label (-background=>$bgcol, -text=>'New model number (without '.$setting{ext_ctl}.'):')->grid(-row=>1,-column=>1,-sticky=>"e");
  $msf_dialog_frame -> Entry (-width=>8, -border=>2, -relief=>'groove', -background=>$white,
     -textvariable=>\$new_ctl_name)->grid(-row=>1,-column=>2,-sticky=>"w");
  $msf_dialog_frame -> Label (-background=>$bgcol, -text=>'Restart using MSF file:')->grid(-row=>2,-column=>1,-sticky=>"e");
  my $restart_msf_entry = $msf_dialog_frame -> Entry (-width=>12, -border=>2, -relief=>'groove', -text=>$msf,  -background=>$white,
     -textvariable=>\$msf)->grid(-row=>2,-column=>2,-sticky=>"w");
  $msf_dialog_frame -> Label (-background=>$bgcol, -text=>'New MSF file:')->grid(-row=>3,-column=>1,-sticky=>"e");
  my $new_msf_entry = $msf_dialog_frame -> Entry (-width=>12, -border=>2, -relief=>'groove', -text=>$new_msf,  -background=>$white,
     -textvariable=>\$new_msf)->grid(-row=>3,-column=>2,-sticky=>"w");
  $msf_dialog_frame -> Label (-background=>$bgcol, -text=>"\nNB. Parameter estimates will be commented out.\n", -foreground=>"#444444",-justify=>"left")->grid(-row=>5,-column=>1,-columnspan=>2,-sticky=>"w");
  $msf_dialog_frame -> Button (-text=>'Create', -width=>12, -border=>$bbw, -background=>$button, -activebackground=>$abutton,-command=>sub {
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
    if (($software{editor} eq "")||(!(-e $software{editor}))) {
	open (IN, "<".$modelfile);
	my @lines = <IN>;
	close IN;
	my $text = join ("",@lines);
	text_edit_window ($text, $modelfile, \$mw, $font_fixed);
    } else {
	start_command($software{editor}, '"'.$modelfile.'"');
    }
}

sub tree_models {
### Purpose : Generate a tree structure and return them as array and text
### Compat  : W+L?
  undef @ctl_copy_order; undef @tr_unsort; undef @tr; undef @tr_sorted;
  undef %tree; undef %model_indent;
  my %tree ;
  my @tr;
  my $i=0;
  foreach (@ctl_copy) {
    if ($file_type{@ctl_copy[$i]}==2) {
      if ((-e $models_refmod{@ctl_copy[$i]}.".".$setting{ext_ctl})&&($models_refmod{@ctl_copy[$i]} ne "")) {
        if (exists ($tree{$models_refmod{@ctl_copy[$i]}})) {
          $tree{$_} = $tree{$models_refmod{@ctl_copy[$i]}}."::";
        } else {
          $tree{$_} = $models_refmod{@ctl_copy[$i]}."::";  # unknown model as parent
        }
      }
      $tree{$_} .= @ctl_copy[$i];
    } else {
      push(@tr, $_); # directories
    }
    $i++;
  }
  our @tr_unsort;
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

  # generate a tree in text format
    my %lastchild;
  foreach(@tr_sorted) { # get the lastchild's number
    @line = split (/\:\:/, $_);
    $lastchild {@line[-2]} = @line[-1];
  }
  $last_root_child = @line[0];
  $tree = "";
  my @flags ; my $ofv;
  foreach (@tr_sorted) {
    my @line = split (/\:\:/, $_);
    for ($i=1; $i<=@line; $i++) {
      $tree .= "    ";
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
      $dofv = rnd($models_ofv{@line[-2]}-$models_ofv{@line[-1]},3);
    } else {
      $dofv = "";
    }
    if ($models_ofv{@line[-1]} ne "") { $ofv = $models_ofv{@line[-1]}."\t" } else {$ofv ="\t"}
    if (@line>1) {$space="\t"} else {$space="\t\t"}; # try to keep things in line
    if (@line>3) {chop($space);};
    my $info = $models_suc{@line[-1]}.$models_cov{@line[-1]}.$models_bnd{@line[-1]}."\t".$models_sig{@line[-1]};
    $tree .=  @line[-1].$space."\t".$ofv." (".$dofv.") \t".$info."\n";
  }
  return (\@ctl_copy_order, $tree);
}

sub project_info_window {
### Purpose : Create a dialog shown info for the current project
### Compat  : W+L+
### Note    : save functionality not implemented yet

  # Get project info from database
  my %proj_record;
  my @sql_fields = ("proj_name","descr","modeler","collaborators","start_date","end_date");
  my $db_results = db_get_project_info();
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
    $project_window -> resizable( 0, 0 );
  }
  our $project_window_frame = $project_window -> Frame(-background=>$bgcol)->grid(-ipadx=>10,-ipady=>10)->grid(-row=>1,-column=>1, -sticky=>'nwse');
  my @labels  = ("Project name: ","Description: ","Modeler: ","Collaborators: ","Start date: ","End date: ");
  my @widths  = (20, 40, 20, 40, 20, 20);
  my %proj_rec_entry;
  for ($i=0; $i<@labels; $i++) {
    $project_window_frame -> Label(-text=> @labels[$i], -font=>$font_normal) ->grid(-row=>($i*2)+1,-column=>1,-sticky=>'e');
    $proj_rec_entry{@sql_fields[$i]} = $project_window_frame -> Entry(-text=> $proj_record{@sql_fields[$i]}, -font=>$font_normal, -relief=>'sunken',-border=>$bbw, -width=>@widths[$i],  -background=>$white) -> grid(-row=>($i*2)+1,-column=>2,-sticky=>'w');
    $project_window_frame -> Label(-text=> " ", -font=>$font_normal) ->grid(-row=>($i*2)+2,-column=>1);
  }
  $i++;
  $project_window_frame -> Label(-text=> "Notes:", -font=>$font_normal) ->grid(-row=>($i*2)+1,-column=>1,-sticky=>'e');
  my $proj_notes_text = $project_window_frame ->Scrolled('Text',
      -width=>40, -relief=>'sunken',
      -border=>$bbw,-height=>10,
      -font=>$font_normal, -background=>'white',
      -state=>'normal',-scrollbars=>'e'
  )->grid(-column=>2, -row=>($i*2)+1,-rowspan=>10,-sticky=>'nw');
  $proj_notes_text -> insert("0.0", $proj_record{"notes"});
  $project_window_frame -> Label (-text=>'  ')->grid(-column=>2, -row=>30,-rowspan=>1);
  $project_window_frame -> Button (-text=>'Save', -width=>12, -background=>$button, -activebackground=>$abutton, -border=>$bbw, -command=>sub{
    foreach (keys(%proj_rec_entry)) {
      $proj_record{$_} = $proj_rec_entry{$_} -> get();
    }
    $proj_record{"notes"} = $proj_notes_text -> get("0.0", "end");
    db_insert_project_info (\%proj_record);
    $project_window -> destroy();
  })->grid(-column=>2, -row=>31,-rowspan=>1, -sticky=>"w");
  $project_window_frame -> Button (-text=>'Cancel', -width=>12, -background=>$button, -activebackground=>$abutton, -border=>$bbw, -command=>sub{
    $project_window -> destroy();
  })->grid(-column=>1, -row=>31,-rowspan=>1, -sticky=>"e");
}

sub show_estim_window {
### Purpose : Show window with final parameter estimates
### Compat  : W+L?
    my $lstfile = shift;
    my $modelfile = $lstfile;
    $modelfile =~ s/$setting{ext_res}/$setting{ext_ctl}/i;

    my ($th_ref, $om_ref, $si_ref, $th_se_ref, $om_se_ref, $si_se_ref) = get_estimates_from_lst ($lstfile);
    my ($methods_ref, $est_ref, $term_ref) = get_estimates_from_lst ($lstfile);
    my @methods = @$methods_ref;
    my %est = %$est_ref;

#    print @methods;
    my $last_method = @methods[-1] ;  # take results from the last estimation method
    my $res_ref = $est{$last_method};
    my @res = @$res_ref;
    my $theta_ref = @res[0];  my @th = @$theta_ref;
    my $omega_ref = @res[1];  my @om = @$omega_ref;
    my $sigma_ref = @res[2];  my @si = @$sigma_ref;
    my $theta_se_ref = @res[3];  my @th_se = @$theta_se_ref;
    my $omega_se_ref = @res[4];  my @om_se = @$omega_se_ref;
    my $sigma_se_ref = @res[5];  my @si_se = @$sigma_se_ref;

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

    unless ($estim_window) {
	our $estim_window = $mw -> Toplevel();
	$estim_window -> OnDestroy ( sub{
	    undef $estim_window; undef $estim_window_frame; undef @estim_grid; undef @estim_headers;
				     });
	$estim_window -> resizable( 0, 0 );
    }
    our $estim_window_frame = $estim_window -> Frame(-background=>$bgcol)->grid(-ipadx=>10,-ipady=>10)->grid(-row=>1,-column=>1, -sticky=>'nwse');

    @estim_grid_headers = ("Parameter", "Description", "Value");
    our $estim_grid = $estim_window_frame ->Scrolled('HList', -head => 1,
						     -columns    => $cols+2, -scrollbars => 'se',-highlightthickness => 0,
						     -height     => 25, -width      => 90,
						     -border     => 0, -indicator=>0,
						     -background => 'white',
	)->grid(-column => 1, -columnspan=>7,-row => 2,-sticky=>'nwse');
    $estim_grid -> columnWidth(1, 120);

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

    $i = 1; $j=1; my $max_i = 1;
    if (@th>0) {
	$estim_window ->configure (-title=>$lstfile." (".$last_method.")");
	$estim_grid -> delete("all");
	$estim_grid -> add($i);
	$estim_grid -> itemCreate($i, 0, -text => "TH 1", -style=>$header_right);
	foreach my $th (@th) {
	    if ($i>1) {
		$estim_grid -> add($i);
		$estim_grid -> itemCreate($i, 0, -text => $i, -style=>$header_right);
	    }
	    my $th_text = rnd($th,4);
	    my $th_rse = "";
	    if (($th!=0)&&(@th_se[$i-1]!=0)) {
		$th_rse = " (".rnd((@th_se[$i-1]/$th*100),3)."%)";
	    }
	    $estim_grid -> itemCreate($i, 2, -text => $th_text, -style=>$estim_style);
	    $estim_grid -> itemCreate($i, 3, -text => $th_rse, -style=>$estim_style_light);
	    $estim_grid -> itemCreate($i, 1, -text => @theta_names[$i-1], -style=>$align_left);
	    $i++;
	}
	if ($max_i > $i) {$i = $max_i};
	$i++;
	$estim_grid -> add($i);
	$estim_grid -> itemCreate($i, 0, -text => " ", -style=>$header_right);
	$i++; my $flag=$i; $cnt=1;
	foreach my $om (@om) {
	    @om_x = @$om; $j = 1;
	    $estim_grid -> add($i);
	    if ($flag==$i) {
		$estim_grid -> itemCreate($i, 0, -text => "OM 1", -style=>$header_right);
	    } else {
		$estim_grid -> itemCreate($i, 0, -text => $cnt, -style=>$header_right);
	    }
	    $estim_grid -> itemCreate($i, 1, -text => @omega_names[$cnt-1], -style=>$align_left);
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
		$estim_grid -> itemCreate($i, $j+1, -text => $om_text, -style=>$style);
		$j++;
	    }
	    $i++; $cnt++;
	}
	$i++;
	$estim_grid -> add($i);
	$estim_grid -> itemCreate($i, 0, -text => " ", -style=>$header_right);
	$i++; my $flag=$i; $cnt=1;
	foreach my $si (@si) {
	    @si_x = @$si; $j = 1;
	    $estim_grid -> add($i);
	    if ($flag==$i) {
		$estim_grid -> itemCreate($i, 0, -text => "SI 1", -style=>$header_right);
	    } else {
		$estim_grid -> itemCreate($i, 0, -text => $cnt, -style=>$header_right);
	    }
	    $estim_grid -> itemCreate($i, 1, -text => @sigma_names[$cnt-1], -style=>$align_left);
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
		$estim_grid -> itemCreate($i, $j+1, -text => $si_text, -style=>$estim_style);
		$j++;
	    }
	    $i++; $cnt++;
	}
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
  my $nm_inst_w = $mw -> Toplevel(-title=>"Add existing NONMEM installation to Piraña");
  $nm_inst_w -> resizable( 0, 0 );
  center_window($nm_inst_w);
  my $nm_inst_frame = $nm_inst_w -> Frame(-background=>$bgcol)->grid(-ipadx=>'10',-ipady=>'10',-sticky=>'n');
  $nm_inst_frame -> Label (-text=>"Local/remote: ",-background=>$bgcol)->grid(-row=>1,-column=>1,-sticky=>"e");
  $nm_inst_frame -> Label (-text=>"Name in Piraña: ",-background=>$bgcol)->grid(-row=>2,-column=>1,-sticky=>"e");
  $nm_inst_frame -> Label (-text=>"NM Location: ",-background=>$bgcol)->grid(-row=>3,-column=>1,-sticky=>"e");
  $nm_inst_frame -> Label (-text=>"NM version: ",-background=>$bgcol)->grid(-row=>4,-column=>1,-sticky=>"e");
  my $nm_name="NM6";
  my $nm_dir ="C:\\nmvi";
  unless ($os =~ m/MSWin/i) {
    $nm_dir = "/opt/nmvi";
  }
  my $nm_type = "regular";
  my $nm_locality = "Local";
  $nm_inst_frame -> Entry (-textvariable=>\$nm_name,  -background=>$white, -border=>$bbw,-width=>16,-border=>2, -relief=>'groove')
         ->grid(-column=>2,-row=>2,-sticky=>"w");
  $nm_inst_frame -> Entry (-textvariable=>\$nm_dir, -background=>$white, -border=>$bbw,-width=>40,-border=>2, -relief=>'groove')
         ->grid(-column=>2,-row=>3,-sticky=>"w");
  my $browse_button = $nm_inst_frame -> Button(-image=>$gif{browse}, -width=>28, -border=>0, -command=> sub{
      $nm_dir = $mw-> chooseDirectory();
      if($nm_dir eq "") {$nm_dir = "C:\\nmvi"};
      $nm_inst_w -> focus();
  })->grid(-row=>3, -column=>2, -rowspan=>1, -sticky => 'nse');
  $help->attach($browse_button, -msg => "Browse filesystem");
  $nm_inst_frame -> Optionmenu (-options=>["Local","Remote (SSH)"], -width=>16, -variable=>\$nm_locality,-border=>$bbw,
    -font=>$font_normal, -background=>$lightblue, -activebackground=>$darkblue)
         ->grid(-column=>2,-row=>1,-sticky=>"w");
  $nm_inst_frame -> Optionmenu (-options=>["5","6","7"],-variable=>\$nm_ver,-border=>$bbw,-font=>$font_normal,
    -background=>$lightblue, -activebackground=>$darkblue)
         ->grid(-column=>2,-row=>4,-sticky=>"w");
  $nm_inst_frame -> Label (-text=>" ",-background=>$bgcol)->grid(-row=>5,-column=>1,-sticky=>"e");
  my $nm_ini_file;
  $nm_inst_frame -> Button (-text=>"Add", -width=>12, -background=>$button, -border=>$bbw, -activebackground=>$abutton, -command=> sub{
    if ($nm_dirs{$nm_name}) {
      message("A NONMEM installation with that name already exists in Piraña.\nPlease choose another name.")
    } else {
      $valid_nm = 0;
      if ($nm_locality eq "Local") {
	  $nm_ini_file = "nm_inst_local.ini";
	  # look if it is maybe an NMQual NM isntallation
	  $nmq_name = get_nmq_name($nm_dir);
	  if (-e unix_path($nm_dir."/test/".$nmq_name.".pl")) {
	      $nm_type = "nmqual";
	      $valid_nm = 1;
	  }
	  # regular installation
	  if ((-e unix_path($nm_dir."/util/nmfe".$nm_ver).".bat")||(-e unix_path($nm_dir."/util/nmfe".$nm_ver))) {
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
	if ($nm_locality eq "Local") {
	    $nm_dirs{$nm_name} = $nm_dir;
	    $nm_vers{$nm_name} = $nm_ver;
	    $nm_types{$nm_name} = $nm_type;
	    save_ini ($home_dir."/ini/".$nm_ini_file, \%nm_dirs, \%nm_vers);
	    chdir($cwd);
	    unless ($nm_type eq "regular") {
		nmqual_compile_script ($nm_dir, $nmq_name);
	    };
	} else {
	    $nm_dirs_cluster{$nm_name} = $nm_dir;
	    $nm_vers_cluster{$nm_name} = $nm_ver;
	    $nm_types_cluster{$nm_name} = $nm_type;
	    save_ini ($home_dir."/ini/".$nm_ini_file, \%nm_dirs_cluster, \%nm_vers_cluster);
	}
	undef $nm_versions_menu;
	$nm_inst_w -> destroy;
	$sizes_w -> destroy;

	# (re)load NM help files
	my $nm_help_ref = get_nm_help_keywords ($nm_dir."/html");
	our @nm_help_keywords = @$nm_help_ref;
	if ($nm_help_entry) {
	    $nm_help_entry -> configure(-state=>'normal');
	}

    } else {
	message("Cannot find nmfe".$nm_ver.".bat (regular installation) or Perl-file (NMQual).\n Check if installation is valid.")
    };
  })-> grid(-row=>6,-column=>2,-sticky=>"w");
  $nm_inst_frame -> Button (-text=>"Cancel", -width=>12, -background=>$button, -border=>$bbw, -activebackground=>$abutton, -command=> sub{
    $nm_inst_w->destroy;
  })-> grid(-row=>6,-column=>1,-sticky=>"e");
}

sub remove_nm_inst {
### Purpose : Remove an NM installation from Pirana (but don't delete the installation)
### Compat  : W+L?
  $nm_remove_w = $mw -> Toplevel(-title=>"Remove NONMEM installation from Piraña");
  $nm_remove_w -> resizable( 0, 0 );
  center_window($nm_remove_w);
  $nm_remove_frame = $nm_remove_w -> Frame(-background=>$bgcol)->grid(-ipadx=>'10',-ipady=>'10',-sticky=>'n');
  $nm_remove_frame -> Label (-text=>"Installation: ")->grid(-row=>1,-column=>1,-sticky=>"e");
  $nm_remove_frame -> Label (-text=>"NONMEM Location: ")->grid(-row=>2,-column=>1,-sticky=>"e");
  $nm_remove_frame -> Label (-text=>"NONMEM version: ")->grid(-row=>3,-column=>1,-sticky=>"e");
  ($nm_name,@dummy) = keys(%nm_dirs);

  $nm_dir_entry = $nm_remove_frame -> Entry ( -background=>$white, -textvariable=>\$nm_dirs{$nm_name},-border=>$bbw,-width=>30,-state=>"disabled", -border=>2, -relief=>'groove')
         ->grid(-column=>2,-row=>2,-sticky=>"w");
  $nm_ver_entry = $nm_remove_frame -> Entry ( -background=>$white, -textvariable=>\$nm_vers{$nm_name},-border=>$bbw,-width=>2,-state=>"disabled", -border=>2, -relief=>'groove')
         ->grid(-column=>2,-row=>3,-sticky=>"w");

  $nm_remove_frame -> Optionmenu (-options=>[keys(%nm_dirs)],-variable=>\$nm_name,-border=>$bbw,-width=>10,-font=>$font_normal, -background=>$lightblue, -activebackground=>$darkblue, -command=>sub{
      $nm_dir_entry -> configure(-textvariable=>\$nm_dirs{$nm_name});
      $nm_ver_entry -> configure(-textvariable=>\$nm_vers{$nm_name});
    })->grid(-column=>2,-row=>1,-sticky=>"w");
  $nm_remove_frame -> Label (-text=>" ")->grid(-row=>4,-column=>1,-sticky=>"e");
  $nm_remove_frame -> Button (-text=>"Remove", -width=>12, -background=>$button, -border=>$bbw, -activebackground=>$abutton, -command=> sub{
    delete $nm_dirs{$nm_name};
    delete $nm_vers{$nm_name};
    save_ini ($home_dir."/ini/nm_inst_local.ini", \%nm_dirs, \%nm_vers);
    ($nm_dirs_ref,$nm_vers_ref) = read_ini($home_dir."/ini/nm_inst_local.ini");
    %nm_dirs = %$nm_dirs_ref; %nm_vers = %$nm_vers_ref;
    chdir($cwd);
    refresh_pirana($cwd);
    $nm_remove_w -> destroy;
  })-> grid(-row=>5,-column=>2,-sticky=>"w");
  $nm_remove_frame -> Button (-text=>"Cancel", -width=>12, -background=>$button, -border=>$bbw, -activebackground=>$abutton, -command=> sub{
    $nm_remove_w->destroy;
  })-> grid(-row=>5,-column=>1,-sticky=>"e");
}

sub save_ini {
### Purpose : Save Pirana settings contained in a hash to ini-file.
### Compat  : W+L?
  ($ini_file, $ref_ini, $ref_ini_descr, $ref_add_1, $cat_ref) = @_;
  my %ini = %$ref_ini;
  my %ini_descr = %$ref_ini_descr;
  my %ini_add_1;
  if ($ref_add_1 ne "") { %ini_add_1 = %$ref_add_1 };
  my %cat;
  if ($cat_ref ne "") { %cat = %$cat_ref };

  open (INI, "<".unix_path($ini_file));
  @lines=<INI>;
  close INI;
  open (INI, ">".unix_path($ini_file));
  my $categ;
  foreach(@lines) {
      if (substr($_,0,1) eq "[") { # additional new keys
	  foreach my $key_cat (keys (%cat)) {
	      if ($cat{$key_cat} eq $categ) {
		  print INI $key_cat.",".$ini{$key_cat}.",".$ini_descr{$key_cat};
		  unless ($ini_add_1{$key_cat} eq "") {print INI ",".$ini_add_1{$key_cat};};
		  print INI "\n";
		  delete($ini{$key_cat}); delete ($ini_descr{$key_cat}); delete ($cat{$key_cat});
	      }
	  }
          $categ = $_;
	  $categ =~ s/\[//;
	  $categ =~ s/\]//;
      }
    if ((substr($_,0,1) eq "#")||(substr($_,0,1) eq "[")) {print INI $_;} else {
        ($key,$value) = split (/,/,$_);
         unless (($ini{$key} eq "")||($key eq "")) {
            $ini_descr{$key} =~ s/\n/\\n/g ;
            #$ini{$key} =~ s/\n/\\\n/g ;
            print INI $key.",".$ini{$key}.",".$ini_descr{$key};
            unless ($ini_add_1{$key} eq "") {print INI ",".$ini_add_1{$key};};
            print INI "\n";
         }
	delete($ini{$key}); delete ($ini_descr{$key}); delete ($cat{$key});
      }
    }
  # just to make sure... if there are remaining keys, put them at the bottom
  foreach(keys(%ini)) {  # new entries
    unless ($_ eq "") {
      print INI $_.",".$ini{$_}.",".$ini_descr{$_};
      unless ($ini_add_1{$_} eq "") {print INI ",".$ini_add_1{$_};};
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
  #print keys(%$descr_ref);
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
  $edit_ini_w -> resizable( 0, 0 );
  center_window($edit_ini_w);
  my $edit_ini_frame = $edit_ini_w -> Frame(-background=>$bgcol)->grid(-ipadx=>'10',-ipady=>'10',-sticky=>'n');
  # $edit_ini_frame -> Label (-text=>"Piraña settings: ")->grid(-column=>1, -row=>1);
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
       if ($software==1) {
         if ((-d @ini_value[$i])||(-e @ini_value[$i])) {$entry_color=$lightgreen} else {$entry_color=$lightred};
       };
       @edit_ini_entry[$i] = $edit_ini_frame -> Entry (-textvariable=>\@ini_value[$i],-border=>2, -relief=>'groove',-background=>$entry_color,-width=>$length)
         ->grid(-column=>$col+1,-row=>$row,-sticky=>"w");
       $help -> attach(@edit_ini_entry[$i], -msg => $ini_descr{$_});
       $row++;
       $i++;
       if($row==int(((@keys+@sections)/2)-0.1)+3) {$row=2; $col=$col+3};
  }
  $edit_ini_frame -> Label (-text=>"  ", -background=>$bgcol)->grid(-column=>1, -row=>int((@keys+@sections)/2)+3,-columnspan=>1,-sticky=>"e");
  $edit_ini_frame -> Button (-text=>'Save', -width=>12, -background=>$button, -activebackground=>$abutton, -border=>$bbw, -command=>sub{
    $i=0;
    foreach(@keys) {  # update %settings
      $ini{$_} = @ini_value[$i];
      $i++;
    }
    save_ini ($home_dir."/ini/".$ini_file, \%ini, \%ini_descr);
    chdir($base_dir);
    my $software_ini = "software_linux.ini";
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
  $edit_ini_frame -> Button (-text=>"Cancel", -width=>12, -background=>$button, -border=>$bbw, -activebackground=>$abutton, -command=> sub{
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
          $sizes_frame -> Label (-text=>@sizes_key[$i], -background=>$bgcol)->grid(-column=>$col,-row=>$row,-sticky=>"e",-ipadx=>'8');
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
  $install_nm_nmq_w -> resizable( 0, 0 );
  center_window($install_nm_nmq_w);
  $install_nm_nmq_frame = $install_nm_nmq_w -> Frame(-background=>$bgcol)->grid(-ipadx=>'10',-ipady=>'10',-sticky=>'n');
  $install_text = "This will perform a new installation of NONMEM VI using\n".
    "predefined NMQual XML files. Please refer to the documentation\n of NMQual for further information on this subject.\n\n".
    "The location of the NMQual XML files can be specified under 'File --> Software'.\nOnly XML-files prefixed with 'config.' are shown in the optionmenu.\n".
    "Since Perl is needed for NMQual, it is assumed that it's location is in the PATH.\n\n";
  $install_nm_nmq_frame -> Label (-text=>$install_text,-justify=>"left")
    ->grid(-row=>1,-column=>1, -columnspan=>3,-sticky=>"w");
  $install_nm_nmq_frame -> Label (-text=>"Name in Piraña:",-justify=>"left")
    ->grid(-row=>2,-column=>1, -columnspan=>1,-sticky=>"w");
  $install_nm_nmq_frame -> Label (-text=>"Installation",-justify=>"left")
    ->grid(-row=>3,-column=>1, -columnspan=>1,-sticky=>"w");
  $install_nm_nmq_frame -> Entry (-textvariable=>\$nm_name,  -background=>$white, -border=>$bbw, -width=>16, -border=>2, -relief=>'groove')
    -> grid(-row=>2,-column=>2,-columnspan=>2,-sticky=>"news");

  $install_nm_nmq_frame -> Label (-text=>"Installation directory:",-justify=>"left")
    ->grid(-row=>4,-column=>1, -columnspan=>1,-sticky=>"w");
  $nmq_to = $install_nm_nmq_frame -> Entry (-state=>'disabled',  -background=>$white, -border=>$bbw, -width=>16, -border=>2, -relief=>'groove')
    -> grid(-row=>4,-column=>2,-columnspan=>2,-sticky=>"news");
  $install_nm_nmq_frame -> Label (-text=>"NONMEM version:",-justify=>"left")
    ->grid(-row=>5,-column=>1, -columnspan=>1,-sticky=>"w");
  $nmq_nmver = $install_nm_nmq_frame -> Entry (-state=>'disabled', -background=>$white, -border=>$bbw, -width=>16, -border=>2, -relief=>'groove')
    -> grid(-row=>5,-column=>2,-columnspan=>2,-sticky=>"news");
  chdir ($software{nmq_path});
  @xml = <config.*.xml>;
  ($target, $version) = nmqual_xml(win_path($software{nmq_path}."/".@xml[0]));
  $nmq_to -> configure(-textvariable=>$target);
  $nmq_nmver -> configure(-textvariable=>$version);
  $install_nm_nmq_frame -> Optionmenu (-options=>[@xml], -variable=> \$nmq_xml, -border=>$bbw, -width=>5, -font=>$font_normal, -background=>$lightblue, -activebackground=>$darkblue, -command=> sub{
    ($target, $version) = nmqual_xml(win_path($software{nmq_path}."/".$nmq_xml));
    $nmq_to -> configure(-textvariable=>$target);
    $nmq_nmver -> configure(-textvariable=>$version);
  }) -> grid(-row=>3,-column=>2,-columnspan=>2,-sticky=>"we");
  $install_nm_nmq_frame -> Button (-image=>$gif{notepad}, -background=>$button, -border=>$bbw, -activebackground=>$abutton, -command=> sub {
        edit_model(unix_path($nmq_xml));
  })->grid(-row=>3,-column=>4,-sticky=>"w");
  $install_nm_nmq_frame -> Label (-text=>" ",-justify=>"left")
    ->grid(-row=>6,-column=>1, -columnspan=>3,-sticky=>"w");
  $install_nm_nmq_frame -> Button (-text=>"Proceed", -width=>12, -background=>$button, -border=>$bbw, -activebackground=>$abutton, -command=> sub {
    if ($nm_dirs{$nm_name}) {message("A NONMEM installation with that name already exists in Piraña.\nPlease choose another name.")} else {
       open (BAT,">".unix_path($base_dir."/internal/nmq_install_nm.bat"));
       print BAT "SET PATH=".$setting{nmq_env_path}.";%PATH%; \n";
       print BAT "SET LIBRARY_PATH=".$setting{nmq_env_libpath}.";%LIBRARY_PATH% \n";
       print BAT win_path("perl.exe nmqual.pl ".$nmq_xml)."\n";
       close BAT;

       system("start /wait ".win_path($base_dir."/internal/nmq_install_nm.bat"));
       # check if the perl file in the /test directory exists
       $perl_file = get_nmq_name ($target);
       print $target."/test/".$perl_file.".pl";
       if (-e $target."/test/".$perl_file.".pl") {
	   my $add_to_pirana = message_yesno ("NONMEM installations seems valid.\n Do you want to add this installation to Piraña?", $mw, $bgcol, $font_normal);
           if ($add_to_pirana == 1) {
	       $nm_dirs{$nm_name} = $target;
	       $nm_vers{$nm_name} = $version;
	       save_ini ($home_dir."/ini/nm_inst_local.ini", \%nm_dirs, \%nm_vers);
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
  $install_nm_nmq_frame -> Button (-text=>"Cancel", -width=>12, -background=>$button, -border=>$bbw, -activebackground=>$abutton, -command=> sub {
    $install_nm_nmq_w -> destroy;
  })->grid(-row=>7,-column=>1,-sticky=>"e");
}

sub install_nonmem_window {
### Purpose : Create dialog for installing NONMEM
### Compat  : W+
  $install_nm_w = $mw -> Toplevel(-title=>'Install NONMEM VI');
  $install_nm_w -> resizable( 0, 0 );
  center_window($install_nm_w);
  my $install_nm_frame = $install_nm_w -> Frame(-background=>$bgcol)->grid(-ipadx=>'10',-ipady=>'10',-sticky=>'n');
  $install_text = "This will perform a new installation of NONMEM VI from CD\n\n".
    "Tip: If you have the NONMEM installation files not on CD, but e.g. on your hard-drive or USB-stick,\n".
    " then you can create a virtual drive of the folder containing the installation files by executing:\n".
    "'subst X: . ' from a command line window from within that folder\n";
  $install_nm_frame -> Label (-text=>$install_text,-justify=>"left")
    ->grid(-column=>1, -columnspan=>2,-sticky=>"w");
  $install_nm_frame -> Label (-text=>"Installation name (for in Piraña)")->grid(-column=>1, -row=>2,-sticky=>"e");
  $install_nm_frame -> Label (-text=>"NONMEM Install CD")->grid(-column=>1, -row=>3,-sticky=>"e");
  $install_nm_frame -> Label (-text=>"Install to")->grid(-column=>1, -row=>4,-sticky=>"e");
  $install_nm_frame -> Label (-text=>"Default compiler optimization")->grid(-column=>1, -row=>5,-sticky=>"e");

  $nm_install_name = "nmvi";
  $install_nm_frame -> Entry (-textvariable=>\$nm_install_name, -background=>$white, -border=>$bbw, -width=>12, -border=>2, -relief=>'groove') -> grid(-row=>2,-column=>2,-sticky=>"nws");
  @drives = Win32::DriveInfo::DrivesInUse();
  foreach (@drives) {$_ .= ":"};
  $install_nm_frame -> Optionmenu (-options=>[@drives], -variable=> \$nm_install_drive, -border=>$bbw, -width=>5, -font=>$font_normal, -background=>$lightblue, -activebackground=>$darkblue)
    -> grid(-row=>3,-column=>2,-sticky=>"w");
  $nm_install_to = "c:\\".$nm_install_name;
  $install_nm_to_entry = $install_nm_frame -> Entry (-textvariable=>\$nm_install_to, -background=>$white, -border=>$bbw, -width=>36, -border=>2, -relief=>'groove') -> grid(-row=>4,-column=>2,-sticky=>"news");
  $def_optimize = 1;
  $install_nm_frame -> Checkbutton(-text=>"",-variable=>\$def_optimize,-selectcolor=>$selectcol, -activebackground=>$bgcol,)
    ->grid(-row=>5,-column=>2,-sticky=>'w');
  $do_bugfixes = 1;

  $install_nm_frame -> Label (-text=>"  ")->grid(-column=>1, -row=>8,-columnspan=>2,-sticky=>"e");

  $install_nm_frame -> Button(-image=>$gif{browse_small}, -border=>0, -command=> sub{
      $nm_install_to = $mw-> chooseDirectory();
      if($cwd eq "") {$install_nm_to_entry ->configure(-textvariable=>\$nm_install_to) };
      $install_nm_w -> focus;
  })
  ->grid(-column=>3, -row=>4, -sticky => 'we');

  $install_nm_frame -> Button (-text=>"Proceed", -width=>12, -background=>$button, -border=>$bbw, -activebackground=>$abutton, -command=> sub {
         if (-d $nm_install_to) {message ("Target folder already exists.\nPlease choose another destination.")} else {
        ($nm_to_drive,$nm_to_dir) = split (/:/,$nm_install_to);
        $nm_to_drive =~ s/://;
        $nm_install_drive =~ s/://;
        $nm_to_dir = substr($nm_to_dir,1,length($nm_to_dir)-1);
        if ($def_optimize==1) {$def_optimize="y"} else {$def_optimize="n"};
        # print "cdsetup6.bat ".$nm_install_drive." ".$nm_to_drive." ".$nm_to_dir." ".$setting{compiler}." ".$def_optimize." link";
        chdir($nm_install_drive.":\\");
        system "start /wait cdsetup6.bat ".$nm_install_drive." ".$nm_to_drive." ".$nm_to_dir." ".$setting{compiler}." ".$def_optimize." link";
        if (-e unix_path($nm_install_to."/util/nmfe6.bat")) {
           my $add_to_pirana = message_yesno ("NONMEM installation seems successful.\nDo you want to add this installation to Piraña?", $mw, $bgcol, $font_normal);
           if( $add_to_pirana == 1) {
              $nm_dirs{$nm_install_name} = $nm_install_to;
              $nm_vers{$nm_install_name} = 6;
              save_ini ($home_dir."/ini/nm_inst_local.ini", \%nm_dirs, \%nm_vers);
              chdir($cwd);
              refresh_pirana($cwd);
           }
        $method_nmfe_button -> configure(-state=>'normal');
        } else {message("Installation of NONMEM failed...")}
        $install_nm_w -> destroy;
      }
  })->grid(-row=>9,-column=>2,-sticky=>"w");
  $install_nm_frame -> Button (-text=>"Cancel", -width=>12, -background=>$button, -border=>$bbw, -activebackground=>$abutton, -command=> sub {
    $install_nm_w -> destroy;
  })->grid(-row=>9,-column=>1,-sticky=>"e");
}

sub manage_nm_window {
### Purpose : Create the dialog for editing the NM sizes file
### Compat  : W+L+
  $sizes_w = $mw -> Toplevel(-title=>'Configure NM6+ installations');
  $sizes_w -> resizable( 0, 0 );
  center_window($sizes_w);

  my $nm_manage_frame = $sizes_w -> Frame(-background=>$bgcol)->grid(-ipadx=>'10',-ipady=>'10',-sticky=>'n');
  $nm_manage_frame -> Label (-text=>"NONMEM Installation: ", -background=>$bgcol)->grid(-column=>1, -row=>1,-sticky=>"nws");
  $nm_manage_frame -> Label (-text=>"Location: ", -background=>$bgcol)->grid(-column=>1, -row=>2,-sticky=>"nws");
  $nm_manage_frame -> Label (-text=>"Version: ",-background=>$bgcol)->grid(-column=>1, -row=>3,-sticky=>"nws");
  $nm_manage_frame -> Label (-text=>"\nNote: Only SIZES files of local NM installations can be read. Versions will be read\nfrom pirana ini-files, and psn.conf (if found). Only regular (non-NMQual) installations\ncan be altered and recompiled. Hover over records to view description.",-background=>$bgcol,-font=>$font_normal,-justify=>'left')
    ->grid(-column=>1, -row=>5, -columnspan=>4, -sticky=>"nws");

  my $nm_save = $nm_manage_frame -> Button (-text=>"Save", -width=>20, -background=>$button, -border=>$bbw, -activebackground=>$abutton, -command=> sub {
    save_sizes($nm_chosen, \@sizes_key, \@sizes_value);
    $sizes_w->destroy;
    message("SIZES saved.\nFor settings to take effect,\nyou have to re-compile NONMEM.");
  })->grid(-row=>10,-column=>2);
  my $nm_save_recompile = $nm_manage_frame -> Button (-text=>"Save and recompile NM", -width=>20, -background=>$button, -border=>$bbw, -activebackground=>$abutton, -command=> sub{
    save_sizes($nm_chosen, \@sizes_key, \@sizes_value);
    chdir ($nm_dirs{$nm_chosen});
    rmtree(["NM","PR","TL","TR"]);
    @nm_loc = split(/:/,$nm_dirs{$nm_chosen});
    my $compile_command = "cdsetup6 ".@nm_loc[0]." ".@nm_loc[0]." ".substr(@nm_loc[1],1,length(@nm_loc[1]))." ".$setting{compiler}." y link";
    $compile_nm = $mw -> Toplevel(-title=>'Delete project');
    $compile_nm -> resizable( 0, 0 );
    center_window($compile_nm);
    $compile_nm_frame = $compile_nm -> Frame (-background=>$bgcol)->grid(-ipadx=>10,-ipady=>10);
    $compile_nm_frame -> Label (-text=>"folders NM, PR, TL and TR in ".$nm_dirs{$nm_chosen}." will be deleted!", -background=>$bgcol) -> grid(-row=>1,-column=>1,-columnspan=>2,-sticky=>"w");
    $compile_nm_frame -> Label (-text=>"Recompile command: \n",-background=>$bgcol,-justify=>'left') -> grid(-row=>2,-column=>1);
    $compile_nm_frame -> Entry (-textvariable=>\$compile_command, -background=>$white, -border=>$bbw, -width=>32, -border=>2, -relief=>'groove') -> grid(-row=>2,-column=>2,-sticky=>"wn");
    $compile_nm_frame -> Button (-text=>'Proceed', -background=>$button, -activebackground=>$abutton, -border=>0, -command=>sub{
      system "start ".$compile_command;
      $compile_nm -> destroy;
      $sizes_w -> destroy;
      message("SIZES saved.\nRecompile started in separate window.");
    })->grid(-row=>4,-column=>2,-sticky=>"nw",-ipadx=>10);
    $compile_nm_frame-> Button (-text=>'Cancel', -background=>$button, -activebackground=>$abutton, -border=>0, -command=>sub{
      $compile_nm -> destroy;
    })->grid(-column=>2,-row=>4,-sticky=>"e",-ipadx=>10);
  }) -> grid(-row=>10,-column=>3);
  $nm_manage_frame -> Button (-text=>"Cancel", -width=>20, -background=>$button, -border=>$bbw, -activebackground=>$abutton, -command=> sub{
     $sizes_w->destroy;
  })-> grid(-row=>10,-column=>1);

  my $nm_dir_entry = $nm_manage_frame -> Entry (-textvariable=>\$nm_dirs{$nm_chosen}, -background=>$white,-border=>$bbw,-width=>30,-state=>"disabled", -border=>2, -relief=>'groove')
         ->grid(-column=>2,-row=>2,-sticky=>"we");
  my $nm_ver_entry = $nm_manage_frame -> Entry (-textvariable=>\$nm_vers{$nm_chosen}, -background=>$white,-border=>$bbw,-width=>2,-state=>"disabled", -border=>2, -relief=>'groove')
         ->grid(-column=>2,-row=>3,-sticky=>"w");

  my $nm_chosen;
  my $button_frame = $nm_manage_frame -> Frame (-background=>$bgcol)->grid(-row=>1, -column=>3,-sticky=>"wns");
  $del_nm_button = $button_frame -> Button (-image=>$gif{trash}, -border=>$bbw, -background=>$button, -activebackground=>$abutton, -width=>22, -command=> sub{
      my $delete = message_yesno ("Do you really want to delete this NONMEM installation?\nNB. The actual installation will not be removed, only the link from Piraña.", $mw, $bgcol, $font_normal);
      if( $delete == 1) {
	  delete $nm_dirs{$nm_chosen};
	  delete $nm_vers{$nm_chosen};
	  delete $nm_types{$nm_chosen};
	  print keys(%nm_dirs);
	  foreach (keys(%nm_dirs)) {
	      if (($_ =~ m/PsN:/)||($_ eq "")||($_ =~ m/Retrieving/i)) {
		  delete $nm_dirs{$_};
		  delete $nm_vers{$_};
		  delete $nm_types{$_};
	      }
	  }
	  if ($nm_chosen =~ m/Remote:/g) {
	      save_ini ($home_dir."/ini/nm_inst_cluster.ini", \%nm_dirs, \%nm_vers);
	  } else {
	      save_ini ($home_dir."/ini/nm_inst_local.ini", \%nm_dirs, \%nm_vers);
	  }
	  my ($nm_dirs_ref,$nm_vers_ref) = read_ini($home_dir."/ini/nm_inst_local.ini");
	  my ($nm_dirs_cluster_ref,$nm_vers_clusters_ref) = read_ini($home_dir."/ini/nm_inst_local.ini");
	  our %nm_dirs = %$nm_dirs_ref;
	  our %nm_vers = %$nm_vers_ref;
	  our %nm_dirs_cluster = %$nm_dirs_cluster_ref;
	  our %nm_vers_cluster = %$nm_vers_cluster_ref;
	  chdir($cwd);
	  refresh_pirana($cwd);
	  $sizes_w -> destroy;
      }
  })-> grid(-row=>1,-column=>1,-sticky=>"wns");
  $help->attach($del_nm_button, -msg => "Remove NM installation");

  $new_nm_button = $button_frame -> Button (-image=>$gif{plus}, -border=>$bbw, -background=>$button, -activebackground=>$abutton, -command=> sub{
     foreach (keys(%nm_dirs)) {
	 if (($_ =~ m/PsN:/)||($_ =~ m/Retrieving/)) {
	     delete $nm_dirs{$_};
	     delete $nm_vers{$_};
	     delete $nm_types{$_};
	 }
     }
     add_nm_inst();
  })-> grid(-row=>1,-column=>2,-sticky=>"wns");
  $help->attach($new_nm_button, -msg => "Add new NM installation");

  my $nm_optionmenu = $nm_manage_frame -> Optionmenu (-options => ["Retrieving NM installations. Please wait..."], -border=>$bbw,
        -variable => \$nm_chosen, -width=>25, -background=>$lightblue,-activebackground=>$darkblue,-font=>$font_normal,
        -command=>sub{
	    refresh_sizes( $nm_types{$nm_chosen},$nm_vers{$nm_chosen},$nm_dirs{$nm_chosen}, $nm_chosen, $nm_manage_frame);
	    if ($nm_chosen =~ m/PsN/) {$del_nm_button -> configure (-state=>'disabled')} else {$del_nm_button -> configure (-state=>'normal')};
	    if ($nm_type_chosen =~ m/nmq/i) { $nm_save_recompile->configure(-state=>"disabled")} else { $nm_save_recompile -> configure(-state=>"normal") };
	    if ($nm_type_chosen =~ m/nmq/i) { $nm_save->configure(-state=>"disabled")} else { $nm_save -> configure(-state=>"normal") };
	    $nm_dir_entry -> configure(-textvariable=>\$nm_dirs{$nm_chosen});
	    $nm_ver_entry -> configure(-textvariable=>\$nm_vers{$nm_chosen});
    })->grid(-row=>1,-column=>2, -sticky => 'wens');

  # get NM installations and fill in Optionmenu
  my @nm6_installations = ();
  my ($nm_dirs_ref, $nm_vers_ref) = read_ini($home_dir."/ini/nm_inst_local.ini");
  my %nm_dirs = %$nm_dirs_ref; my %nm_vers = %$nm_vers_ref; my %nm_types;

  # Add remote NM versions
  my ($nm_dirs_remote_ref, $nm_vers_remote_ref) = read_ini($home_dir."/ini/nm_inst_cluster.ini");
  my %nm_dirs_remote = %$nm_dirs_remote_ref; my %nm_vers_remote = %$nm_vers_remote_ref;
  $nm_manage_frame -> update();

  # add Perl NM-versions
  my ($psn_nm_versions_ref, $psn_nm_versions_vers_ref) = get_psn_nm_versions(\%setting, \%software);
  my %psn_nm_versions = %$psn_nm_versions_ref;
  my %psn_nm_versions_vers = %$psn_nm_versions_vers_ref;

  foreach(keys(%psn_nm_versions)) {
    $nm_types{"PsN: ".$_} = "PsN";
    $nm_dirs{"PsN: ".$_} = $psn_nm_versions{$_};
    $nm_vers{"PsN: ".$_} = $psn_nm_versions_vers{$_};
  }
  foreach(keys(%nm_dirs_remote)) {
    $nm_types{"Remote: ".$_} = "SSH";
    $nm_dirs{"Remote: ".$_} = $nm_dirs_remote{$_};
    $nm_vers{"Remote: ".$_} = $nm_vers_remote{$_};
  }
  my @nm6_installations;
  foreach(keys(%nm_vers)) {   # filter out only NM6 installations
    #if (($nm_vers{$_} =~ m/6/)||($nm_vers{$_} =~ m/7/)&&($nm_type{_})) {
      push (@nm6_installations, $_)
    #};
  };
  my @nm6_installations = sort (@nm6_installations);
  $nm_optionmenu -> configure(-options => [@nm6_installations]);

}

sub csv_tab_window {
### Purpose : Create the dialog for converting a csv-file into a tab file or viceversa
### Compat  : W+L?
   my $file = shift;
   $new_file = $file;
   if ($file =~ m/.$setting{ext_csv}/i) {$new_file=~ s/.$setting{ext_csv}/.$setting{ext_tab}/i};
   if ($file =~ m/.$setting{ext_tab}/i) {$new_file=~ s/.$setting{ext_tab}/.$setting{ext_csv}/i};
   $csv_tab_w = $mw -> Toplevel(-title=>'Convert datafile');
   $csv_tab_w -> resizable( 0, 0 );
   center_window($csv_tab_w);
   $csv_tab_frame = $csv_tab_w -> Frame(-background=>$bgcol)->grid(-ipadx=>'20',-ipady=>'10',-sticky=>'nws');
   $csv_tab_frame -> Label(-text=> "Convert file: ",-justify=>"left")->grid(-column=>1, -row=>1,-sticky=>"wns");
   $csv_tab_frame -> Label(-text=> $file,-justify=>"left")->grid(-column=>2, -row=>1,-sticky=>"wns");
   $csv_tab_frame -> Label(-text=> "to: ",-justify=>"left")->grid(-column=>1, -row=>2,-sticky=>"wns");
   my $length = length($file); if($length<32) {$length=32};
   $csv_tab_frame -> Entry(-textvariable=> \$new_file,  -background=>$white,
      -border=>1, -relief=>'groove', -width=>$length)->grid(-column=>2, -row=>2,-sticky=>"wns");
   $csv_tab_frame -> Button(-text=> "Convert", -background=>$button, -border=>$bbw, -activebackground=>$abutton, -command=> sub {
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
    unless (-d $home_dir."/log") {mkdir $home_dir."/log"};
    my @dir = dir ($base_dir."/ini_defaults", ".ini");

    # check if all settings are in place
    @check_inis = ("settings.ini", "software_win.ini", "software_linux.ini", "psn.ini");

    foreach my $ini (@dir) {
	if (-e $home_dir."/ini/".$ini) {
	    check_ini_file ($home_dir."/ini/".$ini, $base_dir."/ini_defaults/".$ini)
	} else {
	    copy ($base_dir."/ini_defaults/".$ini, $home_dir."/ini/".$ini);
	}
    }
};

sub check_ini_file {
### Purpose : check the ini-files at startup and rewrite if incomplete
### Compat  : W+L+
    my ($user_ini_file, $def_ini_file) = @_;
    my ($user_ini_ref, $user_ini_descr_ref, $drop,$user_cat_ref) = read_ini($user_ini_file); #user ini file
    my ($def_ini_ref, $def_ini_descr_ref, $drop,$def_cat_ref) = read_ini($def_ini_file); # default ini file

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
    save_ini ($user_ini_file, \%user_ini, \%user_ini_descr, " ", \%user_cat);
}

sub renew_pirana {
### Purpose : To reload the main part of the GUI
### Compat  : W+L+
    if($frame2) {$frame2->gridForget()};
    if($run_frame) {$run_frame -> gridForget()};
    if ($frame_links) {$frame_links -> gridForget()};
    if ($frame_status) {$frame_status -> gridForget()};
    frame_models_show(1);
    frame_tab_show(1);
    show_run_frame();
    frame_statusbar(1);
    project_buttons_show();
    our $project_optionmenu = project_optionmenu ();
    refresh_pirana ($cwd, $filter, 1);
    $project_optionmenu -> configure(-state=>'normal');
    status();
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
  if ($frame_links) {$frame_links -> destroy()};
  show_links ();
  read_curr_dir (@_[0], $filter, 1);
  status ("Reading table files...");
  tab_dir(@_[0]);
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
    my $console = text_window($text, "Script / command output");
    return($console);
}

sub message {
### Purpose : Show a small window with a text and an OK button
### Compat  : W+L+
    my $text = shift;
    my $message_box = $mw -> Toplevel (-title => "Pirana message", -background=> $bgcol);
    center_window($message_box);
    my $message_frame = $message_box -> Frame (-background=>$bgcol) -> grid(-ipadx => 10, -ipady => 10);
    $message_frame -> Label (-text=> $text."\n", -font=>$font_normal, -background=>$bgcol) -> grid(-row=>1, -column=>1);
    $message_frame -> Button (-text=>"OK", -font=>$font_normal, -border=>$bbw, -background=>$button, -activebackground=>$abutton, -width=>5, -command => sub{
	$message_box -> destroy();
	return(1);
    }) -> grid(-row=>2, -column=>1);
    $message_box -> focus ();
 # $mw -> messageBox(-type=>'ok', -message=>@_[0]);
}

sub intro_msg {
### Purpose : Issue a message-window showing startup errors
### Compat  : W+L+
  $kill = shift;
  if ($kill == 1) {$kill_text = "\nClick OK to exit Piraña.\n"} else {$kill_text=""};
  our $mw2 = MainWindow -> new (-title => "Piraña",-width=>740, -height=>410);
  open (LOG, "<".$home_dir."/log/startup.log");
  @lines=<LOG>;
  close LOG;
  $all = join("",@lines);
  $mw2 -> messageBox(-type=>'ok',
    	-message=>"Errors were found when starting Piraña.\n Startup log:\n\n**************\n".$all."**************\n".$kill_text);
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
    return (\%setting, \%descr, \%add_1, \%setting_cat);
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
	    print OUT "# Changed by Piraña to allow compiling of nonmem.exe, without executing NONMEM\n";
	    $line_done=1;
	};
	if ($line =~ m/my \$outfile/i) {
	    print OUT $line;
	    print OUT '$outfile .= "_tmp1";'." # Added by Piraña \n";
	    $line_done=1;
	}
	if ($line =~ m/\#restore invoking directory/) {
	    print OUT 'close OUTFILE or die;                                                   # added by Pirana'."\n";
	    print OUT '$outfile =~ s/tmp1/tmp2/;                                               # added by Piraña'."\n";
	    print OUT 'open (OUTFILE,">".$outfile) or die "$nm cant open ".$outfile."_tmp\n";  # added by Piraña'."\n";
	    print OUT "\n".$line;
	    $line_done=1;
	}
	if ($line =~ m/\#execute nonmem/gi ) {
	    $comment_lines = 18;
	}
	if ($line =~ m/open \(INFILE, "\<OUTPUT"\) or \&dieSmart/) {
	    $comment_lines = 5;
	};
	if ($comment_lines>0) { $comment_lines--; print OUT "# Piraña change # ".$line } else {
	    if ($line_done==0) {print OUT $line }
	}
    }
    close OUT;
}

sub first_time_dialog {
### Purpose : Present a dialog the first time Pirana is started
### Compat  : W+L+
  my $user = shift;
  my $first_time_dialog_window = $mw -> Toplevel(-title=>'Welcome to Piraña!');
  my $first_time_dialog_frame = $first_time_dialog_window -> Frame(-background=>$bgcol) -> grid(-ipadx=>10, -ipady=>10);
  $first_time_dialog_frame -> Label (-font=>$font_normal, -background=>$bgcol, -justify=>"left",
    -text=> "Welcome to Piraña!\n\nSince this is the first time you start Piraña, please check the preferences and software\nsettings under 'File' in the menu.\n\nNONMEM installations may be added under 'NONMEM' -> 'Manage Installations'\n\n"
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
    save_ini ($home_dir."/ini/settings.ini", \%setting, \%setting_descr);
    $first_time_dialog_window -> destroy();
  })->grid(-row=>4, -column=>2, -sticky=>"wns");
  center_window($first_time_dialog_window);
}

sub initialize {
### Purpose : Initialize pirana: read ini-files and update settings-hashes
### Compat  : W+L?

    # check if it's the first time to start pirana
    my $user    = getlogin();
    my $first_time_flag = 0;
    unless (-e $home_dir."/log/startup.log") {
	$first_time_flag = 1;
    }
    setup_ini_dir ($user, $home_dir);

    open (LOG,">".$home_dir."/log/startup.log");
    my $error=0;
    print LOG "Piraña ".$version."\n";
    print LOG "Startup time: ".localtime()."\n\n";
    print LOG "Checking pirana installation...\n";

    our ($setting_ref,$setting_descr_ref) = read_ini($home_dir."/ini/settings.ini");
    our %setting = %$setting_ref; %setting_descr = %$setting_descr_ref;

    unless (-d $base_dir."/internal") {$error++; print LOG "Error: Pirana could not find dir containing internal subroutines. Program halted.\n"};
    unless (-d $base_dir."/images") {$error++; print LOG "Error: Pirana could not find images. Program halted.\n"; };
    if ($error>0) {print LOG "Errors were found. Check installation of pirana.\n"; close LOG; intro_msg(1)} else {print LOG "Done\n"};

    print LOG "Reading Pirana settings...\n";
    ($setting_ref,$setting_descr_ref) = read_ini($home_dir."/ini/settings.ini");
    %setting = %$setting_ref; %setting_descr = %$setting_descr_ref;
    #if ($setting{username}) {print LOG "Done\n";} else {print LOG "Error. Settings file might be corrupted. Check ini/settings.ini\n"; close LOG; intro_msg( )};
    our $models_view = $setting{models_view};

    our $font_normal = 'Verdana 7';
    our $font_small = 'Verdana 6';
    our $font_fixed = "Courier 8";
    our $font_bold = 'Verdana 8 bold';

    if ($setting{font_size}==2) {
	our $font_normal = 'Verdana 8';
	our $font_small = 'Verdana 7';
	our $font_fixed = "Courier 9";
	our $font_fixed2 = "LucidaSansUnicode 10";
	our $font_bold = 'Verdana 8 bold';
    }
    if ($setting{font_size}==3) {
	our $font_normal = 'Verdana 10';
	our $font_small = 'Verdana 8';
	our $font_fixed = "Courier 12";
	our $font_fixed2 = "Courier 12";
	our $font_bold = 'Verdana 11 bold';
    }

    print LOG "Deleting temporary files...\n";
    if(chdir ($base_dir."/temp")){
	my @temp_files = <*>;
	unlink (@temp_files);
	chdir ($base_dir);
    }

    print LOG "Reading software settings...\n";
    my $software_ini = "software_linux.ini";
    if ($os =~ m/MSWin/i) {$software_ini = "software_win.ini";}
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
	    save_ini ($home_dir."/ini/software_win.ini", \%software, \%software_descr);
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
	unless (-d $value) {$pr_dir_err++; print LOG "Error: folder for project ".$value." not found!\n"};
    }
    unless ($pr_dir_err==0) {print LOG $pr_dir_err." project(s) not found. Check projects.ini!\n"; close LOG;
			     # intro_msg(0)
    };

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
    ($nm_dirs_cluster_ref,$nm_vers_cluster_ref,$nm_types_cluster_ref) = read_ini($home_dir."/ini/nm_inst_cluster.ini");
    our %nm_dirs_cluster = %$nm_dirs_cluster_ref;
    our %nm_vers_cluster = %$nm_vers_cluster_ref;

    # Read NM help files
    my @dirs = values (%nm_dirs);
    my $nm_help_ref = get_nm_help_keywords (@dirs[0]."/html");
    our @nm_help_keywords = @$nm_help_ref;

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
	$cluster_view -> resizable( 0, 0 );
	center_window($cluster_view);
	our $cluster_view_frame = $cluster_view -> Frame(-background=>$bgcol)->grid(-ipadx=>5,-ipady=>5);
	our $cluster_monitor_grid = $cluster_view_frame ->Scrolled('HList',
								   -head       => 1, -columns    => 5, -scrollbars => 'e',-highlightthickness => 0,
								   -width      => 32, -height => 16, -border => 1, -background => 'white',
	    )->grid(-column => 1, -columnspan=>2,-row => 1);
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
  $save_dialog -> resizable( 0, 0 );
  center_window($save_dialog);
  $save_proj_frame = $save_dialog -> Frame(-background=>$bgcol) -> grid(-ipadx=>10, -ipady=>10);

  $save_proj_frame->Label(-text=>"folder:" ,-background=>$bgcol)->grid(-row=>1,-column=>1,-columnspan=>2,-sticky=>'w');
  $save_proj_frame->Label(-text=>@_[0],-background=>$bgcol)->grid(-row=>1,-column=>2,-columnspan=>2,-sticky=>'w');
  $save_proj_frame->Label(-text=>"Overwrite project: ",-background=>$bgcol,-activebackground=>$bgcol)->grid(-row=>2,-column=>1,-sticky=>'w');
  $new_project_name = "New project";
  my $proj_entry = $save_proj_frame->Entry(-width=>30, -background=>$white, -textvariable=>\$new_project_name,-background=>'#FFFFEE', -border=>2, -relief=>'groove') ->grid(-row=>3,-column=>2,-sticky=>'w');
  $save_proj_frame->Optionmenu(-background=>$lightblue,-activebackground=>$darkblue, -width=>25,-border=>$bbw,
        -options=>["New project",keys(%project_dir)], -font=>$font_normal, -textvariable => \$project_chosen,
        -command=>sub{
          $new_project_name = $project_chosen;
          $proj_entry -> update();
        ;} )
    ->grid(-row=>2,-column=>2,-sticky=>'w');
  $save_proj_frame->Label(-text=>"Project name: ",-background=>$bgcol) ->grid(-row=>3,-column=>1,-sticky=>'w');
  $save_proj_frame->Label(-text=>"  ",-background=>$bgcol)->grid(-row=>4,-column=>1,-columnspan=>2,-sticky=>'w');
  $save_proj_frame->Button(-text=>"Save",-width=>16,-background=>$button,-activebackground=>$abutton,-border=>$bbw, -command=>sub{
     # rewrite the hash:
     unless ($project_chosen eq "New project") {
       delete $project_dir{$project_chosen};
     }
     $project_dir{$new_project_name} = $cwd;
     rewrite_projects_ini();
     $active_project = $new_project_name;
     project_optionmenu();
     $project_optionmenu -> configure(-state=>"normal");
     destroy $save_dialog;
  })
   ->grid(-row=>5,-column=>2,-sticky=>'w');
 $save_proj_frame -> Button (-text=>'Cancel ', -background=>$button, -activebackground=>$abutton, -border=>0, -command=>sub{destroy $save_dialog})->grid(-column=>1,-row=>5,-sticky=>"nwse");
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
  $delproj_dialog -> resizable( 0, 0 );
  $delproj_frame -> Label (-text=>"Really delete project $active_project?\n (folder will not be deleted, only shortcut in Piraña.)\n",-justify=>'left')->grid(-row=>1,-column=>1,-columnspan=>2);
  $delproj_frame -> Button (-text=>'Delete ', -background=>$button, -activebackground=>$abutton, -border=>0, -command=>sub{
    delete $project_dir{$active_project};
    rewrite_projects_ini();
    ($active_project,@rest) = keys(%project_dir);
    project_optionmenu();
    $project_optionmenu -> configure(-state=>"normal");
    refresh_pirana($cwd,$filter,1);
    destroy $delproj_dialog;
  })->grid(-row=>2,-column=>2,-sticky=>"nwse");
  $delproj_frame -> Button (-text=>'Cancel ', -background=>$button, -activebackground=>$abutton, -border=>0, -command=>sub{destroy $delproj_dialog})->grid(-column=>1,-row=>2,-sticky=>"nwse");
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
    if (-d $run.".".$setting{ext_res}) { push (@lst_files, $run.".".$setting{ext_res}); };
    if (-e $run.".".$setting{ext_res}) { push (@lst_files, $run.".".$setting{ext_res}); };
    if (-e $run.".".$setting{ext_ctl}) { push (@mod_files, $run.".".$setting{ext_ctl}); };
    if ($del_tables_check==1) {
      my $mod_ref = extract_from_model ($run.".".$setting{ext_ctl}, $run, "all");
      my $tables_ref = $$mod_ref{tab_files};
      #print join(",", @tables);
      push (@tab_files, @$tables_ref);
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
  $sel_ref = shift;
  my @del_files = @ctl_show; # make copy, since @ctl_file can change during delete process!
  my @runs = @del_files[@$sel_ref];
  my $del_dialog = $mw -> Toplevel( -title=>"Delete model, results and/or tables");
  $del_dialog -> resizable( 0, 0 );
  center_window($del_dialog);
  my $del_dialog_frame = $del_dialog-> Frame(-background=>$bgcol)->grid(-ipadx=>'10',-ipady=>'10',-sticky=>'n');
  my $type = @file_type_copy[@runs];

  $del_dialog_frame -> Label (-text=>"Selected models / folders:", -background=>$bgcol) -> grid(-row=>0, -column=>1,-sticky=>"nws"); # spacer
  $del_dialog_frame -> Label (-text=>"Files / folders to delete:", -background=>$bgcol) -> grid(-row=>0, -column=>2, -columnspan=>2,-sticky=>"nws"); # spacer
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

  my $del_folders_check = 1;
  my $del_models_check = 1;
  my $del_results_check = 1;
  my $del_tables_check = 1;
# filter out folders
  my @folders;
  foreach my $num (@$sel_ref) {
    if ((@file_type_copy[$num] == 1)&&(@del_files[$num] ne "..")) {push (@folders, @del_files[$num])};
  }
  $del_dialog_frame -> Label (-text=>"", -background=>$bgcol) -> grid(-row=>3, -column=>1, -sticky=>"nse"); # spacer
  $del_dialog_frame -> Label (-text=>"Delete:", -background=>$bgcol) -> grid(-row=>4, -column=>1, -sticky=>"nse"); # spacer
  $del_dialog_frame -> Checkbutton (-variable=>\$del_models_check, -text => " Models", -selectcolor=>$selectcol, -activebackground=>$bgcol, -command=>sub{
    populate_delete_models($del_folders_check, $del_models_check, $del_results_check, $del_tables_check, \$delete_models_listbox, \$delete_files_listbox, \@runs, \@folders );
  })-> grid(-row=> 4, -column=>2, -sticky=>"nws");
  $del_dialog_frame -> Checkbutton (-variable=>\$del_results_check, -text => " Results",-selectcolor=>$selectcol, -activebackground=>$bgcol, -command=>sub{
    populate_delete_models($del_folders_check, $del_models_check, $del_results_check, $del_tables_check, \$delete_models_listbox, \$delete_files_listbox, \@runs, \@folders);
  })-> grid(-row=> 5, -column=>2, -sticky=>"nws");
  $del_dialog_frame -> Checkbutton (-variable=>\$del_tables_check, -text => " Table files", -selectcolor=>$selectcol, -activebackground=>$bgcol, -command=>sub{
    populate_delete_models($del_folders_check, $del_models_check, $del_results_check, $del_tables_check, \$delete_models_listbox, \$delete_files_listbox, \@runs, \@folders);
  })-> grid(-row=> 6, -column=>2,-sticky=>"nws");
  $del_dialog_frame -> Checkbutton (-variable=>\$del_folders_check, -text => " Folders",  -selectcolor=>$selectcol, -activebackground=>$bgcol, -command=>sub{
    populate_delete_models($del_folders_check, $del_models_check, $del_results_check, $del_tables_check, \$delete_models_listbox, \$delete_files_listbox, \@runs, \@folders );
  })-> grid(-row=> 7, -column=>2, -sticky=>"nws");

  my $files_ref = populate_delete_models($del_folders_check, $del_models_check, $del_results_check, $del_tables_check, \$delete_models_listbox, \$delete_files_listbox, \@runs, \@folders);

  $del_dialog_frame -> Label (-text=>' ', -background=>$bgcol) -> grid(-row=>8, -column=>2); # spacer
  $del_dialog_frame -> Button (-text=>'Delete ', -width=>12, -background=>$button, -activebackground=>$abutton, -border=>$bbw, -command=>sub{
     # first, delete folders
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
     status ();
     $del_dialog -> destroy();
     read_curr_dir($cwd,$filter, 1);
  })->grid(-row=>9,-column=>3,-sticky=>"nwse");
  $del_dialog_frame -> Button (-text=>'Cancel ', -width=>12, -border=>$bbw, -background=>$button, -activebackground=>$abutton, -command=>sub{
    destroy $del_dialog
  })->grid(-column=>2,-row=>9, -sticky=>"nwse");
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
  $dupl_dialog = $mw -> Toplevel(-title=>'Duplicate');
  $dupl_dialog -> resizable( 0, 0 );
  center_window($dupl_dialog);
  $dupl_dialog_frame = $dupl_dialog-> Frame(-background=>$bgcol)->grid(-ipadx=>'10',-ipady=>'10',-sticky=>'n');
  $dupl_dialog_frame -> Label (-background=>$bgcol, -text=>'New model number (without '.$setting{ext_ctl}.'):')->grid(-row=>1,-column=>1,-sticky=>"we");
  $dupl_dialog_frame -> Entry (-width=>8, -border=>2, -relief=>'groove',  -background=>$white,
     -textvariable=>\$new_ctl_name)->grid(-row=>1,-column=>2,-sticky=>"w");
  $dupl_dialog_frame -> Label (-background=>$bgcol, -text=>'Reference model:')->grid(-row=>2,-column=>1,-sticky=>"e");
  my $ref_mod_entry = $dupl_dialog_frame -> Entry (-width=>8, -border=>2, -relief=>'groove', -text=>@ctl_show[@runs[0]],  -background=>$white,
     -textvariable=>\$new_ctl_ref)->grid(-row=>2,-column=>2,-sticky=>"w");

  my $modelfile = @ctl_show[@runs[0]].".".$setting{ext_ctl};
  my $modelno = $modelfile;
  my $modelno =~ s/\.$setting{ext_ctl}//;
  my $mod_ref = extract_from_model ($modelfile, $modelno);
  my %mod = %$mod_ref;
  $new_ctl_descr = $mod{description};

  $dupl_dialog_frame -> Label (-background=>$bgcol, -text=>'Model description:')->grid(-row=>3,-column=>1,-sticky=>"we");
  $dupl_dialog_frame -> Label (-background=>$bgcol, -justify=>"left", -text=>"\nAutomatically changing of table files only works if in the table name the exact filename of\nthe model is incorporated. E.g. if your model file is name 005.mod, then your tables should\nbe named sdtab005, tab005.tab, 005.tab, etc in the control stream\n\n."
    )->grid(-row=>7,-column=>1,-columnspan=>2,-sticky=>"w");
  $dupl_dialog_frame -> Entry (-width=>40, -border=>2, -relief=>'groove', -background=>$white,
     -textvariable=>\$new_ctl_descr)->grid(-row=>3,-column=>2,-sticky=>"w");

  $dupl_dialog_frame -> Checkbutton (-background=>$bgcol, -text=>"Change model name in \$PROB / \$TABLE / \$EST sections?",  -selectcolor=>$selectcol, -activebackground=>$bgcol,-variable=>\$change_run_nos)->grid(-row=>4,-column=>2,-columnspan=>2,-sticky=>'w');
  $dupl_dialog_frame -> Checkbutton (-background=>$bgcol, -text=>"Use final parameter estimates from reference model?",  -selectcolor=>$selectcol, -activebackground=>$bgcol, -variable=>\$est_as_init)->grid(-row=>5,-column=>2,-columnspan=>2,-sticky=>'w');
  $dupl_dialog_frame -> Checkbutton (-background=>$bgcol, -text=>"Fix estimates?", -selectcolor=>$selectcol, -activebackground=>$bgcol, -variable=>\$fix_est)->grid(-row=>6,-column=>2,-columnspan=>2,-sticky=>'w');

  #$dupl_dialog_frame -> Label (-text=>'')->grid(-row=>7,-column=>1,-sticky=>"e");
  $dupl_dialog_frame -> Label (-background=>$bgcol, -text=>'')->grid(-row=>8,-column=>1,-sticky=>"e");

  $dupl_dialog_frame -> Button (-text=>'Duplicate', -width=>12, -border=>$bbw, -background=>$button, -activebackground=>$abutton,-command=>sub {
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
      duplicate_model ($runno, $new_ctl_name, $new_ctl_descr, $new_ctl_ref, $change_run_nos, $est_as_init, $fix_est, \%setting);
      print $file;
      destroy $dupl_dialog;
      sleep(1); # to make sure the file is ready for reading
      #start_command ($software{editor}, win_path($cwd)."\\".$new_ctl_name.".".$setting{ext_ctl});
      edit_model ( unix_path($cwd)."\\".$new_ctl_name.".".$setting{ext_ctl});
      refresh_pirana($cwd);
    }
  }) -> grid(-row=>8,-column=>2,-sticky=>"w");
  $dupl_dialog_frame -> Button (-text=>'Cancel ', -width=>12, -border=>$bbw, -background=>$button, -activebackground=>$abutton, -command=>sub{destroy $dupl_dialog})->grid(-column=>1,-row=>8,-sticky=>"e");
}

sub new_ctl {
### Purpose : Dialog for creating a new model file, either blank or from a template (dialog + creation of model file)
### Compat  : W+L+
  my $overwrite_bool=1;
  $new_ctl_dialog = $mw -> Toplevel(-title=>'New model file');
  $new_ctl_dialog -> resizable( 0, 0 );
  center_window($new_ctl_dialog);
  $new_ctl_frame = $new_ctl_dialog -> Frame () -> grid(-ipadx=>'10',-ipady=>'10');
  $new_ctl_frame -> Label (-text=>'Model number (without .'.$setting{ext_ctl}.'):')-> grid(-column=>1, -row=>1,-sticky=>'nse');
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
  $new_ctl_frame -> Label (-text=>'Template: ')-> grid(-column=>1, -row=>2, -sticky=>'nse');
  $new_ctl_frame -> Label (-text=>'  ')-> grid(-column=>1, -row=>3, -sticky=>'nse');
  $menu = $new_ctl_frame -> Optionmenu(-options => [@templates_descr], -border=>$bbw,
      -variable=>\$template_chosen,-background=>$lightblue,-activebackground=>$darkblue, -justify=>'left', -border=>$bbw
        )-> grid(-column=>2,-row=>2);

  $new_ctl_frame -> Button (-text=>'Create model', -border=>$bbw, -background=>$button,-activebackground=>$abutton, -command=>sub{
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
}

sub new_dir {
### Purpose : Create a new folder (dialog + create new dir)
### Compat  : W+L+
  my $overwrite_bool=1;
  $newdir_dialog = $mw -> Toplevel(-title=>'New folder');
  $newdir_dialog -> resizable( 0, 0 );
  center_window($newdir_dialog);
  $newdir_dialog_frame = $newdir_dialog-> Frame(-background=>$bgcol)->grid(-ipadx=>'10',-ipady=>'10',-sticky=>'n');;
  $newdir_dialog_frame -> Label (-text=>"Folder name: \n")->grid(-column=>1,-row=>1,-sticky=>"ne");
  $newdir_dialog_frame -> Entry ( -background=>$white, -width=>20, -border=>2, -relief=>'groove', -textvariable=>\$new_dir_name)->grid(-column=>2,-row=>1,-sticky=>"ne");
  $newdir_dialog_frame -> Button (-text=>'Create folder',  -width=>12, -border=>$bbw, -background=>$button,-activebackground=>$abutton, -command=>sub{
    if (-e $cwd."/".$new_dir_name) {  # check if control stream already exists;
      $mw -> messageBox(-type=>'ok', -message=>"Folder ".$new_dir_name." already exists!");
      } else {
      mkdir ($cwd."/".$new_dir_name);
    }
    refresh_pirana($cwd);
    destroy $newdir_dialog;
  })->grid(-column=>2,-row=>2,-sticky=>"w");
  $newdir_dialog_frame -> Button (-text=>'Cancel', -width=>12, -border=>$bbw,-background=>$button,-activebackground=>$abutton,-command=>sub{
    destroy $newdir_dialog;
  })->grid(-column=>1,-row=>2,-sticky=>"e");
}

sub rename_ctl {
### Purpose : Rename a NM model file (create dialog and perform the renaming)
### Compat  : W+L+
  my $overwrite_bool=1;
  $old=@_[0];
  $ren_dialog = $mw -> Toplevel(-title=>'Rename model file');
  $ren_dialog -> resizable( 0, 0 );
  center_window($ren_dialog);
  $ren_dialog_frame = $ren_dialog-> Frame(-background=>$bgcol)->grid(-ipadx=>'10',-ipady=>'10',-sticky=>'n');
  $ren_dialog_frame -> Label (-background=>$bgcol,-text=>'Model number (without .'.$setting{ext_ctl}.'): '."\n")->grid(-column=>1,-row=>1,-sticky=>"ne");
  $ren_dialog_frame -> Label (-background=>$bgcol,-text=>"\nNB. Both model files and result file and will be renamed.\nOther files (e.g. table files) will not be modified.\n", -foreground=>'#777777', -justify=>"l")->grid(-column=>2,-row=>3,-sticky=>"nw",-columnspan=>1);
  $ren_dialog_frame -> Entry ( -background=>$white, -width=>10, -border=>2, -relief=>'groove', -textvariable=>\$ren_ctl_name)->grid(-column=>2,-row=>1,-sticky=>"nw");
  my $change_run_nos = 1;
  $ren_dialog_frame -> Checkbutton (-background=>$bgcol, -text=>"Change model name in \$PROB / \$TABLE / \$EST sections?", -selectcolor=>$selectcol, -activebackground=>$bgcol,-variable=>\$change_run_nos)->grid(-row=>2,-column=>2,-columnspan=>2,-sticky=>'w');
  $ren_dialog_frame -> Button (-text=>"Rename", -width=>12, -border=>$bbw,-background=>$button,-activebackground=>$abutton,-command=>sub{
    if ((-e $cwd."/".$ren_ctl_name.".".$setting{ext_ctl})||((-e $cwd."/".$ren_ctl_name.".".$setting{ext_res}))) {  # check if control stream already exists;
	$overwrite_bool = message_yesno ("Model- or result-file for ".$ren_ctl_name." already exists.\n Do you want to overwrite?", $mw, $bgcol, $font_normal);
    }
    if ($overwrite_bool==1) {
	if ($change_run_nos == 0) {
	    move ($old.".".$setting{ext_ctl}, $ren_ctl_name.".".$setting{ext_ctl});
	    move ($old.".".$setting{ext_res}, $ren_ctl_name.".".$setting{ext_res});
	} else {
	    my $mod_ref = extract_from_model ($modelfile, $modelno);
	    my %mod = %$mod_ref;
	    duplicate_model ($old, $ren_ctl_name, $mod{description}, $mod{refmod}, 1, 0, 0, \%setting);
	    if (-e $ren_ctl_name.".".$setting{ext_ctl}) {
		unlink ($old.".".$setting{ext_ctl});
	    }
	}
	db_rename_model ($old, $ren_ctl_name);
    }
    read_curr_dir($cwd, $filter, 1);
    destroy $ren_dialog;
  })->grid(-column=>2,-row=>4,-sticky=>"w");
  $ren_dialog_frame -> Button (-text=>'Cancel', -width=>12, -border=>$bbw,-background=>$button,-activebackground=>$abutton,-command=>sub{
    destroy $ren_dialog;
  })->grid(-column=>1,-row=>4,-sticky=>"e");
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
    check_db_file_correct ();

    my @bat_remove = dir($cwd,"pirana_start");
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
	undef @ctl_files; undef @ctl_descr; undef @firstline; undef @dirs; undef @dirs2; undef @dir_files;
	undef @ctl_copy; undef @ctl_descr_copy;
	undef @file_type; undef @file_type_copy;  @ctl_descr="";
	our @ctl_files = <*.$setting{ext_ctl}>;
	#our @ctl_files = dir (@_[$load_dir], $setting{ext_ctl}); # faster;

	$i=0; if (@ctl_files>0) {
	    foreach (@ctl_files) {
		@ctl_files[$i] =~ s/.$setting{ext_ctl}//i;
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
	    db_create_tables();
	    update_model_info(db_read_all_model_data()); # get all the models and info from the db if any present
	    status ("Updating database..."); # and update the hashes containing the info
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
			    db_execute ("INSERT INTO model_db (model_id) VALUES ('".$mod."') ");
			    push(@sql_commands, update_model_descr ($mod));
			    push(@sql_commands, update_run_results ($mod));
			}
		    }
		}
	    }
	    db_execute_multiple(\@sql_commands);
	    update_model_info(db_read_all_model_data());
	}

	# Get directories in the current folder
	our @dirs;
	our @dir_files = <*>;
#    our @dir_files = dir ("."); # is faster than a regular <*>  ?
	foreach(@dir_files) {
	    if (-d $_) {
		unless ($_ =~ /\./) {
		    push (@dirs,$_);
		    push (@dirs2,"/".$_);
		}
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
    if (($filter eq "")&&($psn_dir_filter==1)&&(($nmfe_dir_filter==1))) {
	@ctl_descr_copy = @ctl_descr;
	@ctl_copy = @ctl_files;
	@file_type_copy = @file_type;
    } else {
	$i=0;
	undef @ctl_copy; undef @ctl_descr_copy; undef @file_type_copy;
	foreach (@ctl_descr) {   # filter
	    $filter =~ s/[\*,\\,\/,\[,\]]//g;
	    if (((@ctl_files[$i] =~ m/$filter/i) || ($models_notes{@ctl_files[$i]} =~ m/$filter/i) || ($models_descr{@ctl_files[$i]} =~ m/$filter/i)) || ($filter eq "")) {
		unless (((@file_type[$i]<2)&&((@ctl_descr[$i] =~ m/modelfit_dir/i)||(@ctl_descr[$i] =~ m/npc_dir/i)||(@ctl_descr[$i] =~ m/bootstrap_dir/i)||(@ctl_descr[$i] =~ m/sse_dir/i)||(@ctl_descr[$i] =~ m/llp_dir/i))&&($psn_dir_filter==0))||((@file_type[$i]<2)&&(@ctl_descr[$i] =~ m/nmfe_/i)&&($nmfe_dir_filter==0)) || (@ctl_files[$i] =~ m/nmprd4p/i) || (@ctl_files[$i] =~ m/pirana_temp/i) ) {
		    push (@ctl_descr_copy, @ctl_descr[$i]);
		    push (@ctl_copy, @ctl_files[$i]);
		    push (@file_type_copy, @file_type[$i]);
		}
	    }
	    $i++;
	}
    }
    populate_models_hlist ($models_view, $condensed_model_list);
    status ();
}

sub update_model_info {
### Purpose : Read model info and update the hash
### Compat  : W+L?
    my @model_refs = db_read_all_model_data ();
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
	    push (@dofv, rnd(($ref_ofv_c{$meth} - $ofv_c{$meth}),3) );
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
  undef @ctl_show;
  if ($order eq "tree") {
    my ($ctl_show_ref, $tree_text) = tree_models();
    @ctl_show = @$ctl_show_ref;
    $models_hlist->columnWidth(0, (@header_widths[0]+@header_widths[1]));
    $models_hlist->columnWidth(1, 0);
  } else {
    @ctl_show = @ctl_copy;
    undef %model_indent;
    $models_hlist->columnWidth(0, @header_widths[0]);
    $models_hlist->columnWidth(1, @header_widths[1]);
  }
  if ($models_hlist) {
    $models_hlist -> delete("all");
    for ($i=0; $i<int(@ctl_show);$i++) {
      $models_hlist -> add($i);
      my $ofv_diff;
      unless ((@file_type_copy[$i] < 2)&&(length(@ctl_descr_copy[$i]) == 0)) {
        if (@file_type_copy[$i] < 2) {
          $runno = "<DIR>";
	  $style = $dirstyle;
          $models_hlist -> itemCreate($i, 0, -text => $runno, -style=>$style);
          $models_hlist -> itemCreate($i, 1, -text => "", -style=>$style);
          $models_hlist -> itemCreate($i, 2, -text => @ctl_descr_copy[$i], -style=>$style );
          for ($j=3;$j<=10;$j++) {$models_hlist -> itemCreate($i, $j, -text => " ", -style=>$dirstyle);}
        } else {
           $runno=@ctl_show[$i];
	   my $mod_background = "#FFFFFF";
           unless ($models_colors{$runno} eq "") {
             $mod_background = $models_colors{$runno};
           }
	   if (even($i)) {$mod_background = dark_row_color($mod_background)};
           our $style_ofv   = $models_hlist -> ItemStyle( 'text', -anchor => 'ne', -justify=>'l', -padx => 5, -background=>$mod_background, -font => $font_small, -foreground=>"#000000");
           our $style       = $models_hlist -> ItemStyle( 'text', -anchor => 'nw',-padx => 5, -background=>$mod_background, -font => $font_normal);;
           our $style_small = $models_hlist -> ItemStyle( 'text', -anchor => 'nw', -padx => 5, -background=>$mod_background, -font => $font_small);;
           our $style_green = $models_hlist -> ItemStyle( 'text', -padx => 5,-anchor => 'ne', -background=>$mod_background, -foreground=>'#008800',-font => $font_small);
           our $style_red   = $models_hlist -> ItemStyle( 'text', -padx => 5,-anchor => 'ne', -background=>$mod_background, -foreground=>'#990000', -font => $font_small);
           if (($models_ofv{$runno} ne "")&&($models_ofv{$models_refmod{$runno}} ne "")) {
	       $ofv_diff = calc_ofv_diff ($models_ofv{$models_refmod{$runno}}, $models_method{$models_refmod{$runno}}, $models_ofv{$runno}, $models_method{$runno}) ;
             #if ($ofv_diff >= $setting{ofv_sign}) { $style_ofv = $style_green; }
             #if ($ofv_diff < 0) { $style_ofv = $style_red; }
             #if (($ofv_diff >= 0)&&($ofv_diff < $setting{ofv_sign})) {
             #  $style_ofv = $models_hlist->ItemStyle( 'text', -anchor => 'ne',-padx => 5, -foreground=>'#A0A000', -background=>$mod_background,-font => $font_small);
             #}
             #$ofv_diff = rnd(-$ofv_diff,3); # round before printing
	   } else {$ofv_diff=""; $style_ofv = $models_hlist->ItemStyle( 'text', -anchor => 'ne',-padx => 5, -foreground=>'#000000', -background=>$mod_background,-font => $font_small);}
	   my $runno_text = "";
	   for ($sp=0; $sp<$model_indent{$runno}; $sp++) {$runno_text .= "   "};
	   if ($model_indent{$runno}>0) {$runno_text .= "» ";}
	   $runno_text .= $runno;
	   my $method_temp = $models_method{$runno};
	   my $ofv_temp    = $models_ofv{$runno};
	   my $dofv_temp   = $ofv_diff;
	   my $succ_temp; my $cov_temp; my $bnd_temp; my $sig_temp;
	   my @meth = split (",",$method_temp);
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
          $models_hlist -> itemCreate($i, 0, -text => $runno_text.$add_condensed, -style=>$style);
          $models_hlist -> itemCreate($i, 1, -text => $models_refmod{$runno}, -style=>$style_small);
          $models_hlist -> itemCreate($i, 2, -text => $models_descr{$runno}, -style=>$style );
          $models_hlist -> itemCreate($i, 3, -text => $method_temp, -style=>$style);
          $models_hlist -> itemCreate($i, 4, -text => $ofv_temp, -style=>$style);
          $models_hlist -> itemCreate($i, 5, -text => $dofv_temp, -style=>$style);
          $models_hlist -> itemCreate($i, 6, -text => $succ_temp, -style=>$style);
          $models_hlist -> itemCreate($i, 7, -text => $cov_temp, -style=>$style);
          $models_hlist -> itemCreate($i, 8, -text => $bnd_temp, -style=>$style);
          $models_hlist -> itemCreate($i, 9, -text => $sig_temp, -style=>$style);
          my $note = $models_notes{$runno};
	  if ($condensed == 1) {$note =~ s/\n/\ /g;}
          $models_hlist -> itemCreate($i, 10, -text => $note, -style=>$style);
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
  if (chdir ($dir)) {
  if ($show_data eq "tab") {
    my @tab_files = dir ("./",'.'.$setting{ext_tab});
    our @xp_tabs = <??tab*>;
    my @vpc_tabs = <vpctab*>;
    push (@xp_tabs, @vpc_tabs);
    foreach (@tab_files) {
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
  }
  if (($show_data eq "tab")||($show_data eq "fit")) {
    my @dirs = <*>;
    foreach (@dirs) {
      ($model,$rest) = split (/\./, $_);
      if ((-d $_)&&($_ =~ m/\./)&&(-e $_."/".$model.".fit")) {
        push (@tabcsv_files, $model.".fit (".$rest.")");
        push (@tabcsv_files_loc, $_."/".$model.".fit");
      }
    }
  }
  if ($show_data eq "csv") {
    our @csv_files = <*.$setting{ext_csv}>;
    @tabcsv_files = @csv_files;
    @tabcsv_files_loc = @csv_files;
  }

  if ($show_data eq "xpose") {
    our @xp_tabs = <??tab*>;
    our @xp_tabsnos = ();
    foreach(@xp_tabs) {
      $no = $_;
      $no =~ s/sdtab//i;
      $no =~ s/patab//i;
      $no =~ s/catab//i;
      $no =~ s/cotab//i;
      $no =~ s/cwtab//i;
      @test = grep (/$no/, @xp_tabsnos);
      #print int(@test)."\n";
      unless (int(@test)>0) {
        unless (($no =~ m/.$setting{ext_tab}/ig)||($no =~ m/\.csv/ig)||($no =~ m/\.deriv/ig)||($no =~ m/\.est/ig)) {
          push (@xp_tabsnos, $no);
        }
      }
    }
    @tabcsv_files = sort (@xp_tabsnos);
  }
  if ($show_data eq "R") {
    our @R_files = <*\.[RS]>;
    @tabcsv_files = @R_files;
    @tabcsv_files_loc = @R_files;
  }
  if ($show_data eq "*") {
    our @all_files = <*>;
    foreach (@all_files) {
	unless (-d $_) {
	    push(@tabcsv_files, $_);
	    push(@tabcsv_files_loc, $_);
	}
    }
  }

  # get table/file info from databases and put in hash
  chdir($cwd);
  $db_table_info = db_read_table_info ();
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

sub configure_tab_buttons {
### Purpose : Activate/deactive the correct buttons for the table-overview listbox
### Compat  : W+L+
  my $show_data = shift;
  # first deactivate all buttons
  $show_tab_button->configure(-background=>$button);
  $show_csv_button->configure(-background=>$button);
  $show_xpose_button->configure(-background=>$button);
  $show_r_button->configure(-background=>$button);
  $show_all_button->configure(-background=>$button);
  if ($show_data eq "tab") {$show_tab_button->configure(-background=>$abutton);}
  if ($show_data eq "csv") {$show_csv_button->configure(-background=>$abutton);}
  if ($show_data eq "xpose") {$show_xpose_button->configure(-background=>$abutton);}
  if ($show_data eq "R") {$show_r_button->configure(-background=>$abutton);}
  if ($show_data eq "*") {$show_all_button->configure(-background=>$abutton);}

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
  $i=0;
  my $hlist = shift;
  $style = $align_left;
  foreach (@tabcsv_files) {
    if($hlist) {
      $hlist -> add($i);
      my $style = $hlist-> ItemStyle('text', -anchor => 'nw',-padx => 5, -background=> $tab_hlist_color, -font => $font_normal);
      $hlist -> itemCreate($i, 0, -text => $_, -style=>$style);
      $i++;
    }
  }
}

sub print_note {
### Purpose : Print a note saying that the model was executed from Piraña
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
    my ( $command_area, $script_file, $model_list, $nm_version_chosen, $method_chosen, $run_in_new_dir, $new_dirs_ref, $run_in_background, $clusters_ref, $ssh_ref, $nm_versions_menu) = @_;
    #build_nmfe_run_command ($script_file, $model_list, $nm_version_chosen, $method_chosen, $run_in_new_dir, $new_dirs_ref, $run_in_background, $clusters_ref);
    my ($run_script, $script_ref) = create_nm_start_script ($script_file, $nm_version_chosen, os_specific_path($cwd), $model_list, $run_in_new_dir, $new_dirs_ref, $clusters_ref, $ssh_ref);
    my @script = @$script_ref;
    if ($command_area) {
	$command_area -> delete("0.0", "end");
	$command_area -> insert("0.0", join ("", @script));
    }
    my %ssh = %$ssh_ref;
    if ($ssh {connect_ssh} == 1 ) {
	my ($nm_dirs_cluster_ref, $nm_vers_cluster_ref) = read_ini($home_dir."/ini/nm_inst_cluster.ini");
	my @nm_installations = keys(%$nm_dirs_cluster_ref);
	if ($nm_versions_menu) {
	    $nm_versions_menu -> configure (-options=> [@nm_installations]);
	}
    } else {
	my ($nm_dirs_ref, $nm_vers_ref) = read_ini($home_dir."/ini/nm_inst_local.ini");
	my @nm_installations = keys(%$nm_dirs_ref);
	if ($nm_versions_menu) {
	    $nm_versions_menu -> configure (-options=> [@nm_installations]);
	}
    }

    # update global settings
    my %clusters = %$clusters_ref;
    $setting{sge_parameters} = $clusters{sge_parameters};
    $setting{sge_command} = $clusters{sge_submit_command};
    $setting{ssh_parameters} = $ssh{parameters};
    $setting{ssh_login} = $ssh{login};
    $setting{ssh_cluster_mount} = $ssh{remote_folder};
    $setting{ssh_local_mount} = $ssh{local_folder};
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
    $setting{ssh_login} = $ssh{login};
    $setting{ssh_cluster_mount} = $ssh{remote_folder};
    $setting{ssh_local_mount} = $ssh{local_folder};
    return();
}

sub build_nmfe_run_command {
    ($script_file, $model_list_ref, $nm_inst, $method, $run_in_new_dir, $new_dirs_ref, $run_in_background, $clusters_ref, $ssh_ref) = @_;
    my @files = @$model_list_ref;
    my %nm_dirs_run = %$nm_dirs_ref;
    my %nm_vers_run = %$nm_vers_ref;
    my %ssh = %$ssh_ref;
    my @nm_installations = keys(%nm_dirs_run);
    my ($run_script, $script_ref) = create_nm_start_script ($script_file, $nm_inst, os_specific_path($cwd), \@files, $run_in_new_dir, $new_dirs_ref, $clusters_ref, $ssh_ref);
    if (@nm_installations > 0) {
	my $command;
	if ($nm_dir_check==1) { # start NM run in a new folder
	    $nm_new_dir = "nmfe_".@runs[0]."_".generate_random_string(5);
	}
	my $ssh = "";
	if ($ssh{connect_ssh} == 1) { # through SSH
	    $ssh = $ssh{login}." ";
	    if ($ssh{parameters} ne "") {
		$ssh .= $ssh{parameters}.' "';
	    }
	    $dir = $dir_entry -> get();
	    $dir =~ s/$ssh{local_folder}//gi;
	    $ssh .= "cd ".$ssh{remote_folder}."/".$dir."; ";
	    $command = $ssh;
	    $cwd = $dir_entry -> get();
	    my $l = length($cwd);
	    unless (lcase(substr($cwd,0,$l)) eq lcase($setting{cluster_drive})) {
		message ("Your current working directory is not located on the cluster.\nChange to your cluster-drive or change your preferences.");
		return();
	    }
	}
	if ($os =~ m/MSWin/i) {
	    if ($run_in_background == 1) {
		$command .= $run_script;
	    } else {
		$command .= $run_script;
	    }
	} else {
	    $command .= 'bash '.$run_script;
	}
	if (($run_in_background == 0)) {
	    if ($os =~ m/MSWin/i) {
		$command = "start ".$command ;
	    } else {
		if ($setting{quit_shell}==0) { # don't close terminal window after completion
		    $command .= ';read -n1';
		}
		$command = $setting{terminal}.' -e "'.$command.'" ';
	    }
	} else {
	    if ($os =~ m/MSWin/i) {
		$command = "start /b ".$command;
	    }
	}
	if ($ssh{connect_ssh}==1) { $command .= '"'};
	unless ($os =~ m/MSWin/ ) {$command .= " &"}
	return ($run_script, $command, $script_ref);
    } else {
	return ("Please add local NM installations first", "Please add local NM installations first", "")
    }
}

sub exec_run_nmfe {
### Purpose : Run a model using the nmfe command
### Compat  : W+L?
    $command = shift;
    status ("Starting run");
    chdir($cwd);
    system $command;
    status ();
}

sub exec_run_psn {
    my ($psn_command_line, $ssh_ref, $model, $model_description, $background) = @_;
    my %ssh = %$ssh_ref;
    print $background;
    status ("Starting run(s) locally using PsN");
    if($os =~ m/MSWin/) {
	if ($background == 0) {
	    $psn_command_line = "start ".$psn_command_line;
	}
    } else {
	if ($background == 1) {
	    $psn_command_line = $psn_command_line." &";
	} else {
	    if ($setting{terminal} ne "") {
		if ($setting{quit_shell}==0) { # don't close terminal window after completion
		    $psn_command_line .= ';read -n1';
		}
		$psn_command_line = $setting{terminal}." -e '".$psn_command_line."' &";
	    }
	}
    }
    system ($psn_command_line);
    $psn_command_line =~ s/\'//g;
    db_log_execution ($model, $model_description, "PsN", "local", $psn_command_line, $setting{name_researcher});
    status ();
}

sub update_psn_run_command {
    my ($command_line, $parameter, $value, $add, $ssh_ref, $clusters_ref) = @_;
    @com = split (" ",$command_line);
    my $parameter_found=0;
    my $eq="=";
    if ($value eq "") {$eq = ""};
    foreach (@com) {if ($_ =~ m/$parameter/g) {$_ = $parameter.$eq.$value; $parameter_found=1}};
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
    my ($psn_command, $psn_parameters, $model, $ssh_ref, $clusters_ref) = @_;
    my %ssh = %$ssh_ref;
    my $psn_command_line = $psn_command." ".$psn_parameters." ".$model.".".$setting{ext_ctl};
    my $ssh_add = "";
    my $ssh_add2 = "";
    my $outputfile= $model.".".$setting{ext_res};

    if ($psn_command eq "execute") {
	$psn_command_line = update_psn_run_command ($psn_command_line, "-outputfile", $outputfile, 1, \%ssh, \%clusters);
    };
    if ($psn_command eq "sumo") {
	$psn_command_line .= " ".$outputfile;
    } else {
	$psn_command_line = update_psn_run_command ($psn_command_line, "-nm_version", "default", 0, \%ssh, \%clusters);
	$psn_command_line .= " ".$modelfile;
    }
    if ($ssh{connect_ssh}==1) {
	$ssh_add = $ssh{login}." ";
	if ($ssh{parameters} ne "") {
	    $ssh_add .= $ssh{parameters}.' "';
	}
	$dir = $dir_entry -> get();
	$dir =~ s/$ssh{local_folder}//gi;
	$ssh_add .= "cd ".$ssh{remote_folder}."/".$dir."; ";
	$ssh_add2 = '"';
	$cwd = $dir_entry -> get();
	my $l = length($cwd);
	unless (lcase(substr($cwd,0,$l)) eq lcase($setting{cluster_drive})) {
	    message ("Your current working directory is not located on the cluster.\nChange to your cluster-drive or change your preferences.");
	    return();
	}
    }
    if ($clusters{run_on_pcluster}==1) {
        if (lcase(substr($cwd,0,1)) eq lcase(substr($setting{cluster_drive},0,1))) {
            $psn_command_line = win_path($software{perl_dir})."\\bin\\".$psn_command_line;
            $psn_command_line = "start ".$psn_command_line;
            #if ($stdout) {$stdout -> insert('end', "\n".$psn_command);}
        } else {  message ("Your current directory is not located on the cluster.\nChange to your cluster-drive or change your preferences.")};
    }
    $psn_command_line = $ssh_add.$psn_command_line.$ssh_add2 ;
    return( $psn_command_line );
}

sub text_window {
### Purpose : Show a window with a text-widget containing the specified text
### Compat  : W+L+
  my ($text, $title, $font) = @_;
  if ($font eq "" ) {$font = $font_fixed};
  unless ($text_window) {
    our $text_window = $mw -> Toplevel(-title=>$title);
    $text_window -> OnDestroy ( sub{
      undef $text_window; undef $text_window_frame;
    });
    $text_window -> resizable( 0, 0 );
  }
  my $text_window_frame = $text_window -> Frame(-background=>$bgcol)->grid(-ipadx=>10,-ipady=>10)->grid(-row=>1,-column=>1, -sticky=>'nwse');
  $text_window_frame -> Button (-text => 'Close', -width=>12,
    -background=>$button, -activebackground=>$abutton, -border=>$bbw,
    -command=> sub{
      $text_window -> destroy();
  }) -> grid(-column=>1, -row=>2, -sticky=>'ne');
  my $text_text = $text_window_frame -> Scrolled ('Text',
      -scrollbars=>'e', -width=>80, -height=>35,
      -background=>"#FFFFFF",-exportselection => 0,
      -relief=>'groove', -border=>2,
      -font=>$font, -wrap=>"none",
      -selectbackground=>'#606060', -highlightthickness =>0
  ) -> grid(-column=>1, -row=>1, -sticky=>'nwes');
  $text_text->insert('end', $text);
  return ($text_text);
}

sub text_window_nm_help {
### Purpose : Show a window with a text-widget containing the specified text
### Compat  : W+L+
    my ($keywords_ref, $title, $font) = @_;
    my @keywords = @$keywords_ref;
    if ($font eq "" ) {$font = $font_fixed};
    our ($text_window_keywords, $text_window_nm_help);
    unless ($text_window_keywords) {
	our $text_window_keywords = $mw -> Toplevel(-title=>$title);
	$text_window_keywords -> OnDestroy ( sub{
	    undef $text_window_keywords; undef $text_window__keywords_frame;
	});
	$text_window_keywords -> resizable( 0, 0 );
    }

    my $text_window_keywords_frame = $text_window_keywords -> Frame(-background=>$bgcol)->grid(-ipadx=>10,-ipady=>10)->grid(-row=>1,-column=>1, -sticky=>'nwse');
    $text_window_keywords_frame -> Label (-text=> "Keyword:", -font=>$font_normal) -> grid(-row=>0, -column=>2, -sticky=>"nw");
    $nm_help_filename = $text_window_keywords_frame -> Label (-text=> "", -font=>$font_bold) -> grid(-row=>0, -column=>3, -sticky=>"nw");
    our $keywords_list = $text_window_keywords_frame -> Listbox (
	-width=>10, -height=>26, -activestyle=> 'none', -exportselection => 0, -relief=>'groove', -border=>2, -selectmode=>'single',
	-selectbackground=>'#CCCCCC', -highlightthickness =>0, -background=>'#ffffff', -font=>$font_normal
    ) -> grid(-column=>2,-row=>1, -sticky=>'nwe');
    my $text_text = $text_window_keywords_frame -> Scrolled ('Text',
        -scrollbars=>'e', -width=>80, -height=>26,
        -background=>"#FFFFFF",-exportselection => 0,
        -relief=>'groove', -border=>2,
        -font=>$font,
        -selectbackground=>'#606060', -highlightthickness =>0
    ) -> grid(-column=>3, -row=>1, -sticky=>'nwes');
    my @nm = values (%nm_dirs);
    $keywords_list -> bind('<Button>', sub{
	my @x_sel = $keywords_list -> curselection;
	my $keyword = ($keywords_list -> get (@x_sel[0]));
	my $nm_help_text = get_nm_help_text (@nm[0], $keyword);
	$text_text -> delete("0.0", "end");
	$text_text -> insert("0.0", $nm_help_text);
	$nm_help_filename -> configure (-text => $keyword);
    });
    $keywords_list -> bind('<Down>', sub{
	my @x_sel = $keywords_list -> curselection;
	my $keyword = ($keywords_list -> get (@x_sel[0]));
	my $nm_help_text = get_nm_help_text (@nm[0], $keyword);
	$text_text -> delete("0.0", "end");
	$text_text -> insert("0.0", $nm_help_text);
	$nm_help_filename -> configure (-text => $keyword);
    });
    $keywords_list->bind('<Up>', sub{
	my @x_sel = $keywords_list -> curselection;
	my $keyword = ($keywords_list -> get (@x_sel[0]));
	my $nm_help_text = get_nm_help_text (@nm[0], $keyword);
	$text_text -> delete("0.0", "end");
	$text_text -> insert("0.0", $nm_help_text);
	$nm_help_filename -> configure (-text => $keyword);
    });

    $keywords_list -> insert(0, @keyworsd);
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
    foreach (@clients) {
	if ($busy_cpus{$_} < $total_cpus{$_}) {$clients_status{$_} = ($total-$runs); $clients_status_text {$_} = ($total_cpus{$_}-$busy_cpus{$_})." of ".$total_cpus{$_}." CPU(s) available" };
	if ($busy_cpus{$_} == $total_cpus{$_}) {$clients_status{$_} = 0; $clients_status_text{$_} = "All busy: ".$busy_cpus{$_}." CPU(s)" };
    }
    foreach (@clients) {
	if (($clients_status{$_} == 0)&&($clients_status_text{$_}) ne "") {
	    push (@available, $_." - ".$pc_names{$_}." - ".$clients_status_text{$_});
	    # print $_." - ".$clients{$_}." - ".$clients_status_text{$_};
	}
	$i++;
    }
    @available = sort { $a <=> $b } @available;
    return (@available)
}

sub distribute {
### Purpose : Create an interface for distributing NM runs (using nmfe-method) to PCluster (actual distribution of runs is done in sub exec_run_pcluster)
### Compat  : W+L?
  ($nm_inst, $method, $nm_type) = @_;
  my $run_flag=0;
  $comp_errors=0;
  $cluster_report=0;
  $used_clients="";
  our @runs_all = $models_hlist -> selectionGet ();
  our @runs = @runs_all;
  $batches = 1 ; # computer chosen manually
  my @available;
  $i=0;
  my ($total_cpus_ref, $busy_cpus_ref, $pc_names_ref) = get_active_nodes($setting{cluster_drive}, \%clients);
  my %total_cpus = %$total_cpus_ref;
  my %busy_cpus = %$busy_cpus_ref;
  my %pc_names = %$pc_names_ref;
  my %clients_status; my %clients_status_text;
  my @clients = keys(%total_cpus);
  foreach (@clients) {
    if ($busy_cpus{$_} < $total_cpus{$_}) {$clients_status{$_} = ($total-$runs); $clients_status_text {$_} = ($total_cpus{$_}-$busy_cpus{$_})." of ".$total_cpus{$_}." CPU(s) available" };
    if ($busy_cpus{$_} == $total_cpus{$_}) {$clients_status{$_} = 0; $clients_status_text{$_} = "All busy: ".$busy_cpus{$_}." CPU(s)" };
  }
  foreach (@clients) {
    if (($clients_status{$_} == 0)&&($clients_status_text{$_}) ne "") {
      push (@available, $_." - ".$pc_names{$_}." - ".$clients_status_text{$_});
      # print $_." - ".$clients{$_}." - ".$clients_status_text{$_};
    }
    $i++;
  }
  @available = sort { $a <=> $b } @available;
  if(@available==0) {
    $mw -> messageBox(-type=>'OK',
       -message=>("No clients available on cluster!"));
  } else {
    if ($method =~ m/distribute/i) { # distribute
      exec_run_pcluster($nm_inst, "", $nm_type);
      cluster_report(@runs_all-$comp_errors, $specific_client);
    }
    if ($method =~ m/client/i) { # run on specific client
      $cluster_report=0;
      if ($run_client_w) {undef $run_client_w;};
      $run_client_w = $mw -> Toplevel(-title=>'On specific client');
      $run_client_w -> resizable( 0, 0 );
      center_window($run_client_w);
      $run_client_frame = $run_client_w -> Frame(-background=>$bgcol)->grid(-ipadx=>'10',-ipady=>'10',-sticky=>'nws');
      $run_client_frame -> Label(-text=>"Run model(s):",-justify	=>'left')-> grid(-row=>0,-column=>1,-sticky => 'wn'); ;
      $run_client_frame -> Label(-text=>join("\n",@ctl_show[@runs]),-justify	=>'left')-> grid(-row=>0,-column=>2,-sticky => 'w');
      $run_client_frame -> Label(-text=>"on client: ",-justify	=>'left')-> grid(-row=>1,-column=>1,-sticky => 'w  ');
      $run_client_frame -> Optionmenu(-options => [@available], -variable => \$specific_client,-border=>$bbw,
        -command=>sub{},-background=>$lightblue,-activebackground=>$darkblue,-font=>$font_normal)
        -> grid(-row=>1,-column=>2,-sticky => 'we');
      $run_client_frame -> Button(-image=>$gif{run}, -height=>50, -width=>50,-background=>$button, -activebackground=>$abutton,-border=>$bbw,-command=> sub{
        my ($client, $rest) = split(/-/,$specific_client);
        exec_run_pcluster($nm_inst, $client, $nm_type);
        cluster_report(@runs_all-$comp_errors, $specific_client);
        $run_client_w -> destroy();
      } )->grid(-row=>1,-column=>3,-columnspan=>2,-sticky=>'we');
    }
    if ($cluster_report==1) {
      cluster_report(@runs_all-$comp_errors, $used_clients)
    }
  }
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

sub exec_run_pcluster { # (nm_inst, client)
### Purpose : Run a model on PCluster (using nmfe-method)
### Compat  : W+L?
  if ($setting{zink_host} eq "") {
    message ("Please specify a Zink-host under preferences, and try again.");
    return();
  }
  unless ($cwd =~ m/$setting{cluster_drive}/i) {
    message ("Models to be run need to be located on the assigned cluster drive (".$setting{cluster_drive}.")")
  } else {
  status ("Starting run on PCluster...");
  my ($nm_inst, $comp, $nm_type) = @_;
  print "Client: ".$comp;
  my @runs = $models_hlist -> selectionGet ();
  if ($ENV{PATH}=~m/$nm_dir/) {;} else {$ENV{PATH}="$nm_dir/util;".$ENV{PATH}} ;
  unlink $base_dir."/log/compilation_log.txt";
  open (OUT,">".$base_dir."/log/compilation.txt");
  print OUT "********************************************************************************\n";
  print OUT "*** NONMEM Cluster compilation log created by Piraña                         ***\n";
  print OUT "********************************************************************************\n";

  my $rand_bat = &generate_random_string(4);
  chdir $cwd;
  for ($j=0;$j<@runs;$j++) {
        $error_flag=0;
        $file = @ctl_show[@runs[$j]];
        my $new_dir = move_nm_files ($file, $run_in_nm_dir);
        if (-e $new_dir) {
          chdir $new_dir;
          $nm_dir = $nm_dirs{@_[0]};
          $nm_dir =~ win_path($nm_dir);
          print OUT "Run  : ".$file;
          print OUT "date ";
          print OUT "time ";
          status ("Starting compilation of nonmem.exe");
          if ($nm_type =~ m/nmq/i) {
            $nmq_parameters = $nmq_params_entry -> get();
            $bat_file = compile_run_nmq ($nm_dir, $file.".".$setting{ext_ctl}." ".$file.".".$setting{ext_res}, $nmq_parameters);
            system $bat_file.' >"'.win_path($base_dir."/log/compilation_NM.txt").'"';
          } else {
            print OUT win_path($nm_dir."/util/pirana_nmfe".$nm_vers{$nm_inst}."_compile.bat ".$file.".".$setting{ext_ctl}." ".$file.".".$setting{ext_res}.' >"'.win_path($base_dir)."/log/compilation_NM.txt");
            system win_path($nm_dir."/util/pirana_nmfe".$nm_vers{$nm_inst}."_compile.bat ".$file.".".$setting{ext_ctl}." ".$file.".".$setting{ext_res}.' >"'.win_path($base_dir)."/log/compilation_NM.txt");
          }
        }
        open (IN, "<".$base_dir."/log/compilation_NM.txt");
        @NM_compile=<IN>;
        close IN;
        print OUT @NM_compile;
        if (-e "nonmem.exe") {
          $comp =~ s/\s+$//;  #remove trailing spaces
          open (BAT, ">nonmem.bat");
          print BAT "nonmem.exe\n";
          print BAT "copy ".$file.".".$setting{ext_res}." + OUTPUT ".$file.".".$setting{ext_res}."\n";
          close BAT;
          $command = "nonmem.bat";
          generate_zink_file ($setting{zink_host}, $setting{cluster_drive}, $file, 3, $cwd."/".$new_dir, $command, $comp);
        } else {
          print OUT "Error: No NONMEM executable created, run aborted.\n"; ; $error_flag=1;};
          print OUT "********************************************************************************\n";
          if ($error_flag>0) {$comp_errors++};
      }
      print OUT "Finished copying runs to cluster. \n";
      close OUT;
      status ();
  }
  chdir ($cwd);
}

sub get_nmfe_number {
### Purpose : Get the highest number of nmfe_ directories (and add one)
### Compat  : W+L+
  my $file = shift;
  my $max = 0;
  my @dirs_copy = @dirs;
  foreach (@dirs_copy) {
    if ($_ =~ s/nmfe\_//) {
      my ($run, $num) = split (/\_/, $_);
      if ($run eq $file) {
        if ($num =~ /^-?\d/) {  # check if number
          if ($num > $max) {$max = $num;};
        }
      }
    }
  }
  my $max = sprintf("%03d", ($max+1));
  return($max);
}

sub copy_dir_res {
### Purpose : The dialog window to copy results and tab_files from selected dir ( calls copy_dir_res_function()  )
### Compat  : W+L+
  ($cwd, $dirs_ref) = @_;
  my @dirs = @$dirs_ref;
  undef @lst_all; undef @tab_all ; undef @tab_all_loc; undef @lst_all_loc ;
  my @lst_all = (); my @tab_all = (); my @tab_all_loc = (); my @lst_all_loc = (); my @lst_loc =(); my @tab_loc =();
  foreach $sub (@dirs) {
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
    $copy_dir_res_window -> resizable( 0, 0 );
    center_window($copy_dir_res_window);
    $copy_dir_res_frame = $copy_dir_res_window->Frame(-background=>$bgcol)->grid(-ipadx=>8, -ipady=>8);
    $copy_dir_res_frame -> Label (-text=>"Copy files:",-font=>$font_normal,)->grid(-row=>1, -column=>1, -sticky=>"ne");
    $copy_dir_res_text = $copy_dir_res_frame -> Scrolled ('Text', -font=>$font_normal,-width=>32, -height=>8, -scrollbars=>'e')
      -> grid(-row=>1, -column=>2, -ipady=>5, -columnspan=>2);
    $copy_dir_res_text -> insert ("0.0", $lst_files."\n".$tab_files);
    $copy_dir_res_text -> configure(state=>'disabled');
    $copy_res_to = $cwd;
    $copy_dir_res_frame -> Label (-text=>" ",-font=>$font_normal,)->grid(-row=>2, -column=>1, -sticky=>"ne");
    $copy_dir_res_frame -> Label (-text=>"To folder:",-font=>$font_normal,)->grid(-row=>3, -column=>1, -sticky=>"ne");
    $copy_dir_res_text = $copy_dir_res_frame -> Entry ( -background=>$white, -textvariable => \$copy_res_to, -font=>$font_normal, -width=>32)
      -> grid(-row=>3, -column=>2, -sticky=>'wns', -columnspan=>2);
    $copy_dir_res_frame -> Label (-text=>" ",-font=>$font_normal,)->grid(-row=>4, -column=>1, -sticky=>"ne");
    $copy_dir_res_frame -> Label (-justify=>'left',-text=>"NB: Copying will overwrite existing files\nin the destination folder",-font=>$font_normal,)->grid(-row=>5, -column=>2, -columnspan=>2,-sticky=>"nw");
    $copy_dir_res_frame -> Label (-text=>" ",-font=>$font_normal,)->grid(-row=>6, -column=>1, -sticky=>"ne");

    $copy_dir_res_frame -> Button (-text=>"Copy", -width=>10, -background=>$button, -border=>$bbw, -activebackground=>$abutton, -command=> sub {
      $i = 0;
      my $to_dir = $copy_dir_res_text -> get();
      foreach (@lst_all) {
        if ($_ ne "") {
          copy ($cwd."/".@lst_all_loc[$i], $to_dir."/".@lst_all[$i]);
        }
        $i++;
      }
      $i = 0;
      foreach (@tab_all) {
        if ($_ ne "") {
          copy ($cwd."/".@tab_all_loc[$i], $to_dir."/".@tab_all[$i]);
          print $cwd."/".@tab_all_loc[$i].$to_dir."/".@tab_all[$i];
        }
        $i++;
      }
      $copy_dir_res_window -> destroy;
      read_curr_dir($cwd,$filter,1);
      return();
    })->grid(-row=>7,-column=>3,-sticky=>'nwse');
    $copy_dir_res_frame -> Button (-text=>"Cancel", -width=>10, -background=>$button, -border=>$bbw, -activebackground=>$abutton, -command=> sub {
      $copy_dir_res_window -> destroy;
      return();
    })->grid(-row=>7,-column=>2,-sticky=>'nwse');
  } else {message ("No result or \$TABLE files were found in this directory.")}
}

sub copy_dir_res_function {
### Purpose : The function to copy results and tab_files from selected dir
### Compat  : W+
  $sub = shift;
  my (@lst_all, @tab_all, @tab_all_loc, @lst_all_loc, @lst_loc, @tab_loc) =();
  if (-d $sub) {
    chdir ($sub);
    my @lst = <*.$setting{ext_res}>;
    foreach(@lst) {push (@lst_loc, $sub."/".$_)};
    my @tab = <*.$setting{ext_tab}>;
    foreach(@tab) {push (@tab_loc, $sub."/".$_)};
    push (@lst_all, @lst);
    push (@tab_all, @tab);
    push (@lst_all_loc, @lst_loc);
    push (@tab_all_loc, @tab_loc);
    chdir ("..");
  }
  return (\@tab_all, \@tab_all_loc, \@lst_all, \@lst_all_loc);
}

sub create_output_summary {
### Purpose : Loop over all NM results files, and put the resutls in a csv file
### Compat  : W+L?
  $output = shift;
  my @dir = <*.$setting{ext_res}>;
  if (@dir>0) {
    open (CSV, ">pirana_output_list.csv");
    @headers = join (",","Model no", "OFV", "Description", "Notes", "Method", "Min. success?",
      "Functions evals","Sign. digits", "Cond. number", "Boundaries?", "COV step successful?",
      "Model file date","Result file date");
    print CSV @headers;
    print CSV "\n";
    $failed = "";
    foreach $file (@dir) {
        my $res_ref = extract_from_lst ($file);
        my %res = %$res_ref;
        my $model = $file;
        $model =~ s/.$setting{ext_res}//i;
        status ("Reading file: ".$file."...");
        $models_notes{$model} =~ s/\n/\./g;
        $models_notes{$model} =~ s/,/;/g;
        $models_descr{$model} =~ s/,/;/g;
        ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime($models_dates_db{$model});
        $model_date = sprintf "%4d-%02d-%02d %02d:%02d:%02d", $year+1900,$mon+1,$mday,$hour,$min,$sec;
        ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime($models_resdates_db{$model});
        $res_date = sprintf "%4d-%02d-%02d %02d:%02d:%02d", $year+1900,$mon+1,$mday,$hour,$min,$sec;
        @res_lst = ('="'.$model.'"', $models_ofv{$model}, $models_descr{$model}, $models_notes{$model},
          $models_method {$model}, $models_suc{$model},  $res{feval}, $res{sig}, $res{cond_nr},
          $models_bnd{$model}, $models_cov{$model}, $model_date, $res_date);
        print CSV join (",", @res_lst);
        print CSV "\n";
    }
    close (CSV);
  } else {message ("No results files were found.")}
}

sub frame_tab_show {
### Purpose : Construct the frame showing the table/csv files
### Compat  : W+L+
  if (@_[0]==1) {
  #our $frame2 = $mw -> Frame(-background=>$bgcol) ->grid(-row=>2,-column=>3,-ipadx=>'8', -ipady=>'0',-sticky=>'n');
  unless($tab_frame) {
    $tab_frame = $model_overview_frame -> Frame(-background=>$bgcol) ->grid(-row=>2,-column=>10, -rowspan=>1,-ipadx=>5, -ipady=>0,-sticky=>'wn');
    if ($os =~ m/MSWin/i) {$tab_frame -> Label(-text=>"",-font=>'Arial 1', -height=>1)->grid (-row=>3, -column=>1);}
    #$tab_button_frame = $tab_frame -> Frame(-background=>$bgcol) ->grid(-row=>2,-column=>7,-columnspan=>8,-ipadx=>'0', -ipady=>'0',-sticky=>'wn');
  }
  our $summary1,$summary2, $dvvspred, $wresvspred, $other;
  our $show_res = "all_output";

 # result files
  if ($tab_frame) {

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
  }
  #table file listbox
  #our $tab_hlist_color = "#f5FAFF";
  our $tab_hlist_color = "#f0f0f0";
  if ($tab_frame) {
  our $tab_hlist = $tab_frame ->Scrolled('HList',
        -head       => 0,
        -selectmode => "single",
        -highlightthickness => 0,
        -columns    => 1, # int(@models_hlist_headers),
        -scrollbars => 'se',
        -width      => 20,
        -height     => $nrows,
        -border     => 1,
        -pady       => 0,
        -padx       => 0,
        -background => $tab_hlist_color,
        -selectbackground => $pirana_orange,
        -font       => $font_normal,
        -command    => sub {

           my $tabsel = $tab_hlist -> selectionGet ();
           my $tab_file = os_specific_path(@tabcsv_loc[@$tabsel[0]]);
           if (($tab_file ne "")&&(-e $tab_file)) {
	         edit_model(unix_path($tab_file));
           }
        },
        -browsecmd   => sub{
            my $tabsel = $tab_hlist -> selectionGet ();
            my $tab_file = win_path(@tabcsv_files[@$tabsel[0]]);
            #update_text_box(\$tab_file_text, $tab_file);
            update_text_box(\$tab_file_size, (-s $tab_file)." kB");
            my $mod_time;
            if (-e $cwd."/".$tab_file) {$mod_time = gmtime(@{stat $cwd."/".$tab_file}[9])};
            update_text_box(\$tab_file_mod, $mod_time);
            my $note = $table_note{$tab_loc};
            $note =~ s/\n/ /g;
            update_text_box(\$tab_file_note, $note);
        }
      )->grid(-column => 1, -columnspan=>6, -row => 2, -rowspan=>3, -sticky=>'nswe', -ipady=>0);
    $help->attach($tab_hlist, -msg => "Data files\n*\\ = in alternate directory");
    my @tab_menu_enabled = qw(normal normal normal normal disabled normal normal disabled normal);
    bind_tab_menu(\@tab_menu_enabled);
  }
  our $show_data="tab";
  if ($os =~ m/MSWin/i) {
    our @tab_button_widths = qw/3 3 5 3 3/;
  } else {
    our @tab_button_widths = qw/2 2 3 1 1/;
  }
  $b=1;
  $show_tab_button = $tab_frame-> Button(-text=>'TAB',-width=>@tab_button_widths[0],-background=>$abutton,-font=>$font_normal,-activebackground=>$abutton,-border=>$bbw, -command=>sub{
    our $show_data="tab";
    configure_tab_buttons($show_data);
    tab_dir($cwd);
    populate_tab_hlist($tab_hlist);
    my @tab_menu_enabled = qw(normal normal normal normal disabled normal normal disabled normal);
    bind_tab_menu(\@tab_menu_enabled);
  })-> grid(-row=>1,-column=>$b, -sticky => 'nswe', -ipady=>0);
  $b++;
  $help->attach($show_tab_button, -msg => "Show .".$setting{ext_tab}." files");
  $show_csv_button = $tab_frame -> Button(-text=>'CSV', -width=>@tab_button_widths[1],-background=>$button, -font=>$font_normal,-activebackground=>$abutton,-border=>$bbw, -command=>sub{
    our $show_data="csv";
    configure_tab_buttons($show_data);
    tab_dir($cwd);
    populate_tab_hlist($tab_hlist);
    my @tab_menu_enabled = qw(normal normal normal normal normal normal normal disabled normal);
    bind_tab_menu(\@tab_menu_enabled);
  })-> grid(-row=>1,-column=>$b, -sticky => 'nswe', -ipady=>0);
  $b++;
  $help->attach($show_csv_button, -msg => "Show .CSV files");
  $show_xpose_button = $tab_frame -> Button(-text=>'Xpose',-width=>@tab_button_widths[2],-background=>$button,-font=>$font_normal,-activebackground=>$abutton,-border=>$bbw, -command=>sub{
    our $show_data="xpose";
    configure_tab_buttons($show_data);
    tab_dir($cwd);
    populate_tab_hlist($tab_hlist);
    my @tab_menu_enabled = qw(disabled disabled disabled normal disabled disabled disabled normal normal);
    bind_tab_menu(\@tab_menu_enabled);
  })-> grid(-row=>1,-column=>$b, -columnspan=>2, -ipady=>0, -sticky => 'nswe');
  $help->attach($show_xpose_button, -msg => "Show XPose data");
  $b = $b+2;
  $show_r_button = $tab_frame -> Button(-text=>'R',-width=>@tab_button_widths[3],-background=>$button,-font=>$font_normal,-activebackground=>$abutton,-border=>$bbw, -command=>sub{
    our $show_data="R";
    configure_tab_buttons($show_data);
    tab_dir($cwd);
    populate_tab_hlist($tab_hlist);
    my @tab_menu_enabled = qw(disabled normal disabled normal disabled normal disabled disabled normal);
    bind_tab_menu(\@tab_menu_enabled);
  })-> grid(-row=>1,-column=>$b, -columnspan=>1, -ipady=>0, -sticky => 'nswe');
  $help->attach($show_r_button, -msg => "Show R/S scripts");
  $b++;
  $show_all_button = $tab_frame -> Button(-text=>'*',-width=>@tab_button_widths[4],-background=>$button,-activebackground=>$abutton,-border=>$bbw, -command=>sub{
    our $show_data="*";
    configure_tab_buttons($show_data);
    tab_dir($cwd);
    populate_tab_hlist($tab_hlist);
    my @tab_menu_enabled = qw(disabled normal disabled normal disabled disabled disabled disabled normal);
    bind_tab_menu(\@tab_menu_enabled);
  })-> grid(-row=>1,-column=>$b, -ipady=>0, -sticky => 'nswe');
  $b++;
  $help->attach($show_all_button, -msg => "Show all files in folder");

  $tab_frame_info = $model_overview_frame -> Frame(-background=>$bgcol)->grid(-row=>4, -column=>10, -rowspan=>1, -columnspan=>1, -ipady=>3,-sticky=>"nw");
  #$tab_frame_info -> Label(-text=>"  File:", -font=>$font_normal, -background=>$bgcol)-> grid(-row=>1, -column=>1, -sticky=>"nw");
  $tab_frame_info -> Label(-text=>"  Size:", -font=>$font_normal, -background=>$bgcol)-> grid(-row=>1, -column=>1, -sticky=>"nw");
  $tab_frame_info -> Label(-text=>"  Crtd:", -font=>$font_normal, -background=>$bgcol)-> grid(-row=>2, -column=>1, -sticky=>"nw");
  $tab_frame_info -> Label(-text=>"  Note:", -font=>$font_normal, -background=>$bgcol)-> grid(-row=>3, -column=>1, -sticky=>"nw");
  #our $tab_file_text = $tab_frame_info -> Text (
  #    -width=>17, -relief=>'sunken', -border=>0, -height=>1,
  #    -font=>$font_small, -background=>"#f6f6e6", -state=>'normal'
  #)->grid(-column=>2, -row=>1,-sticky=>'nw', -ipadx=>0);
  our $tab_file_size = $tab_frame_info -> Text (
      -width=>17, -relief=>'sunken', -border=>0, -height=>1,
      -font=>$font_small, -background=>"#f6f6e6", -state=>'disabled'
  )->grid(-column=>2, -row=>1,-sticky=>'nw', -ipadx=>0);
  our $tab_file_mod = $tab_frame_info -> Text (
      -width=>17, -relief=>'sunken', -border=>0, -height=>1,
      -font=>$font_small, -background=>"#f6f6e6", -state=>'disabled'
  )->grid(-column=>2, -row=>2,-sticky=>'nw', -ipadx=>0);
  our $tab_file_note = $tab_frame_info -> Text (
      -width=>17, -relief=>'sunken', -border=>0, -height=>1,
      -font=>$font_small, -background=>"#f6f6e6", -state=>'disabled'
  )->grid(-column=>2, -row=>3,-sticky=>'nw', -ipadx=>0);

  $show_ofv=0;
  $show_successful=0;
  $show_covar=0;

  show_links();
  }
}

sub bind_tab_menu {
  my $tab_menu_enabled_ref = shift;
  my @tab_menu_enabled = @$tab_menu_enabled_ref;
  our $tab_menu = $tab_hlist -> Menu(-tearoff => 0,-title=>'None', -background=>$bgcol, -menuitems=> [
        [Button => " Explore dataset / plot variables", -background=>$bgcol,-font=>$font_normal,  -image=>$gif{plots}, -compound=>"left", -state=>@tab_menu_enabled[6], -command => sub{
           my $tabsel = $tab_hlist -> selectionGet ();
           my $tab_file = unix_path(@tabcsv_loc[@$tabsel[0]]);
           if (-e $tab_file) {
             unless($show_data eq "xpose") {create_plot_window($mw, $tab_file, $show_data, $software{r_dir}, \$gif{r_in}, \$gif{close} );}
           }
        }],
       [Button => " Open file in spreadsheet", -background=>$bgcol, -font=>$font_normal, -image=>$gif{spreadsheet},-compound=>"left", -state=>@tab_menu_enabled[0],-command => sub{
         if (-e $software{spreadsheet}) {
	     my $tabsel = $tab_hlist -> selectionGet ();
	     my $tab_file = unix_path(@tabcsv_loc[@$tabsel[0]]);
	     if ($^O =~ m/MSWin/i) {
		 $tab_file = win_path(@tabcsv_loc[@$tabsel[0]]);
	     }
	     if (($tab_file =~ m/.$setting{ext_tab}/i)&&($software{spreadsheet} =~ m/excel/i)) {  # Excel is not able to read the table files correctly
		 tab2csv ($tab_file, $tab_file."_pirana.".$setting{ext_csv});
		 start_command($software{spreadsheet},'"'.$tab_file.'_pirana.'.$setting{ext_csv}.'"');
	     } else {
		 start_command($software{spreadsheet},'"'.$tab_file.'"'); 
	     }
         } else {message("Spreadsheet application not found. Please check settings.")};
       }],
       [Button => " Open file in code editor",  -background=>$bgcol,-font=>$font_normal, -image=>$gif{notepad},-compound=>"left", -state=>@tab_menu_enabled[1], -command => sub{
	   my $tabsel = $tab_hlist -> selectionGet ();
	   my $tab_file = unix_path(@tabcsv_loc[@$tabsel[0]]);
	   if ($^O =~ m/MSWin/i) {
	       $tab_file = win_path(@tabcsv_loc[@$tabsel[0]]);
	   }
	   edit_model(unix_path(win_path($tab_file)));
       }],
       [Button => " Convert CSV <--> TAB",  -background=>$bgcol,-font=>$font_normal, -image=>$gif{convert},-compound=>"left", -state=>@tab_menu_enabled[2],-command => sub{
	   my $tabsel = $tab_hlist -> selectionGet ();
	   my $tab_file = unix_path(@tabcsv_loc[@$tabsel[0]]);
	   if ($^O =~ m/MSWin/i) {
	       $tab_file = win_path(@tabcsv_loc[@$tabsel[0]]);
	   }
	   csv_tab_window ($tab_file);
       }],
       [Button => " Delete file",  -background=>$bgcol,-font=>$font_normal, -image=>$gif{trash},-compound=>"left", -state=>@tab_menu_enabled[3], -command => sub{
	   my $tabsel = $tab_hlist -> selectionGet ();
	   my $tab_file = unix_path(@tabcsv_loc[@$tabsel[0]]);
	   if ($^O =~ m/MSWin/i) {
	       $tab_file = win_path(@tabcsv_loc[@$tabsel[0]]);
	   }
	   my $delete = message_yesno ( "Do you really want to delete ".$tab_file."?", $mw, $bgcol, $font_normal);
	   if( $delete ==1 ) {unless(unlink (unix_path($cwd."/".$tab_file))) {message("For some reason, ".$tab_file." could not be deleted.\nCheck file/folder permissions.")} else {refresh_pirana($cwd, $filter,1)} };
       }],
       [Button => " Check dataset", -background=>$bgcol, -font=>$font_normal, -image=>$gif{check},-compound=>"left", -state=>@tab_menu_enabled[4], -command => sub{
	   my $tabsel = $tab_hlist -> selectionGet ();
	   my $tab_file = unix_path(@tabcsv_loc[@$tabsel[0]]);
	   my $html = check_out_dataset($tab_file);
	   start_command ($software{browser}, '"file:///'.unix_path($cwd).'/'.$html.'"');
        }],
       [Button => " Load in PiranaR", -background=>$bgcol,-font=>$font_normal,  -image=>$gif{pirana_r},-compound=>"left", -state=>@tab_menu_enabled[5], -command => sub{
	   my $scriptsel = $tab_hlist -> selectionGet ();
	   my $script_file = unix_path(@tabcsv_loc[@$scriptsel[0]]);
	   if (-e $script_file) {
	       if ($show_data eq "R") {
#		   open ()
	       }
	       if ($show_data eq "csv") {
		   my $script = "library(utils)\n".
				"csv <- data.frame(read.csv (file='".unix_path($cwd."/".$script_file)."'))\n";
		   $script .= "head(tab)\n";
		   create_window_piranaR ($mw, $script, 1, "temp");
	       }
	       if ($show_data eq "tab") {
		   open (DATA, "<".$script_file);
		   my @dat = <DATA>;
		   close DATA;
		   my $script = "library(utils)\n";
		   if (@dat[0] =~ m/TABLE.NO/) {
		       $script .= "tab <- data.frame(read.table (file='".unix_path($script_file)."', skip=1, header=T))\n";
		   } else {
		       $script .= "tab <- data.frame(read.table (file='".unix_path($script_file)."', skip=0, header=F))\n";
		   };
		   $script .= "head(tab)\n";
		   create_window_piranaR ($mw, $script, 1);
	       }
	   }
        }],
        [Button => " Open Xpose dataset", -background=>$bgcol,-font=>$font_normal,  -image=>$gif{xpose},-compound=>"left", -state=>@tab_menu_enabled[7], -command => sub{
	    if (-e $software{r_dir}."/bin/rgui.exe") {
		chdir($cwd);
		$model = "";
		if (@tabcsv_files[$tab_hlist -> selectionGet()] ne "") {
		    my $tabsel = $tab_hlist -> selectionGet ();
		    my $tab_file = unix_path(@tabcsv_files[@$tabsel[0]]);
		    $model = $tab_file;
		}
		if (($model ne "")&&($show_data eq "xpose")) {
		    copy ($base_dir."/internal/xpose.Rprofile", $cwd."/.Rprofile");
		    open (RPROF,"<.Rprofile");
		    @lines = <RPROF>;
		    close (RPROF);
		    unshift (@lines, 'new.runno <- "'.$model.'"'."\n");
		    open (RPROF,">.Rprofile");
		    print RPROF @lines;
		    close (RPROF);
		    start_command(win_path($software{r_dir}.'/bin/rgui.exe'));
		} else {message ("Select an Xpose dataset to load Xpose.")};
	    } else {message ("R was not found. Please check software settings.")};
        }],
        [Button => " Show/edit table or file info", -background=>$bgcol, -font=>$font_normal, -image=>$gif{edit_info_green},-compound=>"left", -state=>@tab_menu_enabled[8],-command => sub{
	    my $tabsel = $tab_hlist -> selectionGet ();
	    my $tab_file = unix_path(@tabcsv_files[@$tabsel[0]]);
	    if (-e $tab_file) {
		table_info_window($tab_file);
	    }
        }],

    ]);
    $tab_menu -> separator ( -background=>$bgcol) ;
    $tab_menu -> command (-label=> " Close this menu",  -image=>$gif{close}, -compound=>'left', -background=>$bgcol, -command => sub{
       $tab_menu -> unpost();
    });
    $tab_hlist -> bind("<Button-3>" => [ sub {
       $tab_hlist -> focus; # focus on listbox widget
       my($w, $x, $y) = @_;
       our $tabsel = $tab_hlist -> selectionGet ();
       if (@$tabsel >0) { $tab_menu -> post($x, $y) } else {
         message("Please select a file first...");
       }
    }, Ev('X'), Ev('Y') ] );
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
  if ($tab_frame) {
  my $links_height = 24;
  our $frame_links = $frame_dir -> Frame(-background=>$bgcol) ->grid(-row=>2,-column=>14, -columnspan=>3, -ipadx=>'0',-ipady=>'0',-sticky=>'wn');
  our $missing=0;

  $frame_dir -> Label(-text=>'    Cmd:', -font=>$font_normal, -background=>$bgcol)->grid(-row=>1, -column=>12, -sticky => 'ens');
  $frame_dir -> Label(-text=>'  Start:', -font=>$font_normal, -background=>$bgcol)->grid(-row=>2, -column=>12, -sticky => 'ens');
  if ($os =~ m/MSWin/i) {
    $frame_dir -> Label(-text=>'', -font=>'Arial 1', -width=>40, -background=>$bgcol)->grid(-row=>1, -column=>15, -sticky => 'ens');
  }
  our $frame_logo = $mw -> Frame(-background=>$bgcol)-> grid(-row=>0, -column=>1, -columnspan=>2, -sticky=>"ne", -ipadx=>10);
  our $pirana_logo = $frame_logo -> Label (-border=>0,-text=>"Pirana\nv".$version, -justify=>"right", -background=>$bgcol, -font=>$font_normal, -state=>"disabled"
    )->grid(-row=>2, -column=>1, -columnspan=>2,-rowspan=>1, -sticky => 'en');

  # NM help box
  $frame_logo -> Label(-text=>"NM help:", -font=>$font_normal, -background=>$bgcol)->grid (-row=>1,-column=>1, -sticky=>'ew');
  our $nm_help_entry = $frame_logo -> Entry(-width=>12,-textvariable=>\$nm_help_search, -background=>$white,-border=>2, -relief=>'groove' )
    -> grid(-row=>1,-column=>2,-columnspan=>1, -sticky => 'we',-ipadx=>1);
  my @nm = values (%nm_dirs);
  unless (@nm > 0) {
      $nm_help_entry -> configure(-state=>'disabled');
  }
  $nm_help_entry -> bind('<Any-KeyPress>' => sub {
     if (length($nm_help_search)>0) {
	 our $nm_box_on = 1;
	 print $nm_help_search;
	 $filtered_keywords_ref = nm_help_filter_keywords ($nm_help_search, \@nm_help_keywords);
	 my @filtered_keywords = @$filtered_keywords_ref;
	 unless ($text_window_keywords) {
	     text_window_nm_help ( \@filtered_keywords, "NONMEM help files");
	     $keywords_list -> delete(0,"end");
	     $keywords_list -> insert(0, @filtered_keywords);
	 } else {
	     $keywords_list -> delete(0,"end");
	     $keywords_list -> insert(0, @filtered_keywords);
         }
     } else {
	 if ($text_window_keywords) {
	     $text_window_keywords -> destroy();
	     undef($text_window_keywords); undef $text_window_keywords_frame;
	 }
     }
     $nm_help_entry -> focus();
     $mw -> raise();
     $mw -> update();
     ;
  });


  $i=1;
  $software{tty} =~ m/\.exe/i;
  my $pos = length $`;
  if (-e $software{calc}) {
    our $calc_button = $frame_links -> Button(-image=>$gif{calc}, -border=>$bbw,-width=>20,-height=>$links_height, -border=>$bbw,-background=>$button,-activebackground=>$abutton,-command=> sub{
    start_command($software{calc});
    })->grid(-row=>1,-column=>$i,-sticky=>'news');
    $i++;
    $help->attach($calc_button, -msg => "Open system calculator");
  }
#  if (-e substr($software{tty}, 0, $pos+4)) {
    our $putty_button = $frame_links -> Button(-image=>$gif{putty},-border=>$bbw, -width=>20,-height=>$links_height, -border=>$bbw,-background=>$button,-activebackground=>$abutton,-command=> sub{
      start_command(substr($software{tty}, 0, $pos+4), substr($software{tty},$pos+5, length($software{tty})-($pos+4)));
    }) ->grid(-row=>1,-column=>$i,-sticky=>'news');
    $help->attach($putty_button, -msg => $software_descr{tty});
    $i++;
#  }
  if (-e $software{r_dir}."/bin/rgui.exe") {
    our $r_button = $frame_links -> Button(-image=>$gif{r}, -width=>20, -height=>$links_height, -border=>$bbw, -background=>$button,-activebackground=>$abutton,-command=> sub{
    chdir ($cwd);
    start_command($software{r_dir}.'/bin/rgui.exe', '--no-init-file');
    })->grid(-row=>1,-column=>$i,-sticky=>'news');
    $help->attach($r_button, -msg => "Open the R-GUI");
    $i++;
  }
  if (-e $software{splus}) {
    $splus_button = $frame_links -> Button(-image=>$gif{splus}, -width=>20, -height=>$links_height, -border=>$bbw, -background=>$button,-activebackground=>$abutton,-command=> sub{
    chdir ($cwd);
    start_command($software{splus});
    })->grid(-row=>1,-column=>$i,-sticky=>'news');
    $i++;
    $help->attach($splus_button, -msg => "Open S-Plus");
  }
  if (-e $software{sas}) {
    $sas_button = $frame_links -> Button(-image=>$gif{sas}, -width=>20, -height=>$links_height, -border=>$bbw, -background=>$button,-activebackground=>$abutton,-command=> sub{
    chdir ($cwd);
    start_command($software{sas});
    })->grid(-row=>1,-column=>$i,-sticky=>'news');
    $i++;
    $help->attach($sas_button, -msg => "Open SAS");
  }
  if (-e $software{spreadsheet}) {
    our $spreadsheet_button = $frame_links -> Button(-image=>$gif{spreadsheet},-border=>$bbw, -width=>20,-height=>$links_height, -border=>$bbw, -background=>$button,-activebackground=>$abutton,-command=> sub{
    start_command($software{spreadsheet});
    })->grid(-row=>1,-column=>$i,-sticky=>'news');
    $i++;
    $help->attach($spreadsheet_button, -msg => "Open spreadsheet application");
  }
  if (-e $software{editor}) {
    our $notepad_button = $frame_links -> Button(-image=>$gif{notepad},-border=>$bbw, -width=>20,-height=>$links_height, -border=>$bbw,-background=>$button,-activebackground=>$abutton,-command=> sub{
    start_command($software{editor});
    }) ->grid(-row=>1,-column=>$i,-sticky=>'news');
    $help->attach($notepad_button, -msg => "Open text-editor");
    $i++;
  }
  if (-e $software{madonna}) {
    $madonna_button = $frame_links -> Button(-image=>$gif{madonna}, -height=>$links_height, -border=>$bbw, -background=>$button,-activebackground=>$abutton,-command=> sub{
      start_command($software{madonna});
    })->grid(-row=>1,-column=>$i,-sticky=>'news');
    $help->attach($madonna_button, -msg => "Start Berkeley Madonna");
    $i++;
  }
  if (-e $software{extra1}) {
    our $extra1_button = $frame_links -> Button(-image=>$gif{extra1},-border=>$bbw, -width=>20,-height=>$links_height, -border=>$bbw,-background=>$button,-activebackground=>$abutton,-command=> sub{
    start_command($software{extra1});
    }) ->grid(-row=>1,-column=>$i,-sticky=>'news');
    $help->attach($extra1_button, -msg => $software_descr{extra1});
    $i++;
  }
  if (-e $software{extra2}) {
    our $extra2_button = $frame_links -> Button(-image=>$gif{extra2},-border=>$bbw, -width=>20,-height=>$links_height, -border=>$bbw,-background=>$button,-activebackground=>$abutton,-command=> sub{
    start_command($software{extra2});
    }) ->grid(-row=>1,-column=>$i,-sticky=>'news');
    $help->attach($extra2_button, -msg => $software_descr{extra2});
    $i++;
  }

  #$frame_links -> Label(-text=>"Command: ",-font => $font_normal)
  #  ->grid(-row=>2,-column=>1,-sticky=>'nse');
  $command_entry = $frame_dir -> Entry(-textvariable=>\$run_command, -border=>2, -relief=>'groove',-font => $font_normal,-background=>$white)
   ->grid(-row=>1,-columnspan=>1,-column=>14,-sticky=>'we');  #i-3
  if (($cluster_active==1)&&($setting{cluster_type}!=0)) {$gif_shell=$gif{shell_linux}} else {$gif_shell=$gif{shell}};
  $command_button = $frame_dir -> Button(-image=> $gif_shell,-border=>$bbw,-background=>$button,-activebackground=>$abutton, -command=> sub{
        run_command($command_entry -> get())
  })->grid(-row=>1,-columnspan=>1,-column=>15,-sticky=>'w'); # i-1
  $command_entry->bind("<Return>", sub {
     unless(($command_entry -> get()) eq "") {
        run_command($command_entry -> get())
     }
  });
 if ($os =~ m/MSWin/i) {
   $help -> attach($command_button, -msg => "Run command in a command-console");
 } else {
   $help -> attach($command_button, -msg => "Run command in a command-shell");
 }
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
  $old=@_[0];
  $success=0;
  $last_char=substr($old,-1,1);
  $num = ord($last_char);
  if ($num>47 && $num<59) { # numeric
    $suffix="A";
    $new=$old.$suffix;
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
    @header_widths[$x] = $models_hlist->columnWidth($x);
    $x++;
  }
  $new_header_widths = join (";",@header_widths);
  if ($setting{header_widths} ne $new_header_widths) {
    $setting{header_widths} = join (";",@header_widths);
    save_ini ($home_dir."/ini/settings.ini", \%setting, \%setting_descr);
  }
}

sub nmfe_run_window {
### Purpose : Create dialog window for running a model
### Compat  : W+L+
    # get basic information on models and build command
    my @runs = $models_hlist -> selectionGet ();
    my @files = @ctl_show[@runs];
    my $file_string = join (', ',@files);
    my %nm_dirs_run = %$nm_dirs_ref;
    my %nm_vers_run = %$nm_vers_ref;
    my @nm_installations = keys(%nm_dirs_run);
    unless (%clusters) {
	our %clusters;
	$clusters{sge_priority} = 0;
	$clusters{sge_submit_command} = $setting{sge_command};
	$clusters{sge_parameters} = $setting{sge_parameters};
	$clusters{sge_model_as_jobname} = $setting{sge_model_as_jobname};
	$clusters{run_on_sge} = 0;
	$clusters{run_on_pcluster} = 0;
    }
    unless (%ssh) {
	our %ssh ;
	$ssh{connect_ssh} = 0;
	$ssh{command} = "ssh";
	$ssh{login} = $setting{ssh_login};
	$ssh{parameters} = $setting{ssh_parameters};
	$ssh{remote_folder} = $setting{ssh_cluster_mount};
	$ssh{local_folder} = $setting{ssh_local_mount};
    }

    # build dialog window
    my $run_in_new_dir = 0;
    my $title = 'Run model using nmfe ' ;
    my $nmfe_run_window = $mw -> Toplevel(-title=>$title);
    center_window($nmfe_run_window);
    $nmfe_run_window -> OnDestroy ( sub{
	undef $unmfe_run_window; undef $nmfe_run_frame;
    });

    # Already create new folder names and script file name
    my $ext = "sh";
    if ($^O =~ m/MSWin/i) {
	$ext = "bat";
    }
    my $script_file = "pirana_start_".generate_random_string(4).".".$ext;
    my @new_dirs;
    foreach my $model (@files) {
	my $new_dir = "nmfe_".$model."_".generate_random_string(5);
	push (@new_dirs, $new_dir);
    }

    # build notebook
    my $nmfe_frame = $nmfe_run_window -> Frame (-background=>$bgcol)-> grid(-ipadx=>8, -ipady=>8);
    my $nmfe_notebook = $nmfe_frame ->NoteBook(-tabpadx=>5, -font=>$font, -border=>1, -backpagecolor=>$bgcol,-inactivebackground=>$bgcol, -background=>'#FFFFFF') -> grid(-row=>1, -column=>1, -columnspan=>4,-ipadx=>10, -ipady=>10, -sticky=>"nw");
    my $nmfe_run_frame = $nmfe_notebook -> add("general", -label=>"General");
    my $nmfe_sge_frame = $nmfe_notebook -> add("sge", -label=>"Clusters");
    my $nmfe_ssh_frame = $nmfe_notebook -> add("ssh", -label=>"SSH");

    my $command_area_scrollbar = $nmfe_run_frame -> Scrollbar() -> grid (-column=>3,-row=>15,-sticky=>'nws');
    my $command_area = $nmfe_run_frame -> Text (
      -width=>60, -height=>5, -yscrollcommand => ['set' => $command_area_scrollbar],
      -background=>"#FFFFFF", -exportselection => 0, -wrap=>'none',
      -border=>1, -font=>$font_normal, -relief=>'groove',
      -selectbackground=>'#606060', -highlightthickness =>0
    ) -> grid(-row=>15,-column=>2,-sticky=>"nwe");
    $command_area_scrollbar -> configure(-command => ['yview' => $command_area]);
    my $nm_versions_menu = $nmfe_run_frame -> Optionmenu(-options=>[],
      -variable => \$nm_version_chosen,
      -border=>$bbw,
      -background=>$run_color,-activebackground=>$arun_color,
      -font=>$font_normal, -background=>"#c0c0c0",
      -activebackground=>"#a0a0a0", -command=> sub{
        if (-e unix_path($nm_dirs{$nm_version_chosen}."/test/runtest.pl")) {
          $run_method_nm_type="NMQual";
        } else {$run_method_nm_type="nmfe"};
	update_nmfe_run_script_area ($command_area, $script_file, \@files, $nm_version_chosen, $method_chosen, $run_in_new_dir, \@new_dirs, $run_in_background, \%clusters, \%ssh, $nm_versions_menu);
    }) -> grid(-row=>3,-column=>2,-sticky => 'wns');

    $nmfe_run_frame -> Label (-text=>"Model file(s):", -font=>$font_normal,-background=>$bgcol) -> grid(-row=>1,-column=>1,-sticky=>"e");
    $nmfe_run_frame -> Label (-text=>$file_string, -font=>$font_normal,-background=>$bgcol) -> grid(-row=>1,-column=>2,-sticky=>"w");

    $nmfe_run_frame -> Label (-text=>"Run directory:",-font=>$font_normal, -background=>$bgcol) -> grid(-row=>4,-column=>1,-sticky=>"e");
    my $dir = $cwd;
    my $run_directory = $nmfe_run_frame -> Entry (-textvariable=>\$dir, -font=>$font_normal,-background=>$white, -state=>'disabled', -width=>50) -> grid(-row=>4,-column=>2,-sticky=>"w");
    if ($clusters{run_on_sge} == 1) {
         $run_in_new_dir = 1;
    }
    $nmfe_run_frame -> Checkbutton (-text=>"Run in separate folder(s)", -selectcolor=>$selectcol, -activebackground=>$bgcol, -variable=>\$run_in_new_dir, -font=>$font_normal,  -selectcolor=>$selectcol, -activebackground=>$bgcol, -command=> sub{
	update_nmfe_run_script_area ($command_area, $script_file,\@files, $nm_version_chosen, $method_chosen, $run_in_new_dir, \@new_dirs, $run_in_background, \%clusters, \%ssh, $nm_versions_menu);
    }) -> grid(-row=>5,-column=>2,-sticky=>"w");

    ### Run command and start script
    $nmfe_run_frame -> Label (-text=>"Script contents:\n", -font=>$font_normal, -background=>$bgcol
    ) -> grid(-row=>15,-column=>1,-sticky=>"ne");
    (my $script_file, our $nmfe_run_command, my $script_ref) = build_nmfe_run_command ($script_file, \@files, $nm_version_chosen, $method_chosen, $run_in_new_dir, \@new_dirs, $run_in_background, \%clusters);
    my $nmfe_run_script = $nmfe_run_frame -> Entry (-textvariable=> \$nmfe_run_command,
       -background=>'#ffffff', -width=>32, -border=>1, -relief=>'groove', -font=>$font_normal
    ) -> grid(-row=>13,-column=>2,-sticky=>"nwe");
    $nmfe_run_frame -> Label (-text=>"Start script:", -font=>$font_normal, -background=>$bgcol
    ) -> grid(-row=>13,-column=>1,-sticky=>"ne");

    $nmfe_run_frame -> Checkbutton (-text=>"Run in background",-font=>$font_normal,  -selectcolor=>$selectcol, -activebackground=>$bgcol, -variable=>\$run_in_background,  -selectcolor=>$selectcol, -activebackground=>$bgcol, -command=> sub{
	 my ($script_file, $run_command, $script_ref) = build_nmfe_run_command ($script_file, \@files, $nm_version_chosen, $method_chosen, $run_in_new_dir, \@new_dirs, $run_in_background, \%clusters, \%ssh);
	 $nmfe_run_command = $run_command;
    }) -> grid(-row=>6,-column=>2,-sticky=>"w");

    $nmfe_run_frame -> Label (-text=>"NB. If runs are started in the background, execution will continue\nwhen Pirana is closed, or when logging out from a cluster.",
			    -font=>$font_normal, -background=>$bgcol, -justify=>"left") -> grid(-row=>7,-column=>2,-sticky=>"w");
    $nmfe_run_frame -> Label (-text=>" ",-font=>$font_normal, -background=>$bgcol) -> grid(-row=>8,-column=>1,-sticky=>"w");

    # NM installations
    $nmfe_run_frame -> Label (-text=>"NONMEM installation:", -font=>$font_normal, -background=>$bgcol
	) -> grid(-row=>3,-column=>1,-sticky=>"e");
    delete $nm_dirs{""};
    my $nm_dirs_ref; my $nm_vers_ref ;
    my @nm_installations;
    unless ($ssh{connect_ssh} == 0) {
	@nm_installations = keys(%nm_dirs);
    } else {
	@nm_installations = keys(%nm_dirs_cluster);
    }
    if ($nm_versions_menu) { $nm_versions_menu -> configure (-options => [@nm_installations] )} ;

    my @params = ($command_area, $script_file, \@files, $nm_version_chosen, $method_chosen, $run_in_new_dir, \@new_dirs, $run_in_background, \%clusters, \%ssh, $nm_versions_menu);
    ssh_notebook_tab ($nmfe_ssh_frame, 1, \@params);

    ### SGE options
#    $nmfe_sge_frame -> Label (-text=>"Submit to SGE", -font=>$font_normal, -background=>$bgcol
#    ) -> grid(-row=>1,-column=>1,-sticky=>"ne");
    $nmfe_sge_frame -> Label (-text=>"Submit command", -font=> $font_normal, -background=>$bgcol
    ) -> grid(-row=>2,-column=>1,-sticky=>"ne");
    my $sge_submit_entry = $nmfe_sge_frame -> Entry (-border=>1, -relief=>'groove',-textvariable=> \$clusters{sge_submit_command}, -width=>10, -font=>$font_normal, -background=>"#FFFFFF"
    ) -> grid(-row=>2,-column=>2,-sticky=>"nw");
    $sge_submit_entry -> bind('<Any-KeyPress>' => sub { bind_update_nmfe_run_script ($command_area, $script_file, \@files, $nm_version_chosen, $method_chosen, $run_in_new_dir, \@new_dirs, $run_in_background, \%clusters, \%ssh, $nm_versions_menu); });

    $nmfe_sge_frame -> Label (-text=>"Run priority", -font=> $font_normal, -background=>$bgcol
    ) -> grid(-row=>3,-column=>1,-sticky=>"ne");
    my $sge_priority_entry = $nmfe_sge_frame -> Entry (-border=>1, -relief=>'groove',-textvariable=> \$clusters{sge_priority}, -width=>4, -font=>$font_normal, -background=>"#FFFFFF"
    ) -> grid(-row=>3,-column=>2,-sticky=>"nw");
    $sge_priority_entry -> bind('<Any-KeyPress>' => sub { bind_update_nmfe_run_script ($command_area, $script_file,\@files, $nm_version_chosen, $method_chosen,$run_in_new_dir, \@new_dirs, $run_in_background, \%clusters, \%ssh, $nm_versions_menu); });

    $nmfe_sge_frame -> Label (-text=>"Additional parameters", -font=>$font_normal, -background=>$bgcol
    ) -> grid(-row=>4,-column=>1,-sticky=>"ne");
    my $sge_parameters_entry = $nmfe_sge_frame -> Entry (-border=>1, -relief=>'groove',-textvariable=> \$clusters{sge_parameters}, -width=>20, -font=>$font_normal, -background=>"#FFFFFF"
    ) -> grid(-row=>4,-column=>2,-sticky=>"nw");
    $sge_parameters_entry -> bind('<Any-KeyPress>' => sub { bind_update_nmfe_run_script ($command_area, $script_file, \@files, $nm_version_chosen, $method_chosen, $run_in_new_dir, \@new_dirs, $run_in_background, \%clusters, \%ssh, $nm_versions_menu); });

    $nmfe_sge_frame -> Label (-text=>"\n\n", -font=>$font_normal, -background=>$bgcol
    ) -> grid(-row=>5,-column=>1,-sticky=>"nw");
    $nmfe_sge_frame -> Label (-text=>"Use project/model-name as job-name", -font=>$font_normal, -background=>$bgcol
    ) -> grid(-row=>5,-column=>1,-sticky=>"ne");
    $nmfe_sge_frame -> Checkbutton (-text=>"", -variable=> \$clusters{sge_model_as_jobname}, -font=>$font_normal, -background=>$bgcol, -selectcolor=>$selectcol, -activebackground=>$bgcol, -command=>sub{
	update_nmfe_run_script_area ($command_area, $script_file, \@files, $nm_version_chosen, $method_chosen, $run_in_new_dir, \@new_dirs, $run_in_background, \%clusters, \%SSH, $nm_versions_menu );
    }) -> grid(-row=>5,-column=>2,-sticky=>"nw");

    $nmfe_run_frame -> Label (-text=>"Submit to:", -font=>$font_normal, -background=>$bgcol
    ) -> grid(-row=>10,-column=>1,-sticky=>"ne");
    $nmfe_run_frame -> Checkbutton (-text=>"Sun Grid Engine", -variable=> \$clusters{run_on_sge}, -font=>$font_normal,  -selectcolor=>$selectcol, -activebackground=>$bgcol,  -command=>sub{
	if ($clusters{run_on_sge} == 1) {
	    $run_in_new_dir = 1;
	    $clusters{run_on_pcluster} = 0;
	    $nmfe_run_script -> configure (-state=>'normal');
	}
	update_nmfe_run_script_area ($command_area, $script_file, \@files, $nm_version_chosen, $method_chosen, $run_in_new_dir, \@new_dirs, $run_in_background, \%clusters, \%ssh, $nm_versions_menu );
    }) -> grid(-row=>10,-column=>2,-sticky=>"nw");
    $nmfe_run_frame -> Checkbutton (-text=>"PCluster", -variable=> \$clusters{run_on_pcluster}, -font=>$font_normal,  -selectcolor=>$selectcol, -activebackground=>$bgcol, -command=>sub{
	if ($clusters{run_on_pcluster} == 1) {
	    $clusters{run_on_sge} = 0;
	    $nmfe_run_script -> configure (-state=>'disabled');
	} else {
	    $nmfe_run_script -> configure (-state=>'normal');
	}
	update_nmfe_run_script_area ($command_area, $script_file, \@files, $nm_version_chosen, $method_chosen, $run_in_new_dir, \@new_dirs, $run_in_background, \%clusters, \%ssh, $nm_versions_menu );
    }) -> grid(-row=>11,-column=>2,-sticky=>"nw");

    $nmfe_run_frame -> Label (-text=>" ",-font=>$font_normal, -background=>$bgcol) -> grid(-row=>12,-column=>1,-sticky=>"w");
    $nmfe_run_frame -> Label (-text=>" ",-font=>$font_normal, -background=>$bgcol) -> grid(-row=>14,-column=>1,-sticky=>"w");
    $nmfe_run_frame -> Label (-text=>" ",-font=>$font_normal, -background=>$bgcol) -> grid(-row=>16,-column=>1,-sticky=>"w");

    my $nmfe_run_button = $nmfe_run_frame -> Button (-image=> $gif{run}, -background=>$button, -width=>40,-height=>40, -activebackground=>$abutton, -border=>$bbw, -command=> sub {
	unless ($nm_version_chosen eq "") { #NM installed?
	    my $script_text = $command_area -> get("0.0", "end");
	    my ($script_file, $script_text_ref) = create_nm_start_script ($script_file, $nm_version_chosen, os_specific_path($cwd), \@files, $run_in_new_dir, \@new_dirs, \%$clusters, \%ssh);
	    write_nm_start_script ($script_file, \$script_text);
	    if ($run_in_new_dir == 1) {
		foreach my $file (@files) {
		    my $new_dir = shift (@new_dirs);
		    unless ($new_dir eq "") {
			move_nm_files ($file.".".$setting{ext_ctl}, $new_dir) ;
			db_log_execution ($file.".".$setting{ext_ctl}, $models_descr{$file}, "nmfe", $run_method, $nmfe_run_command, $setting{name_researcher});
		    }
		}
	    }
	    if ($clusters{run_on_pcluster} == 1) {
		pcluster_get_available_nodes ();
		exec_run_pcluster($nm_version_chosen, );
	    } else {
		exec_run_nmfe ($nmfe_run_command);
	    }
	    save_ini ($home_dir."/ini/settings.ini", \%setting, \%setting_descr);
	}
#	$help -> detach($nmfe_run_button);
	$nmfe_run_window -> destroy();
    })-> grid(-row=>17, -column=>2,-sticky=>"wns");
    if (keys(%nm_dirs)+keys(%nm_dirs_cluster) == 0) {
	$nmfe_run_button -> configure (-state => "disabled");
    }
#    $help -> attach($nmfe_run_button, "Start run");

    # update
    my ($script_file, $run_command, $script_ref) = build_nmfe_run_command ($script_file, \@files, $nm_version_chosen, $method_chosen, $run_in_new_dir, \@new_dirs, $run_in_background, \%clusters, \%ssh);
    $nmfe_run_command = $run_command;
    update_nmfe_run_script_area ($command_area, $script_file, \@files, $nm_version_chosen, $method_chosen, $run_in_new_dir, \@new_dirs, $run_in_background, \%clusters, \%ssh, $nm_versions_menu);

    $nmfe_run_window -> resizable( 0, 0 );
    $nmfe_run_window -> raise();
    $nmfe_run_window -> update();
}

sub pcluster_select_node_window {


    return ($node_selected);
}

sub ssh_notebook_tab {
    my ($nmfe_ssh_frame, $bind_subroutine, $params_ref) = @_;
    my @params = @$params_ref;

    ### SSH options
    $nmfe_ssh_frame -> Label (-text=>"Note: To enable passwordless access, make sure you have an SSH-keypair installed,\nor supply the SSH password as extra parameter.\n",
       -font=>$font_normal, -background=>$bgcol, -justify=>"left"
    ) -> grid(-row=>0,-column=>1,-columnspan=>2, -sticky=>"ne");

    $nmfe_ssh_frame -> Label (-text=>"Connect to system through SSH", -font=>$font_normal, -background=>$bgcol
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

    if ($bind_subroutine == 1) { # the SSH tab in the nmfe run window
	$ssh_login_entry -> bind('<Any-KeyPress>' => sub { bind_update_nmfe_run_script (@params) });
	$ssh_parameters_entry -> bind('<Any-KeyPress>' => sub { bind_update_nmfe_run_script (@params); });
	$ssh_remote_folder_entry -> bind('<Any-KeyPress>' => sub { bind_update_nmfe_run_script (@params); });
	$ssh_local_folder_entry -> bind('<Any-KeyPress>' => sub { bind_update_nmfe_run_script (@params); });
	$nmfe_connect_ssh_checkbox -> configure (-command => sub {
	    bind_update_nmfe_run_script (@params);
        });
    }
    if ($bind_subroutine == 2) { # the SSH tab in the PsN run window
	$ssh_login_entry -> bind('<Any-KeyPress>' => sub { bind_update_psn_run_script (@params) });
	$ssh_parameters_entry -> bind('<Any-KeyPress>' => sub { bind_update_psn_run_script (@params); });
	$ssh_remote_folder_entry -> bind('<Any-KeyPress>' => sub { bind_update_psn_run_script (@params); });
	$ssh_local_folder_entry -> bind('<Any-KeyPress>' => sub { bind_update_psn_run_script (@params); });
	$nmfe_connect_ssh_checkbox -> configure (-command => sub {
	    bind_update_psn_run_script (@params);
        });
    }
    if ($bind_subroutine == "3") { # the SSH tab in the SGE window
	$ssh_login_entry -> bind('<Any-KeyPress>' => sub { bind_update_psn_run_script (@params) });
	$ssh_parameters_entry -> bind('<Any-KeyPress>' => sub { bind_update_psn_run_script (@params); });
	$ssh_remote_folder_entry -> bind('<Any-KeyPress>' => sub { bind_update_psn_run_script (@params); });
	$ssh_local_folder_entry -> bind('<Any-KeyPress>' => sub { bind_update_psn_run_script (@params); });
	$nmfe_connect_ssh_checkbox -> configure (-command => sub {
	    bind_update_psn_run_script (@params);
        });
    }
    return ();
}

sub bind_update_nmfe_run_script {
    my ($command_area, $script_file, $files_ref, $nm_version_chosen, $method_chosen, $run_in_new_dir, $new_dirs_ref, $run_in_background, $clusters_ref, $ssh_ref, $nm_versions_menu ) = @_;
    my ($script_file, $run_command, $script_ref) = build_nmfe_run_command ($script_file, $files_ref, $nm_version_chosen, $method_chosen, $run_in_new_dir, $new_dirs_ref, $run_in_background, $clusters_ref, $ssh_ref);
    $nmfe_run_command = $run_command;
    update_nmfe_run_script_area ($command_area, $script_file, $files_ref, $nm_version_chosen, $method_chosen, $run_in_new_dir, $new_dirs_ref, $run_in_background, $clusters_ref, $ssh_ref, $nm_versions_menu );
    return();
}
sub bind_update_psn_run_script {
    my ($psn_command_line_entry, $psn_command, $model, $psn_parameters, $clusters_ref, $ssh_ref)  = @_;
    my $psn_command_line = build_psn_run_command ($psn_command, $psn_parameters, $model, $ssh_ref, $cluster_ref);
    update_psn_run_script_area ($psn_command_line_entry, $psn_command_line, $clusters_ref, $ssh_ref );
    return();
}

sub psn_run_window {
  (my $model, my $psn_option) = @_;
  my $modelfile = $model.".".$setting{ext_ctl};
  my $model_description = $models_descr{$model};
  my $psn_parameters = $psn_commands{$psn_option};
  my $run_in_new_dir = 0;
  my $psn_run_window = $mw -> Toplevel(-title=>'PsN Toolkit ('.$psn_option.")");
  center_window($psn_run_window);
  $psn_run_window -> OnDestroy ( sub{
      undef $unmfe_run_window; undef $nmfe_run_frame;
  });

    unless (%ssh) {
	our %ssh ;
	$ssh{connect_ssh} = 0;
	$ssh{command} = "ssh";
	$ssh{login} = $setting{ssh_login};
	$ssh{parameters} = $setting{ssh_parameters};
	$ssh{remote_folder} = $setting{ssh_cluster_mount};
	$ssh{local_folder} = $setting{ssh_local_mount};
    }

  # build notebook
  my $psn_run_frame = $psn_run_window -> Frame (-background=>$bgcol)-> grid(-ipadx=>8, -ipady=>8);
  my $psn_notebook = $psn_run_frame -> NoteBook(-tabpadx=>5, -font=>$font, -border=>1, -backpagecolor=>$bgcol,-inactivebackground=>$bgcol, -background=>'#FFFFFF') -> grid(-row=>1, -column=>1, -columnspan=>4,-ipadx=>10, -ipady=>10, -sticky=>"nw");
  my $psn_run_frame = $psn_notebook -> add("general", -label=>"General");
  my $psn_conf_frame = $psn_notebook -> add("conf", -label=>"Psn.conf");
  my $psn_ssh_frame = $psn_notebook -> add("ssh", -label=>"SSH");

  my $psn_run_text = $psn_run_frame -> Scrolled ("Text", -scrollbars=>'e',
      -width=>70, -height=>16, -highlightthickness =>0,
      -exportselection => 0, -border=>1, -relief=>'groove',
      -font=>$font_small, -background=>"#f6f6e6", -state=>'normal'
  )->grid(-column=>1, -row=>0, -columnspan=>3, -sticky=>'nw', -ipadx=>0);

  $psn_run_frame -> Label (-text=>" ",-font=>$font_normal, -background=>$bgcol) -> grid(-row=>1,-column=>1,-sticky=>"w");
  $psn_run_frame -> Label (-text=>"Model file:", -font=>$font_normal,-background=>$bgcol) -> grid(-row=>2,-column=>1,-sticky=>"w");
  $psn_run_frame -> Entry (-textvariable=>\$modelfile, -font=>$font_normal,-background=>$white, -state=>'disabled', -border=>1, -relief=>'groove',) -> grid(-row=>2,-column=>2,-sticky=>"w");
  $psn_run_frame -> Label (-text=>"Dataset:", -font=>$font_normal,-background=>$bgcol) -> grid(-row=>3,-column=>1,-sticky=>"w");
  $psn_run_frame -> Entry (-textvariable=>$models_dataset{$model}, -font=>$font_normal,-background=>$white, -state=>'disabled', -width=>50,-border=>1, -relief=>'groove',) -> grid(-row=>3,-column=>2,-sticky=>"w");

  $psn_run_frame -> Label (-text=>" ",-font=>$font_normal, -background=>$bgcol) -> grid(-row=>6,-column=>1,-sticky=>"w");

  my $psn_command_line = build_psn_run_command ($psn_option, $psn_parameters, $model, \%ssh, \%clusters);
  my $psn_command_line_entry = $psn_run_frame -> Text (
      -width=>64, -relief=>'sunken', -border=>1, -height=>4,
      -font=>$font_normal, -background=>"#FFFFFF", -state=>'normal'
  )->grid(-column=>1, -row=>10, -columnspan=>2, -sticky=>'nwe', -ipadx=>0);
  $psn_command_line_entry -> delete("1.0","end");
  $psn_command_line_entry -> insert("1.0", $psn_command_line);

  $psn_run_button = $psn_run_frame -> Button (-image=> $gif{run}, -background=>$button, -width=>50,-height=>40, -activebackground=>$abutton)
   -> grid(-row=>10, -column=>3,-sticky=>"wns");
  $help -> attach($psn_run_button, "Start run");

  $psn_run_frame -> Label (-text=>"NM installation:", -font=>$font_normal, -background=>$bgcol) -> grid(-row=>7,-column=>1,-sticky=>"w");
#  my $psn_background = 0;
  $psn_run_frame -> Label (-text=>"Run in background: ", -font=>$font_normal, -background=>$bgcol) -> grid(-row=>6,-column=>1,-sticky=>"w");
  $psn_run_frame -> Checkbutton (-text=>" ", -variable=> \$psn_background, -font=>$font_normal,  -selectcolor=>$selectcol, -activebackground=>$bgcol, -selectcolor=>$selectcol, -command=> sub{
   }) -> grid(-row=>6,-column=>2,-sticky=>"w");

  $psn_run_frame -> Label (-text=>"\nPsN command line:",-font=>$font_normal, -background=>$bgcol) -> grid(-row=>9,-column=>1,-sticky=>"w");
 # $psn_run_frame -> Label (-text=>" ",-font=>$font_normal, -background=>$bgcol) -> grid(-row=>10,-column=>1,-sticky=>"w");
  our $nm_versions_menu = $psn_run_frame -> Optionmenu(
      -border=>$bbw, -background=>$run_color,-activebackground=>$arun_color,
      -font=>$font_normal, -background=>"#c0c0c0",
      -activebackground=>"#a0a0a0", -command=> sub{
        if (-e unix_path($nm_dirs{$nm_version_chosen}."/test/runtest.pl")) {
	    $run_method_nm_type="NMQual";
        } else {
	    $run_method_nm_type="nmfe"
	};
        unless ($psn_option eq "sumo") {
	    $psn_command_line = build_psn_run_command ($psn_option, $psn_parameters, $model, \%ssh, \%clusters);
	    $psn_command_line = update_psn_run_command ($psn_command_line, "-nm_version", $nm_version_chosen, 1, \%ssh, \%clusters);
        }
        $psn_command_line_entry -> delete("1.0","end");
        $psn_command_line_entry =~ s/\n//g;
        $psn_command_line_entry -> insert("1.0", $psn_command_line);
  })-> grid(-row=>7,-column=>2,-sticky => 'wns');

  $psn_run_window -> update();
  $psn_run_text -> insert("0.0", "Requesting NONMEM versions available in PsN...\n");

  my $psn_nm_versions_ref = get_psn_nm_versions(\%setting, \%software);
  %psn_nm_versions = %$psn_nm_versions_ref;
  # bit of a workaround to get "default" option as first option...
  my %psn_nm_versions_copy = %psn_nm_versions;
  delete ($psn_nm_versions_copy {"default"});
  my @psn_nm_installations = keys(%psn_nm_versions_copy);
  unshift (@psn_nm_installations, "default");
  $nm_versions_menu -> configure (-options => [@psn_nm_installations], -variable => \$nm_version_chosen,);

  $psn_run_button -> configure ( -border=>$bbw, -command=> sub {
      my $files = "";

      # store the parameter options
      $psn_command_line = $psn_command_line_entry -> get("1.0","end");
      $psn_command_line =~ s/\n//g;
      $psn_params = $psn_command_line;
      $psn_params =~ s/$psn_option//;
      $psn_params =~ s/$modelfile//;
      $psn_params =~ s/$ssh_login//;
      $psn_params =~ s/$ssh_parameters//;
      $psn_params =~ s/\"+$//;  #remove trailing spaces
      my $psn_nm_version = "";
      @runs = $models_hlist -> selectionGet ();
      $psn_commands{$psn_option} = $psn_params;
      save_ini ($home_dir."/ini/psn.ini", \%psn_commands, \%psn_commands_descr);

      exec_run_psn ($psn_command_line, \%ssh, $modelfile, $model_description, $psn_background);

      status ();
      #if ($stdout) {$stdout -> yview (scroll=>1, units);}
      chdir ($cwd);
      $help -> detach($psn_run_button);
      $psn_run_window -> destroy();
  });

  $psn_run_window -> update();
  $psn_run_text -> insert("1.0", "Requesting command information from PsN...\n");
  $psn_run_text -> update();
  my $psn_text = get_psn_info($psn_option, $software{psn_toolkit});
  if ($psn_text eq "") {
    $psn_text = "PsN was not found. Please check your installation!";
    $psn_run_button -> configure(-state=>'disabled');
  }
  $psn_run_text -> delete ("0.0",end);
  $psn_run_text -> insert("0.0", $psn_text);

  # psn.conf tab
  open (PSN, $software{psn_dir}."/psn.conf");
  my @lines = <PSN>;
  my $text = join("", @lines);
  close (PSN);
  text_edit_window_build ($psn_conf_frame, $text, $software{psn_dir}."/psn.conf", $font_fixed, 70, 22, 0);

  # SSH tab
  my @params = ($psn_command_line_entry, $psn_option, $model, $psn_parameters, \%clusters, \%ssh);
  ssh_notebook_tab ($psn_ssh_frame, 2, \@params);

  status ();
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

sub frame_models_show {
### Purpose : Create the frame and the HList object that show the models
### Compat  : W+L+
### Notes   : needs some os-specifics to make the HList look okay.
  if (@_[0]==1) {
  unless($model_overview_frame) {
    our $model_overview_frame = $mw-> Frame(-background=>"$bgcol")->grid(-row=>2,-column=>1,-columnspan=>1,-sticky=>'nwe',-ipadx=>5,-ipady=>0);
    ### Status bar:
    $model_overview_frame-> Label(-text=>"Models:", -font=>$font_normal)-> grid(-row=>2,-columnspan=>1,-column=>2, -sticky=>"w");
  }
  @models_hlist_headers = (" #", "Ref#","Description", "Method", "OFV","dOFV","S","C","B","Sig","Notes");
  @models_hlist_widths = split (";", $setting{header_widths});

  our $models_hlist = $model_overview_frame -> Scrolled('HList',
        -head       => 1,
        -relief     => 'groove',
        -highlightthickness => 0,
        -selectmode => "extended",
        -columns    => int(@models_hlist_headers),
        -scrollbars => 'se',
        -height     => $nrows,
        -width      => 105,
        -pady       => 0,
        -padx       => 0,
        -background => 'white',
        -selectbackground => $pirana_orange,
        -font       => $font_normal,
        -command    => sub {models_hlist_action ()},
        -browsecmd   => sub{
          my @sel = $models_hlist -> selectionGet ();
          update_psn_lst_param ();
          if (($run_method eq "NONMEM")&&(@file_type_copy[@sel[0]]==2)) { update_new_dir(@ctl_show[@sel])};
          # get note from SQL
          if (@file_type_copy[@sel[0]] == 2) {
            my $mod_file = @ctl_show[@sel[0]].".".$setting{ext_ctl};
            update_text_box(\$model_info_no, @ctl_show[@sel[0]].".".$setting{ext_ctl});
            update_text_box(\$notes_text, $models_descr{@ctl_show[@sel[0]]});
	    my $stat_ref = stat $mod_file;
	    my @stat = @$stat_ref;
            my $mod_time = gmtime(@stat[9]);
            update_text_box(\$model_info_modified, $mod_time);
            update_text_box(\$model_info_dataset, $models_dataset{@ctl_show[@sel[0]]});
          } else {
	      if ($show_model_info==1) { $notes_text -> configure(-state=>"disabled") }
          }
          if ($estim_window) {
            show_estim_window (@ctl_show[@sel[0]].".".$setting{ext_res});
            $estim_window -> raise();
          }
        }
    )->grid(-column => 1, -columnspan=>3, -row => 1, -rowspan=>3, -sticky=>'nswe', -ipady=>0);
    unless ($os =~ m/MSWin/i) {
     # $models_hlist -> bind ('<Button-1>' => sub {
     #   if ($hires_time) { # workaround, on Linux double-click doesn't work due to headers in listbox.
     #     if ((Time::HiRes::time - $hires_time)<0.25) {
     #       models_hlist_action();
     #     }
     #   }
     #   our $hires_time = Time::HiRes::time;
     # })  ;
    }

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
    $models_hlist -> bind ('<Delete>' => sub {
	delete_models_command();
    });

    our $models_menu = $models_hlist -> Menu(-tearoff => 0, -background=>$bgcol, -title=>'None');
    $models_menu -> command (-label=> " Run (nmfe)", -font=>$font, -compound => 'left',-image=>$gif{run}, -background=>$bgcol, -command => sub{
       nmfe_command();
    });
    our $models_menu_psn = $models_menu -> cascade (-label=>" PsN", -font=>$font,-compound => 'left',-image=>$gif{run}, -background=>$bgcol, -tearoff=>0);
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
    $models_menu_psn -> command (-label=> " sumo", -font=>$font,-compound => 'left',-image=>$gif{edit_info}, -background=>$bgcol, -command => sub{
       psn_command("sumo");
    });
    if ($os =~ m/MSWin/i) {
      our $models_menu_wfn = $models_menu -> cascade (-label=> " WFN", -font=>$font,-compound => 'left',-image=>$gif{run}, -background=>$bgcol, -tearoff=>0);
      $models_menu_wfn -> command (-label=> " NMGO", -font=>$font,-compound => 'left',-image=>$gif{run}, -background=>$bgcol, -command => sub{
           wfn_command("NMGO");
         });
      $models_menu_wfn -> command (-label=> " NMBS", -font=>$font,-compound => 'left',-image=>$gif{run}, -background=>$bgcol, -command => sub{
           wfn_command("NMBS");
         });
    }
    $models_menu -> separator (-background=>$bgcol) ;
    $models_menu -> command (-label=>" Model properties...",-font=>$font,-compound => 'left',-image=>$gif{edit_info}, -background=>$bgcol, -command => sub{
           properties_command ();
         });
    $models_menu -> command (-label=>" Edit model", -font=>$font,-image=>$gif{notepad}, -compound=>'left',  -background=>$bgcol, -command => sub{
           edit_model_command();
         });
     $models_menu -> command (-label=> " Rename model", -font=>$font, -image=>$gif{rename}, -compound=>'left', -background=>$bgcol, -command => sub{
           rename_model_command();
         });
    $models_menu -> command (-label=> " Duplicate model",-font=>$font, -image=>$gif{duplicate}, -compound=>'left', -background=>$bgcol, -command => sub{
           duplicate_model_command();
         });
    $models_menu -> command (-label=> " Duplicate model for MSF restart", -font=>$font, -image=>$gif{msf}, -compound=>'left', -background=>$bgcol, -command => sub{
           duplicate_msf_command();
          });
    $models_menu -> command (-label=> " Delete model(s) / result(s)", -font=>$font, -image=>$gif{trash}, -compound=>'left', -background=>$bgcol, -command => sub{
           delete_models_command();
         });

    $models_menu -> separator ( -background=>$bgcol) ;

    create_scripts_menu ($models_menu, "script", 1, $base_dir."/scripts", "Scripts");
    create_scripts_menu ($models_menu, "script", 1, $home_dir."/scripts", "User scripts");
    $models_menu -> command (-label=> " Send model info to PiranaR", -image=>$gif{pirana_r}, -font=>$font,-compound=>'left', -background=>$bgcol, -command => sub{
	send_model_info_to_R_command();
         });

    $models_menu -> command (-label=> " Generate HTML report(s)", -image=>$gif{HTML}, -font=>$font,-compound=>'left', -background=>$bgcol, -command => sub{
           generate_report_command(\%run_reports);
         });

    $models_menu -> command (-label=> " LaTeX tables of parameter estimates", -image=>$gif{latex},-font=>$font, -compound=>'left', -background=>$bgcol, -command => sub{
#           generate_LaTeX_command();
         });
    $models_menu -> command (-label=> " View NM output file",  -image=>$gif{notepad},-font=>$font, -compound=>'left', -background=>$bgcol, -command => sub{
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

  our $dirstyle = $models_hlist->ItemStyle( 'text', -anchor => 'nw',-padx => 5, -background=>'#ffffe0', -font => $font_normal);
  our $align_right = $models_hlist->ItemStyle( 'text', -anchor => 'ne',-padx => 5, -background=>'white', -font => $font_normal);
  our $align_right_red = $models_hlist->ItemStyle( 'text', -anchor => 'ne',-padx => 5, -background=>'red', -font => $font_normal);
  our $align_left = $models_hlist-> ItemStyle( 'text', -anchor => 'nw',-padx => 5, -background=>'white', -font => $font_normal);
  our $header_left = $models_hlist->ItemStyle('text',-background=>'gray', -anchor => 'nw', -pady => 0, -padx => 2, -font => $font_normal );
  our $header_right = $models_hlist->ItemStyle('text',-background=>'gray', -anchor => 'ne', -pady => 0, -padx => 2, -font => $font_normal );
  our $green_ofv = $models_hlist->ItemStyle( 'text', -anchor => 'ne',-padx => 5, -foreground=>'#008800', -background=>'white',-font => $font_fixed);
  our $red_ofv = $models_hlist->ItemStyle( 'text', -anchor => 'ne',-padx => 5, -foreground=>'#990000', -background=>'white',-font => $font_fixed);
  our $yellow_ofv = $models_hlist->ItemStyle( 'text', -anchor => 'ne',-padx => 5, -foreground=>'#888800', -background=>'white',-font => $font_fixed);
  our $black_ofv = $models_hlist->ItemStyle( 'text', -anchor => 'ne',-padx => 5, -foreground=>'#000000', -background=>'white',-font => $font_fixed);
  our $bold_left = $models_hlist->ItemStyle( 'text', -anchor => 'nw',-padx => 5, -foreground=>'#000000', -background=>'white',-font => $font_fixed);
  our $bold_right = $models_hlist->ItemStyle( 'text', -anchor => 'ne',-padx => 5, -foreground=>'#000000', -background=>'white',-font => $font_fixed);
  our $estim_style = $models_hlist-> ItemStyle( 'text', -anchor => 'ne', -background=>'#c0d0ff', -font => $font_normal);
  our $estim_style_left = $models_hlist-> ItemStyle( 'text', -anchor => 'nw', -background=>'#c0d0ff', -font => $font_normal);
  our $estim_style_light = $models_hlist-> ItemStyle( 'text', -anchor => 'ne', -background=>'#d5e5ff', -font => $font_normal);
  our $estim_style_se = $models_hlist-> ItemStyle( 'text', -anchor => 'ne', -background=>'#ffffe5', -font => $font_normal);

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
  $model_overview_frame -> bind('<Leave>' => sub {save_header_widths();});
  $models_hlist -> update();

  $mod_buttons = $model_overview_frame -> Frame(-background=>$bgcol) ->grid(-row=>0,-column=>1,-rowspan=>1,-ipadx=>'0', -ipady=>'0',-sticky=>'w');

  our $condensed_view_button = $mod_buttons -> Button (
       -image=>$gif{binocular}, -background => $button, -border=>$bbw, -activebackground=>$abutton,
       -width=>26, -height=>22,
       -command=>sub{
           $condensed_model_list = 1 - $condensed_model_list;
	   populate_models_hlist ($models_view, $condensed_model_list);
      })->grid(-row=>1,-column=>1,-sticky=>'we');
  $help->attach($condensed_view_button, -msg => "Show condensed or expanded view of models");

  if ($models_view eq "tree") {$listimage = $gif{treeview}} else {$listimage = $gif{listview}};
  our $sort_button = $mod_buttons->Button(-image=>$listimage, -width=>26, -height=>22, -border=>$bbw,-background=>$button,-activebackground=>$abutton,-command=> sub{
    if ($models_view eq "tree") {
       $models_view = "list";
       $listimage = $gif{listview};
    } else {
       $models_view = "tree";
       save_header_widths ();
       $listimage = $gif{treeview};
    }
    $sort_button -> configure (-image=>$listimage);
    populate_models_hlist($models_view, $condensed_model_list);
  })->grid(-row=>1,-column=>2,-sticky=>'we');
  $help->attach($sort_button, -msg => "Show models as list or as tree structure, based on their reference model");

  our $new_button = $mod_buttons->Button(-image=>$gif{newfolder}, -width=>26,  -height=>22, -border=>$bbw,-background=>$button,-activebackground=>$abutton,-command=> sub{
    new_dir();})
    ->grid(-row=>1,-column=>3,-sticky=>'we');
  $help->attach($new_button, -msg => "New folder");
  our $new_button = $mod_buttons->Button(-image=>$gif{new}, -width=>26,  -height=>22, -border=>$bbw,-background=>$button,-activebackground=>$abutton,-command=> sub{
    new_ctl();})
    ->grid(-row=>1,-column=>4,-sticky=>'we');
  $help->attach($new_button, -msg => "New model");

  $mod_buttons -> Label (-text=>"       ", -background=>$bgcol)->grid(-row=>1,-column=>5,-sticky=>'we');

  my $show_execution_log = $mod_buttons -> Button (-image=>$gif{log}, -background=>$button,-activebackground=>$abutton, -border=>0,
	  -command=>sub {
      show_exec_runs_window();
    })->grid(-row=>1,-column=>6,-sticky=>'wens');
  $help->attach($show_execution_log, -msg => "Show model execution log");

  our $show_estim_button = $mod_buttons->Button(-image=>$gif{estim},-width=>26, -height=>24, -border=>$bbw,-background=>$button, -activebackground=>$abutton,-command=>sub{
        my @lst = @ctl_show[$models_hlist -> selectionGet ()];
        my $lst = @lst[0].".".$setting{ext_res};
        show_estim_window ($lst);
        $estim_window -> raise();
      })->grid(-row=>1,-column=>7,-sticky=>'wens');
  $help->attach($show_estim_button, -msg => "Show parameter estimates from runs");

  our $show_inter_button = $mod_buttons->Button(-image=>$gif{edit_inter},-width=>26, -height=>24, -border=>$bbw,-background=>$button, -activebackground=>$abutton,-command=>sub{
      $cwd = $dir_entry -> get();
      chdir($cwd);
      show_inter_window($cwd);
      if ($inter_window) {$inter_window -> focus();}
      })->grid(-row=>1,-column=>8,-sticky=>'wens');
  $help->attach($show_inter_button, -msg => "Show intermediate results for models\ncurrently running in this directory");

  our $sum_list_button = $mod_buttons -> Button(-image=>$gif{compare}, -state=>'normal', -width=>26, -height=>24, -border=>$bbw, -background=>$button,-activebackground=>$abutton,-command=>sub{
    create_output_summary ("pirana_output_list.csv");
    if (-e $software{spreadsheet}) {
      start_command($software{spreadsheet},'"'.win_path('pirana_output_list.csv').'"');
    } else {message("Spreadsheet application not found. Please check settings.")};
    status ();
  }) ->grid(-row=>1,-column=>9,-columnspan=>1,-sticky=>'wens');
  $help->attach($sum_list_button, -msg => "Generate summary (csv-file) of all NONMEM output files");

  our $tree_txt_button = $mod_buttons -> Button(-image=>$gif{treeview2}, -state=>'normal', -width=>26, -height=>24, -border=>$bbw, -background=>$button,-activebackground=>$abutton,-command=>sub{
    my($tree_models_ref, $tree_text) = tree_models();
    text_window($tree_text, "Model tree");
  }) ->grid(-row=>1,-column=>10,-columnspan=>1,-sticky=>'wens');
  $help->attach($tree_txt_button, -msg => "Generate run record as tree");

  $mod_buttons -> Label (-text=>"   ", -background=>$bgcol)->grid(-row=>1,-column=>11,-sticky=>'we');

  unless ($^O =~ m/MSWin/) {
      our $sge_monitor_button = $mod_buttons -> Button(-image=>$gif{cluster}, -state=>'normal', -border=>$bbw, -background=>$button,-activebackground=>$abutton,
		  -command=>sub {sge_monitor_window();
      })->grid(-row=>1,-column=>12,-columnspan=>1,-sticky=>'wens');
      $help->attach($sge_monitor_button, -msg => "Open SGE montitor");
  }

  our $piranaR_button = $mod_buttons -> Button(-image=>$gif{pirana_r}, -state=>'normal', -width=>26, -height=>24, -border=>$bbw, -background=>$button,-activebackground=>$abutton,-command=>sub{
      create_window_piranaR ($mw, "", 0);
  }) ->grid(-row=>1,-column=>13,-columnspan=>1,-sticky=>'wens');
  $help->attach($piranaR_button, -msg => "Open PiranaR interface");

  $copy_dir_res_button = $mod_buttons->Button(-image=>$gif{folderout},-width=>26, -height=>24, -border=>$bbw,-background=>$button, -activebackground=>$abutton,-command=>sub{
      $cwd = $dir_entry -> get();
      $test_dirs = 0;
      foreach (@file_type_copy[$models_hlist -> selectionGet()]) {
        if ($_ != 1) {$test_dirs = 1}
      }
      if ($test_dirs == 0 ) {
        @dirs = @ctl_show[$models_hlist -> selectionGet ()];
        copy_dir_res($cwd, \@dirs);
      } else {
        message ("Please select one or more valid directories.");
      }
  })->grid(-row=>1,-column=>9,-sticky=>'wens');
  $help->attach($copy_dir_res_button, -msg => "Copy results files and \$TABLE files from a subfolder to the current folder");

  $filter_buttons = $model_overview_frame -> Frame(-background=>$bgcol) ->grid(-row=>0,-column=>3,-rowspan=>1,-ipadx=>'0', -ipady=>'0',-sticky=>'e');

  our $psn_dir_filter = 0;
  $filter_buttons -> Label(-text=>"Folders: ", -font=>$font_normal, -background=>$bgcol)->grid (-row=>1,-column=>1, -columnspan=>1, -sticky=>'e');

  $filter_psn_button = $filter_buttons ->Checkbutton(-text=>"PsN   ", -background=>$bgcol, -font=>$font_normal, -variable=>\$psn_dir_filter, -selectcolor=>$selectcol, -activebackground=>$bgcol, -command=>sub{
     read_curr_dir($cwd, $filter, 1);
     status();
  })->grid(-row=>1,-column=>2,-sticky=>'w', -ipady=>0, -ipadx=>0);
  $help->attach($filter_psn_button, -msg => "Filter out PsN-generated directories");
  our $nmfe_dir_filter = 0;
  $filter_nmfe_button = $filter_buttons ->Checkbutton(-text=>"nmfe",-background=>$bgcol, -font=>$font_normal, -variable=>\$nmfe_dir_filter, -selectcolor=>$selectcol, -activebackground=>$bgcol, -command=>sub{
     read_curr_dir($cwd, $filter, 1);
     status();
  })->grid(-row=>1,-column=>3,-sticky=>'w', -ipady=>0, -ipadx=>0);
  $help->attach($filter_nmfe_button, -msg => "Filter out nmfe run directories");

  # Filter
  our $filter = "";
  $filter_buttons -> Label(-text=>"       Filter:", -font=>$font_normal, -background=>$bgcol)->grid (-row=>1,-column=>5, -sticky=>'ew');
  $filter_entry = $filter_buttons -> Entry(-width=>12,-textvariable=>\$filter, -background=>$white,-border=>2, -relief=>'groove' )
    -> grid(-row=>1,-column=>6,-columnspan=>2, -sticky => 'we',-ipadx=>1);
  $filter_entry -> bind('<Any-KeyPress>' => sub {
     if (length($filter)>0) {$filter_entry -> configure(-background=>$lightyellow )} else {$filter_entry -> configure(-background=>$white)};
     read_curr_dir($cwd, $filter, 0);
  });

  $help->attach($filter_entry, -msg => "Filter model files");
}

sub show_run_frame {
  ($nm_dirs_ref,$nm_vers_ref) = read_ini($home_dir."/ini/nm_inst_local.ini");
  %nm_dirs = %$nm_dirs_ref; %nm_vers = %$nm_vers_ref;
  if (-e $home_dir."/log/pirana.log") {  # read last used NM installation
          read_log();
  }
  $run_frame = $model_overview_frame -> Frame(-background=>$bgcol)->grid(-row=>4,-column=>1,-columnspan=>3,-sticky => 'wns', -ipady=>0);

  # spacer
  # $run_frame -> Label(-text=>" ", -font=>'Verdana 1', -width=>10) -> grid(-sticky=>'we',-row=>3,-column=>1,-ipady=>0);
  our $run_color=$lightblue; our $arun_color=$darkblue;

  if ($setting{default_method} =~ m/nmq/gi) {$run_method = "NONMEM"};
  if ($setting{default_method} =~ m/psn/gi) {$run_method = "PsN"; $nm_version_chosen = "default"};
  if ($setting{default_method} =~ m/wfn/gi) {$run_method = "WFN"};
  if ($setting{default_method} =~ m/nmfe/gi) {$run_method = "NONMEM"};

  if ($os =~ m/MSWin/i) {$model_overview_frame -> Label(-text=>" ",-font=>"Arial 1", -background=>$bgcol)->grid(-ipady=>2,-sticky=>'news',-row=>18,-column=>1);}  #spacer

  # Notes
  my $spacer = 5;
  if ($os =~ m/MSWin/i) {$spacer = 14; };
  $run_frame -> Label(-text=>"", -width=>$spacer, -font=>"Courier 1", -background=>$bgcol)->grid(-column=>6, -row=>1);  #spacer
  if ($setting{font_size} == 2) {$note_width=40} else {$note_width = 29};

  $run_info_frame = $run_frame -> Frame(-background=>$bgcol)->grid(-row=>1, -column=>7, -rowspan=>2, -ipady=>3, -sticky=>"ne");
  $run_info_frame -> Label(-text=>"Model file:", -font=>$font_normal, -background=>$bgcol)-> grid(-row=>1, -column=>1, -sticky=>"ne");
  $run_info_frame -> Label(-text=>"  Description:", -font=>$font_normal, -background=>$bgcol)-> grid(-row=>2, -column=>3, -sticky=>"nwe");
  my $edit_note = $run_info_frame -> Button (-image=>$gif{edit_info_small}, -width=>24, -border=>$bbw, -background=>$button,-activebackground=>$abutton, -command=> sub{
    properties_command();
  }) -> grid(-row=>3, -column=>3, -sticky=>"ens");
  $help -> attach($edit_note, -msg => "Edit properties and notes of model / results");
  $run_info_frame -> Label(-text=>"Last modified:", -font=>$font_normal, -background=>$bgcol)-> grid(-row=>2, -column=>1, -sticky=>"nes");
  $run_info_frame -> Label(-text=>"Dataset:", -font=>$font_normal, -background=>$bgcol)-> grid(-row=>3, -column=>1, -sticky=>"nes");
  $run_info_frame -> Label (-text=>"  Coloring:", -font=>$font_normal, -background=>$bgcol )->grid(-column=>3,-row=>1,-sticky=>"en");

  if ($full_screen==0) {$entry_width = 36};
  our $notes_text = $run_info_frame -> Text (
      -width=>$entry_width, -relief=>'sunken', -border=>0, -height=>1,
      -font=>$font_small, -background=>"#f6f6e6", -state=>'disabled'
  )->grid(-column=>4, -row=>2,-sticky=>'nws', -ipadx=>0);
  our $model_info_no = $run_info_frame -> Text (
      -width=>$entry_width, -relief=>'sunken', -border=>0, -height=>1,
      -font=>$font_small, -background=>"#f6f6e6", -state=>'disabled'
  )->grid(-column=>2, -row=>1,-sticky=>'nsw', -ipadx=>0);
  our $model_info_dataset = $run_info_frame -> Text (
      -width=>$entry_width, -relief=>'sunken', -border=>0, -height=>1,
      -font=>$font_small, -background=>"#f6f6e6", -state=>'disabled'
  )->grid(-column=>2, -row=>3, -sticky=>'nws', -ipadx=>0);
  our $model_info_modified = $run_info_frame -> Text (
      -width=>$entry_width, -relief=>'sunken', -border=>0, -height=>1,
      -font=>$font_small, -background=>"#f6f6e6", -state=>'disabled'
  )->grid(-column=>2, -row=>2, -sticky=>'nws', -ipadx=>0);

  my $colorbox_width = 1;
  if($os =~ m/MSWin/i) { $colorbox_width=4;};
  $colors_frame = $run_info_frame -> Frame (-background=>$bgcol)->grid(-column=>4, -row=>1, -rowspan=>1,-sticky=>'wns', -ipady=>0);

  $colors_frame -> Button (-text=>'', -border=>0,-width=>$colorbox_width, -height=>0, -background=>$darkred, -activebackground=>$lightred, -font=>'Arial 5', -command=> sub {
    status("Saving color information...");
    note_color ($lightred);
    status();
  })->grid(-column=>2, -row=>1,-rowspan=>1,-sticky=>'nw');
  $colors_frame -> Button (-text=>'', -border=>0,-width=>$colorbox_width, -height=>1, -background=>$lightblue, -activebackground=>$lighterblue, -font=>'Arial 5', -command=> sub {
    status("Saving color information...");
    note_color ($lighterblue);
    status();
  })->grid(-column=>3, -row=>1,-rowspan=>1,-sticky=>'nw');
  $colors_frame -> Button (-text=>'', -border=>0,-width=>$colorbox_width, -height=>1, -background=>$darkgreen, -activebackground=>$lightgreen, -font=>'Arial 5', -command=> sub {
    status("Saving color information...");
    note_color ($lightgreen);
    status();
  })->grid(-column=>4, -row=>1,-rowspan=>1,-sticky=>'nw');
  $colors_frame -> Button (-text=>'', -border=>0,-width=>$colorbox_width, -height=>1, -background=>'white', -activebackground=>'white', -font=>'Arial 5', -command=> sub {
    status("Saving color information...");
    note_color ("#FFFFFF");
    status();
  })->grid(-column=>7, -row=>1,-rowspan=>1,-sticky=>'nw');
    $colors_frame -> Button (-text=>'',-border=>0,-width=>$colorbox_width, -height=>1,-background=>$abutton, -activebackground=>$button, -font=>'Arial 5', -command=> sub {
    status("Saving color information...");
    note_color ($button);
    status();
  })->grid(-column=>6, -row=>1,-rowspan=>1,-sticky=>'nw');
  $colors_frame -> Button (-text=>'', -border=>0,-width=>$colorbox_width, -height=>1, -background=>$darkyellow, -activebackground=>$lightyellow, -font=>'Arial 5', -command=> sub {
    status("Saving color information...");
    note_color ($lightyellow);
    status();
  })->grid(-column=>5, -row=>1,-rowspan=>1,-sticky=>'nwes');
  }
}

sub table_info_window {
### Purpose : Open a dialog window in which table/file info (size / notes) are shown and can be edited
### Compat  : W+L+?
  my $file = shift; my $mod; my $file_descr=$table_descr{$file};
  my $file_notes = $table_note{$file}; my $creator=$table_creator{$file};
  my $table_info_window = $mw -> Toplevel(-title=>'File properties');
  $table_info_window -> resizable( 0, 0 );
  center_window($table_info_window);
  my $table_info_frame = $table_info_window -> Frame(-relief=>'groove', -border=>0, -padx=>7, -pady=>7)->grid(-ipadx=>'10',-ipady=>'10',-sticky=>'n');
  $table_info_frame -> Label (-text=>"Filename:\n") -> grid(-row=>2, -column=>1,-sticky=>"en");
  $table_info_frame -> Entry (-background=>$white, -text=>unix_path($cwd."/".$file),-font=>$font_normal, -relief=>'sunken', -background=>$button, -border=>0, -width=>60, -state=>'disabled') -> grid(-row=>2, -column=>2,-sticky=>"wn");
  $table_info_frame -> Label (-text=>"Last modified:\n") -> grid(-row=>3, -column=>1, -sticky=>"en");
  if (-e $file) {$mod_time = gmtime(@{stat $file}[9])};
  $table_info_frame -> Entry (-background=>$white, -text=> $mod_time, -font=>$font_normal, -width=>24, -state=>'disabled',-relief=>'sunken', -border=>0, -background=>$button) -> grid(-row=>3, -column=>2,-sticky=>"wn");
  $table_info_frame -> Label (-text=>"Creator:\n") -> grid(-row=>4, -column=>1, -sticky=>"en");
  $table_info_frame -> Entry (-background=>$white, -textvariable=> \$creator, -font=>$font_normal, -width=>45, -state=>'normal',-relief=>'sunken', -border=>0, -background=>'white') -> grid(-row=>4, -column=>2,-sticky=>"wn");

  $table_info_frame -> Label (-text=>"Description:\n") -> grid(-row=>5, -column=>1, -sticky=>"en");
  $table_info_frame -> Entry (-background=>$white, -textvariable=> \$file_descr, -font=>$font_normal, -width=>45, -state=>'normal',-relief=>'sunken', -border=>0, -background=>'white') -> grid(-row=>5, -column=>2,-sticky=>"wn");

  $table_info_frame -> Label (-text=>"Notes:\n") -> grid(-row=>8, -column=>1, -sticky=>"en");
  $table_info_notes = $table_info_frame -> Text (-width=>45, -font=>$font_normal, -height=>10, -state=>'normal',-relief=>'sunken', -border=>0, -background=>'white') -> grid(-row=>8, -column=>2,-sticky=>"wn");
  $table_info_notes -> insert('end', $file_notes);
  $table_info_frame -> Label (-text=>" ") -> grid(-row=>9, -column=>3, -sticky=>"en");

  $table_info_frame -> Button (-text=>"Save and close", -width=>15, -background=>$button, -border=>$bbw, -activebackground=>$abutton, -command=> sub {
    $file_notes = $table_info_notes -> get("0.0", "end");
    my $update = 0;
    if(grep $_ eq $file, keys(%table_descr)) {$update=1};
    db_insert_table_info ($file, $file_descr, $creator, $file_notes, $update);
    $table_descr{$file} = $file_descr;
    $table_creator{$file} = $creator;
    $table_note{$file} = $file_notes;
    my $note = $table_note{$file};
    $note =~ s/\n/ /g;
    update_text_box(\$tab_file_note, $note);
    $table_info_window -> destroy();
    return();
  }) -> grid(-row=>10, -column=>2, -sticky=>"wn");
  $table_info_frame -> Button (-text=>"Cancel", -width=>15, -background=>$button, -border=>$bbw, -activebackground=>$abutton, -command=> sub {
    $table_info_window -> destroy();
    return();
  }) -> grid(-row=>10, -column=>1, -sticky=>"en");
  #$model_prop_frame -> Label (-text=>" ") -> grid(-row=>20, -column=>3, -sticky=>"en");
}

sub model_properties_window {
### Purpose : Open a dialog window in which model properties are shown and can be edited
### Compat  : W+L+?
  my ($model_id, $idx) = @_;
  my $model_info_db = db_read_model_info ($model_id);
  my $row = @{$model_info_db}[0];
  my ($model_id, $ref_mod, $descr, $note_small, $note) = @$row;
  $descr_new = $descr;
  my $model_prop_window = $mw -> Toplevel(-title=>'Model properties');
  $model_prop_window -> resizable( 0, 0 );
  center_window($model_prop_window);

  my $model_prop_frame = $model_prop_window -> Frame(-relief=>'groove', -background=>$bgcol, -border=>0, -padx=>7, -pady=>7)->grid(-ipadx=>'10',-ipady=>'10',-sticky=>'n');
  $model_prop_frame -> Label (-text=>"Model no:\n",-background=>$bgcol) -> grid(-row=>1, -column=>1,-sticky=>"en");
  $model_prop_frame -> Entry (-text=>$model_id, -background=>$bgcol, -font=>$font_normal, -width=>15, -state=>'disabled', -disabledforeground=>'#727272',-relief=>'sunken', -border=>0, -background=>$button) -> grid(-row=>1, -column=>2,-sticky=>"wn");
  $model_prop_frame -> Label (-text=>"Filename:\n", -background=>$bgcol) -> grid(-row=>2, -column=>1,-sticky=>"en");
  $model_prop_frame -> Entry (-text=>unix_path($cwd."/".$model_id.".".$setting{ext_ctl}),-background=>$bgcol,-font=>$font_normal, -disabledforeground=>'#727272', -relief=>'sunken', -background=>$button, -border=>0, -width=>50, -state=>'disabled') -> grid(-row=>2, -column=>2,-sticky=>"wn");
  $model_prop_frame -> Label (-text=>"Last modified:\n", -background=>$bgcol) -> grid(-row=>3, -column=>1, -sticky=>"en");
  my $mod = gmtime($models_dates_db{$model_id});
  $model_prop_frame -> Entry (-text=> $mod,-background=>$bgcol, -font=>$font_normal, -width=>24, -state=>'disabled',-disabledforeground=>'#727272',-relief=>'sunken', -border=>0, -background=>$button) -> grid(-row=>3, -column=>2,-sticky=>"wn");
  $model_prop_frame -> Label (-text=>"Dataset:\n", -background=>$bgcol) -> grid(-row=>4, -column=>1, -sticky=>"en");
  $model_prop_frame -> Entry (-text=> $models_dataset{$model_id}, -background=>$bgcol, -font=>$font_normal, -width=>24, -state=>'disabled',-disabledforeground=>'#727272',-relief=>'sunken', -border=>0, -background=>$button) -> grid(-row=>4, -column=>2,-sticky=>"wn");
  $model_prop_frame -> Label (-text=>"Description:\n", -background=>$bgcol) -> grid(-row=>5, -column=>1, -sticky=>"en");
  $model_prop_frame -> Entry (-text=> $descr_new, -background=>$bgcol, -font=>$font_normal, -width=>45, -state=>'disabled', -disabledforeground=>'#727272', -relief=>'sunken', -border=>0, -background=>'white') -> grid(-row=>5, -column=>2,-sticky=>"wn");
  $model_prop_frame -> Label (-text=>"Reference model:\n", -background=>$bgcol) -> grid(-row=>6, -column=>1, -sticky=>"en");
  $model_prop_frame -> Entry (-text=> $ref_mod, -background=>$bgcol, -font=>$font_normal, -width=>10, -state=>'disabled',-disabledforeground=>'#727272',-relief=>'sunken', -border=>0, -background=>'white') -> grid(-row=>6, -column=>2,-sticky=>"wn");
  $model_prop_frame -> Label (-text=>"Notes:\n",-background=>$bgcol) -> grid(-row=>8, -column=>1, -sticky=>"en");
  $model_prop_notes = $model_prop_frame -> Text (-background=>$bgcol,-width=>45, -font=>$font_normal, -height=>10, -state=>'normal',-relief=>'sunken', -border=>0, -background=>'white') -> grid(-row=>8, -column=>2,-sticky=>"wn");
  $model_prop_frame -> Label (-text=>" ",-background=>$bgcol) -> grid(-row=>9, -column=>3, -sticky=>"en");
  $model_prop_notes -> insert("end", $note);

  $model_prop_frame -> Button (-text=>"Save", -width=>15, -background=>$button, -border=>$bbw, -activebackground=>$abutton, -command=> sub {
      $model_notes = $model_prop_notes -> get("0.0", "end");
      chomp ($model_notes);
      $model_notes =~ s/\'//g; # strip '
      $model_notes =~ s/\"//g; # strip "
      db_insert_model_info ($model_id, $descr, $model_notes);
      if ($descr_new ne $descr) {change_model_description($model_id, $descr_new)};
      $models_notes{$model_id} = $model_notes;
      my $note_strip = $model_notes;
      if ($condensed_model_list == 1) {$note_strip =~ s/\n/\ /g;}
      $models_hlist -> itemConfigure($idx, 10, -text => $note_strip);
      $models_hlist -> update();
      $model_prop_window -> destroy();
      return(1);
    }) -> grid(-row=>10, -column=>2, -sticky=>"wn");
  $model_prop_frame -> Button (-text=>"Cancel", -width=>15, -background=>$button, -border=>$bbw, -activebackground=>$abutton, -command=> sub {
    $model_prop_window -> destroy();
    return(1);
  }) -> grid(-row=>10, -column=>1, -sticky=>"en");
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
      $obj -> configure(-state=>"disabled");
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
      $models_hlist -> itemConfigure($no, 1, -style => $style_color_small);
      $models_hlist -> itemConfigure($no, 2, -style => $style_color);
      $models_hlist -> itemConfigure($no, 3, -style => $style_color);
      $models_hlist -> itemConfigure($no, 4, -style => $style_color);
      $models_hlist -> itemConfigure($no, 5, -style => $style_color);
      $models_hlist -> itemConfigure($no, 6, -style => $style_color);
      $models_hlist -> itemConfigure($no, 7, -style => $style_color);
      $models_hlist -> itemConfigure($no, 8, -style => $style_color);
      $models_hlist -> itemConfigure($no, 9, -style => $style_color);
      $models_hlist -> itemConfigure($no, 10, -style => $style_color);
      db_add_color (@ctl_show[$no], $color)
    }
  }
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
      $rand_filename = "pirana_wfn_".generate_random_string(4);
      if ($wfn_option =~ m/nmbs/) {
        my $count =0;
        foreach (@idx) {
          copy ($file.".".$setting{ext_ctl}, $file."_bs".$_.".".$setting{ext_ctl});
          open (BAT_RUN,">".$rand_filename."_".$_.".bat");
          print BAT_RUN substr($cwd,0,2)."\ncd ".win_path(substr($cwd,2,(length($cwd)-2)))."\n";
          print BAT_RUN "CALL ".win_path($wfn_dir."/bin/wfn.bat ").$wfn_parameters."\n";
          print BAT_RUN "CALL ".win_path($wfn_dir."/bin/".$wfn_option.".bat ".$file."_bs".$_." ".$_." ".($_ + $per_run -1)."\n");
          print BAT_RUN "del ".win_path($cwd."\\".$file."_".$_.".".$setting{ext_ctl})."\n";
          close BAT_RUN;
          if ($cluster_active == 1) {
            $count += generate_zink_file($setting{zink_host}, $setting{cluster_drive}, "Bootstrap ".$file, 3, win_path($cwd), win_path($cwd."\\".$rand_filename."_".$_).".bat\n", "");
          } else {
            open (BAT,">".$rand_filename.".bat");
            print BAT "start /low /b ".$rand_filename."_".$_.".bat\n";
            close BAT;
          }
        }
        message ("WFN bootstrap scheduled, ".$count." job specification file(s) created.");
        db_log_execution ($file, @ctl_descr[$file], "WFN", "Local", win_path($wfn_dir."/bin/".$wfn_option.".bat ".$file." ".$wfn_run_parameters), $setting{username} );
      } else {
        open (BAT,">".$rand_filename.".bat");
        print BAT "CALL ".win_path($wfn_dir."/bin/wfn.bat ").$wfn_parameters."\n";
        print BAT "CALL ".win_path($wfn_dir."/bin/".$wfn_option.".bat ".$file." ".$wfn_run_parameters)."\n";
        close BAT;
        db_log_execution ($file, @ctl_descr[$file], "WFN", "Local", win_path($wfn_dir."/bin/".$wfn_option.".bat ".$file." ".$wfn_run_parameters), $setting{username} );
        if ($cluster_active == 1) {
          if (generate_zink_file($setting{zink_host}, $setting{cluster_drive},"Bootstrap ".$file, 3, win_path($cwd), "CALL ".win_path($cwd."\\".$rand_filename).".bat\n", "") == 1) {
            message ("WFN job scheduled.");
            db_log_execution ($file, @ctl_descr[$file], "WFN", "PCluster", win_path($wfn_dir."/bin/".$wfn_option.".bat ".$file." ".$wfn_run_parameters), $setting{username} );
          };
        }
      }
  status ();
  unless ($cluster_active == 1) {
    return $rand_filename.".bat";
  } else {
    return ();
  }
}

sub exec_run_nmq {
### Purpose : Execute a NM model file through NMQual
### Compat  : W+
  status ("Starting run(s) using NMQual");
      ($nmq_path, $files_ref, $nmq_parameters) = @_;
      undef(my @files);
      if (-e $files_ref.".".$setting{ext_ctl}) {  # if a file is specified instead of an array reference containing files
        @files[0] = $files_ref;
      } else {
        @files = @$files_ref;
      }
      print @files[0];
      unlink <pirana_nmq_????.bat>; # clean up old batch files
      $rand_filename = "pirana_nmq_".generate_random_string(4).".bat";
      open (BAT,">".$rand_filename);
      print BAT "SET PATH=".$setting{nmq_env_path}.";%PATH%; \n";
      print BAT "SET LIBRARY_PATH=".$setting{nmq_env_libpath}.";%LIBRARY_PATH% \n";
      $nmq_name = get_nmq_name($nmq_path);
      foreach (@files) {
        if ($cluster_active==0) {
           print BAT win_path("perl -S ".$nmq_path."/test/".$nmq_name.".pl ".$_.".".$setting{ext_ctl}." ".$_.".".$setting{ext_res}." ".$nmq_parameters)."\n";
        } else {
           print BAT win_path("perl -S ".$nmq_path."/test/".$nmq_name."_compile.pl ".$_.".".$setting{ext_ctl}." ".$_.".".$setting{ext_res}." ".$nmq_parameters)."\n";
        }
      }
      close BAT;
      status ();
      return $rand_filename;
}

sub compile_run_nmq {
### Purpose : Compile a nonmem.exe (but give it a random name) using NMQual method
### Compat  : W+L?
   status ("Compiling run using NMQual");
      ($nmq_path, $file_string, $nmq_parameters) = @_;
      unlink <pirana_nmq_?????.bat>; # clean up old batch files
      $rand_filename = "pirana_nmq_".generate_random_string(4).".bat";
      open (BAT,">".$rand_filename);
      print BAT "SET PATH=".$setting{nmq_env_path}.";%PATH%; \n";
      print BAT "SET LIBRARY_PATH=".$setting{nmq_env_libpath}.";%LIBRARY_PATH% \n";
      my $nmq_name = get_nmq_name($nm_dir);
      print BAT win_path("perl -S ".$nmq_path."/test/".$nmq_name."_compile.pl ".$file_string." ".$nmq_parameters)."\n";
      close BAT;
    status();
    return $rand_filename;
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
  my $param = shift;
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
        -variable => \$active_project,-background=>"#202099",-activebackground=>"#5050aa",-font=>$font_bold, -foreground=>'white', -activeforeground=>'white')
     -> grid(-row=>1,-column=>2,-columnspan=>1, -sticky=>'we');
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
  $frame_dir -> Label(-text=>'Project:',-font => $font_normal, -background=>$bgcol)-> grid(-row=>1,-column=>1, -sticky => 'e');
  $frame_dir -> Label(-text=>'Folder:',-font => $font_normal, -background=>$bgcol)-> grid(-row=>2,-column=>1, -sticky => 'e');
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

  #$frame_dir -> Label (-text=>"  ", -background=>$bgcol, -width=>36)->grid(-row=>1,-column=>2, -sticky => 'wens');
  our $save_button = $frame_dir -> Button(-image=>$gif{save}, -border=>$bbw, -background=>$button,-activebackground=>$abutton, -width=>22, -height=>22, -command=> sub{
    save_project($cwd) })
    ->grid(-row=>1,-column=>3, -sticky => 'we');
  $help->attach($save_button, -msg => "Save this folder as project");
  our $edit_proj_button = $frame_dir -> Button(-image=>$gif{edit_info_blue}, -border=>$bbw, -background=>$button,-activebackground=>$abutton, -width=>22, -height=>22, -command=> sub{
      project_info_window();
    })->grid(-row=>1,-column=>4, -sticky => 'ens');
  $help->attach($edit_proj_button, -msg => "Edit project details");
  our $delete_button = $frame_dir -> Button(-image=>$gif{trash}, -border=>$bbw, -background=>$button, -activebackground=>$abutton, -width=>22, -height=>22, -command=> sub{
    del_project(); })
    ->grid(-row=>1,-column=>5, -rowspan=>1, -sticky => 'we');
  $help->attach($delete_button, -msg => "Delete project");
  our $reload_button = $frame_dir -> Button(-image=>$gif{reload}, -border=>$bbw, -background=>$button, -activebackground=>$abutton, -width=>22, -height=>22, -command=> sub{
      refresh_pirana($cwd);
    })
    ->grid(-row=>1,-column=>6, -rowspan=>1, -sticky => 'we');
  $help->attach($reload_button, -msg => "Refresh directory");
  $frame_dir -> Label(-text=>'   ', -background=>$bgcol)-> grid(-row=>3,-column=>1, -sticky => 'we');
}

sub show_exec_runs_window {
### Purpose : Show a dialog that displays a log of executed runs
### Compat  : W+L?
  unless ($exec_runs_window) {
    our $exec_runs_window = $mw -> Toplevel(-title=>'Execution log in '.$cwd);
    $exec_runs_window -> resizable( 0, 0 );
    $exec_runs_window -> OnDestroy ( sub{
      undef $exec_runs_window; undef $exec_runs_window_frame;
    });
    $exec_runs_window_frame = $exec_runs_window -> Frame(-background=>$bgcol)->grid(-column=>1, -row=>1, -ipadx=>10,-ipady=>10);
    our $exec_runs_hlist = $exec_runs_window_frame ->Scrolled('HList', -head => 1,
        -columns    => 7, -scrollbars => 'e', -highlightthickness => 0,
        -height     => 30, -border     => 0,
        -width      => 140, -background => 'white',
        -selectbackground => $pirana_orange,
        -browsecmd => sub{
          my @run_info = $exec_runs_hlist -> infoSelection();
        }
    )->grid(-column => 1, -columnspan=>7,-row => 1, -sticky=>"wens");
    my @headers = ( "Run", "Description", "Date/time", "NM", "Location", "Researcher", "Command");
    my @headers_widths = (80, 160, 130, 40, 40,50,600);
    my $headerstyle = $models_hlist->ItemStyle('window', -padx => 0);
    foreach my $x ( 0 .. $#headers ) {
        @exec_runs_headers[$x] = $exec_runs_hlist -> HdrResizeButton(
          -text=> $headers[$x], -relief=>'groove', -column=>$x,
          -background=>$button, -activebackground=>$abutton, -activeforeground=>'black',
          -border=>0, -pady =>$header_pad, -resizerwidth => 2);
        $exec_runs_hlist->header('create', $x,
          -itemtype => 'window', -style=> $headerstyle,
          -widget => @exec_runs_headers[$x]
        );
        $exec_runs_hlist -> columnWidth($x, @headers_widths[$x]);
    }
  }
  $db_results = db_read_exec_runs();
  my $i=0;
  $style = $models_hlist-> ItemStyle( 'text', -anchor => 'nw',-padx => 5, -background=>'white', -font => $font_normal);;
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
  $exec_runs_window_frame -> Button(-text=>'Refresh', -width=>4, -border=>$bbw,-background=>$button,-activebackground=>$abutton,-command=> sub{
    $exec_runs_hlist -> delete("all");
    show_exec_runs_window();
  })->grid(-row=>2,-column=>1,-sticky=>'news');
  $exec_runs_window_frame -> Button(-text=>'Delete log', -width=>4, -border=>$bbw,-background=>$button,-activebackground=>$abutton,-command=> sub{
    db_execute ("DELETE FROM executed_runs");
    $exec_runs_hlist -> delete("all");
    $exec_runs_hlist -> update();
  })->grid(-row=>2,-column=>2,-sticky=>'news');
}

sub show_inter_window {
### Purpose : Show a dialog that displays intermediate OFVs, param.estims and gradients for runs in the current folder and below
### Compat  : W+
    my $wd = shift;
    unless (-d $wd) {$wd = $cwd}
    unless ($inter_window) { # build the dialog
      our $inter_window = $mw -> Toplevel(-title=>'Progress of runs in '.$wd, -background=>$bgcol);
      $inter_window -> resizable( 0, 0 );
      $inter_window -> OnDestroy ( sub{
        undef $inter_window; undef $inter_window_frame;
      });
      $inter_window -> iconimage($gif{network}); # doesn't work properly for some reaseon
      $inter_window_frame = $inter_window -> Frame(-background=>$bgcol)->grid(-ipadx=>10,-ipady=>0);
      our $inter_dirs;
      $inter_frame_status = $inter_window -> Frame(-relief=>'sunken', -border=>0, -background=>$status_col)->grid(-column=>0, -row=>4, -ipadx=>10, -sticky=>"nws");
      $inter_status_bar = $inter_frame_status -> Label (-text=>"Status: Idle", -justify=>"l", -anchor=>"w", -font=>$font_normal,-width=>96, -background=>$status_col)->grid(-column=>1,-row=>1,-sticky=>"we");
      $inter_frame_buttons = $inter_window_frame -> Frame(-relief=>'sunken', -border=>0, -background=>$bgcol)->grid(-column=>1, -row=>2, -ipady=>0, -sticky=>"wns");
      $inter_frame_buttons -> Button (-text=>'Rescan directories',  -width=>20, -border=>$bbw,-background=>$button, -activebackground=>$abutton,-command=>sub{
        $grid -> delete("all");
        inter_status ("Searching sub-directories for active runs...");
        @n = get_runs_in_progress($wd);
        if ( int(@n) == 1 ) {
          inter_status ("No active runs found");
        } else {inter_status()};
      }) -> grid(-column => 1, -row=>1, -sticky=>"wns");
      $inter_frame_buttons -> Button (-text=>'Open intermediate files',  -width=>20, -border=>$bbw,-background=>$button, -activebackground=>$abutton,-command=>sub{
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
      $inter_frame_buttons -> Button (-text=>'Refresh estimates',  -width=>20, -border=>$bbw,-background=>$button, -activebackground=>$abutton,-command=>sub{
       #get all
         foreach (@inter_dirs) { };
         @info = $grid->infoSelection();
         $grid_inter -> delete("all");
         inter_results ($wd."/".@info[0]);
      }) -> grid(-column => 3, -row=>1, -sticky=>"w");

      ## Stop run functionality: not yet implemented (has issues)
      #$inter_frame_buttons -> Button (-text=>'Stop run', -width=>20, -border=>$bbw,-background=>$button, -activebackground=>$abutton,-command=>sub{
      #   @info = $grid->infoSelection();
      #   foreach (@info) {
      #     ;
      #   }
      #}) -> grid(-column => 3, -row=>1, -sticky=>"w");

      $inter_window_frame -> Label (-text=>' ',  -width=>9, -background=>$bgcol, -font=>"Arial 3") -> grid(-column => 1, -row=>0, -sticky=>"w");
      $inter_frame_buttons -> Label (-text=>' ',  -width=>9, -background=>$bgcol) -> grid(-column => 1, -row=>2, -sticky=>"w");
      $inter_intermed_frame = $inter_window -> Frame(-relief=>'sunken', -border=>0, -background=>$bgcol)->grid(-column=>0, -row=>3, -ipadx=>10, -sticky=>"nws");
      $inter_intermed_frame -> Label (
        -text=>"\nNote: to obtain intermediate estimates from runs, the specification\nof MSF files are needed. For increasing the number of \nparameter updates, use e.g. PRINT=1 in the $EST block.",
        -font=>$font, -foreground=>"#666666", -justify=>'l',-background=>$bgcol) -> grid(-column => 1, -row=>2, -columnspan=>1, -sticky=>"w");
      $inter_intermed_frame -> Label (-text=>' ',  -width=>9, -background=>$bgcol) -> grid(-column => 1, -row=>3, -sticky=>"w");
    } else {$inter_window -> focus};
    inter_status ("Searching sub-directories for active runs...");
    chdir ($wd);

    my @headers = ( "MSF", "Iterations","OFV");
    my @headers_widths = (60, 60, 60, 160,240);

    our $grid = $inter_window_frame ->Scrolled('HList', -head => 1,
        -columns    => 5, -scrollbars => 'e',-highlightthickness => 0,
        -height     => 6, -border     => 0, -selectbackground => $pirana_orange,
        -width      => 110, -background => 'white'
    )->grid(-column => 1, -columnspan=>7,-row => 1, -sticky=>"wens");

    my @headers_inter = (" ","Theta", "Omega","Sigma", "Gradients", " ");
    my @headers_inter_widths = (24, 54, 54, 54, 54);

    our $grid_inter = $inter_intermed_frame ->Scrolled('HList', -head => 1,
        -columns    => 6, -scrollbars => 'e', -highlightthickness => 0,
        -height     => 18, -border     => 0, -selectbackground => $pirana_orange,
        -width      => 45, -background => 'white',
    )->grid(-column => 1, -columnspan=>1, -row => 1, -sticky=>"nw");
    foreach my $x ( 0 .. $#headers ) {
        $grid -> header('create', $x, -text=> $headers[$x], -style=> $header_right, -headerbackground => 'gray');
        $grid -> columnWidth($x, @headers_widths[$x]);
    }
    $grid -> header('create', 3, -text=> "Folder", -style=> $header_left, -headerbackground => 'gray');
    $grid -> header('create', 4, -text=> "Description", -style=> $header_left, -headerbackground => 'gray');
    $grid -> columnWidth(3, @headers_widths[3]);
    $grid -> columnWidth(4, @headers_widths[4]);

    $x=0; foreach (@headers_inter) {
      if ($x==5) {$style = $header_left} else {$style = $header_right};
      $grid_inter -> header('create', $x, -text=> $headers_inter[$x], -style=> $style, -headerbackground => 'gray');
      $grid_inter -> columnWidth($x, @headers_inter_widths[$x]);
      $x++;
    }

   # create the gradient plot
   $plot_frame = $inter_intermed_frame -> Frame (-relief=>'groove', -background=>$bgcol, -border=>0, -height=>10) -> grid(-column=>2, -row=>1, -rowspan=>3, -sticky=>'nwe');
   my @plot_title = ("",20);
   @border = (8,55,40,52); # top, right, bottom, lef
   our $gradients_plot = $plot_frame -> PlotDataset
    ( -width => 360, -height => 300,
      -background => $bgcol, -border=> \@border,
      -plotTitle => \@plot_title,
      -xlabel => "Iteration", -ylabel => "Gradient",
      -y1label => 'OFV', -xType => 'linear', -yType => 'linear',
      -y1TickFormat => "%d", -xTickFormat => "%g", -yTickFormat => "%d"
    ) -> grid(-column=>2, -row=>1);
   $gradients_plot -> configure (-fonts =>
     ['Arial 7',   # axes ticks
      'Arial 8 italic', # axes labels
      'Arial 9 bold',  # title
      'Arial 7' # legend
      ]);
   $grid_inter -> update();
   $grid -> configure(-browsecmd => sub{ # can only be implemented at the end of the subroutine
          # this is a workaround to avoid difficulties induced by the Hlist widget (browsecmd is issued twice)
          # still sometimes, an error occurs (may be a bug in Tk::PlotDataset)
          $diff = str2time(localtime()) - $last_time;
          our $last_time = str2time(localtime());
          my @info = $grid->infoSelection();

          if (($diff > 0)||($last_chosen ne @info[0])) {
            our $last_chosen = @info[0];
            chdir ("./".@info[0]);
            my ($sub_iter, $sub_ofv, $descr, $minimization_done) = get_run_progress();
            chdir ($wd);
            inter_results ($wd."/".@info[0]);
            $gradients_plot -> clearDatasets;
            my $lines_ref = update_gradient_plot($sub_iter);
            my $gradient_info = $plot_frame -> Balloon();
            unless ($lines_ref == 0) {
              my @lines = @$lines_ref;
              foreach my $line (@lines) {
                if ($line =~ m/linegraph/i) { # test if correct Tk format
                  $gradients_plot -> addDatasets($line);
                }
              }
            }
            my $ofv_line = update_ofv_plot($sub_iter);
            unless ($ofv_line == 0) {
              if ($ofv_line =~ m/linegraph/i) { # test if correct Tk format
                $gradients_plot -> addDatasets($ofv_line);
              }
            }
            $gradients_plot -> plot;
          }
   });
   our @n = get_runs_in_progress($wd);
   if ( int(@n) == 1 ) {
         inter_status ("No active runs found");
  } else {inter_status()};
}

sub update_gradient_plot {
  my $sub_iter = shift;
  my @x_all; my @y_all;
  for (my $n_iter=1; $n_iter <= $sub_iter; $n_iter++) {
     for (my $n_grad=1; $n_grad <= @gradients; $n_grad++) {
       my $gradient = shift (@all_gradients);
       if (!($gradient =~ m/na/i)) {
         my $x_ref = @x_all[$n_grad];
         my $y_ref = @y_all[$n_grad];
         my @x = @$x_ref;
         my @y = @$y_ref;
         push (@x, $n_iter);
         push (@y, $gradient);
         @x_all[$n_grad] = \@x;
         @y_all[$n_grad] = \@y;
       };
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
  my $sub_iter = shift;
  my @x = (1 .. $sub_iter);
  my $line = LineGraphDataset -> new (
        -name => "OFV",
        -xData => \@x,
        -yData => \@all_ofv,
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
    unless ($item =~ m/HASH/) {  # for some reason this sometimes is necessary.
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
    my $wd = shift();
    unless (-d $wd) {$wd = $cwd}
  $dir = fastgetcwd()."/";
  @dirs = read_dirs($wd, "");
  %dir_results = new ;
  %res_iter = {}; %res_ofv = {}; %res_runno = {};  %res_dir = {}; %res_descr = {};
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
      #}
    }
  # check directories
  foreach (@dirs) {
    chdir($_);
    $sub = fastgetcwd();
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
    if ($sub =~ m/_/) { # only do this for PsN- or nmfe directories, to save speed
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
  return (keys (%res_iter));
}

sub get_run_progress {
### Purpose : Return the number of iterations and OFV of a currently running model
### Compat  : W+L+
  my $output_file = shift;
  @l = dir (".", $setting{ext_res});
  if (int(@l)>0) {
    $output_file = @l[0];
  }
  if ((-e "OUTPUT")&&(-s "OUTPUT" >0)) {$output_file = "OUTPUT"};
  $sub_iter =""; $sub_ofv="";
  open (OUT,"<".$output_file);
  @lines = <OUT>;
  close OUT;
  undef our @gradients;      # global variable, bad design, but for some reason local variables are not transferred correctly
  undef our @all_gradients;
  undef our @all_ofv;
  undef our $sub_iter;
  undef our $sub_ofv;
  my $minimization_done = 0;
  foreach $line (@lines) {
     if($line =~ m/ITERATION/gi) {
       our $sub_iter = substr($line,15,9);
       $sub_iter =~ s/\s//g;
       our $sub_ofv = substr($line,41,12);
       $sub_ofv =~ s/\s//g;
       $sub_ofv = rnd($sub_ofv, 7);
       push (@all_ofv, $sub_ofv);
       our $sub_eval = substr($line,76,3);
       $sub_eval =~ s/\s//g;
     }
     if ($line =~ m/GRADIENT/) {
       push (@all_gradients, @gradients);
       delete @gradients[0..@gradients];
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
  @m = dir (".", $setting{ext_ctl});
  my $mod_ref;
  if ((@m == 1)||(@m[0] =~ m/psn/gi)) {
    my $modelno = @m[0];
    my $modelno =~ s/\.$setting{ext_ctl}//;
    $mod_ref = extract_from_model (@m[0], $modelno,"")
  }
  my %mod = %$mod_ref;
  return ($sub_iter, $sub_ofv, $mod{description}, $minimization_done);
}

sub inter_results {
### Purpose : update dialog with intermediat results
### Compat  : W+L+
  my $dir = shift;
  ($thetas_ref, $omegas_ref, $sigmas_ref) = extract_inter($dir);
  my @thetas = @$thetas_ref;
  my @omegas = @$omegas_ref;
  my @sigmas = @$sigmas_ref;
  $inter_window -> update();
  $i=1; $n=0;
  $grid_inter -> delete("all");
  $grid_inter -> update();
  foreach (@thetas) {
    $grid_inter->add($i);
    $grid_inter->itemCreate($i, 0, -text => $i, -style=>$header_right);
    $grid_inter->itemCreate($i, 1, -text => $_, -style=>$align_right);
    $i++;
  }
  $n = $i-1;
  $i = 1;
  foreach (@omegas) {
    if ($i > $n) {
        $n = $i;
        $grid_inter->add($i);
    }
    $grid_inter->itemCreate($i, 2, -text => $_, -style=>$align_right);
    $i++;
  }
  $i=1;
  foreach (@sigmas) {
    if ($i > $n) {
        $n = $i;
        $grid_inter->add($i);
    }
    $grid_inter->itemCreate($i, 3, -text => $_, -style=>$align_right);
    $i++;
  }
  $i=1;
  foreach (@gradients) {
    if ($i > $n) {
        $n = $i;
        $grid_inter -> add($i);
    }
    my $style;
    if ($_ == 0) {
      $style = $align_right_red
    } else {
      $style = $align_right;
    }
    $grid_inter->itemCreate($i, 4, -text => $_, -style=>$style);
    $i++;
  }
}

sub extract_inter {
### Purpose : extract intermediate results from files in a folder
### Compat  : W+
  my $dir = shift;
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

  $no_lines = int(@inter);
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

    ### Gather ETA's
    my $eta_line_no = $theta_line_no+5;
    if ($inter[$no_lines+$eta_line_no+1]=~/ET/g) {$eta_line_no++};
    if ($inter[$no_lines+$eta_line_no+1]=~/ET/g) {$eta_line_no++};
    if ($inter[$no_lines+$eta_line_no+1]=~/ET/g) {$eta_line_no++};
    my $curr_lineno = $no_lines + $eta_line_no + 2;
    my @etas = ();

    until ((@inter[$curr_lineno] =~ m/SIGMA/)||($curr_lineno>@inter)) {
      if ((@inter[$curr_lineno] =~ m/ET/) && (@inter[$curr_lineno+1] ne "")) { # read ETA from subsequent lines
        $eta_line = @inter[$curr_lineno+1];
        if(@inter[$curr_lineno+2] =~ m/\./) {
          $eta_line = @inter[$curr_lineno+2];
        };
        if(@inter[$curr_lineno+3] =~ m/\./) {
          $eta_line = @inter[$curr_lineno+3];
        };
        @eta_arr = split(/\s/,$eta_line);
        @eta_arr = grep /\S/, @eta_arr;
        my $eta;
        if (@eta_arr>0) {$eta = rnd(@eta_arr[@eta_arr-1],5)} else {$eta = ""};
        push (@etas, $eta);
      }
      $curr_lineno++;
    }
    my @epss = ();
    if (@inter[$curr_lineno] =~ m/SIGMA/) {
      while (($curr_lineno < @inter)&&!(@inter[$curr_lineno] =~ m/ITERATION/gi)) {
        if (@inter[$curr_lineno] =~ m/\./) {
          $eps_line = @inter[$curr_lineno];
          @eps_arr = split(/\s/,$eps_line);
          @eps_arr = grep /\S/, @eps_arr;
          $eps = rnd(@eps_arr[@eps_arr-1],5);
          push (@epss,$eps);
        }
        $curr_lineno++;
      }
    }
    return \@thetas, \@etas, \@epss;
  } else {return (0)}
}

sub combine_wfn_bootstraps {
### Purpose : Combine WFN bootstrap results into a combined file
### Compat  : W+L+
### Notes   : beta
  my @bs_dirs = <*_bs*>;  # get all possible bootstrap dirs
  foreach (@bs_dirs) {    # check if it is a directory
    my $file = $_;
    $file =~ s/\.bs//ig;
    if ((-d $_)&&(-e $_."/".$file.".txt")) {push (@bs_files, $_."/".$file.".txt")}
  }
  my @all_runs; my $flag = 0;
  foreach (@bs_files) {
    $file = $_;
    open (BS, "<".$_);
    @lines = <BS>;
    foreach (@lines) {
      if ((substr($_,0,1) ne "#")||($flag==0)) {push (@all_runs, $_)};
      if (substr($_,0,1) eq "#") {$flag = 1};
    }
    close BS;
  }
  open (ALL, ">bs.txt");
  print ALL @all_runs;
  close ALL;
  if (-e $software{spreadsheet}) {
      start_command($software{spreadsheet},'"'.win_path("bs.txt").'"');
  } else {message("Spreadsheet application not found. Please check settings.")};
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
    $duplicates_window -> resizable( 0, 0 );
    center_window($duplicates_window);
    $duplicates_frame = $duplicates_window->Frame(-background=>$bgcol)->grid(-ipadx=>8, -ipady=>8);
    $duplicates_frame -> Label (-background=>$bgcol, -text=>"This will create n copies from one or more model(s),\nadding a suffix (i.e. 'model_001', 'model_002' etc).",-font=>$font_normal,-justify=>"left")->grid(-row=>1, -column=>1, -columnspan=>2,-sticky=>"nw");
    $duplicates_frame -> Label (-background=>$bgcol, -justify=>'left',-text=>" ",-font=>$font_normal,)->grid(-row=>2, -column=>1, -columnspan=>2,-sticky=>"nw");
    $duplicates_frame -> Label (-background=>$bgcol, -text=>"Duplicate models:",-font=>$font_normal,)->grid(-row=>3, -column=>1, -sticky=>"ne");
    $duplicates_frame -> Label (-background=>$bgcol, -justify=>'left',-text=>" ",-font=>$font_normal,)->grid(-row=>4, -column=>1, -columnspan=>2,-sticky=>"nw");
    $duplicates_frame -> Label (-background=>$bgcol, -text=>"Number of duplicates:",-font=>$font_normal,)->grid(-row=>5, -column=>1, -sticky=>"ns");
    $duplicates_frame -> Entry (-textvariable=>\$no_duplicates,-font=>$font_normal,-width=>8, -background=>$white)->grid(-row=>5, -column=>2, -sticky=>"nws");
    $duplicates_frame -> Label (-background=>$bgcol, -justify=>'left',-text=>" ",-font=>$font_normal)->grid(-row=>6, -column=>1, -columnspan=>2,-sticky=>"nw");
    $duplicates_frame -> Checkbutton (-background=>$bgcol, -text=>"Change run-numbers in ouput/tables?",  -selectcolor=>$selectcol, -activebackground=>$bgcol, -variable=>\$change_run_nos)->grid(-row=>7,-column=>2,-sticky=>'w');
    $duplicates_frame -> Checkbutton (-background=>$bgcol, -text=>"Use final parameter estimates from reference model?", -selectcolor=>$selectcol, -activebackground=>$bgcol, -variable=>\$est_as_init)->grid(-row=>8,-column=>2,-sticky=>'w');
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
    $duplicates_frame -> Button (-text=>"Do", -width=>16, -background=>$button, -border=>$bbw, -activebackground=>$abutton, -command=> sub {
      my $no_changed = 0;
      foreach my $mod (@batch) {
        for ($k=1; $k<=$no_duplicates; $k++) {
          duplicate_model ($mod, $mod."_".sprintf($format, $k), "", $mod, $change_run_nos, $est_as_init, \%setting);
          $no_changed++;
        }
      }
      message("Duplicated ".$no_changed." models.");
      $duplicates_window -> destroy;
      return();
    })->grid(-row=>10,-column=>2,-sticky=>'nws');
    $duplicates_frame -> Button (-text=>"Cancel", -width=>16, -background=>$button, -border=>$bbw, -activebackground=>$abutton, -command=> sub {
      $duplicates_window -> destroy;
      return();
    })->grid(-row=>10, -column=>1,-sticky=>'nes');
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
    $replace_block_window -> resizable( 0, 0 );
    center_window($replace_block_window);
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
      -> grid(-row=>5, -column=>2, -ipady=>5, -columnspan=>2, -sticky=>"nwse");
    $replace_block_frame -> Label (-text=>"Models:",-font=>$font_normal, -background=>$bgcol)->grid(-row=>7, -column=>1, -sticky=>"ne");
    $replace_block_text = $replace_block_frame -> Scrolled ('Text', -background=>'white', -font=>$font_normal,-width=>18, -height=>8, -scrollbars=>'e')
      -> grid(-row=>7, -column=>2, -ipady=>5, -columnspan=>2, -sticky=>"nws");
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
    $replace_block_frame -> Button (-text=>"Do", -width=>10, -background=>$button, -border=>$bbw, -activebackground=>$abutton, -command=> sub {
      my $replace_with = $block_replace -> get("0.0", "end");
      my $no_changed = replace_block(\@batch, $block, $replace_with);
      message($block." block changed in ".$no_changed." models.");
      $replace_block_window -> destroy;
      return();
    })->grid(-row=>10,-column=>2,-sticky=>'nws');
    $replace_block_frame -> Button (-text=>"Cancel", -width=>10, -background=>$button, -border=>$bbw, -activebackground=>$abutton, -command=> sub {
      $replace_block_window -> destroy;
      return();
    })->grid(-row=>10,-column=>1,-sticky=>'nes');
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
    $add_code_window -> resizable( 0, 0 );
    center_window($add_code_window);
    $add_code_frame = $add_code_window->Frame(-background=>$bgcol)->grid(-ipadx=>8, -ipady=>8);
    my $block = "\$TABLE";
    $add_code_frame -> Label (-text=>"This will add the specified code at the end\nof the selected model files.\n",
        -font=>$font_normal,-justify=>"left", -background=>$bgcol)
      ->grid(-row=>1, -column=>1, -columnspan=>2,-sticky=>"nw");
    $add_code_frame -> Label (-text=>"Code:",-font=>$font_normal, -background=>$bgcol)
      ->grid(-row=>5, -column=>1, -sticky=>"ne");
    my $code_entry = $add_code_frame -> Scrolled ('Text', background=>'white', -font=>$font_normal, -width=>30, -height=>8, -scrollbars=>'e')
      -> grid(-row=>5, -column=>2, -ipady=>5, -columnspan=>2, -sticky=>"nwse");
    $add_code_frame -> Label (-text=>"Models:",-font=>$font_normal, -background=>$bgcol)->grid(-row=>7, -column=>1, -sticky=>"ne");
    $add_code_text = $add_code_frame -> Scrolled ('Text', background=>'white', -font=>$font_normal,-width=>18, -height=>8, -scrollbars=>'e')
      -> grid(-row=>7, -column=>2, -ipady=>5, -columnspan=>2, -sticky=>"nws");
    $add_code_frame -> Label (-justify=>'left',-text=>" ",-font=>$font_normal, -background=>$bgcol)->grid(-row=>4, -column=>1, -columnspan=>2,-sticky=>"nw");
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
    $add_code_frame -> Button (-text=>"Do", -width=>16, -background=>$button, -border=>$bbw, -activebackground=>$abutton, -command=> sub {
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
    $add_code_frame -> Button (-text=>"Cancel", -width=>16, -background=>$button, -border=>$bbw, -activebackground=>$abutton, -command=> sub {
      $add_code_window -> destroy;
      return();
    })->grid(-row=>10,-column=>1,-sticky=>'nes');
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
    $sim_seed_window -> resizable( 0, 0 );
    center_window($sim_seed_window);
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
    $sim_seed_frame -> Button (-text=>"Do", -width=>10, -background=>$button, -border=>$bbw, -activebackground=>$abutton, -command=> sub {
      my $no_changed = 0;
      foreach my $mod (@batch) {
        change_seed($mod);
        $no_changed++;
      }
      message("\$SIM block changed in ".$no_changed." models.");
      #$sim_seed_window -> destroy;
      return();
    })->grid(-row=>7,-column=>2,-sticky=>'nws');
    $sim_seed_frame -> Button (-text=>"Cancel", -width=>10, -background=>$button, -border=>$bbw, -activebackground=>$abutton, -command=> sub {
      $sim_seed_window -> destroy;
      return();
    })->grid(-row=>7,-column=>1,-sticky=>'nes');
}


