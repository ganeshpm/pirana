# Module to work with some of PsN's-functionality

package pirana_modules::PsN;

use strict;
use pirana_modules::misc qw(generate_random_string lcase replace_string_in_file dir ascend log10 bin_mode rnd one_dir_up win_path unix_path extract_file_name tab2csv csv2tab center_window read_dirs_win win_start);
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(get_psn_info get_psn_help get_psn_nm_versions);

sub get_psn_info {
### Purpose : Get the info on a PsN command, by invoking the -h switch and capturing the output 
### Compat  : W+L? 
  my ($psn_command, $psn_dir)  = @_;
  #print (unix_path($psn_dir."/bin/".$psn_command)." -h |");
  eval (open (OUT, unix_path($psn_dir."/".$psn_command)." -h |"));
  my $psn_text = "";
  my $flag = 0;
  while (my $line = <OUT>) {
    $psn_text .= $line;
    $flag = $flag + 0.5;
    if (($psn_command =~ m/execute/gi)&&($flag = int($flag))) {chomp ($psn_text); $psn_text .= "\t"}
  }
  return ($psn_text);
}
sub get_psn_help {
### Purpose : Get the full help on a PsN command, by invoking the -help swith and capturing the output 
### Compat  : W+L?
  my ($psn_command, $psn_dir)  = @_;
  #print (unix_path($psn_dir."/bin/".$psn_command)." -h |");
  eval (open (OUT, unix_path($psn_dir."/".$psn_command)." -help |"));
  my $psn_text = "";
  my $flag = 0;
  while (my $line = <OUT>) {
    $psn_text .= $line;
    $flag = $flag + 0.5;
    if (($psn_command =~ m/execute/gi)&&($flag = int($flag))) {chomp ($psn_text); $psn_text .= "\t"}
  }
  return ($psn_text);
}

sub get_psn_nm_versions {
### Purpose : Retrieve the NM versions specified to psn. (reads a pipe from "psn -nm_versions") 
### Compat  : W+L+
### Notes   : When the psn command is invoked but cannot be found, Pirana crashes
  my ($setting_ref, $software_ref, $cluster_active)= @_;
  my %setting = %$setting_ref;
  my %software = %$software_ref; 
  my @split;
  our $max_psn_name;
  my %psn_nm_versions; my %psn_nm_versions_vers;
  if ($software{psn_dir} =~ m/perl/i) {  # use the PsN that is specified, not necisssarily the one in the system variables 
    my $psn_dir = $software{psn_dir};
    @split = split(/\\/,$psn_dir); 
  }
  my $command;
  unless (($setting{use_cluster}==1)&&($cluster_active==1)) {
    if (-e @split[0]."\\".@split[1]."\\bin\\psn") {
      $command = @split[0]."\\".@split[1]."\\bin\\psn -nm_versions";
    } else {$command = "psn -nm_versions";}
  } else {  # on cluster using SSH
      $command = $setting{ssh_login}.' '.$software{psn_on_cluster}.'"psn -nm_versions &"';
  }
  if (my $stdout) {my $stdout -> insert('end', "\n".$command);};
  eval (open (OUT, $command." |")); # or die "Could not open command: $!\nCheck installation of PsN.";
  my $flag = 0;
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
1;

