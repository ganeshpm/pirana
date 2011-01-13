# Module to work with some of PsN's-functionality

package pirana_modules::PsN;

use strict;
use pirana_modules::misc qw(generate_random_string lcase replace_string_in_file dir ascend log10 bin_mode rnd one_dir_up win_path os_specific_path unix_path extract_file_name tab2csv csv2tab read_dirs_win win_start);
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(get_psn_info get_psn_help get_psn_nm_versions);

sub get_psn_info {
### Purpose : Get the info on a PsN command, by invoking the -h switch and capturing the output
### Compat  : W+L?
  my ($psn_command, $psn_dir, $ssh_ref, $switch)  = @_;
  my %ssh = %$ssh_ref;
  # Switch is either "h" or "help"
  #print (unix_path($psn_dir."/bin/".$psn_command)." -h |");
  my $ssh_cmd1 = ''; my $ssh_cmd2;
  my $quote = ''; my $psn_full = $psn_command;

  my $ssh_pre; my $ssh_post;
  if ($ssh{connect_ssh} == 1) {
      $ssh_pre .= $ssh{login}.' ';	
      if ($ssh{parameters} ne "") {
	  $ssh_pre .= $ssh{parameters}.' ';
      }
      $ssh_pre .= "'";
      if ($ssh{execute_before} ne "") {
	  $ssh_pre .= $ssh{execute_before}.'; ';
      }
      $ssh_post = "; exit'";
  } else {
      my $loc_str = $psn_dir;
      $loc_str =~ s/\s//g; # strip spaces
      if ($loc_str ne "") {
	  $psn_full = os_specific_path($psn_dir.'/'.$psn_command);
      }
  }
  my $cmd = os_specific_path($ssh_pre.$psn_full.' -'.$switch.$ssh_post.' |');
  eval(open (OUT, $cmd));
  my $psn_text = "";
  while (my $line = <OUT>) {
    $psn_text .= $line;
  }
  close (OUT);
  return ($psn_text);
}

sub get_psn_nm_versions {
### Purpose : Retrieve the NM versions specified to psn. (reads a pipe from "psn -nm_versions")
### Compat  : W+L+
### Notes   : When the psn command is invoked but cannot be found, Pirana crashes
  my ($setting_ref, $software_ref, $ssh_ref)= @_;
  my %setting = %$setting_ref;
  my %software = %$software_ref;
  my %ssh = %$ssh_ref;
  my @split;
  my %psn_nm_versions; my %psn_nm_versions_vers;
  my $command;
  unless ($ssh{connect_ssh} == 1) {
      $command = "psn -nm_versions";
  } else {  # on cluster using SSH
      $command = $ssh{login}.' '.$ssh{parameters}.' "psn -nm_versions &"';
  }
  eval (  open (OUT, $command." |")); # or die "Could not open command: $!\nCheck installation of PsN.";
 # open (OUT, $command." |"); # or die "Could not open command: $!\nCheck installation of PsN.";
  my $flag = 0;
  my %psn_nm_versions;
  my $i =0;
  while (my $line = <OUT>) {
      unless (($line =~ m/Valid choices/gi)||($line =~ m/the default is/i)) {
       	  chomp($line);
       	  unless ($line eq "") {
       	      $line =~ s/will call //i; # older PsN versions
       	      my ($nm_name, $nm_loc) = split(/\(/,$line);
       	      my ($nm_loc, $nm_ver) = split (/,/, $nm_loc);
       	      $nm_name =~ s/\s//g;
       	      chomp($nm_ver); $nm_ver =~ s/\)//;
       	      #  $nm_name = substr($nm_name,0,9);
       	      $psn_nm_versions{$nm_name} = $nm_loc;
       	      $psn_nm_versions_vers{$nm_name} = $nm_ver;
       	  }
      }
  }
  close (OUT);
  return (\%psn_nm_versions, \%psn_nm_versions_vers);
}

1;
