# module to create the data-inspector window

package pirana_modules::data_inspector;

use strict;
use Tk::Balloon;
use List::Util qw(max min);
use pirana_modules::misc  qw(win_path unix_path win_start); 

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(create_plot_window read_table);

our $bgcol      = "#ece9d8";
our $button     = "#dddac9";
our $abutton    = "#cecbba";
our $status_col = "#fffdec";
our $pirana_orange  = "#ffEE99";
our $lighterblue    = "#d3d3e3";
our $lightblue      = "#b3c3ea";
our $darkblue       = "#a5b5dc";
our $lightred       = "#FFC9a4";
our $darkred        = "#efb894";
our $darkerred      = "#BE5040";
our $lightyellow    = "#EFEFc7";
our $darkyellow     = "#DFDF95";
our $lightgreen     = "#b8e3b8";
our $darkgreen      = "#a5d3a5";
our $yellow         = "#f8f8e6";
our $white          = "#ffffff";
our $bbw = 0;
our (@filter_match, @filter_type, @filter_var, @filter_entry, @border,
     @xdata, @ydata, @colname, @x_sel, @y_sel, @plot_colors, @pointstyles,
     $table_type, $log_x, $log_y, $x_var_list, $y_var_list, $unity_line, 
     $show_unity, $plot_table, $main_window, $r_dir, $skip_lines, $cnames,
     $x_var, $y_var, $xType, $yType, $plot_frame, $r_text, $r_filter,$r_in_gif_ref, $read_what, 
     $r_delete_ref, $y_var_list, $x_var_list, $help_box,
     %values);

