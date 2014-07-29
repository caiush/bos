#!/usr/bin/perl
use strict;

# subroutine to verify that the named table in param 1 has a default
# route.
# param 2 can optionally specify verbose output
# Returns 1 if network has default route present, else return 0
sub checkroute {

    my $network = shift(@_);
    my $verbose = shift(@_);
    print "checking $network network\n" if "$verbose";
    my $command = "ip route show table $network | grep -i default";
    my $result = system("$command >/dev/null 2>&1");
    if ($result) {
        print "No default route in table $network\n" if "$verbose";
        return 0;
    } else {
        print "$network passes (has default route)\n" if "$verbose";
        return 1;
    }
}

# check current status of routes for comparison later
my $mgmt    = checkroute ("mgmt", 1);
my $storage = checkroute ("storage", 1);

print "Monitoring default routes status  ...\n";

# monitor all IP events and after each one check to see whether the
# default route appeared or disappeared
open (IPEVENTS, "ip monitor all |") or die "Failed $!\n";
while (<IPEVENTS> )
{
    my $LINE = $_;

    my $currentmgmt = checkroute("mgmt",0);
    if ($currentmgmt != $mgmt) {
	if ($currentmgmt) {
	    print "Info: Default route established on mgmt network after \n $LINE\n";
	} else {
	    print "WARN: Default route disappeared on mgmt network after \n $LINE\n";
	}
    }
    $mgmt = $currentmgmt;

    my $currentstorage = checkroute("storage",0);

    if ($currentstorage != $storage) {
	if ($currentstorage) {
	    print "Info: Default route established on storage network after \n $LINE\n";
	} else {
	    print "WARN: Default route disappeared on storage network after \n $LINE\n";
	}
    }
    $storage = $currentstorage;
}
close IPEVENTS



