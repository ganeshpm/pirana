# Module to work with some of PsN's-functionality

package pirana_modules::PsN;

use strict;
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(get_psn_info get_psn_help);

sub get_psn_info {
### Purpose : Get the info on a PsN command, by invoking the -h switch and capturing the output 
### Compat  : W+L? 
  my $psn_command = shift;
  open (OUT, $psn_command." -h |") or die "Could not open command: $!\n";
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
  my ($psn_command, $psn_dir) = shift;
  my $psn_text;
  if (-e $psn_dir."/bin/".$psn_command) {
    open (OUT, $psn_command." --help |") or die "Could not open command: $!\n";
    while (my $line = <OUT>) {
      $psn_text .= $line;
    }
    close OUT;
    return $psn_text;
  } else {
    message ("PsN help file for command ".$psn_command." not found");
  }
}
1;
