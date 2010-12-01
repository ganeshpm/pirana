# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'
use Test;
use strict;

BEGIN { plan tests => 16 };

my $widget;

eval { require Tk; };
ok($@, "", "loading Tk module");

my $mw;
eval {$mw = Tk::MainWindow->new();};
ok($@, "", "can't create MainWindow");

ok(Tk::Exists($mw), 1, "MainWindow creation failed");

#--------------------------------------------------------------
my $class = 'Checkbox';
my $dummyvar = '0';
#--------------------------------------------------------------
print "Testing $class\n";

eval "require Tk::$class;";
ok($@, "", "Error loading Tk::$class");

eval { $widget = $mw->$class(); };
ok($@, "", "can't create $class widget");
skip($@, Tk::Exists($widget), 1, "$class instance does not exist");

if (Tk::Exists($widget)) {
    eval { $widget->pack; };

    ok ($@, "", "Can't pack a $class widget");
    eval { $mw->update; };
    ok ($@, "", "Error during 'update' for $class widget");
	#------------------------------------------------------------------
    eval { $widget->configure( -variable => \$dummyvar); };
    ok ($@, "", "Error: can't configure  '-variable' for $class widget");
    eval { $widget->configure( -command  => \&test_cb ); };
    ok ($@, "", "Error: can't configure  '-command' for $class widget");
    eval { $widget->configure( -onvalue  => 'Up' ); };
    ok ($@, "", "Error: can't configure  '-onvalue' for $class widget");
    eval { $widget->configure( -offvalue => 'Down' ); };
    ok ($@, "", "Error: can't configure  '-offvalue' for $class widget");
	
	# here we need some more tests
	#...
	
	#------------------------------------------------------------------

    eval { my @dummy = $widget->configure; };
    ok ($@, "", "Error: configure list for $class");
    eval { $mw->update; };
    ok ($@, "", "Error: 'update' after configure for $class widget");

    eval { $widget->destroy; };
    ok($@, "", "can't destroy $class widget");
    ok(!Tk::Exists($widget), 1, "$class: widget not really destroyed");
} else  { 
    for (1..5) { skip (1,1,1, "skipped because widget couldn't be created"); }
}
sub test_cb
{
	print "test_cb called with [@_], \$dummyvar = >$dummyvar<\n";
}

1;
