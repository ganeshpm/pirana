# Module with functionality to interact with R (currently not included in Pirana)

package pirana_modules::R;

# use strict;
use Statistics::R;
use Cwd;

our @ISA = qw(Exporter);
use File::Basename;
use pirana_modules::misc qw(os_specific_path);
use pirana_modules::misc_tk qw(message_yesno);
our @EXPORT_OK = qw(R_insert_multiple_lines R_create_script_text_box R_create_R_box R_insert_line R_start_process R_stop_process R_run_script);
our $button         = "#dddac9";
our $abutton        = "#cecbba";

sub R_create_script_text_box {
    my ($text, $title, $frame, $R_proc, $R_box, $R_commands_ref, $R_script_file) = @_;
    my $script_text_box = $frame -> Scrolled ('Text',
        -scrollbars=>'e', -width=>90, -height=>16,
        -background=>"#FFFFFF",-exportselection => 1,
        -relief=>'groove', -border=>2, -wrap=>"none",
        -selectbackground=>'#606060', -highlightthickness =>0
    ) -> grid(-column=>1, -row=>1, -columnspan=>12, -sticky=>'nwes');
#    my $font = $frame -> fontCreate('script_text_box', -family=>'arial', -size=>int(-11));
    my $font = "Verdana -11";
    $script_text_box -> insert('end', $text);
    $frame -> Button (-text=>"Send all", -font=>$font, -border=>0,  -width=>13,-background=>$button, -activebackground=>$abutton, -command => sub {
	my $script = $script_text_box -> get("0.0","end");
	my $success = R_insert_multiple_lines ($R_proc, $R_box, $script, $R_commands_ref, 1);
	unless ($success == 1) {
	    $R_box -> insert ("end", "Please close parentheses or quotes before sending commands to R.\n", "pirana");
	    $R_box -> insert ("end", ">");
	    $R_box -> update();
	}
    }) -> grid(-row=>2, -column=>1, -sticky=>"nwse");
    my $types = [
	['R Scripts',       ['.R', '.r']],
	['All Files',        '*',       ],
	];
    $frame -> Button (-text=>"Send selected", -font=>$font, -border=>0, -width=>12, -background=>$button, -activebackground=>$abutton, -command => sub {
    	my $sel = $script_text_box -> tagRanges("sel");
    	if ($sel =~ m/ARRAY/) {
    	    my @sel_lines = @$sel;
    	    my $script = $script_text_box -> get (@sel_lines[0], @sel_lines[1]);
    	    my @lines = split ("\n", $script);
	    my $line_send = "";
	    my $success = R_insert_multiple_lines ($R_proc, $R_box, $script, $R_commands_ref, 1);
	    unless ($success == 1) {
		$R_box -> insert ("end", "Please close parentheses or quotes before sending commands to R.\n", "pirana");
		$R_box -> insert ("end", ">");
		$R_box -> update();
	    }
    	}
    }) -> grid(-row=>2, -column=>2, -sticky=>"nwse");
    $frame -> Label (-text=> " ", -border=>0) -> grid(-row=>0, -column=>1, -columnspan=>1, -sticky=>"nwse");
    my $script_file_entry = $frame -> Label (-font=>$font,-text=>$R_script_file) -> grid(-row=>0, -column=>1, -columnspan=>5, -sticky=>"nw");

    my $cwd = os_specific_path ( dirname ($R_script_file) );
    $frame -> Button (-text=>"Save script",-font=>$font, -border=>0, -width=>12, -background=>$button, -activebackground=>$abutton, -command => sub {
	my $script_text = $script_text_box -> get ("0.0", "end");
	open (SCR, ">".$R_script_file);
	print SCR $script_text;
	close (SCR);
    }) -> grid(-row=>2, -column=>3, -sticky=>"nwse");
    $frame -> Button (-text=>"Save as...",-font=>$font, -border=>0, -width=>12, -background=>$button, -activebackground=>$abutton, -command => sub {
	my $save_file = $frame -> getSaveFile (-defaultextension=>".R", -filetypes=>$types, -title=>"Save R script as", -initialdir => $cwd);
	my $script_text = $script_text_box -> get ("0.0", "end");
	open (SCR, ">".$save_file);
	print SCR $script_text;
	close (SCR);
	$R_script_file = $save_file;
	$script_file_entry -> configure (-text => $save_file);
    }) -> grid(-row=>2, -column=>4, -sticky=>"nwse");
    $frame -> Button (-text=>"Open script",-font=>$font, -border=>0,  -width=>12,-background=>$button, -activebackground=>$abutton, -command => sub {
	my $open_file = $frame -> getOpenFile (-defaultextension=>".R", -filetypes=>$types, -title=>"Open R script", -initialdir=> $cwd);
	open (SCR, "<".$open_file);
	my @lines = <SCR>;
	close (SCR);
	my $text = join ("", @lines);
	$script_text_box -> delete ("0.0", "end");
	$script_text_box -> insert ("0.0", $text);
    }) -> grid(-row=>2, -column=>5, -sticky=>"nwse");
#    $frame -> Button (-text=>"Close window", -font=>$font, -border=>0, -width=>12, -background=>$button, -activebackground=>$abutton, -command => sub {
#	$ -> destroy();
#    }) -> grid(-row=>2, -column=>6, -sticky=>"nwse");
    my $scriptfile = $R_script_file;

    return ($script_text_box);
}

