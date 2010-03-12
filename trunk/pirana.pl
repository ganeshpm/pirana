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
use Cwd qw (fastgetcwd cwd realpath); # Basic functions
use Tk;                     # Tk
use Tk::Balloon;            # Help balloon widget
use Tk::HList;              # HList widget
use Tk::ItemStyle;          # ..
use Tk::HdrResizeButton;    # Resizable headers in Tk::Hlist
use Tk::Text;               # Textarea widget
use Tk::PlotDataset;        # For DataInspector
use Tk::LineGraphDataset;   # ..
use Tk::PNG;
use File::Copy;             # File info and operations
use File::stat;             # ..
use File::Path;             # ..
use Time::HiRes;
use HTTP::Date;             # Date and time functions
use List::Util qw(max maxstr min minstr reduce); # some basic functions
use POSIX qw(ceil floor);   # some basic functions
use DBI;                    # database connection to sqlite

#*** Some parameter initalisation **********************************************
our $version = "2.3.0b";     # version "Oahu"
our $os      = $^O;
if ($os =~ m/MSWin/i) {
  require Win32::PerfLib;
  require Win32::Process;
  require Getopt::Std;
  use vars qw($opt_d);
  require Win32::Process;
  Win32::SetChildShowWindow(0); # don't open new console windows
  require Win32::DriveInfo;     # needed for NM install
}
our $user = getlogin();

#*** include pirana modules in INC
eval 'exec $PERLLOCATION/bin/perl -x $0;'
  if 0;
$| = 1;
use File::Basename;
our $base_dir;
our $cwd = fastgetcwd();
BEGIN{
   $base_dir = &File::Basename::dirname(realpath($0));
	push (@INC, $base_dir);
}

#*** Set $home directory
if ($os =~ m/MSWin/i) {
  if ($ENV{APPDATA} eq "") {
    our $home_dir = $base_dir;
  } else {
    our $home_dir = $ENV{APPDATA}."/pirana";
  }
} else {
  our $home_dir = $ENV{HOME}."/.pirana";
}
our %setting, our %setting_descr, our %nm_dirs, our %nm_vers;
our %software, our %software_descr; our $nm_reg_chosen; our $nm_reg_chosen;
our %project, our %project_dir, our %project_nr = (); our %scripts; our %scripts_descr;
our %clients, our %clients_descr; our $active_project; our %vars; our %psn_commands; our %psn_commands_descr;
our $first_time_flag= 0; our $condensed_model_list = 1;

#*** Read all Pirana modules ***************************************************
do ($base_dir."/subs.pl");
use pirana_modules::db        qw(check_db_file_correct db_rename_model db_get_project_info db_insert_project_info db_create_tables db_log_execution db_read_exec_runs db_read_model_info db_read_table_info db_insert_model_info db_insert_table_info delete_run_results db_add_note db_add_color db_read_all_model_data db_execute db_execute_multiple);
use pirana_modules::editor    qw(text_edit_window refresh_edit_window save_model);
use pirana_modules::nm        qw(add_item convert_nm_table_file save_etas_as_csv read_etas_from_file replace_block replace_block change_seed get_estimates_from_lst extract_from_model extract_from_lst extract_th extract_cov blocks_from_estimates duplicate_model get_cov_mat output_results_HTML output_results_LaTeX);
use pirana_modules::pcluster  qw(generate_zink_file get_active_nodes);
use pirana_modules::misc      qw(get_file_extension make_clean_dir generate_random_string lcase replace_string_in_file dir ascend log10 bin_mode rnd one_dir_up win_path unix_path os_specific_path extract_file_name tab2csv csv2tab center_window read_dirs_win read_dirs start_command);
use pirana_modules::PsN       qw(get_psn_info get_psn_help get_psn_nm_versions);
use pirana_modules::data_inspector qw(create_plot_window read_table);
if ($^O =~ m/MSWin32/) {
  require pirana_modules::windows_specific ; #qw(nonmem_priority get_processes);
}

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
if ($^O =~ m/MSWin/i) {
    our $selectcol = $white;
} else {
    our $selectcol = $darkerred;
};
our $filter         = "";

#*** Main Window ***************************************************************
our $bgcol      = "#ece9d8";
our $button     = "#dddac9";
our $abutton    = "#cecbba";
our $status_col = "#fffdec";
our $mw = MainWindow -> new (-title => "Pirana", -background=>$bgcol);
$mw -> setPalette ($bgcol);

# I don't know why this is necessary, but the following line prevents X-window tunneling from minimizing the window...
$mw -> Label (-text=> "                                                       ", -background=>$bgcol) -> grid (-row=>2, -column=>1,-columnspan=>2);

our $nrows = 24;
if ($setting{n_rows} > 24) {
  our $nrows = 24;
}
our $models_hlist_width=112;
our $help = $mw->Balloon();

#*** Load Icons (from http://sourceforge.net/projects/icon-collection **********
our $frame_dir = $mw -> Frame(-background=>$bgcol) -> grid(-row=>0,-column=>1, -columnspan=>10, -ipadx=>5,-ipady=>0,-sticky=>'nws', -rowspan=>2);
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
    my  $icon = $mw -> Photo (-file=>$base_dir.'/images/pirana_blue.png', -format=>'PNG', -width => 32, -height => 32);
    $mw -> Icon (-image=> $icon);
} else {
    my  $icon = $mw -> Photo (-file=>$base_dir.'/images/pirana_blue.png', -format=>'PNG', -width => 32, -height => 32);
}

#*** Menu bar ******************************************************************
create_menu_bar();

#*** Main Loop ***********************************************************
$mw -> optionAdd('*BorderWidth' => 1);
$mw -> update();

renew_pirana();
our $pirana_normal_width = $mw->width;
our $pirana_normal_height = $mw->height;

if ($first_time_flag==1) { # save to home folder
  $first_time_flag = 0;
  first_time_dialog($user);
}
$mw -> resizable( 0, 0);
$mw -> raise;
MainLoop;
#***********************************************************************

