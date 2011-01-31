# This script is not included as a module, but read from pirana.pl
# as in-line script. This is to make it for developers easier to
# include extra functionality

sub create_menu_bar {
### Purpose : Create the menu bar
### Compat  : W+L+
  pirana_debug ($debug_mode, "Declare menu bar.");
  $mbar = $mw -> Menu(-background=>$bgcol, -border=>0);
  $mw -> configure(-menu => $mbar);
  
  pirana_debug ($debug_mode, "Declare FILE menu.");
  my $mbar_file = $mbar -> cascade(-label=>"File", -font=>$font, -background=>$bgcol,-underline=>0, -tearoff => 0);
  my $mbar_file_settings = $mbar_file -> cascade (-label => "Settings", -font=>$font,-background=>$bgcol,-underline=>1, -tearoff => 0);
  $mbar_file_settings -> command(-label => "General", -font=>$font, -background=>$bgcol,-underline=>0, -command=>sub {
      edit_ini_window("settings.ini", \%setting, \%setting_descr, "General settings",0)});
  $mbar_file_settings -> command (-label => "SSH settings",-font=>$font, -background=>$bgcol,-underline=>1, -command=> sub {
       ssh_setup_window();
    });
  $mbar_file_settings -> command (-label => "Sun Grid Engine settings",-font=>$font, -background=>$bgcol,-underline=>1, -command=> sub {
       sge_setup_window();
    });

  $mbar_file_settings -> command(-label => "Software locations", -font=>$font, -background=>$bgcol,-underline=>5, -command=>sub {
      my $software_ini = "software_linux.ini";
      if ($^O =~ m/darwin/i) {$software_ini = "software_osx.ini";}
      if ($^O =~ m/MSWin/i) {$software_ini = "software_win.ini";}
      edit_ini_window($software_ini, \%software, \%software_descr, "Software integration",1);
      });
  $mbar_file -> command(-label => "Exit",-font=>$font, -underline=>0,-background=>$bgcol, -command=>sub { quit(); } );

  pirana_debug ($debug_mode, "Declare MODEL menu.");
  my $mbar_model = $mbar -> cascade(-label =>"Models", -font=>$font,-background=>$bgcol,-underline=>0, -tearoff => 0);
  if ($setting{use_nmfe}==1) {
      $mbar_model -> command(-label => "Run (nmfe)",-font=>$font, -image=>$gif{run}, -compound => 'left',-background=>$bgcol, -background=>$bgcol,-underline=>0, -command=> sub { nmfe_command() });
  }

 pirana_debug ($debug_mode, "Declare MODEL -> PSN menu.");
  my $mbar_model_psn;
  if ($setting{use_psn}==1) {
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
  }
 pirana_debug ($debug_mode, "Declare MODEL -> WFN menu.");
  my $mbar_model_wfn;
  if ($setting{use_wfn}==1) {
      if ($os =~ m/MSWin/i) {
	  $mbar_model_wfn = $mbar_model -> cascade(-label => "WFN", -font=>$font,-image=>$gif{run}, -compound => 'left',-background=>$bgcol, -background=>$bgcol, -tearoff=>0);
	  $mbar_model_wfn -> command (-label=> " nmgo", -font=>$font,-compound => 'left',-image=>$gif{run}, -background=>$bgcol, -command => sub{
	      wfn_command("NMGO");
          });
	  $mbar_model_wfn -> command (-label=> " nmbs", -font=>$font,-compound => 'left',-image=>$gif{run}, -background=>$bgcol, -command => sub{
	      wfn_command("NMBS");
          });
      }
  }
  pirana_debug ($debug_mode, "Add to MODEL menu.");
  $mbar_model -> separator ;
  $mbar_model -> command(-label => "Properties", -font=>$font,-compound => 'left',-image=>$gif{edit_info}, -background=>$bgcol,-underline=>0, -command=> sub { properties_command(); });
  $mbar_model -> command(-label => "Edit model", -font=>$font,-image=>$gif{notepad}, -compound=>'left', -background=>$bgcol,-underline=>0, -command=> sub { edit_model_command(); });
  $mbar_model -> command(-label => "Rename model", -font=>$font, -image=>$gif{rename}, -compound=>'left',-background=>$bgcol,-underline=>0, -command=> sub { rename_model_command(); });
  $mbar_model -> command(-label => "Duplicate model", -font=>$font, -image=>$gif{duplicate}, -compound=>'left',-background=>$bgcol,-underline=>0, -command=> sub { duplicate_model_command(); });
  $mbar_model -> command(-label => "Duplicate model for MSF restart",-font=>$font,  -image=>$gif{msf}, -compound=>'left',-background=>$bgcol,-underline=>0, -command=> sub { duplicate_msf_command(); });
  $mbar_model -> command(-label => "Delete model(s)",-font=>$font, -image=>$gif{trash}, -compound=>'left',-background=>$bgcol,-underline=>0, -command=> sub { delete_models_command(); });

# Run reports

  pirana_debug ($debug_mode, "Declare RESULTS menu.");
  my $mbar_results = $mbar -> cascade(-label =>"Results", -font=>$font,-background=>$bgcol,-underline=>0, -tearoff => 0);
  $mbar_results -> command (-label => "Generate HTML run report", -font=>$font,-background=>$bgcol,-underline=>0,  -image=>$gif{HTML}, -compound=>'left', -command=> sub {
      generate_report_command(\%run_reports);
  });
  $mbar_results -> command(-label => "LaTeX tables of parameter estimates",-font=>$font, -background=>$bgcol,-underline=>0,  -image=>$gif{latex}, -compound=>'left', -command=> sub {
      generate_LaTeX_command(\%run_reports);
  });
  my $mbar_results_html = $mbar_results -> cascade (-image=>$gif{question_doc},-font=>$font, -compound=>'left', -label => "Include in run reports", -background=>$bgcol, -tearoff => 0);
  $mbar_results_html -> checkbutton (-label => "Basic run info",-font=>$font, -variable=>\$run_reports{basic_run_info}, -command=> sub{
      save_ini ($home_dir."/ini/run_reports.ini", \%run_reports, \%run_reports_descr, $base_dir."/ini_defaults/run_reports.ini");
  });
  $mbar_results_html -> checkbutton (-label => "Notes and comments",-font=>$font, -variable=>\$run_reports{notes_and_comments}, -command => sub{
      save_ini ($home_dir."/ini/run_reports.ini", \%run_reports, \%run_reports_descr, $base_dir."/ini_defaults/run_reports.ini");
  });
  $mbar_results_html -> checkbutton (-label => "Model file",-font=>$font, -variable=>\$run_reports{model_file}, -command=>sub{
      save_ini ($home_dir."/ini/run_reports.ini", \%run_reports, \%run_reports_descr, $base_dir."/ini_defaults/run_reports.ini");
  });
  $mbar_results_html -> checkbutton (-label => "Parameter estimates of all estimation methods", -font=>$font,-variable=>\$run_reports{param_est_all}, -command => sub {
      if ($run_reports{param_est_all} == 1 ) {
	  $run_reports{param_est_last} = 0;
      }
      save_ini ($home_dir."/ini/run_reports.ini", \%run_reports, \%run_reports_descr, $base_dir."/ini_defaults/run_reports.ini");
  });
  $mbar_results_html -> checkbutton (-label => "Parameter estimates of last estimation methods",-font=>$font, -variable=>\$run_reports{param_est_last}, -command => sub {
      if ($run_reports{param_est_last} == 1 ) {
	  $run_reports{param_est_all} = 0;
      }
      save_ini ($home_dir."/ini/run_reports.ini", \%run_reports, \%run_reports_descr, $base_dir."/ini_defaults/run_reports.ini");
  });
  $mbar_results -> command(-label => "View NM output file", -font=>$font,-background=>$bgcol,-underline=>0,-image=>$gif{notepad}, -compound=>'left', -command=> sub {
      @run = @ctl_show[$models_hlist -> selectionGet];
         if (@run>0) {
           my @sel = $models_hlist -> selectionGet ();
           my $model_id = @ctl_show[@sel[0]];
           edit_model(unix_path($cwd."\\".$model_id.".".$setting{ext_res}));
         } else {message("Please select model first!")};
       });

  if($use_scripts == 1) {
    pirana_debug ($debug_mode, "Declare SCRIPTS menu.");
    my $mbar_scripts = $mbar -> cascade(-label =>"Scripts", -font=>$font, -background=>$bgcol,-underline=>0, -tearoff => 0);
    my $mbar_scripts_run = create_scripts_menu ($mbar_scripts, "", 1, $base_dir."/scripts", "Scripts", 0);
    $mbar_scripts_run -> separator;
    my $mbar_scripts_user = create_scripts_menu ($mbar_scripts_run, "", 1, $home_dir."/scripts", "My scripts", 0);
    $mbar_scripts_run -> separator;
    
    my $mbar_scripts_rgui = create_scripts_menu ($mbar_scripts, "", 1, $base_dir."/scripts", "Open in RGUI", 2);
    $mbar_scripts_rgui -> separator;
    my $mbar_scripts_rgui_user = create_scripts_menu ($mbar_scripts_rgui, "", 1, $home_dir."/scripts", "My scripts", 2);
    $mbar_scripts_rgui -> separator;
    
    my $mbar_scripts_edit = create_scripts_menu ($mbar_scripts, "", 1, $base_dir."/scripts", "Edit template", 1);
    $mbar_scripts_edit -> separator;
    my $mbar_scripts_edit_user = create_scripts_menu ($mbar_scripts_edit, "", 1, $home_dir."/scripts", "My scripts", 1);
    #  $mbar_scripts_edit_user -> command (-background=>$bgcol, -font=>$font,-label=> "New script...", -command => sub {
    #      my $dialog = new_script_dialog ($home_dir."/scripts");
    #      center_window($dialog);
    #      $dialog -> focus();
    #  });

    $mbar_scripts -> command (-background=>$bgcol, -font=>$font,-label=> "New script...", -command => sub{
      my $dialog = new_script_dialog ($base_dir."/scripts");
      center_window($dialog);
      $dialog -> focus();
    });
    $mbar_scripts -> checkbutton (-label => "Show script console", -font=>$font, -variable => \$show_console);
  }

### removed temporarily due to problems with Statistics::R
#  $mbar_scripts -> command (-background=>$bgcol, -font=>$font,-label=> "Send model info to PiranaR", -command => sub {
#      send_model_info_to_R_command ();
#  });
  pirana_debug ($debug_mode, "Declare TOOLS menu.");
  my $mbar_tools = $mbar -> cascade(-label =>"Tools", -font=>$font, -background=>$bgcol,-underline=>0, -tearoff => 0);
  my $mbar_tools_NM = $mbar_tools -> cascade(-label =>"NONMEM", -font=>$font,-background=>$bgcol,-underline=>1, -tearoff => 0);
#  if ($^O =~ m/MSWin/) {
      $mbar_tools_NM -> command(-label => "Manage NM installations",-font=>$font, -background=>$bgcol,-underline=>1, -command=> sub { manage_nm_window() });
#  }
  $mbar_tools_NM -> command(-label => "Environment variables",-font=>$font, -background=>$bgcol,-underline=>1, -command=> sub { nm_env_var_window(); });
  if ($^O =~ m/MSWin/) {
      $mbar_tools_NM -> command(-label => "Install NM6/7 using NMQual", -font=>$font,-background=>$bgcol,-underline=>1, -command=> sub { install_nonmem_nmq_window() });
      $mbar_tools_NM -> command(-label => "Install NM6/7 from CD", -font=>$font,-background=>$bgcol,-underline=>0,-command=> sub { install_nonmem_window() });
  }
  my $mbar_tools_NM_priority;
  if ($os =~ m/MSWin/i) {
    $mbar_tools_NM_priority = $mbar_tools_NM -> cascade(-label => "Set priority active runs", -font=>$font,-background=>$bgcol,-underline=>1, -tearoff => 0);
    $mbar_tools_NM_priority -> command(-label => "Low", -background=>$bgcol,-underline=>1, -command=> sub {
       my $m = nonmem_priority("low");
       message ($m);
    });
    $mbar_tools_NM_priority -> command(-label => "Normal",-font=>$font, -background=>$bgcol,-underline=>1, -command=> sub {
       my $m = nonmem_priority("normal");
       message ($m);
    });
    $mbar_tools_NM_priority -> command(-label => "High",-font=>$font, -background=>$bgcol,-underline=>1, -command=> sub {
       my $m = nonmem_priority("high");
       message ($m);
    });
  }
  $mbar_tools_NM -> command(-label => "Search NM help files",-font=>$font, -background=>$bgcol,-underline=>1, -command=> sub {
	  text_window_nm_help ( \@nm_help_keywords, "NONMEM Help files");
   });
  $mbar_tools_NM -> command(-label => "Import / update NM help files",-font=>$font, -background=>$bgcol,-underline=>1, -command=> sub {
	  retrieve_nm_help_window ();
   });
 
  pirana_debug ($debug_mode, "Declare PSN options.");
  my $mbar_psn;
  if ($setting{use_psn}==1) {
    $mbar_psn = $mbar_tools -> cascade (-label => "PsN",-font=>$font,-background=>$bgcol, -underline=>0, -tearoff => 0);
    if (-e unix_path($software{psn_dir})."/psn.conf") {
      $mbar_psn -> command(-label => "Edit psn.conf (local)",-font=>$font, -background=>$bgcol,-underline=>0, -command=> sub {
	  edit_model (unix_path($software{psn_dir}."/psn.conf"));
      });
    }
    $mbar_psn -> command(-label => "Edit PsN default command parameters",-font=>$font, -background=>$bgcol,-underline=>1, -command=> sub {
	  edit_ini_window("psn.ini", \%psn_commands, \%psn_commands_descr, "PsN commands default parameters", 0);
      });
    $mbar_psn -> command(-label => "Update PsN help files",-font=>$font, -background=>$bgcol,-underline=>1, -command=> sub {
	  retrieve_psn_info_window ();
      });

  };

  pirana_debug ($debug_mode, "Declare WFN options.");
  my $mbar_wfn;
  if ((-e unix_path($software{wfn_dir})."/bin/wfn.bat")&&($os =~ m/MSWin/i)) {
    $mbar_wfn = $mbar_tools -> cascade (-label => "WFN", -font=>$font,-background=>$bgcol, -underline=>0, -tearoff => 0);
    $mbar_wfn -> command (-label=> "Edit wfn.bat",-font=>$font, -background=>$bgcol, -command => sub{
        edit_model($software{wfn_dir}."\\bin\\wfn.bat");
    });
  };

  my $mbar_xpose;
#  if (-d $software{r_dir}) {
#    $mbar_xpose = $mbar_tools -> cascade (-label => "Xpose",-font=>$font, -background=>$bgcol, -underline=>0, -tearoff => 0);
#    $mbar_xpose -> command(-label => "xpose.VPC from npc_dir folder", -background=>$bgcol,-underline=>6, -command=> sub {xpose_VPC_window();} );
#  };
  
  pirana_debug ($debug_mode, "Declare TOOLS -> BATCH options.");
  my $mbar_tools_batch = $mbar_tools -> cascade(-label =>"Batch processing",-font=>$font, -background=>$bgcol, -tearoff => 0);
  $mbar_tools_batch -> command(-label => "Create n duplicates of model(s)", -font=>$font,-background=>$bgcol, -command=> sub { create_duplicates_window()});
  $mbar_tools_batch -> command(-label => "Add code to models",-font=>$font, -background=>$bgcol, -command=> sub { add_code() });
  $mbar_tools_batch -> command(-label => "Replace blocks", -font=>$font,-background=>$bgcol, -command=> sub { batch_replace_block() });
  $mbar_tools_batch -> command(-label => "Random seeds in \$SIM", -font=>$font,-background=>$bgcol, -command=> sub { random_sim_block_window() });

#  $mbar_tools -> command(-label => "PiranaR interface",-image=>$gif{pirana_r}, -font=>$font,-compound=>'left', -background=>$bgcol,-underline=>0,
#		  -command=>sub {create_window_piranaR ($mw, "", 0);});

  $mbar_tools -> command(-label => "Covariance calculator",-image=>$gif{calc_cov}, -font=>$font,-compound=>'left', -background=>$bgcol,-underline=>0, -command=>sub {cov_calc_window()});
  $mbar_tools -> command(-label => "Generate summary (csv) of all output", -font=>$font, -image=>$gif{compare}, -compound=>'left',-background=>$bgcol,-underline=>1, -command=> sub {
        create_output_summary_csv ("pirana_run_summary.csv", \%setting, \%models_notes, \%models_descr, $mw);
        if (-e $software{spreadsheet}) {
          start_command($software{spreadsheet},'"'.win_path('pirana_run_summary.csv').'"');
        } else {message("Spreadsheet application not found. Please check settings.")};
        status ();
    });
  $mbar_tools -> command(-label => "Clean-up folder", -font=>$font, -image=>$gif{clean_dir}, -compound=>'left',-background=>$bgcol,-underline=>1, -command=> sub {
      cleanup_runtime_files_window();
    });
  pirana_debug ($debug_mode, "Declare VIEW options.");
  my $mbar_view = $mbar -> cascade(-label =>"View", -font=>$font, -background=>$bgcol,-underline=>0, -tearoff => 0);

#  $mbar_view -> checkbutton(-variable=>\$show_tab_list, -image=>$gif{split_vertical}, -label=>"    Show tables & files", -compound=>'left', -command=>sub{
#      redraw_screen($full_screen, $show_tab_list);
#  });
#  $mbar_view -> checkbutton(-variable=>\$show_model_info, -image=>$gif{edit_info}, -label=>"    Show model info / coloring", -compound=>'left', -command=>sub{
#      $run_frame -> destroy();
#      $tab_frame_info -> destroy();
#      refresh_pirana();
#  });
  $mbar_view -> checkbutton (-variable=>\$condensed_model_list, -font=>$font,-image=>$gif{binocular}, -label => "    Condensed view", -compound=>'left',  -command=>sub{
      populate_models_hlist ($models_view, $condensed_model_list);
  });

  $mbar_view -> command (-label => "    Execution log", -font=>$font, -image=>$gif{log}, -compound=>'left',-background=>$bgcol, -command=>sub {
      show_exec_runs_window();
    });
  #if ($setting{use_cluster} == 1) {
  #    $mbar_view -> command(-label => "PCluster monitor", -font=>$font, -image=>$gif{pcluster_active}, -compound=>'left',-background=>$bgcol, -command=>sub {cluster_monitor()});
  #}
 #$mbar_view -> checkbutton (-label => "Console output", -variable=> \$process_monitor, -background=>$bgcol,-underline=>1,
 #  -command=>sub {
 #     show_console_output();
 #   });
  $mbar_view -> command (-label => "    Show parameter estimates", -font=>$font,-image=>$gif{estim}, -compound=>'left', -background=>$bgcol, -command=>sub {
        my @lst = @ctl_show[$models_hlist -> selectionGet ()];
        my $lst = @lst[0].".".$setting{ext_res};
        show_estim_window ($lst);
        $estim_window -> raise();
    });
  $mbar_view -> command (-label => "    Intermediate results of active runs", -font=>$font, -image=>$gif{edit_inter}, -compound=>'left',-background=>$bgcol, -command=>sub {
    $cwd = $dir_entry -> get();
      chdir($cwd);
      show_inter_window($cwd);
      if ($inter_window) {$inter_window -> focus();}
   });
  pirana_debug ($debug_mode, "Declare HELP options.");
  my $mbar_help = $mbar -> cascade(-label =>"Help", -font=>$font, -background=>$bgcol,-underline=>0, -tearoff => 0);
  $mbar_help -> command(-label => "Piraña manual", -font=>$font, -background=>$bgcol,-underline=>0,-command=> sub {
      if (-e $software{pdf_viewer} ) {
	  start_command($software{pdf_viewer}, unix_path($base_dir."/doc/Manual.pdf"));
      } else {
	  start_command($software{browser}, "file://".unix_path($base_dir."/doc/Manual.pdf"));
      }
  });
  $mbar_help -> command(-label => "Piraña website", -font=>$font, -background=>$bgcol,-underline=>0,-command=>sub {start_command($software{browser},"http://pirana.sf.net")});
  
  $mbar_help -> command(-label => "Search NM help files",-font=>$font, -background=>$bgcol,-underline=>1, -command=> sub {
	  text_window_nm_help ( \@nm_help_keywords, "NONMEM Help files");
   });

   pirana_debug ($debug_mode, "Declare HELP -> PSN options.");
  my $mbar_help_psn = $mbar_help -> cascade(-label => "PsN", -font=>$font, -background=>$bgcol, -tearoff=>0);
  $mbar_help_psn -> command(-label => "PsN documentation", -font=>$font, -background=>$bgcol,-command=>sub {
      start_command($software{browser}, "http://psn.sourceforge.net/docs.php");
  });
  $mbar_help_psn -> command(-label => "execute", -font=>$font, -background=>$bgcol,-command=>sub { $psn_help_command = get_psn_help ("execute", $software{psn_toolkit}); text_window($mw, $psn_help_command, "PsN Help files"); });
  $mbar_help_psn -> command(-label => "vpc", -font=>$font, -background=>$bgcol,-command=>sub { $psn_help_command = get_psn_help ("vpc", $software{psn_toolkit}); text_window($mw, $psn_help_command, "PsN Help files"); });
  $mbar_help_psn -> command(-label => "npc", -font=>$font, -background=>$bgcol,-command=>sub { $psn_help_command = get_psn_help ("npc", $software{psn_toolkit}); text_window($mw, $psn_help_command, "PsN Help files"); });
  $mbar_help_psn -> command(-label => "bootstrap", -font=>$font, -background=>$bgcol,-command=>sub { $psn_help_command = get_psn_help ("bootstrap", $software{psn_toolkit}); text_window($mw, $psn_help_command, "PsN Help files"); });
  $mbar_help_psn -> command(-label => "llp", -font=>$font, -background=>$bgcol,-command=>sub { $psn_help_command = get_psn_help ("llp", $software{psn_toolkit}); text_window($mw, $psn_help_command, "PsN Help files"); });
  $mbar_help_psn -> command(-label => "sse", -font=>$font, -background=>$bgcol,-command=>sub { $psn_help_command = get_psn_help ("sse", $software{psn_toolkit}); text_window($mw, $psn_help_command, "PsN Help files"); });
  $mbar_help_psn -> command(-label => "sumo", -font=>$font, -background=>$bgcol,-command=>sub { $psn_help_command = get_psn_help ("sumo", $software{psn_toolkit}); text_window($mw, $psn_help_command, "PsN Help files"); });

  $mbar_help -> command(-label => "Xpose", -font=>$font, -background=>$bgcol,-command=>sub {start_command($software{browser},"http://xpose.sourceforge.net")});
  $mbar_help -> command(-label => "WFN", -font=>$font, -background=>$bgcol,-command=>sub {start_command($software{browser},"http://wfn.sourceforge.net")});
  $mbar_help -> command(-label => "About Piraña", -font=>$font, -background=>$bgcol, -command=>sub {
      my $about_text = "Piraña (version ".$version.")\n\n Development team:\nRon Keizer (2007-2010)\nCoen van Hasselt(2010)\n\nDepartment of Pharmacy & Pharmacology,\n   Slotervaart Hospital / The Netherlands Cancer Institute.\n\nAcknowledgments to the people in my modeling group for testing.\nValuable feedback was also provided by various modelers from around the world.\n\nhttp://pirana.sf.net\n";
      message ($about_text);
  });
}
