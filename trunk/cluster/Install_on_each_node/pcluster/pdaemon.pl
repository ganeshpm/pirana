# make sure the network drive is accessible
use Win32::OLE;
use Cwd;
use Cwd qw /abs_path/;
use File::Copy;
use Win32;
use Win32::Process;
use Win32::Process::Info;
Win32::SetChildShowWindow(0); # don't open new console windows

### Initialization
$base = abs_path($0); # get path of script
our $cwd = $base;
$cwd =~ s/\.pl//i;
$cwd =~ s/\.exe//i;
$cwd =~ s/pdaemon//i;
unless (-e $cwd."pcluster.ini") { die "pcluster.ini not found." }
our ($setting_ref, $descr_ref) = read_ini ($cwd."\\pcluster.ini");
%setting = %$setting_ref;
map_network_drive($setting{cluster_drive}, $setting{network_address}, $setting{network_user}, $setting{network_password});
our $cluster_drive = $setting{cluster_drive};
our $comp_no = $setting{pc_number};
our $comp_name =$setting{pc_user};
our $cpus = $setting{cpus_available};
our $psn_dir = $setting{psn_dir};
our $perl_dir = $setting{perl_dir};
our $fortran_dir = $setting{fortran_dir};
push (@INC, $psn_dir);
####

our @intensive_processes = ("nonmem.exe", "nmbs.exe", "matlab.exe"); #report as busy when one of these is loaded
our $i=0; # our $kill=0;

unless ($ENV{'PATH'} =~ m/$fortran_dir/) {
  $ENV{'PATH'} = $fortran_dir.";".$ENV{'PATH'};
}
unless ($ENV{'PATH'} =~ m/$perl_dir/) {
  $ENV{'PATH'} = $perl_dir.";".$ENV{'PATH'};
}

our $nm_process = 0;       # Currently a NM-process running?
unless ($pid1 = fork) {    # create a forked process that makes sure all nonmem.exe executions are run under low priority and signal status
  while ($kill==0) {
    sign_status($comp_no, NM_processes());
    sleep(15); # do this every 15 seconds
  }
  exit(0);
}

while ($kill==0) {
  my @forks;
  if (-e $cluster_drive."/ZinkStop/".$comp_no.".stop") {
    unlink $cluster_drive."/ZinkStop/".$comp_no.".stop";
    $kill=1;
  };
  check_jobs ($comp_no);
  sleep(10);
}
kill 9, $pid1;
die;

### Subroutines ###

