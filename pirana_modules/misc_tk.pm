# Miscellaneous subroutines for Perl/Tk

package pirana_modules::misc_tk;

#use strict;
use Getopt::Std;
use Cwd;
require Exporter;

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(no_resize text_window message_yesno center_window);
my $bgcol = "#ededed"; 
my $button = "#dad7d3";
my $abutton = "#c6c3c0";
my $font_fixed = "Courier 9";

sub no_resize {
    # switches off the resizing of dialog-windows
    my $win = shift;
    # unless ($^O =~ m/linux/) { 
    $win -> resizable (0,0) ;
    # }
}

sub text_window {
### Purpose : Show a window with a text-widget containing the specified text
### Compat  : W+L+
  my ($mw, $text, $title, $font) = @_;
  if ($font eq "" ) {$font = $font_fixed};
  unless ($text_window) {
    our $text_window = $mw -> Toplevel(-title=>$title);
    $text_window -> OnDestroy ( sub{
      undef $text_window; undef $text_window_frame;
    });
    $text_window -> resizable( 0, 0 );
  }
  my $text_window_frame = $text_window -> Frame(-background=>$bgcol)->grid(-ipadx=>10,-ipady=>10)->grid(-row=>1,-column=>1, -sticky=>'nwse');
  $text_window_frame -> Button (-text => 'Close', -width=>12,
    -background=>$button, -activebackground=>$abutton, -border=>0,
    -command=> sub{
      $text_window -> destroy();
  }) -> grid(-column=>1, -row=>2, -sticky=>'ne');
  my $text_text = $text_window_frame -> Scrolled ('Text',
      -scrollbars=>'e', -width=>80, -height=>35,
      -background=>"#FFFFFF",-exportselection => 0,
      -relief=>'groove', -border=>2,
      -font=>$font, -wrap=>"none",
      -selectbackground=>'#606060', -highlightthickness =>0
  ) -> grid(-column=>1, -row=>1, -sticky=>'nwes');
  $text_text->insert('end', $text);
  return ($text_text);
}

sub message_yesno {
### Purpose : Show a small window with a text and an OK button
### Compat  : W+L+
    my ($text, $mw, $bgcol, $font_normal) = @_;
    my $bool = 0;
    my $message_box = $mw -> Toplevel (-title => "Pirana message", -background=> $bgcol);
    center_window($message_box);
    my $message_frame = $message_box -> Frame (-background=>$bgcol) -> grid(-ipadx => 10, -ipady => 10);
    $message_frame -> Label (-text=> $text."\n ", -font=>$font_normal, -background=>$bgcol) -> grid(-row=>1, -column=>1, -columnspan => 2);
    $message_frame -> Button (-text=>"No", -font=>$font_normal, -border=>0, -background=>$button, -activebackground=>$abutton, -command => sub{
	$message_box -> destroy();
    }) -> grid(-row=>2, -column=>1);
    $message_frame -> Button (-text=>"Yes", -font=>$font_normal, -border=>0, -background=>$button, -activebackground=>$abutton, -command => sub{
	$message_box -> destroy();
	$bool = 1;
    }) -> grid(-row=>2, -column=>2);
    $message_box -> focus ();
    $message_box -> waitWindow; # wait until destroyed
    return($bool);
    # $mw -> messageBox(-type=>'ok', -message=>@_[0]);
}

sub center_window {
### Purpose : Center dialog window
### Compat  : W+L+M-
### Notes   : Doesn't work properly on mac correct yet, and on Linux only Ubuntu nseems to get it right...
    my ($win, $center_window) = @_;
    # On windows this works fine, but on Linux this has been reported to not work correctly
    # so on linux this only works if you set the setting "center_window" to 1
    if (($^O =~ m/MSWin/i)||($center_window == 1)) {
	$win -> withdraw;   # Hide the window while we move it about
	$win -> update;     # Make sure width and height are current
	my $width = $win->width;
	my $height = $win->height;
	if ($width == 1) {$width=200} # assume width of 200 on Linux
	if ($height == 1) {$height=200} # assume width of 200 on Linux
	my $xpos = int(($win->screenwidth  - $width ) / 2);
	my $ypos = int(($win->screenheight - $height) / 2);
	$win -> geometry("+$xpos+$ypos");
	$win -> deiconify;  # Show the window again
	$win -> raise();
    }
}

1;
