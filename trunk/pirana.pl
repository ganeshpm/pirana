#    ----------------------------------------------------------------------
#    Piraña
#    Copyright Ron Keizer, Coen van Hasselt, 2007-2011, Uppsala/Amsterdam
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

our $debug_mode = 0;
our $console = 0; # keep console window open on Windows
foreach (@ARGV) {
  if ($_ =~ m/debug/i) {
      $debug_mode = 1;
  }
  if ($_ =~ m/console/i) {
      $console = 1;
  }
}

sub pirana_debug {
  (my $debug_mode, my $text) = @_;
  if ($debug_mode == 1) {
    print $text."\n";
  }
}

pirana_debug ($debug_mode, "1. Loading basic modules.");
use strict;                 #
use Cwd qw (fastgetcwd cwd realpath); # Basic functions
pirana_debug ($debug_mode, "2. Loading Tk modules.");
use Tk;                     # Tk
use Tk::NoteBook;
use Tk::BrowseEntry;
use Tk::Balloon;            # Help balloon widget
use Tk::HList;              # HList widget
use Tk::ItemStyle;          # ..
use Tk::HdrResizeButton;    # Resizable headers in Tk::Hlist
use Tk::Text;               # Textarea widget
use Tk::PlotDataset;        # For DataInspector
use Tk::LineGraphDataset;   # ..
use Tk::PNG;
# use Tk::FontDialog;
pirana_debug ($debug_mode, "3. Loading other modules.");
use File::Copy;             # File info and operations
use File::Find;
use File::stat;             # ..
use File::Path;             # ..
use File::Basename;
use File::Spec;
use Time::HiRes;
use HTTP::Date;             # Date and time functions
use List::Util qw(max maxstr min minstr reduce); # some basic functions
use POSIX qw(ceil floor);   # some basic functions
use DBI;                    # database connection to sqlite
use Text::ParseWords;       # needed for wizards

#*** Some parameter initalisation **********************************************
our $version = "2.4.0b";
our $os      = $^O;
if ($os =~ m/MSWin/i) {
  pirana_debug ($debug_mode, "3b. Loading Windows-based modules.");
  require Win32::PerfLib;
  require Win32::Process;
  require Getopt::Std;
  use vars qw($opt_d);
  require Win32::Process;
  Win32::SetChildShowWindow(0); # don't open new console windows
  require Win32::DriveInfo;     # needed for NM install
  unless ($console == 1) {
      require Win32::GUI;
      my $hw = Win32::GUI::GetPerlWindow();
      Win32::GUI::Hide($hw);
  }
}

our $user = getlogin();

pirana_debug ($debug_mode, "4. Setting directories.");
#*** include pirana modules in INC
eval 'exec $PERLLOCATION/bin/perl -x $0;'
  if 0;
$| = 1;
use File::Basename;
our $base_dir;
our $home_dir;
our $portable_mode = 0;
our $use_scripts = 1;
our $cwd = fastgetcwd();
BEGIN{
   $base_dir = &File::Basename::dirname(realpath($0));
	push (@INC, $base_dir);
}

#*** Set $home directory
foreach (@ARGV) {
    if ($_ =~ m/port/) {
        $home_dir = $base_dir;
	mkdir ($base_dir."/ini");
	$portable_mode = 1;
    }
    if ($_ =~ m/noscript/) {
 	$use_scripts = 0;
    }
}
if ($portable_mode == 0) {
    if ($os =~ m/MSWin/i) {
	if ($ENV{USERPROFILE} eq "") {
	    our $home_dir = $base_dir;
	} else {
	    our $home_dir = $ENV{USERPROFILE}."/.pirana";
	}
    } else { # Linux
	our $home_dir = $ENV{HOME}."/.pirana";
    }
}

our %setting, our %setting_descr, our %nm_dirs, our %nm_vers;
our %software, our %software_descr; our $nm_reg_chosen; our $nm_reg_chosen;
our %project, our %project_dir, our %project_nr = (); our %scripts; our %scripts_descr;
our %clients, our %clients_descr; our $active_project; our %vars; our %psn_commands; our %psn_commands_descr;
our $first_time_flag= 0; our $condensed_model_list = 1;

#*** Read all Pirana modules ***************************************************
pirana_debug ($debug_mode, "5. Loading pirana modules");

