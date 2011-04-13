use strict;
use Cwd;
use File::Basename;
use File::Copy;
use pirana_modules::nm        qw(extract_name_from_nm_loc nm_smart_search create_output_summary_csv get_nm_help_text get_nm_help_keywords add_item convert_nm_table_file save_etas_as_csv read_etas_from_file replace_block replace_block change_seed get_estimates_from_lst extract_from_model extract_from_lst extract_th extract_cov blocks_from_estimates duplicate_model get_cov_mat output_results_HTML output_results_LaTeX interpret_pk_block_for_ode rh_convert_array extract_nm_block interpret_des translate_des_to_BM translate_des_to_R detect_nm_version);
use pirana_modules::misc      qw(unique rm_spaces text_to_file file_to_text block_size base_drive get_max_length_in_array find_R get_file_extension make_clean_dir generate_random_string lcase replace_string_in_file dir ascend log10 is_integer is_float bin_mode rnd one_dir_up win_path unix_path os_specific_path extract_file_name tab2csv csv2tab read_dirs_win read_dirs start_command );

if (@ARGV < 1) {
    print "\nCreate HTML-report from NONMEM outputfile \n(c) Ron Keizer, 2011\n\n";
    print "Usage:      perl lst2html.pl <nm_outputfile> \n";
    print "      e.g.  perl lst2html.pl run001.lst \n\n";
    die "Please specify outputfile from NONMEM run.\n";
};
my $lst = @ARGV[0]; 
unless (-e $lst) {
    die "Lst-file was not found, please check.\n";
}

my %setting;
my %include_html;
$include_html{basic_run_info} = 1;
$include_html{notes_and_comments} = 0;
$include_html{model_file} = 0;
$include_html{param_est_all} = 1;
my $cwd = fastgetcwd();
my $file = basename ($lst);
my $dir = dirname($lst);
chdir($dir);
output_results_HTML($file, \%setting, "", \%include_html);
my $html = "pirana_sum_".$file.".html";
if (-e $html) {
    move ($html, $file.".html");
    print "\n".$file.".html successfully created.\n(in ".$dir.")\n\n";
} else {
    print "File ".$file.".html could not be created. Check results file and write priviliges.\n";
}
chdir ($cwd);