sub create_plot_window {
### Purpose : Create the dataInspector window
### Compat  : W+L?
  ($main_window, $plot_table, $table_type, $r_dir, $r_in_gif_ref, $r_delete_ref) = @_;
  our $plot_window = $main_window -> Toplevel(-title=>"Pira�a Data Inspector (".$plot_table.")"); 
  $plot_window -> resizable( 0, 0 );
  $plot_window -> Popup;

  @plot_colors = qw/darkblue darkred darkgreen/;
  @pointstyles = qw/circle square triangle/;
  $plot_frame = $plot_window -> Frame (-relief=>'groove', -border=>2) -> grid(-column=>2, -row=>1, -sticky=>'nwe');
  our $r_in_gif  = $$r_in_gif_ref;
  our $delete_gif = $$r_delete_ref;

  my $var_frame = $plot_window -> Frame (-relief=>'groove', -border=>0, -padx=>7, -pady=>7) -> grid(-column=>1, -rowspan=>1,-row=>1,-sticky=>'nw');
  my $add_frame = $plot_window -> Frame (-relief=>'groove', -border=>0, -padx=>7, -pady=>7) -> grid(-column=>1, -rowspan=>1,-row=>2,-sticky=>'nwe');
  my $r_frame = $plot_window -> Frame (-width=>510, -relief=>'groove', -border=>0, -pady=>7) -> grid(-column=>2, -row=>2,-sticky=>'nw');
  $var_frame -> Label (-text=>"X-axis") -> grid(-column=>1, -row=>1, -sticky=>'nwe');
  $var_frame -> Label (-text=>"Y-axis") -> grid(-column=>2, -row=>1, -sticky=>'nwe');
  $add_frame -> Label (-text=>"Additional graphic parameters:      ")-> grid(-column=>1, -row=>3, -columnspan=>2, -sticky=>'nw');
  $add_frame -> Checkbutton(-text=>"Show unity line", -variable=>\$show_unity, -command=>sub{refresh_plot();})->grid(-column=>1,-columnspan=>2,-row=>4, -sticky=>"w");
  $add_frame -> Checkbutton(-text=>"Log X-axis", -variable=>\$log_x, -command=>sub{refresh_plot();})->grid(-column=>1,-columnspan=>2,-row=>6, -sticky=>"w");
  $add_frame -> Checkbutton(-text=>"Log Y-axis", -variable=>\$log_y, -command=>sub{refresh_plot();})->grid(-column=>1,-columnspan=>2,-row=>7, -sticky=>"w");
  $add_frame -> Label (-text=>"   ")-> grid(-column=>1, -row=>8, -sticky=>'nw');

  $x_var_list = $var_frame -> Listbox (-width=>10, -height=>26, -activestyle=> 'none', -exportselection => 0, -relief=>'groove', -border=>2,
    -selectbackground=>'#606060',-highlightthickness =>0, -background=>'#fffeee') -> grid(-column=>1,-row=>2, -sticky=>'nwe');
  $y_var_list = $var_frame -> Listbox (-width=>10, -height=>26, -activestyle=> 'none', -exportselection => 0, -relief=>'groove', -border=>2,
    -selectbackground=>'#606060',-selectmode=>'extended', -highlightthickness =>0, -background=>'#fffeee') -> grid(-column=>2,-row=>2, -sticky=>'nwe');
  $help_box = $plot_window -> Balloon();
  $help_box -> attach($y_var_list, -msg => "Multiple columns for Y can be selected by holding control-key.");
  $var_frame -> Label (-text=>" ") -> grid(-column=>1,-row=>3, -columnspan=>2, -sticky=>'nwe');

  # read the table file
  #status ("Reading table file...");
  my ($colname_ref, $values_ref) = read_table ($plot_table, $table_type);
  #status ();
  our @colname = @$colname_ref;
  our %values = %$values_ref;
  $x_var_list -> insert(0,@colname);
  $y_var_list -> insert(0,@colname);

  my $x_sel = 0;
  my $y_sel = 1;
  $x_var_list -> selectionSet(0,0);
  $y_var_list -> selectionSet(1,1);

  # Filter
  my $filter_frame = $var_frame -> Frame (-background=>$bgcol) -> grid(-column=>1,-row=>4, -columnspan=>2); 
  $filter_frame -> Optionmenu (-options => [@colname],-variable => \@filter_var[0], -border=>0, -background=>$lightblue, -activebackground=>$darkblue) -> grid(-column=>1,-row=>1, -sticky=>'nwe');
  $filter_frame -> Optionmenu (-options => ['=','<','>','!='],-variable => \@filter_type[0], -border=>0, -background=>$lightblue, -activebackground=>$darkblue) -> grid(-column=>2,-row=>1, -sticky=>'nwe');
  @filter_entry[0] = $filter_frame -> Entry (-width=>10, -relief=>'groove', -border=>1) -> grid(-column=>3,-row=>1, -columnspan=>2,-sticky=>'nwes');
  $filter_frame -> Optionmenu (-options => [@colname],-variable => \@filter_var[1], -border=>0, -background=>$lightblue, -activebackground=>$darkblue) -> grid(-column=>1,-row=>2, -sticky=>'nwe');
  $filter_frame -> Optionmenu (-options => ['=','<','>','!='],-variable => \@filter_type[1], -border=>0, -background=>$lightblue, -activebackground=>$darkblue) -> grid(-column=>2,-row=>2, -sticky=>'nwe');
  @filter_entry[1] = $filter_frame -> Entry (-width=>10, -relief=>'groove', -border=>1) -> grid(-column=>3,-row=>2, -columnspan=>2,-sticky=>'nwes');
  
  $filter_frame -> Button ( -text=>"Filter",-border=>0, -background=>$button,-activebackground=>$abutton,-command=>sub{
      @filter_match[0] = @filter_entry[0] -> get();
      @filter_match[1] = @filter_entry[1] -> get();
      refresh_plot();
    }) -> grid(-column=>3,-row=>3, -columnspan=>1, -sticky=>'wens');
  $filter_frame -> Button ( -image=>$delete_gif, -border=>$bbw, -background=>$button,-activebackground=>$abutton,-command=>sub{
      @filter_match[0] = "";
      @filter_entry[0] -> configure(-textvariable=>\@filter_match[0]);
      refresh_plot();
    }) -> grid(-column=>4,-row=>1, -columnspan=>1, -sticky=>'wens');
  $filter_frame -> Button ( -image=>$delete_gif, -border=>$bbw, -background=>$button,-activebackground=>$abutton,-command=>sub{
      @filter_match[1] = "";
      @filter_entry[1] -> configure(-textvariable=>\@filter_match[1]);
      refresh_plot();
  }) -> grid(-column=>4,-row=>2, -columnspan=>1, -sticky=>'wens');

  # add some bindings
  $x_var_list->bind('<Button>', sub{
   refresh_plot();
  });
  $x_var_list->bind('<Down>', sub{
    refresh_plot();
  });
  $x_var_list->bind('<Up>', sub{
    refresh_plot();
  });
  $y_var_list->bind('<Button>', sub{
    refresh_plot();
  });
  $y_var_list->bind('<Down>', sub{
    refresh_plot();
  });
  $y_var_list->bind('<Up>', sub{
    refresh_plot();
  });

  $r_frame -> Label(-text=>"R command to generate this plot:") -> grid(-column=>2, -row=>0, -sticky=>'nw');
  $r_text = $r_frame -> Scrolled("Text", -scrollbars=>"e", -width=>60, -height=>5, -background=>"#fffeee",-exportselection => 0, -relief=>'groove', -border=>2,
    -selectbackground=>'#606060',-highlightthickness =>0) -> grid(-column=>2, -row=>2, -sticky=>'nwes');
  my $r_button_plot = $r_frame -> Button(-image=>$r_in_gif, -width=>26,-height=>26, -border=>$bbw, 
     -background=>$button,-activebackground=>$abutton,-command=> sub {
      my $r_code = $r_text -> get("0.0", "end");
      open (OUT, ">.Rprofile");
      print OUT "library(graphics)\n";
      print OUT "library(utils)\n";
      $r_code =~ s/\'/\"/g;
      print OUT "cat ('".$r_code."\n')\n";
      print OUT $r_code;
      close OUT;
      win_start($r_dir."/bin/rgui.exe");
   })->grid(-row=>2,-column=>3,-sticky=>'nw');
  $help_box -> attach($r_button_plot, -msg => "Send script to Rgui");
  refresh_plot();
}

