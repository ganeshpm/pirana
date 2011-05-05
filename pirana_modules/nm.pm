# Subroutines that perform actions on NM modelfiles or NM results files, or anything related to NONMEM

package pirana_modules::nm;

use strict;
require Exporter;
use Cwd;
# use File::Basename;
use File::stat;
use Time::localtime;
use pirana_modules::misc qw(unique count_numeric om_block_structure time_format rm_spaces block_size generate_random_string get_max_length_in_array lcase replace_string_in_file dir ascend log10 is_float is_integer bin_mode rnd one_dir_up win_path unix_path extract_file_name tab2csv csv2tab read_dirs_win win_start);
use pirana_modules::misc_tk qw{text_window};

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(get_current_ext extract_name_from_nm_loc nm_smart_search create_output_summary_csv get_nm_help_text get_nm_help_keywords add_item convert_nm_table_file save_etas_as_csv read_etas_from_file replace_block change_seed get_estimates_from_lst extract_from_model extract_from_lst extract_th extract_cov blocks_from_estimates duplicate_model get_cov_mat output_results_HTML output_results_LaTeX interpret_pk_block_for_ode rh_convert_array extract_nm_block interpret_des translate_des_to_BM translate_des_to_R detect_nm_version);
our @collect_nm;

sub get_current_ext {
### Purpose : Get the name of the .ext file that has the same date-time stamp as the OUTPUT file
### Compat  : W+L+
    my $dir = shift;
    my @dir = dir ($dir, '.ext');     
    my $ext_file;
    if (-e $dir."/psn.ext") {
	$ext_file = "psn.ext"; # don't look any further
    } else { # assume the most recent ext-file
	my $t_max;
	foreach my $ext (@dir) {
	    my $t = stat($dir."/".$ext) -> mtime;
	    if ($t > $t_max) {
		$ext_file = $ext;
	    }
	}
    }
    return(unix_path($dir."/".$ext_file));
}

sub extract_name_from_nm_loc {
    my $loc = shift;
    my ($part1, $rest) = split ("\/util\/", unix_path ($loc));
    my @spl = split ("\/", $part1);
    return (@spl[(@spl-1)]);
}

sub nm_smart_search {
# Do a smart search for NONMEM installations on a system
    our @collect_nm;
    my @loc_dir;
    my @dirs;
    if ($^O =~ m/MSWin/) {
	@dirs = ("C:/Program Files", "C:/");
	# if in portable mode from USB stick, add stick location as well
	my $base_dir = File::Spec -> rel2abs($0);
	unless (substr($base_dir,0,2) =~ m/C\:/i) {
	    push (@dirs, substr($base_dir,0,2)."/");
	}
    } else {
	@dirs = ("/opt", "/usr", $ENV{HOME});
    }

    #1. In the allocated locations, find subfolders that start with nm or nonmem
    my @loc = ("nm", "nonmem", "mod", "NONMEM");
    foreach my $main_dir (@dirs) {
	my $loc_ref = find_nm_possibles ($main_dir, \@loc);
	push (@loc_dir, @$loc_ref);
    }

    #2. within the located folders, look if a nmfex file or nmfex.bat can be found
    my @nm_found;
    foreach my $loc (@loc_dir) {
	File::Find::find ( \&wanted, $loc);
	foreach (@collect_nm) { 
	    if (unix_path($_) =~ m/\/util\//i) {
		push (@nm_found, one_dir_up(one_dir_up($_)));
	    }
	}
    }
    @nm_found = sort (ascend @nm_found);
    my $nm_found_ref = unique (\@nm_found);
    return ($nm_found_ref);
}

sub wanted {
#    /^nmfe.?\z/s 
    /^nmfe*/s 
    && push(@collect_nm, $File::Find::name);
}

sub find_nm_possibles {
### Purpose : Find folders in a given folder which start with nm or nonmem
### Compat  : W+L+
    my ($main_dir, $loc_ref) = @_;
    my @dir = <$main_dir/*>;
    my @loc_dir;   
    my @loc = @$loc_ref;
    foreach my $f (@dir) {
	if (-d $f) {
	    my $added = 0;
	    foreach (@loc) {
		if (($f =~ m/$_/i)&&($added == 0)) { 
		    push (@loc_dir, $f); 
		    $added = 1 
		};
	    }
	}
    }
    return (\@loc_dir);
}

sub create_output_summary_csv {
### Purpose : Loop over all NM results files, and put the resutls in a csv file
### Compat  : W+L?
  my ($output, $setting_ref, $models_notes_ref, $models_descr_ref, $mw) = @_;
  my %setting = %$setting_ref;
  my %models_notes = %$models_notes_ref;
  my %models_descr = %$models_descr_ref;
  my @dir = <*.$setting{ext_res}>;
  if (@dir>0) {
    open (CSV, ">pirana_run_summary.csv");
    my @headers = join (",","Model.no", "Description","Method", "OFV", "Termination.text",
			"Boundaries", "Cov.step.successful?",
			"OM.shrink%", "SI.shrink%",
			"Est.time","Cov.time",
			"Model.created","Results.created","Notes");
    print CSV @headers;
    print CSV "\n";
    my $failed = "";
#    my $text_console = text_window($mw, "", "Create csv-summary of results in current folder", "");
    foreach my $file (@dir) {
        my $model = $file;
        $model =~ s/.$setting{ext_res}//i;
        $models_notes{$model} =~ s/\n/\./g;
        $models_notes{$model} =~ s/,/;/g;
        $models_descr{$model} =~ s/,/;/g;
	my $model_file = $model.".".$setting{ext_ctl};

        my $model_date;
	if (-e $model_file) {
	    my $mtime = stat($model_file) -> mtime;
	    my @time = @{localtime($mtime)};
	    $model_date = sprintf ("%4d-%02d-%02d %02d:%02d:%02d", @time[5]+1900,@time[4]+1,@time[3],@time[2],@time[1],@time[0]);
	}
	my $res_date;
	if (-e $file) {
	    my $mtime = stat($file) -> mtime;
	    my @time = @{localtime($mtime)};
	    $res_date = sprintf ("%4d-%02d-%02d %02d:%02d:%02d", @time[5]+1900,@time[4]+1,@time[3],@time[2],@time[1],@time[0]);
	}

        # Read data from files
	my $mod_ref = extract_from_model ($model.".".$setting{ext_ctl}, $model, "all");
	my %mod = %$mod_ref;
	my ($methods_ref, $est_ref, $se_est_ref, $term_ref, $ofvs_ref, $cov_ref, $times_ref, $bnd_ref) = get_estimates_from_lst ($file);
	my @methods  = @$methods_ref;
	my %est      = %$est_ref;
	my %se_est   = %$se_est_ref;
	my %term_res = %$term_ref;
	my %ofvs     = %$ofvs_ref;
	my %cov_mat  = %$cov_ref;
	my %times    = %$times_ref;
	my %bnd      = %$bnd_ref;
	my $meth_descr;
	foreach my $meth (@methods) {
	    if ($meth eq "NA") {
		$meth_descr = $mod{method}  # NM 6, take method from
	    } else {
		$meth_descr = $meth;
	    }
	    $meth_descr = small_method_name ($meth);
	    my @term;
	    if ($term_res{$meth} =~ m/ARRAY/) {
		@term = @{$term_res{$meth}};
	    };
	    my $term_text = " ";
	    if (@term[5] =~ m/SCALAR/) {
		$term_text = ${@term[5]};
		$term_text =~ s/[\r\n,\n,\,]/ /gi;
	    }
	    my $om_shrinkage = "";
	    if (@term[3] =~ m/ARRAY/) {
		$om_shrinkage = join("  ", @{@term[3]});
	    }
	    my $si_shrinkage = "";
	    if (@term[4] =~ m/ARRAY/) {
		$si_shrinkage = join("  ", @{@term[4]});
	    }
	    my $time_est = @{$times{$meth}}[0];
	    my $time_cov = @{$times{$meth}}[1];
	    if ($bnd{$meth} eq "") {$bnd{$meth} = "-"}
	    if ($cov_mat{$meth} eq "") {$cov_mat{$meth} = "-"}
	    $models_descr{$model} =~ s/[\r\n,\n]//g;
	    my @res_lst = ('="'.$model.'"', $models_descr{$model}, $meth_descr, $ofvs{$meth}, $term_text,
			   $bnd{$meth}, $cov_mat{$meth},
			   $om_shrinkage, $si_shrinkage,
			   $time_est, $time_cov,
			   $model_date, $res_date, $models_notes{$model});
#	    $text_console -> insert("end", "Reading results for model ".$model."...\n");
	    print CSV join (",", @res_lst);
	    print CSV "\n";
	}
    }
    close (CSV);
  }
}

# sub get_nm_help_text_old {
#     my ($nm, $keyword) = @_;
#     open (HELP, "<".$nm."/html/".$keyword.".htm");
#     my @lines = <HELP>;
#     close (HELP);
#     my @lines2;
#     foreach my $line (@lines) {
# 	unless( $line =~ m/(\<HTML|\<BODY|\<PRE|\<\/BODY|\<I\>|\<\/I>|\<HR)/i  ) {
# 	    push(@lines2, $line);
# 	}
#     }
#     my $text = join ("",@lines2);
#     return ($text);
# }

sub get_nm_help_text {
    my ($db_name, $keyword) = @_; 
    my $dbargs = {AutoCommit => 0, PrintError => 1};
    my $db = DBI->connect("dbi:SQLite:dbname=".$db_name,"","",$dbargs);
    my $all = $db -> selectall_arrayref("SELECT nm_help FROM nm_help WHERE nm_key = '".$keyword."'");
    my $row0 = @{$all}[0];
    my $text = @{$row0}[0];
    return (\$text);
}

# sub get_nm_help_keywords_old {
#     my $nm_help_dir = @_[0];
#     my $cwd = fastgetcwd();
#     chdir ($nm_help_dir);
#     my $cwd = fastgetcwd();
#     my @help_files = <*.htm>;
#     my $i = 0;
#     my @help_files2 ;
#     foreach my $file (@help_files) {
# 	$file =~ s/\.htm//i;
# 	unless (length($file) == 1) { # remove the alfabet letters
# 	    push (@help_files2, $file);
# 	}
#     }
#     chdir ($cwd);
#     return (\@help_files2)
# }

sub get_nm_help_keywords {
    my $db_name = shift; 
    my $all;
    if (-s $db_name > 500000) {
	my $dbargs = {AutoCommit => 0, PrintError => 1};
	my $db = DBI-> connect("dbi:SQLite:dbname=".$db_name,"","",$dbargs);
	if ($db -> err()) { 
	    print "Error connecting to NM help files database: $DBI::errstr\n";
	    return(0);
	} else {
	    $all = $db -> selectall_arrayref("SELECT nm_key FROM nm_help");
	}
	return ($all);
    } else {
	return(0);
    }
}

sub convert_nm_table_file {
# Purpose: Convert covariance / correlation tables as exported by NM7 to csv files
    my $table_file = shift;
    open (TAB, "<".$table_file);
    my @lines = <TAB>;
    close (TAB);
    my $est_method = "";
    my $row = 0;
    foreach my $line (@lines) {
	if ($line =~ m/TABLE/) {
	    unless ($est_method eq "") {
		close (CSV);
	    }
	    open (CSV, ">pirana_temp/".$table_file.".".$est_method.".csv");
	    $row = 0;
	} else {
	    my @dat = extract_nm_line_numeric ($line, 0);
	    for (my $i=0; $i<@dat; $i++) {
		if (($i > 0)&($row>0)) {@dat[$i] = @dat[$i]*1}
	    }
	    print CSV join(",", @dat)."\n";
	    $row++;
	}
    }
    close (CSV);
}

sub save_etas_as_csv {
# Purpose: convert a file containting eta's for all individuals to a csv file
    my ($eta_file, $eta_file_csv) = @_;
    my ($ids_ref, $eta_results) = read_etas_from_file ($eta_file);
    my %etas = %$eta_results;
    my @ids  = @$ids_ref;
    open (ETACSV, ">".$eta_file_csv);
    print ETACSV "id";
    my $et = $etas{(keys(%etas))[0]};
    for (my $i = 0; $i < (int(@$et)); $i++) {
	print ETACSV ",eta.".($i+1);
    }
    print ETACSV "\n";
    foreach my $id (@ids) {
	my $et = $etas{$id};
	my @eta_vals = @$et;
	print ETACSV $id.",";
	print ETACSV join(",",@eta_vals);
	print ETACSV "\n";
    }
    close (ETACSV);
    return (1);
}

sub read_etas_from_file {
# Purpose: Extract etas from NM7 output file and return as hash
    my $eta_file = shift;
    open (ETA, "<".$eta_file);
    my @lines = <ETA>;
    close (ETA);
    shift (@lines); # remove first line
    my $header_line = shift (@lines);

    # get location of ETAs
    my @matches = ( $header_line =~ m{ETA}g );
    my $n_eta = int(@matches); # start offsets of matched ETA columns

    my %etas ; #hash of referenced tables
    my @ids  ; #array of individuals
    # loop over lines
    foreach my $line (@lines) {
	my @dat = extract_nm_line_numeric ($line, 1) ;
        my $id = shift (@dat);
	$etas{$id} = \@dat;
	push (@ids, $id);
    }
    return (\@ids, \%etas);
}

sub extract_nm_line_numeric {
    my ($line, $convert_notation) = shift;
    my $n_elem = int ((length ($line) / 13)+0.5) ;
    my @dat;
    for (my $i = 0; $i < $n_elem; $i++ ) {
	my $elem = substr ($line, ($i*13), 13) ;
	$elem =~ s/\s//g;
	$elem =~ s/,/\./g;
        if ($convert_notation eq "1") {
	    $elem = $elem * 1; # make numeric if numeric
	}
	push (@dat, $elem);
    }
    return (@dat);
}

sub change_seed {
### Purpose : Change the seed in SIM to a random number (invoke random_sim_block)
### Compat  : W+L+
  my $mod = shift;
  open (RMOD, "<".$mod);
  my @lines = <RMOD>;
  close RMOD;
  foreach (@lines) {
    if (substr($_,0,4) =~ m/\$SIM/) {
      $_ = random_sim_block ($_);
    }
  }
  open (WMOD, ">".$mod);
  print WMOD @lines;
  close WMOD;
}

sub replace_block {
  my ($batch_ref, $block, $replace_with) = @_;
  my @batch = @$batch_ref;

  my $no_changed = 0;
  foreach my $mod (@batch) {
    open (MOD, "<".$mod);
    my @lines = <MOD>;
    close MOD;
    open (WMOD, ">".$mod);
    my $bl_flag = 0;
    foreach my $line (@lines) {
      if ((substr($line,0,1) eq "\$")&&(substr($line,0,length($block)) ne $block)) {$bl_flag = 0;}
      if ((substr($line,0,length($block)) eq $block)&&($bl_flag==0)) {
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
  return ($no_changed);
}

sub random_sim_block {
### Purpose : Create a random seed in $SIM
### Compat  : W+L+
  my $sim_string = shift;
  my $seed1 = ""; my $seed2 = "";
  my $seed1_text = ""; my $seed2_text = "";
  if($sim_string =~ s/\((.*?)\)/SEED1/) { # scan for seed 1
    $seed1_text = get_seed_text($1);
	  $seed1 = int(rand (100000));
    if($sim_string =~ s/\((.*?)\)/SEED2/) { # scan for seed 2
      $seed2_text = get_seed_text ($1);
      $seed2 = int(rand (100000));
    }
  }
  if ($seed1) { $sim_string =~ s/SEED1/\($seed1$seed1_text\)/; }
  if ($seed2) { $sim_string =~ s/SEED2/\($seed2$seed2_text\)/; }
  return($sim_string);
}

sub get_seed_text {
### Purpose : Get info on what $SIM options are specified
### Compat  : W+L+
  my $seed = shift; my $seed_text = "";
  if ($seed =~ m/UNI/gi) {$seed_text  .= " UNIFORM" }
  if ($seed =~ m/NEW/gi) {$seed_text  .= " NEW" }
	if ($seed =~ m/NORM/gi) {$seed_text .= " NORMAL" }
	if ($seed =~ m/NONP/gi) {$seed_text .= " NONPARAMETRIC" }
  return ($seed_text);
}

sub check_nm_version_from_lst {
# Purpose: check if a file is a NM7 or NM6- output file
    my $output_file = shift;
    open (LST, "<".$output_file);
    my @lines = <LST>;
    close (LST);
    my $line;
    my $i = 0;
    my $version = 0;
    do {
	$line = @lines[$i];
	$i++;
    } until (($line =~ m/1NONLINEAR MIXED EFFECTS MODEL PROGRAM/)||($i>=@lines));
    if ($i < @lines) { # NONMEM declaration found, now check version
	if ($line =~ m/VERSION V /) {
	    $version = 5
        }
	if ($line =~ m/VERSION VI /) {
	    $version = 6
        }
	if ($line =~ m/VERSION VII/) {
	    $version = 7
        }
    }
    return ($version);
}

sub clean_estim_method {
    my $est_method = shift;
    $est_method =~ s/\#METH\://g;
    $est_method =~ s/^\s+//; #remove leading spaces
    $est_method =~ s/\s+$//; #remove trailing spaces
    return($est_method);
}

sub get_estimates_from_lst {
### Purpose : Get parameter estimates from NM output file
### Compat  : W+L+
  my $file = shift;
  open (LST, "<".$file);
  my @lst = <LST>;
  close (LST);
  my $l_prev = ""; my $est_method = "NA";
  my @text; my $i=0;
  my $est_area = 0; my $se_area = 0; my $term_area = 0; my $gradient_area;
  my $eigen_area; my $e = 0; my @eig; my %cond_nr;
  my @term_text; my @est_text; my %ofvs;
  my %estimates; my %se_estimates;
  my %term_res; # results from #TERM section
  my @methods;
  my %cov_mat;
  my %est_times;
  my @times;
  my %bnd; $i=0;
  my $nm6 = 1; # Assume NM6
  my $count_est_methods = 1;
  my %grad_zero;
  my $est_method = "#1 First Order"; # assume first order (For NM5/6, if FO, this is not mentioned in the output file!)
  foreach my $line (@lst) {
      if ($line =~ m/NONLINEAR MIXED EFFECTS MODEL PROGRAM \(NONMEM\) VERSION 7/) {
	  $nm6 = 0; #nm version 5 or 6 assumed
      } 
      # Determine estimation method
      if ($line =~ m/\#METH\:/) {
	  $est_method = "#".$count_est_methods." ".clean_estim_method($line);
	  $cov_mat{$est_method} = "N";
	  $bnd{$est_method} = "N";
	  $count_est_methods++;
      }
      if (($nm6 == 1)&&($line =~ m/CONDITIONAL ESTIMATES USED/)&&($line=~m/YES/)) { $est_method = "#".$count_est_methods." First Order Conditional Estimation"; $count_est_methods++; }
      if (($nm6 == 1)&&($line =~ m/LAPLACIAN OBJ. FUNC./)&&($line=~m/YES/)) { $est_method = "#".$count_est_methods." Laplacian Conditional Estimation"; $count_est_methods++; }
      if (($nm6 == 1)&&($line =~ m/EPS-ETA INTERACTION/)&&($line=~m/YES/)) { $est_method .= "#".$count_est_methods." With Interaction"; $count_est_methods++;}

      if (($line =~ m/0MINIMIZATION SUCCESSFUL/)||($line =~ m/0MINIMIZATION TERMINATED/)) { #NM6
	  $term_area = 1;
	  $line =~ s/0//;
      }
      if ($line =~ m/\#TERM\:/) {
	  $term_area = 1;
      }
      if (($line =~ m/MINIMUM VALUE OF OBJECTIVE FUNCTION/)||($line =~ m/AVERAGE VALUE OF LIKELIHOOD FUNCTION/)||($line =~ m/FINAL VALUE OF OBJECTIVE FUNCTION/)||($line=~m/FINAL VALUE OF LIKELIHOOD FUNCTION/)) {
        my $ofv = @lst[$i+9];
	$ofv =~ s/#OBJV://g;
	$ofv =~ s/\*//g;
	$ofv =~ s/\s//g;
	$ofvs {$est_method} = $ofv;
      }
      if ($line =~ m/FINAL PARAMETER ESTIMATE/) {
	  $est_area = 1;
      }
      if ($line =~ m/STANDARD ERROR OF ESTIMATE/) {
	  $se_area = 1;
      }
      if (($est_area + $se_area) > 0) {
	  push (@est_text, $line);
      }
      if ($term_area == 1) {
	  push (@term_text, $line);
      }
      if (($line =~ m/COVARIANCE MATRIX OF ESTIMATE/)&&!($line =~ m/INVERSE/)) {
	  $cov_mat{$est_method} = "Y";
      }
      if ($line =~ m/Elapsed estimation time in seconds:/) {
	  $line = $';
	  @times[0] = $line;
          @times[0] =~ s/\s//g;
      }
      if ($line =~ m/Elapsed covariance time in seconds:/) {
	  $line = $';
	  @times[1] = $line;
          @times[1] =~ s/\s//g;
      }
      if ($line =~ m/EIGENVALUES/) {
	  $eigen_area = 1;
	  $e=0;
      }
      if (($eigen_area == 1)&&((substr($line,0,1) eq "1")||(substr($line,0,4) eq "Stop"))) {
	  $eigen_area = 0;
	  if (@eig[0] != 0) {
	      $cond_nr{$est_method} = @eig[(@eig-1)]/@eig[0];
	  }
      }
      if ($eigen_area == 1) {
	  $e++;
	  if (($e>7)&&($e<11)) {
	      push (@eig, extract_th($line));
	  }
      }
      # get gradients: check if some gradient is 0.
      if ($line =~ m/GRADIENT/) { $gradient_area = 1; }
      if ($gradient_area == 1) {
	 unless (($line =~ m/GRADIENT/)||(substr($line,0,6) eq "      ")) {
	     $gradient_area = 0;
	 };
      }
      if ($gradient_area == 1) {
	  $line =~ s/GRADIENT:// ;
	  my @gradients;
	  my @gradients_line = split(" ",$line);
	  foreach (@gradients_line) {
	      if ($_ ne "") {
		  chomp($_);
		  $_ =~ s/\s//g;
		  push(@gradients, rnd($_,6));
	      }
	  }
	  foreach my $grad (@gradients) {
	      if ($grad == 0) {$grad_zero{$est_method} = 1}
	  }
      }

      if ($line =~ m/NEAR ITS BOUNDARY/) {$bnd{$est_method}="Y"};
