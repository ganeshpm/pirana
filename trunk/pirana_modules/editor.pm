# Built-in modelfile editor

package pirana_modules::editor;

use strict;
use Tk;
use pirana_modules::misc qw(extract_file_name);
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(text_edit_window text_edit_window_build refresh_edit_window save_model);

our $status_col = "#eae8e2";
our $white          = "#ffffff";
our $bgcol          = "#efebe7";
our $button         = "#dad7d3";
our $abutton        = "#c6c3c0";

sub text_edit_window {
### Purpose : A built-in text editor for NM model files, the actual dialog
### Compat  : W+L+
  my ($text, $filename, $mw_ref, $font) = @_;
  if ($font eq "" ) {$font = "Courier 10"};
  my $mw = $$mw_ref;
  my $text_edit_window = $mw -> Toplevel(-title=>'Edit file');
  $text_edit_window -> resizable( 0, 0 );
  my $text_edit_window_frame = $text_edit_window -> Frame(-background=>$bgcol)->grid(-ipadx=>8,-ipady=>5)->grid(-row=>1,-column=>1, -sticky=>'nwse');
  text_edit_window_build ($text_edit_window_frame, $text, $filename, $font, 90, 40, 1) ;
}

sub text_edit_window_build {
  my ($text_edit_window_frame, $text, $filename, $font, $width, $height, $line_nrs) = @_;
  my $edit_status_bar = $text_edit_window_frame -> Label (
    -text=>"", -anchor=>"w", -font=>"Arial 8", -width=>$width, -background=>$bgcol, -foreground=>"#757575"
  )->grid(-column=>3,-row=>3,-sticky=>"w", -ipady=>0, -columnspan=>3);
  my $text_edit_scrollbar = $text_edit_window_frame -> Scrollbar()->grid(-column=>4,-row=>1,-sticky=>'nws');
  my $text_edit_text = $text_edit_window_frame -> Text (
      -width=>$width, -height=>$height, -yscrollcommand => ['set' => $text_edit_scrollbar],
      -background=>"#ffffff", -exportselection => 0, -wrap=>'none',
      -spacing1=>2, -spacing2=>0, -spacing3=>2,
      -relief=>'groove', -border=>2,
      -selectbackground=>'#606060',-font=>$font, -highlightthickness =>0
  )-> grid(-column=>3, -row=>1, -columnspan=>3,-sticky=>'nwes');
  $text_edit_text -> tagConfigure('block', -font => $font, -background => '#661111', -foreground=>'#FFFFFF' );
  $text_edit_text -> tagConfigure('comment', -font => $font, -foreground => '#3333bb' );
  $text_edit_text -> tagConfigure('theta', -font => $font, -foreground => '#882222' );

  my $text_line_nrs;
  if ($line_nrs == 1) {
      $text_line_nrs = $text_edit_window_frame -> Text (
	  -background=>$status_col, -font=>$font, -foreground=>'#888888', -highlightthickness =>0,-relief=>'groove',
	  -spacing1=>2, -spacing2=>0, -spacing3=>2,
	  -width=>4, -height=>$height, -pady=>2) -> grid(-column=>2, -row=>1, -sticky=>'nwes');
      $text_line_nrs -> tagConfigure('line', -justify=>'right');
  }
  $text_edit_window_frame -> Label (-text=>" ", -font=>$font, -justify=>"right", -width=>($width-10),
  ) -> grid(-row=>0, -column=>5, -sticky=>"nse");
  my $filename_label = $text_edit_window_frame -> Label (-text=>$filename, -font=>$font, -justify=>"right", #-width=>($width-10),
  ) -> grid(-row=>0, -column=>5, -sticky=>"nse");
  my $save_note_button = $text_edit_window_frame -> Button (-text=>'Save', -background=> $button, -activebackground=>$button, -border=>0, -command=> sub {
      unless ($filename eq "") {
	  save_model ($filename, $text_edit_text, $text_line_nrs, $edit_status_bar);
      }
  }) -> grid(-row=>0, -column=>3, -sticky=>"nsw");
  my $save_note_button = $text_edit_window_frame -> Button (-text=>'Save as...', -background=> $button, -activebackground=>$button, -border=>0, -command=> sub {
      my @spl = split (/\./,$filename);
      my $def_ext = ".".pop(@spl);
      my $file = extract_file_name ($filename);
      $filename = $text_edit_window_frame -> getSaveFile( -title => 'Save File:', -initialfile=> $file, -defaultextension => $def_ext, -initialdir => '.' );
      unless ($filename eq "") {
	  if ( save_model ($filename, $text_edit_text, $text_line_nrs, $edit_status_bar) ) {
	      $filename_label -> configure (-text=>$filename);
#	      $filename_label -> destroy ();
#	      $filename_label = $text_edit_window_frame -> Label (-text=>$filename, -font=>$font, -justify=>"right", #-width=>($width-10),
#		  ) -> grid(-row=>0, -column=>5, -sticky=>"nse");
	  }
      }
  }) -> grid(-row=>0, -column=>4, -sticky=>"nsw");
#  unless (-W $filename) {$save_note_button -> configure(-state=>'disabled')};
# the above commented command doesn't work on all systems, better done through stat()
  my $mode = (stat($filename))[2];
  my $mode2 = sprintf ("%04o", $mode & 07777);
  if ( substr($mode2, 0, 2) < 6) {
      $save_note_button -> configure(-state=>'disabled');
  }

  $text_edit_text -> bind('<Motion>' => sub {  # The MouseWheel event is not working on Linux, so this is used instead
      my @idx = $text_edit_text -> yview();
      if ($line_nrs == 1) {
      $text_line_nrs -> yview(moveto => @idx[0]);
    }
  });
  $text_edit_text -> bind('<KeyPress>' => sub {
    my @idx = $text_edit_text -> yview();
    if ($line_nrs == 1) {
	$text_line_nrs -> yview(moveto => @idx[0]);
    }
  });
  $text_edit_text -> bind('<Control-Key-s>' => sub {
    my $curs = $text_edit_text -> index("insert");
    my @loc = split (/\./, $curs);
    if ($line_nrs == 1) {
	$text_edit_text -> delete(@loc[0].".".(int(@loc[1])-1), $curs);
    }
    save_model($filename, $text_edit_text, $text_line_nrs, $edit_status_bar);
  });
  $text_edit_text -> bind('<Control-Key-S>' => sub {
    my $curs = $text_edit_text -> index("insert");
    my @loc = split (/\./, $curs);
    $text_edit_text -> delete(@loc[0].".".(int(@loc[1])-1), $curs);
    save_model($filename, $text_edit_text, $text_line_nrs, $edit_status_bar);
  });
  $text_edit_text -> bind('<Key-space>' => sub {
     my $code = $text_edit_text -> get("0.0", "end");
     refresh_edit_window($code, $text_edit_text, $text_line_nrs);
  });
  $text_edit_text -> bind('<Key-Return>' => sub {
     my $code = $text_edit_text -> get("0.0", "end");
     refresh_edit_window($code, $text_edit_text, $text_line_nrs);
  });
  $text_edit_text -> bind('<Key-Insert>' => sub {
     my $code = $text_edit_text -> get("0.0", "end");
     refresh_edit_window($code, $text_edit_text, $text_line_nrs);
  });
  $text_edit_text -> bind('<Key-Delete>' => sub {
     my $code = $text_edit_text -> get("0.0", "end");
     refresh_edit_window($code, $text_edit_text, $text_line_nrs);
  });
  $text_edit_text -> bind('<Key-BackSpace>' => sub {
     my $code = $text_edit_text -> get("0.0", "end");
     refresh_edit_window($code, $text_edit_text, $text_line_nrs);
  });
  $text_edit_scrollbar->configure(-command => ['yview' => $text_edit_text]);
  $text_edit_scrollbar -> bind('<Motion>' => sub {
    my @idx = $text_edit_text -> yview();
    if ($line_nrs == 1) {
	$text_line_nrs -> yview(moveto => @idx[0]);
    }
  });
  refresh_edit_window($text, $text_edit_text, $text_line_nrs);
  return ($text_edit_text, $filename_label);
}

