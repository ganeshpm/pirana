#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'Tk::PlotDataset' );
}

diag( "Testing Tk::PlotDataset $Tk::PlotDataset::VERSION, Perl $], $^X" );