#      if ((substr($line,0,1) eq "1")||(($i+1) == @lst)) {
      if ( ((substr($line,0,1) eq "1")&&(!(@lst[$i+2] =~ m/(ET|SI)/))) || ($i == (int(@lst)-1))  ) {
	  # if (($est_area==1)&&(!((@lst[$i+4] =~ m/STANDARD ERROR OF ESTIMATE/)||(@lst[$i+3] =~ m/STANDARD ERROR OF ESTIMATE/)))){ # no SE errors
	  #     my @est = get_estimates_from_text (\@est_text);
	  #     $estimates {$est_method} = \@est;
	  #     @est_text = ();
	  #     push (@methods, $est_method);
	  # }
	  if ($est_area==1) {
	      my @est = get_estimates_from_text (\@est_text);
	      $estimates {$est_method} = \@est ;
	      @est_text = ();
	      push (@methods, $est_method);
	  }
	  if ($se_area == 1) {
	      my @se = get_estimates_from_text (\@est_text);
	      $se_estimates{$est_method} = \@se ;
	      @est_text = ();
	  }
	  if ($term_area == 1) {
	      my @term = get_term_results_from_text (\@term_text);
	      $term_res{$est_method} = \@term;
	      @term_text = ();
	  }
	  $term_area = 0;
	  $est_area  = 0;
	  $se_area   = 0;
      }
      $l_prev = $line;
      $i++;
      $est_times{$est_method} = \@times;
  }
  return (\@methods, \%estimates, \%se_estimates, \%term_res, \%ofvs, \%cov_mat, \%est_times, \%bnd, \%grad_zero, \%cond_nr);
}

sub get_term_results_from_text {
# Purpose: get results from #TERM section from a block of text
    my $text_ref = shift;
    my @lines = @$text_ref;
    my @etabar; my @etabar_se; my @etabar_p; my @om_shrink; my @si_shrink;
    my $term_text; 
    my $text_area = 1; my $etabar_area; my $se_area; my $p_val_area; my $eta_shrink_area; my $eps_shrink_area;
    foreach my $line (@lines) {
	if ($line =~ m/ETABAR:/)    {
	    $etabar_area = 1; 
	}
	$line =~ s/\#TERM\:// ;
	$line =~ s/\#TERE\:// ;
	if ($line =~ m/ETABAR/) {
	    $text_area = 0;
	}
	if ($text_area == 1) {
	    chomp($line); 
	    $line =~ s/^\s+//; 
	    if ($line ne "") {
		$term_text .= $line."\n";}
	}
	if ($line =~ m/SE:/)       {
	    $etabar_area = 0;
	    $se_area = 1;
	}
	if ($line =~ m/P VAL.:/)   {
	    $se_area = 0;
	    $p_val_area = 1;
	}
	if ($line =~ m/ETAshrink/) {
	    $p_val_area = 0;
	    $eta_shrink_area = 1;
	}
	if ($line =~ m/EPSshrink/) {
	    $eta_shrink_area = 0;
	    $eps_shrink_area = 1;
	}
	if ($etabar_area == 1) {
	    $line =~ s/ETABAR://;
	    push (@etabar, extract_th($line)); 
	}
	if ($se_area == 1) {
	    if ($line =~ m/\d/) {
		$line =~ s/SE://;
		push (@etabar_se, extract_th($line));
	    }
	}
	if ($p_val_area == 1) {
	    if ($line =~ m/\d/) {
		$line =~ s/P VAL.://;
		push (@etabar_p, extract_th($line));
	    }
	}
	if ($eta_shrink_area == 1) {
	    if ($line =~ m/\d/) {
		$line =~ s/ETAshrink\(%\)://;
		push (@om_shrink, extract_th($line));
	    }
	}
	if (substr($line,0,1) eq "1") {$eps_shrink_area = 0}
	if ($eps_shrink_area == 1) {
	    if ($line =~ m/\d/) {
		$line =~ s/EPSshrink\(%\)://;
		push (@si_shrink, extract_th($line))
	    }
	}
    }
    foreach (@om_shrink) {$_ = rnd($_,3)};
    foreach (@si_shrink) {$_ = rnd($_,3)};
    return (\@etabar, \@etabar_p, \@etabar_se, \@om_shrink, \@si_shrink, \$term_text);
}

sub get_estimates_from_text {
# Purpose: get parameter estimates and se's from a block of text
    my ($text_ref) = shift;
    my @lines = @$text_ref;

    my $th_area=0; my $om_area=0; my $si_area=0; my $se_area=0; my $etabar_area = 1;
    my @th; my @om; my @si; my @th_se; my @om_se; my @si_se;
    my $om_line; my $cnt_om = 0; my $i;
    foreach my $line (@lines) {
	if ($line =~ m/THETA - VECTOR/) {
	    $th_area = 1;
	}
	if ($line =~ m/OMEGA - COV MATRIX/) {
	    $om_area = 1;
	    $th_area = 0;
	}
	if ($th_area == 1) {
	    unless ($line =~ m/TH/) {
		push (@th, extract_th ($line));
	    }
	}
	if ($om_area == 1) {
#	    if (((substr($line, 0,3) eq " ET")&&($cnt_om > 0))||(substr($line,0,1) eq "1")) {
	    unless ($line =~ m/(ET|\/|\:|\\)/) {
		if ($line =~ m/\./ ) {
		    chomp($line);
		    $om_line .= $line;
		}
	    }
	    if (((substr($line, 0,3) eq " ET")&&($cnt_om > 0)) || ($line =~ m/SIGMA/) || ($line =~ m/(\:|\/|\\)/) ) {
		push (@om, extract_cov ($om_line));
		$om_line = "";
	    }
	    if (substr($line,0,3) eq " ET") {
		$cnt_om++;
	    }
	}
	if ($si_area == 1) {
	    unless ($line =~ m/EP/) {
		if ($line =~ m/\./ ) {
		    chomp($line);
		    push (@si, extract_cov ($line));
		}
	    }
	}
	if ($line =~ m/(\:|\\|\/)/i) {
	    $om_area = 0;
	    $si_area = 0;
	}
	if ($line =~ m/SIGMA - COV MATRIX/) {
	    $si_area = 1;
	    $om_area = 0;
	}
	if ($line =~ m/ETABAR:/) {
	    $etabar_area = 1;
	}
	$i++;
    }
    return (\@th, \@om, \@si);
}

sub extract_th {
### Purpose : Extract parameter values from a line in a NM results file
### Compat  : W+L+
  my $line = shift;
  my @sp;
  $line =~ s/FIX//;
  my @raw_split = split (" ",$line);
  foreach (@raw_split) {
    unless ($_ eq "") {
      $_ =~ s/\s//g;
      push (@sp, $_);
    }
  }
  return (@sp);
}

sub extract_th_mod {
### Purpose : Extract parameter values from a line in a NM model file
### Compat  : W+L+
  my $line = shift;
  $line =~ s/FIX//;
  $line =~ s/\(/ /g;
  $line =~ s/\)/ /g;
  $line =~ s/,/ /g;
  my @spl = split (/\s/,$line);
  my @spl2;
  foreach my $num (@spl) {
      if ($num =~ m/\d/) {
	  push (@spl2, $num);
      }
  }
  if (@spl2==1) { # only initial estimate
      unshift (@spl2, "NA");
  }
  if (@spl2==2) { # only lower boundary and initial estimate
      push (@spl2, "NA");
  }
  return (@spl2);
}

sub extract_cov {
### Purpose : Extract se of parameter values from a line in a NM results file
### Compat  : W+L+
  my $line = shift;
  $line =~ s/FIX//;
  my @sp;
  my @raw_split = split (" ",$line);
  my $i=0;
  foreach (@raw_split) {
    if ($_ =~ m/\./) {
      $_ =~ s/\s//g;
      push (@sp, $_);
      $i++;
    }
  }
  return (\@sp);
}

