use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	=> 'Tk::MK',
	'VERSION' => '0.17',
    'DISTNAME' => 'Tk-MK',
    'PREREQ_PM' => { 'Tk' => '804.027', },
    'dist' => { COMPRESS => 'gzip -9f', SUFFIX => 'gz' },
    'AUTHOR'	=> 'M. Krause',
    'ABSTRACT'	=> "Several Add-on widgets (Buttonplus, HListplus, DHList, DTree, Checkbox, Optionbox, PopUpSelectBox, Statusbox, BootSplash, ProgressBarPlus & HdrResizeButton)",
);
