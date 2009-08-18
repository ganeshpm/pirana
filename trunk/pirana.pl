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
use strict;                 # 
use Cwd;                    # Basic functions
use Tk;                     # Tk
use Tk::Balloon;            # Help balloon widget
use Tk::HList;              # HList widget
use Tk::ItemStyle;          # ..
use Tk::HdrResizeButton;    # Resizable headers in Tk::Hlist
use Tk::Text;               # Textarea widget 
use Tk::PlotDataset;        # For DataInspector
use Tk::LineGraphDataset;   # ..
use File::Copy;             # File info and operations
use File::stat;             # ..
use File::Path;             # ..
use HTTP::Date;             # Date and time functions
use List::Util qw(max maxstr min minstr reduce); # some basic functions
use POSIX qw(ceil floor);   # some basic functions
use DBI;                    # database connection to sqlite
use Math::BigFloat;         # used for rounding to significant digits

#*** Some parameter initalisation **********************************************
our $version="2.1b";
our $os = $^O;
our $base = cwd();
if ($os =~ m/MSWin/i) {
  require Win32::Process;
  Win32::SetChildShowWindow(0); # don't open new console windows
  require Win32::DriveInfo;     # needed for NM install
} 
our $base_dir = $base;
our %setting, our %setting_descr, our %nm_dirs, our %nm_vers;
our %software, our %software_descr; our $nm_reg_chosen; our $nm_reg_chosen;
our %project, our %project_dir, our %project_nr = (); our %scripts; our %scripts_descr;
our %clients, our %clients_descr; our $active_project; our $cwd;
our $show_ofv, our $show_successful, our $show_covar; our $init_message;
our $first_startup; our %vars; our %psn_commands; our %psn_commands_descr;
our $dir_old, our $run_listbox, our $i, our $nm_reg_chosen; our $mw_width = 1016; our $mw_height = 600;
our $method_chosen, our $local_method_chosen, our $psn_parameters;  our $cluster_active = 0;
our @runs, our @ctl_files, our @res_files; our @res_files_loc; our @tabcsv_files; our @tabcsv_loc;
our $models_hlist; our $tab_hlist; our $frame_links; our $cluster_active;

if (-e $base_dir."/log/startup.log") {$first_startup=0} else {$first_startup=1};

#*** Read all Pirana modules ***************************************************
do ("./subs.pl");           
use pirana_modules::db        qw(db_create_tables db_log_execution db_read_exec_runs db_read_model_info db_read_table_info db_insert_model_info db_insert_table_info delete_run_results db_add_note db_add_color db_read_all_model_data db_execute db_execute_multiple);
use pirana_modules::editor    qw(text_edit_window refresh_edit_window save_model);
use pirana_modules::model     qw(change_seed get_estimates_from_lst extract_from_model extract_from_lst extract_th extract_cov blocks_from_estimates duplicate_model get_cov_mat output_results_HTML); 
use pirana_modules::pcluster  qw(generate_zink_file get_active_nodes);
use pirana_modules::misc      qw(dir ascend log10 bin_mode rnd one_dir_up win_path unix_path tab2csv csv2tab center_window read_dirs_win win_start); 
use pirana_modules::PsN       qw(get_psn_info get_psn_help get_psn_nm_versions);
use pirana_modules::data_inspector qw(create_plot_window read_table);

#*** Initialization ************************************************************
read_log();    # read last settings for Project / NONMEM
initialize();  # read ini-files: preferences, software, nm-installations etc.
$setting{frame2_vis} = 1;

#*** Windows & Colors **********************************************************
our $run_msf        = 0;
our $blue           = "#D0F0FF";
our $pirana_orange  = "#ffEE99";
our $lighterblue    = "#d3d3e3";
our $lightblue      = "#b3c3ea";
our $darkblue       = "#a5b5dc";
our $lightred       = "#FFC9a4";
our $darkred        = "#efb894";
our $darkerred      = "#BE5040";
our $lightyellow    = "#EFEFc7";
our $darkyellow     = "#DFDF95";
our $lightgreen     = "#b8e3b8";
our $darkgreen      = "#a5d3a5";
our $yellow         = "#f8f8e6";
our $white          = "#ffffff";
our $bbw            = 0; # button border width;
our $filter         = "";

#*** Main Window ***************************************************************
our $bgcol      = "#ece9d8";
our $button     = "#dddac9";
our $abutton    = "#cecbba";
our $status_col = "#fffdec"; 
our $mw = MainWindow -> new (-title => "Piraña", -background=>$bgcol);
our $nrows = 28;
if ($os =~ m/MSWin/i) {
  our $models_hlist_width=106; 
} else {
  our $models_hlist_width=104; 
}
our $help = $mw->Balloon();

