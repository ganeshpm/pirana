use Tk;
use Tk::Widget;
use Tk::FontDialog;

my $mw = new MainWindow;
my $font = $mw -> FontDialog(-nicefont => 1, -font=> "Helvetica 10" ) -> Show;
print $mw -> GetDescriptiveFontName($font)."\n";

MainLoop();
