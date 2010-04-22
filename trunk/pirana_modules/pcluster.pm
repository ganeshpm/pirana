# Subroutines that perform actions on NM modelfiles

package pirana_modules::pcluster;

use strict;
use Cwd;
use File::stat;
use HTTP::Date;
use pirana_modules::misc qw(generate_random_string lcase replace_string_in_file dir ascend log10 bin_mode rnd one_dir_up win_path unix_path extract_file_name tab2csv csv2tab read_dirs_win win_start);
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(generate_zink_file get_active_nodes);

sub generate_zink_file {
### Purpose : Generate a zink-file (PsN)
### Compat  : W+L+
  my ($zink_host, $cluster_drive, $jobname, $priority, $exepath, $command, $specific_client) = @_ ;
  if ($specific_client ne "") {
    mkdir ($cluster_drive."/ZinkJobs/".$specific_client);
    $specific_client .= "\/";
  }
  my $filename = $cluster_drive."/ZinkJobs/".$specific_client.$zink_host."-".generate_random_string(17).".znk";
  #print "\n".$filename."\n";
  open (ZINK, ">".$filename);
  print ZINK "SUBMITHOST: ".$zink_host."\n";
  print ZINK "JOBNAME: ".$jobname."\n";
  print ZINK "PRIORITY: ".$priority."\n";
  print ZINK "EXEPATH: ".$exepath."\n";
  print ZINK "COMMAND: ".$command."\n";
  close (ZINK);
  if (-e $filename) {return 1} else {return 0};
}


sub get_active_nodes {
### Purpose : Return the CPUs in the PCluster
### Compat  : W+L?
  my ($cluster_drive, $clients_ref) = @_;
  my %clients = %$clients_ref;
  my $cwd = getcwd();
  chdir ($cluster_drive."/ZinkClients");
  my @idle = <*.idl>;
  my %clients_status = %clients; my %clients_status = %clients;
  my %total_cpus ; my %busy_cpus ; my %pc_names;
  foreach (keys (%clients_status)) {$clients_status{$_} = ""};
  foreach (@idle) {
    my $df = stat($_) -> mtime();
    open (STAT, "<".$_);
    my @lines = <STAT>;
    my $stat = @lines[0];
    chomp($stat);
    my ($runs, $total) = split (/\//,$stat);
    close STAT;
    $_ =~ s/\.idl//i ;
    my $now = str2time(localtime());
    if (int(int($now)-int($df)) < 60) {
      $total_cpus{$_} = $total;
      $busy_cpus{$_} = $runs;
    }
    chomp(@lines[1]);
    $pc_names{$_} = @lines[1];
  };
  chdir ($cwd);
  return (\%total_cpus, \%busy_cpus, \%pc_names);
}
1;