sub refresh_plot {
### Purpose : Refresh the plot in the dataInspector window
### Compat  : W+L?
  my @add_eq; 
  show_plot ();
  if (@filter_match[0] ne "") {
    if (@filter_type[0] eq "=") {@add_eq[0] = "="} else {@add_eq[0]=""};
    if (@filter_type[1] eq "=") {@add_eq[1] = "="} else {@add_eq[1]=""};
    $r_filter = "dat <- subset (dat, ".@filter_var[0].@filter_type[0].@add_eq[0].@filter_match[0];
    if (@filter_match[1] ne "") {$r_filter .= "&".@filter_var[1].@filter_type[1].@add_eq[1].@filter_match[1]};
    $r_filter .= ")\n";
  } else {$r_filter=""};
  if ($table_type eq "nm") {$read_what = "table"} else {$read_what = "csv"}
  my $r_command = "dat <- read.".$read_what." (file='".unix_path($plot_table)."',"
    ." skip=".$skip_lines.", header=".$cnames.")\n"
    .$r_filter
    ."plot (x=dat\$".@colname[@x_sel[0]].", y=dat\$".@colname[@y_sel[0]].", type='p', pch=19, col='".@plot_colors[0]."',"
    ." xlab='".@colname[@x_sel[0]]."', ylab='".@colname[@y_sel[0]]."', main='".unix_path($plot_table)."' ";
  my $log = "";
  if ($log_x==1) {$log .= "x"};
  if ($log_y==1) {$log .= "y"};
  if (length($log)>0) {
    $r_command .= "log='".$log."')";
  } else {
    $r_command .= ")";
  }
  my $i=0; foreach(@y_sel) {
    unless ($i==0) { # already plotted
      $r_command .= "\n"."points (x=dat\$".@colname[@x_sel[0]].", y=dat\$".@colname[@y_sel[$i]].", pch=".($i+1).", col='".@plot_colors[$i]."')";
    }
    $i++;
  }
  $r_text -> delete('0.0','6.0');
  $r_text -> insert('0.0', $r_command);
}

