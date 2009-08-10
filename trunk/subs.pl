#    ----------------------------------------------------------------------
#    Pira�a
#    Copyright Ron Keizer, 2007-2009, Amsterdam, the Netherlands
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
# As much as possible, subs are located in separate modules

sub get_psn_nm_versions {
### Purpose : Retrieve the NM versions specified to psn. (reads a pipe from "psn -nm_versions") 
### Compat  : W+L+
### Notes   : When the psn command is invoked but cannot be found, Pirana crashes
  my @split;
  our $max_psn_name;
  my %psn_nm_versions; my %psn_nm_versions_vers;
  if ($software{psn_dir} =~ m/perl/i) {  # use the PsN that is specified, not necisssarily the one in the system variables 
    my $psn_dir = $software{psn_dir};
    @split = split(/\\/,$psn_dir); 
  }
  my $command;
  unless (($setting{use_cluster}==1)&&($gif{cluster_active}==1)) {
    if (-e @split[0]."\\".@split[1]."\\bin\\psn") {
      $command = @split[0]."\\".@split[1]."\\bin\\psn -nm_versions";
    } else {$command = "psn -nm_versions";}
  } else {  # on cluster using SSH
      $command = $setting{ssh_login}.' '.$software{psn_on_cluster}.'"psn -nm_versions &"';
  }
  if ($stdout) {$stdout -> insert('end', "\n".$command);};
  open (OUT, $command." |") or die "Could not open command: $!\nCheck installation of PsN.";
  $flag = 0;
  my %psn_nm_versions;
  while (my $line = <OUT>) {
     if ($line =~ m/will call/gi) {
       my ($nm_name, $nm_loc) = split(/\(will call /,$line);
       my ($nm_loc, $nm_ver) = split (/,/, $nm_loc);
       $nm_name =~ s/\s//g;
       chomp($nm_ver); $nm_ver =~ s/\)//;
     #  $nm_name = substr($nm_name,0,9);
       if(length($nm_name)>$max_psn_name) {$max_psn_name=length($nm_name)}
       $psn_nm_versions{$nm_name} = $nm_loc;
       $psn_nm_versions_vers{$nm_name} = $nm_ver;
     }
  }
  if ($max_psn_name<9) {$max_psn_name=9};
  return \%psn_nm_versions, \%psn_nm_versions_vers;  
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
  $cov_calc_dialog -> Popup;
  my $cov_calc_frame = $cov_calc_dialog-> Frame()->grid(-ipadx=>'10',-ipady=>'10',-sticky=>'n');
  $cov_calc_frame -> Label (-text=>"Covariance block:") -> grid(-row=>1, -column=>1);
  my $var1=1; my $covar=1; my $var2=1;
  $var1_entry  = $cov_calc_frame -> Entry (-width=>6, -textvariable=>\$var1, -justify=>"right") -> grid(-row=>1, -column=>2);
  $covar_entry = $cov_calc_frame -> Entry (-width=>6, -textvariable=>\$covar,-justify=>"right") -> grid(-row=>2, -column=>2);
  $var2_entry  = $cov_calc_frame -> Entry (-width=>6, -textvariable=>\$var2,-justify=>"right") -> grid(-row=>2, -column=>3);
  $var1_entry -> bind('<Any-KeyPress>' => sub { recalc_cov($var1,$var2,$covar)});
  $var2_entry -> bind('<Any-KeyPress>' => sub { recalc_cov($var1,$var2,$covar)});
  $covar_entry -> bind('<Any-KeyPress>' => sub {recalc_cov($var1,$var2,$covar)});
  $cov_calc_frame -> Label (-text=>" ") -> grid(-row=>3, -column=>1);
  $cov_calc_frame -> Label (-text=>"SD1:", -foreground=>"#666666") -> grid(-row=>4, -column=>1,-sticky=>'e');
  $cov_calc_frame -> Label (-text=>"SD2:", -foreground=>"#666666") -> grid(-row=>5, -column=>1,,-sticky=>'e');
  $cov_calc_frame -> Label (-text=>"Correlation:", -foreground=>"#666666") -> grid(-row=>6, -column=>1,,-sticky=>'e');
  our $var1_sd=rnd(sqrt($var1),3); our $var2_sd=rnd(sqrt($var1),3); our $covar_sd=rnd(sqrt($covar/($var1_sd*$var2_sd)),3); 
  $var1_sd_entr = $cov_calc_frame -> Entry (-width=>6, -textvariable=>\$var1_sd, -justify=>"right", -background=>$bgcol, -foreground=>'#666666') -> grid(-row=>4, -column=>2);
  $var2_sd_entr = $cov_calc_frame -> Entry (-width=>6, -textvariable=>\$covar_sd,-justify=>"right", -background=>$bgcol, -foreground=>'#666666') -> grid(-row=>6, -column=>2);
  $covar_sd_entr = $cov_calc_frame -> Entry (-width=>6, -textvariable=>\$var2_sd,-justify=>"right", -background=>$bgcol, -foreground=>'#666666') -> grid(-row=>5, -column=>2);
}

sub recalc_cov {
### Purpose : Does the actual calculation used in cov_calc_window
### Compat  : W+L+
  my ($var1,$var2,$covar) = @_;
  if ($var1!=0) {$var1_sd=rnd(sqrt($var1),3);}
  if ($var2!=0) {$var2_sd=rnd(sqrt($var2),3);}
  if ($covar!=0) {$covar_sd=rnd(sqrt($covar/($var1_sd*$var2_sd)),3)};
  $var1_sd_entr -> update();
  $var2_sd_entr -> update();
  $covar_sd_entr -> update();
}

