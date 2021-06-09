package Writers;

use strict;
use warnings;

use Data::Dumper;

use POSIX;
use Exporter;

require Utils;  # Must use require, to get INC updated
import Utils qw( &get_progname &get_progpath );

use constant DBG => 1;   ## Also, comment out unused 'uses'
use constant CHK => 1;

use constant F_ERR_MSG =>
    "Please check file name, existence, permissions, etc.\n";
use constant HLPMAP => 1;
use constant CCAT_CH => '_';


BEGIN {
    @Writers::ISA = ('Exporter');
    @Writers::EXPORT_OK =
        qw( &write_xp &write_digest &write_digest_int &write_cnf );
}


# Write explanation
sub write_xp()
{
    my ($opts, $mxp, $xp, $xtype) = @_;

    if ($opts->{l}) {
        print "$xtype: ";
        for(my $i=0; $i<=$#{$xp}; $i++) {
            my $idx = $i+1;
            my $val = ${$mxp->{vect}}[$i];
            print "($idx=$val) ";
        }
        print "\n";
    } elsif ($opts->{w}) {
        print "$xtype: @{$xp}\n";
    }
}

# Write summary of tool's execution
sub write_digest()
{
    my ($opts, $mxp, $stats) = @_;
    print "Summary of running $0\n";
    #
    my ($nxp, $nlits, $avg) = (0, 0, 0.0);
    if ($stats->{AXp}->{Num} != 0 && $stats->{CXp}->{Num} != 0) {
        $nxp = $stats->{AXp}->{Num} + $stats->{CXp}->{Num};
        $nlits = $stats->{AXp}->{Lits} + $stats->{CXp}->{Lits};
        my $avg = sprintf("%3.2f", $nlits / $nxp);
        print "Total number of explanations: $nxp\n";
        print "Average explanation size:     $avg\n";
    }
    #
    if ($stats->{AXp}->{Num} != 0) {
        $nxp = $stats->{AXp}->{Num};
        $nlits = $stats->{AXp}->{Lits};
        $avg = sprintf("%3.2f", $nlits / $nxp);
        print "Total number of AXp's:        $nxp\n";
        print "Average AXp size:             $avg\n";
    }
    #
    if ($stats->{CXp}->{Num} != 0) {
        $nxp = $stats->{CXp}->{Num};
        $nlits = $stats->{CXp}->{Lits};
        $avg = sprintf("%3.2f", $nlits / $nxp);
        print "Total number of CXp's:        $nxp\n";
        print "Average CXp size:             $avg\n";
    }
    #
    my $ptime = 0;
    if (!defined($stats->{NSAT})) { $stats->{NSAT} = 0; }
    print "Number of SAT oracle calls:   $stats->{NSAT}\n";
    if (!defined($stats->{SATTIME})) { $stats->{SATTIME} = 0; }
    $ptime = sprintf("%7.6f", $stats->{SATTIME});
    print "Total time in SAT oracle:     $ptime\n";
    if (!defined($stats->{NSIM})) { $stats->{NSIM} = 0; }
    print "Number of classifier calls:   $stats->{NSIM}\n";
    if (!defined($stats->{SIMTIME})) { $stats->{SIMTIME} = 0; }
    $ptime = sprintf("%7.6f", $stats->{SIMTIME});
    print "Total time in classifier:     $ptime\n";
    if (!defined($stats->{MFIXES})) { $stats->{MFIXES} = 0; }
    if ($opts->{t} eq 'CMT') {
        print "Number of prediction fixes:   $stats->{MFIXES}\n";
    }
}

# Write summary of tool's execution (given interrupt)
sub write_digest_int()
{
    my $args = shift @_;

    my ($opts, $mxp, $stats) = @{$args};
    &write_digest($opts, $mxp, $stats);
}

sub write_cnf()
{
    my ($opts, $fname, $cnf) = @_;

    open(my $fh, ">$fname") || die "Unable to open output CNF file: $fname.\n";
    if ($cnf->{NC} > 0) {
        print $fh ("p cnf $cnf->{NV} $cnf->{NC}\n");
        if (DBG && $opts->{d}) { print ("p cnf $cnf->{NV} $cnf->{NC}\n"); }
        foreach my $cl (@{$cnf->{Cls}}) {
            print $fh "@{$cl} 0\n";
            if (DBG && $opts->{d}) { print "@{$cl} 0\n"; }
        }
    }
    else {
        print $fh ("p cnf $cnf->{NV} $cnf->{NV}\n");
        if (DBG && $opts->{d}) { print ("p cnf $cnf->{NV} $cnf->{NV}\n"); }
        for(my $i=1; $i<=$cnf->{NV}; ++$i){
            print $fh "-$i 0\n";
            if (DBG && $opts->{d}) { print "-$i 0\n"; }
        }
    }
    close($fh);
}


END {
}

1;  # to ensure that the 'require' or 'use' succeeds