sub check_jobs {
  my $no = shift;
  my $nm = NM_processes();
# first look if specific jobs are scheduled for client
  chdir ($cluster_drive."/ZinkJobs");
  undef my @sorted_jobs; undef my @zink_files; undef my $request_job; my $comp_dir;
  if (-d $no) {
    chdir ($no);
    @zink_files = <*.znk>;
    our %zink_files;
    foreach (@zink_files) {$_ = $no."/".$_ };
    chdir ("..");
  } else { # in /ZinkJobs
    @zink_files = <*.znk>;our @zink_id = @zink_files;
  }
  $nm = NM_processes();

  if ((@zink_files > 0)&&($nm < $cpus)) {
    our (%zink_host, $job_name, $priority, $exe_path, $command) = {};
    open (LOG, ">U:\\log".$comp_no.".log");
    foreach my $zink_file (@zink_files) { # needed for sorting by priority
      @zink_info = read_zink_file ($zink_file);
      $zink_host{$zink_file} = @zink_info[0];
      $job_name{$zink_file} = @zink_info[1];
      $priority{$zink_file} = @zink_info[2];
      $exe_path{$zink_file} = @zink_info[3];
      $command{$zink_file} = @zink_info[4];
    }

    @sorted_jobs = @zink_files;
    my $j = 0; my $exit=0; our $request_job; my $job_file;
    while ($j<@sorted_jobs&&$exit==0) { # loop through available job specificatino files
      our $request_job = @sorted_jobs[$j];
      if ($request_job =~m/\//) {(my $dir, $job_file) = split ("/", $request_job);} else {$job_file = $request_job; };
      if ((-e $cluster_drive."/ZinkActive/".$job_file)||(-e $cluster_drive."/ZinkDone/".$job_file)) {
         print LOG localtime()." Already busy or done with ".$job_file."\n";
      } else {
        if (move ($cluster_drive."/ZinkJobs/".$request_job, $cluster_drive."/ZinkActive/".$job_file)) {
          print LOG "Trying to start job: ".$job_file."\n";
          $exit=1;
        } else { print LOG localtime()." Can't move job file ".$job_file."\n"; }
      }
      $j++;
    }

    if ($exit==1) {
    if (-e $cluster_drive."/ZinkActive/".$job_file) {
      open (ZNK, ">>".$cluster_drive."/ZinkActive/".$job_file);
      print ZNK "CLIENT:  ".$no."\n";
      close (ZNK);
      unless (my $pid = fork ()) {
        # start execution of PsN / nonmem.exe;
        chdir ($exe_path{$request_job});
        print "Starting job.\n";
        if ($command{$request_job} =~ m/nonmem.exe/ig) { #nmfe
          win_start($command{$request_job});
          my @lst = <*.lst>;
          my @cat = (@lst[0],"OUTPUT");
          cat (@cat, @lst[0]);
        }
        if ($command{$request_job} =~ m/perl/i) { #PsN
          $perl_com = $command{$request_job};
          $com = substr($perl_com, 5, (length($perl_com)-5));
          $com =~ s/^\s+//;
          $com =~ s/\s+$//;
          print LOG localtime()." Starting: ".win_path($perl_dir."\\perl.exe ".$com);
          win_start($perl_dir."\\perl.exe", $com, $exe_path{$request_job});
        }
        if ($command{$request_job} =~ m/wfn/i) { #WFN
          print LOG localtime()." Starting WFN: ".$command{$request_job};
          win_start ($command{$request_job}, "", $exe_path{$request_job});
        }
        print LOG "Finished job.\n";
        move ($cluster_drive."/ZinkActive/".$request_job, $cluster_drive."/ZinkDone/".$request_job); # move zink-file from Active to Done
        rmdir ($cluster_drive."/ZinkActive/".$no);  # Try to remove dir (only works when empty)
    }
    sleep(1);
    sign_status($comp_no, NM_processes());
  }
  } else {
    print lOG localtime()." No jobs to be run.";
  }
  close LOG;
  }
  return ();
}

sub cat {
  my ($files_ref, $endfile) = @_;
  my @files = @$files_ref;
  foreach (@files) {
      open(FILE, $_) || ((warn "Can't open file $_\n"), next FILE);
      while (<FILE>) {
         $text .= $_;
      }
      close(FILE);
   }
   open (OUT, ">".$endfile);
   print OUT $text;
   close OUT;
}

sub sign_status { # signal the cluster that the PC is idle
  ($no, $active) = @_;
  open (IDLE, ">".$cluster_drive."/ZinkClients/".$no.".idl");
  print IDLE $active."/".$cpus."\n";
  print IDLE $comp_name;
  close IDLE;
}

sub read_zink_file {
  my $zink_file = shift;
  open (ZINK, "<".$cluster_drive."/ZinkJobs/".$zink_file);
  @zink_lines = <ZINK>;
  close ZINK;
  foreach (@zink_lines) {
    @spl = split (/\:\s/, $_);
    $_ = @spl[-1];
    chomp ($_);
  }
  my ($zink_host, $job_name, $priority, $exe_path, $command) = @zink_lines;
  return (@zink_lines);
}

sub NM_processes { # get NM processes
  my $pi = Win32::Process::Info->new();
  my @pids = $pi->ListPids (); # Get all known PIDs
  my @info = $pi->GetProcInfo (); # Get the max
  my $nm = 0;
  for $pid (@info){
    foreach (@intensive_processes) {
      if ($pid->{"Name"} =~ m/$_/i) {
       $nm++;
      }
    }
  }
  return ($nm);
}

sub win_start {
  # arguments: program, arguments, dir
  @path = split(/\\/,@_[0]);
  $program = @path[@path-1];
  $program =~ s/.exe//i;
  $cmd_line = $program." ".@_[1];
  my $cwd = @_[2];
  if (-e @_[0]) {
    my $proc = Win32::Process::Create($Process, @_[0], $cmd_line, 0, LOW_PRIORITY_CLASS, $cwd) || die "Failed to start @_[0]!";
    $Process -> SetPriorityClass(THREAD_PRIORITY_LOWEST);
    $Process -> Wait(INFINITE);
  } else {
    sleep 2;
  }
}

sub map_network_drive {
  my $strDrive = @_[0];
  my $strPath = @_[1];
  my $strUser = @_[2];
  my $strPassword = @_[3];
  my $boolPersistent = 1;
  $objNetwork = Win32::OLE->new('WScript.Network');
  $objNetwork->MapNetworkDrive($strDrive, $strPath, $boolPersistent, $strUser, $strPassword);
  #print "Successfully mapped drive\n";
}

sub read_ini {
  unless (open (INI,"<".@_[0])) {print "File not found: ".@_[0]."\n"};
  my %setting;
  my %descr;
  my %add_1;
  @ini=<INI>;
  close INI;
  foreach (@ini) {
    unless ($_=~ m/\#/) {
      chomp ($_);
      @a = split(/,/,$_);
      $setting{@a[0]} = @a[1];
      $descr{@a[0]} = @a[2];
    }
  }
  return (\%setting, \%descr);
}
sub win_path {
  $win_dir = shift;
  $win_dir =~ s/\//\\/g ;
  $win_dir =~ s/\\\\/\\/g;  # if '\\' occurs then '\'
  return $win_dir;
}
