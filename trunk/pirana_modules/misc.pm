# Miscellaneous subroutines

package pirana_modules::misc;

#use strict;
use Getopt::Std;
use Cwd;
require Exporter;

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(block_size base_drive find_R get_max_length_in_array get_file_extension make_clean_dir nonmem_priority get_processes generate_random_string lcase replace_string_in_file dir ascend log10 is_integer is_float bin_mode rnd one_dir_up win_path unix_path os_specific_path extract_file_name tab2csv csv2tab read_dirs_win read_dirs win_start start_command);

sub block_size {
### Purpose : Get the maximum length of a string in an array of strings
### Compat  : W+L+
    my $n = shift;
    if ($n < 2) {
      return $n;
    } else {
      return $n + block_size($n-1);
    }
}


sub base_drive {
    my $path = shift;
    my $drive = "";
    if (substr($path,0,2) =~ m/.:/ ) {
	$drive = substr($path,0,2);
    } 
    return ($drive);
}

sub get_max_length_in_array {
### Purpose : Get the maximum length of a string in an array of strings
### Compat  : W+L+
    my @array = @_;
    my $max_length = 0;
    foreach( @array ) {
	if (length($_) > $max_length) {$max_length = length($_)};
    }
    return ($max_length);
} 

sub find_R {
### Purpose : Find the newest R version on Windows
### Compat  : W+L-
    my $prog_dir_ref = shift;
    my @prog_dir = @$prog_dir_ref;
    my %all_R;
    foreach my $dir (@prog_dir) {
	my @dirs = read_dirs ($dir);
	foreach my $R_dir (@dirs) {
	    if (($R_dir =~ m/R-/)&&(-d $dir."/".$R_dir."/bin")) {
		$all_R {$R_dir} = $dir."/".$R_dir;
	    }
        }
    }
    # find newest R version available
    my $highest_version_number;
    my $version;
    foreach my $R (keys(%all_R)) {
	my $R_num = $R;
	$R_num =~ s/R-//i;
	my @spl = split (/\./, $R_num);
	my $version_number = @spl[0]*10000 + @spl[1]*100 + @spl[2];
	if ($version_number > $highest_version_number) {
	    $highest_version_number = $version_number;
	    $version = $R;
	}
    }
    return ($all_R{$version});
}

sub get_file_extension {
    my $filename = shift;
    my @spl = split (/\./, $filename);
    my $ext = "";
    if (@spl > 1) {
	$ext = @spl[(@spl-1)];
    }
    return($ext);
}

sub make_clean_dir {
    my $dir = shift;
    $cwd = fastgetcwd();
    unless (-d $dir) {mkdir $dir};
    if (chdir ($dir)) {
	@files = dir($dir);
	foreach (@files) {$_ = $dir."/".$_ }
        unlink (@files);
    }
    chdir ($cwd);
}

sub generate_random_string {
### Purpose : Generate a random string of n length
### Compat  : W+L?
	my $length_of_randomstring=shift;
	my @chars=('a'..'z','A'..'Z','0'..'9','_');
	my $random_string;
	foreach (1..$length_of_randomstring)
	{$random_string.=$chars[rand @chars];}
	return $random_string;
}

sub lcase {
  my $string = shift;
  my $string =~ tr/A-Z/a-z/;
  return($string);
}
sub replace_string_in_file {
  my ($filename, $string, $replace) = @_;
  open (IN, "+<".$filename);
  my @file = <IN>;
  seek IN,0,0;
  foreach (@file){
    $_ =~ s/$string/$replace/g;
    print IN $_;
  }
  close IN;
}

sub dir {
### Purpose : Return files in a dir
### Compat  : W+L+
  my ($dir, $filter) = @_;
  undef my @dirfiles;
  opendir ( DIR, $dir) || die "Error in opening dir $dir\n";
  while( (my $filename = readdir(DIR))){
    my $l = length($filename);
    if ($filename =~ m/$filter/i) {
      push (@dirfiles, $filename);
    }
  }
  closedir(DIR);
  sort (ascend @dirfiles);
  return @dirfiles;
}

sub ascend
### Purpose : Sort ascending
### Compat  : W+L+
{
 $a <=> $b;
}

sub log10 {
### Purpose : return logarithmic value
### Compat  : W+L+
	my $n = shift;
	return log($n)/log(10);
}

sub is_integer {
   defined $_[0] && $_[0] =~ /^[+-]?\d+$/;
}

sub is_float {
   defined $_[0] && $_[0] =~ /^[+-]?\d+(\.\d+)?$/;
}

sub bin_mode {
### Purpose : Rewrite a file in binary mode
### Compat  : W+L+?
  # rewrite file in binary mode
  my $file = shift;
  if (-e $file) {
    open (I, "<".$file);
    my @lines = <I>;
    close (I);
    open (O, ">".$file);
    binmode O;  #  this is for binary files
    print O @lines;
    close (O);
  }
}

sub rnd {
### Purpose : Return a rounded number (with trailing zeroes removed)
### Compat  : W+L+
    my ($n, $rnd) = @_;
    $b = sprintf("%.".$rnd."f", $n);
    $b =~ s/0*$//;
    $b =~ s/\.*$//;
    return ($b);
}

