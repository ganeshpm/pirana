# Load the Module::Install bundled in ./inc/
use inc::Module::Install;

# Define metadata
name            'Tk-PlotDataset';
all_from        'lib/Tk/PlotDataset.pm';
abstract        'An extended version of the canvas widget for plotting 2D ' .
                'line graphs. Plots have a legend and zooming capabilities.';

# Specific dependencies
requires        'Carp';
requires        'POSIX';
requires        'Tk::Canvas';
requires        'Tk::Balloon';
build_requires  'Test::More';
build_requires  'Test::Pod'            => '1.22';
build_requires  'Test::Pod::Coverage'  => '1.08';
build_requires  'Pod::Coverage'        => '0.18';
recommends      'Tk::LineGraphDataset';

auto_install;
WriteAll;