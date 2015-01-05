#!/usr/bin/perl
use strict;
use warnings;

sub getLoggingTime {

    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time);
    my $nice_timestamp = sprintf ( "[%04d/%02d/%02d %02d:%02d:%02d] ",
                                   $year+1900,$mon+1,$mday,$hour,$min,$sec);
    return $nice_timestamp;
}

# timestamped print
sub myprint {
    my $timestamp = getLoggingTime();
    print "$timestamp " . "@_";
}

# subroutine to verify that the named table in param 1 has a default
# route.
# param 2 can optionally specify verbose output
# Returns 1 if network has default route present, else return 0
sub checkroute {

    my $network = shift(@_);
    my $verbose = shift(@_);
    myprint "checking $network network\n" if "$verbose";
    my $command = "ip route show table $network | grep -i default";
    my $result = system("$command >/dev/null 2>&1");
    if ($result) {
        myprint "WARN: No default route in table $network\n" if "$verbose";
        return 0;
    } else {
        myprint "Info: $network passes (has default route)\n" if "$verbose";
        return 1;
    }
}

# check current status of routes for comparison later
my $mgmt    = checkroute ("mgmt", 1);
my $storage = checkroute ("storage", 1);

myprint "Monitoring default routes status  ...\n";

my @scrollback;

# monitor all IP events and after each one check to see whether the
# default route appeared or disappeared
open (IPEVENTS, "ip monitor all |") or die "Failed $!\n";
while (<IPEVENTS> )
{
    my $LINE = $_;

    push @scrollback, $LINE;

    my $currentmgmt = checkroute("mgmt",0);
    if ($currentmgmt != $mgmt) {
        if ($currentmgmt) {
            myprint "Info: Default route established on mgmt network after \n $LINE\n";
        } else {
            myprint "WARN: Default route disappeared on mgmt network after \n $LINE\n";
        }
    }
    $mgmt = $currentmgmt;

    my $currentstorage = checkroute("storage",0);

    if ($currentstorage != $storage) {
        if ($currentstorage) {
            myprint "Info: Default route established on storage network after \n $LINE\n";
        } else {
            myprint "WARN: Default route disappeared on storage network after \n $LINE\n";
        }
    }
    $storage = $currentstorage;

    if ($#scrollback >= 10) {
        shift @scrollback;          
    }

    myprint "\n-----------------------------------------------------\n";

    foreach (@scrollback) {
        myprint "$_";
    }

    myprint "\n-----------------------------------------------------\n";

}
close IPEVENTS



