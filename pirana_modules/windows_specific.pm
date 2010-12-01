use Win32::PerfLib;
use Win32::Process;

sub nonmem_priority {
  my $priority = shift;
  my %process_by_name = &get_processes;
  my @proc = keys(%process_by_name);
  my $count_succ = 0; my $count_nm = 0;
  foreach my $key (@proc) {
	if ($key eq "nonmem") {
	    my $info_ref =$process_by_name{$key};
	    my @info = @$info_ref;
	    foreach my $pid (@info) {
		$count_nm = $count_nm + 1;
		my $iflags = 0;
		Win32::Process::Open (my $nm_proc, $pid , $iflags);
		my $pr;
		if ($priority eq "low") {
		    $pr = $nm_proc -> SetPriorityClass( IDLE_PRIORITY_CLASS );
		}
		if ($priority eq "normal") {
		    $pr = $nm_proc -> SetPriorityClass( NORMAL_PRIORITY_CLASS );
		}
		if ($priority eq "high") {
		    $pr = $nm_proc -> SetPriorityClass( HIGH_PRIORITY_CLASS );
		}
	        $count_succ = $count_succ + $pr;
	    }
	}
    }
    return ($count_succ." of ".$count_nm." NONMEM processes were set to ".$priority." priority.")
}

# Get all process IDs by name.
sub get_processes
{
    my (%counter, %r_counter, %process_by_name);
    Win32::PerfLib::GetCounterNames('', \%counter);
    %r_counter = reverse %counter;

    # Get id for the process object
    my $process_obj = $r_counter{'Process'};
    # Get id for the process ID counter
    my $process_id = $r_counter{'ID Process'};

    # create connection to local computer
    my $perflib = new Win32::PerfLib('');
    my $proc_ref = {};

    # get the performance data for the process object
    $perflib->GetObjectList($process_obj, $proc_ref);
    $perflib->Close();

    my $instance_ref = $proc_ref->{'Objects'}->{$process_obj}->{'Instances'};
    foreach my $instance (values %{$instance_ref})
    {
        my $counter_ref = $instance->{'Counters'};
        foreach my $counter (values %{$counter_ref})
        {
            if($counter->{'CounterNameTitleIndex'} == $process_id)
            {
                # Process ID:s stored by name, in anonymous array:
                push @{$process_by_name{$instance->{'Name'}}}, $counter->{'Counter'};
            }
        }
    }
    return %process_by_name;
}

1;
