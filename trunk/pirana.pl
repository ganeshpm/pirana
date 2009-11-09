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
use Time::HiRes;
use HTTP::Date;             # Date and time functions
use List::Util qw(max maxstr min minstr reduce); # some basic functions
use POSIX qw(ceil floor);   # some basic functions
use DBI;                    # database connection to sqlite
use Math::BigFloat;         # used for rounding to significant digits

#*** Some parameter initalisation **********************************************
our $version = "2.2.0"; # version "Pipeline"
our $os      = $^O;
if ($os =~ m/MSWin/i) {
  require Win32::Process;
  Win32::SetChildShowWindow(0); # don't open new console windows
  require Win32::DriveInfo;     # needed for NM install
}
our $user = getlogin();

# delcare some global variables (keep to a minimum)
our $cwd      = cwd();
our $base_dir = cwd();
if ($os =~ m/MSWin/i) {
  our $home_dir = $ENV{HOME}."/Application Data/pirana";
} else {
  our $home_dir = $ENV{HOME}."/.pirana";
}
our %setting, our %setting_descr, our %nm_dirs, our %nm_vers;
our %software, our %software_descr; our $nm_reg_chosen; our $nm_reg_chosen;
our %project, our %project_dir, our %project_nr = (); our %scripts; our %scripts_descr;
our %clients, our %clients_descr; our $active_project; our %vars; our %psn_commands; our %psn_commands_descr; 
our $first_time_flag= 0;

#*** Read all Pirana modules ***************************************************
do ("./subs.pl");           
use pirana_modules::db        qw(db_get_project_info db_insert_project_info db_create_tables db_log_execution db_read_exec_runs db_read_model_info db_read_table_info db_insert_model_info db_insert_table_info delete_run_results db_add_note db_add_color db_read_all_model_data db_execute db_execute_multiple);
use pirana_modules::editor    qw(text_edit_window refresh_edit_window save_model);
use pirana_modules::model     qw(replace_block change_seed get_estimates_from_lst extract_from_model extract_from_lst extract_th extract_cov blocks_from_estimates duplicate_model get_cov_mat output_results_HTML output_results_LaTeX); 
use pirana_modules::pcluster  qw(generate_zink_file get_active_nodes);
use pirana_modules::misc      qw(generate_random_string lcase replace_string_in_file dir ascend log10 bin_mode rnd one_dir_up win_path unix_path os_specific_path extract_file_name tab2csv csv2tab center_window read_dirs_win start_command); 
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
our $nrows = 27;
our $models_hlist_width=112; 
our $help = $mw->Balloon();

#*** Load Icons (from http://sourceforge.net/projects/icon-collection **********
our $frame_dir = $mw -> Frame(-background=>$bgcol) -> grid(-row=>0,-column=>1, -columnspan=>10, -ipadx=>5,-ipady=>0,-sticky=>'nws', -rowspan=>2);
#$mw->geometry("1024x560");
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
create_menu_bar();

#*** Main Loop ***********************************************************
$mw -> optionAdd('*BorderWidth' => 1);
$mw -> resizable( 0, 0);
$mw -> update();

renew_pirana();
our $pirana_normal_width = $mw->width;
our $pirana_normal_height = $mw->height;

if ($first_time_flag==1) { # save to home folder
  $first_time_flag = 0;
  first_time_dialog($user);
}

MainLoop;
#***********************************************************************