sub plot_corr_matrix {
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
  $vpc_dialog -> Popup;
  my $vpc_dialog_frame = $vpc_dialog-> Frame()->grid(-ipadx=>'10',-ipady=>'10',-sticky=>'n');
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
      win_start ($software{browser}, win_path($software{r_dir}.'/library/xpose4specific/html/xpose.VPC.html'));
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

sub run_script { 
### Purpose : Run a perl (or other type of) script and capture the console output
### Compat  : W+L?
  $command = shift;
  show_process_monitor($process_monitor);
  open (OUT, $command);
  if (defined $stdout) {
    while (my $line = <OUT>) {
      $stdout -> insert('end', $line);
      $mw -> update;
      $stdout -> yview (moveto=>1);
    }
  }
  close OUT;
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
  $msf_dialog -> Popup;
  $msf_dialog_frame = $msf_dialog-> Frame()->grid(-ipadx=>'10',-ipady=>'10',-sticky=>'n');
  
  $msf_dialog_frame -> Label (-text=>'New model number (without '.$setting{ext_ctl}.'):')->grid(-row=>1,-column=>1,-sticky=>"e");
  $msf_dialog_frame -> Entry (-width=>8, -border=>2, -relief=>'groove',
     -textvariable=>\$new_ctl_name)->grid(-row=>1,-column=>2,-sticky=>"w");  
  $msf_dialog_frame -> Label (-text=>'Restart using MSF file:')->grid(-row=>2,-column=>1,-sticky=>"e");
  my $restart_msf_entry = $msf_dialog_frame -> Entry (-width=>12, -border=>2, -relief=>'groove', -text=>$msf,
     -textvariable=>\$msf)->grid(-row=>2,-column=>2,-sticky=>"w");  
  $msf_dialog_frame -> Label (-text=>'New MSF file:')->grid(-row=>3,-column=>1,-sticky=>"e");
  my $new_msf_entry = $msf_dialog_frame -> Entry (-width=>12, -border=>2, -relief=>'groove', -text=>$new_msf,
     -textvariable=>\$new_msf)->grid(-row=>3,-column=>2,-sticky=>"w");
  $msf_dialog_frame -> Label (-text=>"\nNB. Parameter estimates will be commented out.\n", -foreground=>"#444444",-justify=>"left")->grid(-row=>5,-column=>1,-columnspan=>2,-sticky=>"w");
  $msf_dialog_frame -> Button (-text=>'Create', -width=>12, -border=>$bbw, -background=>$button, -activebackground=>$abutton,-command=>sub {
    my $overwrite_bool=1;
    if (-e $cwd."/".$new_ctl_name.".".$setting{ext_ctl}) {  # check if control stream already exists;
      my $overwrite = $mw -> messageBox(-type=>'yesno', -icon=>'question',
        -message=>"Control stream with name ".$new_ctl_name.".".$setting{ext_ctl}." already exists.\n Do you want to overwrite?"); 
      if( $overwrite eq "No") {$overwrite_bool=0;} 
    } else {$overwrite_bool=1};
    if ($overwrite_bool==1) {
      my $file = $cwd."/".@ctl_show[@runs[0]].".".$setting{ext_ctl};
      my $new_file = $cwd."/".$new_ctl_name.".".$setting{ext_ctl};
      print $new_file;
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
  }) -> grid(-row=>7,-column=>2,-sticky=>"w");
  $msf_dialog_frame -> Button (-text=>'Cancel ', -width=>12, -border=>$bbw, -background=>$button, -activebackground=>$abutton, -command=>sub{destroy $msf_dialog})->grid(-column=>1,-row=>7,-sticky=>"e");
};

sub edit_model {
### Purpose : Edit a modelfile, choose to invoke the built-in editor or a user-specified one
### Compat  : W+L?
  my $modelfile = shift;
  if (($software{editor} eq "")||(!(-e $software{editor}))) {
    open (IN, "<".$modelfile);
    my @lines = <IN>;
    close IN;
    my $text = join ("",@lines);
    text_edit_window ($text, $modelfile, \$mw);
  } else {
    win_start($software{editor}, $modelfile);
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
  unless ($project_window) {
    our $project_window = $mw -> Toplevel(-title=>'Project Information');
    $project_window -> OnDestroy ( sub{
       undef $project_window; undef $project_window_frame;
    });
    $project_window -> resizable( 0, 0 );
  }
  our $project_window_frame = $project_window -> Frame(-background=>$bgcol)->grid(-ipadx=>10,-ipady=>10)->grid(-row=>1,-column=>1, -sticky=>'nwse');
  my @labels  = ("Project name: ","Description: ","Modeler: ","Collaborators: ","Start date: ","End date: ");
  my @entries = ($active_project," ",$setting{name_researcher},"","","");
  my @widths  = (20, 40, 20, 40, 20, 20);
  my @sql_fields = ("proj_name","descr","modeler","collaborators","start_date","end_date"); 
  my %proj_record; my %proj_rec_entry;
  for ($i=0; $i<@labels; $i++) {
    $project_window_frame -> Label(-text=> @labels[$i], -font=>$font_normal) ->grid(-row=>($i*2)+1,-column=>1,-sticky=>'e');
    $proj_rec_entry{@sql_fields[$i]} = $project_window_frame -> Entry(-text=> @entries[$i], -font=>$font_normal, -relief=>'sunken',-border=>$bbw, -width=>@widths[$i]) -> grid(-row=>($i*2)+1,-column=>2,-sticky=>'w');
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
  $project_window_frame -> Label (-text=>'  ')->grid(-column=>2, -row=>30,-rowspan=>1);
  $project_window_frame -> Button (-text=>'Save', -width=>12, -background=>$button, -activebackground=>$abutton, -border=>$bbw, -command=>sub{  
    $sql = "UPDATE project_info SET ";
    foreach (keys(%proj_rec_entry)) {
      $proj_record{$_} = $proj_rec_entry{$_} -> get();
      print $_.": ".$proj_record{$_}."\n";
    }
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
    my @th = @$th_ref; my @om = @$om_ref; my @si = @$si_ref;
    my @th_se = @$th_se_ref; my @om_se = @$om_se_ref; my @si_se = @$si_se_ref;

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
      our $estim_window = $mw -> Toplevel(-title=>'Final parameter estimates');
      $estim_window -> OnDestroy ( sub{
        undef $estim_window; undef $estim_window_frame;
      });
      $estim_window -> resizable( 0, 0 );
    }
    our $estim_window_frame = $estim_window -> Frame(-background=>$bgcol)->grid(-ipadx=>10,-ipady=>0)->grid(-row=>1,-column=>1, -sticky=>'nwse');
    our $estim_grid = $estim_window_frame ->Scrolled('HList', -head => 0, 
        -columns    => $cols+2, -scrollbars => 'se',-highlightthickness => 0,
        -height     => 25, -width      => 60,
        -border     => 0, -indicator=>0,
        -background => 'white',
      )->grid(-column => 0, -columnspan=>7,-row => 0,-sticky=>'nwse');   
    $estim_grid -> columnWidth(1, 120);
    $i = 1; $j=1; my $max_i = 1;
    if (@th>0) {
    $estim_window ->configure (-title=>'Final parameter estimates '.$lstfile);
    $estim_grid -> add($i);
    $estim_grid -> itemCreate($i, 0, -text => "TH 1", -style=>$header_right);
    foreach my $th (@th) {
      if ($i>1) {
        $estim_grid -> add($i);
        $estim_grid -> itemCreate($i, 0, -text => $i, -style=>$header_right);
      }
      $estim_grid -> itemCreate($i, 2, -text => rnd($th,4), -style=>$estim_style);
      if (($th!=0)&&(@th_se[$i-1]!=0)) {
        $estim_grid -> itemCreate($i, 3, -text => "(".rnd((@th_se[$i-1]/$th*100),3)."%)", -style=>$estim_style_se);
      } else {
        $estim_grid -> itemCreate($i, 3, -text => "( )", -style=>$estim_style_se);
      }
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
        $estim_grid -> itemCreate($i, $j+1, -text => rnd($om_cov,4), -style=>$style);
        if ($j == $cnt) {
             my $om_se_x = @om_se[$cnt-1];
             my @om_cov_se = @$om_se_x; 
            if (($om_cov!=0)&&(@om_cov_se[$cnt-1]!=0)) {
              $estim_grid -> itemCreate($i, $j+2, -text => "(".rnd((@om_cov_se[$cnt-1]/$om_cov*100),3)."%)", -style=>$estim_style_se);
            }
        }
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
      if ($flag==$i) {$estim_grid -> itemCreate($i, 0, -text => "SI 1", -style=>$header_right);
      } else {
        $estim_grid -> itemCreate($i, 0, -text => $cnt, -style=>$header_right);
      }
      $estim_grid -> itemCreate($i, 1, -text => @sigma_names[$cnt-1], -style=>$align_left);
      foreach $si_cov (@si_x) {
        if ($si_cov == 0) {$style = $estim_style_light} else {$style = $estim_style};
        $estim_grid -> itemCreate($i, $j+1, -text => rnd($si_cov,4), -style=>$style);
        if ($j == $cnt) {
            my $si_se_x = @si_se[$cnt-1];
            my @si_cov_se = @$si_se_x; 
            if (($si_cov!=0)&&(@si_cov_se[$cnt-1]!=0)) {
              $estim_grid -> itemCreate($i, $j+2, -text => "(".rnd((@si_cov_se[$cnt-1]/$si_cov*100),3)."%)", -style=>$estim_style_se);
            }
        }
        $j++;
      }
      $i++; $cnt++;
    }
  }
}

sub read_log {
### Purpose : Read Pirana log file
### Compat  : W+L?
    if (-e "<".$base_dir."/log/pirana.log") {
      open (NM_LOG, "<".$base_dir."/log/pirana.log");
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
    if (-e "<".$base_dir."/log/pirana.log") {
      open (NM_LOG, ">".$base_dir."/log/pirana.log");
      print NM_LOG $nm_inst_chosen."\n"; 
      print NM_LOG $active_project;
      close NM_LOG;
    }  
}

sub add_nm_inst {
### Purpose : Add an NM installation to Pirana 
### Compat  : W+
  $nm_inst_w = $mw -> Toplevel(-title=>"Add existing NONMEM installation to Pira�a");
  $nm_inst_w -> resizable( 0, 0 );
  $nm_inst_w -> Popup;
  $nm_inst_frame = $nm_inst_w -> Frame()->grid(-ipadx=>'10',-ipady=>'10',-sticky=>'n');
  $nm_inst_frame -> Label (-text=>"Local/cluster: ")->grid(-row=>1,-column=>1,-sticky=>"e");
  $nm_inst_frame -> Label (-text=>"Name in Pira�a: ")->grid(-row=>2,-column=>1,-sticky=>"e");
  $nm_inst_frame -> Label (-text=>"NM Location: ")->grid(-row=>3,-column=>1,-sticky=>"e");
  $nm_inst_frame -> Label (-text=>"NM version: ")->grid(-row=>4,-column=>1,-sticky=>"e");
  $nm_name="NM6";
  $nm_dir ="C:\\nmvi"; 
  $nm_inst_frame -> Entry (-textvariable=>\$nm_name,-border=>$bbw,-width=>16,-border=>2, -relief=>'groove')
         ->grid(-column=>2,-row=>2,-sticky=>"w");
  $nm_inst_frame -> Entry (-textvariable=>\$nm_dir,-border=>$bbw,-width=>40,-border=>2, -relief=>'groove')
         ->grid(-column=>2,-row=>3,-sticky=>"w");
  my $browse_button = $nm_inst_frame -> Button(-image=>$gif{browse}, -width=>28, -border=>0, -command=> sub{
      $nm_dir = $mw-> chooseDirectory();
      if($nm_dir eq "") {$nm_dir = "C:\\nmvi"};
      $nm_inst_w -> focus();
  })->grid(-row=>3, -column=>2, -rowspan=>1, -sticky => 'nse');
  $help->attach($browse_button, -msg => "Browse filesystem");
 # $nm_inst_frame -> Optionmenu (-options=>["regular (nmfe)","NMQual"], -width=>16, -variable=>\$nm_type,-border=>$bbw,
 #   -font=>$font_normal, -background=>$lightblue, -activebackground=>$darkblue)
 #        ->grid(-column=>2,-row=>0,-sticky=>"w");   
  $nm_inst_frame -> Optionmenu (-options=>["Local","Cluster"], -width=>16, -variable=>\$nm_locality,-border=>$bbw,
    -font=>$font_normal, -background=>$lightblue, -activebackground=>$darkblue)
         ->grid(-column=>2,-row=>1,-sticky=>"w");   
  $nm_inst_frame -> Optionmenu (-options=>["6","5"],-variable=>\$nm_ver,-border=>$bbw,-font=>$font_normal, 
    -background=>$lightblue, -activebackground=>$darkblue)
         ->grid(-column=>2,-row=>4,-sticky=>"w");       
  $nm_inst_frame -> Label (-text=>" ")->grid(-row=>5,-column=>1,-sticky=>"e");
  $nm_inst_frame -> Button (-text=>"Add", -width=>12, -background=>$button, -border=>$bbw, -activebackground=>$abutton, -command=> sub{ 
    if ($nm_dirs{$nm_name}) {
      message("A project with that name already exists in Pira�a.\nPlease choose another name.")
    } else {
      $valid_nm = 0;
      if ($nm_locality eq "Cluster") {
        $nm_ini_file = "nm_inst_cluster.ini";
        $valid_nm = 1; # no test if installation is available
      } else {
        $nm_ini_file = "nm_inst_local.ini";
        $nmq_name = get_nmq_name($nm_dir); 
        if (-e unix_path($nm_dir."/test/".$nmq_name.".pl")) {
          $nm_type = "nmqual";
          $valid_nm = 1;
        }
        if (-e unix_path($nm_dir."/util/nmfe".$nm_ver).".bat") {
          $nm_type = "regular";
          $valid_nm = 1;
        }
      }
      if ($valid_nm==1) {  # test for existence of 
        $nm_dirs{$nm_name} = $nm_dir; $nm_vers{$nm_name} = $nm_ver; $nm_types{$nm_name} = $nm_type;
        save_settings ($nm_ini_file, \%nm_dirs, \%nm_vers);
        chdir($cwd);
        if ($nm_type eq "regular") {
          nmfe_files()
        } else {
          nmqual_compile_script ($nm_dir, $nmq_name);
        };
        $run_method = "NONMEM";
        undef $nm_versions_menu;
        show_run_method($run_method);
        $nm_inst_w -> destroy;
        $sizes_w -> destroy;
      } else {
        message("Cannot find nmfe".$nm_ver.".bat (regular installation) or Perl-file (NMQual).\n Check if installation is valid.")
      };
    }
  })-> grid(-row=>6,-column=>2,-sticky=>"w");
  $nm_inst_frame -> Button (-text=>"Cancel", -width=>12, -background=>$button, -border=>$bbw, -activebackground=>$abutton, -command=> sub{
    $nm_inst_w->destroy; 
  })-> grid(-row=>6,-column=>1,-sticky=>"e");
}

sub remove_nm_inst {
### Purpose : Remove an NM installation from Pirana (but don't delete the installation) 
### Compat  : W+L?
  $nm_remove_w = $mw -> Toplevel(-title=>"Remove NONMEM installation from Pira�a");
  $nm_remove_w -> resizable( 0, 0 );
  $nm_remove_w -> Popup;
  $nm_remove_frame = $nm_remove_w -> Frame()->grid(-ipadx=>'10',-ipady=>'10',-sticky=>'n');
  $nm_remove_frame -> Label (-text=>"Installation: ")->grid(-row=>1,-column=>1,-sticky=>"e");
  $nm_remove_frame -> Label (-text=>"NONMEM Location: ")->grid(-row=>2,-column=>1,-sticky=>"e");
  $nm_remove_frame -> Label (-text=>"NONMEM version: ")->grid(-row=>3,-column=>1,-sticky=>"e");
  ($nm_name,@dummy) = keys(%nm_dirs);
 
  $nm_dir_entry = $nm_remove_frame -> Entry (-textvariable=>\$nm_dirs{$nm_name},-border=>$bbw,-width=>30,-state=>"disabled", -border=>2, -relief=>'groove')
         ->grid(-column=>2,-row=>2,-sticky=>"w");
  $nm_ver_entry = $nm_remove_frame -> Entry (-textvariable=>\$nm_vers{$nm_name},-border=>$bbw,-width=>2,-state=>"disabled", -border=>2, -relief=>'groove')
         ->grid(-column=>2,-row=>3,-sticky=>"w");
  
  $nm_remove_frame -> Optionmenu (-options=>[keys(%nm_dirs)],-variable=>\$nm_name,-border=>$bbw,-width=>10,-font=>$font_normal, -background=>$lightblue, -activebackground=>$darkblue, -command=>sub{
      $nm_dir_entry -> configure(-textvariable=>\$nm_dirs{$nm_name});
      $nm_ver_entry -> configure(-textvariable=>\$nm_vers{$nm_name});
    })->grid(-column=>2,-row=>1,-sticky=>"w");
  $nm_remove_frame -> Label (-text=>" ")->grid(-row=>4,-column=>1,-sticky=>"e");
  $nm_remove_frame -> Button (-text=>"Remove", -width=>12, -background=>$button, -border=>$bbw, -activebackground=>$abutton, -command=> sub{ 
    delete $nm_dirs{$nm_name};
    delete $nm_vers{$nm_name};
    save_settings ("nm_inst_local.ini", \%nm_dirs, \%nm_vers);
    ($nm_dirs_ref,$nm_vers_ref) = read_ini("ini/nm_inst_local.ini");
    %nm_dirs = %$nm_dirs_ref; %nm_vers = %$nm_vers_ref;
    chdir($cwd);
    refresh_pirana($cwd);
    $nm_remove_w -> destroy;
  })-> grid(-row=>5,-column=>2,-sticky=>"w");
  $nm_remove_frame -> Button (-text=>"Cancel", -width=>12, -background=>$button, -border=>$bbw, -activebackground=>$abutton, -command=> sub{
    $nm_remove_w->destroy; 
  })-> grid(-row=>5,-column=>1,-sticky=>"e");
}

sub save_settings {
### Purpose : Save Pirana settings contained in a hash to ini-file.
### Compat  : W+L?
  ($ini_file, $ref_ini, $ref_ini_descr, $ref_add_1) = @_;
  %ini = %$ref_ini;
  %ini_descr = %$ref_ini_descr;
  %ini_add_1 = %$ref_add_1;
  print %ini_add_1;
  open (INI, "<".unix_path($base_dir."/ini/".$ini_file));
  @lines=<INI>;
  close INI;
  open (INI, ">".unix_path($base_dir."/ini/".$ini_file));
  foreach(@lines) {
     if (substr($_,0,1) eq "#") {print INI $_;} else {
        ($key,$value) = split (/,/,$_);
         unless (($ini{$key} eq "")||($key eq "")) {
            $ini_descr{$key} =~ s/\n/\\n/g ;
            #$ini{$key} =~ s/\n/\\\n/g ;
            print INI $key.",".$ini{$key}.",".$ini_descr{$key};
            unless ($ini_add_1{$key} eq "") {print INI ",".$ini_add_1{$key};};
            print INI "\n";
         }
         delete($ini{$key}); delete ($ini_descr{$key});
      }
    }
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
    our $edit_scripts_params = $edit_scripts_w -> Frame()->grid(-ipadx=>'10',-ipady=>'10',-sticky=>'n',-column=>2,-row=>1);
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
    $p_entry{$_} = $edit_scripts_params -> Entry (-textvariable=>\$defaults{$_}, -width=>$width, -border=>2, -relief=>'groove')->grid(-column=>2,-row=>$i+4,-sticky=>"w");
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

sub edit_scripts {
### Purpose : Edit/run scripts (currently discontinued Pirana function)
### Compat  : W+L?
  chdir ($base_dir."/scripts");
  @scripts = <*.pl>;
  @awk = <*.awk>;
  push (@scripts, @awk);
  chdir ($cwd);
  $edit_scripts_w = $mw -> Toplevel(-title=>"Scripts");
  $edit_scripts_w -> resizable( 0, 0 );
  $edit_scripts_w -> minsize( 520, 180); $edit_scripts_w -> maxsize( 520,250);
  $edit_scripts_w -> Popup;
  our $edit_scripts_frame = $edit_scripts_w -> Frame()->grid(-ipadx=>'10',-ipady=>'10',-sticky=>'n',-column=>1,-row=>1);
  our $edit_scripts_params = $edit_scripts_w -> Frame()->grid(-ipadx=>'10',-ipady=>'10',-sticky=>'n',-column=>2,-row=>1);
  $edit_scripts_params -> Label (-text=>"Description: ", -font=>$font_bold)->grid(-column=>1,-row=>1);
  $edit_scripts_params -> Label (-text=>"Parameters: ", -font=>$font_bold)->grid(-column=>1,-row=>3);
  $edit_scripts_params -> Label (-text=>" ", -width=>50)->grid(-column=>2,-row=>1,-sticky=>"w");
  $edit_scripts_frame -> Label (-text=>"\n \n \n \n \n ")->grid(-column=>2,-row=>13,-sticky=>"w");
  $edit_scripts_scrollbar = $edit_scripts_frame -> Scrollbar(-border=>$bbw, -orient => 'vertical');
  $edit_scripts_listbox = $edit_scripts_frame -> Listbox(-border=>$bbw, -width=>16,-height=>10, -border=>2, -relief=>'groove',
      -yscrollcommand => ['set' => $edit_scripts_scrollbar],-background=>"#ffffff",-font=>$font_normal)
      -> grid(-row=>1,-column=>1,-rowspan=>9,-columnspan=>3,-sticky => 'we',);
  $edit_scripts_listbox -> bind ('<ButtonPress-1>', sub {
     $curr_script = @scripts[$edit_scripts_listbox->curselection];
     show_script_params(@scripts[$edit_scripts_listbox->curselection]) 
  });
  $edit_scripts_scrollbar -> grid(-row=>1,-column=>4,-rowspan=>10,-sticky => 'wens',);
  $edit_scripts_listbox -> insert(0, @scripts);
  $edit_scripts_scrollbar -> configure(-command => ['yview' => $edit_scripts_listbox]);
  $edit_scripts_frame -> Button (-text=>'Edit', -width=>10, -background=>$button, -activebackground=>$abutton, -border=>$bbw, -command=>sub{ 
    edit_model ($base_dir."\\scripts\\".@scripts[$edit_scripts_listbox->curselection]);
  })->grid(-row=>12,-column=>2,-sticky=>"e"); 
  $edit_scripts_frame -> Button (-text=>'Run', -width=>10, -background=>$button, -activebackground=>$abutton, -border=>$bbw, -command=>sub{
    $params = "";
    $i=0;
    foreach(keys (%descr)) {
      $params .= " -".$_."=".$defaults{$_};
      $i++;
    }
    $command = win_path($base_dir."\\scripts\\".$curr_script).$params;
    if ($params =~ m/.pl/)  {$lang = "perl"};
    if ($params =~ m/.awk/) {$lang = "awk"}; 
    system "start ".$lang." ".$command; #" >".win_path($base_dir."\\log\\")."script.log";
    #$see_script_log = $edit_scripts_w -> messageBox(-type=>'yesno', -icon=>'question',
    #  -message=>"Script executed.\nDo you want to view the script output?"); 
    #if( $see_script_log eq "Yes") {
    #  win_start ($software{editor}, $base_dir."\\log\\script.log");
    #}
    #$edit_scripts_w->destroy();
    renew_pirana()
  })->grid(-row=>12,-column=>3,-sticky=>"e");
}

sub edit_ini_window {
### Purpose : Open a window to edit preferences/software settings
### Compat  : W+L?
  ($ini_file, $ref_ini, $ref_ini_descr, $title, $software) = @_;
  %ini = %$ref_ini; 
  %ini_descr = %$ref_ini_descr;
  open (INI, "<".unix_path($base_dir."/ini/".$ini_file));
  @lines=<INI>;
  close INI;
  my @keys;
  foreach(@lines) {
    unless (substr($_,0,1) eq "#") {
       ($key,$value)=split(/,/,$_);
       push (@keys, $key)
    }
  }
  close INI;
  $edit_ini_w = $mw -> Toplevel(-title=>$title);
  $edit_ini_w -> resizable( 0, 0 );
  $edit_ini_w -> Popup;
  my $edit_ini_frame = $edit_ini_w -> Frame()->grid(-ipadx=>'10',-ipady=>'10',-sticky=>'n');
  # $edit_ini_frame -> Label (-text=>"Pira�a settings: ")->grid(-column=>1, -row=>1);
  $row=2; $col=1; $i=0;
  my @ini_value;
  foreach (@keys) {
       if (length($ini{$_})<10) {$length=10} else {$length=40};
       $edit_ini_frame -> Label (-text=>$_)->grid(-column=>$col,-row=>$row,-sticky=>"e",-ipadx=>'8');
       $edit_ini_frame -> Label (-text=>"  ")->grid(-column=>$col+2,-row=>$row); # spacer
       @ini_value[$i]=$ini{$_};
       $entry_color=$white;
       if ($software==1) {
         if ((-d @ini_value[$i])||(-e @ini_value[$i])) {$entry_color=$lightgreen} else {$entry_color=$lightred};
       };
       @edit_ini_entry[$i] = $edit_ini_frame -> Entry (-textvariable=>\@ini_value[$i],-border=>2, -relief=>'groove',-background=>$entry_color,-width=>$length)
         ->grid(-column=>$col+1,-row=>$row,-sticky=>"w"); 
       $help -> attach(@edit_ini_entry[$i], -msg => $ini_descr{$_});
       $row++; $i++;
       if($row==int((@keys/2)-0.1)+3) {$row=2; $col=4};
  }
  $edit_ini_frame -> Label (-text=>"  ")->grid(-column=>1, -row=>int(@keys/2)+3,-columnspan=>1,-sticky=>"e");
  $edit_ini_frame -> Button (-text=>'Save', -width=>12, -background=>$button, -activebackground=>$abutton, -border=>$bbw, -command=>sub{  
    $i=0;
    foreach(@keys) {  # update %settings
      $ini{$_} = @ini_value[$i];
      $i++;
    }
    save_settings ($ini_file, \%ini, \%ini_descr);
    chdir($base_dir);
    ($software_ref,$software_descr_ref) = read_ini("ini/software.ini");
    %software = %$software_ref; %software_descr = %$software_descr_ref;  
    ($setting_ref,$setting_descr_ref) = read_ini("ini/settings.ini");
    %setting = %$setting_ref; %setting_descr = %$setting_descr_ref;
    ($psn_commands_ref, $psn_commands_descr_ref) = read_ini("ini/psn.ini");
    %psn_commands = %$psn_commands_ref; our %psn_commands_descr = %$psn_commands_descr_ref;
    $psn_parameters = $psn_commands{$psn_option};
    if ($psn_command_entry) {$psn_command_entry -> update();}
    $edit_ini_w->destroy;
    refresh_pirana($cwd,$filter,1);
  })->grid(-row=>int(@keys/2)+4,-column=>5,-sticky=>"w");
  $edit_ini_frame -> Button (-text=>"Cancel", -width=>12, -background=>$button, -border=>$bbw, -activebackground=>$abutton, -command=> sub{
    $edit_ini_w->destroy; 
  })-> grid(-row=>int(@keys/2)+4,-column=>4,-sticky=>"e");
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
    $sizes_frame = $nm_manage_frame ->  Frame() -> grid(-ipadx=>'10',-ipady=>'10',-sticky=>'nws',-column=>1,-row=>6,-columnspan=>3); 
    our @sizes;
       @sizes_refs = read_sizes($nm_dirs{$nm_chosen});
       ($sizes_key_ref,$sizes_value_ref,$sizes_comment_ref) = @sizes_refs;
       @sizes_key = @$sizes_key_ref;
       @sizes_value = @$sizes_value_ref;
       @sizes_comment = @$sizes_comment_ref;
       $row=0; $col=1; $i=0;
       foreach (@sizes_key) {
          $sizes_frame -> Label (-text=>@sizes_key[$i])->grid(-column=>$col,-row=>$row,-sticky=>"e",-ipadx=>'8');
          $sizes_frame -> Label (-text=>"  ")->grid(-column=>$col+2,-row=>$row); # spacer
          if ($nm_types{$nm_chosen} =~ m/nmq/i) {$state='disabled'} else {$state='normal'};
          @sizes_entry[$i] = $sizes_frame -> Entry (-textvariable=>\@sizes_value[$i],-state=>$state,-border=>2, -relief=>'groove')->grid(-column=>$col+1,-row=>$row);
          $help->attach(@sizes_entry[$i], -msg => @sizes_comment[$i] ); 
          $row++; $i++;
          if($row==18&&$col==1) {$row=0; $col=4};
          if($row==18&&$col==4) {$row=0; $col=7};
       }
    if ($nm_types{$nm_chosen} =~ m/nmq/i) {$nm_save_recompile->configure(-state=>"disabled")} else {$nm_save_recompile->configure(-state=>"normal")};
    if ($nm_types{$nm_chosen} =~ m/nmq/i) {$nm_save->configure(-state=>"disabled")} else {$nm_save->configure(-state=>"normal")};
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
  $install_nm_nmq_w -> Popup;
  $install_nm_nmq_frame = $install_nm_nmq_w -> Frame()->grid(-ipadx=>'10',-ipady=>'10',-sticky=>'n');
  $install_text = "This will perform a new installation of NONMEM VI using\n".
    "predefined NMQual XML files. Please refer to the documentation\n of NMQual for further information on this subject.\n\n".
    "The location of the NMQual XML files can be specified under 'File --> Software'.\nOnly XML-files prefixed with 'config.' are shown in the optionmenu.\n".
    "Since Perl is needed for NMQual, it is assumed that it's location is in the PATH.\n\n";
  $install_nm_nmq_frame -> Label (-text=>$install_text,-justify=>"left")
    ->grid(-row=>1,-column=>1, -columnspan=>3,-sticky=>"w");
  $install_nm_nmq_frame -> Label (-text=>"Name in Pira�a:",-justify=>"left")
    ->grid(-row=>2,-column=>1, -columnspan=>1,-sticky=>"w");
  $install_nm_nmq_frame -> Label (-text=>"Installation",-justify=>"left")
    ->grid(-row=>3,-column=>1, -columnspan=>1,-sticky=>"w");
  $install_nm_nmq_frame -> Entry (-textvariable=>\$nm_name, -border=>$bbw, -width=>16, -border=>2, -relief=>'groove') 
    -> grid(-row=>2,-column=>2,-columnspan=>2,-sticky=>"news");

  $install_nm_nmq_frame -> Label (-text=>"Installation directory:",-justify=>"left")
    ->grid(-row=>4,-column=>1, -columnspan=>1,-sticky=>"w");
  $nmq_to = $install_nm_nmq_frame -> Entry (-state=>'disabled',-border=>$bbw, -width=>16, -border=>2, -relief=>'groove') 
    -> grid(-row=>4,-column=>2,-columnspan=>2,-sticky=>"news");
  $install_nm_nmq_frame -> Label (-text=>"NONMEM version:",-justify=>"left")
    ->grid(-row=>5,-column=>1, -columnspan=>1,-sticky=>"w");
  $nmq_nmver = $install_nm_nmq_frame -> Entry (-state=>'disabled',-border=>$bbw, -width=>16, -border=>2, -relief=>'groove') 
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
        edit_model($nmq_xml);
  })->grid(-row=>3,-column=>4,-sticky=>"w");
  $install_nm_nmq_frame -> Label (-text=>" ",-justify=>"left")
    ->grid(-row=>6,-column=>1, -columnspan=>3,-sticky=>"w");
  $install_nm_nmq_frame -> Button (-text=>"Proceed", -width=>12, -background=>$button, -border=>$bbw, -activebackground=>$abutton, -command=> sub {
    if ($nm_dirs{$nm_name}) {message("A NONMEM installation with that name already exists in Pira�a.\nPlease choose another name.")} else {
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
         my $add_to_pirana = $mw -> messageBox(-type=>'yesno', -icon=>'question', -message=>"NONMEM installations seems valid.\n Do you want to add this installation to Pira�a?"); 
           if ($add_to_pirana eq "Yes") {
           $nm_dirs{$nm_name} = $target;
           $nm_vers{$nm_name} = $version;
           save_settings ("nm_inst_local.ini", \%nm_dirs, \%nm_vers);
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
  $install_nm_w -> Popup;
  my $install_nm_frame = $install_nm_w -> Frame()->grid(-ipadx=>'10',-ipady=>'10',-sticky=>'n');
  $install_text = "This will perform a new installation of NONMEM VI from CD\n\n".
    "Tip: If you have the NONMEM installation files not on CD, but e.g. on your hard-drive or USB-stick,\n".
    " then you can create a virtual drive of the folder containing the installation files by executing:\n".
    "'subst X: . ' from a command line window from within that folder\n";
  $install_nm_frame -> Label (-text=>$install_text,-justify=>"left")
    ->grid(-column=>1, -columnspan=>2,-sticky=>"w");
  $install_nm_frame -> Label (-text=>"Installation name (for in Pira�a)")->grid(-column=>1, -row=>2,-sticky=>"e");
  $install_nm_frame -> Label (-text=>"NONMEM Install CD")->grid(-column=>1, -row=>3,-sticky=>"e");
  $install_nm_frame -> Label (-text=>"Install to")->grid(-column=>1, -row=>4,-sticky=>"e");
  $install_nm_frame -> Label (-text=>"Default compiler optimization")->grid(-column=>1, -row=>5,-sticky=>"e");
  
  $nm_install_name = "nmvi";
  $install_nm_frame -> Entry (-textvariable=>\$nm_install_name, -border=>$bbw, -width=>12, -border=>2, -relief=>'groove') -> grid(-row=>2,-column=>2,-sticky=>"nws");
  @drives = Win32::DriveInfo::DrivesInUse();
  foreach (@drives) {$_ .= ":"};
  $install_nm_frame -> Optionmenu (-options=>[@drives], -variable=> \$nm_install_drive, -border=>$bbw, -width=>5, -font=>$font_normal, -background=>$lightblue, -activebackground=>$darkblue)
    -> grid(-row=>3,-column=>2,-sticky=>"w");
  $nm_install_to = "c:\\".$nm_install_name;
  $install_nm_to_entry = $install_nm_frame -> Entry (-textvariable=>\$nm_install_to, -border=>$bbw, -width=>36, -border=>2, -relief=>'groove') -> grid(-row=>4,-column=>2,-sticky=>"news");
  $def_optimize = 1;
  $install_nm_frame -> Checkbutton(-text=>"",-activebackground=>$bgcol,-variable=>\$def_optimize)
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
           my $add_to_pirana = $mw -> messageBox(-type=>'yesno', -icon=>'question', -message=>"NONMEM installation seems successful.\nDo you want to add this installation to Pira�a?"); 
           if( $add_to_pirana eq "Yes") {
              $nm_dirs{$nm_install_name} = $nm_install_to;
              $nm_vers{$nm_install_name} = 6;
              save_settings ("nm_inst_local.ini", \%nm_dirs, \%nm_vers);
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

sub edit_sizes_window {
### Purpose : Create the dialog for editing the NM sizes file
### Compat  : W+L+ 
  $sizes_w = $mw -> Toplevel(-title=>'Configure NM6 installations');
  $sizes_w -> resizable( 0, 0 );
  $sizes_w -> Popup;
  our $nm_manage_frame = $sizes_w -> Frame()->grid(-ipadx=>'10',-ipady=>'10',-sticky=>'n');
  $nm_manage_frame -> Label (-text=>"NONMEM Installation: ")->grid(-column=>1, -row=>1,-sticky=>"nws");
  $nm_manage_frame -> Label (-text=>"Location: ")->grid(-column=>1, -row=>2,-sticky=>"nws");
  $nm_manage_frame -> Label (-text=>"Version: ")->grid(-column=>1, -row=>3,-sticky=>"nws");
  $nm_manage_frame -> Label (-text=>"\nNote: Only SIZES files of local NM installations can be read. Versions will be read\nfrom pirana ini-files, and psn.conf (if found). Only regular (non-NMQual) installations\ncan be altered and recompiled. Hover over records to view description.",-justify=>'left')
    ->grid(-column=>1, -row=>5, -columnspan=>4, -sticky=>"nws");
  my @nm6_installations = ();
  ($nm_dirs_ref, $nm_vers_ref) = read_ini("ini/nm_inst_local.ini");
  %nm_dirs = %$nm_dirs_ref; %nm_vers = %$nm_vers_ref; 
  # add Perl NM-versions
  my ($psn_nm_versions_ref, $psn_nm_versions_vers_ref) = get_psn_nm_versions();
  my %psn_nm_versions = %$psn_nm_versions_ref;
  my %psn_nm_versions_vers = %$psn_nm_versions_vers_ref;
  foreach(keys(%psn_nm_versions)) {
    $nm_types{"PsN: ".$_} = "PsN";
    $nm_dirs{"PsN: ".$_} = $psn_nm_versions{$_};
    $nm_vers{"PsN: ".$_} = $psn_nm_versions_vers{$_};
  }
  foreach(keys(%nm_vers)) {   # filter out only NM6 installations 
    if ($nm_vers{$_} =~ m/6/) {push (@nm6_installations, $_) };
  };
  $nm_save = $nm_manage_frame -> Button (-text=>"Save", -width=>20, -background=>$button, -border=>$bbw, -activebackground=>$abutton, -command=> sub {
    save_sizes($nm_chosen, \@sizes_key, \@sizes_value);
    $sizes_w->destroy;
    message("SIZES saved.\nFor settings to take effect,\nyou have to re-compile NONMEM.");
  })->grid(-row=>10,-column=>2);
  $nm_save_recompile = $nm_manage_frame -> Button (-text=>"Save and recompile NM", -width=>20, -background=>$button, -border=>$bbw, -activebackground=>$abutton, -command=> sub{
    save_sizes($nm_chosen, \@sizes_key, \@sizes_value);
    chdir ($nm_dirs{$nm_chosen});
    rmtree(["NM","PR","TL","TR"]);
    @nm_loc = split(/:/,$nm_dirs{$nm_chosen});
    my $compile_command = "cdsetup6 ".@nm_loc[0]." ".@nm_loc[0]." ".substr(@nm_loc[1],1,length(@nm_loc[1]))." ".$setting{compiler}." y link";
    $compile_nm = $mw -> Toplevel(-title=>'Delete project');
    $compile_nm -> resizable( 0, 0 ); $compile_nm -> Popup;
    $compile_nm_frame = $compile_nm -> Frame ()->grid(-ipadx=>10,-ipady=>10);
    $compile_nm_frame -> Label (-text=>"folders NM, PR, TL and TR in ".$nm_dirs{$nm_chosen}." will be deleted!") -> grid(-row=>1,-column=>1,-columnspan=>2,-sticky=>"w");
    $compile_nm_frame -> Label (-text=>"Recompile command: \n",,-justify=>'left') -> grid(-row=>2,-column=>1);
    $compile_nm_frame -> Entry (-textvariable=>\$compile_command, -border=>$bbw, -width=>32, -border=>2, -relief=>'groove') -> grid(-row=>2,-column=>2,-sticky=>"wn");
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
  
  $nm_dir_entry = $nm_manage_frame -> Entry (-textvariable=>\$nm_dirs{$nm_chosen},-border=>$bbw,-width=>30,-state=>"disabled", -border=>2, -relief=>'groove')
         ->grid(-column=>2,-row=>2,-sticky=>"we");
  $nm_ver_entry = $nm_manage_frame -> Entry (-textvariable=>\$nm_vers{$nm_chosen},-border=>$bbw,-width=>2,-state=>"disabled", -border=>2, -relief=>'groove')
         ->grid(-column=>2,-row=>3,-sticky=>"w");  
  $del_nm_button = $nm_manage_frame -> Button (-image=>$gif{del_project}, -border=>$bbw, -background=>$button, -activebackground=>$abutton, -width=>22, -command=> sub{ 
    my $delete = $mw -> messageBox(-type=>'yesno', -icon=>'question', -message=>"Do you really want to delete this NONMEM installation?\nNB. The actual installation will not be removed, only the link from Pira�a.");       
      if( $delete eq "Yes") {
      delete $nm_dirs{$nm_chosen};
      delete $nm_vers{$nm_chosen};
      delete $nm_types{$nm_chosen};
      foreach (keys(%nm_dirs)) {if (($_ =~ m/PsN:/)||($_ eq "")) { delete $nm_dirs{$_}; delete $nm_vers{$_};  delete $nm_types{$_};}}
      save_settings ("nm_inst_local.ini", \%nm_dirs, \%nm_vers);
      ($nm_dirs_ref,$nm_vers_ref) = read_ini("ini/nm_inst_local.ini");
      our %nm_dirs = %$nm_dirs_ref; our %nm_vers = %$nm_vers_ref; 
      chdir($cwd);
      refresh_pirana($cwd);
      $sizes_w -> destroy;
    }
  })-> grid(-row=>1,-column=>3,-sticky=>"w");
  $help->attach($del_nm_button, -msg => "Remove NM installation");
  $new_nm_button = $nm_manage_frame -> Button (-text=>"Add NONMEM installation", -border=>$bbw, -background=>$button, -activebackground=>$abutton, -width=>22, -command=> sub{ 
     foreach (keys(%nm_dirs)) {if ($_ =~ m/PsN:/) { delete $nm_dirs{$_}; delete $nm_vers{$_}; delete $nm_types{$_};}}
     add_nm_inst();
     #refresh_pirana($cwd);
  })-> grid(-row=>4,-column=>2,-sticky=>"w");
  $help->attach($new_nm_button, -msg => "Add new NM installation");
  @nm6_installations = sort (@nm6_installations);
  $nm_manage_frame -> Optionmenu (-options => [@nm6_installations], -border=>$bbw,   
        -variable => \$nm_chosen, -width=>25, -background=>$lightblue,-activebackground=>$darkblue,-font=>$font_normal,
        -command=>sub{ 
          refresh_sizes();
          if ($nm_chosen =~ m/PsN/) {$del_nm_button -> configure (-state=>'disabled')} else {$del_nm_button -> configure (-state=>'normal')};
          $nm_dir_entry -> configure(-textvariable=>\$nm_dirs{$nm_chosen});
          $nm_ver_entry -> configure(-textvariable=>\$nm_vers{$nm_chosen});
    })->grid(-row=>1,-column=>2, -sticky => 'we');
    
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
   $csv_tab_w -> Popup;
   $csv_tab_frame = $csv_tab_w -> Frame()->grid(-ipadx=>'20',-ipady=>'10',-sticky=>'nws');
   $csv_tab_frame -> Label(-text=> "Convert file: ",-justify=>"left")->grid(-column=>1, -row=>1,-sticky=>"wns");
   $csv_tab_frame -> Label(-text=> $file,-justify=>"left")->grid(-column=>2, -row=>1,-sticky=>"wns");
   $csv_tab_frame -> Label(-text=> "to: ",-justify=>"left")->grid(-column=>1, -row=>2,-sticky=>"wns");
   my $length = length($file); if($length<32) {$length=32};
   $csv_tab_frame -> Entry(-textvariable=> \$new_file,  
      -border=>1, -relief=>'groove', -width=>$length)->grid(-column=>2, -row=>2,-sticky=>"wns");
   $csv_tab_frame -> Button(-text=> "Convert", -background=>$button, -border=>$bbw, -activebackground=>$abutton, -command=> sub {
     my $overwrite_bool = 1;
     if (-e $new_file) {
       my $overwrite = $mw -> messageBox(-type=>'yesno', -icon=>'question',
        -message=>"Datafile ".$new_file." already exists.\n Do you want to overwrite?"); 
       if( $overwrite eq "No") {$overwrite_bool=0;};
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
  our $frame_status = $mw -> Frame(-border=>1, -background=>$bgcol)->grid(-column=>1, -columnspan=>10,-row=>4,-ipady=>3, -sticky=>"nws");
  $mw->update();
  $frame_status -> Label (-text=>"   ",-font=>"Arial 7", -width=>1, -background=>$bgcol)->grid(-column=>0,-row=>1,-sticky=>"nsw");
  our $status_bar = $frame_status -> Label (-text=>"Status: Idle", -anchor=>"w", -font=>"Arial 8", -width=>140, -background=>$bgcol, -foreground=>"#757575")->grid(-column=>1,-row=>1,-sticky=>"w", -ipady=>0);
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

sub renew_pirana {
### Purpose : To reload the main part of the GUI
### Compat  : W+L+
  if($frame2) {$frame2->gridForget()}; 
  if($run_frame) {$run_frame -> gridForget()};
  if ($frame_links) {$frame_links -> gridForget()};
  if ($frame_status) {$frame_status -> gridForget()};
  frame_models_show($setting{models_vis});
  frame_statusbar(1);
  project_buttons_show();
  frame_tab_show(1);
  project_optionmenu ();
  refresh_pirana ($cwd, $filter, 1);
  status();
  if ($first_time_flag==1) {message("Welcome to Pira�a!\n\nSince this is the first time you start Pira�a, please check the preferences and software\nsettings under 'File' in the menu.\n\nNONMEM installations may be added under 'Tools' -> 'NONMEM' -> 'Manage Installations'\n\n")};

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
sub show_process_monitor {
### Purpose : Create (or destroy) a text-box that show the output of several commands 
### Compat  : W+L+
    if ($process_monitor == 1) {
      unless (defined $stdout) {
        our $stdout = $frame_status -> Scrolled("Text", 
          -scrollbars=>"e", -border=>1, -foreground=>"#000000", -background=>"#f2f2ef",
          -width=>135,-height=>3,-relief=>'groove', -state=>'normal'
        ) -> grid(-row=>10, -column=>1,-columnspan=>10,-sticky=>"we");
      }
    } else {
      if (defined $stdout) {
        $stdout -> gridForget();
        undef $stdout;
      }
    }
}

sub message { 
### Purpose : Show a small window with a text and an OK button
### Compat  : W+L+
 $mw -> messageBox(-type=>'ok', 
          	-message=>@_[0]);
}
 
sub intro_msg {
### Purpose : Issue a message-window showing startup errors 
### Compat  : W+L+
  $kill = shift;
  if ($kill == 1) {$kill_text = "\nClick OK to exit Pira�a.\n"} else {$kill_text=""};
  our $mw2 = MainWindow -> new (-title => "Pira�a",-width=>740, -height=>410);
  open (LOG, "<log/startup.log");
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
  unless (open (INI,"<".$base_dir."/".@_[0])) {print LOG "File not found: ".@_[0]."\n"};
  my %setting;
  my %descr;
  my %add_1;
  @ini=<INI>;
  close INI;
  foreach (@ini) {
    unless ($_=~ m/\#/) {
      chomp ($_);
      @a = split(/,/,$_);
      # @a[0] =~ s/\s//g;  # strip spaces from keys
      $setting{@a[0]} = @a[1];
      $descr{@a[0]} = @a[2];
      $add_1{@a[0]} = @a[3];
    }
  }
  return (\%setting, \%descr, \%add_1);
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

sub nmfe_files {
### Purpose : Create bat-file for starting NM-files (adapted from nmfe6.bat)
### Compat  : W+L- 
  print LOG "Checking NM start-up files..."; 
  $i=1; foreach (keys(%nm_dirs)) {
    my $ver=$nm_vers{$_};
    my $dir=$nm_dirs{$_};
    my $type=$nm_types{$_};
    unless ($dir eq "") {
    #unless (-e $dir."/util/pirana_runs".$ver.".bat") {
      open (OUT,">".$dir."/util/pirana_runs".$ver.".bat");
      print OUT ":loop\n";
      print OUT "IF '%1' == '' GOTO END\n";
      print OUT "COLOR 4F\n";
      print OUT "CALL ".$dir."\\util\\nmfe".$ver.".bat %1.".$setting{ext_ctl}." %1.".$setting{ext_res}."_tmp\n";
      print OUT "COLOR 07\n";
      print OUT "copy note.txt + %1.".$setting{ext_res}."_tmp %1.".$setting{ext_res}."\n";
      print OUT "del %1.".$setting{ext_res}."_tmp\n";
      print OUT "SHIFT\n";
      print OUT "GOTO LOOP\n";
      print OUT ":END\n";  
      if ($setting{quit_shell}==1) {print OUT "exit\n";}  
      close OUT;
    #}
    unless ((-e $dir."/util/pirana_nmfe".$ver."_compile.bat")||(-d $dir."/test/")) {
      unless (copy ($dir."/util/nmfe".$ver.".bat", $dir."/util/pirana_nmfe".$ver."_compile.bat")) {print LOG "Compile batch file could not be created.\n"; close LOG; intro_msg(1)};
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

sub initialize {
### Purpose : Initialize pirana: read ini-files and update settings-hashes
### Compat  : W+L? 
  our $first_time_flag=0;
  unless (-e "log/startup.log") {$first_time_flag=1};
  open (LOG,">log/startup.log");
  my $error=0;
  print LOG "Pira�a ".$version."\n";
  print LOG "Startup time: ".localtime()."\n\n";
  print LOG "Checking pirana installation...\n";
  unless (-d $base_dir."/ini") {$error++; print LOG "Error: Pirana could not find ini/settings.ini. Program halted.\n";} ;
  unless (-d $base_dir."/internal") {$error++; print LOG "Error: Pirana could not find dir containing internal subroutines. Program halted.\n"};
  unless (-d $base_dir."/log") {$error++; print LOG "Error: Pirana could not find log-folder. Program halted.\n"; };
  unless (-d $base_dir."/images") {$error++; print LOG "Error: Pirana could not find images. Program halted.\n"; };
  if ($error>0) {print LOG "Errors were found. Check installation of pirana.\n"; close LOG; intro_msg(1)} else {print LOG "Done\n"};

  print LOG "Reading Pirana settings...\n"; 
  ($setting_ref,$setting_descr_ref) = read_ini("ini/settings.ini");
  %setting = %$setting_ref; %setting_descr = %$setting_descr_ref;  
  if ($setting{name_researcher}) {print LOG "Done\n";} else {print LOG "Error. Settings file might be corrupted. Check ini/settings.ini\n"; close LOG; intro_msg( )};
  our $models_view = $setting{models_view};
    
  if ($setting{font_size}==2) {
    if ($os =~ m/MSWin/) {
       our $font_normal = 'Verdana 8';
       our $font_small = 'Verdana 7';
    } else {
       our $font_normal = 'Verdana 10';
       our $font_small = 'Verdana 9';
    }
    our $font_fixed = "Courier 9 bold";
    our $font_fixed2 = "Courier 10";
    our $font_bold = 'Verdana 8 bold';
  } else {
    our $font_normal = 'Verdana 7';
    our $font_small = 'Verdana 7';
    our $font_fixed = "Courier 8 bold";
    our $font_bold = 'Verdana 7 bold'; 
  }
  
  print LOG "Reading software settings...\n"; 
  ($software_ref,$software_descr_ref) = read_ini("ini/software.ini");
  %software = %$software_ref; %software_descr = %$software_descr_ref;  

  if ($ENV{PATH} =~ m/$nm_dir/) {;} else { $ENV{PATH}="$nm_dir/util;".$ENV{PATH}} ;
  unless ($ENV{'PATH'} =~ m/$software{f77_dir}/) {
    $ENV{'PATH'} = $software{f77_dir}.";".$ENV{'PATH'};
  } 
  # check if XML:XPath is present, if NMQual will be used.
  if ($setting{use_nmq}==1) {
    print LOG "Checking XML::XPath availability (NMQual)...\n";
    system ('perl "'.win_path($base_dir.'/internal/test_xpath.pl" >"'.$base_dir.'/log/xpath.log"'));
    if (-s $base_dir."/log/xpath.log" > 2) { 
      our $xpath=1;
    } else {our $xpath = 0; print LOG "Perl module XML::XPath required for NMQual support was not found.\nIf you prefer not to work with NMQual,\ndisable use of NMQual under 'File->Preferences'.\n"; intro_msg(0) 
    }; 
  }
  if ($setting{use_psn}==1) {
    print LOG "Reading PsN commands default parameters...\n"; 
    my ($psn_commands_ref, $psn_commands_descr_ref) = read_ini("ini/psn.ini");
    our %psn_commands = %$psn_commands_ref; our %psn_commands_descr = %$psn_commands_descr_ref;  
    foreach(keys(%psn_commands_descr)) {
      $psn_commands_descr{$_} =~ s/\\n/\n/g;
    }
  }

  if (-e "ini/scripts.ini") {
    print LOG "Reading scripts...\n"; 
    ($scripts_ref,$scripts_descr_ref) = read_ini("ini/scripts.ini");
    %scripts = %$scripts_ref; %scripts_descr = %$scripts_descr_ref;  
  }
  
  print LOG "Reading Projects...\n"; 
  (%project_dir,%project_descr) = read_ini("ini/projects.ini");
  ($project_dir_ref,$project_descr_ref) = read_ini("ini/projects.ini");
  %project_dir = %$project_dir_ref; %project_descr = %$project_descr_ref;
  $pr_dir_err=0;
  while(($key, $value) = each(%project_dir)) {
    unless (-d $value) {$pr_dir_err++; print LOG "Error: folder for project ".$value." not found!\n"};
  }
  unless ($pr_dir_err==0) {print LOG $pr_dir_err." project(s) not found. Check ini/projects.ini!\n"; close LOG; 
    # intro_msg(0)
  };
  
  print LOG "Reading NM versions...\n";
  $pr_dir_err=0;   
  ($nm_dirs_ref, $nm_vers_ref) = read_ini("ini/nm_inst_local.ini");
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
  if ($setting{use_cluster}==1) {
    ($nm_dirs_cluster_ref,$nm_vers_cluster_ref,$nm_types_cluster_ref) = read_ini("ini/nm_inst_cluster.ini");
    %nm_dirs_cluster = %$nm_dirs_cluster_ref; %nm_vers_cluster = %$nm_vers_cluster_ref;
  }
  
  # following error messages removed, since if you work with WFN / PsN, NONMEM versions do not have to be specified to pirana
  # unless ($pr_dir_err==0) {print LOG $pr_dir_err." NM installations not found. Check ini/nm_inst_local.ini!\n"; close LOG; intro_msg(1)};
  if (keys(%nm_dirs)==0) {
    # $init_message = "No NONMEM installations specified. Please add \nNONMEM installations under Tools -> NONMEM -> Add.\n\nAlso, if this is the first time you start Pira�a, check if\nsofware locations are set correctly (File -> Software)";
  } else {
    nmfe_files();
  }
}

sub cluster_monitor {
### Purpose : Create a window showing the active nodes in the PCluster
### Compat  : 
    our $cluster_view = $mw -> Toplevel(-title=>'Cluster monitor');
    $cluster_view -> resizable( 0, 0 );
    $cluster_view -> Popup;
    $cluster_view -> iconimage($gif{network}); # doesn't work properly for some reaseon
    $cluster_view_frame = $cluster_view -> Frame()->grid(-ipadx=>5,-ipady=>5);
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
    unless($cluster_monitor_grid) {
      our $available_label = $cluster_view_frame -> Label (
        -text=>"Total CPUs: ".$capacity."  In use: ".$in_use,
        -font=>$font_bold
      ) -> grid(-column =>1, -columnspan=>5, -row=>0, -sticky=>"w");
      my @widths  = (25, 100, 30, 30,5);
      my @headers = ( "Client", "Owner", "CPUs", "In use"," ");
      our $cluster_monitor_grid = $cluster_view_frame ->Scrolled('HList',
        -head       => 1,
        -columns    => 5,
        -scrollbars => 'e',
        -width      => 32,
        -height     => 16,
        -border     => 0,
        -background => 'white',
      )->grid(-column => 1, -columnspan=>2,-row => 1);
    }   
    my $i=0;
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
  $save_dialog -> Popup;
  $save_proj_frame = $save_dialog -> Frame(-background=>$bgcol) -> grid(-ipadx=>10, -ipady=>10);
  
  $save_proj_frame->Label(-text=>"folder: ")->grid(-row=>1,-column=>1,-columnspan=>2,-sticky=>'w');
  $save_proj_frame->Label(-text=>@_[0])->grid(-row=>1,-column=>2,-columnspan=>2,-sticky=>'w');
  $save_proj_frame->Label(-text=>"Overwrite project: ",-activebackground=>$bgcol)->grid(-row=>2,-column=>1,-sticky=>'w');
  $new_project_name = "New project";
  my $proj_entry = $save_proj_frame->Entry(-width=>30, -textvariable=>\$new_project_name,-background=>'#FFFFEE', -border=>2, -relief=>'groove') ->grid(-row=>3,-column=>2,-sticky=>'w');
  $save_proj_frame->Optionmenu(-background=>$lightblue,-activebackground=>$darkblue, -width=>25,-border=>$bbw, 
        -options=>["New project",keys(%project_dir)], -font=>$font_normal, -textvariable => \$project_chosen,
        -command=>sub{
          $new_project_name = $project_chosen;
          $proj_entry -> update();
        ;} )
    ->grid(-row=>2,-column=>2,-sticky=>'w');
  $save_proj_frame->Label(-text=>"Project name: ") ->grid(-row=>3,-column=>1,-sticky=>'w');
  $save_proj_frame->Label(-text=>"  ")->grid(-row=>4,-column=>1,-columnspan=>2,-sticky=>'w');
  $save_proj_frame->Button(-text=>"Save",-width=>16,-background=>$button,-activebackground=>$abutton,-border=>$bbw, -command=>sub{
     # rewrite the hash:
     unless ($project_chosen eq "New project") {
       delete $project_dir{$project_chosen};  
     }
     $project_dir{$new_project_name} = $cwd;  
     rewrite_projects_ini();
     $active_project = $new_project_name;
     project_optionmenu();
     destroy $save_dialog;})
   ->grid(-row=>5,-column=>2,-sticky=>'w'); 
 $save_proj_frame -> Button (-text=>'Cancel ', -background=>$button, -activebackground=>$abutton, -border=>0, -command=>sub{destroy $save_dialog})->grid(-column=>1,-row=>5,-sticky=>"nwse");
}

sub rewrite_projects_ini {
### Purpose : Rewrite the projects.ini file after updates have been made
### Compat  : W+L+?
     open (INI, ">".$base_dir."/ini/projects.ini");
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
  $delproj_frame -> Label (-text=>"Really delete project $active_project?\n (folder will not be deleted, only shortcut in Pira�a.)\n",-justify=>'left')->grid(-row=>1,-column=>1,-columnspan=>2);
  $delproj_frame -> Button (-text=>'Delete ', -background=>$button, -activebackground=>$abutton, -border=>0, -command=>sub{  
    delete $project_dir{$active_project};
    rewrite_projects_ini();
    ($active_project,@rest) = keys(%project_dir);
    project_optionmenu();
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

sub delete_ctl {
### Purpose : Delete a NM results file
### Compat  : W+L+
  @runs = @sel;
  $del_dialog = $mw -> Toplevel( -title=>"Delete model/folder(s)");
  $del_dialog -> resizable( 0, 0 );
  $del_dialog -> Popup;
  $del_dialog_frame = $del_dialog-> Frame()->grid(-ipadx=>'10',-ipady=>'10',-sticky=>'n');
  $type = @file_type_copy[@sel];
  @del_files = @ctl_show; # make copy, since @ctl_file can change during delete process!
  if ($type == 1) { # < delete folder>
    my $folders = join("\n",@del_files[@runs]);
    $del_dialog_frame -> Label (-text=>"Really delete folder(s)\n".$folders."\nand everything in it?\n")->grid(-row=>1,-column=>1,-columnspan=>2);
    } else {     # < models >
    my $files = join ("\n",@del_files[@runs]);
    $del_dialog_frame -> Label (-text=>"Really delete model(s)\n".$files."\n?\n")->grid(-row=>1,-column=>1,-columnspan=>2);
  };
  $del_dialog_frame -> Button (-text=>'Delete ', -width=>12, -background=>$button, -activebackground=>$abutton, -border=>$bbw, -command=>sub{
    if ($type == 1) {
      foreach(@del_files[@runs]) {
        if($_ ne "..") {   # for safety...
          status ("Deleting complete folder ".$_);
          rmtree($cwd."/".$_,1,1);
        }
      }
    } else {
        $i=0; while (@runs[$i]) {
          $delstring = "$cwd/@del_files[@runs[$i]].".$setting{ext_ctl};
          $delstring =~ s/\//\\/g;
          status ("Deleting model file ".$_);
          unlink ($delstring);
          $i++;
        };
      }
    status ();
    destroy $del_dialog;
    read_curr_dir($cwd,$filter, 1);
  })->grid(-row=>2,-column=>2,-sticky=>"w");
  $del_dialog_frame -> Button (-text=>'Cancel ', -width=>12, -border=>$bbw, -background=>$button, -activebackground=>$abutton, -command=>sub{destroy $del_dialog})->grid(-column=>1,-row=>2);
}

sub duplicate_model_window {
### Purpose : Creates a dialog window for duplicating a model file
### Compat  : W+L+
  chdir ($cwd);
  my $overwrite_bool=1;
  @runs = @sel;
  my $runno = @ctl_show[@runs[0]];
  $new_ctl_name = new_model_name($runno);
  my $change_run_nos=1; my $est_as_init=0;
  $dupl_dialog = $mw -> Toplevel(-title=>'Duplicate');
  $dupl_dialog -> resizable( 0, 0 );
  $dupl_dialog -> Popup;
  $dupl_dialog_frame = $dupl_dialog-> Frame()->grid(-ipadx=>'10',-ipady=>'10',-sticky=>'n');
  $dupl_dialog_frame -> Label (-text=>'New model number (without '.$setting{ext_ctl}.'):')->grid(-row=>1,-column=>1,-sticky=>"we");
  $dupl_dialog_frame -> Entry (-width=>8, -border=>2, -relief=>'groove',
     -textvariable=>\$new_ctl_name)->grid(-row=>1,-column=>2,-sticky=>"w");  
  $dupl_dialog_frame -> Label (-text=>'Reference model:')->grid(-row=>2,-column=>1,-sticky=>"e");
  my $ref_mod_entry = $dupl_dialog_frame -> Entry (-width=>8, -border=>2, -relief=>'groove', -text=>@ctl_show[@runs[0]],
     -textvariable=>\$new_ctl_ref)->grid(-row=>2,-column=>2,-sticky=>"w");  
  
  my $modelfile = @ctl_show[@runs[0]].".".$setting{ext_ctl};
  my $modelno = $modelfile;
  my $modelno =~ s/\.$setting{ext_ctl}//;
  my $mod_ref = extract_from_model ($modelfile, $modelno);
  my %mod = %$mod_ref;
  $new_ctl_descr = $mod{description}; 
     
  $dupl_dialog_frame -> Label (-text=>'Model description:')->grid(-row=>3,-column=>1,-sticky=>"we");
  $dupl_dialog_frame -> Label (-justify=>"left", -text=>"\nAutomatically changing of table files only works if in the table name the exact filename of\nthe model is incorporated. E.g. if your model file is name 005.mod, then your tables should\nbe named sdtab005, tab005.tab, 005.tab, etc in the control stream\n\n."
    )->grid(-row=>7,-column=>1,-columnspan=>2,-sticky=>"w"); 
  $dupl_dialog_frame -> Entry (-width=>40, -border=>2, -relief=>'groove',
     -textvariable=>\$new_ctl_descr)->grid(-row=>3,-column=>2,-sticky=>"w");  
     
  $dupl_dialog_frame -> Checkbutton (-text=>"Change run-numbers in ouput/tables?",-activebackground=>$bgcol,-variable=>\$change_run_nos)->grid(-row=>4,-column=>2,-columnspan=>2,-sticky=>'w');  
  $dupl_dialog_frame -> Checkbutton (-text=>"Use final parameter estimates from reference model?",-activebackground=>$bgcol,-variable=>\$est_as_init)->grid(-row=>5,-column=>2,-columnspan=>2,-sticky=>'w');  
  $dupl_dialog_frame -> Checkbutton (-text=>"Fix estimates?",-activebackground=>$bgcol,-variable=>\$fix_est)->grid(-row=>6,-column=>2,-columnspan=>2,-sticky=>'w');
    
  #$dupl_dialog_frame -> Label (-text=>'')->grid(-row=>7,-column=>1,-sticky=>"e");
  $dupl_dialog_frame -> Label (-text=>'')->grid(-row=>8,-column=>1,-sticky=>"e");
    
  $dupl_dialog_frame -> Button (-text=>'Duplicate', -width=>12, -border=>$bbw, -background=>$button, -activebackground=>$abutton,-command=>sub {
    if (-e $cwd."/".$new_ctl_name.".".$setting{ext_ctl}) {  # check if control stream already exists;
      my $overwrite = $mw -> messageBox(-type=>'yesno', -icon=>'question',
        -message=>"Control stream with name ".$new_ctl_name.".".$setting{ext_ctl}." already exists.\n Do you want to overwrite?"); 
      if( $overwrite eq "No") {$overwrite_bool=0; $dupl_dialog -> focus();} 
    } else {$overwrite_bool=1};
    
    if ($new_ctl_descr eq "") {$descr_bool=0; $mw -> messageBox(-type=>'ok', -message=>"You have to provide a description of the model");} else {$descr_bool=1};
    if (($overwrite_bool==1)&&($descr_bool==1)) {
      my $new_ctl_ref = $ref_mod_entry -> get();
      duplicate_model ($runno, $new_ctl_name, $new_ctl_descr, $new_ctl_ref, $change_run_nos, $est_as_init, $fix_est, \%setting);
      print $file;
      destroy $dupl_dialog;
      sleep(1); # to make sure the file is ready for reading
      #win_start ($software{editor}, win_path($cwd)."\\".$new_ctl_name.".".$setting{ext_ctl});
      edit_model ( win_path($cwd)."\\".$new_ctl_name.".".$setting{ext_ctl});
      refresh_pirana($cwd);
    } 
  }) -> grid(-row=>8,-column=>2,-sticky=>"w");
  $dupl_dialog_frame -> Button (-text=>'Cancel ', -width=>12, -border=>$bbw, -background=>$button, -activebackground=>$abutton, -command=>sub{destroy $dupl_dialog})->grid(-column=>1,-row=>8,-sticky=>"e");
}

sub new_ctl {
### Purpose : Create a new model file, either blank or from a template (dialog + creation of model file)
### Compat  : W+L+ 
  my $overwrite_bool=1;
  $new_ctl_dialog = $mw -> Toplevel(-title=>'New model file');
  $new_ctl_dialog -> resizable( 0, 0 );
  $new_ctl_dialog -> Popup;
  $new_ctl_frame = $new_ctl_dialog -> Frame () -> grid(-ipadx=>'10',-ipady=>'10');
  $new_ctl_frame -> Label (-text=>'Model number (without .'.$setting{ext_ctl}.'):')-> grid(-column=>1, -row=>1,-sticky=>'nse');
  $new_ctl_frame -> Entry (-width=>10, -border=>2, -relief=>'groove', -textvariable=>\$new_ctl_name)->grid(-column=>2,-row=>1, -sticky=>'w');
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
  $menu = $new_ctl_frame -> Optionmenu(-options => [@templates_descr], -border=>$bbw,  
      -variable=>\$template_chosen,-background=>$lightblue,-activebackground=>$darkblue, -justify=>'left', -border=>$bbw
        )-> grid(-column=>2,-row=>2);
  
  $new_ctl_frame -> Button (-text=>'Create model', -border=>$bbw, -background=>$button,-activebackground=>$abutton, -command=>sub{
    if (-e $cwd."/".$new_ctl_name.".".$setting{ext_ctl}) {  # check if control stream already exists;
        my $overwrite = $mw -> messageBox(-type=>'yesno', -icon=>'question',
        -message=>"Control stream with name ".$new_ctl_name.".".$setting{ext_ctl}." already exists.\n Do you want to overwrite?"); 
        if( $overwrite eq "No") {$overwrite_bool=0;}
      }
    if ($overwrite_bool==1) {
      copy ($base_dir."/templates/".$template_file{$template_chosen}, $cwd."/".$new_ctl_name.".".$setting{ext_ctl});
    }
    read_curr_dir($cwd, $filter,1);
    destroy $new_ctl_frame;
    destroy $new_ctl_dialog;
    edit_model ($cwd."/".$new_ctl_name.".".$setting{ext_ctl});
  }
  )-> grid(-column=>2,-row=>3, -sticky=>'w');
}

sub new_dir {
### Purpose : Create a new folder (dialog + create new dir)
### Compat  : W+L+
  my $overwrite_bool=1;
  $newdir_dialog = $mw -> Toplevel(-title=>'New folder');
  $newdir_dialog -> resizable( 0, 0 );
  $newdir_dialog -> Popup;
  $newdir_dialog_frame = $newdir_dialog-> Frame()->grid(-ipadx=>'10',-ipady=>'10',-sticky=>'n');;
  $newdir_dialog_frame -> Label (-text=>"Folder name: \n")->grid(-column=>1,-row=>1,-sticky=>"ne");
  $newdir_dialog_frame -> Entry (-width=>20, -border=>2, -relief=>'groove', -textvariable=>\$new_dir_name)->grid(-column=>2,-row=>1,-sticky=>"ne");
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
  $ren_dialog -> Popup;
  $ren_dialog_frame = $ren_dialog-> Frame()->grid(-ipadx=>'10',-ipady=>'10',-sticky=>'n');
  $ren_dialog_frame -> Label (-text=>'Model number (without .'.$setting{ext_ctl}.'): '."\n")->grid(-column=>1,-row=>1,-sticky=>"ne");
  $ren_dialog_frame -> Label (-text=>"\nNB. Both model files and result files will be renamed.", -foreground=>'#777777')->grid(-column=>1,-row=>3,-sticky=>"ne",-columnspan=>3);
  $ren_dialog_frame -> Entry (-width=>10, -border=>2, -relief=>'groove', -textvariable=>\$ren_ctl_name)->grid(-column=>2,-row=>1,-sticky=>"nw");
  $ren_dialog_frame -> Button (-text=>"Rename", -width=>12, -border=>$bbw,-background=>$button,-activebackground=>$abutton,-command=>sub{
    if ((-e $cwd."/".$ren_ctl_name.".".$setting{ext_ctl})||((-e $cwd."/".$ren_ctl_name.".".$setting{ext_res}))) {  # check if control stream already exists;
      my $overwrite = $mw -> messageBox(-type=>'yesno', -icon=>'question',
        -message=>"model- or result-file for ".$ren_ctl_name." already exists.\n Do you want to overwrite?"); 
      if( $overwrite eq "No") {$overwrite_bool=0;
      }
    }
    if ($overwrite_bool==1) {
      move ($old.".".$setting{ext_ctl},$ren_ctl_name.".".$setting{ext_ctl});
      move ($old.".".$setting{ext_res},$ren_ctl_name.".".$setting{ext_res});
    }
    read_curr_dir($cwd, $filter, 1);
    destroy $ren_dialog;
  })->grid(-column=>2,-row=>2,-sticky=>"w");
  $ren_dialog_frame -> Button (-text=>'Cancel', -width=>12, -border=>$bbw,-background=>$button,-activebackground=>$abutton,-command=>sub{
    destroy $ren_dialog;
  })->grid(-column=>1,-row=>2,-sticky=>"e");
    
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
   update_model_info(db_read_all_model_data); # get all the models and info from the db if any present
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
      # print int(@ctl_files[$i] =~ m/$filter/i).int(@ctl_descr[$i] =~ m/$filter/i).int(@ctl_descr[$i] =~ m/\.\./ ).$filter."\n";
      if (((@ctl_files[$i] =~ m/$filter/i) || ($models_notes{@ctl_files[$i]} =~ m/$filter/i) || ($models_descr{@ctl_files[$i]} =~ m/$filter/i)) || (@ctl_descr[$i] =~ m/\.\./i) || ($filter eq "")) {        
        unless (((@file_type[$i]<2)&&((@ctl_descr[$i] =~ m/modelfit_dir/i)||(@ctl_descr[$i] =~ m/npc_dir/i)||(@ctl_descr[$i] =~ m/bootstrap_dir/i)||(@ctl_descr[$i] =~ m/sse_dir/i)||(@ctl_descr[$i] =~ m/llp_dir/i))&&($psn_dir_filter==0))||((@file_type[$i]<2)&&(@ctl_descr[$i] =~ m/nmfe_/i)&&($nmfe_dir_filter==0))) {
          push (@ctl_descr_copy, @ctl_descr[$i]);
          push (@ctl_copy, @ctl_files[$i]);
          push (@file_type_copy, @file_type[$i]);
        }
      } 
      $i++; 
    } 
  }
  populate_models_hlist ($models_view);
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

sub populate_models_hlist {
### Purpose : To put all the NM model files and directories found in the current working directory in the main overview table
### Compat  : W+
  my $order = shift;
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
          $runno = "<DIR>"; $style=$dirstyle; $style_ofv = $dirstyle;
          $models_hlist -> itemCreate($i, 0, -text => $runno, -style=>$style);
          $models_hlist -> itemCreate($i, 1, -text => "", -style=>$style);
          $models_hlist -> itemCreate($i, 2, -text => @ctl_descr_copy[$i], -style=>$style );
          for ($j=3;$j<=10;$j++) {$models_hlist -> itemCreate($i, $j, -text => " ", -style=>$dirstyle);}
        } else {
           $runno=@ctl_show[$i]; 
           $mod_background = "#FFFFFF";
           if ($models_colors {$runno} ne "") {
             $mod_background = $models_colors{$runno};
           }
           $style = $models_hlist-> ItemStyle( 'text', -anchor => 'w',-padx => 5, -background=>$mod_background, -font => $font_normal);;
           $style_small = $models_hlist-> ItemStyle( 'text', -anchor => 'w', -padx => 5, -background=>$mod_background, -font => $font_small);;
           
           our $style_green = $models_hlist->ItemStyle( 'text', -padx => 5,-anchor => 'e', -background=>$mod_background, -foreground=>'#008800',-font => $font_fixed);
           our $style_red = $models_hlist->ItemStyle( 'text', -padx => 5,-anchor => 'e', -background=>$mod_background, -foreground=>'#990000', -font => $font_fixed);
           if (($models_ofv{$runno} ne "")&&($models_ofv{$models_refmod{$runno}} ne "")) {
             $ofv_diff = $models_ofv{$models_refmod{$runno}} - $models_ofv{$runno} ;
             if ($ofv_diff >= $setting{ofv_sign}) { $style_ofv = $style_green; }
             if ($ofv_diff < 0) { $style_ofv = $style_red; }
             if (($ofv_diff >= 0)&&($ofv_diff < $setting{ofv_sign})) { 
               $style_ofv = $models_hlist->ItemStyle( 'text', -anchor => 'e',-padx => 5, -foreground=>'#A0A000', -background=>$mod_background,-font => $font_fixed); 
             }
             $ofv_diff = rnd(-$ofv_diff,3); # round before printing
            } else {$ofv_diff=""; $style_ofv = $models_hlist->ItemStyle( 'text', -anchor => 'e',-padx => 5, -foreground=>'#000000', -background=>$mod_background,-font => $font_fixed);}
          if ($models_suc{$runno} eq "S") {$style_success = $style_green} else {$style_success = $style_red};
          if ($models_cov{$runno} eq "C") {$style_cov = $style_green} else {$style_cov = $style_red};
          my $runno_text = "";
          for ($sp=0; $sp<$model_indent{$runno}; $sp++) {$runno_text .= "   "};
          if ($model_indent{$runno}>0) {$runno_text .= "� ";}
          $runno_text .= $runno;
          if (($models_ofv{$runno} eq "")||($models_ofv{$models_refmod{$runno}} eq "")) {
            $models_dofv{$runno} = "";
          }
          $models_hlist -> itemCreate($i, 0, -text => $runno_text, -style=>$style);
          $models_hlist -> itemCreate($i, 1, -text => $models_refmod{$runno}, -style=>$style_small);
          $models_hlist -> itemCreate($i, 2, -text => $models_descr{$runno}, -style=>$style );
          $models_hlist -> itemCreate($i, 3, -text => $models_method{$runno}, -style=>$style_small);
          $models_hlist -> itemCreate($i, 4, -text => $models_ofv{$runno}, -style=>$style_ofv);
          $models_hlist -> itemCreate($i, 5, -text => $ofv_diff, -style=>$style_ofv);
          $models_hlist -> itemCreate($i, 6, -text => $models_suc{$runno}, -style=>$style_success);
          $models_hlist -> itemCreate($i, 7, -text => $models_cov{$runno}, -style=>$style_cov); 
          $models_hlist -> itemCreate($i, 8, -text => $models_bnd{$runno}, -style=>$style_red);
          $models_hlist -> itemCreate($i, 9, -text => $models_sig{$runno}, -style=>$style);
          my $note = $models_notes{$runno};
          $note =~ s/\n/\ /g;
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
    my @tab_files = <*.$setting{ext_tab}>;
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
  if ($setting{use_wfn}==1) {
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
    @tabcsv_files = @all_files;
    @tabcsv_files_loc = @all_files;
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
  $show_tab_button->configure(-background=>$button); # first deactivate all buttons
  $show_csv_button->configure(-background=>$button);
  $show_xpose_button->configure(-background=>$button);
  $show_r_button->configure(-background=>$button);
  $show_all_button->configure(-background=>$button);
  $xpose_button -> configure (-state=>'disabled');
  $GOF_button -> configure (-state=>'disabled');
  $load_rscript_button -> configure (-state=>'disabled');
  $convert_button -> configure (-state=>'disabled');
  $tab_spreadsheet_button -> configure (-state=>'disabled');
  $tab_text_button -> configure (-state=>'disabled');
  $del_tab_button -> configure (-state=>'disabled');
  $check_data_button -> configure (-state=>'disable');
  if (($show_data eq "tab")||($show_data eq "csv")) { # then turn them on again specifically
      $tab_spreadsheet_button -> configure (-state=>'normal');
      $tab_text_button -> configure (-state=>'normal');
      $GOF_button -> configure (-state=>'normal');
      $convert_button -> configure (-state=>'normal');
      $load_rscript_button -> configure (-state=>'normal');
      $del_tab_button -> configure (-state=>'normal');
      $check_data_button -> configure (-state=>'normal');
  }
  if ($show_data eq "tab") {$show_tab_button->configure(-background=>$abutton);}
  if ($show_data eq "csv") {$show_csv_button->configure(-background=>$abutton);}
  if ($show_data eq "R") {
      $tab_text_button -> configure (-state=>'normal');
      $tab_spreadsheet_button -> configure (-state=>'normal');
      $load_rscript_button -> configure (-state=>'normal');
      $show_r_button->configure(-background=>$abutton);
      $del_tab_button -> configure (-state=>'normal');
  }
  if ($show_data eq "xpose") {
      $xpose_button -> configure (-state=>'normal');
      $show_xpose_button->configure(-background=>$abutton);
  }
  if ($show_data eq "*") {
    $tab_text_button -> configure (-state=>'normal');
    $show_all_button->configure(-background=>$abutton);
    $del_tab_button -> configure (-state=>'normal');
  }
}

sub tab_dir { 
### Purpose : Read tab/csv/r files for the current dir
### Compat  : W+
  my $tabdir = shift;  
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
sub populate_tab_hlist {
### Purpose : Put the tables/files in the current (and data-)dir in the listbox that was created earlier
### Compat  : W+
  $i=0;
  my $hlist = shift;
  $style = $align_left;
  foreach (@tabcsv_files) {
    if($hlist) {
      $hlist -> add($i);
      my $style = $hlist-> ItemStyle('text', -anchor => 'w',-padx => 5, -background=> $tab_hlist_color, -font => $font_normal);
      $hlist -> itemCreate($i, 0, -text => $_, -style=>$style);
      $i++;
    }
  }
}

sub generate_random_string {
### Purpose : Generate a random string of n length
### Compat  : W+L? 
	my $length_of_randomstring=shift;
	my @chars=('a'..'z','A'..'Z','0'..'9','_');
	my $random_string;
	foreach (1..$length_of_randomstring) 
	{$random_string.=$chars[rand @chars];}
	return $random_string;
}

sub print_note {
### Purpose : Print a note saying that the model was executed from Pira�a
### Compat  : W+L+?
  open (NOTE,">note.txt");
  print NOTE "*********************************************************\n";
  print NOTE "Compiled by Pirana v".$version." using NONMEM version: ".$nm_inst_chosen."\n";
  print NOTE "Run started locally by ".$setting{name_researcher}."\n";
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

sub exec_run_nmfe {  
### Purpose : Run a model using the nmfe command
### Compat  : W+L?
  status ("Starting run using nmfe (or NMQual perl file)");
  if (@nm_installations>0) {
  ($nm_inst, $method) = @_;
  @runs = $models_hlist -> selectionGet ();
  @files = @ctl_show[@runs];
  $file_string = join (' ',@files);
  chdir($cwd);
  if (($gif{cluster_active}==1)&&($setting{use_cluster}==1)) {
    @cur_dir = split('/',unix_path($cwd));
    shift(@cur_dir);
    $cur_dir_unix = join('/',@cur_dir); 
    $nm_dir_cluster = $nm_dirs_cluster{@nm_installations[$nm_inst_chosen]}; 
    $nm_ver_cluster = $nm_vers_cluster{@nm_installations[$nm_inst_chosen]}; 
  }
  if ( $nm_dir_check==0 ) { # start NONMEM regular, in the current folder
    if (($gif{cluster_active}==1)&&($setting{use_cluster}==1)) {
      foreach $file (@files) {
        my $command = 'start '.$setting{ssh_login}.' "cd ~/'.$cur_dir_unix.'; '.$nm_dir_cluster."/nmfe".$nm_ver_cluster." ".$file.'.'.
          $setting{ext_ctl}.' '.$file.'.'.$setting{ext_res}.' &"';
        if ($stdout) {$stdout -> insert('end', "\n".$command);}
        system $command;
        db_log_execution ($file.".".$setting{ext_ctl}, $models_descr{$model}, "nmfe", "LinuxCluster", $command, $setting{name_researcher});
      }
    } else {
      print_note($nm_inst);
      #print $ENV{'PATH'};
      my $command = "start /low ".win_path($nm_dirs{$nm_inst}."/util/pirana_runs".$nm_vers{$nm_inst}.".bat ".$file_string);
      if ($stdout) {$stdout -> insert('end', "\n".$command);}
      system $command;
      foreach my $model (@files) {
        db_log_execution ($model.".".$setting{ext_ctl}, $models_descr{$model}, "nmfe", "local", $command, $setting{name_researcher});   
      }
    }
  }
  if ( $method =~ m/compile/i) { # Only compile, in current folder
    foreach (@files) {
      compile_run($nm_inst_chosen, $_);  # NM installation, run
      chdir($cwd);
    }
  }
  if ( $method =~ m/Test syntax/i) { # Test syntax, in current folder
    my $errors = "";
    foreach $file (@files) {
      open (OUT, win_path($nm_dirs{$nm_inst}."/tr/nmtran.exe <".$file.".".$setting{ext_ctl}).' |') or die "Could not open NM-TRAN\n";
      while (my $line = <OUT>) {
        $errors .= $line;
      }
      close OUT;
    }
    text_window($errors, "NM-TRAN messages");
  }
  if ( $nm_dir_check==1) { # start NM run in a new folder
    $new_dir = $run_in_nm_dir;
    foreach $file (@files) {
      my $command;
      my $new_dir = move_nm_files($file, $run_in_nm_dir); # move NM files to new dir and return the dir
      if (-d $new_dir) {
        chdir ($new_dir);
        print_note($nm_inst);
        if (($gif{cluster_active}==1)&&($setting{use_cluster}==1)) {
           $command = 'start '.$setting{ssh_login}.' "cd ~/'.$cur_dir_unix.'/'.$new_dir.'; '.$nm_dir_cluster."/nmfe".$nm_ver_cluster." ".$file.'.'.
             $setting{ext_ctl}.' '.$file.'.'.$setting{ext_res}.' &"';
           if ($stdout) {$stdout -> insert('end', "\n".$command);}
        } else {
           $command = "start /low ".win_path($nm_dirs{$nm_inst}."/util/pirana_runs".$nm_vers{$nm_inst}.".bat ".$file);
           if ($stdout) {$stdout -> insert('end', "\n".$command);}
        } 
        chdir($cwd);
        rmdir ($new_dir); # only works if directory is empty... So is cleared if unsuccesful.
      }
      system $command;
      db_log_execution ($file.".".$setting{ext_ctl}, @ctl_descr[$file], "nmfe", "local", $command, $setting{name_researcher});   
    }
  }
#  if ( $method =~ m/monitor/i) { # Monitor run, not implemented currently
#    foreach (@files) {
#      chdir ($base_dir);
#      system "start perl internal\\monitor.pl ".$file_string;
#      chdir ($cwd);     
#    }
#  }
  } else {message("Please add local NONMEM installation(s) to Pirana first.")};
  status ();
}

sub text_window {
### Purpose : Show a window with a text-widget containing the specified text
### Compat  : W+L+
  my ($text, $title) = @_;
  unless ($text_window) {
    our $text_window = $mw -> Toplevel(-title=>$title);
    $text_window -> OnDestroy ( sub{
      undef $text_window; undef $text_window_frame;
    });
    $text_window -> resizable( 0, 0 );
  }
  our $text_window_frame = $text_window -> Frame(-background=>$bgcol)->grid(-ipadx=>10,-ipady=>10)->grid(-row=>1,-column=>1, -sticky=>'nwse');
  our $text_text = $text_window_frame -> Scrolled ('Text', 
      -scrollbars=>'e', -width=>80, -height=>35, 
      -background=>"#ffffff",-exportselection => 0, 
      -relief=>'groove', -border=>2, 
      -selectbackground=>'#606060',-font=>$font_normal,-highlightthickness =>0) -> grid(-column=>1, -row=>1, -sticky=>'nwes');
  $text_text->insert('end', $text);
  return $text_text; 
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
      $run_client_w -> Popup;
      $run_client_frame = $run_client_w -> Frame()->grid(-ipadx=>'10',-ipady=>'10',-sticky=>'nws');
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
  $see_comp_log = $mw -> messageBox(-type=>'yesno', -icon=>'question',
      -message=>($successfull_comps)." runs were succesfully copied to cluster\nClient(s):\n".$used_clients."\n There were ".$comp_errors." unsuccesful compilations.\n Do you want to view the compilation log?"); 
  if( $see_comp_log eq "Yes") {
    chdir ($base_dir);
    edit_model ("log\\compilation.txt");
    chdir ($cwd);
  }
}

sub compile_run {
### Purpose : Compile an model to an .exe file (using nmfe-method)
### Compat  : 
  $curr_dir = fastgetcwd;
  if ($ENV{PATH}=~m/$nm_dir/) {;} else {$ENV{PATH}="$nm_dir/util;".$ENV{PATH}} ;
  $error_flag=0;
  $nm_to_use = @_[0];
  $file = @_[1];
  my $new_dir = move_nm_files ($file, $run_in_nm_dir);
  if (-e $new_dir && ($error_flag==0)) {
      chdir $new_dir;
      $nm_dir = $nm_dirs{@_[0]};
      print OUT "Run  : ".$file;
      #print OUT "date ";
      #print OUT "time ";
      print OUT win_path($nm_dir."\\util\\pirana_nmfe".$nm_vers{$nm_to_use}."_compile.bat "
          .$file.".".$setting{ext_ctl}." ".$file.".".$setting{ext_res}.' >"'.$base_dir.'\log\compilation_NM.txt"');
      system win_path($nm_dir."\\util\\pirana_nmfe".$nm_vers{$nm_to_use}."_compile.bat "
          .$file.".".$setting{ext_ctl}." ".$file.".".$setting{ext_res}.' >"'.$base_dir.'\log\compilation_NM.txt"'); 
    }
  chdir ($curr_dir);
  return $new_dir;
}

sub move_nm_files {  
### Purpose : move nonmem files to a new directory for compilation or running in new dir
### Compat  : W+L?
  my ($file, $new_dir) = @_;
  open (ctl,"<$cwd/".$file.".".$setting{ext_ctl}); @S=<ctl>;
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
  @fortran3 = split /\./, $fortran3;
  @msfi = split (" ", $msfi);
  print $include."\n";
  @include = split ("=", $include);
  print @include[1]."\n";
  @include_files = split(",", @include[1]);
  
  mkdir ($new_dir);

  unless (copy($file.".".$setting{ext_ctl}, $new_dir."/".$file.".".$setting{ext_ctl})) {print OUT "Error: Unable to copy control stream.\n"; $error_flag=1;}
  $datafile = unix_path(@data[1]);
  #$datafile =~ s/\./\\\./g;
  unless (copy($datafile, $new_dir."/".$datafile)) {print OUT "echo Error: Unable to copy dataset. \n"; $error_flag=1;}
  $for="FOR";
  if (@fortran3[1]=~$for) {
    copy (@fortran3[0].".for",$new_dir."/".@fortran3[0].".for");
    copy (@fortran3[0].".csv",$new_dir."/".@fortran3[0].".csv");
  }
  copy (@fortran3[0].".for",$new_dir."/".@fortran3[0].".for");
  if (@msfi[1]=~MSF) {copy (@msfi[1],$new_dir."/".@msfi[1]); }     
  # include misc files (such as csv files mentioned in included .for files)
  
  foreach(@include_files) {
    if (-e $_) {
      copy ($_,$new_dir."/".$_);
      # print $_;
    }
  }
  return $new_dir;
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
### Purpose : Run a model on PCluseter (using nmfe-method)
### Compat  : W+L?
  if ($setting{zink_host eq ""}) {
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
  print OUT "*** NONMEM Cluster compilation log created by Pira�a                         ***\n";
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
    $copy_dir_res_window -> Popup;
    $copy_dir_res_frame = $copy_dir_res_window->Frame()->grid(-ipadx=>8, -ipady=>8);
    $copy_dir_res_frame -> Label (-text=>"Copy files:",-font=>$font_normal,)->grid(-row=>1, -column=>1, -sticky=>"ne");
    $copy_dir_res_text = $copy_dir_res_frame -> Scrolled ('Text', -font=>$font_normal,-width=>32, -height=>8, -scrollbars=>'e') 
      -> grid(-row=>1, -column=>2, -ipady=>5, -columnspan=>2);
    $copy_dir_res_text -> insert ("0.0", $lst_files."\n".$tab_files);
    $copy_dir_res_text -> configure(state=>'disabled'); 
    $copy_res_to = $cwd;
    $copy_dir_res_frame -> Label (-text=>" ",-font=>$font_normal,)->grid(-row=>2, -column=>1, -sticky=>"ne");
    $copy_dir_res_frame -> Label (-text=>"To folder:",-font=>$font_normal,)->grid(-row=>3, -column=>1, -sticky=>"ne");
    $copy_dir_res_text = $copy_dir_res_frame -> Entry (-textvariable => \$copy_res_to, -font=>$font_normal, -width=>32) 
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
        @res_lst = ("'".$model, $models_ofv{$model}, $models_descr{$model}, $models_notes{$model}, 
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
  #our $frame2 = $mw -> Frame() ->grid(-row=>2,-column=>3,-ipadx=>'8', -ipady=>'0',-sticky=>'n');
  unless($tab_frame) {
    $tab_frame = $mw -> Frame(-background=>$bgcol) ->grid(-row=>2,-column=>3, -rowspan=>3,-ipadx=>5, -ipady=>0,-sticky=>'wn');
    if ($os =~ m/MSWin/i) {$tab_frame -> Label(-text=>"",-font=>'Arial 1', -height=>1)->grid (-row=>3, -column=>1);}
    $tab_button_frame = $tab_frame -> Frame() ->grid(-row=>2,-column=>7,-columnspan=>8,-ipadx=>'0', -ipady=>'0',-sticky=>'wn');
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
        edit_model (@res_files_loc_copy[$models_hlist -> selectionGet]);
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
        -head       => 1,
        -selectmode => "single",
        -highlightthickness => 0,
        -columns    => int(@models_hlist_headers),
        -scrollbars => 'se',
        -width      => 17,
        -height     => $nrows,
        -border     => 1,
        -pady       => 1,
        -padx       => 0,
        -background => $tab_hlist_color,
        -selectbackground => $pirana_orange,
        -font       => $font_normal,
        -command    => sub {
          if (-e $software{spreadsheet}) {
            my $tabsel = $tab_hlist -> selectionGet ();
            my $tab_file = win_path(@tabcsv_loc[@$tabsel[0]]);
            if ($show_data eq "csv") {
              win_start($software{spreadsheet},'"'.win_path($tab_file).'"');
            }
            if ($show_data eq "tab") {
              tab2csv ($tab_file,$tab_file."_pirana.".$setting{ext_csv});
              win_start($software{spreadsheet},'"'.win_path($tab_file.'_pirana.'.$setting{ext_csv}).'"');
            } 
          } else {message("Spreadsheet application not found. Please check settings.")};
        },
        -browsecmd   => sub{
            my $tabsel = $tab_hlist -> selectionGet ();
            my $tab_file = win_path(@tabcsv_files[@$tabsel[0]]);
            update_text_box(\$tab_file_text, $tab_file);
            update_text_box(\$tab_file_size, (-s $tab_file)." kB");
            my $mod_time;
            if (-e $cwd."/".$tab_file) {$mod_time = gmtime(@{stat $cwd."/".$tab_file}[9])};
            update_text_box(\$tab_file_mod, $mod_time);
            my $note = $table_note{$tab_loc};
            $note =~ s/\n/ /g;
            update_text_box(\$tab_file_note, $note);
        }
      )->grid(-column => 1, -columnspan=>6, -row => 2, -sticky=>'nswe', -ipady=>0);   
    $help->attach($tab_hlist, -msg => "Data files\n*\\ = in alternate directory");
    my $tab_menu = $tab_hlist->Menu(-tearoff => 0,-title=>'None', -menuitems=> [
       [Button => "Properties...",  -command => sub{niy()}], 
       [Button => "Delete file", -command => sub{niy()}], 
       [Button => "Rename file", -command => sub{niy()}]]);
    $tab_hlist -> bind("<Button-3>" => [ sub {
       $tab_hlist -> focus; # focus on listbox widget 
       my($w, $x, $y) = @_;
       our $tabsel = $tab_hlist -> selectionGet ();
       if (@$tabsel >0) { $tab_menu -> post($x, $y) } else {
         message("Please select a file first...");
       }
    }, Ev('X'), Ev('Y') ] );
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
  })-> grid(-row=>1,-column=>$b, -sticky => 'w');
  $b++;
  $help->attach($show_tab_button, -msg => "Show .".$setting{ext_tab}." files");
  $show_csv_button = $tab_frame -> Button(-text=>'CSV', -width=>@tab_button_widths[1],-background=>$button, -font=>$font_normal,-activebackground=>$abutton,-border=>$bbw, -command=>sub{
    our $show_data="csv";
    configure_tab_buttons($show_data);
    tab_dir($cwd);
    populate_tab_hlist($tab_hlist);
  })-> grid(-row=>1,-column=>$b, -sticky => 'w');
  $b++;
  $help->attach($show_csv_button, -msg => "Show .CSV files");
  $show_xpose_button = $tab_frame -> Button(-text=>'Xpose',-width=>@tab_button_widths[2],-background=>$button,-font=>$font_normal,-activebackground=>$abutton,-border=>$bbw, -command=>sub{
    our $show_data="xpose";
    configure_tab_buttons($show_data);
    tab_dir($cwd);
    populate_tab_hlist($tab_hlist);
  })-> grid(-row=>1,-column=>$b, -columnspan=>2, -sticky => 'we');
  $help->attach($show_xpose_button, -msg => "Show XPose data");
  $b = $b+2;
  $show_r_button = $tab_frame -> Button(-text=>'R',-width=>@tab_button_widths[3],-background=>$button,-font=>$font_normal,-activebackground=>$abutton,-border=>$bbw, -command=>sub{
    our $show_data="R";
    configure_tab_buttons($show_data);
    tab_dir($cwd);
    populate_tab_hlist($tab_hlist);
  })-> grid(-row=>1,-column=>$b, -columnspan=>1, -sticky => 'we');
  $help->attach($show_r_button, -msg => "Show R/S scripts");
  $b++;
  $show_all_button = $tab_frame -> Button(-text=>'*',-width=>@tab_button_widths[4],-background=>$button,-activebackground=>$abutton,-border=>$bbw, -command=>sub{
    our $show_data="*";
    configure_tab_buttons($show_data);
    tab_dir($cwd);
    populate_tab_hlist($tab_hlist);
  })-> grid(-row=>1,-column=>$b, -sticky => 'we');
  $b++;
  $help->attach($show_all_button, -msg => "Show all files in folder");
   
  $tab_frame_info = $tab_frame -> Frame(-background=>$bgcol)->grid(-row=>5, -column=>1, -rowspan=>1, -columnspan=>8, -ipady=>4,-sticky=>"nw");
  $tab_frame_info -> Label(-text=>"File:", -font=>$font_normal, -background=>$bgcol)-> grid(-row=>1, -column=>1, -sticky=>"nw");
  $tab_frame_info -> Label(-text=>"Size:", -font=>$font_normal, -background=>$bgcol)-> grid(-row=>2, -column=>1, -sticky=>"nw");
  $tab_frame_info -> Label(-text=>"Crtd:", -font=>$font_normal, -background=>$bgcol)-> grid(-row=>3, -column=>1, -sticky=>"nw");
  $tab_frame_info -> Label(-text=>"Note:", -font=>$font_normal, -background=>$bgcol)-> grid(-row=>4, -column=>1, -sticky=>"nw");
  our $tab_file_text = $tab_frame_info -> Text (
      -width=>20, -relief=>'sunken', -border=>0, -height=>1, 
      -font=>$font_small, -background=>"#f6f6e6", -state=>'normal'
  )->grid(-column=>2, -row=>1,-sticky=>'nw', -ipadx=>0);
  our $tab_file_size = $tab_frame_info -> Text (
      -width=>20, -relief=>'sunken', -border=>0, -height=>1, 
      -font=>$font_small, -background=>"#f6f6e6", -state=>'disabled'
  )->grid(-column=>2, -row=>2,-sticky=>'nw', -ipadx=>0);
  our $tab_file_mod = $tab_frame_info -> Text (
      -width=>20, -relief=>'sunken', -border=>0, -height=>1, 
      -font=>$font_small, -background=>"#f6f6e6", -state=>'disabled'
  )->grid(-column=>2, -row=>3,-sticky=>'nw', -ipadx=>0);
  our $tab_file_note = $tab_frame_info -> Text (
      -width=>20, -relief=>'sunken', -border=>0, -height=>1, 
      -font=>$font_small, -background=>"#f6f6e6", -state=>'disabled'
  )->grid(-column=>2, -row=>4,-sticky=>'nw', -ipadx=>0);
 
  # result buttons
  $res_buttons = $model_overview_frame -> Frame(-background=>$bgcol) ->grid(-row=>11,-column=>1,-rowspan=>5,-ipadx=>'0', -ipady=>'0',-sticky=>'wne');
  $res_buttons->Label(-text=>"Results: ", -background=>$bgcol,-width=>7,-height=>1, -font=>$font_normal)->grid(-row=>0,-column=>1,-sticky=>'es',-ipadx=>0, -columnspan=>2);
  
  $sum_HTML_button = $res_buttons->Button(-image=>$gif{HTML}, -state=>'normal', -width=>20, -height=>24, -border=>$bbw, -background=>$button,-activebackground=>$abutton,-command=>sub{
      @run = @ctl_show[$models_hlist -> selectionGet];
      foreach (@run) {$_ .= ".".$setting{ext_res}};
      output_results_HTML(@run[0], \%setting);
      win_start($software{browser}, '"file:///'.unix_path($cwd).'/pirana_sum.html"');
  }) ->grid(-row=>2,-column=>1,-columnspan=>1,-sticky=>'wens');
  $help->attach($sum_HTML_button, -msg => "Generate run report and list parameter estimates");
  
  $show_output_button = $res_buttons->Button(-image=>$gif{notepad},-width=>20, -height=>24, -border=>$bbw,-background=>$button, -activebackground=>$abutton,-command=>sub{
      if (($models_hlist -> selectionGet()) > 0) {
        foreach ($models_hlist -> selectionGet()) { 
          edit_model(@ctl_show[$_].".".$setting{ext_res});
        }
      }
    })->grid(-row=>1,-column=>2,-columnspan=>1,-sticky=>'wens');
  $help->attach($show_output_button, -msg => "Show NONMEM output file (".$setting{ext_res}.")");
  
  $del_res_button = $res_buttons->Button(-image=>$gif{deldoc}, -width=>20, -height=>24, -border=>$bbw,-background=>$button, -activebackground=>$abutton,-command=>sub{
      @res_sel = $models_hlist -> selectionGet();
      @res_file = @ctl_show[@res_sel];
      $res_files = join ("\n",@res_file);
      my $delete = $mw -> messageBox(-type=>'yesno', -icon=>'question', -message=>"Do you really want to results files for these models: \n".$res_files."\n?");       
      if( $delete eq "Yes") {
        $delete_errors = "";
        $i=0;
        foreach (@res_file) {
          my $file = $_.".".$setting{ext_res};
          unless (unlink (unix_path($file))) { 
            $delete_errors .= $_."\n";
          } 
          delete_run_results ($_);
          $i++;
        }
        if ($delete_errors ne "") {message("For some reason, these output file(s) could not be deleted:\n".$delete_errors."\nCheck file/folder permissions.")};
        refresh_pirana($cwd);
        status();
      }
    })->grid(-row=>4,-column=>2,-columnspan=>1,-sticky=>'wens');
  $help->attach($del_res_button, -msg => "Delete output-file and results for this run"); 
  
  $sum_list_button = $res_buttons -> Button(-image=>$gif{compare}, -state=>'normal', -width=>20, -height=>24, -border=>$bbw, -background=>$button,-activebackground=>$abutton,-command=>sub{
    create_output_summary ("pirana_output_list.csv");
    if (-e $software{spreadsheet}) {
      win_start($software{spreadsheet},'"'.win_path('pirana_output_list.csv').'"');
    } else {message("Spreadsheet application not found. Please check settings.")};
    status ();
  }) ->grid(-row=>3,-column=>2,-columnspan=>1,-sticky=>'wens');
  $help->attach($sum_list_button, -msg => "Generate summary (csv-file) of all NONMEM output files");
 
  $show_inter_button = $res_buttons->Button(-image=>$gif{edit_inter},-width=>20, -height=>24, -border=>$bbw,-background=>$button, -activebackground=>$abutton,-command=>sub{
      $cwd = $dir_entry -> get();
      chdir($cwd);
      show_inter_window();
      if ($inter_window) {$inter_window -> focus();}
      })->grid(-row=>4,-column=>1,-sticky=>'wens');
  $help->attach($show_inter_button, -msg => "Show intermediate results for models\ncurrently running in this directory");
  
  $copy_dir_res_button = $res_buttons->Button(-image=>$gif{folderout},-width=>20, -height=>24, -border=>$bbw,-background=>$button, -activebackground=>$abutton,-command=>sub{
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
    })->grid(-row=>2,-column=>2,-sticky=>'wens');
  $help->attach($copy_dir_res_button, -msg => "Copy results files and \$TABLE files from a subfolder to the current folder");
  
  $tree_txt_button = $res_buttons -> Button(-image=>$gif{treeview2}, -state=>'normal', -width=>20, -height=>24, -border=>$bbw, -background=>$button,-activebackground=>$abutton,-command=>sub{
    my($tree_models_ref, $tree_text) = tree_models();
    text_window($tree_text, "Model tree");
  }) ->grid(-row=>3,-column=>1,-columnspan=>1,-sticky=>'wens');
  $help->attach($tree_txt_button, -msg => "View run record as tree");
  
  $show_estim_button = $res_buttons->Button(-image=>$gif{estim},-width=>20, -height=>24, -border=>$bbw,-background=>$button, -activebackground=>$abutton,-command=>sub{
      my @lst = @ctl_show[$models_hlist -> selectionGet ()];
      my $lst = @lst[0].".".$setting{ext_res};
      show_estim_window ($lst);
      $estim_window -> focus();
      })->grid(-row=>1,-column=>1,-sticky=>'wens');
  $help->attach($show_estim_button, -msg => "Show final parameter estimates for runs");
  
  $show_ofv=0;
  $show_successful=0;
  $show_covar=0;
   
  $tab_spreadsheet_button = $tab_button_frame -> Button(-image=>$gif{spreadsheet},-width=>29, -height=>25, -border=>$bbw,-background=>$button,-activebackground=>$abutton,-command=>sub{
    if (-e $software{spreadsheet}) {
      my $tabsel = $tab_hlist -> selectionGet ();
      my $tab_file = win_path(@tabcsv_loc[@$tabsel[0]]);
      unless ($tab_file =~ m/.$setting{ext_csv}/i ) {
        tab2csv ($tab_file,$tab_file."_pirana.".$setting{ext_csv});
        win_start($software{spreadsheet},'"'.win_path($tab_file.'_pirana.'.$setting{ext_csv}).'"');
      } else {win_start($software{spreadsheet},'"'.win_path($tab_file).'"'); } 
    } else {message("Spreadsheet application not found. Please check settings.")};
  }) -> grid(-row=>1,-column=>1,-columnspan=>1,-sticky=>'we');
  $help->attach($tab_spreadsheet_button, -msg => "Load tab/csv file in spreadsheet");
  
  $tab_text_button = $tab_button_frame ->Button(-image=>$gif{notepad}, -width=>29, -height=>25, -border=>$bbw,-background=>$button,-activebackground=>$abutton,-command=>sub{
      my $tabsel = $tab_hlist -> selectionGet ();
      $tab_file = win_path(@tabcsv_loc[@$tabsel[0]]);
      edit_model(win_path($tab_file));
  }) -> grid(-row=>2,-column=>1,-columnspan=>1,-sticky=>'we');
  $help->attach($tab_text_button, -msg => "Load tab/csv file in text-editor");
  
  $convert_button = $tab_button_frame ->Button(-image=>$gif{convert}, -width=>29,-height=>25, -border=>$bbw, -background=>$button,-activebackground=>$abutton,-command=>sub{
      my $tabsel = $tab_hlist -> selectionGet ();
      my $tab_file = win_path(@tabcsv_loc[@$tabsel[0]]);
        csv_tab_window ($tab_file);
    }) -> grid(-row=>3,-column=>1,-columnspan=>1,-sticky=>'we');
  $help->attach($convert_button, -msg => "Convert CSV<->TAB");
  
  $del_tab_button = $tab_button_frame ->Button(-image=>$gif{deldoc}, -width=>29, -height=>25,-border=>$bbw,-background=>$button, -activebackground=>$abutton,-command=>sub{
      my $tabsel = $tab_hlist -> selectionGet ();
      my $tab_file = win_path(@tabcsv_loc[@$tabsel[0]]);
      my $delete = $mw -> messageBox(-type=>'yesno', -icon=>'question', -message=>"Do you really want to delete ".$tab_file."?"); 
      if( $delete eq "Yes") {unless(unlink (unix_path($cwd."/".$tab_file))) {message("For some reason, ".$tab_file." could not be deleted.\nCheck file/folder permissions.")} else {refresh_pirana($cwd, $filter,1)} };  
    })->grid(-row=>4,-column=>1,-columnspan=>1,-sticky=>'w');
  $help->attach($del_tab_button, -msg => "Delete data-file");
  $check_data_button = $tab_button_frame ->Button(-image=>$gif{check}, -width=>29, -height=>25,-border=>$bbw,-background=>$button, -activebackground=>$abutton,-command=>sub{
      my $tabsel = $tab_hlist -> selectionGet ();
      my $tab_file = win_path(@tabcsv_loc[@$tabsel[0]]);
      my $html = check_out_dataset($tab_file);
      win_start ($software{browser}, '"file:///'.unix_path($cwd).'/'.$html.'"');
    })->grid(-row=>5,-column=>1,-columnspan=>1,-sticky=>'w');
  $help->attach($check_data_button, -msg => "Checkout dataset (needs columns: ID, DV, TIME)");
  
  $i=1;
  $load_rscript_button = $tab_button_frame ->Button(-image=>$gif{r_in}, -width=>29, -height=>25,-border=>$bbw,-background=>$button, -activebackground=>$abutton, -state=>'normal',-command=>sub{
      my $scriptsel = $tab_hlist -> selectionGet ();
      my $script_file = win_path(@tabcsv_loc[@$scriptsel[0]]);
      if (-e $script_file) {
        if ($show_data eq "R") {
          run_script ('"'.$software{r_dir}.'\\bin\\R" --vanilla <'.$script_file.' |');
        }
        if ($show_data eq "csv") {
          open (RPROF,">.Rprofile");
          #print RPROF "cat ('".unix_path($script_file)." is available as data-frame: csv\n') \n";
          print RPROF "cat ('csv <- data.frame(read.csv (file=\"".unix_path($script_file)."\"))\n')\n";
          print RPROF "csv <- data.frame(read.csv (file='".unix_path($script_file)."'))\n";
          close (RPROF);
          win_start($software{r_dir}.'/bin/rgui.exe');
        }
        if ($show_data eq "tab") {
          open (RPROF,">.Rprofile");
          # determine if tab has headers
          open (TAB, $script_file);
          $line1 = <TAB>;
          close TAB;
          my ($header, $skip);
          if ($line1 =~ m/TABLE/) {$header="T"; $skip=1} else {$header="F"; $skip=0};
          #print RPROF 'cat ("'.unix_path($script_file).' is available as data-frame: tab\n")'."\n";
          print RPROF "cat ('tab <- read.table (file=\"".unix_path($script_file)."\")\n')\n";
          print RPROF "tab <- read.table (file='".unix_path($script_file)."', skip=".$skip.", header=".$header.")\n";
          close (RPROF);
          win_start($software{r_dir}.'/bin/rgui.exe');
        }
      }
    })->grid(-row=>6,-column=>1,-columnspan=>1,-sticky=>'w');
  $help->attach($load_rscript_button, -msg => "Run R script, or load dataset in R-GUI");
  
  $GOF_button = $tab_button_frame ->Button(-image=>$gif{plots}, -width=>29, -height=>25, -border=>$bbw, -background=>$button,-activebackground=>$abutton,-command=>sub{
     my $tabsel = $tab_hlist -> selectionGet ();
     my $tab_file = win_path(@tabcsv_loc[@$tabsel[0]]);
     if (-e $tab_file) {
        unless($show_data eq "xpose") {create_plot_window($mw, $tab_file, $show_data, $software{r_dir}, \$gif{r_in}, \$gif{delete} );}
     }
  }) -> grid(-row=>7,-column=>1,-columnspan=>1,-sticky=>'wens');
  $help->attach($GOF_button, -msg => "Explore dataset / plot variables");

  $xpose_button = $tab_button_frame  -> Button(-image=>$gif{xpose} , -width=>29,-height=>25,-border=>$bbw,-background=>$button,-activebackground=>$abutton, -state=>'disabled', -command=> sub{
    if (-e $software{r_dir}."/bin/rgui.exe") {
      chdir($cwd);
      $model = "";
      if (@tabcsv_files[$tab_hlist -> selectionGet()] ne "") {
        my $tabsel = $tab_hlist -> selectionGet ();
        my $tab_file = win_path(@tabcsv_files[@$tabsel[0]]);
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
        win_start(win_path($software{r_dir}.'/bin/rgui.exe'));
      } else {message ("Select an Xpose dataset to load Xpose.")};
    } else {message ("R was not found. Please check software settings.")};
    }) -> grid(-row=>8,-column=>1, -sticky => 'wens');
  $help->attach($xpose_button, -msg => "Open Xpose dataset");
  $table_info_button = $tab_button_frame ->Button(-image=>$gif{edit_info_green}, -width=>29, -height=>25, -border=>$bbw, -background=>$button,-activebackground=>$abutton,-command=>sub{
     my $tabsel = $tab_hlist -> selectionGet ();
     my $tab_file = win_path(@tabcsv_files[@$tabsel[0]]);
     if (-e $tab_file) {
        table_info_window($tab_file);
     }
  }) -> grid(-row=>9,-column=>1,-columnspan=>1,-sticky=>'wens');
  $help->attach($table_info_button, -msg => "Show/edit table or file info");
  show_links();
  }
}

sub show_links {  
  if ($tab_frame) {
  my $links_height = 24;
  our $frame_links = $frame_dir -> Frame() ->grid(-row=>2,-column=>14, -columnspan=>3, -ipadx=>'0',-ipady=>'0',-sticky=>'wn');
  our $missing=0;
  
  $frame_dir -> Label(-text=>'    Cmd:', -font=>$font_normal, -background=>$bgcol)->grid(-row=>1, -column=>12, -sticky => 'ens');
  $frame_dir -> Label(-text=>'  Start:', -font=>$font_normal, -background=>$bgcol)->grid(-row=>2, -column=>12, -sticky => 'ens');
  if ($os =~ m/MSWin/i) {
    $frame_dir -> Label(-text=>'', -font=>'Arial 1', -width=>40, -background=>$bgcol)->grid(-row=>1, -column=>15, -sticky => 'ens');
  }
  our $frame_logo = $mw -> Frame(-background=>$bgcol)-> grid(-row=>0, -column=>2, -columnspan=>2, -sticky=>"ne", -ipadx=>10);
  our $pirana_logo = $frame_logo -> Label (-border=>0,-text=>"Pirana\nv".$version, -justify=>"right", -background=>$bgcol, -font=>$font_normal, -state=>"disabled")->grid(-row=>1, -column=>1, -columnspan=>10,-rowspan=>1, -sticky => 'en');

  $i=4; 
  $software{tty} =~ m/\.exe/i;
  my $pos = length $`;
  our $calc_cov_button = $frame_links -> Button(-image=>$gif{calc_cov}, -border=>$bbw,-width=>20,-height=>$links_height, -border=>$bbw,-background=>$button,-activebackground=>$abutton,-command=> sub{
    cov_calc_window();
  })->grid(-row=>1,-column=>$i,-sticky=>'news');
  $i++;
  $help->attach($calc_cov_button, -msg => "Covariance calculator");
  if (-e $software{calc}) {
    our $calc_button = $frame_links -> Button(-image=>$gif{calc}, -border=>$bbw,-width=>20,-height=>$links_height, -border=>$bbw,-background=>$button,-activebackground=>$abutton,-command=> sub{
    win_start($software{calc});
    })->grid(-row=>1,-column=>$i,-sticky=>'news');
    $i++;
    $help->attach($calc_button, -msg => "Open system calculator");
  } 
#  if (-e substr($software{tty}, 0, $pos+4)) {
    our $putty_button = $frame_links -> Button(-image=>$gif{putty},-border=>$bbw, -width=>20,-height=>$links_height, -border=>$bbw,-background=>$button,-activebackground=>$abutton,-command=> sub{
      win_start(substr($software{tty}, 0, $pos+4), substr($software{tty},$pos+5, length($software{tty})-($pos+4)));  
    }) ->grid(-row=>1,-column=>$i,-sticky=>'news');
    $help->attach($putty_button, -msg => $software_descr{tty});
    $i++;
#  }
  if (-e $software{r_dir}."/bin/rgui.exe") {
    our $r_button = $frame_links -> Button(-image=>$gif{r}, -width=>20, -height=>$links_height, -border=>$bbw, -background=>$button,-activebackground=>$abutton,-command=> sub{
    chdir ($cwd);
    win_start($software{r_dir}.'/bin/rgui.exe', '--no-init-file');
    })->grid(-row=>1,-column=>$i,-sticky=>'news');
    $help->attach($r_button, -msg => "Open the R-GUI");
    $i++; 
  }
  if (-e $software{splus}) {
    $splus_button = $frame_links -> Button(-image=>$gif{splus}, -width=>20, -height=>$links_height, -border=>$bbw, -background=>$button,-activebackground=>$abutton,-command=> sub{
    chdir ($cwd);
    win_start($setting{splus});
    })->grid(-row=>1,-column=>$i,-sticky=>'news'); 
    $i++;
    $help->attach($splus_button, -msg => "Open S-Plus");
  }
  if (-e $software{sas}) {
    $sas_button = $frame_links -> Button(-image=>$gif{sas}, -width=>20, -height=>$links_height, -border=>$bbw, -background=>$button,-activebackground=>$abutton,-command=> sub{
    chdir ($cwd);
    win_start($setting{sas});
    })->grid(-row=>1,-column=>$i,-sticky=>'news'); 
    $i++;
    $help->attach($sas_button, -msg => "Open SAS");
  }
  if (-e $software{spreadsheet}) {
    our $spreadsheet_button = $frame_links -> Button(-image=>$gif{spreadsheet},-border=>$bbw, -width=>20,-height=>$links_height, -border=>$bbw, -background=>$button,-activebackground=>$abutton,-command=> sub{
    win_start($software{spreadsheet});
    })->grid(-row=>1,-column=>$i,-sticky=>'news');
    $i++;
    $help->attach($spreadsheet_button, -msg => "Open spreadsheet application");
  }
  if (-e $software{editor}) {
    our $notepad_button = $frame_links -> Button(-image=>$gif{notepad},-border=>$bbw, -width=>20,-height=>$links_height, -border=>$bbw,-background=>$button,-activebackground=>$abutton,-command=> sub{
    win_start($software{editor});
    }) ->grid(-row=>1,-column=>$i,-sticky=>'news');
    $help->attach($notepad_button, -msg => "Open text-editor");
    $i++;
  }
  if (-e $software{census}) {
    $census_button = $frame_links -> Button(-image=>$gif{census}, -width=>20, -height=>$links_height, -border=>$bbw, -background=>$button,-activebackground=>$abutton,-command=> sub{
      win_start($software{census});
    })->grid(-row=>1,-column=>$i,-sticky=>'news'); 
    $help->attach($census_button, -msg => "Start Census");
    $i++;
  }
  if (-e $software{madonna}) {
    $madonna_button = $frame_links -> Button(-image=>$gif{madonna}, -height=>$links_height, -border=>$bbw, -background=>$button,-activebackground=>$abutton,-command=> sub{
      win_start($software{madonna});
    })->grid(-row=>1,-column=>$i,-sticky=>'news'); 
    $help->attach($madonna_button, -msg => "Start Berkeley Madonna");
    $i++;
  }
  if (-e $software{extra1}) {
    our $extra1_button = $frame_links -> Button(-image=>$gif{extra1},-border=>$bbw, -width=>20,-height=>$links_height, -border=>$bbw,-background=>$button,-activebackground=>$abutton,-command=> sub{
    win_start($software{extra1});
    }) ->grid(-row=>1,-column=>$i,-sticky=>'news');
    $help->attach($extra1_button, -msg => $software_descr{extra1});
    $i++;
  }
  if (-e $software{extra2}) {
    our $extra2_button = $frame_links -> Button(-image=>$gif{extra2},-border=>$bbw, -width=>20,-height=>$links_height, -border=>$bbw,-background=>$button,-activebackground=>$abutton,-command=> sub{
    win_start($software{extra2});
    }) ->grid(-row=>1,-column=>$i,-sticky=>'news');
    $help->attach($extra2_button, -msg => $software_descr{extra2});
    $i++;
  }
  
  our $filter = "";
  $frame_dir -> Label(-text=>"          Filter:", -font=>$font_normal, -background=>$bgcol)->grid (-row=>1,-column=>7, -sticky=>'ew');
  $filter_entry = $frame_dir -> Entry(-width=>12,-textvariable=>\$filter, -background=>'#ffffff',-border=>2, -relief=>'groove' )
    -> grid(-row=>1,-column=>8,-columnspan=>2, -sticky => 'we',-ipadx=>1);
  $filter_entry -> bind('<Any-KeyPress>' => sub {
     if (length($filter)>0) {$filter_entry -> configure(-background=>$lightyellow )} else {$filter_entry -> configure(-background=>$white)};
     read_curr_dir($cwd, $filter, 0);
  });
  $help->attach($filter_entry, -msg => "Filter model files");
  
  our $psn_dir_filter = 0;
  $frame_dir -> Label(-text=>"Folders:", -font=>$font_normal, -background=>$bgcol)->grid (-row=>2,-column=>7, -columnspan=>1, -sticky=>'e');
 
  $filter_psn_button = $frame_dir ->Checkbutton(-text=>"PsN", -background=>$bgcol, -font=>$font_normal, -variable=>\$psn_dir_filter, -activebackground=>$bgcol,-command=>sub{
     read_curr_dir($cwd, $filter, 0);
     status();
  })->grid(-row=>2,-column=>8,-sticky=>'w', -ipady=>0, -ipadx=>0);
  $help->attach($filter_psn_button, -msg => "Filter out PsN-generated directories");
  our $nmfe_dir_filter = 0;
  $filter_nmfe_button = $frame_dir ->Checkbutton(-text=>"nmfe",-background=>$bgcol, -font=>$font_normal, -variable=>\$nmfe_dir_filter, -activebackground=>$bgcol,-command=>sub{
     read_curr_dir($cwd, $filter, 0);
     status();
  })->grid(-row=>2,-column=>9,-sticky=>'w', -ipady=>0, -ipadx=>0);
  $help->attach($filter_nmfe_button, -msg => "Filter out nmfe run directories");
  
  #$frame_links -> Label(-text=>"Command: ",-font => $font_normal)
  #  ->grid(-row=>2,-column=>1,-sticky=>'nse');
  $command_entry = $frame_dir -> Entry(-textvariable=>\$run_command, -border=>2, -relief=>'groove',-font => $font_normal,-background=>'#FFFFEE')
   ->grid(-row=>1,-columnspan=>1,-column=>14,-sticky=>'we');  #i-3
  if (($gif{cluster_active}==1)&&($setting{use_cluster}==1)) {$gif_shell=$gif{shell_linux}} else {$gif_shell=$gif{shell}};
  $command_button = $frame_dir -> Button(-image=> $gif_shell,-border=>$bbw,-background=>$button,-activebackground=>$abutton, -command=> sub{
        run_command($command_entry -> get())
  })->grid(-row=>1,-columnspan=>1,-column=>15,-sticky=>'w'); # i-1
  $command_entry->bind("<Return>", sub { 
     unless(($command_entry -> get()) eq "") {
        run_command($command_entry -> get())
     }
  });
 if ($os =~ m/MSWin/i) {
   $help->attach($command_button, -msg => "Run command in a command-console (or TTY on linux-cluster)");
 } else {
   $help->attach($command_button, -msg => "Run command in a command-shell (or TTY on linux-cluster)");
 } 
#  $setting{frame2_vis}=1;
#  } else {
#    if ($tab_frame) {
##      $tab_frame->destroy(); 
 #     $frame_links->destroy();
#      $x_width = 422;
#    };
#    $setting{frame2_vis}=0;
  }
}


sub run_command {
### Purpose : Run a command, either using CMD.exe in windows, or using ssh on the cluster (when using the linux-cluster functionality and when the cluster is enabled)
### Compat  : W+L? 
  my $com = shift;
  unless (($setting{use_cluster}==1)&&($gif{cluster_active}==1)) {
    open (RUN, ">pirana_run_command.bat");
    print RUN $com."\n";
    close RUN;
    if ($stdout) {$stdout -> insert('end', "\n".$com);}
    system ("start pirana_run_command.bat");
    sleep 1;
    unlink ("pirana_run_command.bat");
  } else {  # on cluster using SSH
      @cur_dir = split('/',unix_path($cwd));
      shift(@cur_dir);
      $cur_dir_unix = join('/',@cur_dir); 
      my $command = $setting{ssh_login}.' "cd ~/'.$cur_dir_unix.'; '.$com.'"';
      system "start ".$command."&";
      #open (OUT, ">".$base_dir."/internal/run_ssh_command.bat");
      #print OUT "CALL ".$command."\n";
      #close OUT;
      #if ($stdout) {$stdout -> insert('end', "\n".$command);}
      #system 'start "'.win_path($base_dir."/internal/run_ssh_command.bat").'"';
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

sub cluster_active {
### Purpose : Activate cluster functionality
### Compat  : W+L+
  $active = shift;
  if ($active==1) {
    $enable_local_button->configure(-image=>$gif{"local_inactive"});
    $enable_cluster_button->configure(-image=>$gif{"cluster_active"});
    @nm_installations = keys(%nm_dirs);
  } else {
    $enable_local_button->configure(-image=>$gif{"local_active"});
    $enable_cluster_button->configure(-image=>$gif{"cluster_inactive"});
    @nm_installations = keys(%nm_dirs);
  }
}

sub cluster_enable {
### Purpose : Enable cluster functionality (not activate)
### Compat  : W+L+
  $enable = shift;
  #if (($enable==1)&&(-d $setting{cluster_drive})) {
  if ($enable==1) {
    $enable_cluster_button->configure (-state=>"normal");
  } else {
    $enable_cluster_button->configure (-state=>"disabled");
  }
}

sub add_run_methods {
### Purpose : Add the relevant NONMEM methods (NONMEM/PsN/WFN) to the NM-method Listbox
### Compat  : W+L+ 
  if (@run_methods) {undef @run_methods};
  our @run_methods;
  if ($setting{use_nmfe}==1) {push(@run_methods,"NONMEM")}
  if ($setting{use_psn}==1) {push(@run_methods,"PsN")}
  if ($setting{use_wfn}==1) {push(@run_methods,"WFN")}
  $method_list -> configure(-options=>[@run_methods]);
}

sub save_header_widths {
### Purpose : Save the columnwidths of the main Listbox 
### Compat  : W+L+?
  my $x=0; 
  foreach(@main_headers) {
    @header_widths[$x] = $models_hlist->columnWidth($x);
    $x++;
  }
  $new_header_widths = join (";",@header_widths);
  if ($setting{header_widths} ne $new_header_widths) {
    $setting{header_widths} = join (";",@header_widths);
    save_settings ("settings.ini", \%setting, \%setting_descr);
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
    $model_overview_frame-> Label(-text=>"Models:", -font=>$font_normal)->
    grid(-row=>2,-columnspan=>1,-column=>2, -sticky=>"w");
  }      
  @models_hlist_headers = (" #", "Ref#","Description", "Method", "OFV","dOFV","S","C","B","Sig","Notes");
  @models_hlist_widths = split (";", $setting{header_widths});

  our $models_hlist = $model_overview_frame -> Scrolled('HList',
        -head       => 1,
        -selectmode => "extended",
        -highlightthickness => 0,
        -columns    => int(@models_hlist_headers),
        -scrollbars => 'se',
        -width      => $models_hlist_width,
        -height     => $nrows,
        -border     => 2,
        -pady       => 0,
        -padx       => 0,
        -background => 'white',
        -selectbackground => $pirana_orange,
        -font       => $font_normal,
        -command    => sub {      
          @sel = $models_hlist -> selectionGet ();
          foreach (@sel) { 
            if ( @file_type_copy[$_] == 2) {
              edit_model(win_path($cwd."\\".@ctl_show[$_].".".$setting{ext_ctl}));
            } else {  # change directory
              $cwd .= @ctl_descr_copy[$_];
              chdir ($cwd);
              $cwd = fastgetcwd();
              refresh_pirana($cwd,$filter,1);
            }
          }
        },
        -browsecmd   => sub{
          my @sel = $models_hlist -> selectionGet ();
          update_psn_lst_param ();
          update_psn_zink ();
          if (($run_method eq "NONMEM")&&(@file_type_copy[@sel[0]]==2)) { update_new_dir(@ctl_show[@sel])};
          # get note from SQL
          if (@file_type_copy[@sel[0]] ==2) {
            my $mod_file = @ctl_show[@sel[0]].".".$setting{ext_ctl};
            update_text_box(\$model_info_no, @ctl_show[@sel[0]].".".$setting{ext_ctl});
            update_text_box(\$notes_text, $models_descr{@ctl_show[@sel[0]]});
            my $mod_time = gmtime(@{stat $mod_file}[9]);
            update_text_box(\$model_info_modified, $mod_time);
            update_text_box(\$model_info_dataset, $models_dataset{@ctl_show[@sel[0]]});
          } else {
            $notes_text -> configure(-state=>"disabled")
          }
          if ($estim_window) {
            show_estim_window (@ctl_show[@sel[0]].".".$setting{ext_res});
          }
        }
    )->grid(-column => 2, -columnspan=>1, -row => 1, -rowspan=>15, -sticky=>'nswe', -ipady=>0);
    
    my $models_menu = $models_hlist->Menu(-tearoff => 0,-title=>'None', -menuitems=> [
       [Button => "Model properties...",  -command => sub{
           my @sel = $models_hlist -> selectionGet ();
           my $model_id = @ctl_show[@sel[0]];
           model_properties_window($model_id, @sel[0]);
         }], 
       ]);
    $models_hlist -> bind("<Button-3>" => [ sub {
       $tab_hlist -> focus; # focus on listbox widget 
       my($w, $x, $y) = @_;
       our $modsel = $models_hlist -> selectionGet ();
       if (@$modsel >0) { $models_menu -> post($x, $y) } else {
         message("Please select a model to show options...");
       }
    }, Ev('X'), Ev('Y') ] );
 
  our $dirstyle = $models_hlist->ItemStyle( 'text', -anchor => 'w',-padx => 5, -background=>'#ffffe0', -font => $font_normal);
  our $align_right = $models_hlist->ItemStyle( 'text', -anchor => 'e',-padx => 5, -background=>'white', -font => $font_normal);
  our $align_left = $models_hlist-> ItemStyle( 'text', -anchor => 'w',-padx => 5, -background=>'white', -font => $font_normal);
  our $header_left = $models_hlist->ItemStyle('text',-background=>'gray', -anchor => 'w', -pady => 0, -padx => 2, -font => $font_normal );
  our $header_right = $models_hlist->ItemStyle('text',-background=>'gray', -anchor => 'e', -pady => 0, -padx => 2, -font => $font_normal );
  our $green_ofv = $models_hlist->ItemStyle( 'text', -anchor => 'e',-padx => 5, -foreground=>'#008800', -background=>'white',-font => $font_fixed); 
  our $red_ofv = $models_hlist->ItemStyle( 'text', -anchor => 'e',-padx => 5, -foreground=>'#990000', -background=>'white',-font => $font_fixed); 
  our $yellow_ofv = $models_hlist->ItemStyle( 'text', -anchor => 'e',-padx => 5, -foreground=>'#888800', -background=>'white',-font => $font_fixed); 
  our $black_ofv = $models_hlist->ItemStyle( 'text', -anchor => 'e',-padx => 5, -foreground=>'#000000', -background=>'white',-font => $font_fixed); 
  our $bold_left = $models_hlist->ItemStyle( 'text', -anchor => 'w',-padx => 5, -foreground=>'#000000', -background=>'white',-font => $font_fixed);
  our $bold_right = $models_hlist->ItemStyle( 'text', -anchor => 'e',-padx => 5, -foreground=>'#000000', -background=>'white',-font => $font_fixed);
  our $estim_style = $models_hlist-> ItemStyle( 'text', -anchor => 'e', -background=>'#d0d0ff', -font => $font_normal);
  our $estim_style_light = $models_hlist-> ItemStyle( 'text', -anchor => 'e', -background=>'#e5e5ff', -font => $font_normal);  
  our $estim_style_se = $models_hlist-> ItemStyle( 'text', -anchor => 'e', -background=>'#ffffe5', -font => $font_normal);  

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
          -border=> 0, -pady => $header_pad, 
          -command => sub {; }, -resizerwidth => 2,
          -column => $x
        );
        $models_hlist->header('create', $x, 
          -itemtype => 'window', -style => $headerstyle,
          -widget => @main_headers[$x]
        );
        $models_hlist -> columnWidth($x, @models_hlist_widths[$x]);
  }
  $model_overview_frame -> bind('<Leave>' => sub {save_header_widths();}); 
  $models_hlist -> update();
  
  $mod_buttons = $model_overview_frame -> Frame(-background=>$bgcol) ->grid(-row=>1,-column=>1,-rowspan=>8,-ipadx=>'0', -ipady=>'0',-sticky=>'wne');
  $mod_buttons -> Label(-text=>"Models:", -background=>$bgcol,-width=>6, -font=>$font_normal)->grid(-row=>1,-column=>1,-sticky=>'ews',-ipadx=>0, -columnspan=>2, -ipady=>2);

  our $new_button = $mod_buttons->Button(-image=>$gif{newfolder}, -width=>46,  -height=>22, -border=>$bbw,-background=>$button,-activebackground=>$abutton,-command=> sub{
    new_dir();})
    ->grid(-row=>3,-column=>1,-sticky=>'news');
  $help->attach($new_button, -msg => "New folder");
  our $new_button = $mod_buttons->Button(-image=>$gif{new}, -width=>46,  -height=>22, -border=>$bbw,-background=>$button,-activebackground=>$abutton,-command=> sub{
    new_ctl();})
    ->grid(-row=>4,-column=>1,-sticky=>'news');
  $help->attach($new_button, -msg => "New model");
  our $edit_button = $mod_buttons->Button(-image=>$gif{notepad}, -width=>46,  -height=>22,-border=>$bbw,-background=>$button,-activebackground=>$abutton, -command=> sub{
      @sel = $models_hlist -> selectionGet ();
      if (@sel > 0) {
        foreach (@sel) { 
        if ( @file_type_copy[$_] == 2) {
          edit_model(win_path($cwd."\\".@ctl_show[$_].".".$setting{ext_ctl}));
        }
      }
    }})->grid(-row=>5,-column=>1,-sticky=>'news');
  $help->attach($edit_button, -msg => "Edit model");
  our $duplicate_button = $mod_buttons->Button(-image=>$gif{duplicate}, -width=>46,  -height=>22, -border=>$bbw, -background=>$button,-activebackground=>$abutton, -command=> sub{
      @sel = $models_hlist -> selectionGet ();
      if (@sel > 0) {
         if ( @file_type_copy[@sel[0]]==2) {
           duplicate_model_window();
         }
       }
     })->grid(-row=>6,-column=>1,-sticky=>'news');
  $help->attach($duplicate_button, -msg => "Duplicate model");
  
  our $msf_button = $mod_buttons->Button(-image=>$gif{msf}, -width=>46,  -height=>22, -border=>$bbw, -background=>$button,-activebackground=>$abutton, -command=> sub{
      @sel = $models_hlist -> selectionGet ();
      if (@sel > 0) {
         if ( @file_type_copy[@sel[0]]==2) {
           restart_msf(@ctl_show[@sel[0]]);
         }
       }
     })->grid(-row=>7,-column=>1,-sticky=>'news');
  $help->attach($msf_button, -msg => "Duplicate model for restart using MSF file");

  our $rename_button = $mod_buttons->Button(-image=>$gif{rename},-width=>46,  -height=>22, -border=>$bbw,-background=>$button,-activebackground=>$abutton, -command=> sub{
      @sel = $models_hlist -> selectionGet ();
      if (@sel > 0) {
        rename_ctl(@ctl_show[@sel[0]] ); 
      }
  })->grid(-row=>8,-column=>1,-sticky=>'news');
  $help->attach($rename_button, -msg => "Rename model");
  
  our $delete_button = $mod_buttons->Button(-image=>$gif{delete},-width=>46,  -height=>22, -border=>$bbw,-background=>$button,-activebackground=>$lightred,-command=> sub{
    @sel = $models_hlist -> selectionGet ();
    if (@sel > 0) {
      delete_ctl();
    }
  })->grid(-row=>9,-column=>1,-sticky=>'news');
  $help->attach($delete_button, -msg => "Delete model/folder(s)");
  
  if ($models_view eq "tree") {$listimage = $gif{treeview}} else {$listimage = $gif{listview}};
  our $sort_button = $mod_buttons->Button(-image=>$listimage, -width=>46, -height=>22, -border=>$bbw,-background=>$button,-activebackground=>$abutton,-command=> sub{
    if ($models_view eq "tree") {
       $models_view = "list";
       $listimage = $gif{listview};
    } else {
       $models_view = "tree";
       $listimage = $gif{treeview};
    }
    $sort_button -> configure (-image=>$listimage);
    populate_models_hlist($models_view);
  })->grid(-row=>2,-column=>1,-sticky=>'news');
  $help->attach($sort_button, -msg => "Show models as list or as tree structure, based on their reference model");

  ($nm_dirs_ref,$nm_vers_ref) = read_ini("ini/nm_inst_local.ini");
  %nm_dirs = %$nm_dirs_ref; %nm_vers = %$nm_vers_ref;
  if (-e $base_dir."/log/pirana.log") {  # read last used NM installation
          read_log();
  }
  $run_frame = $mw -> Frame(-width=>600, -background=>$bgcol)->grid(-row=>3,-column=>1,-sticky => 'wns');
  $enable_local_button   = $run_frame -> Button (-image=>$gif{local_active}, -border=>$bbw, -width=>56, -height=>24, , -background=>$bgcol,-activebackground=>$abutton,-command=>sub{
     $gif{cluster_active} = 0;
     $gif_shell=$gif{shell};
     $command_button -> configure(-image=>$gif_shell);
     cluster_active($gif{cluster_active});
     add_run_methods();      
     show_run_method($run_method);
  })->grid(-row=>1,-column=>0,-sticky => 'wens');
  $help -> attach($enable_local_button, -msg => "Run NONMEM locally");
  $enable_cluster_button = $run_frame -> Button (-image=>$gif{cluster_inactive}, -border=>$bbw, -width=>56, -height=>24, -background=>$bgcol, -activebackground=>$abutton, -command=>sub{
     if (($gif{cluster_active} == 1)&&($setting{cluster_monitor})) {cluster_monitor()} ;
     $gif{cluster_active} = 1;
     if (($gif{cluster_active}==1)&&($setting{use_cluster}==1)) {$gif_shell=$gif{shell_linux}} else {$gif_shell=$gif{shell}};
     $command_button -> configure(-image=>$gif_shell);
     cluster_active($gif{cluster_active});
     update_psn_zink ();
     add_run_methods(); 
     show_run_method($run_method);
  })->grid(-row=>2,-column=>0,-sticky => 'we');
  $gif{cluster_active} = $setting{cluster_default};
  cluster_active($gif{cluster_active});
  $help -> attach($enable_cluster_button, -msg => "Run NONMEM on a cluster");
  
  our $run_in_nm_dir = "nmfe_";
  # spacer
 # $run_frame -> Label(-text=>" ", -font=>'Verdana 1', -width=>10) -> grid(-sticky=>'we',-row=>3,-column=>1,-ipady=>0);
 our $run_color=$lightblue; our $arun_color=$darkblue;  
 our $method_list = $run_frame -> Optionmenu (
   -background=>"#c0c0c0", -activebackground=>"#a0a0a0", -width=>13, -border=>$bbw,
   -font=>$font_normal, -textvariable=> \$run_method, -command=>sub{
      undef $nm_versions_menu;
      show_run_method ($run_method);
  })-> grid(-row=>1,-column=>1,-sticky=>'news');
  add_run_methods();

  if ($setting{default_method} =~ m/nmq/gi) {$run_method = "NONMEM"};
  if ($setting{default_method} =~ m/psn/gi) {$run_method = "PsN"; $nm_version_chosen = "default"};
  if ($setting{default_method} =~ m/wfn/gi) {$run_method = "WFN"};
  if ($setting{default_method} =~ m/nmfe/gi) {$run_method = "NONMEM"};

  show_run_method ($run_method);     
  if ($os =~ m/MSWin/i) {$model_overview_frame -> Label(-text=>" ",-font=>"Arial 1", -background=>$bgcol)->grid(-ipady=>2,-sticky=>'news',-row=>18,-column=>1);}  #spacer
  }
  
  # Notes
  my $spacer = 5;
  if ($os =~ m/MSWin/i) {$spacer = 14; };
  $run_frame -> Label(-text=>"", -width=>$spacer, -font=>"Courier 1", -background=>$bgcol)->grid(-column=>6, -row=>1);  #spacer
  if ($setting{font_size} == 2) {$note_width=40} else {$note_width = 29};
  
  $run_info_frame = $run_frame -> Frame(-background=>$bgcol)->grid(-row=>1, -column=>7, -rowspan=>2, -sticky=>"ne");
  $run_info_frame -> Label(-text=>"Model file:", -font=>$font_normal, -background=>$bgcol)-> grid(-row=>1, -column=>1, -sticky=>"nw");
  $run_info_frame -> Label(-text=>"Description:", -font=>$font_normal, -background=>$bgcol)-> grid(-row=>2, -column=>1, -sticky=>"nw");
  $run_info_frame -> Label(-text=>"Last modified:", -font=>$font_normal, -background=>$bgcol)-> grid(-row=>3, -column=>1, -sticky=>"nw");
  $run_info_frame -> Label(-text=>"Dataset:", -font=>$font_normal, -background=>$bgcol)-> grid(-row=>4, -column=>1, -sticky=>"nw");
  our $notes_text = $run_info_frame -> Text (
      -width=>28, -relief=>'sunken', -border=>0, -height=>1, 
      -font=>$font_small, -background=>"#f6f6e6", -state=>'disabled'
  )->grid(-column=>2, -row=>2,-sticky=>'nw', -ipadx=>0);
  our $model_info_no = $run_info_frame -> Text (
      -width=>28, -relief=>'sunken', -border=>0, -height=>1, 
      -font=>$font_small, -background=>"#f6f6e6", -state=>'disabled'
  )->grid(-column=>2, -row=>1,-sticky=>'nw', -ipadx=>0);
  our $model_info_dataset = $run_info_frame -> Text (
      -width=>28, -relief=>'sunken', -border=>0, -height=>1, 
      -font=>$font_small, -background=>"#f6f6e6", -state=>'disabled'
  )->grid(-column=>2, -row=>4, -sticky=>'nw', -ipadx=>0);
  our $model_info_modified = $run_info_frame -> Text (
      -width=>28, -relief=>'sunken', -border=>0, -height=>1, 
      -font=>$font_small, -background=>"#f6f6e6", -state=>'disabled'
  )->grid(-column=>2, -row=>3, -sticky=>'nw', -ipadx=>0);
  our $model_properties_button = $run_frame -> Button(-image=>$gif{edit_info}, -border=>$bbw, -background=>$bgcol, -activebackground=>$abutton, -command=> sub{
    my @sel = $models_hlist -> selectionGet ();
    my $model_id = @ctl_show[@sel[0]];
    model_properties_window($model_id, @sel[0]);
  }) -> grid(-column=>9, -row=>1,-rowspan=>1,-sticky=>'n');
  $help->attach($model_properties_button, -msg => "Edit model properties");

if($os =~ m/MSWin/i) {
  $colors_frame = $run_frame -> Frame (-background=>$bgcol)->grid(-column=>9, -row=>2,-rowspan=>2,-sticky=>'ws', -ipady=>0);
  $colors_frame -> Button (-text=>'', -width=>1, -background=>$darkred, -activebackground=>$lightred, -font=>'Arial 5', -command=> sub {
    status("Saving color information...");
    note_color ($lightred);
    status();
  })->grid(-column=>1, -row=>1,-rowspan=>1,-sticky=>'nw');
  $colors_frame -> Button (-text=>'', -width=>1, -background=>$lightblue, -activebackground=>$lighterblue, -font=>'Arial 5', -command=> sub {
    status("Saving color information...");
    note_color ($lighterblue);
    status();
  })->grid(-column=>2, -row=>1,-rowspan=>1,-sticky=>'nw');
  $colors_frame -> Button (-text=>'', -width=>1, -background=>$darkgreen, -activebackground=>$lightgreen, -font=>'Arial 5', -command=> sub {
    status("Saving color information...");
    note_color ($lightgreen);
    status();
  })->grid(-column=>1, -row=>2,-rowspan=>1,-sticky=>'nw');
  $colors_frame -> Button (-text=>'', -width=>1, -background=>'white', -activebackground=>'white', -font=>'Arial 5', -command=> sub {
    status("Saving color information...");
    note_color ("#ffffff");
    status();
  })->grid(-column=>2, -row=>3,-rowspan=>1,-sticky=>'nw');
    $colors_frame -> Button (-text=>'', -width=>1, -background=>$abutton, -activebackground=>$button, -font=>'Arial 5', -command=> sub {
    status("Saving color information...");
    note_color ($button);
    status();
  })->grid(-column=>1, -row=>3,-rowspan=>1,-sticky=>'nw');
  $colors_frame -> Button (-text=>'', -width=>1, -background=>$darkyellow, -activebackground=>$lightyellow, -font=>'Arial 5', -command=> sub {
    status("Saving color information...");
    note_color ($lightyellow);
    status();
  })->grid(-column=>2, -row=>2,-rowspan=>1,-sticky=>'nw');
  }
}

sub table_info_window {
### Purpose : Open a dialog window in which table/file info (size / notes) are shown and can be edited 
### Compat  : W+L+?
  my $file = shift; my $mod; my $file_descr=$table_descr{$file};
  my $file_notes = $table_note{$file}; my $creator=$table_creator{$file};
  my $table_info_window = $mw -> Toplevel(-title=>'File properties');
  $table_info_window -> resizable( 0, 0 );
  $table_info_window -> Popup;
  my $table_info_frame = $table_info_window -> Frame(-relief=>'groove', -border=>0, -padx=>7, -pady=>7)->grid(-ipadx=>'10',-ipady=>'10',-sticky=>'n');
  $table_info_frame -> Label (-text=>"Filename:\n") -> grid(-row=>2, -column=>1,-sticky=>"en");
  $table_info_frame -> Entry (-text=>unix_path($cwd."/".$file),-font=>$font_normal, -relief=>'sunken', -background=>$button, -border=>0, -width=>60, -state=>'disabled') -> grid(-row=>2, -column=>2,-sticky=>"wn");
  $table_info_frame -> Label (-text=>"Last modified:\n") -> grid(-row=>3, -column=>1, -sticky=>"en");
  if (-e $file) {$mod_time = gmtime(@{stat $file}[9])};
  $table_info_frame -> Entry (-text=> $mod_time, -font=>$font_normal, -width=>24, -state=>'disabled',-relief=>'sunken', -border=>0, -background=>$button) -> grid(-row=>3, -column=>2,-sticky=>"wn");
  $table_info_frame -> Label (-text=>"Creator:\n") -> grid(-row=>4, -column=>1, -sticky=>"en");
  $table_info_frame -> Entry (-textvariable=> \$creator, -font=>$font_normal, -width=>45, -state=>'normal',-relief=>'sunken', -border=>0, -background=>'white') -> grid(-row=>4, -column=>2,-sticky=>"wn");

  $table_info_frame -> Label (-text=>"Description:\n") -> grid(-row=>5, -column=>1, -sticky=>"en");
  $table_info_frame -> Entry (-textvariable=> \$file_descr, -font=>$font_normal, -width=>45, -state=>'normal',-relief=>'sunken', -border=>0, -background=>'white') -> grid(-row=>5, -column=>2,-sticky=>"wn");
  
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
  $model_prop_window -> Popup;
  
  my $model_prop_frame = $model_prop_window -> Frame(-relief=>'groove', -border=>0, -padx=>7, -pady=>7)->grid(-ipadx=>'10',-ipady=>'10',-sticky=>'n');
  $model_prop_frame -> Label (-text=>"Model no:\n") -> grid(-row=>1, -column=>1,-sticky=>"en");
  $model_prop_frame -> Entry (-text=>$model_id, -font=>$font_normal, -width=>15, -state=>'disabled', -disabledforeground=>'#727272',-relief=>'sunken', -border=>0, -background=>$button) -> grid(-row=>1, -column=>2,-sticky=>"wn");
  $model_prop_frame -> Label (-text=>"Filename:\n") -> grid(-row=>2, -column=>1,-sticky=>"en");
  $model_prop_frame -> Entry (-text=>unix_path($cwd."/".$model_id.".".$setting{ext_ctl}),-font=>$font_normal, -disabledforeground=>'#727272', -relief=>'sunken', -background=>$button, -border=>0, -width=>50, -state=>'disabled') -> grid(-row=>2, -column=>2,-sticky=>"wn");
  $model_prop_frame -> Label (-text=>"Last modified:\n") -> grid(-row=>3, -column=>1, -sticky=>"en");
  my $mod = gmtime($models_dates_db{$model_id});
  $model_prop_frame -> Entry (-text=> $mod, -font=>$font_normal, -width=>24, -state=>'disabled',-disabledforeground=>'#727272',-relief=>'sunken', -border=>0, -background=>$button) -> grid(-row=>3, -column=>2,-sticky=>"wn");
  $model_prop_frame -> Label (-text=>"Dataset:\n") -> grid(-row=>4, -column=>1, -sticky=>"en");
  $model_prop_frame -> Entry (-text=> $models_dataset{$model_id}, -font=>$font_normal, -width=>24, -state=>'disabled',-disabledforeground=>'#727272',-relief=>'sunken', -border=>0, -background=>$button) -> grid(-row=>4, -column=>2,-sticky=>"wn");
  $model_prop_frame -> Label (-text=>"Description:\n") -> grid(-row=>5, -column=>1, -sticky=>"en");
  $model_prop_frame -> Entry (-text=> $descr_new, -font=>$font_normal, -width=>45, -state=>'disabled', -disabledforeground=>'#727272', -relief=>'sunken', -border=>0, -background=>'white') -> grid(-row=>5, -column=>2,-sticky=>"wn");
  $model_prop_frame -> Label (-text=>"Reference model:\n") -> grid(-row=>6, -column=>1, -sticky=>"en");
  $model_prop_frame -> Entry (-text=> $ref_mod, -font=>$font_normal, -width=>10, -state=>'disabled',-disabledforeground=>'#727272',-relief=>'sunken', -border=>0, -background=>'white') -> grid(-row=>6, -column=>2,-sticky=>"wn");
  $model_prop_frame -> Label (-text=>"Notes:\n") -> grid(-row=>8, -column=>1, -sticky=>"en");
  $model_prop_notes = $model_prop_frame -> Text (-width=>45, -font=>$font_normal, -height=>10, -state=>'normal',-relief=>'sunken', -border=>0, -background=>'white') -> grid(-row=>8, -column=>2,-sticky=>"wn");
  $model_prop_frame -> Label (-text=>" ") -> grid(-row=>9, -column=>3, -sticky=>"en");
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
      $note_strip =~ s/\n/\ /g;
      $models_hlist -> itemConfigure($idx, 10, -text => $note_strip);
      $models_hlist -> update();
      $model_prop_window -> destroy();
      return();
    }) -> grid(-row=>10, -column=>2, -sticky=>"wn");
    $model_prop_frame -> Button (-text=>"Cancel", -width=>15, -background=>$button, -border=>$bbw, -activebackground=>$abutton, -command=> sub {
    $table_info_window -> destroy();
    return();
  }) -> grid(-row=>10, -column=>1, -sticky=>"en");
}

sub update_text_box {
### Purpose : Update the specified text-box with text (used for updating information boxes about model / table-file info) 
### Compat  : W+L+
  my($obj_ref, $text) = @_;
  $obj = $$obj_ref;
  $obj -> configure(-state=>"normal");
  $obj -> delete("0.0","end");
  $obj -> insert ("0.0", $text);
  $obj -> configure(-state=>"disabled");
}

sub note_color {
### Purpose : Give the selected model/result a color
### Compat  : W+L+
  my $color = shift;
  my $style_color = $models_hlist->ItemStyle( 'text', -padx => 5, -background=>$color, -font=>$font_normal);
  my $style_color_small = $models_hlist->ItemStyle( 'text', -padx => 5, -background=>$color, -font=>"Verdana 8");
  
  my @sel = $models_hlist -> selectionGet ();
  foreach my $no (@sel) {
    if ($file_type{@ctl_show[$no]} == 2) {
      $models_colors {$no} = $color;
      # determine style colors
      $runno = @ctl_show[$no]; 
      $mod_background = $color;
      $style = $models_hlist-> ItemStyle( 'text', -anchor => 'w',-padx => 5, -background=>$mod_background, -font => $font_normal);;
      our $style_green = $models_hlist->ItemStyle( 'text', -padx => 5, -background=>$mod_background, -foreground=>'#008800',-font => "Courier 9 bold");
      our $style_red = $models_hlist->ItemStyle( 'text', -padx => 5, -background=>$mod_background, -foreground=>'#990000', -font => "Courier 9 bold");
      if (($res_ofv{$runno} ne "")&&($res_ofv{$models_refmod{$runno}} ne "")) {
        my $ofv_diff = $res_ofv{$models_refmod{$runno}} - $res_ofv{$runno} ;
        if ($ofv_diff >= $setting{ofv_sign}) { $style_ofv = $style_green; }
        if ($ofv_diff < 0) { $style_ofv = $style_red; }
        if (($ofv_diff >= 0)&&($ofv_diff < $setting{ofv_sign})) { 
          $style_ofv = $models_hlist->ItemStyle( 'text', -anchor => 'e',-padx => 5, -foreground=>'#A0A000', -background=>$mod_background,-font => "Courier 8 bold"); 
        }
      } else {$style_ofv = $models_hlist->ItemStyle( 'text', -anchor => 'e',-padx => 5, -foreground=>'#000000', -background=>$mod_background,-font => "Courier 8 bold");}
      if ($res_success{$runno} eq "S") {$style_success = $style_green} else {$style_success = $style_red};
      if ($res_cov{$runno} eq "C") {$style_cov = $style_green} else {$style_cov = $style_red};
      $models_hlist -> itemConfigure($no, 0, -style => $style_color);
      $models_hlist -> itemConfigure($no, 1, -style => $style_color_small);
      $models_hlist -> itemConfigure($no, 2, -style => $style_color);
      $models_hlist -> itemConfigure($no, 3, -style => $style_color_small);          
      $models_hlist -> itemConfigure($no, 4, -style => $style_ofv);
      $models_hlist -> itemConfigure($no, 5, -style => $style_ofv);
      $models_hlist -> itemConfigure($no, 6, -style => $style_success);
      $models_hlist -> itemConfigure($no, 7, -style => $style_cov);
      $models_hlist -> itemConfigure($no, 8, -style => $style_red);
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
          if ($gif{cluster_active} == 1) {
            $count += generate_zink_file($setting{zink_host}, $setting{cluster_drive}, "Bootstrap ".$file, 3, win_path($cwd), win_path($cwd."\\".$rand_filename."_".$_).".bat\n", "");
          } else {
            open (BAT,">".$rand_filename.".bat");
            print BAT "start /low /b ".$rand_filename."_".$_.".bat\n";
            close BAT;
          }
        }
        message ("WFN bootstrap scheduled, ".$count." job specification file(s) created.");
        db_log_execution ($file, @ctl_descr[$file], "WFN", "Local", win_path($wfn_dir."/bin/".$wfn_option.".bat ".$file." ".$wfn_run_parameters), $setting{name_researcher} );
      } else {
        open (BAT,">".$rand_filename.".bat");
        print BAT "CALL ".win_path($wfn_dir."/bin/wfn.bat ").$wfn_parameters."\n";
        print BAT "CALL ".win_path($wfn_dir."/bin/".$wfn_option.".bat ".$file." ".$wfn_run_parameters)."\n";
        close BAT;
        db_log_execution ($file, @ctl_descr[$file], "WFN", "Local", win_path($wfn_dir."/bin/".$wfn_option.".bat ".$file." ".$wfn_run_parameters), $setting{name_researcher} );    
        if ($gif{cluster_active} == 1) {
          if (generate_zink_file($setting{zink_host}, $setting{cluster_drive},"Bootstrap ".$file, 3, win_path($cwd), "CALL ".win_path($cwd."\\".$rand_filename).".bat\n", "") == 1) {
            message ("WFN job scheduled.");
            db_log_execution ($file, @ctl_descr[$file], "WFN", "PCluster", win_path($wfn_dir."/bin/".$wfn_option.".bat ".$file." ".$wfn_run_parameters), $setting{name_researcher} );
          };
        } 
      }
  status ();
  unless ($gif{cluster_active} == 1) {
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
        if ($gif{cluster_active}==0) {
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
   if ($nm_dir_entry) {$nm_dir_entry -> update()};
}

sub show_run_method {
### Purpose : Show the buttons for running/executing runs. For nmfe-, PsN- or WFN-method specific buttons are created in "method_specific_options" 
### Compat  : W+L+ 
  if ($run_frame) {  
  unless ($nm_versions_menu) { # if not already exists, build optionmenu
    unless ($run_method eq "WFN") {
      if ($max_psn_name<13) {$max_psn_name=13};
      our $nm_versions_menu = $run_frame -> Optionmenu(-options=>[],-variable => \$nm_version_chosen, 
        -border=>$bbw, -width=>$max_psn_name,      
        -background=>$run_color,-activebackground=>$arun_color,
        -font=>$font_normal, -background=>"#c0c0c0", 
        -activebackground=>"#a0a0a0", -command=> sub{ 
          if (-e unix_path($nm_dirs{$nm_version_chosen}."/test/runtest.pl")) {
            $run_method_nm_type="NMQual";
          } else {$run_method_nm_type="nmfe"}
          method_specific_options();
        })-> grid(-row=>2,-column=>1,-columnspan=>2,-sticky => 'wns');
      $help->attach($nm_versions_menu, -msg => "Choose NM installation to use");
    }
  }
  $run_color=$lightblue; $arun_color=$darkblue;  
  if ($run_method eq "NONMEM") { 
    delete $nm_dirs{""};
    @nm_installations = keys(%nm_dirs);
    foreach (@nm_installations) {
      $_ = substr($_,0,13); 
    };
    if ($nm_versions_menu) { $nm_versions_menu -> configure (-options => [@nm_installations] )} ;
  } 
  method_specific_options();
  }
}

sub method_specific_options {
### Purpose : Show the buttons for "NONMEM", "PsN" or "WFN" run methods 
### Compat  : W+L+
  if ($run_method eq "") {$run_method = "PsN";};
  if ($local_nm) {$local_nm-> gridForget()};
  if ($method_options) {$method_options-> gridForget()};
  if ($psn_methods) {$psn_methods-> gridForget()};
  if ($psn_command_entry) {$psn_command_entry-> gridForget()};
  if ($psn_method_options) {$psn_method_options-> gridForget()};
  if ($run_psn_button) {$run_psn_button-> gridForget()};
  if ($nmq_command_entry) {$psn_command_entry-> gridForget()};
  if ($run_nmq_button) {$run_nmq_button-> gridForget()};
  if ($nmq_method_options) {$nmq_method_options -> gridForget()};
  if ($nmq_run_local_button) {$nmq_run_local_button -> gridForget()};
  if ($nmq_params_entry) {$nmq_params_entry -> gridForget()}; 
  if ($wfn_command_entry) {$wfn_command_entry-> gridForget()};
  if ($run_wfn_button) {$run_wfn_button-> gridForget()};
  if ($wfn_methods) {$wfn_methods -> gridForget();}
  if ($wfn_method_options) {$wfn_method_options-> gridForget()};
  if ($wfn_param_entry) {$wfn_param_entry -> gridForget()}; 
  if ($threads_options) {$threads_options -> gridForget();}; 
  if ($psn_help_button) {$psn_help_button -> gridForget();};
  if ($nm_dir_checkbutton) {$nm_dir_checkbutton -> gridForget();};
  if ($nm_dir_entry) {$nm_dir_entry -> gridForget();};

if (($run_method eq "NONMEM")&&($run_method_nm_type ne "NMQual")) {
#   if ($nm_version_chosen eq "") {$nm_version_chosen = @nm_installations[0]};
   if (($gif{cluster_active}==1)&&($setting{use_cluster}==2)) {our @methods = ("Distribute", "Specify client")} else {our @methods = ("Run", "Test syntax (NM-TRAN)")};
   our $method_options = $run_frame -> Optionmenu(-options => [@methods],-variable => \$method_chosen, -background=>$run_color,-activebackground=>$arun_color,
          -font=>$font_normal, -border=>$bbw, -height=>1, -width=>32
   )-> grid(-row=>1,-column=>2, -columnspan=>3,-sticky => 'wens', -ipady=>2);
   
   our $nm_dir_entry = $run_frame -> Entry (-textvariable=>\$run_in_nm_dir, -width=>16, -relief=>'sunken', -border=>1, -state=>'disabled'
   ) -> grid(-column=>3,-row=>2, -columnspan=>2, -sticky=>'nwes');
   our $nm_dir_checkbutton = $run_frame -> Checkbutton(-text=>"in new dir: ", -background=>$bgcol, -variable=>\$nm_dir_check, -command=>sub{
     if ($nm_dir_check==0) {$nm_dir_entry -> configure(-state=>'disabled')} else {
       update_new_dir();
       $nm_dir_entry -> configure(-state=>'normal')
     }
   })->grid(-column=>2,-row=>2, -sticky=>"e"); 
   our $run_local_button = $run_frame->Button(-image=>$gif{run}, -border=>$bbw,-width=>45, -background=>$button, -activebackground=>$abutton,-command=> sub{
      unless ($nm_version_chosen eq "") { #NM installed?
        if ($gif{cluster_active}==1)  {
          if ($setting{use_cluster}==2) { # run on PCluster
            distribute ($nm_version_chosen, $method_chosen, "nmfe");
          }
          if ($setting{use_cluster}==1) { # run on regular cluster
            $cwd = $dir_entry -> get();
            if ($cwd =~ m/$setting{cluster_drive}/i) {
              exec_run_nmfe ($nm_version_chosen, $method_chosen);
              chdir($cwd);
            } else {
              message ("Your current working directory is not located on the cluster.\nChange to your cluster-drive or change your preferences.");
            }
          }
        } else {
          exec_run_nmfe ($nm_version_chosen, $method_chosen);
        }
      } else {message("Please add NONMEM installation to Pira�a");
      }
      })->grid(-row=>1,-column=>5,-columnspan=>1, -rowspan=>2,-sticky=>'wens');
    $help->attach($run_local_button, -msg => "Run model(s)");
  }

  if ($run_method_nm_type eq "NMQual") {
    $nmq_params_entry = $run_frame -> Entry(-textvariable=>\$setting{nmq_parameters}, -border=>1, 
      -width=>16,-relief=>'groove', -font=>$font_normal,-background=>"#FFFFFF")
       ->grid(-sticky=>'wens',-row=>2,-column=>4,-columnspan=>1);
    our $nmq_method_options = $run_frame -> Optionmenu(-options => [@nm_installations], -variable => \$nmq_version_chosen, -background=>$run_color,-activebackground=>$arun_color,
          -font=>$font_normal, -border=>$bbw, -width=>32 
      )-> grid(-row=>1,-column=>3,-columnspan=>3,-sticky => 'wens'); 
    if ($gif{cluster_active}==1) {our @methods = ("Distribute", "1 client")} else {our @methods = ("NMQual: run here", "NMQual: in new dir")};
    if ($gif{cluster_active}==1) {
      our $method_options = $run_frame -> Optionmenu(-options => [sort(@methods)],-variable => \$method_chosen, -background=>$run_color,-activebackground=>$arun_color,
        -font=>$font_normal, -border=>$bbw, -height=>1, -width=>32
      )-> grid(-row=>1,-column=>2,-columnspan=>3,-sticky => 'ewns', -ipady=>2); 
    } else {
      our $method_options = $run_frame -> Optionmenu(-options => [@methods],-variable => \$method_chosen, 
          -background=>$run_color,-activebackground=>$arun_color,
          -font=>$font_normal, -border=>$bbw,-width=>32
      )-> grid(-row=>1,-column=>2,-columnspan=>3,-sticky => 'ewns',-ipady=>2);
    }
    $run_frame -> Label(-text=>"NMQual parameters:", -justify=>"right")->grid(-row=>2, -column=>3, -ipady=>6,-sticky=>'nwe');
    our $nmq_run_local_button = $run_frame->Button(-image=>$gif{run}, -border=>$bbw,-width=>45, -background=>$button, -activebackground=>$abutton,-command=> sub{
        @runs = $models_hlist -> selectionGet ();
        @files = @ctl_show[@runs];
        chdir($cwd);
        $nmq_params = $nmq_params_entry -> get();
        if ($gif{cluster_active}==1){
            distribute ($nm_version_chosen, $method_chosen, "NMQual");
        } else {
            print "Run";
            if($method_chosen =~ m/run here/i) {
              my $rand_filename = exec_run_nmq ($nm_dirs{$nm_version_chosen}, \@files, $nmq_params);
              my $nmq_command = "start /low ".$rand_filename;
              if($stdout) {$stdout -> insert('end', "\n".$nmq_command);}
              system $nmq_command;   # start execution
            } else {
              foreach $file(@files) {
                my $new_dir = move_nm_files ($file, $run_in_nm_dir);
                if (-d $new_dir) {
                  $old_dir = fastgetcwd;
                  chdir ($new_dir);
                  my $rand_filename = exec_run_nmq ($nm_dirs{$nm_version_chosen}, $file, $nmq_params);
                  my $nmq_command = "start /low ".$rand_filename; 
                  if($stdout) {$stdout -> insert('end', "\n".$nmq_command);}
                  system $nmq_command;    # start execution
                  chdir ($old_dir);
                }
              }
           } 
        }   
      })->grid(-row=>1,-column=>5, -columnspan=>1, -rowspan=>2,-sticky=>'wens');
    $help->attach($nmq_run_local_button, -msg => "Run model(s)");
  }
  if (($run_method eq "PsN")&&($setting{use_psn}==1)) {
    my $psn_nm_versions_ref = get_psn_nm_versions();
    %psn_nm_versions = %$psn_nm_versions_ref; 
    #print $psn_nm_versions_ref;
    chdir($cwd); 
    if ($psn_option eq "") {$psn_option="execute";}
    $psn_parameters = $psn_commands{$psn_option};
    update_psn_lst_param();
    update_psn_zink ();  
   $psn_command_entry = $run_frame -> Entry(-textvariable=>\$psn_parameters, 
      -width=>(36),-border=>2, -relief=>'groove',-font=>$font_small,-background=>"#FFFFFF")
   ->grid(-sticky=>'wens',-row=>2,-column=>2,-columnspan=>3,-ipady=>4);
    
    my $psn_text = get_psn_info($psn_option);
    $help->attach($psn_command_entry, -msg => $psn_text);
    
    if ($nm_versions_menu) { $nm_versions_menu -> configure (-options => [sort(keys(%psn_nm_versions))] )}
    our $psn_methods = $run_frame -> Optionmenu(-options => [sort(keys(%psn_commands))],-variable => \$psn_option, -border=>$bbw, -background=>$run_color,-activebackground=>$arun_color,
          -font=>$font_normal, -width=>28,-command=> sub{
            $psn_text = get_psn_info($psn_option);
            $help->attach($psn_command_entry, -msg => $psn_text);
            $psn_command_entry->configure(-textvariable=>$psn_commands{$psn_option});
          })-> grid(-row=>1,-column=>2,-columnspan=>2,-sticky => 'wns',-ipady=>2);
    our $psn_help_button = $run_frame -> Button(-image=>$gif{help}, -width=>26,-border=>$bbw, -background=>$button, -activebackground=>$abutton, -command=>sub{
      $psn_help_command = get_psn_help ($psn_option, $software{perl_dir});
      text_window($psn_help_command, "PsN Help files");
    }) -> grid(-row=>1,-column=>4,-columnspan=>1,-sticky => 'ens');
     
    our $run_psn_button = $run_frame -> Button(-image=>$gif{run}, -width=>45,-border=>$bbw, -background=>$button, -activebackground=>$abutton,-command=> sub{
      my $files = ""; 
      $psn_params = $psn_command_entry -> get();
      my $psn_nm_version = "";
      if ($nm_version_chosen ne "default") {$psn_nm_version .= " -nm_version=".$nm_version_chosen." ";};
      @runs = $models_hlist -> selectionGet ();
      $psn_commands{$psn_option} = $psn_params;
      save_settings ("psn.ini", \%psn_commands, \%psn_commands_descr);
      if ($psn_option eq "sumo") { # then use .lst file as argument
        foreach (@ctl_show[@runs]) {$files = $files." ".$_.".".$setting{ext_res}};
      } else {
        foreach (@ctl_show[@runs]) {$files = $files." ".$_.".".$setting{ext_ctl}};
      }
      if ($gif{cluster_active}==1) {
        if (substr($cwd,0,1) eq substr($setting{cluster_drive},0,1)) {
          @cur_dir = split('/',unix_path($cwd));
          shift(@cur_dir);
          $cur_dir_unix = join('/',@cur_dir); 
          status ("Starting PsN command on cluster");
          if ($setting{cluster_type}==1) {
            my $psn_command = $setting{ssh_login}.' "cd ~/'.$cur_dir_unix.'; '.$software{psn_on_cluster}.$psn_option." ".$psn_params.$psn_nm_version.$files.' &"';
            system 'start '.$psn_command;
            db_log_execution (@ctl_show[@runs[0]].".".$setting{ext_ctl}, $models_descr{@ctl_show[@runs[0]]}, "PsN", "LinuxCluster", $psn_command, $setting{name_researcher});
            if ($stdout) {$stdout -> insert('end', "\n".$psn_command);}
          } else {
            my $psn_command = win_path($software{perl_dir})."\\bin\\".$psn_option." ".$psn_params.$psn_nm_version.$files;
            system "start ".$psn_command;
            db_log_execution (@ctl_show[@runs[0]].".".$setting{ext_ctl}, $models_descr{@ctl_show[@runs[0]]}, "PsN", "PCLuster", $psn_command, $setting{name_researcher});
            if ($stdout) {$stdout -> insert('end', "\n".$psn_command);}
          }
          status ();
        } else {
          message ("Your current directory is not located on the cluster.\nChange to your cluster-drive or change your preferences.")
        }
      } else {
        status ("Starting run(s) locally using PsN");
        my $psn_command = win_path($software{perl_dir})."\\bin\\".$psn_option." ".$psn_params.$psn_nm_version.$files;
        system "start ".$psn_command;
        db_log_execution (@ctl_show[@runs[0]].".".$setting{ext_ctl}, $models_descr{@ctl_show[@runs[0]]}, "PsN", "local", $psn_command, $setting{name_researcher});
        if ($stdout) {$stdout -> insert('end', "\n".$psn_command);}
        $mw -> update();
        status ();
      }
      if ($stdout) {$stdout -> yview (scroll=>1, units);}
      $mw -> update();
      chdir ($cwd);
    })->grid(-row=>1,-column=>5,-columnspan=>1,-rowspan=>2,-sticky=>'wens');   
    $help->attach($run_psn_button, -msg => "Run model(s) using PsN");
  }
  
  if ($run_method eq "WFN") {
    chdir($cwd);
    $wfn_command_entry = $run_frame -> Entry(-textvariable=>\$wfn_run_parameters, -border=>2, -state=>'normal',-width=>10,-relief=>'groove',-font=>$font_normal,-background=>"#FFFFFF")
       ->grid(-sticky=>'we',-row=>1,-column=>3,-columnspan=>1,-ipady=>4);
    if($setting{"wfn_".$wfn_option} eq "") {$par = " "} else {$par = $setting{"wfn_".$wfn_option}};
    $wfn_command_entry -> configure(-textvariable=>$par);
    my $no_threads;
    my @threads = qw/Threads: 1 2 4 8 10/ ; my $no_threads = @threads[0];
   # $run_frame -> Label(-text=>"WFN parameters: ") -> grid(-sticky=>'e',-row=>2,-column=>3,-columnspan=>1,-ipady=>4);
    $threads_options = $run_frame -> Optionmenu(-options => [@threads], -variable => \$no_threads, -border=>0, -background=>"#c0c0c0",-activebackground=>"#a0a0a0",
          -font=>$font_normal, -state=>'normal', -width=>8, -command=> sub{
         })-> grid(-row=>1,-column=>4,-columnspan=>1,-sticky => 'ens');
    $help -> attach($threads_options, -msg => "Number of threads to divide the number of bootstrap runs into.\nE.g. 'nmbs 1 1000', with 4 threads will start the following bootstrap runs:\n  nmbs 1 250\n  nmbs 251 500\n  nmbs 501 750\n  nmbs 751 1000\nSee manual for more information.");
    
    if ($nm_versions_menu) { $nm_versions_menu -> gridForget(); } ;
    $run_frame -> Label(-text=>"WFN parameters: ") -> grid(-sticky=>'e',-row=>2,-column=>1,-columnspan=>1,-ipady=>4);
    $wfn_parameters = $setting{wfn_param};
    $wfn_param_entry = $run_frame -> Entry(-textvariable=>\$wfn_parameters, -width=>37, -border=>1, -relief=>'groove', -font=>$font_normal,-background=>$yellow)
       ->grid(-sticky=>'wens',-row=>2,-column=>2,-columnspan=>3, -ipady=>0);
    @methods = qw/nmgo nmbs/;
    $wfn_methods = $run_frame -> Optionmenu(-options => [@methods],-variable => \$wfn_option, -border=>0, -background=>$run_color,-activebackground=>$arun_color,
          -font=>$font_normal, -width=>7, -command=> sub{ 
             if($setting{"wfn_".$wfn_option} eq "") {$par = " "} else {$par = $setting{"wfn_".$wfn_option}};
             $wfn_command_entry -> configure(-textvariable=>$par);
             if ($wfn_option eq "nmgo") {$state="disabled"} else {$state="normal"};
             $wfn_command_entry -> configure(-state=>$state);
             $threads_options -> configure(-state=>$state); 
          })-> grid(-row=>1,-column=>2,-columnspan=>1,-sticky => 'wns');
    $help->attach($wfn_command_entry, -msg => "Run parameters");
    $help->attach($wfn_param_entry, -msg => "WFN parameters, e.g. g77 std");
    our $run_wfn_button = $run_frame -> Button(-image=>$gif{run}, -width=>45,-border=>$bbw, -background=>$button, -activebackground=>$abutton,-command=> sub{
      my $files = ""; 
      if ($no_threads eq "Threads:") {$no_threads = 1};
      @runs = $models_hlist -> selectionGet ();
      $wfn_run_params = $wfn_command_entry -> get();
      $wfn_params = $wfn_param_entry -> get();
      $setting{wfn_param} = $wfn_params;
      my $rand_filename = exec_run_wfn (win_path($software{'wfn_dir'}), $wfn_option, (@ctl_show[@runs])[0], $wfn_run_params, $wfn_params, $no_threads);      
      unless ($rand_filename eq "") {
        my $wfn_command = "start ".$rand_filename;
        if ($stdout) {$stdout -> insert('end', "\n".$wfn_command);}        
        system $wfn_command;
      }        
    })->grid(-row=>1,-column=>5,-columnspan=>1,-rowspan=>2,-sticky=>'wens');   
    $help->attach($run_wfn_button, -msg => "Run model(s) using Wings for NONMEM");
  }
}

sub update_psn_zink {
### Purpose : Add or substract " -run_on_zink" from the psn parameter entry, depending on if in cluster mode or not
### Compat  : W+L? 
  if ($psn_command_entry) {
    my $psn_parameters = $psn_command_entry -> get();
    if (($gif{cluster_active}==1)&&($setting{cluster_type}==2)) {
      unless ($psn_parameters =~ m/-run_on_zink/i) {
        $psn_parameters .= " -run_on_zink";
        $psn_command_entry -> configure (-text=>$psn_parameters);
      }
    } else {
      $psn_parameters =~ s/-run_on_zink//gi;
      $psn_command_entry -> configure (-text=>$psn_parameters);
    }      
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
    $project_buttons = $frame_dir -> Optionmenu(-options => [sort (@projects)], -width=>38, -border=>$bbw,  
        -variable => \$active_project,-background=>"#202099",-activebackground=>"#5050aa",-font=>$font_bold, -foreground=>'white', -activeforeground=>'white')
     -> grid(-row=>1,-column=>2,-columnspan=>1, -sticky=>'we');
     $frame_dir -> update();
     $project_buttons -> configure (-command=>sub{
        $cwd = $project_dir{$active_project}; 
        $dir_entry -> configure(-text=>$cwd);
        save_log();
        $frame_dir -> update();
        refresh_pirana($cwd);
     });
    $cwd = $project_dir{$active_project}; 
    $dir_entry -> configure(-text=>$cwd);  
}

sub project_buttons_show {
### Purpose : Show the buttons for saving/editing/info of the projects
### Compat  : W+L?
  $frame_dir -> Label(-text=>'Project:',-font => $font_normal, -background=>$bgcol)-> grid(-row=>1,-column=>1, -sticky => 'e');
  $frame_dir -> Label(-text=>'Folder:',-font => $font_normal, -background=>$bgcol)-> grid(-row=>2,-column=>1, -sticky => 'e');
  $dir_entry = $frame_dir -> Entry(-width=>44, -textvariable=>\$cwd, -border=>2, -relief=>'groove', -background=>'#FFFFEE',-font=>$font_normal)
    -> grid(-row=>2,-column=>2, -sticky => 'wens',-columnspan=>4);
  $dir_entry->bind("<Return>", sub { 
     $cwd = $dir_entry -> get();
     unless (-d $cwd) {
       $cwd = substr($cwd,0,2)."/";
     }
     refresh_pirana($cwd);
  });
  $mw->iconimage($gif{pirana});
  our $browse_button = $frame_dir -> Button(-image=>$gif{browse}, -width=>28, -border=>0,-background=>$button, -activebackground=>$abutton, -command=> sub{
      $dir_old = $cwd;
      $cwd = $mw-> chooseDirectory();
      if($cwd eq "") {$cwd=$dir_old};
      refresh_pirana($cwd);
    })->grid(-row=>2, -column=>6, -rowspan=>1, -sticky => 'nwse');
  $help->attach($browse_button, -msg => "Browse filesystem");
  
  $frame_dir -> Label (-text=>"  ", -background=>$bgcol, -width=>36)->grid(-row=>1,-column=>2, -sticky => 'wens');
  our $save_button = $frame_dir -> Button(-image=>$gif{save}, -border=>$bbw, -background=>$button,-activebackground=>$abutton, -width=>22, -height=>22, -command=> sub{
    save_project($cwd) })
    ->grid(-row=>1,-column=>3, -sticky => 'we');
  $help->attach($save_button, -msg => "Save this folder as project");
  our $edit_proj_button = $frame_dir -> Button(-image=>$gif{edit_info_blue}, -border=>$bbw, -background=>$button,-activebackground=>$abutton, -width=>22, -height=>22, -command=> sub{
      project_info_window();
    })->grid(-row=>1,-column=>4, -sticky => 'ens');
  $help->attach($edit_proj_button, -msg => "Edit project details");
  our $delete_button = $frame_dir -> Button(-image=>$gif{del_project}, -border=>$bbw, -background=>$button, -activebackground=>$abutton, -width=>22, -height=>22, -command=> sub{
    del_project(); })
    ->grid(-row=>1,-column=>5, -rowspan=>1, -sticky => 'we');
  $help->attach($delete_button, -msg => "Delete project");
  our $reload_button = $frame_dir -> Button(-image=>$gif{reload}, -border=>$bbw, -background=>$button, -activebackground=>$abutton, -width=>22, -height=>22, -command=> sub{
    refresh_pirana($cwd)
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
  $style = $models_hlist-> ItemStyle( 'text', -anchor => 'w',-padx => 5, -background=>'white', -font => $font_normal);;
  foreach my $row (@$db_results) {
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
    unless ($inter_window) { # build the dialog
      our $inter_window = $mw -> Toplevel(-title=>'Progress of runs in '.$cwd);
      $inter_window -> resizable( 0, 0 );
      $inter_window -> OnDestroy ( sub{
        undef $inter_window; undef $inter_window_frame; 
      });
      $inter_window -> iconimage($gif{network}); # doesn't work properly for some reaseon
      $inter_window_frame = $inter_window -> Frame(-background=>$bgcol)->grid(-ipadx=>10,-ipady=>0);
      our $inter_dirs;
      $inter_frame_status = $inter_window -> Frame(-relief=>'sunken', -border=>0, -background=>$status_col)->grid(-column=>0, -row=>4, -ipadx=>10, -sticky=>"nwse");
      $inter_status_bar = $inter_frame_status -> Label (-text=>"Status: Idle", -anchor=>"w", -font=>$font_normal,-width=>85, -background=>$status_col)->grid(-column=>1,-row=>1,-sticky=>"w");
      $inter_frame_buttons = $inter_window_frame -> Frame(-relief=>'sunken', -border=>0, -background=>$bgcol)->grid(-column=>1, -row=>2, -ipady=>0, -sticky=>"wns");
      $inter_frame_buttons -> Button (-text=>'Rescan directories',  -width=>20, -border=>$bbw,-background=>$button, -activebackground=>$abutton,-command=>sub{
        $grid -> delete("all");
        inter_status ("Searching sub-directories for active runs...");
        @n = get_runs_in_progress();
        if ( int(@n) == 1 ) {
          inter_status ("No active runs found");
        } else {inter_status()};
      }) -> grid(-column => 1, -row=>1, -sticky=>"wns");
      $inter_frame_buttons -> Button (-text=>'Open intermediate files',  -width=>20, -border=>$bbw,-background=>$button, -activebackground=>$abutton,-command=>sub{
         @info = $grid->infoSelection();
         foreach (@info) { 
           my $dir = $_;
           if ($dir ne "") {
             if (-e $cwd."/".$dir."/OUTPUT") {edit_model(win_path($cwd."/".$dir."/OUTPUT"));}
             if (-e $cwd."/".$dir."/INTER") {edit_model(win_path($cwd."/".$dir."/INTER"));}
             if (-e $cwd."/".$dir."/psn.lst") {edit_model(win_path($cwd."/".$dir."/psn.lst"))}
           }
         }
      }) -> grid(-column => 2, -row=>1, -sticky=>"w");
      $inter_frame_buttons -> Button (-text=>'Refresh estimates',  -width=>20, -border=>$bbw,-background=>$button, -activebackground=>$abutton,-command=>sub{
       #get all 
         foreach (@inter_dirs) { };
         @info = $grid->infoSelection();
         $grid_inter -> delete("all");
         inter_results ($cwd."/".@info[0]);
      }) -> grid(-column => 3, -row=>1, -sticky=>"w");
    
      $inter_window_frame -> Label (-text=>' ',  -width=>9, -background=>$bgcol, -font=>"Arial 3") -> grid(-column => 1, -row=>0, -sticky=>"w");
      $inter_frame_buttons -> Label (-text=>' ',  -width=>9, -background=>$bgcol) -> grid(-column => 1, -row=>2, -sticky=>"w");
      $inter_intermed_frame = $inter_window -> Frame(-relief=>'sunken', -border=>0, -background=>$bgcol)->grid(-column=>0, -row=>3, -ipadx=>10, -sticky=>"nwse");
      $inter_intermed_frame -> Label (-text=>'Note: to get intermediate estimates from runs, MSF files are needed.', -foreground=>"#666666", -background=>$bgcol) -> grid(-column => 1, -row=>2, -sticky=>"w");
      $inter_intermed_frame -> Label (-text=>' ',  -width=>9, -background=>$bgcol) -> grid(-column => 1, -row=>3, -sticky=>"w");
    } else {$inter_window -> focus};
    inter_status ("Searching sub-directories for active runs...");
    chdir ($cwd);
      
    my @headers = ( "MSF", "Iterations","OFV");
    my @headers_widths = (60, 60, 60, 160,160);
    
    our $grid = $inter_window_frame ->Scrolled('HList', -head => 1, 
        -columns    => 5, -scrollbars => 'e',-highlightthickness => 0,
        -height     => 6, -border     => 0, 
        -width      => 100, -background => 'white',
        -browsecmd => sub{
          @info = $grid->infoSelection();
          chdir (@info[0]);
          get_run_progress();
          chdir ($cwd);
          inter_results ($cwd."/".@info[0]);
        }
    )->grid(-column => 1, -columnspan=>7,-row => 1, -sticky=>"wens");   
    
    my @headers_inter = (" ","Theta", "Omega","Sigma", "Gradients", " ");
    my @headers_inter_widths = (1, 54, , 54, 54, 100);

    our $grid_inter = $inter_intermed_frame ->Scrolled('HList', -head => 1, 
        -columns    => 6, -scrollbars => 'e', -highlightthickness => 0,
        -height     => 15, -border     => 0, 
        -width      => 100, -background => 'white',
    )->grid(-column => 1, -columnspan=>7, -row => 1);   
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
   $grid_inter -> update();
   @n = get_runs_in_progress();
   if ( int(@n) == 1 ) {
         inter_status ("No active runs found");
  } else {inter_status()};
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
    $item = shift;
    my $dir1;
    unless ($item =~ m/HASH/) {  # for some reason this sometimes is necessary.
        $grid->add($item);
        $grid->itemCreate($item, 0, -text => $res_runno{$item}, -style=>$align_right);
        $grid->itemCreate($item, 1, -text => $res_iter{$item}, -style=>$align_right );
        $grid->itemCreate($item, 2, -text => $res_ofv{$item}, -style=>$align_right);
        if ($item eq "/") { $dir1 = $item} else { $dir1 = "/".$item }
        $res_dir{$item} = $dir1;
        $grid->itemCreate($item, 3, -text => $dir1, -style=>$align_left);
        $grid->itemCreate($item, 4, -text => $res_descr{$item}, -style=>$align_left);
    }
    $grid -> update();
    push (@inter_dirs, $item)
}

sub get_runs_in_progress {
### Purpose : return a hash of runs that are currently in progress in the current directory, or in PsN/nmfe directories below 
### Compat  : W+L? 
  $dir = fastgetcwd()."/";
  @dirs = read_dirs_win();
  %dir_results = new ;
  %res_iter = {}; %res_ofv = {}; %res_runno = {};  %res_dir = {}; %res_descr = {};
  # First check main directory
  inter_status ("Searching / for active runs...");
    if ((-e "nonmem.exe")||(-e "nonmem")) {  # check for nmfe runs
      #unless ((-e "nonmem.exe")&&(-w "nonmem.exe")) {
        if (-e "INTER") {
          if ((-e "OUTPUT")&&(-s "OUTPUT" > 0)) {
            ($res_iter {"/"}, $res_ofv {"/"}, $res_descr{"/"}) = get_run_progress("OUTPUT");
          }
          inter_window_add_item("/");
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
            ($res_iter {$sub}, $res_ofv {$sub}, $res_descr{$sub}) = get_run_progress("OUTPUT");
          }
          @msf = glob("*MSF*");
          @msf[0] =~ s/MSF//ig;
          $res_runno{$sub} = @msf[0];
          inter_window_add_item($sub);
        }
      #}
    }
    # Check sub-directories
    if ($sub =~ m/_/) { # only do this for PsN- or nmfe directories, to save speed
    @dirs_sub = read_dirs_win("NM_run"); # PsN directories
    foreach $subdir (@dirs_sub) {
      chdir ($subdir);
      if ((-e "nonmem.exe")||(-e "nonmem")) {
          if (-e "INTER") {
            $sub = fastgetcwd();
            $sub =~ s/$dir//; # relative dir
            inter_status ("Searching ".$sub." for active runs...");
            if (-e "OUTPUT") {
              ($res_iter {$sub}, $res_ofv {$sub}, $res_descr{$sub}) = get_run_progress("psn.lst");
            }
            if (-e "psn.lst") {
              ($res_iter {$sub}, $res_ofv {$sub}, $res_descr{$sub}) = get_run_progress("psn.lst");
            }
            @msf = glob("*MSF*");
            @msf[0] =~ s/MSF//ig;
            $res_runno{$sub} = @msf[0];
            inter_window_add_item($sub);
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
  $output_file = shift;
  undef @gradients;
  @l = dir (".", $setting{ext_res});
  if (int(@l)>0) {
    $output_file = @l[0];
  }
 # if (-e "psn.lst") {$output_file = "psn.lst"};
  if ((-e "OUTPUT")&&(-s "OUTPUT" >0)) {$output_file = "OUTPUT"};
  $sub_iter =""; $sub_ofv="";
  open (OUT,"<".$output_file);
  @lines = <OUT>;
  close OUT;
  foreach $line (@lines) {
     if($line =~ m/ITERATION/gi) {
       our $sub_iter = substr($line,15,9);
       $sub_iter =~ s/\s//g;
       our $sub_ofv = substr($line,41,12);
       $sub_ofv =~ s/\s//g;
       $sub_ofv = rnd($sub_ofv, 7);
       our $sub_eval = substr($line,76,3);
       $sub_eval =~ s/\s//g;
     }
     if ($line =~ m/GRADIENT/) {
       $line =~ s/GRADIENT:// ;
       my @gradients_line = split(" ",$line);
       undef @gradients;
       foreach (@gradients_line) {
         if ($_ ne "") {
           chomp($_);
           $_ =~ s/\s//g;
           push(@gradients, rnd($_,6));
         }
       }  
     }
     if ($_ =~ m/OBJECTIVE VALUE/) {
      @ofv_line = split (/:/, $_);
      $sub_ofv = @ofv_line[2];
      $sub_ofv = substr($ofv,0,16);
      $sub_ofv =~ s/\s//g;
      $ofv_found = 1;
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
  return ($sub_iter, $sub_ofv, $mod{description});
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
    $grid_inter->itemCreate($i, 0, -text => $i, -style=>$align_right);
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
        $grid_inter->add($i);
    }
    $grid_inter->itemCreate($i, 4, -text => $_, -style=>$align_right);
    $i++;
  }
} 

sub extract_inter {
### Purpose : extract intermediate results from files in a folder
### Compat  : W+
  my $dir = shift;
  if ((-e $dir."/INTER")&&(-s $dir."/INTER" > 0)) {
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
  }

  $no_lines = int(@inter);
  if($no_lines>0) {
    my $last_iter=0;
    while (($no_lines>0) && ($last_iter<2)) {  # get last iteration line no
      $no_lines = $no_lines-1;
      if (@inter[$no_lines] =~ m/ITERATION/) {$last_iter++;} 
    }
    ### Gather THETA's
    my $theta_line_no = 3;
    if (@inter[$no_lines+$theta_line_no+1]=~/TH/g) {$theta_line_no++};
    $theta_line = @inter[$no_lines+$theta_line_no+2];
    @theta_arr = split(/\s/,$theta_line);
    @thetas = grep /\S/, @theta_arr;
    foreach(@thetas) {$_ = rnd($_, 7)};
    if($theta_line_no==4) { # 2 lines of THETAs
    $theta_line = @inter[$no_lines+$theta_line_no+3];
    @theta_arr = split(/\s/,$theta_line);
    @theta_arr = grep /\S/, @theta_arr;
    foreach(@theta_arr) {$_ = rnd($_, 6)};
      push(@thetas,@theta_arr);
    }

    ### Gather ETA's
    my $eta_line = $theta_line_no+5;
    if ($inter[$no_lines+$eta_line+1]=~/ET/g) {$eta_line++};
    if ($inter[$no_lines+$eta_line+1]=~/ET/g) {$eta_line++};
    if ($inter[$no_lines+$eta_line+1]=~/ET/g) {$eta_line++};
    our $curr_lineno = $no_lines + $eta_line + 2;
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
        $eta = rnd(@eta_arr[@eta_arr-1],5);
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
### Compat  : W+
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
      win_start($software{spreadsheet},'"'.win_path("bs.txt").'"');
  } else {message("Spreadsheet application not found. Please check settings.")};
}


sub create_duplicates_window { 
### Purpose : Create dialog window for making n duplicates from model(s)
### Compat  : W+
    my @models = $models_hlist -> selectionGet ();
    my $no_changed = 0; my $prefix = "###"; my $no_duplicates = 100;
    if (@models == 0) {
      message("First select some model to apply this batch funcion on!");
      return() ;
    }
    our $duplicates_window = $mw -> Toplevel(-title=>'Create n duplicates from model(s)');;
    $duplicates_window -> resizable( 0, 0 );
    $duplicates_window -> Popup;
    $duplicates_frame = $duplicates_window->Frame()->grid(-ipadx=>8, -ipady=>8);
    $duplicates_frame -> Label (-text=>"This will create n copies from one or more model(s),\nadding a suffix (i.e. 'model_001', 'model_002' etc).",-font=>$font_normal,-justify=>"left")->grid(-row=>1, -column=>1, -columnspan=>2,-sticky=>"nw");
    $duplicates_frame -> Label (-justify=>'left',-text=>" ",-font=>$font_normal,)->grid(-row=>2, -column=>1, -columnspan=>2,-sticky=>"nw");
    $duplicates_frame -> Label (-text=>"Duplicate models:",-font=>$font_normal,)->grid(-row=>3, -column=>1, -sticky=>"ne");
    $duplicates_frame -> Label (-justify=>'left',-text=>" ",-font=>$font_normal,)->grid(-row=>4, -column=>1, -columnspan=>2,-sticky=>"nw");
    $duplicates_frame -> Label (-text=>"Number of duplicates:",-font=>$font_normal,)->grid(-row=>5, -column=>1, -sticky=>"ns");
    $duplicates_frame -> Entry (-textvariable=>\$no_duplicates,-font=>$font_normal,-width=>8)->grid(-row=>5, -column=>2, -sticky=>"nws");
    $duplicates_frame -> Label (-justify=>'left',-text=>" ",-font=>$font_normal,)->grid(-row=>6, -column=>1, -columnspan=>2,-sticky=>"nw");
    $duplicates_frame -> Checkbutton (-text=>"Change run-numbers in ouput/tables?",-activebackground=>$bgcol,-variable=>\$change_run_nos)->grid(-row=>7,-column=>2,-sticky=>'w');  
    $duplicates_frame -> Checkbutton (-text=>"Use final parameter estimates from reference model?",-activebackground=>$bgcol,-variable=>\$est_as_init)->grid(-row=>8,-column=>2,-sticky=>'w');  
    $duplicates_frame -> Label (-justify=>'left',-text=>" ",-font=>$font_normal,)->grid(-row=>9, -column=>1, -columnspan=>2,-sticky=>"nw");
    $duplicates_text = $duplicates_frame -> Scrolled ('Text', -font=>$font_normal,-width=>18, -height=>8, -scrollbars=>'e') 
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
### Compat  : W+
    my @models = $models_hlist -> selectionGet ();
    my $no_changed = 0;
    if (@models == 0) {
      message("First select some model to apply this batch funcion on!");
      return() ;
    }
    our $replace_block_window = $mw -> Toplevel(-title=>'Change block in models');;
    $replace_block_window -> resizable( 0, 0 );
    $replace_block_window -> Popup;
    $replace_block_frame = $replace_block_window->Frame()->grid(-ipadx=>8, -ipady=>8);
    my $block = "\$TABLE";      
    $replace_block_frame -> Label (-text=>"This will replace the specified block with a new one.\n",-font=>$font_normal,-justify=>"left")
      ->grid(-row=>1, -column=>1, -columnspan=>2,-sticky=>"nw");
    $replace_block_frame -> Label (-text=>"Find block:",-font=>$font_normal,)
      ->grid(-row=>3, -column=>1, -sticky=>"ne");
    $replace_block_frame -> Entry (-textvariable=>\$block,-font=>$font_normal)
      ->grid(-row=>3, -column=>2, -sticky=>"nws");
    $replace_block_frame -> Label (-text=>"and replace with:",-font=>$font_normal,)
      ->grid(-row=>5, -column=>1, -sticky=>"ne");
    my $block_replace = $replace_block_frame -> Scrolled ('Text', -font=>$font_normal, -width=>30, -height=>8, -scrollbars=>'e') 
      -> grid(-row=>5, -column=>2, -ipady=>5, -columnspan=>2, -sticky=>"nwse");
    $replace_block_frame -> Label (-text=>"Models:",-font=>$font_normal,)->grid(-row=>7, -column=>1, -sticky=>"ne");
    $replace_block_text = $replace_block_frame -> Scrolled ('Text', -font=>$font_normal,-width=>18, -height=>8, -scrollbars=>'e') 
      -> grid(-row=>7, -column=>2, -ipady=>5, -columnspan=>2, -sticky=>"nws");
    $replace_block_frame -> Label (-justify=>'left',-text=>" ",-font=>$font_normal,)->grid(-row=>4, -column=>1, -columnspan=>2,-sticky=>"nw");
    $replace_block_frame -> Label (-justify=>'left',-text=>" ",-font=>$font_normal,)->grid(-row=>6, -column=>1, -columnspan=>2,-sticky=>"nw");
    $replace_block_frame -> Label (-justify=>'left',-text=>" ",-font=>$font_normal,)->grid(-row=>8, -column=>1, -columnspan=>2,-sticky=>"nw");
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
      my $no_changed = 0;
      foreach my $mod (@batch) {
        open (MOD, "<".$mod);
        my @lines = <MOD>;
        close MOD;
        open (WMOD, ">".$mod);
        my $bl_flag = 0;
        foreach my $line (@lines) {
          if (substr($line,0,1) eq "\$") {$bl_flag = 0}
          if (substr($line,0,length($block)) eq $block) {
            print WMOD $replace_with."\n";
            $bl_flag = 1;
          }
          if ($bl_flag==0) {
            print WMOD $line;          
          }
        }
        close WMOD;
        $no_changed++;
      }
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
    our $add_code_window = $mw -> Toplevel(-title=>'Change block in models');;
    $add_code_window -> resizable( 0, 0 );
    $add_code_window -> Popup;
    $add_code_frame = $add_code_window->Frame()->grid(-ipadx=>8, -ipady=>8);
    my $block = "\$TABLE";      
    $add_code_frame -> Label (-text=>"This will add the specified code at the end\nof the selected model files.\n",-font=>$font_normal,-justify=>"left")
      ->grid(-row=>1, -column=>1, -columnspan=>2,-sticky=>"nw");
    $add_code_frame -> Label (-text=>"Code:",-font=>$font_normal,)
      ->grid(-row=>5, -column=>1, -sticky=>"ne");
    my $code_entry = $add_code_frame -> Scrolled ('Text', -font=>$font_normal, -width=>30, -height=>8, -scrollbars=>'e') 
      -> grid(-row=>5, -column=>2, -ipady=>5, -columnspan=>2, -sticky=>"nwse");
    $add_code_frame -> Label (-text=>"Models:",-font=>$font_normal,)->grid(-row=>7, -column=>1, -sticky=>"ne");
    $add_code_text = $add_code_frame -> Scrolled ('Text', -font=>$font_normal,-width=>18, -height=>8, -scrollbars=>'e') 
      -> grid(-row=>7, -column=>2, -ipady=>5, -columnspan=>2, -sticky=>"nws");
    $add_code_frame -> Label (-justify=>'left',-text=>" ",-font=>$font_normal,)->grid(-row=>4, -column=>1, -columnspan=>2,-sticky=>"nw");
    $add_code_frame -> Label (-justify=>'left',-text=>" ",-font=>$font_normal,)->grid(-row=>6, -column=>1, -columnspan=>2,-sticky=>"nw");
    $add_code_frame -> Label (-justify=>'left',-text=>" ",-font=>$font_normal,)->grid(-row=>8, -column=>1, -columnspan=>2,-sticky=>"nw");

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
    $sim_seed_window -> Popup;
    my $sim_seed_frame = $sim_seed_window->Frame()->grid(-ipadx=>8, -ipady=>8);
    $sim_seed_frame -> Label (-text=>"This will change the seeds in the \$SIMULATION block\nto a random number. Other specifications such as\nUNIFORM/NEW/NONPARAMETRIC are kept.\n",-font=>$font_normal,-justify=>"left")->grid(-row=>1, -column=>1, -columnspan=>2,-sticky=>"nw");
    $sim_seed_frame -> Label (-text=>"Change seeds in:",-font=>$font_normal,)->grid(-row=>2, -column=>1, -sticky=>"ne");
    my $sim_seed_text = $sim_seed_frame -> Scrolled ('Text', -font=>$font_normal,-width=>18, -height=>8, -scrollbars=>'e') 
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
    $sim_seed_frame -> Label (-justify=>'left',-text=>" ",-font=>$font_normal)->grid(-row=>3, -column=>1, -columnspan=>2,-sticky=>"nw");
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