use Tk;
use Cwd;
use Text::ParseWords;

my @args = ("linux", "/opt/NONMEM/nmvi");
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
    $str =~ s/\/(E|O|A|Q|S|C)//g; 
    $str =~ s/\[//g; 
    $str =~ s/\]//g;
    $str =~ s/\"//g;
    $str =~ s/\\n/\n/g;
    return($str);
}

sub get_key {
    my $line = shift;
    $line =~ m/\[(.*?)\]/i;
    my ($key, $rest) = split (",", $line);
    $key = clean_string($key);
    return ($key);
}

sub wizard_read_pwiz_file {
    my ($wiz_file, @args) = @_;
    open (WIZ, "<".$wiz_file);
    my @lines = <WIZ>;
    close WIZ;
    my $s_area; my $q_area; my $screen_name; my $wiz_area = 0; my $out_area = 0;
    my @screens; my %wiz_variables; my $q_key; my @out_text = ();
    my %questions; our @question_keys; my %screen_questions;
    my @answer_keys; my @answers; my %question_answers; my %answer_defaults; 
    my %optionmenu_options; my %checkboxes;
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
	if ((substr($line, 0, 3) =~ m/\[(E|O|C)\]/i)&&($wiz_area == 1)) {
	    my $type = substr($line,0,3); # widget type to make (E/O)
	    $type =~ s/(\[|\]|\s)//g;
	    $line =~ s/\[(E|O|C)\]//i;
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
		@l[0] =~ s/(\(|\)|\[|\])//g;
		my @a = quotewords (",", 0, @l[0]); # get key, extra info
		$answers{$a_key} = rm_spaces (@a[0]);
		shift(@a);
		$optionmenu_options{$a_key} = rm_spaces(join (",", @a));
	    }
	    if ($type eq "C") { # Checkbox	
		@l[0] =~ s/(\(|\)|\[|\])//g;
		my @a = quotewords (",", 0, @l[0]); # get key, extra info
		$answers{$a_key} = rm_spaces (@a[0]);
		shift(@a);
		$checkboxes{$a_key} = rm_spaces(join (",", @a));
		# put answers in hash
		$answer_defaults{$a_key} =~ m/\((.*?)\)/;
		my @answ = split (",",$1);
		my $j = 1;
		foreach (@a) { # set defaults to 0
		    my $key = $a_key . "_" . $j ;
		    $answer_defaults{$key} = 0;
		    $j++;
		}
		for (my $j = 0; $j <= length(@answ); $j++) { # put some checkboxes back on
		    my $key = $a_key . "_" . @answ[$j];
		    $answer_defaults{$key} = 1;		    
		}
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
	if (substr($line,0,6) =~ m/\[\/OUT\]/i) {
	    $out_area = 0;
	}
	if ($out_area == 1) {
	    push (@out_text, $line);
	}
	if (substr($line,0,5) =~ m/\[OUT\]/i) {
	    $out_area = 1;
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
    $wiz_variables{checkboxes} = \%checkboxes;
    $wiz_variables{total_screens} = int(@screens);
    $wiz_variables{out_text} = \@out_text;
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
    my %checkboxes = %{$var{checkboxes}};
    my $out_text_ref = $var{out_text};

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
		$frame -> Entry (-width=> $answer_widths{$a}, -font=>$font_normal, -textvariable => \$entry_values{$a}, -border=>$bbw, -background=>$white
		    ) -> grid (-row=> (3+($i_row*2)), -column=>2, -sticky => "nw");	       
	    };
	    unless ($optionmenu_options{$a} eq "") { # test, if options specified, implement optionmenu
		my @opt = quotewords(",", 0, $optionmenu_options{$a});
		$entry_values{$a} = int($entry_values{$a});
		my $optionmenu = $frame -> Optionmenu (-options => \@opt, -justify=>"left", -font=>$font_normal, -border=>$bbw
		    ) -> grid (-row=> (3+($i_row*2)), -column=>2, -sticky => "nw"); 
		$optionmenu -> configure (-textvariable => \$opt[$entry_values{$a}]);
	    }
	    unless ($checkboxes{$a} eq "") { # test, if options specified, implement checkbox
		my @chkboxes = quotewords (",", 0, $checkboxes{$a});
		my %checkbox_checked;
		my $j = 1;
		foreach my $box (@chkboxes) {
		    my $ref = $a."_".$j;
		    $entry_values{$ref} = $answer_defaults{$ref};
		    $frame ->  Checkbutton (-text => $box, -variable=> \$entry_values{$ref}, -font=>$font_normal, -justify=>"left", -background=>$bgcol, -border=>$bbw, -command => sub{
			print $ref;		    
                    }
		    ) -> grid (-row=> (3+($i_row*2)+$j), -column=>2, -sticky => "nw");
		    $j++;
		}
		$i_row = $i_row + $j;
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
	my @keys = keys(%entry_values);
	my %values = %entry_values;
	foreach my $a (@keys) {
	    unless ($optionmenu_options{$a} eq "") {
		my @opt = quotewords(",", 0, $optionmenu_options{$a});
		$values{$a} = @opt[$entry_values{$a}];
	    }
	}
	wizard_write_output ($out_text_ref, \%values);
	$mw -> destroy();
    }) -> grid(-row=>1, -column=>3,-sticky=>"nwse"); 
    if ($var{i_screen} == 0) {
	$prv_button -> configure (-state=>'disabled');
    }
    if ($var{i_screen} >= ($var{total_screens}-1)) {
	$finish_button -> configure (-state=>'normal');
	$next_button -> configure (-state=>'disabled');
    }
    return(1);
}


