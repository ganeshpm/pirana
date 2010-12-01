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
my $class = 'HListplus';
my $foo = 'i01';
my $bar = 'DummyProject';
my $result;
#--------------------------------------------------------------
print "Testing $class\n";

eval "require Tk::$class;";
ok($@, "", "Error loading Tk::$class");

eval { $widget = $mw->$class(-columns => 3, -header => 1); };
ok($@, "", "can't create $class widget");
skip($@, Tk::Exists($widget), 1, "$class instance does not exist");

if (Tk::Exists($widget)) {
    eval { $widget->pack; };

    ok ($@, "", "Can't pack a $class widget");
    eval { $mw->update; };
    ok ($@, "", "Error during 'update' for $class widget");
	#------------------------------------------------------------------
	my $headerstyle = $mw->ItemStyle ('window', -padx => 0, -pady => 0);
    eval { $widget->header('create', 0, 
          -itemtype => 'resizebutton',
          -style => $headerstyle,
          -text => 'Test Name1', );
	};
    ok ($@, "", "Error: can't set header  '-itemtype => resizebutton' for $class widget");
    eval { $widget->header('create', 1, 
          -itemtype => 'resizebutton',
          -style => $headerstyle,
          -text => 'Test Name2', 
		  -activeforeground => 'blue',);
	};
    ok ($@, "", "Error: can't set header  '-activeforeground' for $class widget");
	#
    eval { $widget->header('create', 1, 
          -itemtype => 'resizebutton',
          -style => $headerstyle,
          -text => 'Test Name2', 
		  -activebackground => 'orange',);
	};
    ok ($@, "", "Error: can't set header  '-activebackground' for $class widget");
	#
    eval { $widget->header('create', 1, 
          -itemtype => 'resizebutton',
          -style => $headerstyle,
          -text => 'Test Name2', 
		  -command => \&test_cb);
	};
    ok ($@, "", "Error: can't set header  '-activebackground' for $class widget");
	#
	
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
	print "test_cb called with [@_], \$foo = >$foo<\n";
}

1;
