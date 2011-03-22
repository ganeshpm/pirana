#  Subroutines for Wizards

package pirana_modules::wizards;
use strict;
require Exporter;
use Tk;
use Cwd;
use Text::ParseWords;
use pirana_modules::misc qw(rm_spaces);

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(clean_string get_key wizard_read_pwiz_file wizard_write_output parse_lines);

sub clean_string {
    my $str = shift;
    $str = rm_spaces($str);
    $str =~ s/\/(M|E|F|O|A|Q|S|C)//g; 
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
    my @answer_keys; my %answers; my %question_answers; my %answer_defaults;  my %answer_widths;
    my %optionmenu_options; my %checkboxes; my %messages; my %file_entries;
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
	if ((substr($line, 0, 3) =~ m/\[M\]/i)&&($wiz_area == 1)) {
	    $line =~ s/\[M\]//i;
	    $line =~ s/\[\/M\]//i;
	    $line = rm_spaces($line);
	    $line =~ s/\\n/\n/g;
	    my $m_key = get_key ($line);
	    my @m = split ("]", $line);
	    $messages{$m_key} = rm_spaces (@m[1]);
	    push (@question_keys, $m_key);
	}
	if ((substr($line, 0, 3) =~ m/\[(E|F|O|C)\]/i)&&($wiz_area == 1)) {
	    my $type = substr($line,0,3); # widget type to make (E/O)
	    $type =~ s/(\[|\]|\s)//g;
	    my $line_orig = $line;
	    $line =~ s/\[(E|F|O|C)\]//i;
	    $line = rm_spaces($line);
	    my $a_key = get_key ($line);
	    my @l = split ("]", $line); # get key information
	    $answer_defaults{$a_key} = clean_string (@l[1]);
	    push (@answer_keys, $a_key);
	    if (($type eq "E") || ($type eq "F")) {	# Entry widget
		my $answer;
		my $width=20;
		if (@l[0] =~ m/,/) {
		    my @a = split (",", @l[0]); # get key, extra info
		    $width = @a[1];
		    $answer = rm_spaces(@a[0]);
		} else {
		    $answer = rm_spaces(@l[0]);
		}
		$answers{$a_key} = $answer;
		if (substr($line_orig, 0, 3) =~ m/\[F\]/i) {
		    $file_entries{$a_key} = $answer ;
		}
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
    $wiz_variables{messages} = \%messages;
#    $wiz_variables{question_keys} = \@questions;
    $wiz_variables{question_answers} = \%question_answers;
    $wiz_variables{answers} = \%answers;
    $wiz_variables{answer_keys} = \@answer_keys;
    $wiz_variables{file_entries} = \%file_entries;
    $wiz_variables{answer_widths} = \%answer_widths;
    $wiz_variables{answer_defaults} = \%answer_defaults;
    $wiz_variables{optionmenu_options} = \%optionmenu_options;
    $wiz_variables{checkboxes} = \%checkboxes;
    $wiz_variables{total_screens} = int(@screens);
    $wiz_variables{out_text} = \@out_text;
    return (\%wiz_variables)
}

sub wizard_write_output {
    my ($out_text_ref, $values_ref)  = @_;
    my @out_text = @$out_text_ref;
    my @all = ();
    my $all_ref = parse_lines ($out_text_ref, $values_ref);
    my %values = %$values_ref;
    my $output_file = $values{output_file};

    open (OUT, ">".$output_file ); 
    print OUT @$all_ref;
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
	$line =~ s/\\\;/\;/ ;
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

1;
