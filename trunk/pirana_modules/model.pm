# Subroutines that perform actions on NM modelfiles or NM results files

package pirana_modules::model;

use strict;
require Exporter;
use File::stat;
use pirana_modules::misc  qw(rnd); 

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(change_seed get_estimates_from_lst extract_from_model extract_from_lst extract_th extract_cov blocks_from_estimates duplicate_model get_cov_mat output_results_HTML);

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


sub get_estimates_from_lst {
### Purpose : Get parameter estimates from NM output file
### Compat  : W+
  my $file = shift; 
  open (LST, "<".$file);
  my @lst = <LST>;
  my $th_area=0; my $om_area=0; my $si_area=0; my $se_area=0;
  my @th; my @om; my @si; my @th_se; my @om_se; my @si_se;
  foreach my $line (@lst) {
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
    if ($th_area == 1) {
      unless ($line =~ m/TH/) {
        if ($se_area == 0) {
          push (@th, extract_th ($line));
        } else {
          push (@th_se, extract_th ($line));
        }
      }
    }
    if ($om_area == 1) {
      unless ($line =~ m/ET/) {
        if ($line =~ m/\./ ) {
          chomp($line);
          if ($se_area == 0) {
            push (@om, extract_cov ($line));
          } else {
            push (@om_se, extract_cov ($line));
          }
        }
      }
    }
    if ($si_area == 1) {
      unless ($line =~ m/EP/) {
        if ($line =~ m/\./ ) {
          chomp($line);
          if ($se_area == 0) {
            push (@si, extract_cov ($line));
          } else {
            push (@si_se, extract_cov ($line));
          }
        }
      }
    }
    if (substr($line,0,1) eq "1") {
      $th_area=0;
      $om_area=0;
      $si_area=0;
    }
  } 
  close LST;
  return (\@th, \@om, \@si, \@th_se, \@om_se, \@si_se);
}

sub extract_th {
### Purpose : Extract parameter values from a line in a NM results file
### Compat  : W+L+
  my $line = shift;
  my @sp;
  my @raw_split = split (" ",$line);
  my $i=0;
  foreach (@raw_split) {
    unless ($_ eq "") {
      $_ =~ s/\s//g;
      push (@sp, $_);
      $i++;
    }
  }
  return (@sp);
}

