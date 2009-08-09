# Built-in modelfile editor

package pirana_modules::editor;

use strict;
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(text_edit_window refresh_edit_window save_model);

our $text_edit_text; our $text_edit_window; our $text_line_nrs; our $edit_status_bar; our $text_edit_window_frame;
our $bgcol ="#ece9d8"; our $button="#dddac9"; our $abutton = "#cecbba"; 
our $status_col = "#fffdec"; our $font_fixed2 = "Courier 10";

sub text_edit_window {
### Purpose : A built-in text editor for NM model files, the actual dialog
### Compat  : W+L+
  my ($text, $filename, $mw_ref) = @_;
  unless ($text_edit_window) {
  my $mw = $$mw_ref;
  undef $text_edit_window;
  our $text_edit_window = $mw -> Toplevel(-title=>'Edit file: '.$filename);
    $text_edit_window -> OnDestroy ( sub{
       undef $text_edit_window; undef $text_edit_window_frame;
    });
    $text_edit_window -> resizable( 0, 0 );
  }
  our $text_edit_window_frame = $text_edit_window -> Frame(-background=>$bgcol)->grid(-ipadx=>10,-ipady=>5)->grid(-row=>1,-column=>1, -sticky=>'nwse');
  our $edit_status_bar = $text_edit_window_frame -> Label (
    -text=>"", -anchor=>"w", -font=>"Arial 8", -width=>100, -background=>$bgcol, -foreground=>"#757575"
  )->grid(-column=>3,-row=>3,-sticky=>"w", -ipady=>0, -columnspan=>1);
  my $save_note_button = $text_edit_window_frame -> Button (-text=>'Save', -background=> $button, -activebackground=>$button, -command=> sub {
    save_model($filename);
  }) -> grid(-row=>1, -column=>1, -sticky=>"nw");
  my $text_edit_scrollbar = $text_edit_window_frame -> Scrollbar()->grid(-column=>4,-row=>1,-sticky=>'nws');
  our $text_edit_text = $text_edit_window_frame -> Text (
      -width=>90, -height=>40, -yscrollcommand => ['set' => $text_edit_scrollbar],
      -background=>"#ffffff", -exportselection => 0, -wrap=>'none',
      -relief=>'groove', -border=>2, 
      -selectbackground=>'#606060',-font=>$font_fixed2, -highlightthickness =>0
  )-> grid(-column=>3, -row=>1, -sticky=>'nwes');
  $text_edit_text -> tagConfigure('block', -font => "Courier 10", -background => '#661111', -foreground=>'#FFFFFF' );
  $text_edit_text -> tagConfigure('comment', -font => "Courier 10", -foreground => '#4444cc' );
  $text_edit_text -> tagConfigure('theta', -font => "Courier 10", -foreground => '#882222' );
 
  our $text_line_nrs = $text_edit_window_frame -> Text ( 
    -background=>$status_col, -font=>"Courier 8", -highlightthickness =>0,-relief=>'groove',
    -width=>4, -pady=>2,-spacing1=>2) -> grid(-column=>2, -row=>1, -sticky=>'nwes');
  $text_line_nrs -> tagConfigure('line', -justify=>'right');
  $text_edit_text -> bind('<MouseWheel>' => sub {
    my @idx = $text_edit_text -> yview();
    $text_line_nrs -> yview(moveto => @idx[0]);
  });
  $text_edit_text -> bind('<KeyPress>' => sub {
    my @idx = $text_edit_text -> yview();
    $text_line_nrs -> yview(moveto => @idx[0]);
  });
  $text_edit_window -> bind('<Control-Key-s>' => sub {
    my $curs = $text_edit_text -> index("insert");
    my @loc = split (/\./, $curs);
    $text_edit_text -> delete(@loc[0].".".(int(@loc[1])-1), $curs);
    save_model($filename);
  });
  $text_edit_window -> bind('<Control-Key-S>' => sub {
    my $curs = $text_edit_text -> index("insert");
    my @loc = split (/\./, $curs);
    $text_edit_text -> delete(@loc[0].".".(int(@loc[1])-1), $curs);
    save_model($filename);
  });
  $text_edit_window -> bind('<Key-space>' => sub {
     my $code = $text_edit_text -> get("0.0", "end");
     refresh_edit_window($code);
  });
  $text_edit_window -> bind('<Key-Return>' => sub {
     my $code = $text_edit_text -> get("0.0", "end");
     refresh_edit_window($code);
  });
  $text_edit_window -> bind('<Key-Insert>' => sub {
     my $code = $text_edit_text -> get("0.0", "end");
     refresh_edit_window($code);
  });
  $text_edit_window -> bind('<Key-Delete>' => sub {
     my $code = $text_edit_text -> get("0.0", "end");
     refresh_edit_window($code);
  });
  $text_edit_window -> bind('<Key-BackSpace>' => sub {
     my $code = $text_edit_text -> get("0.0", "end");
     refresh_edit_window($code);
  });
  $text_edit_scrollbar->configure(-command => ['yview' => $text_edit_text]);
  $text_edit_scrollbar -> bind('<Motion>' => sub {
    my @idx = $text_edit_text -> yview();
    $text_line_nrs -> yview(moveto => @idx[0]);
  });
  refresh_edit_window($text);
}

sub save_model {
### Purpose : Save the text in the TextEdtitor window to a file
### Compat  : W+L+
     my @yloc = $text_edit_text -> yview();
     my $filename = shift;
     my $code = $text_edit_text -> get("0.0", "end");
     refresh_edit_window($code);
     $text_edit_text -> yview(moveto => @yloc[0]); # set the view back to the original location
     $text_line_nrs  -> yview(moveto => @yloc[0]);
     open (OUT, ">".$filename);
     print OUT $code;
     close OUT;
     $edit_status_bar -> configure (-text=>"Modelfile saved.");
     $edit_status_bar -> update();
     sleep(1);
     $edit_status_bar -> configure (-text=>"");
     $edit_status_bar -> update();
     $text_edit_text -> focus();
}

sub refresh_edit_window {
### Purpose : Update the TextEditor window
### Compat  : W+L+
  my $code = shift;
  my $curs = $text_edit_text -> index("insert");
  my @yloc = $text_edit_text -> yview();
  my $i = 1;
  my @lines = split (/\n/, $code);
  $text_line_nrs -> delete ("0.0", "end");
  foreach (@lines) {
    $text_line_nrs -> insert ('end', $i."\n",  'line');
    $i++;
  }
  $text_edit_text -> delete ("0.0", "end");
  $text_line_nrs -> insert ('end', $i."\n",  'line');
  my $flag=""; 
  foreach (@lines) {
    if (substr($_, 0,1) eq "\$") {
      $flag = "";
      $_ =~ m/\s/;
      my $pos = length $`; 
      if ($pos == 0) { $pos = length($_)}
      $text_edit_text -> insert('end', substr($_,0,$pos)."", 'block');
      $_ = substr($_, $pos, );
    }
    if ($_ =~ m/\;/g) { 
      my $pos = length $`;
      $text_edit_text -> insert('end', substr($_,0,$pos));
      $text_edit_text -> insert('end', substr($_,$pos,length($_)), 'comment');
      $_ = "";
    }
    $text_edit_text -> insert('end', $_."\n");
  }
  $text_edit_text -> yview(moveto => @yloc[0]); # set the view back to the original location
     $text_line_nrs  -> yview(moveto => @yloc[0]);
     $text_edit_text -> SetCursor( $curs );
}
