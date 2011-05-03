# Subroutines for connecting with an SGE cluster

package pirana_modules::sge;

use strict;
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(ssh_get_pre_post sge_get_job_cwd stop_job qstat_get_nodes_info qstat_process_nodes_info qstat_get_jobs_info qstat_process_jobs_info qstat_get_specific_job_info);

sub ssh_get_pre_post {
    my $ssh_ref = shift;
    my %ssh = %$ssh_ref;
    my $ssh_pre; my $ssh_post;
    unless ($ssh{login} =~ m/(plink|putty)/i) {
	    $ssh_post = "'";
    }
    if ($ssh{connect_ssh} == 1) {
	$ssh_pre .= $ssh{login}.' ';	
	if ($ssh{parameters} ne "") {
	    $ssh_pre .= $ssh{parameters}.' ';
	}
	unless ($ssh{login} =~ m/(plink|putty)/i) {
	    $ssh_pre .= "'";
	}
	if ($ssh{execute_before} ne "") {
	    $ssh_pre .= $ssh{execute_before}.'; ';
	}
    }
    return ($ssh_pre, $ssh_post);
}

sub sge_get_job_cwd {
    my ($job, $ssh_ref) = @_;
    my $info_ref = qstat_get_specific_job_info ($job, $ssh_ref);
    my @info = @$info_ref;
    my $folder;
    foreach my $line (@info) {
	if (substr($line, 0, 3) eq "cwd") {
	    $folder = $line;
	    $folder =~ s/cwd://i;
	    $folder =~ s/^\s+//; #remove leading spaces
	}
    }
    return ($folder);
}

sub stop_job {
    my ($job_n, $ssh_ref) = @_;
    my ($ssh_pre, $ssh_post) = ssh_get_pre_post ($ssh_ref); 
    open (OUT, $ssh_pre."qdel ".$job_n." |".$ssh_post);
    my @all;
    while (my $line = <OUT>) {
	push (@all, $line);
    }
    return (\@all)
}

sub qstat_get_nodes_info {
    my ($command, $ssh_ref) = @_;
    my ($ssh_pre, $ssh_post) = ssh_get_pre_post ($ssh_ref); 
    my @all; my @txt;
    open (OUT, $ssh_pre.$command.$ssh_post);
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
	    @arr[5] .= " ". splice (@arr,6,1); # date/time has a space in the middle
	    push (@all, \@arr);
	}
    }
    return (\@all);
}

sub qstat_get_jobs_info {
    my ($command, $ssh_ref) = @_;
    my ($ssh_pre, $ssh_post) = ssh_get_pre_post ($ssh_ref); 
    my @all; my @txt;
    $command = $ssh_pre.$command.$ssh_post;
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
    my ($n, $ssh_ref) = @_;
    my ($ssh_pre, $ssh_post) = ssh_get_pre_post ($ssh_ref); 
    print $ssh_pre. $ssh_post;
    open (OUT, $ssh_pre."qstat -j ".$n." |".$ssh_post);
    my @all;
    while (my $line = <OUT>) {
	chomp ($line);
	push (@all, $line);
    }
    return (\@all)
}


1;