sub extract_cov {
### Purpose : Extract se of parameter values from a line in a NM results file
### Compat  : W+L+
  my $line = shift;
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
  my ($th_ref, $om_ref, $si_ref, $th_se_ref, $om_se_ref, $si_se_ref) = get_estimates_from_lst ($lstfile);
  my @th = @$th_ref; my @om = @$om_ref; my @si = @$si_ref;
  my $fix_str = "";
  if ($fix==1) {$fix_str = " FIX"}

# get information from NM model file
  my $modelfile = $model.".".$setting{ext_ctl};
  my $mod_ref = extract_from_model ($modelfile, $model, "all");
  my %mod = %$mod_ref;
  
  my $th_descr_ref = $mod{th_descr};
  my @th_descr = @$th_descr_ref;
  my $om_descr_ref = $mod{om_descr};
  my @om_descr = @$om_descr_ref;
  my $si_descr_ref = $mod{om_descr};
  my @si_descr = @$si_descr_ref;
  
  my ($th_block, $om_block, $si_block) = "";
  my $i=0;
  foreach (@th) {
    $th_block .= rnd($th[$i],4).$fix_str." ;".@th_descr[$i]."\n"; 
    $i++;
  }
  $i=0;
  foreach (@om) {
    my @om_n = @$_;
    foreach (@om_n) {
      unless ($_ == 0) {
        $om_block .= rnd($_,4).$fix_str." ;".@om_descr[$i]."\n";
      }
    }
    $i++;
  }
  $i=0;
  foreach (@si) {
    my @si_n = @$_;
    foreach (@si_n) {
      unless ($_ == 0) {
        $si_block .= rnd($_,4).$fix_str." ;".@si_descr[$i]."\n";
      }
    }
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
  if ($new_ctl_descr eq "") {$new_ctl_descr = $mod{description};}
  my ($th_block, $om_block, $si_block) = blocks_from_estimates($file, $fix_est, \%setting);
  my @omegas = split (/\n/,$om_block);
  my @sigmas = split (/\n/,$si_block);
  my ($th_area, $om_area, $si_area);
  my @ctl_new; my $om_line=0; my $si_line=0;
  
  open (CTL_IN, "<".$file);
  my @ctl_lines=<CTL_IN>; close CTL_IN;
  open (CTL_OUT, ">".$new_file);
  if (($change_run_nos==1)||($est_as_init==1)) {
    my $i=0; while (@ctl_lines[$i]) {
    if (@ctl_lines[$i]  =~ /\$TABLE/ ) {@ctl_lines[$i] =~ s/$runno/$new_runno/i;};
    if (@ctl_lines[$i-1]=~ /\$TABLE/ ) {unless (@ctl_lines[$i]=~m/$new_runno/) {@ctl_lines[$i] =~ s/$runno/$new_runno/i}};
    if (@ctl_lines[$i-2]=~ /\$TABLE/ ) {unless (@ctl_lines[$i]=~m/$new_runno/) {@ctl_lines[$i] =~ s/$runno/$new_runno/i}};
    if (@ctl_lines[$i]  =~ /RUN/ ) {@ctl_lines[$i] =~ s/$runno/$new_runno/i}; 
    if (@ctl_lines[$i]  =~ /MSF/ ) {@ctl_lines[$i] =~ s/$runno/$new_runno/i};
    if ((substr(@ctl_lines[$i],0,1) eq "\$")&&(substr(@ctl_lines[$i],0,6) ne "\$THETA")) {$th_area=0};
    if ((substr(@ctl_lines[$i],0,1) eq "\$")&&(substr(@ctl_lines[$i],0,6) ne "\$OMEGA")) {$om_area=0};
    if ((substr(@ctl_lines[$i],0,1) eq "\$")&&(substr(@ctl_lines[$i],0,6) ne "\$SIGMA")) {$si_area=0};
    if ((substr(@ctl_lines[$i],0,6) eq "\$THETA")&&($est_as_init==1)&&($th_area==0)) {$th_area=1; push (@ctl_new, "\$THETA\n".$th_block."\n")};
    if ((substr(@ctl_lines[$i],0,6) eq "\$OMEGA")&&($est_as_init==1)&&($om_area==0)) {$om_area=1; $om_line=0};
    if ($om_area==1) {
      if (substr(@ctl_lines[$i],0,15) =~ m/\$OMEGA/ ) {  #
        push (@ctl_new, @ctl_lines[$i]);
      } else {
        push (@ctl_new, @omegas[$om_line]."\n");
          $om_line++;
      }
    }
    if ((substr(@ctl_lines[$i],0,6) eq "\$SIGMA")&&($est_as_init==1)&&($si_area==0)) {$si_area=1; $si_line=0};
      if ($si_area==1) {
        if (substr(@ctl_lines[$i],0,15) =~ m/\$SIGMA/ ) {  #
          push (@ctl_new, @ctl_lines[$i]);
        } else {
          push (@ctl_new, @sigmas[$si_line]."\n");
          $si_line++;
        }
      }
      unless ((($th_area==1)||($om_area==1)||($si_area==1))&&($est_as_init==1)) {push (@ctl_new,@ctl_lines[$i]);}
      $i++;
    }
  } else {
    @ctl_new = @ctl_lines;
  }
  if ($new_ctl_descr ne "") { print CTL_OUT "; Model desc: ".$new_ctl_descr."\n"; }
  if ($new_ctl_ref ne "") { print CTL_OUT "; Ref. model: ".$new_ctl_ref."\n"; }
  print CTL_OUT "; Duplicated from: ".$runno."\n";
  if (@ctl_new[0] =~ m/Model desc/i) {shift @ctl_new};
  if (@ctl_new[0] =~ m/Ref\. model/i) {shift @ctl_new};
  print CTL_OUT @ctl_new;  
  close CTL_OUT;
}


sub get_cov_mat {
### Purpose : Get varcov matrix from NM model file and return as array refs
### Compat  : W+
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
  my $eigen_area; my @etabar; my @etabar_se; my @etabar_p; my $minim_text;
  my @th; my @om; my @si; my @th_se; my @om_se; my @si_se; my @eig; my $e;
  my %all; my $feval; my $sig; my @bnd_low; my @bnd_up; my @bnd_th; my @th_init;
  my $j=0; 
  foreach my $line (@lst) {
    if (($line =~ m/MINIMUM VALUE OF OBJECTIVE FUNCTION/)&&($all{ofv} eq "")) {
      $all{ofv} = @lst[$j+9];
      $all{ofv} =~ s/\*//g;
      $all{ofv} =~ s/\s//g;
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
     
    if ($line =~ m/EIGENVALUES/) {
      $eigen_area = 1;
      $e=0;
    }
    if ($eigen_area == 1) {
      $e++;
      if (($e>7)&&($e<11)) {
        push (@eig, extract_th($line));
      }
    }
    if ($line =~ m/ETABAR:/) {
      $etabar_area = 1;
    }
    if ($etabar_area == 1) {
      if ($line =~ m/ETABAR:/) {push (@etabar, extract_th(substr($line,8)))}
      if ($line =~ m/SE:/) {push (@etabar_se, extract_th(substr($line,8)))}
      if ($line =~ m/P VAL.:/) {push (@etabar_p, extract_th(substr($line,8)))}
    }
    if ($th_area == 1) {
      unless ($line =~ m/TH/) {
        if ($se_area == 0) {
          push (@th, extract_th ($line));
        } else {
          push (@th_se, extract_th ($line));
        }
      }
    }
    if ($om_area == 1) {
      unless ($line =~ m/ET/) {
        if ($line =~ m/\./ ) {
          chomp($line);
          if ($se_area == 0) {
            push (@om, extract_cov ($line));
          } else {
            push (@om_se, extract_cov ($line));
          }
        }
      }
    }
    if ($si_area == 1) {
      unless ($line =~ m/EP/) {
        if ($line =~ m/\./ ) {
          chomp($line);
          if ($se_area == 0) {
            push (@si, extract_cov ($line));
          } else {
            push (@si_se, extract_cov ($line));
          }
        }
      }
    }
    if (substr($line,0,1) eq "1") {
      $th_area=0;
      $om_area=0;
      $si_area=0;
    }
    $j++;
  } 
  close LST;
  if(-e $file) {$all{resdat} = stat($file) -> mtime};
  $all{theta} = \@th;
  $all{theta_init} = \@th_init;
  $all{theta_bnd_low} = \@bnd_low;
  $all{theta_bnd_up} = \@bnd_up;
  $all{omega} = \@om;
  $all{sigma} = \@si;
  $all{theta_se} = \@th_se;
  $all{omega_se} = \@om_se;
  $all{sigma_se} = \@si_se;
  $all{minim_text} = $minim_text;
  @eig = sort { $a <=> $b } @eig;
  if (@eig[0] != 0) {
    $all{cond_nr} = @eig[-1]/@eig[0];
  }
  $all{etabar} = \@etabar;
  $all{etabar_se} = \@etabar_se;
  $all{etabar_p} = \@etabar_p;
  return \%all;
}

sub output_results_HTML {
### Purpose : Compile a HTML file that presents some run info and parameter estimates 
### Compat  : W+
  my ($file, $setting_ref) = @_;
  my %setting = %$setting_ref;
  my $run = $file;
  $run =~ s/\.$setting{ext_res}//;

# get information from NM output file 
  my $res_ref = extract_from_lst ($file);
  my %res = %$res_ref;
# and get information from NM model file
  my $mod_ref = extract_from_model ($run.".".$setting{ext_ctl}, $run, "all");
  my %mod = %$mod_ref;
  my $etabar_ref = $res{etabar};  my @etabar = @$etabar_ref;
  my $etabar_se_ref = $res{etabar_se};  my @etabar_se = @$etabar_se_ref;
  my $etabar_p_ref = $res{etabar_p};  my @etabar_p = @$etabar_p_ref;
 
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($res{resdat}); 
  my $html = "pirana_sum.html";
  
  ### Start HTML output
  open (HTML,">".$html);
  print HTML "<HTML><HEAD><STYLE>\n";
  print HTML "TD {font-family:Verdana,arial; font-size:0.8em}\n";
  print HTML ".stats {background-color: #F3F3F3}\n";
  print HTML ".theta {background-color: #F3F3F3; text-align:left; font-size:0.7em}\n";
  print HTML ".omega {background-color: #F3F3F3; text-align:right; font-size:0.7em}\n";
  print HTML ".sigma {background-color: #F3F3F3; text-align:right; font-size:0.7em}\n";
  print HTML ".matrix {background-color: #F3F3F3}\n";
  print HTML "A {font-family:Verdana,arial; font-size:0.8em}\n";
  print HTML "</STYLE></HEAD><BODY>&nbsp;<BR>\n";
  print HTML "<TABLE border=0 cellpadding=2 cellspacing=0 CLASS='stats' width=600>\n";
  print HTML "<TR><TD bgcolor='#000000' colspan=3><B><FONT color='#FFFFFF'>Run statistics:</FONT></B></TD></TR>\n";
  print HTML "<TR><TD>Run number</TD><TD><FONT FACE=verdana,arial size=2 color='darkred'><B>".$mod{mod}."</B></FONT></TD></TR>\n";
  print HTML "<TR><TD>Reference model</TD><TD><FONT FACE=verdana,arial size=2>".$mod{refmod}."</FONT></TD></TR>\n";
  print HTML "<TR><TD>Description</TD><TD><FONT FACE=verdana,arial size=2>".$mod{description}."</FONT></TD></TR>\n";
  
  print HTML "<TR><TD>Nonmem output file</TD><TD><A href='".$file."'>".$file."</A></TD><TD></TD></TR>\n";
  print HTML "<TR><TD>Output file date</TD><TD>".($year+1900)."-".($mon+1)."-".$mday.", $hour:$min:$sec</TD><TD></TD></TR>\n";
  
  print HTML "<TR><TD>Minimization successful</TD><TD>";
  if ($res{suc} eq "S") {print HTML "Yes"};
  if ($res{suc} eq "T") {print HTML "No, terminated."};
  print HTML "</TD><TD></TD></TR>\n"; 
  print HTML "<TR><TD>Objective function value</TD><TD>".$res{ofv}."</TD><TD></TD></TR>\n";
  print HTML "<TR><TD>Function evaluations</TD><TD>".$res{feval}."</TD><TD></TD></TR>\n";
  print HTML "<TR><TD>Significant digits</TD><TD>".$res{sig}."</TD><TD></TD></TR>\n";
  print HTML "<TR><TD>Covariance step successful</TD><TD>";
  if ($res{cov} eq "C") {print HTML "Yes"} else {print HTML "No. "};
  if ($res{cov} eq "M") {  
    print HTML "Singular matrix\n";
  }
  print HTML "</TD></TR>\n";
  print HTML "<TR><TD valign='top'>Minimization text</TD><TD width=390><FONT size=-2>";
  print HTML $res{minim_text};
  print HTML "</FONT></TD></TR>\n";
  
  print HTML "<TR><TD>Condition number</TD><TD>";
  if ($res{cond_nr} ne "") {
    printf HTML ("%.2f",$res{cond_nr}); 
  } else {
    print HTML "NA";
  }
  print HTML "</TD><TD></TD></TR>\n";
    
  print HTML "<TR><TD>Estimate near boundary</TD><TD>";
  if ($res{bnd} eq "B") {print HTML "Yes"} else {print HTML "No"}; 
  print HTML "</TD><TD></TD></TR>\n";
  print HTML "</TD><TD></TD></TR>\n";
  
  print HTML "<TR><TD>MSF file:</TD><TD>";
  print HTML $mod{msf_file}; 
  print HTML "</TD><TD></TD></TR>\n";
  
  print HTML "<TR><TD>Table files:</TD><TD>";
  my $tables_ref = $mod{tab_files};
  my @tables = @$tables_ref;
  foreach (@tables) {
    unless (-e $_) {$_ .= " (not found)"}
  }
  print HTML join("<BR>\n", @tables); 
  print HTML "</TD><TD></TD></TR>\n";
  print HTML "</TABLE>\n<P>\n";

# Parameter estimates
  print HTML "<TABLE border=0 cellpadding=2 cellspacing=0 CLASS='theta'>\n";
  print HTML "<TR bgcolor='#000000'><TD colspan=9><B><FONT color='#FFFFFF'>Final parameter estimates:</FONT></B></TD></TR>";
  print HTML "<TR bgcolor='#C0D0FF'><TD width=200 colspan=2><B>Theta</B></TD><TD width=80 align=left><B>Estimate*</B></TD><TD width=50></TD><TD width=80 align=RIGHT><B>SE</B></TD><TD width=80 align=RIGHT><B>RSE**</B></TD><TD align='left'>[ lower, </TD><TD align='center'>init,</TD><TD> upper]</TD><TR>\n";
  
  my $theta_ref = $res{theta};  my @theta = @$theta_ref;
  my $theta_init_ref = $res{theta_init};  my @theta_init = @$theta_init_ref;
  my $theta_bnd_low_ref = $res{theta_bnd_low};  my @theta_bnd_low = @$theta_bnd_low_ref;
  my $theta_bnd_up_ref = $res{theta_bnd_up};  my @theta_bnd_up = @$theta_bnd_up_ref;
    
  my $theta_se_ref = $res{theta_se};  my @theta_se = @$theta_se_ref;
  my $theta_names_ref = $mod{th_descr}; my @theta_names = @$theta_names_ref;
  my $theta_fix_ref = $mod{th_fix}; my @theta_fix = @$theta_fix_ref;
  my $omega_ref = $res{omega};  my @omega = @$omega_ref;
  my $omega_se_ref = $res{omega_se};  my @omega_se = @$omega_se_ref;
  my $omega_names_ref = $mod{om_descr}; my @omega_names = @$omega_names_ref;
  my $sigma_ref = $res{sigma};  my @sigma = @$sigma_ref;
  my $sigma_se_ref = $res{sigma_se};  my @sigma_se = @$sigma_se_ref;
  my $sigma_names_ref = $mod{si_descr}; my @sigma_names = @$sigma_names_ref;

  my $col='black'; my $text="";
  my $i=0;
  foreach (@theta) {
    
    print HTML "<TR>";
    if (@theta[$i] ne "") {print HTML "<TD width=40 bgcolor='#C0D0FF' align='right'><FONT size=-2>".($i+1)."</FONT></TD>".
       "<TD width=160>".@theta_names[$i]."</TD><TD width=80 ALIGN=left bgcolor='#EAEAEA'><FONT color='".$col."'><B>".rnd(@theta[$i],5)."</B></TD>"};
    print HTML "<TD width=50 bgcolor='#EAEAEA'>".@theta_fix[$i]."</TD>";
    my $rse = "";
    unless (@theta[$i] == 0) {$rse = abs(rnd(@theta_se[$i]/@theta[$i]*100,3)) };
    if (@theta_se[$i] ne "") {print HTML "<TD width=80 align=RIGHT>".rnd(@theta_se[$i],4)."</TD><TD width=80 align=RIGHT bgcolor='#EAEAEA'>".$rse."%</TD>"} 
      else {print HTML "<TD width=80>&nbsp;</TD><TD width=80 bgcolor='#EAEAEA'>&nbsp;</TD>"};
    my $low = rnd($theta_bnd_low[$i],3);
    my $up = rnd($theta_bnd_up[$i],3);
    if ($low <= -100000) {$low = "-Inf"};
    if ($up >= 100000) {$up = "+Inf"};
    print HTML "<TD align='right'>".$low."</TD><TD align='right' bgcolor='#EAEAEA'>".rnd(@theta_init[$i],3)."</TD><TD align='right'>".$up."</TD>";
    print HTML "</TR>\n";
    $i++;  
  }
  print HTML "</TABLE>\n<TABLE cellpadding=2 cellspacing=0 border=0 CLASS='omega'>";
  print HTML "<TR bgcolor='#C0D0FF'><TD><B>Omega</B></TD><TD></TD>";
  $i=1;
  foreach my $om (@omega) {print HTML "<TD>".$i."</TD><TD></TD>" ; $i++};
  print HTML "<TD>Etabar (SE)</TD><TD>p val</TD></TR>\n"; 
  $i=0; my $om_se_x; my @om_cov_se;
  foreach my $om (@omega) {
      my @om_x = @$om; my $j = 1;
      print HTML "<TR><TD bgcolor='#C0D0FF' width=40>".($i+1)."</TD>\n";
      print HTML "<TD align='left'>".@omega_names[$i]."</TD>\n";
      my $bg = "";
      foreach my $om_cov (@om_x) {
        if (@omega_se>0) {$om_se_x = @omega_se[$i]; @om_cov_se = @$om_se_x;};
        if (($j-1)/2 == int(($j-1)/2)) {$bg = "bgcolor='#EAEAEA'"} else {$bg = ""}
        print HTML "<TD $bg>".rnd($om_cov,4); 
        if (($om_cov!=0)&&(@om_cov_se[$i]!=0)) {
          print HTML "<TD $bg><FONT color='#888888'>(".rnd((@om_cov_se[$i]/$om_cov*100),3)."%)</FONT></TD>";
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
        if ((@omega)/2 == int((@omega)/2)) {$bg1 = "bgcolor='#EAEAEA'"; $bg2="bgcolor='#F3F3F3'"} else {$bg2 = "bgcolor='#EAEAEA'"; $bg1="bgcolor='#F3F3F3'"}
        print HTML "<TD $bg1>".rnd(@etabar[$i],3)." (".rnd(@etabar_se[$i],3).")</TD><TD $bg2>".rnd(@etabar_p[$i],4)."</TD>";
      }
      print HTML "</TR>";
      $i++;
  }
  print HTML "</TABLE>\n<TABLE cellpadding=2 cellspacing=0 border=0 CLASS='sigma'>";
  print HTML "<TR bgcolor='#C0D0FF'><TD><B>Sigma</B></TD><TD></TD>";
  $i=1; 
  foreach my $si (@sigma) {print HTML "<TD>".$i."</TD><TD></TD>" ; $i++};
  print HTML "</TR>\n"; 
  $i=0; my $si_se_x; my @si_cov_se; my $bg;
  foreach my $si (@sigma) {
      my @si_x = @$si; my $j = 1;
      print HTML "<TR><TD bgcolor='#C0D0FF' width=40>".($i+1)."</TD>\n";
      if (($j-1)/2 == int(($j-1)/2)) {$bg = "bgcolor='#EAEAEA'"} else {$bg = ""}
      print HTML "<TD>".@sigma_names[$i]."</TD>\n";
      foreach my $si_cov (@si_x) {
        if (@omega_se>0) {
           $om_se_x = @omega_se[$i]; 
           #@om_cov_se = @$om_se_x;
        };
        print HTML "<TD $bg>".rnd($si_cov,4); 
        if (($si_cov!=0)&&(@si_cov_se[$i]!=0)) {
          print HTML "<TD $bg><FONT color='#777777'>(".rnd((@si_cov_se[$i]/$si_cov*100),3)."%)</FONT></TD>";
        } else {
          print HTML "<TD $bg></TD>";
        }
        print HTML "</TD>";
        $j++;
      }
      print HTML "</TR>";
      $i++;
  }
  
  print HTML "</TABLE width=600><BR>\n";
  print HTML "<font size=1 face=verdana,arial>* Random effects are shown as OM^2 and SI^2</FONT><BR>";
  print HTML "<font size=1 face=verdana,arial>** RSE on random effects are shown as RSE(OM^2) and RSE(SI^2). RSE(OM) can be calculated as RSE(OM^2)/2. </FONT><BR>";
  #print HTML "<font size=1 face=verdana,arial><font color='red'>#</FONT><FONT color='black'> Final estimate is the same as initial (with unfixed parameter)</FONT></FONT>";
    
  ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
  print HTML "<TABLE><TR><TD colspan=2><FONT FACE=verdana,arial size=0>Generated ".($year+1900)."-".($mon+1)."-".$mday.", $hour:$min:$sec by Piraña</FONT></TD></TR></TABLE>\n";
  print HTML "</BODY>";
  close HTML;
}

sub extract_from_model {
### Purpose : Extract information about the model from a NM model file
### Compat  : W+L+
  my ($file, $modelno, $what) = @_;
  my $description = ""; my $refmod = ""; my $date_mod ="";
  my %mod;
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
  # search first few lines for reference model.
  for (my $j =0; $j<3; $j++) {
    if ($j < 3) {
      if ((@ctl_lines[$j] =~ m/Ref/i)||(@ctl_lines[$j] =~ m/Parent/i)) {  # Census uses 'Parent', but you can also use anything containing Ref
        @ctl_lines[$j] =~ s/\=/:/g;  # for people that code 'Ref=001'
        #@ctl_lines[$j] =~ s/\s+$//;  #remove trailing spaces
        @ctl_lines[$j] =~ s/\s/:/;   #in between spaces
        my @l = split (/\:/, @ctl_lines[$j]); # get last word (hopefully the ref model no#)
        #@l = split (/\:/, @ctl_lines[$j]); # get last word (hopefully the ref model no#)
        $refmod = @l[int(@l)-1];
        $refmod =~ s/^\s+//; #remove leading spaces
        chomp ($refmod);
      }
    }
  }
  if ($what eq "all") {
    # loop through model file to extract parameter names
    my $theta_area=0; my $omega_area=0; my $sigma_area=0;
    my $table_area=0; my $estim_area=0; my $msf_file=""; 
    my $cnt = 0; 
    my @th_descr; my @om_descr; my @si_descr;
    my @tab_files;  
    my (@th_fix, @om_fix, @si_fix);
    foreach (@ctl_lines) {
      if (substr($_,0,1) eq "\$") {
        if ($theta_area==1) {$theta_area=0} ;
        if ($omega_area==1) {$omega_area=0} ;
        if ($sigma_area==1) {$sigma_area=0} ;
        if ($table_area==1) {$table_area=0} ;
        if ($estim_area==1) {$estim_area=0} ;
      }
      if (substr ($_,0,6) eq "\$THETA") {$theta_area = 1 }
      if (substr ($_,0,6) eq "\$OMEGA") {$omega_area = 1 }
      if (substr ($_,0,6) eq "\$SIGMA") {$sigma_area = 1 }
      if (substr ($_,0,6) eq "\$TABLE") {$table_area = 1 }
      if (substr ($_,0,4) eq "\$EST") {$estim_area = 1 }
      if (substr ($_,0,5) eq "\$DATA") {
        my @data_arr = split (" ", $_);
        shift(@data_arr);
        my $dataset = "";
        while ($dataset eq "") {$dataset = shift(@data_arr)};
        $mod{dataset} = $dataset;
      }
      if ($theta_area+$omega_area+$sigma_area>0) {
        my ($init, $descr) = split (";",$_);
        if (($init =~ m/\d/)&&($_ =~ m/\;/)) { # match numeric character
          $init =~ s/\s//g;
          chomp($descr);
          if ($theta_area ==1) {push (@th_descr, $descr); }
          if (($omega_area ==1)&&(!($descr =~ m/cov/i))) {push (@om_descr, $descr); }
          if (($sigma_area ==1)&&(!($descr =~ m/cov/i))) {push (@si_descr, $descr); }
          if ($init =~ m/FIX/) { # match numeric character
            if ($theta_area ==1) {push (@th_fix, "FIX")} ;
            if ($omega_area ==1) {push (@om_fix, "FIX")} ;
            if ($sigma_area ==1) {push (@si_fix, "FIX")} ;
          } else {
            if ($theta_area ==1) {push (@th_fix, "")} ;
            if ($omega_area ==1) {push (@om_fix, "")} ;
            if ($sigma_area ==1) {push (@si_fix, "")} ;        
          }
        }
      }
      if($table_area==1) {
        if($_ =~ s/FILE\=//) {
          my $pos = length $`;
          my @tabline = split(/\s/,substr($_, $pos, -1)); 
          push (@tab_files, @tabline[0]);
        }
      }
      if($estim_area==1) {
        if($_ =~ s/MSF\=//) {
          my $pos = length $`;
          my @msfline = split(/\s/,substr($_, $pos, -1)); 
          $msf_file = @msfline[0];
        }
        my $line = $_;
        if ( $line =~ m/METH/i ) {
          my $offs = 7; # METHOD
          my $pos = length ($`);
          if (substr($line, $pos+4,1) eq "=") {$offs = 5}; # METH
          $pos = $pos+$offs;
          if (substr($line,$pos, 1) eq "0") {$mod{method}="FO"};    
          if (substr($line,$pos, 4) eq "ZERO") {$mod{method}="FO"};    
          if (substr($line,$pos, 1) eq "1") {$mod{method}="FOCE"};
          if (substr($line,$pos, 4) eq "FOCE") {$mod{method}="FOCE"};
          if (substr($line,$pos, 6) eq "HYBRID") {$mod{method}="HYB"};
          if ($line =~ m/\sLAPLAC/gi) {$mod{method} = "LAPL"}
          if ($line =~ m/\sINTER/) {$mod{method} .= "+I"}
        }
      }
    }
    $mod{th_descr} = \@th_descr;
    $mod{om_descr} = \@om_descr;
    $mod{si_descr} = \@si_descr;
    $mod{th_fix} = \@th_fix;
    $mod{om_fix} = \@om_fix;
    $mod{si_fix} = \@si_fix;
    $mod{tab_files} = \@tab_files;
    $mod{msf_file} = $msf_file;
  }
  $mod{description} = $description;
  $mod{refmod} = $refmod;
  return (\%mod);
}
