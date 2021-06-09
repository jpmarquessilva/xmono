package Solver;

use strict;
use warnings;

use Data::Dumper;

use POSIX qw( !assert );
use Exporter;

require Utils;  # Must use require, to get INC updated
import Utils qw( &assert &mark_curr_time &read_elapsed_time );

require Parsers;
import Parsers qw( parse_solver_outp );

use constant DBG => 1;   ## Also, comment out unused 'uses'
use constant CHK => 1;

use constant F_ERR_MSG =>
    "Please check file name, existence, permissions, etc.\n";
use constant HLPMAP => 1;
use constant CCAT_CH => '_';


BEGIN {
    @Solver::ISA = ('Exporter');
    @Solver::EXPORT_OK =
        qw( &run_sat_solver );
}


my $solver = './tools/glucose-syrup-4.1/simp/glucose';
#my $solver = './bin/minisat';
my $fout = './scripts/outp/sat_output';


# For enumerating AXp's/CXp's, we use a SAT solver. For now, the calls
# to the SAT solver are file-based.

sub run_sat_solver()
{
    my ($opts, $stats, $cnf, $fcnf) = @_;

    my $rtime = &mark_curr_time();
    system("$solver -model $fcnf > $fout");
    my $elapsed = &read_elapsed_time($rtime);
    if ($opts->{s}) { $stats->{SATTIME} += $elapsed; }
    my ($outc, $model) = &parse_solver_outp($opts, $fout);
    if ($#{$model}+1 < $cnf->{NV}) {
        for(my $i=$#{$model}+1; $i<$cnf->{NV}; $i++) {
            push @{$model}, -($i+1);  # pad with 0s
        }
    }
    if (DBG && $opts->{d}) { print "(outc,model)=($outc,[@{$model}])\n"; }
    return ($outc, $model);
}


END {
}

1;  # to ensure that the 'require' or 'use' succeeds
