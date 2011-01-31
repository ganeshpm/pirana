use Tk;
use Cwd;
use Text::ParseWords;

my $variables_ref = wizard_read_pwiz_file ("parallel.pwiz", \@args);
my %var = %$variables_ref;
our $mw = MainWindow -> new (-title => "Pirana wizard: ".$var{wiz_type}, -background=>$bgcol);
our $bgcol          = "#efebe7";
our $button         = "#dad7d3";
our $abutton        = "#c6c3c0";
our $white = "#FFFFFF";
our $bbw = 1;
our $font_family = "Helvetica";
our $font_fixed_family = "Courier";
my %setting;
$setting{font_size} = 11;
my $font_small_size = ($setting{font_size} - 1);
our $font = $font_family.' '.$setting{font_size};
our $font_normal =  $font_family.' '.$setting{font_size};
our $font_small =  $font_family.' '.$font_small_size;
our $font_fixed = $font_fixed_family.' '.$setting{font_size};
our $font_bold =  $font_family.' '.$setting{font_size}.' bold';
my $base_dir = "~/svn/pirana";

my @args = ("linux", "/opt/NONMEM/nmvi");
wizard_build_dialog ($mw, $variables_ref);
$mw -> raise;

MainLoop();

sub rm_spaces {
# Remove leading and trailing spaces and \n, and []
    my $str = shift;
    chomp ($str);
    $str =~ s/^\s+//; # leading spaces
    $str =~ s/\s+$//; # trailing space
    return ($str);
}

sub clean_string {
    my $str = shift;
    $str = rm_spaces($str);
    $str =~ s/\/(E|O|A|Q|S)//g; 
    $str =~ s/\[//g; 
    $str =~ s/\]//g;
    $str =~ s/\"//g;
    $str =~ s/\\n/\n/g;
    return($str);
}

sub get_key {
    my $line = shift;
    $line =~ m/\[(.*?)\]/i; 
    return ($1);
}

sub wizard_read_pwiz_file {
    my ($wiz_file, @args) = @_;
    open (WIZ, "<".$wiz_file);
    my @lines = <WIZ>;
    close WIZ;
    my $s_area; my $q_area; my $screen_name; my $wiz_area = 0;
    my @screens; my %wiz_variables; my $q_key;
    my %questions; our @question_keys; my %screen_questions;
    my @answer_keys; my @answers; my %question_answers; my %answer_defaults; 
    my %optionmenu_options;
    foreach my $line (@lines) {
	if (substr($line, 0, 5) =~ m/\[WIZ\]/i) {
	    $wiz_area = 1;
	} 
	if (substr($line, 0, 6) =~ m/\[TYPE\]/i) {
	    $line =~ s/\[TYPE\]//i;
	    $line =~ s/\[\/TYPE\]//i;
	    $line = rm_spaces($line);
	    $wiz_variables{wiz_type} = $line;
	}	
        if ((substr($line, 0, 3) =~ m/\[S\]/i)&&($wiz_area == 1)) { 
	    $s_area = 1;
	    $line =~ s/\[S\]//i;
	    $screen_name = rm_spaces($line);
	    push (@screens, $screen_name);    
	}
	if ((substr($line, 0, 3) =~ m/\[Q\]/i)&&($wiz_area == 1)) {
	    $line =~ s/\[Q\]//i;
	    $line = rm_spaces($line);
	    $line =~ s/\\n/\n/g;
	    $q_key = get_key ($line);
	    my @q = split ("]", $line);
	    $questions{$q_key} = rm_spaces (@q[1]);
	    push (@question_keys, $q_key);
	}
	if ((substr($line, 0, 3) =~ m/\[(E|O)\]/i)&&($wiz_area == 1)) {
	    my $type = substr($line,0,3); # widget type to make (E/O)
	    $type =~ s/(\[|\]|\s)//g;
	    $line =~ s/\[(E|O)\]//i;
	    $line = rm_spaces($line);
	    my $a_key = get_key ($line);
	    my @l = split ("]", $line); # get key information
	    $answer_defaults{$a_key} = clean_string (@l[1]);
	    push (@answer_keys, $a_key);
	    if ($type eq "E") {	# Entry widget
		my @a = split (",", @l[0]); # get key, extra info
		$answers{$a_key} = rm_spaces (@a[0]);
		my $width = @a[1];
		unless ($width =~ m/\d/g) { $width = 20}
		$answer_widths{$a_key} = rm_spaces ($width);
	    }
	    if ($type eq "O") { # Optionmenu	
		my @a = split (",", @l[0]); # get key, extra info
		$answers{$a_key} = rm_spaces (@a[0]);
		shift(@a);
		$optionmenu_options{$a_key} = rm_spaces(join (",", @a));
		if (substr($optionmenu_options{$a_key},0,1) eq "(") { $optionmenu_options{$a_key} = substr($optionmenu_options{$a_key}, 1, -1) }
	    }
	}
	if ((substr($line, 0, 4) =~ m/\[\/Q\]/i)&&($wiz_area == 1)) {
	    my @answer_keys_cp = @answer_keys;
	    $question_answers{$q_key} = \@answer_keys_cp;
	    @answer_keys = ();
	}
        if ((substr($line, 0, 4) =~ m/\[\/S\]/i)&&($wiz_area == 1)) {
	    my @question_keys_cp = @question_keys;
	    $screen_questions{$screen_name} = \@question_keys_cp;
	    @question_keys = ();
	    $s_area = 0
	}
    }
    $wiz_variables{screens} = \@screens;
    $wiz_variables{screen_questions} = \%screen_questions;
    $wiz_variables{questions} = \%questions;
    $wiz_variables{question_keys} = \@questions;
    $wiz_variables{question_answers} = \%question_answers;
    $wiz_variables{answers} = \%answers;
    $wiz_variables{answer_keys} = \@answer_keys;
    $wiz_variables{answer_widths} = \%answer_widths;
    $wiz_variables{answer_defaults} = \%answer_defaults;
    $wiz_variables{optionmenu_options} = \%optionmenu_options;
    $wiz_variables{total_screens} = int(@screens);
    return (\%wiz_variables)
}

