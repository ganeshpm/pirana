### NB. the script doesn't check for succesful installation
use strict;
print "Make command (e.g. make / dmake / nmake): ";
my $make_command = <>;
if ($make_command eq "") {$make_command = "make"};
my @dirs = <*>;
foreach my $dir (@dirs) {
  if (-d $dir) {
    if (chdir ($dir)) {
      system ("perl Makefile.PL");
      system ($make_command);
      system ($make_command." install");
      chdir ("..");
    }
  }
}