sub show_plot {
### Purpose : Draw the plot in the dataInspector window
### Compat  : W+L?
  #status("Drawing plot...");
  my @x_sel = $x_var_list -> curselection;
  my @y_sel = $y_var_list -> curselection;
  my $x_var = @colname[@x_sel[0]];
  my $xdat = $values{$x_var};
  @xdata = (); 
  my @xdata_unfiltered = @$xdat; # or get unfiltered data
  my @ydata_unfiltered =(); my @filterdata2_filtered;
  my @dataset;
  my $j=0; my @ydata; my @ydata0; my @ydata1; my @ydata2;
  foreach(@y_sel) {
    unless ($j>2) {
      $y_var = @colname[@y_sel[$j]];
      @ydata = (); @filterdata2_filtered = ();
      my $ydat = $values{$y_var};
      @ydata_unfiltered = @$ydat; 
      my $n = 0; 
      if (@filter_match[0] ne "") {$n++;};
      if (@filter_match[1] ne "") {$n++;};
      unless ($n == 0) {
        my $filterdat1 = $values{@filter_var[0]};  
        my @filterdata = @$filterdat1;
        my $filterdat2 = $values{@filter_var[1]};  
        my @filterdata2 = @$filterdat2;    
        my $reverse = 0; 
        if (@filter_match[1] ne "" && @filter_match[0] eq "") {
          @filter_match[0] = @filter_match[1];
          @filter_type[0] = @filter_type[1];
          @filter_var[0] = @filter_var[1];
          $reverse=1;
        }
        for (my $i=0; $i<$n; $i++) {
          my $r=0;
          my $filterdat = $values{@filter_var[$i]};  
          @filterdata = @$filterdat;
          if ($i>0) {
            @xdata_unfiltered = @xdata; # use already filtered data
            @ydata_unfiltered = @ydata; 
            @filterdata = @filterdata2_filtered;
          } 
        if (@filter_type[$i] eq "=") {
          foreach(@filterdata) {
            if ($_ == @filter_match[$i]) {push(@xdata, @xdata_unfiltered[$r]); push (@ydata, @ydata_unfiltered[$r]); push (@filterdata2_filtered, @filterdata2[$r])};$r++;
          }
        }
        if (@filter_type[$i] eq "<") {
          foreach(@filterdata) {
            if ($_ < @filter_match[$i]) {push(@xdata, @xdata_unfiltered[$r]); push (@ydata, @ydata_unfiltered[$r]);  push (@filterdata2_filtered, @filterdata2[$r])};$r++;
          }
        }
        if (@filter_type[$i] eq ">") {
          foreach(@filterdata) {
            if ($_ > @filter_match[$i]) {push(@xdata, @xdata_unfiltered[$r]); push (@ydata, @ydata_unfiltered[$r]);  push (@filterdata2_filtered, @filterdata2[$r]) };$r++;
          }
        }
        if (@filter_type[$i] eq "!=") {
          foreach(@filterdata) {
            unless ($_ == @filter_match[$i]) {push(@xdata, @xdata_unfiltered[$r]); push (@ydata, @ydata_unfiltered[$r]); push (@filterdata2_filtered, @filterdata2[$r])};$r++;
          }
        }
      }
      if ($reverse==1) {
        @filter_match[0] = "";
        @filter_type[0] = "=";
        @filter_var[0] = @colname[0] ;
      }
    } else {@xdata = @xdata_unfiltered; @ydata = @ydata_unfiltered; $r_filter=""};
    if ($j==0) {@ydata0 = @ydata; };
    if ($j==1) {@ydata1 = @ydata; };
    if ($j==2) {@ydata2 = @ydata; };
  
    push (@dataset, LineGraphDataset -> new
    (
      -name => "set_$j",
      -yData => \@ydata,
      -xData => \@xdata,
      -yAxis => 'Y',
      -color => @plot_colors[$j],
      -lineStyle=> 'none',
      -pointStyle=> @pointstyles[$j],
      -pointSize=>2,
      -fillPoint=>0
     ) );
   }
   $j++;
  }
  
  my @title = ($y_var." vs ".$x_var, 20);
  my $xlab = $x_var;
  my $ylab = $y_var;
  if ($log_x == 1) {$xType = 'log'} else {$xType = 'linear'};
  if ($log_y == 1) {$yType = 'log'} else {$yType = 'linear'};
  @border=(35,25,40,49);
  my $xMin = min (@xdata);
  my $xMax = max (@xdata);  
  my $yMin = min (@ydata);
  my $yMax = max (@ydata); 
    
  if (@xdata == 0) {
    push(@xdata, 0); push(@ydata,0);  
    @title = ("Empty dataset",20);
  }
   my $graph = $plot_frame -> PlotDataset
    (
     -width => 460,
     -height => 460,
     -background => 'white',
     -plotTitle => \@title,
     -autoScaleX=> "On",
     -autoScaleY=> "On",
     -xlabel => $xlab,
     -ylabel => $ylab,
     -y1label => '',
     -xType => $xType,
     -yType => $yType,
     -border => \@border
    ) -> grid(-column=>1, -row=>1);
    $graph -> configure (-fonts =>
     ['Arial 8',   # axes ticks
      'Arial 9 italic', # axes labels
      'Arial 12 bold',  # title
      'Arial 8' # legend
      ]
    );
    foreach(@dataset) {
      $graph -> addDatasets($_);
    }
    if($show_unity==1){
     my @unity_x = (min($xMin,$yMin), max($xMax,$yMax));
     my @unity_y = (min($xMin,$yMin), max($xMax,$yMax)); 
     $unity_line = LineGraphDataset -> new (
       -name => 'Unity line',
       -xData => \@unity_x,
       -yData => \@unity_y,
       -yAxis => 'Y',
       -color => 'red',
       -pointStyle => 'none'
     );
     $graph -> addDatasets($unity_line); 
    }
  $graph -> plot;
  #status ();
}