sub wizard_build_dialog {
    my ($window, $variables_ref, $entry_values_ref) = @_;
    my %var = %$variables_ref;

    # put all variables in correct hashes and arrays again;
    my @screens = @{$var{screens}};
    my %screen_questions = %{$var{screen_questions}};
    my %questions = %{$var{questions}};
    my @question_keys = @{$var{question_keys}};
    my %question_answers = %{$var{question_answers}};
    my %answers = %{$var{answers}};
    my @answer_keys = @{$var{answer_keys}};
    my %answer_widths = %{$var{answer_widths}};
    my %answer_defaults = %{$var{answer_defaults}};
    my %optionmenu_options = %{$var{optionmenu_options}};

    # create new hashes to collect the information entered
    my %entry_values = %$entry_values_ref;

    my $i_row = 0;
    if ($var{i_screen} == 0 ) {
	$var{i_screen} = 0;
    }
    my $button_text = "Finish";
    if (@screens > 1) {
	$button_text = "Next";
    }
    my $frame = $window -> Frame (-background => $bgcol) -> grid(-ipadx => 10, -ipady => 10); 
    for ($i = 0; $i < 16; $i++) {
	$frame -> Label (-background=>$bgcol, -font=>$font_normal, -width=>80, -text=> "  "
	    ) -> grid (-row=>$i, -column=>1, -rowspan=>1, -columnspan=>2);
    }
    $frame -> Label (-text=> "Step ".($var{i_screen} + 1)." of ".$var{total_screens}.": ".@screens[$var{i_screen}], -background => $bgcol, -font=>$font_bold
	) -> grid(-row=>1, -column=>1,-sticky=>"nws"); 

    my @curr_questions = @{$screen_questions{@screens[$var{i_screen}]}};
    foreach my $q_key (@curr_questions) {
	$frame -> Label (-text => $questions{$q_key}, -justify=> "right", -font=>$font_normal, -background=>$bgcol
	    ) -> grid (-row=> (3+($i_row*2)), -column=>1, -sticky => "nes");
	$frame -> Label (-text => " ", -font=>$font_normal, -background=>$bgcol  # SPACER
	    ) -> grid (-row=> (4+($i_row*2)), -column=>1, -sticky => "nws");
	my @curr_answers = @{$question_answers{$q_key}};
	foreach my $a (@curr_answers) {
	    $entry_values{$a} = $answer_defaults{$a};
	    unless ($answer_widths{$a} eq "") { # test, if no value here, than the key does not refer to an entry
		$frame -> Entry (-width=> $answer_widths{$a}, -font=>$font_normal, -textvariable => $entry_values{$a}, -border=>$bbw, -background=>$white
		    ) -> grid (-row=> (3+($i_row*2)), -column=>2, -sticky => "nw");	       
	    };
	    unless ($optionmenu_options{$a} eq "") { # test, if options specified, implement optionmenu
		my @opt = quotewords(",", 0, $optionmenu_options{$a});
		$entry_values{$a} = int($entry_values{$a});
		my $optionmenu = $frame -> Optionmenu (-options => \@opt, -justify=>"left", -font=>$font_normal, -border=>$bbw
		    ) -> grid (-row=> (3+($i_row*2)), -column=>2, -sticky => "nw"); 
		$optionmenu -> configure (-textvariable => \$opt[$entry_values{$a}]);
	    } 
	}
	$i_row++;
    }

    my $button_frame = $frame -> Frame (-background=>$bgcol) -> grid (-row => 15, -column => 2, -columnspan=>2, -sticky=>"nse");
    my $prv_button = $button_frame -> Button (-text=> "Previous", -background => $bgcol, -font=>$font_normal,  -command => sub {
	$var{i_screen} = $var{i_screen} - 1;    
	$frame -> destroy();
	wizard_build_dialog($window, \%var, \%entry_values);
    }) -> grid(-row=>1, -column=>1,-sticky=>"nwse"); 
    my $next_button = $button_frame -> Button (-text=> "Next", -background => $bgcol, -font=>$font_normal,  -command => sub {
	$var{i_screen}++;
	$frame -> destroy();
	wizard_build_dialog($window, \%var, \%entry_values);
    }) -> grid(-row=>1, -column=>2,-sticky=>"nwse"); 
    my $finish_button = $button_frame -> Button (-text=> "Finish", -background => $bgcol, -font=>$font_normal, -state=>'disabled', -command => sub {
	$mw -> destroy();
    }) -> grid(-row=>1, -column=>3,-sticky=>"nwse"); 
    if ($var{i_screen} == 0) {
	$prv_button -> configure (-state=>'disabled');
    }
    if ($var{i_screen} >= ($var{total_screens}-1)) {
	$finish_button -> configure (-state=>'normal');
	$next_button -> configure (-state=>'disabled');
    }
    wizard_write_output(\%var);
    return(1);
}

sub wizard_write_output {
    my $variables_ref = shift;
    my %var = %$variables_ref;
    return(1);
}