sub save_model {
### Purpose : Save the text in the TextEdtitor window to a file
### Compat  : W+L+
     my ($filename, $text_edit_text, $text_line_nrs, $edit_status_bar ) = @_;

     my @yloc = $text_edit_text -> yview();
     my $code = $text_edit_text -> get("0.0", "end");
     refresh_edit_window($code, $text_edit_text, $text_line_nrs);
     $text_edit_text -> yview(moveto => @yloc[0]); # set the view back to the original location
     $text_line_nrs  -> yview(moveto => @yloc[0]);
     open (OUT, ">".$filename);
     print OUT $code;
     close OUT;
     $edit_status_bar -> configure (-text=>"File saved.");
     $edit_status_bar -> update();
     sleep(1);
     $edit_status_bar -> configure (-text=>"");
     $edit_status_bar -> update();
     if (-e $filename) {
	 return(1);
     }
}

sub refresh_edit_window {
### Purpose : Update the TextEditor window
### Compat  : W+L+
  my ($code, $text_edit_text, $text_line_nrs, $line_nrs) = @_;
  my $curs = $text_edit_text -> index("insert");
  my @yloc = $text_edit_text -> yview();
  my $i = 1;
  my @lines = split (/\n/, $code);
  if ($text_line_nrs ne "") {
      $text_line_nrs -> delete ("0.0", "end");
      foreach (@lines) {
	  $text_line_nrs -> insert ('end', $i."\n",  'line');
	  $i++;
      }
      $text_line_nrs -> insert ('end', $i."\n",  'line');
  }
  $text_edit_text -> delete ("0.0", "end");
  my $flag="";
  foreach (@lines) {
      unless ($^O =~ m/MSWin/i) {
	  $_ =~ s/\r\n?//g;
      }
      if (substr($_, 0,1) eq "\$") {
	  $flag = "";
	  $_ =~ m/\s/;
	  my $pos = length $`;
	  if ($pos == 0) { $pos = length($_)}
	  $text_edit_text -> insert('end', substr($_,0,$pos)."", 'block');
	  $_ = substr($_, $pos);
      }
      if ($_ =~ m/;/g) {
	  my $pos = length $`;
	  unless ($pos == 0) {
	      $text_edit_text -> insert('end', substr($_,0,$pos));
	      $_ = substr($_, $pos);
	  }
	  $text_edit_text -> insert('end', $_, 'comment');
	  $_ = "";
      }
      $text_edit_text -> insert('end', $_."\n");
  }
  $text_edit_text -> yview(moveto => @yloc[0]); # set the view back to the original location
  if ($text_line_nrs ne "") {
      $text_line_nrs  -> yview(moveto => @yloc[0]);
  }
  $text_edit_text -> SetCursor( $curs );
}
