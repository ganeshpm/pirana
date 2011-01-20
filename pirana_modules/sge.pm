# Subroutines for connecting with an SGE cluster

package pirana_modules::sge;

use strict;
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(stop_job qstat_get_nodes_info qstat_process_nodes_info qstat_get_jobs_info qstat_process_jobs_info qstat_get_specific_job_info);

sub stop_job {
    my $job_n = shift;
    open (OUT, "qdel ".$job_n." |");
    my @all;
    while (my $line = <OUT>) {
	push (@all, $line);
    }
    return (\@all)
}

sub qstat_get_nodes_info {
    my $command = shift;
    my @all; my @txt;
    open (OUT, $command);
    while (my $line = <OUT>) {
        push (@txt, $line);
    }
    my $txt = join ("", @txt);
    my $all_ref = qstat_process_nodes_info ($txt);

    return ($all_ref);
}

sub qstat_process_nodes_info {
    my $txt = shift;
    my @txt = split ("\n", $txt);
    my @all;
    foreach my $line (@txt) {
        if (!(($line =~ m/HOSTNAME/)||($line =~ m/----/)||($line =~ m/CLUSTER/)||($line =~ m/global/)||($line =~ m/job-ID/i))) {
	    chomp ($line);
	    my @arr = split (" ", $line);
	    my $i=0; foreach(@arr) {
		if ($_ eq "") {delete (@arr[$i])};
		$i++;
	    }
	    push (@all, \@arr);
	}
    }
    return (\@all);
}

sub qstat_get_jobs_info {
    my $command = shift;
    my @all; my @txt;
    open (OUT, $command);
    while (my $line = <OUT>) {
        push (@txt, $line);
    }
    my $txt = join ("", @txt);
    my $all_ref = qstat_process_jobs_info ($txt);
    return($all_ref);
}

sub qstat_process_jobs_info {
    my $txt = shift;
    my @txt = split ("\n", $txt);
    my @all;
    my %comb;
    foreach my $line (@all) {
	unless (($line =~ m/job-ID/i)||($line =~ m/----/)) {
	    print $line;
	    chomp($line);
	    my @arr = split (" ", $line);
	    my $i=0; foreach(@arr) {
		if ($_ eq "") {delete (@arr[$i])};
		$i++;
	    }
	    $comb{@arr[0]} = \@arr;
	}
    }
    my @k = sort {$a <=> $b } keys (%comb);
    foreach (@k) {
	unshift (@all, $comb{$_});
    }
    return (\@all)
}

sub qstat_get_specific_job_info {
    my $n = shift;
    open (OUT, "qstat -j ".$n." |");
    my @all;
    while (my $line = <OUT>) {
	chomp ($line);
	push (@all, $line);
    }
    return (\@all)
}


1;