sub blocks_from_estimates {
### Purpose : Get the final parameter estimates from a NM results file and return them as blocks of text that can be used for duplicating a model (dupl_ctl)
### Compat  : W+L+
  my ($model, $fix, $setting_ref) = @_;
  my %setting = %$setting_ref;
  $model =~ s/.$setting{ext_ctl}//i ;
  my $lstfile = $model.".".$setting{ext_res};

  my ($methods_ref, $est_ref, $term_ref, $ofvs_ref) = get_estimates_from_lst ($lstfile);
  my @methods = @$methods_ref;
  my %est = %$est_ref;
  my $estimates_ref = $est{@methods[(@methods-1)]};
  unless ($estimates_ref =~ m/ARRAY/) {
      return("");
  }
  my ($th_ref, $om_ref, $si_ref, $th_se_ref, $om_se_ref, $si_se_ref) = @$estimates_ref;;
  my @th = @$th_ref; my @om = @$om_ref; my @si = @$si_ref;
  my $fix_str = "";

# get information from NM model file
  my $modelfile = $model.".".$setting{ext_ctl};
  my $mod_ref = extract_from_model ($modelfile, $model, "all");
  my %mod = %$mod_ref;
  my @th_descr = @{$mod{th_descr}};
  my @om_descr = @{$mod{om_descr}};
  my @si_descr = @{$mod{si_descr}};
  my @th_bnd_low = @{$mod{th_bnd_low}};
  my @th_bnd_up  = @{$mod{th_bnd_up}};
  my @th_fix  = @{$mod{th_fix}};

  my ($th_block, $om_block, $si_block) = "";
  my $i=0;
  foreach (@th) {
      $th_block .= "(";
      if ($th_bnd_low[$i] ne "NA") {
	  $th_block .= rnd(@th_bnd_low[$i],4).", ";
      }
      $th_block .= rnd($th[$i],4);
      if ($th_bnd_up[$i] ne "NA") {
	  $th_block .= ",".rnd(@th_bnd_up[$i],4);
      }
      $th_block .= ")";
#      if ((!(@th_fix[$i] =~ m/FIX/i))&&($fix==0)) {
#	 $th_block .= " FIX";
#      }
      $th_block .= " ;".@th_descr[$i]."\n";
      $i++;
  }
  $i=0;
  foreach (@om) {
    my @om_n = @$_;
    #print @om_n."\n";
    foreach (@om_n) {
      unless ($_ eq "") {
        $om_block .= rnd($_,4)." ";
      }
    }
    $om_block .= " ;".@om_descr[$i]."\n";
    $i++;
  }
#  print $om_block;
  $i=0;
  foreach (@si) {
    my @si_n = @$_;
    foreach (@si_n) {
      unless ($_ eq "") {
         $si_block .= rnd($_,4)." ";
      }
    }
    $si_block .= " ;".@si_descr[$i]."\n";
    $i++;
  }
  return ($th_block, $om_block, $si_block);
}

sub duplicate_model {
### Purpose : Duplicate a NM model (actual subroutine)
### Compat  : W+L+
  my ($runno, $new_file, $new_ctl_descr, $new_ctl_ref, $change_run_nos, $est_as_init, $fix_est, $setting_ref) = @_;
  my %setting = %$setting_ref ; # make the general settings locally available.
  my $file .= $runno.".".$setting{ext_ctl};
  my $new_runno = $new_file;
  $new_file .= ".".$setting{ext_ctl};

  my $mod_ref = extract_from_model ($file, $runno);
  my %mod = %$mod_ref;

  # get estimates for last estimation method
  my (@methods, $methods_ref, $est_ref, $term_ref, $ofvs_ref);
  if (-e $runno.".".$setting{ext_res}) {
      ($methods_ref, $est_ref, $term_ref, $ofvs_ref) = get_estimates_from_lst ($runno.".".$setting{ext_res});
      @methods = @$methods_ref;
  }
  my (%est, @th, @om, @si);
  if (@methods > 0) {
      my %est = %$est_ref;
      my $estimates_ref = $est{@methods[(@methods-1)]};
      my ($th_ref, $om_ref, $si_ref, $th_se_ref, $om_se_ref, $si_se_ref) = @$estimates_ref;;
      @th = @$th_ref;
      @om = @$om_ref;
      @si = @$si_ref;
  };
  my $i=0;
  my $fix_str = ""; my $fix_str_om = "";
  if ($fix_est==1) {$fix_str = " FIX"};

  # convert omega and sigma to numbers
  my @all_om;
  foreach (@om) {
      my @om_n = @$_;
      foreach (@om_n) {
	  unless ($_ == 0) {
	      push (@all_om, rnd($_,4).$fix_str);
	  }
      }
      $i++;
  }

  if ($new_ctl_descr eq "") {$new_ctl_descr = $mod{description};}
  my ($th_block, $om_block, $si_block);
  my (@thetas, @omegas, @sigmas);
  if (($est_as_init==1)||($fix_est==1)) {
      ($th_block, $om_block, $si_block) = blocks_from_estimates($file, $fix_est, \%setting);
      @thetas = split (/\n/,$th_block);
      @omegas = split (/\n/,$om_block);
      @sigmas = split (/\n/,$si_block);
  }
  open (CTL_IN, "<".$file);
  my @ctl_lines=<CTL_IN>; close CTL_IN;
  open (CTL_OUT, ">".$new_file);
  my @ctl_new;

  $runno =~ s/run//;
  $new_runno =~ s/run//;

#  print $om_block;
  if (($change_run_nos==1)||($est_as_init==1)||($fix_est==1)) {
      my ($th_area, $om_area, $si_area);
      my $om_line=0; my $si_line=0; my $th_line = 0;
      my $change_area = 0; my $prior_area=0; my $th_area_flag=0;
      my $om_block_area = 0; my $om_block_cnt = 0; my $om_block_total;
      my $si_block_area = 0; my $si_block_cnt = 0; my $si_block_total;
      my $om_n = 0; my $th_n = 1; my $si_n = 0;
      my $i=0; while (@ctl_lines[$i]) {
	  if (substr(@ctl_lines[$i],0,1) eq "\$" ) {$change_area = 0};
	  if (substr(@ctl_lines[$i],0,5) eq "\$PROB") {
	      @ctl_lines[$i] =~ s/$runno/$new_runno/ig;
	  }
	  if (@ctl_lines[$i]  =~ /(\$TABLE|\$EST)/ ) {$change_area = 1};
	  if ($change_area == 1) {
	      my @spl = split (" ", @ctl_lines[$i]);
	      foreach (@spl) {
		  if ($_ =~ m/FILE=/) {
		      $_ =~ s/$runno/$new_runno/ig;
		  }
		  if ($_ =~ m/MSF=/) {
		      $_ =~ s/$runno/$new_runno/ig;
		  }
	      }
	      @ctl_lines[$i] = join (" ", @spl)."\n";
	  }
	  # second declarations of THETA indicates the use of priors
	  if ((substr(@ctl_lines[$i],0,6) eq "\$THETA")&&($th_area_flag==1)) {$prior_area=1};
	  if (substr(@ctl_lines[$i],0,1) eq "\$") {$th_area=0; $om_area=0; $om_block_area = 0; $si_area=0 };
	  if ((substr(@ctl_lines[$i],0,6) eq "\$THETA")&&(($est_as_init==1)||($fix_est==1))&&($th_area==0)&&($prior_area==0)) {$th_area=1; $th_area_flag=1; $th_line=0};
	  if ((substr(@ctl_lines[$i],0,6) eq "\$OMEGA")&&(($est_as_init==1)||($fix_est==1))&&($om_area==0)&&($prior_area==0)) {$om_area=1; $om_line=0; $om_block_cnt=0};
	  if (($om_area == 1)&&(@ctl_lines[$i] =~ m/BLOCK/i)) {
	      @ctl_lines[$i] =~ m/\((.*)\)/;
	      $om_block_area = $1;
	      $om_block_total = block_size ($om_block_area);
	  };
	  if (($si_area == 1)&&(@ctl_lines[$i] =~ m/BLOCK/i)) {
	      @ctl_lines[$i] =~ m/\((.*)\)/;
	      $si_block_area = $1;
	      $si_block_total = block_size ($si_block_area);
	  };
	  if ((substr(@ctl_lines[$i],0,6) eq "\$SIGMA")&&(($est_as_init==1)||($fix_est==1))&&($si_area==0)&&($prior_area==0)) {$si_area=1; $si_n = 0};
	  if ($th_area == 1) {
	      if (substr(@ctl_lines[$i],0,15) =~ m/\$THETA/ ) {  # First line of $OMEGA block
		  push (@ctl_new, @ctl_lines[$i]);
	      } else {
		  if ($est_as_init == 1) {
		      unless (($th_n == 0)||(@thetas[($th_n-1)] eq "")) {
			  @ctl_lines[$i] = @thetas[($th_n-1)]."\n";
		      }
		  }
		  if ($fix_est == 1) {
		      @ctl_lines[$i] = add_fix_to_param_line (@ctl_lines[$i])
		  }
		  $th_n++;
		  push (@ctl_new, @ctl_lines[$i]);
	      }
	  }
	  if ($om_area == 1) {
	      (my $om_string, $om_n, $om_block_cnt, $om_block_area) = parse_omega_line (@ctl_lines[$i], $fix_est, $est_as_init, \@omegas, $om_n, $om_block_cnt, $om_block_total, $om_block_area, 1);
	      push (@ctl_new, $om_string);
	  }
	  if ($si_area==1) {
	      (my $si_string, $si_n, $si_block_cnt, $si_block_area) = parse_omega_line (@ctl_lines[$i], $fix_est, $est_as_init, \@sigmas, $si_n, $si_block_cnt, $si_block_total, $si_block_area, 0);
	      push (@ctl_new, $si_string);
	  }
	  unless ( ($th_area + $om_area  + $si_area) > 0) {
	      push (@ctl_new,@ctl_lines[$i]);
	  }
	  $i++;
      }
  } else {
      @ctl_new = @ctl_lines;
  }
  if ($new_ctl_descr ne "") { print CTL_OUT "; Model desc: ".$new_ctl_descr."\n"; }
  if ($new_ctl_ref ne "") { print CTL_OUT "; Ref. model: ".$new_ctl_ref."\n"; }
  print CTL_OUT "; Duplicated from: ".$file."\n";
  if (@ctl_new[0] =~ m/Model desc/i) {shift @ctl_new};
  if (@ctl_new[0] =~ m/Ref\. model/i) {shift @ctl_new};
  unless ($^O =~ m/MSWin/) {
      foreach (@ctl_new) {
	  $_ =~ s/\r\n$/\n/;
      }  
  }
  print CTL_OUT @ctl_new;
  close CTL_OUT;
}

sub parse_omega_line { # can also be used for sigma block
    my ($ctl_line, $fix_est, $est_as_init, $omegas_ref, $om_n, $om_block_cnt, $om_block_total, $om_block_area, $om_area) = @_;
    my @omegas = @$omegas_ref;
    my ($om_string, $rest) = split (";", $ctl_line);
    my ($om_first_word, $rest2) = split (" ",$om_string);
    my $om_string_strip_block = $om_string;
    $om_string_strip_block =~ s/BLOCK\(.\)//i;
    my $add_om_string = "";
    my $replace_om = 1;
    if (!($om_first_word =~ m/\d/))       { $replace_om = 0 };
    if ( $om_string_strip_block =~ m/\d/) { # contains an omega value on the same line as $OMEGA (BLOCK)
	$replace_om = 1;
	if ($om_area == 1) {
	    $om_string =~ m/(\$OMEGA BLOCK\(.\))/i ;
	    $add_om_string = $1." ";
	} else {
	    $om_string =~ m/(\$SIGMA BLOCK\(.\))/i ;
	    $add_om_string = $1." ";
	}
    };
    if ( $om_string =~ m/SAME/) { 
	$replace_om = 0 
    };

    if ($replace_om == 0) {  # First line of $OMEGA block
	if ($om_string =~ m/SAME/) {$om_n++};
	return ( $ctl_line, $om_n, $om_block_cnt, $om_block_area);
    }
    if ($replace_om == 1) {
	if ($est_as_init == 1) {
	    ($om_string, $rest) = split (";", @omegas[$om_n]);
	    $ctl_line = "";
	}
	my @omegas_on_line = split (" ", $om_string);
	if ($om_block_cnt >= $om_block_total) {
	    $om_block_area = 0; # if the block has ended
	}
#		  print $om_block_area;
	if ($est_as_init == 1) {
	    if ($om_block_area > 1) {
		foreach my $om (@omegas_on_line) {
		    $ctl_line .= $om." ";
		    $om_block_cnt++;
		}
	    } else {
#			  print @omegas_on_line;
		$ctl_line .= @omegas_on_line[(@omegas_on_line)-1];
	    }
	}
	if ($fix_est==1) {
	    if (($om_block_area > 1)&&($om_n>0)) {
		# don't add FIX
	    } else {
		$ctl_line = add_fix_to_param_line ($ctl_line) ;
	    }
	}
	chomp ($ctl_line);
	if ($rest ne "") { $ctl_line .= "; ".$rest; } # if there was a comment, include it again
	$ctl_line .= "\n";
	$om_n++;
	return ($add_om_string.$ctl_line, $om_n, $om_block_cnt, $om_block_area);
    }
}

sub add_fix_to_param_line {
### Purpose : Add FIX to a THETA / OMEGA / SIGMA parameter line
### Compat  : W+L+
    my $line = shift;
    chomp ($line);
    my ($val, $comment) = split ( ";", $line);
    unless (($val =~ m/FIX/i)||($val eq "")) {
	$val .= " FIX ";
    }
    if ($comment ne "") {
	$line = $val.";".$comment."\n";
    } else {
	$line = $val."\n";
    }
    return ($line);
}