sub wizard_write_output {
    my ($out_text_ref, $values_ref)  = @_;
    my @out_text = @$out_text_ref;
    my @all = ();
    my $all_ref = parse_lines ($out_text_ref, $values_ref);
    my %values = %$values_ref;
    my $output_file = $values{output_file};

    open (OUT, ">".$output_file ); 
    print @$all_ref;
    close OUT;
    
    return(1);
}

sub parse_lines {
    # this is done in a subroutine to be able to make it recursive 
    my ($text_ref, $values_ref) = @_;
    my @text = @$text_ref; my %values = %$values_ref; my $n;
    my $if_area = 0; my @if_text; my $if_key = ""; my $if_print = 0;
    my $for_area = 0; my @for_text; my $for_start; my $for_stop; my $i;
    my @all;
    foreach my $line (@text) {
	my $skip_line = 0;
	# parse if-routines
	if ($line =~ m/\[\/IF/i) { 
	    $skip_line = 1;
	    if ($if_print == 1) { 
		my $if_ref = parse_lines (\@if_text, $values_ref);
		push (@all, @$if_ref) 
	    }; 
	    $if_print = 0;
	    $if_area = 0; 
	}
	if ($if_area == 1) {
	    $skip_line = 1;
	}	
	if ($if_print == 1) {
	    push (@if_text, $line);	
	}
	if ($line =~ m/\[IF(.*?)\]/i) {
	    $skip_line = 1;
	    @if_text = ();
	    my $newline = clean_string ($1);
	    my ($if_str, $if_key, $if_answer, $rest) = split (",", $newline);
	    my $answer = rm_spaces($if_answer);
	    my $l = length($answer);
	    my $value = substr(rm_spaces($values{$if_key}),0,$l);
 	    $if_area = 1;
	    $if_print = 0;
	    if ($value eq $answer) {
		$if_print = 1;
	    } 
	}	

	# parse for-routines
 	if ($line =~ m/\[\/LOOP/i) { 
	    $skip_line = 1;
	    $for_area = 0;
	    for ($i = $for_start; $i <= $for_stop; $i++) {
		my @for_text_copy = @for_text;
		foreach my $text (@for_text_copy) {
		    $text =~ s/\[\[\%i\]\]/$i/g;
		}
		my $for_ref = parse_lines(\@for_text_copy, $values_ref); 
		push (@all, @$for_ref);
	    }
	}
	if (($if_area == 0)&&($for_area == 1)) {
	    $skip_line = 1;
	    push (@for_text, $line);
	}
	if ($line =~ m/\[LOOP(.*?)\]/i) {
	    $skip_line = 1;
	    $for_area = 1;
	    @for_text = ();
	    my $text = $1;
	    $text =~ s/LOOP//i;
	    $text =~ s/\,//;
	    ($for_start, $for_stop) = split ("\:",rm_spaces($text));
	    unless ($for_start =~ /^(\d+)$/) {$for_start = rm_spaces($values{$for_start})}; 
	    unless ($for_stop =~ /^(\d+)$/) {$for_stop = rm_spaces($values{$for_stop})};
	}

	# print to file
	if ($skip_line == 0) {
	    while ( $line =~ m/(\[\[(.*?)\]\])/ ) {
		my $key = clean_string($1);
		my $value;
		if ($key =~ m/\,/) {
		    ($key, $n) = split (",", $key);
		    $value = substr(rm_spaces($values{$key}),0,$n);
		} else {
		    $value = rm_spaces($values{$key});
		}
		$line =~ s/(\[\[(.*?)\]\])/$value/;		
	    };
	    push(@all, $line);
	}

    }
    return (\@all);
}

sub substitute_keys {
    my ($line) = @_;
    
}