sub R_create_R_box {
    my ($text, $title, $frame, $R_proc, $R_commands_ref) = @_;
    my @R_commands = @$R_commands_ref;

    my $font = 'Courier 10 bold';
    my $R_box = $frame -> Scrolled ('Text',
        -scrollbars=>'e', -width=>90, -height=>16,
        -background=>"#FFFFFF",-exportselection => 0,
        -relief=>'groove', -border=>2, -wrap=>"none",
        -selectbackground=>'#606060', -highlightthickness =>0
    ) -> grid(-column=>1, -row=>1, -sticky=>'nwes');
    $R_box -> tagConfigure ("comment", -foreground=>"#888888", -font=>$font);
    $R_box -> tagConfigure ("r", -foreground=>"#3344ee", -font=>$font);
    $R_box -> tagConfigure ("command", -foreground=>"#000000", -font=>$font);
    $R_box -> tagConfigure ("pirana", -foreground=>"#cc6611", -font=>$font);
    $R_box -> tagConfigure ("error", -foreground=>"#880000", -font=>$font);

    $R_box -> bind ("<Return>", sub{
	my $idx = $R_box -> index('end');
	my $line = $R_box -> get (change_pos($idx, -2, 2), "end");
	R_insert_line ($R_proc, $R_box, $line, $R_commands_ref, 1);
	$R_box -> insert ("end", "> ");
	$R_box -> update();
    });
    $R_box -> bind ("<Control-Up>", sub{
	my $idx  = $R_box -> index('end');
	my $last_R_command = @$R_commands_ref[@$R_commands_ref];
        $R_box -> insert($idx, $last_R_command);
	$R_box -> markSet("insert", change_pos($idx,-1,2));
    });

    return ($R_box);
}
sub R_insert_multiple_lines {
    my ($R_proc, $R_box, $script, $R_commands_ref, $explicit_print) = @_;
    my @lines = split ("\n", $script);
    my $count_brack1 = 0;
    my $count_brack2 = 0;
    my $count_quote1 = 0;
    my $count_quote2 = 0;
    my $line_send = "";
    foreach my $line (@lines) {
	$line_send .= $line."\n";
	$count_brack1 = $count_brack1 + ($line =~ tr/\{//) - ($line =~ tr/\}//);
	$count_brack2 = $count_brack2 + ($line =~ tr/\(//) - ($line =~ tr/\)//);
	$count_quote1 = $count_quote1 + ($line =~ tr/\"//) - ($line =~ tr/"//);
	$count_quote2 = $count_quote2 + ($line =~ tr/\'//) - ($line =~ tr/\'//);
	if (($count_brack1 == 0)&
	    ($count_brack2 == 0)&
	    ($count_quote1 == 0)&
	    ($count_quote2 == 0)) {
	    $R_box -> insert ("end", $line_send);
	    R_insert_line ($R_proc, $R_box, $line_send, $R_commands_ref, 1);
	    $R_box -> insert ("end", "> ");
	    $R_box -> update();
	    $line_send = "";
	    $count_brack1 = 0;
	    $count_brack2 = 0;
	    $count_quote1 = 0;
	    $count_quote2 = 0;
	}
    }
    my $success = 0;
    if (($count_brack1 == 0)&
	($count_brack2 == 0)&
	($count_quote1 == 0)&
	($count_quote2 == 0)) {$success = 1};
    return ($success);
}

sub R_insert_line {
    my ($R_proc, $R_box, $line, $R_commands_ref, $explicit_print) = @_;
    push(@$R_commands_ref, $line);
    my $R_res;
    chomp($line);
    chomp($line);
    unless ($line eq "") {
	unless (($line =~ m/\<\-/)||($line =~ m/print/)||($explicit_print==0)) {
	    $line = "print (".$line.")";
	}
	$R_proc -> send($line."\n");
	$R_res = $R_proc -> read();
    }
    my $tag = "r";
    if ($R_res =~ m/\<simple/) {
	$R_res =~ s/\<simple//;
	chop($R_res);
	$tag = "error";
    }
    $R_box -> insert ("end", $R_res."\n", $tag);
    $R_box -> see ("end");
}

sub change_pos  {
    my ($idx, $dx, $dy ) = @_;
    my @xy = split (/\./, $idx);
    return ((@xy[0]+$dx).'.'.(@xy[1]+$dy));
}

sub R_run_script {
    my ($R, $R_script, $arg_ref) = @_;
    unless ($R =~ m/Statistics::R/) {
	(our $R, my $res) = R_start_process();
	unless ($res =~ m/Perl brige started/i) {
	    return("R process could not be started.")
	}
    }
    my @arg = @$arg_ref; # R script arguments
    my %args;
    my $i = 1;
    foreach my $argument (@arg) {
	$args{"#ARG".$i."#"} = $argument;
	$i++ ;
    }
    open (RSCR, "<".$R_script);
    my @lines = <RSCR>;
    close (RSCR);
    my $R_res ;
    my $i=0;
    foreach my $com (@lines) { # replace arguments
	$com =~ s/#ARG.#/$args{$&}/g;
	print $com;
	$i++;
    }
    $R -> send(join("\n",@lines));
    $R_res = $R -> read()."\n";
    return ($R_res);
}

sub R_start_process {
    my $r_dir = shift;
    my $bin = "R";
    my $cwd = "C:\\test";
    if ($^O =~ m /MSWin/i) {$bin = "R.exe"}
    my $R = Statistics::R -> new(
	-log_dir => $cwd,
	-r_dir => $cwd,
	-tmp_dir => $cwd,
	-r_bin => "C:/program files/R/R-2.10.0/bin/".$bin
	) ;
    $R -> startR ();
    my $read = $R -> read ();
    chdir ($cwd);
    return ($R, $read);
}

sub R_stop_process {
    my $R = shift;
    $R -> stopR () ;
    undef ($R);
}

1;