sub get_cov_mat {
### Purpose : Get varcov matrix from NM model file and return as array refs
### Compat  : W+L+
  my $file = shift;
  open (LST, "<".$file);
  my @lst = <LST>; my $skip=0; my $area=0; my $r_area=0; my $s_area=0; my $inv_cov_area; my $corr_area; my $cov_area;
  my $j=0; my @cov;
  my @cov_matrix; my @inv_cov_matrix; my @r_matrix; my @s_matrix; my @corr_area; my @corr_matrix; my @labels;
  foreach my $line (@lst) {
    if (($line =~ m/COVARIANCE MATRIX OF ESTIMATE/)&&(!($line =~ m/INVERSE/))) {;
      $cov_area = 1; $#labels = -1;
    }
    if ($line =~ m/INVERSE COVARIANCE MATRIX OF ESTIMATE/) { $inv_cov_area = 1; $#labels = -1;}
    if ($line =~ m/CORRELATION MATRIX OF ESTIMATE/) {$corr_area = 1; $#labels = -1;}
    if ($line =~ m/ R MATRIX/) { $r_area = 1; $#labels = -1;}
    if ($line =~ m/ S MATRIX/) { $s_area = 1; $#labels = -1; }
    $area = $cov_area + $inv_cov_area + $corr_area + $r_area + $s_area;
    if ($skip==0) {
    if ($area == 1) {
      if ($line =~ m/\./ ) {
        $line =~ s/\n//g;
        if (@lst[$j+1] =~ m/\./) {$line .= @lst[$j+1]; $skip=1}  # continued on following line
        if (@lst[$j+2] =~ m/\./) {$line .= @lst[$j+2]; $skip=2}  # continued on following line
        if ((@lst[$j+3] =~ m/\./)&&(@lst[$j+2] =~ m/\./)) {$line .= @lst[$j+3]; $skip=3}  # continued on following line
        my $cov_ref = extract_cov_line ($line);
        push (@cov, $cov_ref);
        my $label = substr(@lst[$j-1],0,7); $label =~ s/\s//g;
        push (@labels, $label);
      }
    }
    } else {$skip=$skip-1;}
    if (((substr($line,0,1) eq "1")&!(@lst[$j+2] =~m/TH1/))||($line =~ m/Stop/)) {
      $area = 0;
      if ($cov_area == 1) {@cov_matrix = @cov ; $cov_area=0}
      if ($inv_cov_area == 1) {@inv_cov_matrix = @cov ; $inv_cov_area=0}
      if ($corr_area == 1) {@corr_matrix = @cov ; $corr_area=0}
      if ($r_area == 1) {@r_matrix = @cov ; $r_area=0}
      if ($s_area == 1) {@s_matrix = @cov ; $s_area=0}
      undef @cov;
    };
    $j++;
  }
  close LST;
  return \@cov_matrix, \@inv_cov_matrix, \@corr_matrix, \@r_matrix, \@s_matrix, \@labels;
}

sub extract_cov_line {
### Purpose : Extract values from a line
### Compat  : W+L+
  my $line = shift;
  $line =~ s/\n//;
  my @sp;
  my @raw_split = split (" ",$line);
  my $i=0;
  foreach (@raw_split) {
    if ($_ =~ m/\./) {
      if ($_ =~ m/\.\./) {$_ = 0};
      $_ =~ s/\s//g;
      push (@sp, $_);
      $i++;
    }
  }
  return (\@sp);
}

sub extract_from_lst {
### Purpose : Extract parameter estimates and other information from a NM results file
### Compat  : W+L+
  my $file = shift;
  open (LST, "<".$file);
  my @lst = <LST>;
  my $th_area; my $om_area; my $si_area; my $se_area; my $minim_area; my $bnd_area; my $etabar_area;
  my $obs_rec; my $tot_id; my $nm_ver;
  my $eigen_area; my @etabar; my @etabar_se; my @etabar_p; my $minim_text;
  my @th; my @om; my @si; my @th_se; my @om_se; my @si_se; my @eig; my $e;
  my %all; my $feval; my $sig; my @bnd_low; my @bnd_up; my @bnd_th; my @th_init;
  my $j=0;
  foreach my $line (@lst) {
    if (($line =~ m/MINIMUM VALUE OF OBJECTIVE FUNCTION/)||($line =~ m/AVERAGE VALUE OF LIKELIHOOD FUNCTION/)||($line =~ m/FINAL VALUE OF OBJECTIVE FUNCTION/)||($line=~m/FINAL VALUE OF LIKELIHOOD FUNCTION/)) {
	my $ofv = @lst[$j+9];
	$ofv =~ s/#OBJV://g;
	$ofv =~ s/\*//g;
	$ofv =~ s/\s//g;
	$all{ofv} = add_item($all{ofv}, $ofv, "");
    }
    if ($line =~ m/MINIMIZATION SUCCESSFUL/) {$all{suc}="S"};
    if ($line =~ m/MINIMIZATION TERMINATED/) {
      $all{suc}="T";
      if (@lst[$j+1] =~ m/ROUNDING ERRORS/) {$all{suc}="R"}
    };
    if ($line =~ m/SIG. DIGITS/) {
      if ($line =~ m/UNREPORTABLE/) {$sig="U"}
      else {
        my @dig_line = split(" ", $line);
        $all{sig} = @dig_line[int(@dig_line)-1];
        $all{sig} =~ s/^\s+//; #remove leading spaces
      }
    };
    if ($line =~ m/NEAR ITS BOUNDARY/) {$all{bnd}="B"};
    if ($line =~ m/COVARIANCE MATRIX OF ESTIMATE/) {$all{cov}="C"};
    if (($line =~ m/MATRIX/)&&($line =~ m/SINGULAR/)) {$all{cov}="M"; $all{cov_warning} = substr($line,1,length($line)-1)};
    if ($line =~ m/STANDARD ERROR OF ESTIMATE/) {
      $se_area = 1;
    }
    if ($line =~ m/THETA - VECTOR/) {
      $th_area = 1;
    }
    if ($line =~ m/OMEGA - COV MATRIX/) {
      $om_area = 1;
      $th_area = 0;
    }
    if ($line =~ m/SIGMA - COV MATRIX/) {
      $si_area = 1;
      $om_area = 0;
    }
    if ($bnd_area == 1) {
      @bnd_th = extract_th($line);
      push (@bnd_low, @bnd_th[0]);
      #print join (" ",@bnd_th)."\n";
      push (@th_init, @bnd_th[1]);
      push (@bnd_up, @bnd_th[2]);
      if (substr($line,0,1) eq "0") {$bnd_area=0}
    }
    if ($line =~ m/TOT. NO. OF OBS RECS:/) {
        $obs_rec = rm_spaces($'); 
    }
    if ($line =~ m/TOT. NO. OF INDIVIDUALS:/) {
        $tot_id = rm_spaces($');
    }
    if ($line =~ m/1NONLINEAR MIXED EFFECTS MODEL PROGRAM \(NONMEM\)/) {
        $nm_ver = rm_spaces($'); 
    }
    if ($line =~ m/LOWER BOUND/){
      $bnd_area =1;
    }
    if ($line =~ m/NO. OF FUNCTION EVALUATIONS USED/) {
      chomp($line);
      $all{feval} = substr($line, 35);
    }
    if ($line =~ m/NO. OF SIG. DIGITS IN FINAL EST./) {
      chomp($line);
      $all{sig} = substr($line, 35);
    }
    if ($line =~ m/0MINIMIZATION/) {$minim_area=1; $line=substr($line,1,-1)};
    #if (($minim_area==1)&&((substr($line,0,1) eq "1")||($line =~ m/FUNCTION EVALUATIONS/))) {$minim_area=0};
    if (($minim_area==1)&&(substr($line,0,1) eq "1")) {$minim_area=0};
    if ($minim_area==1) {$minim_text .= $line."\n<BR>"};

    $j++;
  }
  close LST;
  if(-e $file) {$all{resdat} = stat($file) -> mtime};
  $all{theta_init} = \@th_init;
  $all{theta_bnd_low} = \@bnd_low;
  $all{theta_bnd_up} = \@bnd_up;
  $all{nm_ver} = $nm_ver;
  $all{minim_text} = $minim_text;
  $all{obs_rec} = $obs_rec;
  $all{tot_id} = $tot_id;
  @eig = sort { $a <=> $b } @eig;
  $all{etabar} = \@etabar;
  $all{etabar_se} = \@etabar_se;
  $all{etabar_p} = \@etabar_p;
  return \%all;
}

sub output_results_HTML {
### Purpose : Compile a HTML file that presents some run info and parameter estimates
### Compat  : W+
  my ($file, $setting_ref, $pirana_notes, $include_html_ref) = @_;
  my %setting = %$setting_ref;
  my %include_html = %$include_html_ref;
  my $run = $file;
  $run =~ s/\.$setting{ext_res}//;

# get information from NM output file
  my $res_ref = extract_from_lst ($file);
  my %res = %$res_ref;
# and get information from NM model file
  my $mod_ref = extract_from_model ($run.".".$setting{ext_ctl}, $run, "all");
  my %mod = %$mod_ref;

  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = @{localtime($res{resdat})};
  my $html = "pirana_sum_".$file.".html";

  ### Start HTML output
  open (HTML,">".$html);
  print HTML "<HTML><HEAD><STYLE>\n";
  print HTML "TD {font-family:Verdana,arial; font-size:0.8em}\n";
  print HTML ".stats {background-color: #F3F3F3}\n";
  print HTML ".head1 {background-color: #6a6a6a; color: #FFFFFF}\n";
  print HTML ".head2 {background-color: #909090; color: #FFFFFF}\n";
  print HTML ".theta {background-color: #F3F3F3; text-align:left; font-size:0.7em}\n";
  print HTML ".omega {background-color: #F3F3F3; text-align:right; font-size:0.7em}\n";
  print HTML ".sigma {background-color: #F3F3F3; text-align:right; font-size:0.7em}\n";
  print HTML ".matrix {background-color: #F3F3F3}\n";
  print HTML "A {font-family:Verdana,arial; font-size:0.8em}\n";
  print HTML "</STYLE></HEAD><BODY>&nbsp;<BR>\n";
  print HTML "<TABLE border=0 cellpadding=2 cellspacing=0 CLASS='stats' width=600>\n";
  print HTML "<TR><TD bgcolor='#550000' colspan=3><B><FONT color='#FFFFFF'>Run statistics:</FONT></B></TD></TR>\n";
  print HTML "<TR><TD width=200>Run number</TD><TD><FONT FACE=verdana,arial size=2 color='darkred'><B>".$mod{mod}."</B></FONT></TD></TR>\n";
  print HTML "<TR><TD>Nonmem output file</TD><TD><A href='".$file."'>".$file."</A></TD><TD></TD></TR>\n";
  if ($include_html{basic_run_info} == 1 ) {
      print HTML "<TR><TD>Reference model</TD><TD><FONT FACE=verdana,arial size=2>".$mod{refmod}."</FONT></TD></TR>\n";
      print HTML "<TR><TD>Description</TD><TD><FONT FACE=verdana,arial size=2>".$mod{description}."</FONT></TD></TR>\n";
      print HTML "<TR><TD>NONMEM version:</TD><TD><FONT FACE=verdana,arial size=2>".$res{nm_ver}."</FONT></TD></TR>\n";
      print HTML "<TR><TD>Dataset</TD><TD><FONT FACE=verdana,arial size=2>".$mod{dataset}."</FONT></TD></TR>\n";
      print HTML "<TR><TD># Individuals</TD><TD><FONT FACE=verdana,arial size=2>".$res{tot_id}."</FONT></TD></TR>\n";
      print HTML "<TR><TD># Observation records</TD><TD><FONT FACE=verdana,arial size=2>".$res{obs_rec}."</FONT></TD></TR>\n";
      print HTML "<TR><TD>Output file date</TD><TD>".($year+1900)."-".($mon+1)."-".$mday.", $hour:$min:$sec</TD><TD></TD></TR>\n";
      print HTML "<TR><TD valign=top>Table files:</TD><TD>";
      my $tables_ref = $mod{tab_files};
      my @tables = @$tables_ref;
      foreach (@tables) {
	  unless (-e $_) {$_ .= " (not found)"}
      }
      print HTML join("<BR>\n", @tables);
      print HTML "</TD><TD></TD></TR>\n";
  }
  if ($include_html{notes_and_comments} == 1 ) {
      my $comments_ref = $mod{comment_lines};
      my @comments = @$comments_ref;
      if (@comments > 0) {
	  my $comments_join = join("<BR>", @comments);
	  print HTML "<TR><TD valign=top>Comment lines:</TD><TD><FONT FACE=verdana,arial size=2>".$comments_join."</FONT></TD></TR>\n";
      }
      if ($pirana_notes ne "") {
	  $pirana_notes =~ s/\n/<BR>/g;
	  print HTML "<TR><TD valign=top>Pirana notes:</TD><TD><FONT FACE=verdana,arial size=2>".$pirana_notes."</FONT></TD></TR>\n";
      }
  }
  if ($include_html{model_file} == 1) {
      open (MOD, "<".$mod{mod}.".".$setting{ext_ctl});
      my @mod_lines = <MOD>;
      foreach (@mod_lines) {
	  $_ =~ s/\n/\<BR\>/g;
      }
      close (MOD);
      print HTML "<TR><TD valign=top>Model:</TD>\n";
      print HTML "<TD>";
      print HTML @mod_lines;
      print HTML "</TD></TD></TR>\n"
  }
  print HTML "</TABLE>\n<P>\n";

# Estimation specific info and Parameter estimates
  if (($include_html{param_est_all} == 1) || ($include_html{param_est_last}==1) ) {
      my ($methods_ref, $est_ref, $se_est_ref, $term_ref, $ofvs_ref, $cov_mat_ref, $est_times_ref, $bnd_ref, $grad_zero_ref, $cond_nr_ref) = get_estimates_from_lst ($file);
      my @methods = @$methods_ref;
      if ($include_html{param_est_last} == 1) {
	  @methods = @methods[(@methods-1)];
      }      
      my %est = %$est_ref;
      my %se_est  = %$se_est_ref;
      my %term_res = %$term_ref;
      my %ofvs = %$ofvs_ref;
      my $meth_descr;
      my %cov_mat = %$cov_mat_ref;
      my %est_times = %$est_times_ref;
      my %bnd = %$bnd_ref;
      my %grad_zero = %$grad_zero_ref;
      my %cond_nr = %$cond_nr_ref;
      foreach my $meth (@methods) {
	  if ($meth eq "NA") {
	      $meth_descr = $mod{method}  # NM 6
	  } else {
	      $meth_descr = $meth;
	  }
#	  print $meth.$est{$meth}."\n";
	  print HTML "<TABLE width=600 border=0 cellpadding=2 cellspacing=0 CLASS='theta'>\n";
	  print HTML "<TR bgcolor='#000055'><TD colspan=2><B><FONT color='#FFFFFF'>".$meth_descr."</FONT></B></TD></TR>";
	  generate_HTML_run_specific_info ($meth, \%res, \%mod, $term_res{$meth}, $ofvs{$meth}, $est_times{$meth}, $bnd{$meth}, $grad_zero{$meth}, $cond_nr{$meth});
	  generate_HTML_parameter_estimates (\%res, \%mod, $est{$meth}, $se_est{$meth}, $term_res{$meth});
      }
  print HTML "<font size=1 face=verdana,arial>* Correlations in omega are shown as the off-diagonal elements. SAME blocks are not shown.<BR>";
#      print HTML "<font size=1 face=verdana,arial>* Random effects are shown as OM^2 and SI^2</FONT><BR>";
#      print HTML "<font size=1 face=verdana,arial>** RSE on random effects are shown as RSE(OM^2) and RSE(SI^2). RSE(OM) can be calculated as RSE(OM^2)/2. </FONT><BR>";
  }
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = @{localtime()};
#  print @{localtime()};
  print HTML "<TABLE><TR><TD colspan=2><FONT FACE=verdana,arial size=0>Generated ".($year+1900)."-".($mon+1)."-".$mday.", ".$hour.":".$min.":".$sec." by Piraña</FONT></TD></TR></TABLE>\n";
  print HTML "</BODY>";
  close HTML;
}

sub generate_HTML_run_specific_info {
  my ($meth, $res_ref, $mod_ref, $term_ref, $ofv, $est_time_ref, $bnd, $grad_zero, $cond_nr) = @_;
  my %res = %$res_ref;
  my %mod = %$mod_ref;
  my @term;
  my @times;
  if ($est_time_ref =~ m/ARRAY/) {
      @times = @$est_time_ref;
  }
  if ($term_ref =~ m/ARRAY/) {
      @term = @$term_ref;
  }
  my $term_message_ref = @term[5];
  my $term_message = lc($$term_message_ref);
  $term_message =~ s/\n/\<BR\>/g;
  $term_message =~ s/unreportable/<FONT color='#770000'><b>unreportable<\/b><\/FONT>/;
  $term_message =~ s/terminated/<FONT color='#770000'><b>terminated<\/b><\/FONT>/;
  $term_message =~ s/rounding errors/<FONT color='#770000'><b>rounding errors<\/b><\/FONT>/;
  print HTML "<TR><TD colspan=1 width=200>Objective function value:</TD><TD colspan=1>".$ofv."</TD></TR>";
  print HTML "<TR><TD colspan=1 valign='top'>Termination message:</TD><TD colspan=1>".$term_message."</TD></TR>";
  if (@times[0] != 0) {
      my $dur = time_format (@times[0]);
      print HTML "<TR><TD colspan=1 valign='top'>Estimation time:</TD><TD colspan=1>".$dur."</TD></TR>";
  }
  if (@times[1] ne "") {
      my $dur_cov = time_format (@times[1]);
      print HTML "<TR><TD colspan=1 valign='top'>Covariance step time:</TD><TD colspan=1>".$dur_cov."</TD></TR>";
  }
  print HTML "<TR><TD colspan=1 valign='top'>Checks:</TD><TD>" ;
  if ($bnd eq "Y") {
      print HTML "<FONT color='#770000'><B>Boundary problem reported by NONMEM!</B><FONT></TD></TR>";
  } else {
      print HTML "<FONT color='#007700'>No boundary problems reported by NONMEM</FONT></TD></TR>";
  }
  if (($meth =~ m/first order/i )||($meth =~ m/cond/i)) { # FO or FOCE methods
      if ($grad_zero == 1) {
	  print HTML "<TR><TD colspan=1 valign='top'></TD><TD><FONT color='#770000'><B>Zero gradients encountered during estimation!</B></FONT></TD></TR>";
      } else {
	  print HTML "<TR><TD colspan=1 valign='top'></TD><TD><FONT color='#007700'>All gradients non-zero during estimation</FONT></TD></TR>";
      }
      # for gradient methods, also print cond.number when available
      print HTML "<TR><TD colspan=1 valign='top'>Condition number:</TD><TD colspan=1>";
      if ($cond_nr eq "") {
	  print HTML "NA";
      } else {
	  print HTML rnd($cond_nr,2)
      }
      print HTML "</TD></TR>\n";
  }
  print HTML "<TR><TD colspan=1></TD><TD colspan=1></TD></TR>";
  if ($mod{msf_file} ne "") {
      print HTML "<TR><TD colspan=1>MSF file:</TD><TD colspan=1>";
      print HTML $mod{msf_file};
      print HTML "</TD></TR>\n";
  }
}

sub generate_HTML_parameter_estimates {
  my ($res_ref, $mod_ref, $est_ref, $se_est_ref, $term_ref) = @_;
  my %res = %$res_ref;
  my %mod = %$mod_ref;

  my @est;
  if ($est_ref =~ m/ARRAY/) {
      @est = @$est_ref;
  } else {return();}

  print HTML "</TABLE><TABLE border=0 cellpadding=2 cellspacing=0 CLASS='theta'>\n";
  print HTML "<TR class='head1'><TD colspan=2><B>Theta</B></TD><TD align=left><B>Estimate*</B></TD><TD width=50></TD><TD width=80 align=RIGHT><B>SE</B></TD><TD width=80 align=RIGHT><B>RSE</B></TD><TD width=80 align=RIGHT><B>95% CI**</B></TD><TD align='left'>[ lower, </TD><TD align='center'>init,</TD><TD> upper]</TD><TR>\n";

  my $theta_ref = @est[0]; my @theta = @$theta_ref;
  my $theta_init_ref = $res{theta_init};  my @theta_init = @$theta_init_ref;
  my $theta_bnd_low_ref = $res{theta_bnd_low};  my @theta_bnd_low = @$theta_bnd_low_ref;
  my $theta_bnd_up_ref = $res{theta_bnd_up};  my @theta_bnd_up = @$theta_bnd_up_ref;

  my @theta_se; my @omega_se; my @sigma_se;
  my @se_est;
  if ($se_est_ref =~ m/ARRAY/) {
      @se_est = @$se_est_ref;
      if (@est>1) {
	  my $theta_se_ref = @se_est[0];  @theta_se = @$theta_se_ref;
	  my $omega_se_ref = @se_est[1];  @omega_se = @$omega_se_ref;
	  my $sigma_se_ref = @se_est[2];  @sigma_se = @$sigma_se_ref;
      }
  } 

  my $theta_names_ref = $mod{th_descr}; my @theta_names = @$theta_names_ref;
  my $theta_fix_ref = $mod{th_fix}; my @theta_fix = @$theta_fix_ref;

  my $omega_ref = @est[1];  my @omega = @$omega_ref;
  my $omega_names_ref = $mod{om_descr}; my @omega_names = @$omega_names_ref;
  my $omega_same_ref = $mod{om_same}; my @omega_same = @$omega_same_ref;

  my $sigma_ref = @est[2];  my @sigma = @$sigma_ref;
  my $sigma_names_ref = $mod{si_descr}; my @sigma_names = @$sigma_names_ref;

  my @term; my $term_info = 0; my @etabar; my @etabar_se; my @etabar_p; my @si_shrink; my @om_shrink;
  if ($term_ref =~ m/ARRAY/) {
      my @term = @$term_ref;
      my $etabar_ref = @term[0];  @etabar = @$etabar_ref;
      my $etabar_p_ref = @term[1]; @etabar_p = @$etabar_p_ref;
      my $etabar_se_ref = @term[2]; @etabar_se = @$etabar_se_ref;
      my $om_shrink_ref = @term[3];  @om_shrink = @$om_shrink_ref;
      my $si_shrink_ref = @term[4];  @si_shrink = @$si_shrink_ref;
      $term_info = 1 ;
      #    return (\@etabar, \@etabar_p, \@etabar_se, \@om_shrink, \@si_shrink, \$term_text);
  }
  my $col='black'; my $text="";
  my $i=0;

  # THETA
  foreach (@theta) {
    print HTML "<TR>";
    if (@theta[$i] ne "") {print HTML "<TD class='head2' align='right'><FONT size=-2>".($i+1)."</FONT></TD>".
       "<TD>".@theta_names[$i]."</TD><TD ALIGN=left bgcolor='#EAEAEA'><FONT color='".$col."'><B>".rnd(@theta[$i],5)."</B></TD>"};
    print HTML "<TD bgcolor='#EAEAEA'>".@theta_fix[$i]."</TD>";

    my $rse = "";
    unless (@theta[$i] == 0) {$rse = abs(rnd(@theta_se[$i]/@theta[$i]*100,1)) };
    if (@theta_se[$i]) {
	my $up = rnd((@theta[$i] + @theta_se[$i]),3);
	my $low = rnd((@theta[$i] - @theta_se[$i]),3);
	print HTML "<TD align=RIGHT>".rnd(@theta_se[$i],4)."</TD>";
	print HTML "<TD align=RIGHT bgcolor='#EAEAEA'>".$rse."%</TD>";
	print HTML "<TD align=RIGHT bgcolor='#EAEAEA'>".$low." - ".$up."</TD>";
    } else {
	print HTML "<TD>&nbsp;</TD>";
	print HTML "<TD bgcolor='#EAEAEA'>&nbsp;</TD>";
	print HTML "<TD bgcolor='#EAEAEA'>&nbsp;</TD>";
    };

    my $low = $theta_bnd_low[$i];
    my $up = $theta_bnd_up[$i];
    if ($low <= -10000) {$low = "-Inf"} else {$low = rnd($theta_bnd_low[$i],3)};
    if ($up >= 10000) {$up = "+Inf"} else {$up = rnd($theta_bnd_up[$i],3)};

    print HTML "<TD align='right'>".$low."</TD><TD align='right' bgcolor='#EAEAEA'>".rnd(@theta_init[$i],3)."</TD><TD align='right'>".$up."</TD>";
    print HTML "</TR>\n";
    $i++;
  }
  print HTML "</TABLE>\n<TABLE cellpadding=2 cellspacing=0 border=0 CLASS='omega'>";

  # OMEGA
  print HTML "<TR class='head1''><TD align='left'><B>Omega</B></TD><TD></TD>";
  $i=1;
  foreach my $om (@omega) {
      print HTML "<TD>".$i."</TD><TD></TD>" ; 
      $i++;
  };
  if (@etabar>0) {
      print HTML "<TD>Etabar (SE)</TD><TD>p val</TD>";
  }
  if (@om_shrink>0) {
      print HTML "<TD>Shrinkage</TD>";
  }
  print HTML "</TR>\n";
  $i=0; my $om_se_x; my @om_cov_se;
  my @om_diag; my @om_se_diag;
  foreach my $om (@omega) {
      my @om_x = @$om; my $j = 1;
      print HTML "<TR><TD class='head2'>".($i+1)."</TD>\n";
      print HTML "<TD align='left'>".@omega_names[$i]."</TD>\n";
      my $bg = "";
      foreach my $om_cov (@om_x) {
        if (@omega_se>0) {$om_se_x = @omega_se[$i]; @om_cov_se = @$om_se_x;};
        if ($j == @om_x) {
	    push (@om_diag, $om_cov);
	    if ($om_cov != 0) {
		push (@om_se_diag, (@om_cov_se[$i]/$om_cov));
	    }
	} 
        # on- or off-diagonal?
        if (($j-1)/2 == int(($j-1)/2)) {$bg = "bgcolor='#EAEAEA'"} else {$bg = ""}
        print HTML "<TD $bg>".rnd($om_cov,4);
        if (($om_cov!=0)&&(@om_cov_se[$i]!=0)) {
          print HTML "<TD $bg><FONT color='#888888'>(".abs(rnd((@om_cov_se[($j-1)]/$om_cov*100),1))."%)</FONT></TD>";
        } else {
          print HTML "<TD $bg></TD>";
        }
        print HTML "</TD>";
        $j++;
      }

      if (@etabar>0) {
        for (my $fill = $j-1; $fill<@omega; $fill++) {
          if (($fill)/2 == int(($fill)/2)) {$bg = "bgcolor='#EAEAEA'"} else {$bg = "";}
          print HTML "<TD $bg></TD><TD $bg></TD>";
        };
        my ($bg1, $bg2);
        if ((@omega)/2 == int((@omega)/2)) {$bg1 = "bgcolor='#EAEAEA'"; $bg2="bgcolor='#F3F3F3'"} else {$bg2 = "bgcolor='#EAEAEA'"; $bg1="bgcolor='#F3F3F3'"};
        if ($term_info == 1) { print HTML "<TD $bg1>".rnd(@etabar[$i],3)." (".rnd(@etabar_se[$i],3).")</TD><TD $bg2>".rnd(@etabar_p[$i],4)."</TD>"; }
      }
      if (@om_shrink>0) {
	  print HTML "<TD>".rnd($om_shrink[$i],1)."%</TD>";
      }
      print HTML "</TR>";
      $i++;
  }
  print HTML "</TABLE>\n<TABLE cellpadding=2 cellspacing=0 border=0 CLASS='sigma'>";

  #OMEGA transformed
  print HTML "<TR class='head1''><TD align='left' colspan=2><B>Omega (on SD scale) *</B></TD>";
  $i=1;
  foreach my $om (@omega) {
      if (@omega_same[($i-1)] == 0) {
	  print HTML "<TD>".$i."</TD><TD></TD>" ; 
      }
      $i++;
  };
  print HTML "</TR>\n";
  $i=0; my $om_se_x; my @om_cov_se; 
  my $cnt_om_nonsame = 0; foreach (@omega_same) {if ($_ == 0) {$cnt_om_nonsame++}}
  foreach my $om (@omega) {
      my $col = 0;
      my @om_x = @$om; my $j = 1;
      if (@omega_same[$i] == 0) {
      print HTML "<TR><TD class='head2'>".($i+1)."</TD>\n";
      print HTML "<TD align='left'>".@omega_names[$i]."</TD>\n";
      my $bg = "";
      my $diag = 1;
      foreach my $om_cov (@om_x) {
	  if (($col)/2 == int(($col)/2)) {$bg = "bgcolor='#EAEAEA'"} else {$bg = ""}
	  if (@omega_same[($j-1)] == 0) {
	  print HTML "<TD $bg>";
	  if (@omega_se>0) {
	      $om_se_x = @omega_se[$i];
	      @om_cov_se = @$om_se_x;
	  }
	  my $corr;
	  if ($j == @om_x) {
	      print HTML rnd(sqrt(abs($om_cov))*100,1)."%";
	  } else {
	      my $corr_denom = sqrt(@om_diag[$i])*sqrt(@om_diag[($j-1)]) ;
	      if ($corr_denom != 0) {
		  $corr = ($om_cov / $corr_denom);
		  print HTML rnd ( 100 * $corr , 1)."%";
	      } else {
		  print HTML "NA";
	      }
	  }
#	  print HTML "%";

	  # uncertainty in correlation
	  if (($om_cov!=0)&&(@om_cov_se[$i]!=0)) {
	      if ($j == @om_x) { # diagonal: just divide u_var by 2
		  print HTML "<TD $bg><FONT color='#888888'>(".abs(rnd((@om_cov_se[$i]/$om_cov*100/2),1))."%)</FONT></TD>";
	      } else {
#		  my $u1 = @om_se_diag[$i]/2;
#		  my $u2 = @om_se_diag[($j-1)]/2;
#		  my $u12 = sqrt($u1*$u1 + $u2*$u2 + (2 * $u1 * $u2 * $corr));
#		  my $u_covar = (@om_cov_se[($j-1)] / $om_cov);
#		  my $u_corr  = sqrt (($u_covar*$u_covar) + ($u12*$u12) - (2 * $u_covar * $u12 * 1));
#		  print HTML "<TD $bg><FONT color='#888888'>(".abs(rnd($u_corr*100,1))."%)</FONT></TD>";
		  print HTML "<TD $bg><FONT color='#888888'></FONT></TD>";
	      }
	  } else {
	      print HTML "<TD $bg></TD>";
	  }
	  print HTML "</TD>";
          $col++;
	  }
	  $j++;
      }
      for (my $fill = $col; $fill < $cnt_om_nonsame; $fill++) {
           if (($fill)/2 == int(($fill)/2)) {$bg = "bgcolor='#EAEAEA'"} else {$bg = "";}
           print HTML "<TD $bg></TD><TD $bg></TD>";
      };
      print HTML "</TR>";
      }
      $i++;
  }
  print HTML "</TABLE>\n<TABLE cellpadding=2 cellspacing=0 border=0 CLASS='sigma'>";

  # SIGMA
  print HTML "<TR class='head1'><TD align='left'><B>Sigma</B></TD><TD></TD>";
  $i=1;
  foreach my $si (@sigma) {print HTML "<TD>".$i."</TD><TD></TD>" ; $i++};
  if (@si_shrink>0) {
      print HTML "<TD>Shrinkage</TD>";
  }
  print HTML "</TR>\n";
  $i=0; my $si_se_x; my @si_cov_se; my $bg;
  my @si_diag; my @si_se_diag;
  foreach my $si (@sigma) {
      my @si_x = @$si; my $j = 1;
      print HTML "<TR><TD class='head2'>".($i+1)."</TD>\n";
      if (($j-1)/2 == int(($j-1)/2)) {$bg = "bgcolor='#EAEAEA'"} else {$bg = ""}
      print HTML "<TD>".@sigma_names[$i]."</TD>\n";

      foreach my $si_cov (@si_x) {
        if (@sigma_se>0) {$si_se_x = @sigma_se[$i]; @si_cov_se = @$si_se_x;};
        if ($j == @si_x) {
	    push (@si_diag, $si_cov);
	    if ($si_cov != 0) {
		push (@si_se_diag, (@si_cov_se[$i]/$si_cov));
	    }
	}
        if (($j-1)/2 == int(($j-1)/2)) {$bg = "bgcolor='#EAEAEA'"} else {$bg = ""}
        print HTML "<TD $bg>".rnd($si_cov,4);
        if (($si_cov!=0)&&(@si_cov_se[$i]!=0)) {
          print HTML "<TD $bg><FONT color='#777777'>(".rnd((@si_cov_se[$i]/$si_cov*100),1)."%)</FONT></TD>";
        } else {
          print HTML "<TD $bg></TD>";
        }
        print HTML "</TD>";
        $j++;
      }
      for (my $fill = $j-1; $fill<int(@sigma); $fill++) {
	   
           if (($fill)/2 == int(($fill)/2)) {$bg = "bgcolor='#EAEAEA'"} else {$bg = "";}
           print HTML "<TD $bg></TD><TD $bg></TD>";
      };

      if (@si_shrink>0) {
	  print HTML "<TD>".rnd(@si_shrink[$i],1)."%</TD>";
      }
      print HTML "</TR>";
      $i++;
  }
  print HTML "</TABLE>\n";
  print HTML "<BR>";
}

sub extract_from_model {
### Purpose : Extract information about the model from a NM model file
### Compat  : W+L+
  my ($file, $modelno, $what) = @_;
  my $description = ""; my $refmod = ""; my $date_mod ="";
  my @th_bnd_low; my @th_init; my @th_bnd_up;
  my %mod; my @comments;
  $mod{mod} = $modelno;
  if (-e $file) {
      $mod{date_mod} = stat($file)->mtime();
  }
  open (CTL,"<".$file);
  my @ctl_lines=<CTL>;
  close CTL;
  my $description = @ctl_lines[0];
  $description =~ s/model desc://i;
  $description =~ s/\$PROBLEM//i;
  $description =~ s/\$PROB//i;
  $description =~ s/\;//;
  $description =~ s/^\s+//; #remove leading spaces
  $description =~ s/\n//;
  my $descr_area = 0;
  # search first few lines for reference model and model description.
  for (my $j =0; $j < 20; $j++) {
    if (substr(@ctl_lines[$j],0,1) eq ";") {
      if ((@ctl_lines[$j] =~ m/Ref/i)||(@ctl_lines[$j] =~ m/Parent/i)||(@ctl_lines[$j] =~ m/based on/i)) {  # Census uses 'Parent', but you can also use anything containing Ref
        @ctl_lines[$j] =~ s/\=/:/g;  # for people that code 'Ref=001'
        @ctl_lines[$j] =~ s/\s/:/;   #in between spaces
        my @l = split (/\:/, @ctl_lines[$j]); # get last word (hopefully the ref model no#)
        $refmod = @l[int(@l)-1];
        $refmod =~ s/^\s+//; #remove leading spaces
	$refmod =~ s/\"+$//;  #remove trailing spaces
        chomp ($refmod);
      }
      # PsN run specification format:
      if ((substr(@ctl_lines[$j], 0,2) eq ";;")&&(@ctl_lines[$j] =~ m/based on:/i)) {  # Census uses 'Parent', but you can also use anything containing Ref
	  @ctl_lines[$j] =~ s/;;//;
	  @ctl_lines[$j] =~ s/\=/:/g;  # for people that code 'Ref=001'
	  @ctl_lines[$j] =~ s/\s/:/;   #in between spaces
	  my @l = split (/\:/, @ctl_lines[$j]); # get last word (hopefully the ref model no#)
	  my $refmod = @l[int(@l)-1];
	  $refmod =~ s/^\s+//; #remove leading spaces
	  $refmod =~ s/\"+$//;  #remove trailing spaces
      }
      if ((substr(@ctl_lines[$j], 0,2) eq ";;")&&(@ctl_lines[$j] =~ m/description:/i)) {  # Census uses 'Parent', but you can also use anything containing Ref
	  $descr_area = 1;
	  @ctl_lines[$j] =~ s/2\.//;
	  $description = "" ; # reset description as it is supplied in the PsN run record
      }
      if ($descr_area == 1) {
	  if ((@ctl_lines[$j] =~ m/;;/)&&(@ctl_lines[$j] =~ m/(based on:|label:|structural model:|covariate model:|inter-individual variability:|inter-occasion variability:|residual variability:|estimation:)/i)) {
	      $descr_area = 0;
	  }
	  unless (@ctl_lines[$j] =~ m/;;/) {
	      $descr_area = 0;
	  }
	  @ctl_lines[$j] =~ s/;;//g;
	  if (@ctl_lines[$j] =~ m/description/i) {
	      @ctl_lines[$j] =~ s/://g;
	      @ctl_lines[$j] =~ s/=//g;
	      @ctl_lines[$j] =~ s/description//i;
	  }
	  if ($descr_area == 1) {
	      $description .= @ctl_lines[$j];
	  }
      }
    }
  }
  $description =~ s/^\s+//; #remove leading spaces
  if ($what eq "all") {
    # loop through model file to extract parameter names
      my $theta_area=0; my $omega_area=0; my $sigma_area=0; my $prior=0;
    my $theta_area_prv=0; my $omega_area_prv=0; my $sigma_area_prv=0; # needed to determine whether in Prior region or not
    my $table_area=0; my $estim_area=0; my $msf_file="";
      my $cnt = 0; 
    my @th_descr; my @om_descr; my @si_descr;
    my $om_comment_flag; my $si_comment_flag;
    my @tab_files;
    my (@th_fix, @om_fix, @si_fix);
      my @om_same; my $sigma_flag;
      my @block = (1); my $last_om = 1;
    foreach (@ctl_lines) {
      if (substr($_,0,1) eq "\$") {
        if ($theta_area==1) {$theta_area=0} ;
        if ($omega_area==1) {$omega_area=0} ;
        if ($sigma_area==1) {$sigma_area=0} ;
        if ($table_area==1) {$table_area=0} ;
        if ($estim_area==1) {$estim_area=0} ;
      }
      if ((substr ($_,0,1) eq ";")&&(!($_ =~ m/model desc/i))&&(!($_ =~ m/ref\. model\:/i))) {
	  my $comment = $_;
	  $comment =~ s/;//g;
	  push (@comments, $comment);
      } else {
	  if (substr ($_,0,6) eq "\$THETA") {$theta_area = 1; $theta_area_prv=1; }
	  if (substr ($_,0,6) eq "\$OMEGA") {$omega_area = 1; if ($theta_area_prv==1) {$omega_area_prv=1;} }
	  if (substr ($_,0,6) eq "\$SIGMA") {$sigma_area = 1; $sigma_flag = 1; }
	  if (substr ($_,0,6) eq "\$TABLE") {$table_area = 1 }
	  if (substr ($_,0,4) eq "\$EST")   {$estim_area = 1 }
	  if (substr ($_,0,5) eq "\$DATA") {
	      my @data_arr = split (" ", $_);
	      shift(@data_arr);
	      my $dataset = "";
	      while (($dataset eq "")&&(@data_arr>0)) {$dataset = shift(@data_arr)};
	      $mod{dataset} = $dataset;
	  }
	  if ( $theta_area_prv + $omega_area_prv + $theta_area == 3) {
	      $prior = 1;
	  }
	  if ($theta_area+$omega_area+$sigma_area>0) {
	      my ($init, @rest) = split (";",$_);
	      my $descr = @rest[0];
	      if (@rest>1) { # PsN specific (units)
		  @rest[1] =~ s/^\s+//; #remove leading spaces
		  @rest[1] =~ s/\"+$//;  #remove trailing spaces
		  $descr .= "(".@rest[1].")";
	      };
	      if (($init =~ m/\d/)&&($theta_area==1)) {
		  my @th_ex = extract_th_mod($init);
		  push (@th_bnd_low, @th_ex[0]);
		  push (@th_init,    @th_ex[1]);
		  push (@th_bnd_up,  @th_ex[2]);
	      }
	      $om_comment_flag = 0;
	      my $init_clean = $init; 
	      $init_clean =~ s/BLOCK\(.\)//;
	      $init_clean =~ s/DIAGONAL\(.\)//;
	      if ((($init_clean =~ m/\d/)||($init =~ m/same/i))&&($omega_area == 1)) {
		  $om_comment_flag = 1;
	      }
	      if (($init =~ m/\d/)&&($sigma_area == 1)) {$si_comment_flag = 0}
	      if (($init =~ m/\$OMEGA/)&&($init =~ m/BLOCK/)) {
		  $init =~ m/\((.*)\)/;
		  unless ($init =~ m/SAME/i) {
		      my $block_ref = om_block_structure($1);
		      @block = @$block_ref;
		  }
	      }
	      if ($init_clean =~ m/\d/) { # match numeric character
		  $init =~ s/\s//g;
		  chomp($descr);
		  if ($omega_area+$sigma_area > 0) {
		      my $n = count_numeric ($init_clean);
		      for (my $l = 0; $l < $n; $l++) { 
			  if (int(@block) > 1) {
			      $last_om = shift (@block);
			  } else {
			      $last_om = 1;
			  } 
		      }
		  }
		  $descr =~ s/\r//g; # also take care of carriage return on Windows
		  if (($theta_area == 1)&&($prior==0)) {
		      push (@th_descr, $descr); 
		  }
		  if (($omega_area == 1)&&($last_om==1)&&($sigma_flag==0)) {
		      push (@om_descr, $descr); 
		      push (@om_same, 0);
		      $om_comment_flag = 2 
		  }
		  if (($sigma_area == 1)&&($last_om==1)) {
		      push (@si_descr, $descr); 
		      $si_comment_flag = 2; 
		  }
		  if ($init =~ m/FIX/) { # match numeric character
		      if (($theta_area ==1)&&($prior==0)) {push (@th_fix, "FIX")} ;
		      if ($omega_area ==1) {push (@om_fix, "FIX")} ;
		      if ($sigma_area ==1) {push (@si_fix, "FIX")} ;
		  } else {
		      if ($theta_area ==1) {push (@th_fix, "")} ;
		      if ($omega_area ==1) {push (@om_fix, "")} ;
		      if ($sigma_area ==1) {push (@si_fix, "")} ;
		  }
	      }
	      if (($omega_area == 1)&&($sigma_flag == 0)) {
		  if (($init =~ m/SAME/)&&($init =~ m/BLOCK/)) {
		      $init =~ m/\((.*)\)/;
		      for (my $n = 0; $n < $1; $n++) {
			  push (@om_same, 1);
		      }
		      $last_om = 1;
		  } 
	      }
	      if (($om_comment_flag == 1)&&($omega_area==1)) {
		  if ($last_om == 1) {
		      my $k = 1;
		      if (($init =~ m/SAME/)&&($init =~ m/BLOCK/)) {
			  $init =~ m/\((.*)\)/;
			  $k = $1;
		      } 
		      for (my $n = 0; $n < $k; $n++) {
			  push (@om_descr, $descr);
		      }
		  }		  
	      }
	      if (($si_comment_flag == 1)&&($sigma_area==1)) {push (@si_descr, $descr);}
	  }
	  if($table_area==1) {
	      if($_ =~ s/FILE\=//) {
		  chomp ($_);
		  my $tab = $';    #'
		      $tab =~ s/^\s+//; #remove leading spaces
		  my @tabline = split(/\s/, $tab);
		  push (@tab_files, @tabline[0]);
	      }
	  }
	  if($estim_area==1) {
	      if($_ =~ s/MSF\=//) {
		  chomp ($_);
		  my $pos = length $`;
		  my @msfline = split(/\s/,substr($_, $pos));
		  $msf_file = @msfline[0];
	      }
	      my $line = $_;
	      if ( $line =~ m/METH/i ) {
		  my $offs = 7; # METHOD
		  my $pos = length ($`);
		  if (substr($line, $pos+4,1) eq "=") {$offs = 5}; # METH
		  $pos = $pos+$offs;
		  if (substr($line,$pos, 1) eq "0")      {$mod{method} = add_item($mod{method},"FO", $line)};
		  if (substr($line,$pos, 4) eq "ZERO")   {$mod{method} = add_item($mod{method},"FO", $line)};
		  if ((substr($line,$pos, 1) eq "1")&&!($line =~ m/\sLAPLAC/gi))      {$mod{method} = add_item($mod{method},"FOCE", $line)};
		  if ((substr($line,$pos, 4) eq "FOCE")&&!($line =~ m/\sLAPLAC/gi))   {$mod{method} = add_item($mod{method},"FOCE", $line)};
		  if ((substr($line,$pos, 4) eq "COND")&&!($line =~ m/\sLAPLAC/gi))   {$mod{method} = add_item($mod{method},"FOCE", $line)};
		  if ((substr($line,$pos, 6) eq "HYBRID")&&!($line =~ m/\sLAPLAC/gi)) {$mod{method} = add_item($mod{method},"HYB", $line)};
		  if (substr($line,$pos, 3) eq "ITS")    {$mod{method} = add_item($mod{method},"ITS", $line)};
		  if (substr($line,$pos, 4) eq "SAEM")   {$mod{method} = add_item($mod{method},"SAEM", $line)};
		  if (substr($line,$pos, 3) eq "IMP")    {$mod{method} = add_item($mod{method},"IMP", $line)};
		  if (substr($line,$pos, 5) eq "BAYES")  {$mod{method} = add_item($mod{method},"BAYES", $line)};
		  if ($line =~ m/ LAPL/i) {$mod{method} = add_item($mod{method},"LAPL", $line)}
	      }
	  }
      }
    }
    $mod{th_descr} = \@th_descr;
    $mod{th_init} = \@th_init;
    $mod{th_bnd_low} = \@th_bnd_low;
    $mod{th_bnd_up} = \@th_bnd_up;
    $mod{om_descr} = \@om_descr;
    $mod{om_same} = \@om_same;
    $mod{si_descr} = \@si_descr;
    $mod{th_fix} = \@th_fix;
    $mod{om_fix} = \@om_fix;
    $mod{si_fix} = \@si_fix;
    $mod{tab_files} = \@tab_files;
    $mod{msf_file} = $msf_file;
  }
  $mod{description} = $description;
  $mod{refmod} = $refmod;
  $mod{comment_lines} = \@comments;
  return (\%mod);
}

sub small_method_name {
    my $line = shift;
    my $method;
    if ($line =~ m/Iterative Two Stage/){$method = "ITS"}
    if ($line =~ m/Importance Sampling/){$method = "IMP"}
    if ($line =~ m/Stochastic Approximation Expectation-Maximization/){$method = "SAEM"}
    if ($line =~ m/Objective Function Evaluation by Importance Sampling/){$method = "OFEV-IMP"}
    if ($line =~ m/MCMC Bayesian Analysis/){$method = "MCMC-Bayes"}
    if ($line =~ m/First Order/i){$method = "FO"}
    if ($line =~ m/First Order Conditional Estimation/i){$method = "FOCE"}
    if ($line =~ m/Laplacian/i){$method .= "LAPL"}
    if ($line =~ m/with Interaction/i){$method .= "+I"}
    return ($method);
}

sub add_item {
### Purpose : Add NONMEM methods to combined string
### Compat  : W+L+
    my ($comb, $add, $line) = @_;
    if ($comb eq "") {
	$comb = $add}
    else {
	$comb .= ",".$add;
    };
    if ($line =~ m/\sINTER/) {$comb .= "+I"}   # with INTERACTION?
    return ($comb);
}


sub output_results_LaTeX {
### Purpose : Compile a HTML file that presents some run info and parameter estimates
### Compat  : W+
  my ($file, $setting_ref, $pirana_notes, $include_html_ref) = @_;
  my %setting = %$setting_ref;
  my %include_html = %$include_html_ref;
  my $run = $file;
  $run =~ s/\.$setting{ext_res}//;

# get information from NM output file
  my $res_ref = extract_from_lst ($file);
  my %res = %$res_ref;
# and get information from NM model file
  my $mod_ref = extract_from_model ($run.".".$setting{ext_ctl}, $run, "all");
  my %mod = %$mod_ref;

  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($res{resdat});
  my $html = "pirana_sum_".$file.".html";

  ### Start HTML output
  # Start LaTeX output
  my $latex = "\\documentclass[a4paper,10pt]{article}\n";
  $latex .= "\\usepackage[landscape]{geometry}\n";
  $latex .= "\\renewcommand{\\familydefault}{\\sfdefault}  % sans serif\n";
  $latex .= "\\setlength\\textwidth{12cm} \n";
  $latex .= "\\setlength\\textheight{30cm} \n";
  $latex .= "\\setlength\\oddsidemargin{-1.5cm} \n";
  $latex .= "\\setlength\\topmargin{-3cm} \n";
  $latex .= "\\usepackage{color}\n";
  $latex .= "\\usepackage[table]{xcolor} % for alternating table colors\n";
  $latex .= "\\definecolor{Grey1}{rgb}{0.9,0.9,0.9}\n";
  $latex .= "\\definecolor{Grey2}{rgb}{0.95,0.95,0.95}\n";
  $latex .= "\\begin{document}\n\n";
  $run =~ s/\_/\\\_/i;
  $run =~ s/\%/\\\%/i;
  $run =~ s/\&/\\\&/i;
  $latex .= "\\subsection*{Run summary for ".$run."}\n";

# Estimation specific info and Parameter estimates
  if (($include_html{param_est_all} == 1) || ($include_html{param_est_last}==1) ) {
      my ($methods_ref, $est_ref, $se_est_ref, $term_ref, $ofvs_ref) = get_estimates_from_lst ($file);
      my @methods = @$methods_ref;
      if ($include_html{param_est_last} == 1) {
	  @methods = @methods[(@methods-1)];
      }
      my %est = %$est_ref;
      my %se_est  = %$se_est_ref;
      my %term_res = %$term_ref;
      my %ofvs = %$ofvs_ref;
      my $meth_descr;
      my $i=1;
      foreach my $meth (@methods) {
	  if ($meth eq "NA") {
	      $meth_descr = $mod{method}  # NM 6
	  } else {
	      $meth_descr = $meth;
	  }
	  my $meth_esc = $meth;
	  $meth_esc =~ s/\#/\\\#/gi;  # insert escape estimation number
	  $latex .= "\\subsection*{Parameter estimates from ".$meth_esc."}\n";
	  $latex .= generate_LaTeX_parameter_estimates (\%res, \%mod, $est{$meth}, $se_est{$meth}, $term_res{$meth});
	  if ($i < @methods) {
	      $latex .= "\\clearpage \n"; $i++
	  }
      }
  }
  $latex .= "\\end{document}\n";
  ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
  return($latex);
}

sub generate_LaTeX_run_specific_info {
  my ($res_ref, $mod_ref, $term_ref, $ofv) = @_;
  my %res = %$res_ref;
  my %mod = %$mod_ref;
  my @term = @$term_ref;
  my $term_message_ref = @term[5];
  $$term_message_ref =~ s/\n/\<BR\>/g;
  my $latex;
  $latex .= "Objective function value: & ".$ofv."\n\n";
  $latex .= "Termination message: ".$$term_message_ref."\n\n";
  if ($mod{msf_file} ne "") {
      $latex .= "MSF file: &".$mod{msf_file}."\n\n";
  }
  return ($latex);
}

sub generate_LaTeX_parameter_estimates {
  my ($res_ref, $mod_ref, $est_ref, $se_est_ref, $term_ref) = @_;
  my %res = %$res_ref;
  my %mod = %$mod_ref;
  my @est = @$est_ref;

  my $latex;
  $latex .= "\\begin{table}[!h] \\rowcolors{1}{Grey1}{Grey2}\n";
  $latex .= "\\begin{tabular}{l l c c c c c c c c}\n";
  # Parameter estimates
  $latex .= "\\textbf{\$\\Theta\$} & \\textbf{Parameter} & \\textbf{Estimate} & & \\textbf{SE} & \\textbf{RSE} & \\textbf{95\\% CI} & \\textbf{lower} & \\textbf{init} & \\textbf{upper} \\tabularnewline \n";

  my $theta_ref = @est[0];  my @theta = @$theta_ref;
  my $theta_init_ref = $res{theta_init};  my @theta_init = @$theta_init_ref;
  my $theta_bnd_low_ref = $res{theta_bnd_low};  my @theta_bnd_low = @$theta_bnd_low_ref;
  my $theta_bnd_up_ref = $res{theta_bnd_up};  my @theta_bnd_up = @$theta_bnd_up_ref;

  my @theta_se; my @omega_se; my @sigma_se;
  my @se_est;
  if ($se_est_ref =~ m/ARRAY/) {
      @se_est = @$se_est_ref;
      if (@est>1) {
	  my $theta_se_ref = @se_est[0];  @theta_se = @$theta_se_ref;
	  my $omega_se_ref = @se_est[1];  @omega_se = @$omega_se_ref;
	  my $sigma_se_ref = @se_est[2];  @sigma_se = @$sigma_se_ref;
      }
  } 

  my $theta_names_ref = $mod{th_descr}; my @theta_names = @$theta_names_ref;
  my $theta_fix_ref = $mod{th_fix}; my @theta_fix = @$theta_fix_ref;

  my $omega_ref = @est[1];  my @omega = @$omega_ref;
  my $omega_names_ref = $mod{om_descr}; my @omega_names = @$omega_names_ref;
  my $omega_same_ref = $mod{om_same}; my @omega_same = @$omega_same_ref;

  my $sigma_ref = @est[2];  my @sigma = @$sigma_ref;
  my $sigma_names_ref = $mod{si_descr}; my @sigma_names = @$sigma_names_ref;

  my @term; my $term_info = 0; my @etabar; my @etabar_se; my @etabar_p; my @si_shrink; my @om_shrink;
  if ($term_ref =~ m/ARRAY/) {
      my @term = @$term_ref;
      my $etabar_ref = @term[0];  @etabar = @$etabar_ref;
      my $etabar_p_ref = @term[1]; @etabar_p = @$etabar_p_ref;
      my $etabar_se_ref = @term[2]; @etabar_se = @$etabar_se_ref;
      my $om_shrink_ref = @term[3];  @om_shrink = @$om_shrink_ref;
      my $si_shrink_ref = @term[4];  @si_shrink = @$si_shrink_ref;
      $term_info = 1 ;
  }
  my $col='black'; my $text="";
  my $i=0;

  # THETA
  foreach (@theta) {
      if (@theta[$i] ne "") {
	  @theta_names[$i] =~ s/\_/\\\_/i;
	  @theta_names[$i] =~ s/\%/\\\%/i;
	  @theta_names[$i] =~ s/\&/\\\&/i;
	  $latex .= ($i+1)." & ".@theta_names[$i]." & ".rnd(@theta[$i],5)." & ".@theta_fix[$i];
	  my $rse = "";
	  unless (@theta[$i] == 0) {$rse = abs(rnd(@theta_se[$i]/@theta[$i]*100,1)) };
	  if (@theta_se[$i] ne "") {
	      my $up = rnd((@theta[$i] + @theta_se[$i]),3);
	      my $low = rnd((@theta[$i] - @theta_se[$i]),3);
	      $latex .= " & ".rnd(@theta_se[$i],3)." & ".$rse." & ".$up." - ".$low." & "; 
	  }
	  else {$latex .= " & "};
	  my $low = $theta_bnd_low[$i];
	  my $up = $theta_bnd_up[$i];

	  if ($low <= -10000) {$low = "-Inf"} else {$low = rnd($theta_bnd_low[$i],3)};
	  if ($up >= 10000) {$up = "+Inf"} else {$up = rnd($theta_bnd_up[$i],3)};
	  $latex .= $low." & ".rnd(@theta_init[$i],3)." & ".$up." \\tabularnewline \n ";
	  $i++;
      }
  }
  $latex .= "\\end{tabular} \n";
  $latex .= "\\end{table} \n\n";

  # OMEGA
  $latex .= "\\begin{table}[!h] \\rowcolors{1}{Grey1}{Grey2}\n";
  $latex .= "{\\footnotesize\n";
  $latex .= "\\begin{tabular}{l l ";
  foreach (@omega) {$latex .= " c c " };
  $latex .= " c c c c }\n";
  $latex .= "\\textbf{\$\\Omega^2\$} & \\textbf{Description} & ";
  $i=1;
  foreach my $om (@omega) {$latex .= "\\textbf{".$i."} & & " ; $i++};
  if (@etabar>0) {
      $latex .= "\\textbf{Etabar (SE)} & \\textbf{p val} &";
  }
  if (@om_shrink>0) {
      $latex .= "& \\textbf{Shrinkage}";
  }
  $latex .= " \\tabularnewline \n";
  $i=0; my $om_se_x; my @om_cov_se;
  my @om_diag; my @om_se_diag;
  foreach my $om (@omega) {
      @omega_names[$i] =~ s/\_/\\\_/i;
      @omega_names[$i] =~ s/\%/\\\%/i;
      @omega_names[$i] =~ s/\&/\\\&/i;
      my @om_x = @$om; my $j = 1;
      $latex .= "".($i+1)." & ";
      $latex .= "".@omega_names[$i]." & ";
      my $bg = "";
      foreach my $om_cov (@om_x) {
        if (@omega_se>0) {$om_se_x = @omega_se[$i]; @om_cov_se = @$om_se_x;};
        if ($j == @om_x) {
	    push (@om_diag, $om_cov);
	    if ($om_cov != 0) {
		push (@om_se_diag, (@om_cov_se[$i]/$om_cov));
	    }
	} # on- or off-diagonal?
        $latex .= "".rnd($om_cov,4)." & ";
        if (($om_cov!=0)&&(@om_cov_se[$i]!=0)) {
          $latex .= "(".abs(rnd((@om_cov_se[($j-1)]/$om_cov*100),1))."\\%) & ";
        } else {
          $latex .= " & ";
        }
        $j++;
      }
      if (@etabar>0) {
        for (my $fill = $j-1; $fill<@omega; $fill++) {
          $latex .= " & & ";
        };
        my ($bg1, $bg2);
        if ($term_info == 1) { $latex .= "".rnd(@etabar[$i],3)." (".rnd(@etabar_se[$i],3).") & ".rnd(@etabar_p[$i],4)." & "; }
      }
      if (@om_shrink>0) {
	  $latex .= "".rnd($om_shrink[$i],1)."\\% &";
      }
      $latex .= "\\tabularnewline \n";
      $i++;
  }
  $latex .= "\\end{tabular} \n\n";
  $latex .= "}\n";
  $latex .= "\\end{table} \n\n";

  # OMEGA sd scale
  $latex .= "\\begin{table}[!h] \\rowcolors{1}{Grey1}{Grey2}\n";
  $latex .= "{\\footnotesize \n";
  $latex .= "\\begin{tabular}{l l ";
  foreach (@omega) {$latex .= " c c c " };
  $latex .= " c c c }\n";
  $latex .= "\\textbf{\$\\Omega\$} & \\textbf{Description} & ";

  $i=1;
  foreach my $om (@omega) {$latex .= "\\textbf{".$i."} & & " ; $i++};
  $latex .= " \\tabularnewline \n";
  $i=0; my $om_se_x; my @om_cov_se;
  foreach my $om (@omega) {
      my @om_x = @$om; my $j = 1;
      if (@omega_same[$i] == 0) {
      $latex .= "".($i+1)." & ";
      $latex .= "".@omega_names[$i]." & ";
      my $bg = "";
      my $diag = 1;
      foreach my $om_cov (@om_x) {
	  if (@omega_se>0) {
	      $om_se_x = @omega_se[$i];
	      @om_cov_se = @$om_se_x;
	  }
	  my $corr;
	  if ($j == @om_x) {
	      $latex .= "".rnd(sqrt(abs($om_cov))*100,1)."\\% &";
	  } else {
	      my $corr_denom = sqrt(@om_diag[$i])*sqrt(@om_diag[($j-1)]) ;
	      if ($corr_denom != 0) {
		  $corr = ($om_cov / $corr_denom);
		  $latex .= rnd ( 100 * $corr , 1)."\\% & ";
	      } else {
		  $latex .= "-";
	      }
	  }

	  # uncertainty in correlation
	  if (($om_cov!=0)&&(@om_cov_se[$i]!=0)) {
	      if ($j == @om_x) { # diagonal: just divide u_var by 2
		  $latex .= "(".abs(rnd((@om_cov_se[$i]/$om_cov*100/2),1))."\\%) &";
	      } else {
		  $latex .= " & ";
	      }
	  } else {
	      $latex .= " & ";
	  }
	  $j++;
      }
      for (my $fill = $j-1; $fill<@omega; $fill++) {
          $latex .= " & & ";
      };
      $latex .= "\\tabularnewline \n";
      }
      $i++;
  }
  $latex .= "\\end{tabular} \n\n";
  $latex .= "}\n";
  $latex .= "\\end{table} \n\n";

  # SIGMA
  $latex .= "\\begin{table}[!h] \\rowcolors{1}{Grey1}{Grey2}\n";
  $latex .= "{\\footnotesize\n";
  $latex .= "\\begin{tabular}{l l ";
  foreach (@sigma) {$latex .= " c c " };
  $latex .= " c c c}\n";

  $latex .= "\\textbf{\$\\Sigma^2\$} & \\textbf{Description} & \n";

  $i=1;
  foreach my $si (@sigma) {$latex .= "\\textbf{".$i."}  & & " ; $i++};
  if (@si_shrink>0) {
      $latex .= "\\textbf{Shrinkage} & ";
  }
  $latex .= "\\tabularnewline \n";
  $i=0; my $si_se_x; my @si_cov_se; my $bg;
  my @si_diag; my @si_se_diag;
  foreach my $si (@sigma) {
      @sigma_names[$i] =~ s/\_/\\\_/i;
      @sigma_names[$i] =~ s/\%/\\\%/i;
      @sigma_names[$i] =~ s/\&/\\\&/i;
      my @si_x = @$si; my $j = 1;
      $latex .= "".($i+1)." & ";
      $latex .= " ".@sigma_names[$i]." & ";
      foreach my $si_cov (@si_x) {
        if (@sigma_se>0) {$si_se_x = @sigma_se[$i]; @si_cov_se = @$si_se_x;};
        if ($j == @si_x) {
	    push (@si_diag, $si_cov);
	    if ($si_cov != 0) {
		push (@si_se_diag, (@si_cov_se[$i]/$si_cov));
	    }
	} 
        $latex .= " ".rnd($si_cov,4)." & ";
        if (($si_cov!=0)&&(@si_cov_se[$i]!=0)) {
          $latex .= "(".rnd((@si_cov_se[$i]/$si_cov*100),3)."\\%) & ";
        } else {
          $latex .= " & ";
        }
        $latex .= " & ";
        $j++;
      }
      if (@si_shrink>0) {
	  $latex .= rnd(@si_shrink[$i],1)."\\% & ";
      }
      $latex .= "\\tabularnewline \n";
      $i++;
  }
  $latex .= "\\end{tabular}\n";
  $latex .= "}\n";
  $latex .= "\\end{table}\n";

  return($latex);
}

### subroutines for converting $DES to R
# interpret_pk_block_for_ode rh_convert_array extract_nm_block interpret_des translate_des_to_R

sub interpret_pk_block_for_ode {
# get variable declarations made in $PK: try to obtain initial estimates
    my ($pk_block, $vars_not_decl_ref) = @_;
    my %vars_not_decl_upd = %$vars_not_decl_ref;
    my @lines = split ("\n", $pk_block);
    my %vars_decl_pk;
    my @pk_vars_order;
    foreach my $line (@lines) {
	my ($line, $rest) = split (";", $line);
	$line =~ s/\s//g;
	if ($line =~ m/=/) {
	    my ($lh, $rh) = split ("=", $line);
	    if ($rh =~ m/THETA\((.*)\)/) {
		my $th_1 = $1;
		($th_1, my $rest) = split (/\)/, $th_1); # split of eta or other garbage
		$rh = "theta[".$th_1."]" ;
	    }
	    $lh =~ s/\s//g;
	    if ((exists ($vars_not_decl_upd{$lh})||($rh =~ m/eta/))) {
		$vars_decl_pk{$lh} = $rh;
		push (@pk_vars_order, $lh);
	    }
	}
    }
    return (\%vars_decl_pk, \@pk_vars_order)
}

sub rh_convert_array {
# convert NONMEM's ODE array to R: substitute () for []
# and also put in p["VAR"], and handle brackets
    my $rh = shift;
    my @rh_elem = split (/(\*|\+|\-|\/|\^|\(|\))/, $rh);
    my $rh_R = "";
    my %vars_decl;
    my $prv_elem; my $a_area = 0;
    foreach my $el (@rh_elem) {
	my $t = $el;
	$t =~ s/a/A/g;
	if ($prv_elem eq "A") {$a_area = 1};
	if ($a_area == 1) {
	    $t =~ s/\(/\[/;
	    $t =~ s/\)/\]/;
	    $a_area = 1;
	} else {
	    unless (($t eq "")||($t =~ m/(\*|\+|\-|\/|\^|\(|\))/)|(exists($vars_decl{$t}))) {
		if ((is_float($t))||($t =~ m/(SQRT|ABS)/)||($t eq "A")) {
		    $t = $t;
		} else {
		    $t = 'p$'.$t;
		}
	    }
	    # if ($t =~ m /(\*|\/|\^)/) {  # beautify code
	    # 	$t = " ".$t." ";
	    # }
	}
	$t =~ s/SQRT/sqrt/g;
	$t =~ s/ABS/sqrt/g;
	if ($el =~ m/\)/) {$a_area = 0};
	$prv_elem = $el;
	$rh_R .= $t;
    }
    return($rh_R);
}

sub extract_nm_block {
# Descr: extract $DES or $PK block from NM control stream
    my ($mod_file, $block) = @_;
    open (MOD, "<".$mod_file);
    my @lines = <MOD>;
    my $in_block = 0;
    my $block_text = "";
    foreach my $line (@lines) {
	if (substr($line,0,1) eq "\$") {
	    $in_block = 0;
	}
	if (substr($line, 0, (length($block)+1)) eq "\$".$block) {
	    $in_block = 1;
	}
	if ($in_block == 1) {
	    $block_text .= $line;
	}
    }
    close (MOD);
    return($block_text);
}

sub interpret_des {
# read in code, convert to hashes / arrays
    my $text = shift;
    my @des = split ("\n", $text);
    my %des_descr; # descriptions of ODEs
    my %des_rh;    # right-hand side of ODEs
    my %vars_decl; # declared variables
    my @vars;
    my %vars_dum;
    my @vars_decl_dum;
    foreach my $des_line (@des) {
	my $ode = 0;
	$des_line =~ s/^\s+//; #remove leading spaces
	$des_line =~ s/\s+$//; #remove trailing spaces
	my ($des_cont, $dadt_descr) = split (";", $des_line);
	$des_cont =~ s/\*\*/\^/g;
	if (substr($des_cont,0,4) =~ m/\$DES/i) {
	    # recognize des declaration
	}
	my $if_constr = 0;
	if ($des_cont =~ m/(IF\(|IF \()/i) {
	    $if_constr = 1;
	}
	if (substr($des_cont,0,4) =~ m/\DADT/i) { 	# recognize ode line
	    $ode = 1;
	    my ($dadt_n, $dadt_rh) = split ("=", $des_cont);
	    $dadt_n =~ s/DADT//i;
	    $dadt_n =~ s/\(//i;
	    $dadt_n =~ s/\)//i;
	    $dadt_n =~ s/\s//ig;
	    $dadt_rh =~ s/\s//ig;
	    $des_rh{$dadt_n} = $dadt_rh;
	}
	if (($ode == 0)&&($if_constr==0)) { # no $DES line, no ODE line. Maybe contains other declaration
	    if ($des_cont =~ m/\=/) { # declaration
		my ($var, $var_rh) = split ("=", $des_cont);
		$var =~ s/\s//g;
		$var_rh =~ s/\s//g;
		push(@vars_decl_dum, $var);
		$vars_decl{$var} = $var_rh;
	    }
	}

	# extract variables
	if (($des_cont =~ m/\=/)&&($if_constr==0)) { # declaration
	    my ($var, $var_rh) = split ("=", $des_cont);
	    my @rh_elem = split (/(\*|\+|\-|\/|\^)/, $var_rh);
	    foreach my $elem (@rh_elem) {
		unless (($elem =~ m/A\(/i)||($elem =~ m/(\*|\+|\-|\/|\^)/)||($elem eq "")) {
		    $elem =~ s/(\(|\))//g;
		    $elem =~ s/\s//;
		    unless (is_float($elem)) { # unless numeric, this is a variable
			unless (exists($vars_dum{$elem})) {
			    push (@vars, $elem);
			    $vars_dum{$elem} = "";
			}
		    }
		}
	    }
	}
    }
# create array with undeclared variables
    my %vars_not_decl;
    my @vars_not_decl_dum;
    foreach (@vars) {
	unless (exists($vars_decl{$_})) {
	    unless ($_ eq "") {
		$vars_not_decl{$_} = 1;
		push (@vars_not_decl_dum, $_);
	    }
	}
    }
    return (\%des_rh, \%des_descr, \%vars_decl, \@vars_decl_dum, \%vars_not_decl, \@vars_not_decl_dum)
}

sub translate_des_to_BM {
    my ($des_rh_ref, $des_descr_ref, $vars_decl_ref, $vars_decl_dum_ref, $vars_pk_decl_ref, $vars_pk_order_ref, $est_ref) = @_;
    my %des_rh = %$des_rh_ref;
    my %des_descr = %$des_descr_ref;
    my %vars_decl = %$vars_decl_ref;
    my @vars_decl_dum = @$vars_decl_dum_ref;
    my %vars_pk_decl = %$vars_pk_decl_ref;
    my @vars_pk_order= @$vars_pk_order_ref;
    my $BM_code;

# parameter estimates
    my @est = @$est_ref;
    my $theta_ref = @est[0];  my @th = @$theta_ref;
#    my $omega_ref = @est[1];  my @om = @$omega_ref;
#    my $sigma_ref = @est[2];  my @si = @$sigma_ref;

# translate to R / deSolve code
    my @n = sort (keys (%des_rh));
    my @n_init = @n;
    foreach (@n_init) {$_ = 0};
    my $BM_code = "METHOD RK4\n";
    $BM_code .= "STARTTIME = 0\n";
    $BM_code .= "STOPTIME=24\n";
    $BM_code .= "DT = 0.02\n\n";
    $BM_code .= ";### Settings\n";
    foreach my $comp (@n) {
	$BM_code .= "init A".$comp." = 0 \n";
    }
    $BM_code .= "\n";
    $BM_code .= "theta [1..".int(@th)."] = 0\n";
    my $i = 1; foreach (@th) {
	$BM_code .= "theta[".$i."] = ".(rnd ($_,3))."\n";
        $i++;
    }
    $BM_code .= "\n";

     my $max_length = get_max_length_in_array (@vars_pk_order);
     my $i=1;
     foreach my $var ( @vars_pk_order ) {
 	my $space_no = ($max_length - length($var)) ;
 	my $space = " " x $space_no;
 	$BM_code .= $var . $space.' = '.$vars_pk_decl{$var}."\n";
 	$i++;
     };

    $BM_code .= "\n;### ODE system\n";
# $R_code .= ODEs
    foreach my $n_ode (@n) {
	my $code = rh_convert_array($des_rh{$n_ode});
	my $code = $des_rh{$n_ode};
	$code =~ s/(\(|\))//g;
	$BM_code .= "d\/dt (A".$n_ode.") = ".$code."\n";
    }

    return($BM_code);
}

sub translate_des_to_R {
    my ($des_rh_ref, $des_descr_ref, $vars_decl_ref, $vars_decl_dum_ref, $vars_pk_decl_ref, $vars_pk_order_ref, $est_ref) = @_;
    my %des_rh = %$des_rh_ref;
    my %des_descr = %$des_descr_ref;
    my %vars_decl = %$vars_decl_ref;
    my @vars_decl_dum = @$vars_decl_dum_ref;
    my %vars_pk_decl = %$vars_pk_decl_ref;
    my @vars_pk_order= @$vars_pk_order_ref;
    my $R_code;

# parameter estimates
    my @est = @$est_ref;
    my $theta_ref = @est[0];  my @th = @$theta_ref;
    #my $omega_ref = @est[1];  my @om = @$omega_ref;
    #my $sigma_ref = @est[2];  my @si = @$sigma_ref;

# translate to R / deSolve code
    my @n = sort (keys (%des_rh));
    my @n_init = @n;
    foreach (@n_init) {$_ = 0};
    $R_code .= "### Settings\n";
    $R_code .= "A_init <- c(".join(",",@n_init).")  # Initial state of ODE system\n";
    $R_code .= "times  <- seq(from=0, to=24, by=0.1)  # Integration window and stepsize \n";
    $R_code .= "obs_c  <- c(1:".@n_init.")  # Observation compartments \n";
    $R_code .= "n_ind  <- 20\n";
    my $n_par = 0;
    foreach (@vars_pk_order) {
	if ($vars_pk_decl{$_} =~ m/theta/) {
	    $n_par++;
	}
    }
    $R_code .= "n_par  <- ".$n_par."\n\n";
    $R_code .= "### Parameters\n";
    $R_code .= "theta <- c(";
    my $i = 1; foreach (@th) {
	$R_code .= (rnd ($_,3));
	unless ($i == int(@th)) {
	    $R_code .= ", ";
	}
        $i++;
    }
    $R_code .= ")\n";
    $R_code .= "omega  <- diag(.01, n_par)  # 10% iiv in each parameter\n";
    $R_code .= "etas   <- mvrnorm(n = n_ind, mu=rep(0, n_par), Sigma=omega )\n\n";
    $R_code .= "draw_params <- function (eta) {\n";
    $R_code .= "  p <- list()  # Parameter list \n";

    my $max_length = get_max_length_in_array (@vars_pk_order);
    my $i=1; my $eta_par = 1;
    foreach my $var (@vars_pk_order ) {
	my $space_no = ($max_length - length($var)) ;
	my $space = " " x $space_no;
	
	# for variables declared in right-hand side, put p$ in front
	$vars_pk_decl{$var} =~ s/\s//g;
	my @eq = split (/(\*|\+|\-|\/|\^|\(|\))/, $vars_pk_decl{$var});
	my $j = 0; my $eq_str;
	foreach (@eq) {
	    unless ((is_float($_))||($_ =~ m /(\*|\+|\-|\/|\^|\(|\))/)||($_ =~ m/theta/)) { # unless numeric, this is a variable
		$_ = "p\$".$_;
	    }
	    $eq_str .= $_;
	    $j++;
	}
	$vars_pk_decl{$var} = $eq_str;

	my $eta ;
	if ($vars_pk_decl{$var} =~ m/theta/) {
	    $eta = " * exp(eta[".$eta_par."])"; 
	    $eta_par++;
	}
	$R_code .= '  p$'.$var.$space.' <- '.$vars_pk_decl{$var}." ".$eta;
	$R_code .= "\n";
	$i++;
    };


    $R_code .= "  return(p)\n";
    $R_code .= "}\n\n";

    my @n = sort (keys (%des_rh));
    $R_code .= "### ODE system\n";
    $R_code .= "des <- function (t, A, p) {  # ODE system \n";

# $R_code .= declared variables
    foreach( @vars_decl_dum ) {
	$R_code .= "  p\$".$_." <- ".rh_convert_array($vars_decl{$_})."\n";
    };

# $R_code .= ODEs
    foreach my $n_ode (@n) {
	$R_code .= "  dAdt_".$n_ode." <- ".rh_convert_array($des_rh{$n_ode})."\n";
    }

# $R_Code .= list of ODE-array to return
    $R_code .= "  return ( list ( c ( ";
    my $i=1;
    foreach my $n_ode (@n) {
	$R_code .= "dAdt_".$n_ode;
	if ($i < @n) {
	    $R_code .= ", ";
	} else {$R_code .= " ) ) )\n";}
	$i++;
    }
    $R_code .= "}\n\n";

    $R_code .= "### Perform numerical integration, collect data\n";
    $R_code .= "pl_dat <- c()\n";
    $R_code .= "for (i in 1:n_ind) {\n";
    $R_code .= "  p_ind <- draw_params (eta = etas[i,])\n";
    $R_code .= "  des_out <- lsoda(A_init, times, des, p_ind)\n";
    $R_code .= "  for (j in 1:length(obs_c)) { \n";
    $R_code .= "    pl_dat <- rbind (pl_dat, cbind(i, t=des_out[,1], comp=obs_c[j], ipred=des_out[,(obs_c[j]+1)]))\n";
    $R_code .= "  }\n";
    $R_code .= "}\n\n";
    $R_code .= "### Plot\n";
    $R_code .= "xyplot ( ipred~t|as.factor(comp), group=i, data=data.frame(pl_dat),\n";
    $R_code .= "         type='l', col='lightblue' )\n";
    return($R_code);
}

sub detect_nm_version {
 my ($nm_path) = @_;
  
 #INPUT variable that contains NM path
 #my $nm_path = '/opt/nonmem/nm7_gf_reg';
 my $nm_pathfull = $nm_path.'/util';

 # search for nmfe files
 my @nm_files = dir($nm_pathfull, "nmfe");
 my $nm_file = shift(@nm_files);
 
 # extract version number
 my ($nm_file2) = $nm_file =~ /(\d+)/;

 # output
 return($nm_file2);
}


1;