sub one_dir_up {
### Purpose : Return the directory paht located one dir up
### Compat  : W+
  my $dir = shift;
  my @dir_pieces = split (/\//, unix_path ($dir));
  pop (@dir_pieces);
  my $dir2 = join ("/", @dir_pieces);
  return $dir2;
}

sub win_path {
### Purpose : Return a path with only \
### Compat  : W+L+
  my $win_dir = @_[0];
  $win_dir =~ s/\//\\/g ;
  $win_dir =~ s/\\\\/\\/g;  # if '\\' occurs then '\'
  return $win_dir;
}
sub unix_path {
### Purpose : Return a path with only /
### Compat  : W+L+
  my $unix_dir = @_[0];
  $unix_dir =~ s/\\/\//g ;
  $unix_dir =~ s/\/\//\//g; # remove double //
  return $unix_dir;
}
sub os_specific_path {
  my $str = shift;
  if ($^O =~ m/MSWin/i) {
    $str = win_path($str);
  } else {
    $str = unix_path($str);
  }
  return $str;
}
sub extract_file_name {
### Purpose : Return only the filename from a full given path
### Compat  : W+L+
  my $full = unix_path(shift);
  my @parts = split ("/",$full);
  my $file_name = @parts[int(@parts)-1];
  return($file_name);
}

sub csv2tab {
### Purpose : Convert a csv file to a table file
### Compat  : W+
  my ($file, $file_new) = @_;
  open (IN,$file);
  my @IN = <IN>;
  close IN;
  foreach (@IN) {
    $_ =~ s/,/\t/g;
  }
  open (OUT, ">".$file_new);
  print OUT @IN;
  close OUT;
}

sub tab2csv {
### Purpose : Convert a NM table to a csv file (e.g. for reading in excel)
### Compat  : W+
### Notes: laborious method, since NONMEM does not output tables using \t but with spaces
  open (IN,@_[0]);
  my @TAB = <IN>;
  close (IN);
  my $i=0;
  while (@TAB[$i]) {
    @TAB[$i] =~ s/  NaN         /,.,/g;
    @TAB[$i] =~ s/  NaN        /,.,/g;
    @TAB[$i] =~ s/  /,/g;
    @TAB[$i] =~ s/ /,/g;
    if ($i<2) {
      @TAB[$i] =~s/ID/id/; # to avoid Excel problems with SYLK files
      @TAB[$i] =~ s/,,,,,,/,/g;
      @TAB[$i] =~ s/,,,,,/,/g;
      @TAB[$i] =~ s/,,,,/,/g;
      @TAB[$i] =~ s/,,,/,/g;
      @TAB[$i] =~ s/,,/,/g;
    }
    $i=$i+1;
  };
  open (OUT,">".@_[1]);
  my $start=1;
  if (@TAB[0] =~ m/TABLE/) {
      shift @TAB;
      chomp(@TAB[0]);
  } else {                      # TAB file has column names
    my $row1 = @TAB[0];
    chomp($row1);
    my @row = split (/,/,$row1);
    my $k=1;
    my $header="";
    while($k<@row) {             # Impute column names
      $header = $header.",V".$k;
      $k++;
    }
    $header =~ s/\n//g;
    chomp($header);
    unshift @TAB;
    @TAB[0] = $header;
  }
  my $k=0;
  foreach(@TAB) {
    $_ =~ s/,//;
    my @row = split (/,/,$_);      # data
    my $j=0;
    foreach(@row) {
      $j++;
      if ($k>=$start) {print OUT $_ * 1;}         # data
        else {print OUT $_;}; # headers
      if ($j<@row) {print OUT ",";} else {print OUT "\n";}
    }
    $k++;
  }
  close (OUT);
}

sub read_dirs {
### Purpose : Return all directories in the current directory
### Compat  : W+L?
    my ($path, $filter) = shift;
    my @dirs = ();
    my $cwd = fastgetcwd();
    chdir ($path);
    my @dir_all = <*>;
    foreach (@dir_all) {
	if (-d $_) {
	    if (($_ ne ".")&&($_ ne "..")) {
		unless (($filter ne "")&!($_ =~ m/$filter/i)) {
		    push (@dirs, $_);
		}
	    }
	}
    }
    chdir ($cwd);
    return @dirs;
}
sub read_dirs_win {
### Purpose : Return all directories in the current directory
### Compat  : W+L?
    my $filter = shift;
    my @dirs = ();
    my @dir_all = <*>;
    foreach (@dir_all) {
	if (-d $_) {
	    if (($_ ne ".")&&($_ ne "..")) {
		unless (($filter ne "")&!($_ =~ m/$filter/)) {
		    push (@dirs, $_);
		}
	    }
	}
    }
    return @dirs;
}

sub win_start {
### Purpose : Start a program on Windows (with arguments)
### Compat  : W+L-
    # arguments: program, arguments
    my @path = split(/\\/,@_[0]);
    my $program = @path[@path-1];
    $program =~ s/.exe//i;
    my $cmd_line = $program." ".@_[1];
    my $priority = "LOW_PRIORITY_CLASS";
    if (-e @_[0]) {
	Win32::Process::Create(my $Process, @_[0], $cmd_line, 0, $priority,".") || die "Failed to start @_[0]!";
	return("");
    } else {
	my @file = split ('/',unix_path(@_[0]));
	return("Cannot find ".$program.". Please check software settings.");
    }
}
sub linux_start {
    my $curr_dir = cwd();
    system (@_[0]." ".@_[1]." &");
#    print @_[0]." ".@_[1]." &";
}
sub darwin_start {
    my $curr_dir = cwd();
  #  @_[0] =~ s/\s/\\ /g;
    system ("open -a '".@_[0]."' ".@_[1]." &");

}

sub start_command {
    my $os = "$^O";
    if ($os =~ m/MSWin/i) {
	win_start (@_);
    } else {
      if ($os =~ m/darwin/i) {
	  darwin_start (@_);
      } else {
	  linux_start(@_);
      }
    }
}

1;