sub read_table {
### Purpose : Read in a table/csv file and return values by column
### Compat  : W+L/
  my ($data_file, $data_type) = @_;
  my @colname=(); my %values =(); my $cnames; my %values;
  open (DATA, "<".$data_file);
  my @data_lines = <DATA>;
  close DATA;
  if ($data_type eq "tab") {
    if (@data_lines[0] =~ m/TABLE.NO/) {
      $skip_lines=1; $cnames="T";
    } else {
      $skip_lines=0; $cnames="F";
    };
  }
  if ($data_type eq "csv") {
    if ( int(split(/\,/,@data_lines[0])) < int(split(/\,/,@data_lines[1])) ) {$skip_lines=1} else {$skip_lines=0};
  }
  for (my $i=1; $i<=$skip_lines; $i++) {
    shift (@data_lines);
  }
  if ($data_type eq "tab") {  # NONMEM table files
    my $n = 12;
    my $colname_line = @data_lines[0];
    chomp($colname_line);
    if ($cnames eq "T") { # get the column names
      for (my $i=0; ($i*$n)<length($colname_line); $i++) {
        @colname[$i] = substr($colname_line, $i*$n,$n);
        @colname[$i] =~ s/\s//g;
      }
      shift (@data_lines);
    } else {
      for (my $i=0; ($i*$n)<length($colname_line); $i++) {
        @colname[$i] = "V".$i;
      }
    }
    my $row = 0;
    my @line_values;
    foreach my $line (@data_lines) { # get the data
      chomp($line);
      for (my $i=0; ($i*$n)<length($line); $i++) {
        @line_values[$i] = substr($line, $i*$n,$n);
        @line_values[$i] =~ s/\s//g;
      }
      my $ncol=0;
      foreach my $col (@colname) {
        $values{$col}[$row] = sprintf("%.4f",@line_values[$ncol]);
        $ncol++; 
      }
      $row++;
    }  
  }
  if ($data_type eq "csv") {
    my $colname_line = @data_lines[0];
    chomp($colname_line);
    my $characters = join ("", ("a" .. "z"), ("A" .. "Z")); 
    @colname = split(",",$colname_line);
    my $count=0;
    foreach (@colname) {
      my $t = substr($_,0,1);
      if ($characters =~ m/$t/ig ) {$count++}; # test if it is not numerical (and therefore a header)
    }
    if ($count > length(@colname)/2) {$cnames="T"} else {$cnames="F"};
    if ($cnames eq "T") { # get the column names
      shift (@data_lines);
    } else {
      @colname = ();
      my @arr = split(/,/,$colname_line);
      my $j=1; foreach (@arr) {push (@colname, "V".$j); $j++}
    }
    my $row = 0;
    foreach my $line(@data_lines) { # get the data
      chomp($line);
      my @line_values = split(/\,/,$line);
      my $ncol=0;
      foreach my $col (@colname) {
            $values{$col}[$row] = sprintf("%.2f",@line_values[$ncol]) ;
        $ncol++; 
      }
      $row++;
    }  
  }
  return (\@colname, \%values);
}

1;