do ($base_dir."/internal/subs.pl");
do ($base_dir."/internal/subs_custom.pl"); # Custom subroutines
our $base_drive     = base_drive ($base_dir);
use pirana_modules::db        qw(check_db_file_correct db_rename_model db_get_project_info db_insert_project_info db_create_tables db_log_execution db_read_exec_runs db_read_model_info db_read_table_info db_insert_model_info db_remove_model_info db_insert_table_info db_remove_table_info delete_run_results db_add_note db_add_color db_read_all_model_data db_execute db_execute_multiple);
use pirana_modules::editor    qw(text_edit_window text_edit_window_build refresh_edit_window save_model);
use pirana_modules::nm        qw(extract_om_mod get_current_ext extract_name_from_nm_loc nm_smart_search create_output_summary_csv get_nm_help_text get_nm_help_keywords add_item convert_nm_table_file save_etas_as_csv read_etas_from_file replace_block replace_block change_seed get_estimates_from_lst extract_from_model extract_from_lst extract_th extract_cov blocks_from_estimates duplicate_model get_cov_mat output_results_HTML output_results_LaTeX interpret_pk_block_for_ode rh_convert_array extract_nm_block interpret_des translate_des_to_BM translate_des_to_R detect_nm_version);
use pirana_modules::sge       qw(ssh_get_pre_post sge_get_job_cwd stop_job qstat_get_nodes_info qstat_process_nodes_info qstat_get_jobs_info qstat_process_jobs_info qstat_get_specific_job_info);
use pirana_modules::pcluster  qw(generate_zink_file get_active_nodes);
use pirana_modules::misc      qw(hash_print sort_model_files get_nmfe_number get_highest_file_number get_R_gui_command filter_array sort_table count_numeric om_block_structure unique rm_spaces text_to_file file_to_text block_size base_drive get_max_length_in_array find_R get_file_extension make_clean_dir generate_random_string lcase replace_string_in_file dir ascend log10 is_integer is_float bin_mode rnd one_dir_up win_path unix_path os_specific_path extract_file_name tab2csv csv2tab read_dirs_win read_dirs start_command );
use pirana_modules::misc_tk   qw(no_resize text_window message_yesno center_window);
use pirana_modules::PsN       qw(get_psn_info get_psn_help get_psn_nm_versions);
use pirana_modules::data_inspector qw(create_plot_window read_table);
use pirana_modules::wizards   qw(clean_string get_key wizard_read_pwiz_file wizard_write_output parse_lines);
if ($^O =~ m/MSWin32/) {
  require pirana_modules::windows_specific ; #qw(nonmem_priority get_processes);
}

#*** Initialization ************************************************************
pirana_debug ($debug_mode, "6. Initializing Pirana");

read_log();    # read last settings for Project / NONMEM
initialize();  # read ini-files: preferences, software, nm-installations etc.

pirana_debug ($debug_mode, "7. Setting variables");
#*** Windows & Colors **********************************************************
our $blue           = "#D0F0FF";
our $pirana_orange  = "#ffEE99";
our $lightestblue   = "#d3d3e3";
our $lighterblue    = "#aacaef";
our $lightblue      = "#4060D0";
our $darkblue2      = "#7190c9";
our $darkblue       = "#4271c9";
our $lightred       = "#efC9a4";
our $darkred        = "#efb894";
our $darkerred      = "#BE5040";
our $yellow         = "#e3e3e6";
our $lightyellow    = "#ffffc0";
our $darkyellow     = "#f0f0b0";
our $lightgreen     = "#c0dfc0";
our $darkgreen      = "#a5d3a5";
our $white          = "#ffffff";
#our $bgcol          = "#efebe7";
our $bgcol          = "#ededed";
our $button         = "#dad7d3";
our $abutton        = "#c6c3c0";
our $status_col     = "#fffdec";
our $bbw            = 0; # button border width;
our $dir_bgcol      = "#e3e8f0";
our $entry_color    = $white;
our $tab_hlist_color = "#f6f6f6";
our $grey           = "#777777";
if ($^O =~ m/MSWin/i) {
    our $selectcol = $white;
} else {
    our $selectcol = $darkerred;
};
our $hlist_pady     = 1;
our $filter         = "";