#*** Load Icons (from http://sourceforge.net/projects/icon-collection **********
our $frame_dir = $mw -> Frame(-background=>$bgcol) -> grid(-row=>0,-column=>1, -columnspan=>10, -ipadx=>'5',-ipady=>'0',-sticky=>'nws', -rowspan=>2);
chdir ("./images");
my @images = <*.gif>;
chdir ("..");
our %gif; our %gif_file;
foreach my $file (@images) {
  my $name = $file;
  $name =~ s/\.gif//i;
  $gif_file{$name} = $file;
  $gif{$name} = $frame_dir -> Photo ( -file => "images/".$file );
} 
    
#*** Menu bar ******************************************************************
our $mbar = $mw -> Menu(-background=>$bgcol);
our $mw -> configure(-menu => $mbar);
our $mbar_file = $mbar -> cascade(-label=>"File", -background=>$bgcol,-underline=>0, -tearoff => 0);
$mbar_file -> command(-label => "Preferences...", -background=>$bgcol,-underline=>0,
		-command=>sub {
      edit_ini_window("settings.ini", \%setting, \%setting_descr, "Piraña preferences",0)});
$mbar_file -> command(-label => "Software...", -background=>$bgcol,-underline=>5,
		-command=>sub {
      edit_ini_window("software.ini", \%software, \%software_descr, "Software integration",1);
    });

$mbar_file -> command(-label => "Exit", -underline=>0,-background=>$bgcol, 
		-command=>sub { quit(); } );

our $mbar_tools = $mbar -> cascade(-label =>"Tools", -background=>$bgcol,-underline=>0, -tearoff => 0);
  our $mbar_tools_NM = $mbar_tools -> cascade(-label =>"NONMEM", -background=>$bgcol,-underline=>1, -tearoff => 0);
  $mbar_tools_NM -> command(-label => "Manage installations", -background=>$bgcol,-underline=>1,
		-command=> sub { edit_sizes_window();
   });
  $mbar_tools_NM -> command(-label => "Install NM6 using NMQual", -background=>$bgcol,-underline=>1,
		-command=> sub { install_nonmem_nmq_window() });
  $mbar_tools_NM -> command(-label => "Install NM6 from CD", -background=>$bgcol,-underline=>0,
		-command=> sub { install_nonmem_window() });
  
if ($setting{use_psn}==1) {
  our $mbar_psn = $mbar_tools -> cascade (-label => "PsN", -background=>$bgcol, -underlin=>0, -tearoff => 0);  
  if (-e unix_path($software{psn_dir})."/psn.conf") {
    $mbar_psn -> command(-label => "Edit psn.conf (local)", -background=>$bgcol,-underline=>0,
		  -command=> sub {win_start ($software{editor}, win_path($software{psn_dir}."/psn.conf"));
    });
  }
    $mbar_psn -> command(-label => "Edit PsN default command parameters", -background=>$bgcol,-underline=>1,
		  -command=> sub {
		    edit_ini_window("psn.ini", \%psn_commands, \%psn_commands_descr, "PsN commands default parameters", 0);
    })
};
if ((-e unix_path($software{wfn_dir})."/bin/wfn.bat")&&($setting{use_wfn}==1)) {
  our $mbar_wfn = $mbar_tools -> cascade (-label => "WFN", -background=>$bgcol, -underlin=>0, -tearoff => 0);  
  $mbar_wfn -> command(-label => "Edit wfn.bat", -background=>$bgcol,-underline=>0,
		-command=> sub {win_start ($software{editor}, win_path($software{wfn_dir}."/bin/wfn.bat"));});
  $mbar_wfn -> command(-label => "Combine bootstrap results", -background=>$bgcol,-underline=>0,
		-command=> sub {combine_wfn_bootstraps()} );
};
  our $mbar_matrix = $mbar_tools -> cascade (-label => "Matrices", -background=>$bgcol, -underlin=>0, -tearoff => 0);  
  $mbar_matrix -> command(-label => "Extract all matrices from output", -background=>$bgcol,
		 -command=> sub {save_matrices();} );
  $mbar_matrix -> command(-label => "Plot correlation matrix (R)", -background=>$bgcol,
		  -command=> sub {plot_corr_matrix();} );

if (-d $software{r_dir}) {
  our $mbar_xpose = $mbar_tools -> cascade (-label => "Xpose", -background=>$bgcol, -underline=>0, -tearoff => 0);  
  $mbar_xpose -> command(-label => "xpose.VPC from npc_dir folder", -background=>$bgcol,-underline=>6,
		  -command=> sub {xpose_VPC_window();} );
};

our $mbar_tools_batch = $mbar_tools -> cascade(-label =>"Batch processing", -background=>$bgcol,-underline=>1, -tearoff => 0);
$mbar_tools_batch -> command(-label => "Create n duplicates of model(s)", -background=>$bgcol,-underline=>1,
		-command=> sub {  create_duplicates_window()}); 
$mbar_tools_batch -> command(-label => "Add code to models", -background=>$bgcol,-underline=>1,
		-command=> sub { add_code() }); 
$mbar_tools_batch -> command(-label => "Replace blocks", -background=>$bgcol,-underline=>1,
		-command=> sub { batch_replace_block() }); 
