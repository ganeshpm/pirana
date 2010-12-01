# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'
use Test;
use strict;

BEGIN { plan tests => 21 };

my $widget;

eval { require Tk; };
ok($@, "", "loading Tk module");

my $mw;
eval {$mw = Tk::MainWindow->new();};
ok($@, "", "can't create MainWindow");

ok(Tk::Exists($mw), 1, "MainWindow creation failed");

#--------------------------------------------------------------
my $class = 'Optionbox';
my $foo = '12';
my @opt = (0..20);
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
    eval { $widget->configure( -variable => \$foo); };
    ok ($@, "", "Error: can't configure  '-variable' for $class widget");
    eval { $widget->configure( -command  => \&test_cb ); };
    ok ($@, "", "Error: can't configure  '-command' for $class widget");
    eval { $widget->configure( -options => \@opt ); };
    ok ($@, "", "Error: can't configure  '-options' for $class widget");

	#------------------------------------------------------------------
	#those tests are snipped from original TK/optmenu.t
	ok($ {$widget->cget(-variable)}, $foo, "setting of -variable failed");
	ok($widget->cget(-variable),\$foo, "Wrong variable");

	my $optmenu = $widget->cget(-menu);
	ok($optmenu ne "", 1, "can't get menu from Optionmenu");
	ok(ref $optmenu, 'Tk::Menu', "reference returned is not a Tk::Menu");
	ok($optmenu->index("last"), 21, "wrong number of elements in menu");
	ok($optmenu->entrycget("last", -label), "20", "wrong label");
	
	# here we might need some more tests
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
	print "test_cb called with [@_], \$dummyvar = >$foo<\n";
}

1;