#*** Some other variables *****************************************************
our $full_screen = 0;
our $show_tab_list = 1;
our $show_model_info = 1;
our $process_monitor = 0;
our $show_console = 1;
$setting{frame2_vis} = 1;

#*** Main Window ***************************************************************
pirana_debug ($debug_mode, "8. Building Pirana main window.");

our $mw = MainWindow -> new (-title => "Pirana", -background=>$bgcol);
$mw -> setPalette ($bgcol);
#our $font = $mw -> fontCreate('main_normal', -family=>'Helvetica', -size=>int(-11));

our $font_family = "Verdana";
if ($^O =~ m/Linux/i) {
    $font_family = "Helvetica";
}; 
our $font_fixed_family = "Courier";
if ($^O =~ m/Darwin/i) {
    $font_family = "Helvetica"; # a little bit more dense than Verdana
    $font_fixed_family = "System";
}; 
# Font face can always be overriden by user from settings
if (length($setting{font_face}) >= 4) { # quick 'n dirty check if it is a valid font name
    $font_family = $setting{font_face};  
}
if ($setting{font_size} < 5) { # probably setting from old version of Pirana
    $setting{font_size} = 10 ;
} 
my $font_small_size = ($setting{font_size} - 1);
our $font = $font_family.' '.$setting{font_size};
our $font_normal =  $font_family.' '.$setting{font_size};
our $font_small =  $font_family.' '.$font_small_size;
our $font_fixed = $font_fixed_family.' '.$setting{font_size};
our $font_fixed_small = $font_fixed_family.' '.$font_small_size;
our $font_bold =  $font_family.' '.$setting{font_size}.' bold';

# I don't know why this is necessary, but the following line prevents X-window tunneling from minimizing the window...
$mw -> Label (-text=> "                                                       ", -background=>$bgcol) -> grid (-row=>2, -column=>1,-columnspan=>2);

our $nrows = 30;
if ($setting{n_rows} > 30) {
  our $nrows = 30;
}
our $models_hlist_width=112;
our $help = $mw->Balloon();

#*** Load Icons (from http://sourceforge.net/projects/icon-collection **********
pirana_debug ($debug_mode, "9. Loading icons to memory.");
our $frame_dir = $mw -> Frame(-background=>$bgcol) -> grid(-row=>1,-column=>1, -rowspan=>2, -columnspan=>2, -ipadx=>5,-ipady=>0,-sticky=>'nws');
chdir ($base_dir."/images");
my @images = <*.gif>;
chdir ($cwd);
our %gif; our %gif_file;
foreach my $file (@images) {
  my $name = $file;
  $name =~ s/\.gif//i;
  $gif_file{$name} = $file;
  $gif{$name} = $frame_dir -> Photo ( -file => $base_dir."/images/".$file );
}

if ($^O =~ m/MSWin/) {
    our  $icon = $mw -> Photo (-file=>$base_dir.'/images/pirana_blue.png', -format=>'PNG', -width => 32, -height => 32);
    $mw -> Icon (-image=> $icon);
} else {
    our  $icon = $mw -> Photo (-file=>$base_dir.'/images/pirana_blue.png', -format=>'PNG', -width => 32, -height => 32);
}

#*** Menu bar ******************************************************************
pirana_debug ($debug_mode, "10. Building menu bar.");
our $mbar;
do ($base_dir."/internal/menus.pl");
do ($base_dir."/internal/menus_custom.pl");
our $mbar = create_menu_bar();
menu_bar_add_custom ($mbar); # allow developers to easily add menu items (located in internal/menu_custom.pl)

#*** Main Loop ***********************************************************
$mw -> optionAdd('*BorderWidth' => 1);
$mw -> update();

pirana_debug ($debug_mode, "11. Renewing Pirana interface.");
renew_pirana();

our $pirana_normal_width = $mw  -> width;
our $pirana_normal_height = $mw -> height;

if ($first_time_flag==1) { # save to home folder
  $first_time_flag = 0;
  first_time_dialog($user);
}

#$mw -> resizable( 0, 0);
$mw -> raise;

pirana_debug ($debug_mode, "12. Preparing Pirana for use.");
MainLoop; # Tk: start main window process
pirana_debug ($debug_mode, "\nPirana closed.");


#***********************************************************************