$mbar_tools_batch -> command(-label => "Random seeds in \$SIM", -background=>$bgcol,-underline=>1,
		-command=> sub { random_sim_block_window() }); 
if ($setting{use_scripts} == 1) { # beta functionality
  $mbar_tools -> command(-label => "Scripts", -background=>$bgcol,-underline=>1,
		-command=>sub {edit_scripts()});
}
my $mbar_tools_misc = $mbar_tools -> cascade(-label => "Misc", -background=>$bgcol,-underline=>0, -tearoff => 0);
$mbar_tools_misc -> command(-label => "Covariance calculator", -background=>$bgcol,-underline=>0,
		-command=>sub {cov_calc_window()});

our $mbar_view = $mbar -> cascade(-label =>"View", -background=>$bgcol,-underline=>0, -tearoff => 0);
if ($os =~ m/MSWin/i) {
  our $full_screen = 0;
  $mbar_view -> checkbutton (-variable=>\$full_screen, -label => "Full screen", -background=>$bgcol,-underline=>0, -command=>sub{
    my $scr_mode;
    if ($full_screen==1) {
       our $models_hlist_width = int((($mw->screenwidth)-252)/7.2);
       our $nrows = int((($mw->screenheight)-206)/14.2);
       my $height = ($mw->screenheight)-80;
       my $width = ($mw->screenwidth)-5;
       $mw -> geometry($width."x".$height."+0+0"); 
    } else {
       $mw->geometry("1024x560");
       center_window($mw);
       our $models_hlist_width = 106;
       our $nrows = 28;
       $mw -> resizable( 0, 0);
    }
    $models_hlist -> destroy();
    $tab_hlist -> destroy();
    frame_tab_show(1);
    frame_models_show(1);
    populate_models_hlist ($setting{models_view});
    populate_tab_hlist ();
  });
}

$mbar_view -> command (-label => "Execution log", -background=>$bgcol,-underline=>1,
	-command=>sub {
    show_exec_runs_window();
  });
if (($setting{use_cluster})&&($setting{cluster_type}==2)) {
  $mbar_view -> command(-label => "Cluster monitor", -background=>$bgcol,-underline=>1,
		-command=>sub {cluster_monitor()});
}
our $process_monitor = 0;
$mbar_view -> checkbutton (-label => "Console output", -variable=> \$process_monitor, -background=>$bgcol,-underline=>1,
	-command=>sub {
    show_process_monitor($process_monitor);
  });

our $mbar_help = $mbar -> cascade(-label =>"Help", -background=>$bgcol,-underline=>0, -tearoff => 0);
$mbar_help -> command(-label => "Piraña manual", -background=>$bgcol,-underline=>0,-command=>sub {system("start ".win_path($base_dir.'\Manual.pdf'))});
$mbar_help -> command(-label => "Piraña website", -background=>$bgcol,-underline=>0,-command=>sub {win_start($software{browser},"http://pirana.sf.net")});
my @nm = values(%nm_dirs);
our @nm_keys = keys(%nm_dirs);
unless (@nm_keys == 0) {
  $mbar_help -> command(-label => "NONMEM Help files", -background=>$bgcol,-underline=>0,-command=>sub {
    win_start($software{browser},unix_path($nm_dirs{@nm_keys[0]}."/html/index.htm")) } 
  );
}
$mbar_help -> command(-label => "NM UsersNet", -background=>$bgcol,-underline=>0,-command=>sub {win_start($software{browser},"http://www.cognigencorp.com/nonmem/sitesearch/index.html")});
$mbar_help -> command(-label => "Xpose", -background=>$bgcol,-underline=>0,-command=>sub {win_start($software{browser},"http://xpose.sourceforge.net")});
$mbar_help -> command(-label => "WFN", -background=>$bgcol,-underline=>0,-command=>sub {win_start($software{browser},"http://wfn.sourceforge.net")});
$mbar_help -> command(-label => "About Piraña", -background=>$bgcol,-underline=>0, -command=>sub {
$mw -> messageBox(-type=>'ok',	-message=>"Piraña (version ".$version.")\n   Created by Ron Keizer.\n   Department of Pharmacy & Pharmacology,\n   Slotervaart Hospital / The Netherlands Cancer Institute.\n\nAcknowledgments to the people in my modeling group for testing.\nValuable feedback was also provided by the Uppsala PM group,\nand several other modelers.\n\nhttp://pirana.sf.net\n"); });

#*** Main Loop ***********************************************************
$mw->update();
if ($init_message ne "") {message ($init_message)};
if ($os =~ m/MSWin/i) {
  $mw -> optionAdd('*BorderWidth' => 0);
  $mw-> resizable( 0, 0);
} else {
  $mw-> resizable( 1, 1);
  $mw -> update();
  $mw->geometry("1200x700"); #more space is needed in *nix due to the differences in Tk
}

renew_pirana();

MainLoop;
#***********************************************************************

