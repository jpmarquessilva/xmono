package Parsers;

use strict;
use warnings;

use Data::Dumper;

use POSIX qw( !assert );
use Exporter;

##use Math::Round qw ( round );

require Utils;  # Must use require, to get INC updated
import Utils qw( &get_progname &get_progpath &assert );

use constant DBG => 1;   ## Also, comment out unused 'uses'
use constant CHK => 1;

use constant F_ERR_MSG =>
    "Please check file name, existence, permissions, etc.\n";
use constant HLPMAP => 1;
use constant CCAT_CH => '_';


BEGIN {
    @Parsers::ISA = ('Exporter');
    @Parsers::EXPORT_OK =
        qw( &parse_spec &parse_instance 
            &parse_cmt_outp &parse_mbt_outp &parse_solver_outp );
}


# Parse Spec format
sub parse_spec()
{
    my ($opts, $mxp, $fname) = @_;
    if (DBG && $opts->{d}) { print "Parsing desc file $fname...\n"; }

    open(my $fh, "<$fname") || die "Unable to open file $fname. " . F_ERR_MSG;
    my ($fn, $cn, $rmode) = (1, 1, 0);
    while(<$fh>) {
        s/\r[\n]*/\n/gm;
        chomp;
        next if m/^\s*c\s+$/;
        if ($rmode == 0) {        # Read number of features
            m/^(\d+)$/ || die "Unable to match $_ in mode=$rmode\n";
            $mxp->{NF} = $1;
            $rmode = 1;
        }
        elsif ($rmode == 1) {     # Read the features' names, LBs and UBs
            m/^(\S+)\s+(\d+\.?\d*)\s+(\d+\.?\d*)$/ ||
                die "Unable to match $_ in mode=$rmode\n";
            $mxp->{Feats}->{$fn} = $1;
            $mxp->{LBs}->{$fn} = $2;
            $mxp->{UBs}->{$fn} = $3;
            if ($fn++ == $mxp->{NF}) { $rmode = 2; }
        }
        elsif ($rmode == 2) {     # Read number of classes
            m/^(\d+)$/ || die "Unable to match $_ in mode=$rmode\n";
            $mxp->{NC} = $1;
            $rmode = 3;
        }
        elsif ($rmode == 3) {     # Read classes' names
            m/^(\S+)$/ || die "Unable to match $_ in mode=$rmode\n";
            $mxp->{Cls}->{$cn} = $1;
            if ($cn++ == $mxp->{NC}) { $rmode = 4; }
        }
        else { die "Invalid state $rmode with input: $_\n"; }
    }
    close($fh);
}

# Parse instance format
sub parse_instance()
{
    my ($opts, $inst, $fname) = @_;
    if (DBG && $opts->{d}) { print "Parsing inst file $fname...\n"; }

    open(my $fh, "<$fname") || die "Unable to open file $fname. " . F_ERR_MSG;
    my ($fn, $rmode) = (1, 0);
    while(<$fh>) {
        s/\r[\n]*/\n/gm;
        next if m/^\s*$/ || m/^c\s+/;
        chomp;
        if (DBG && $opts->{d}) { print "Line: |$_|\n"; }
        if ($rmode == 0) {
            m/^(\d+)$/ || die "Unable to match $_ in mode=$rmode\n";
            $inst->{NF} = $1;
            $rmode = 1;
        }
        elsif ($rmode == 1) {
            m/^(\d+\.?\d*)$/ || die "Unable to match $_ in mode=$rmode\n";
            $inst->{Vs}->{$fn} = $1;
            if ($fn++ == $inst->{NF}) { $rmode = 2; }
        }
        elsif ($rmode == 2) {
            m/^(\S+)$/ || die "Unable to match $_ in mode=$rmode\n";
            $inst->{Cl} = $1;
            $rmode = 3;
        }
        else { die "Invalid state $rmode with input: $_\n"; }
    }
    close($fh);
}

sub parse_cmt_outp()
{
    my ($opts, $fname) = @_;

    open(my $fh, "<$fname") || die "Unable to open file $fname. " . F_ERR_MSG;
    my ($prediction, $rmode) = ('', 0);
    while(<$fh>) {
        s/\r[\n]*/\n/gm;
        chomp;
        if ($rmode == 0) {
            # Obs: assuming reals for the classification values
            if (m/Monotone upper envelope prediction:\s+(\d+\.?\d*)/) {
                $prediction = round($1);
                last;
            }
        }
        else { die "Invalid state $rmode with input: $_\n"; }
    }
    return $prediction;
}

sub parse_mbt_outp()
{
    my ($opts, $fname) = @_;

    open(my $fh, "<$fname") || die "Unable to open file $fname. " . F_ERR_MSG;
    my ($prediction, $rmode) = ('', 0);
    while(<$fh>) {
        s/\r[\n]*/\n/gm;
        chomp;
        if ($rmode == 0) {
            if (m/(\S+)/) {
                $prediction = "$1";
                last;
            }
        }
        else { die "Invalid state $rmode with input: $_\n"; }
    }
    return $prediction;
}


sub parse_solver_outp()
{
    my ($opts, $fname) = @_;

    open(my $fh, "<$fname") || die "Unable to open file $fname. " . F_ERR_MSG;
    my ($outc, $model, $rmode) = (0, [], 0);
    while(<$fh>) {
        s/\r[\n]*/\n/gm;
        chomp;
        if ($rmode == 0) {
            if (m/^s\s+UNSATISFIABLE\s*$/) {
                last;
            }
            elsif (m/^s\s+SATISFIABLE\s*$/) {
                ($outc, $rmode) = (1, 1);
            }
        }
        elsif ($rmode == 1) {
            if (m/^v\s+(.+)\s+0$/) {
                my @raw_model = split(/ +/, $1);
                @{$model} = sort { abs($a) <=> abs($b) } @raw_model;
                $rmode = 2;
            }
        }
        else { die "Invalid state $rmode with input: $_\n"; }
    }
    close($fh);
    return ($outc, $model);
}

sub round()
{
    my ($val) = @_;
    my $rval = sprintf("%.0f", $val);
    return $rval;
}


END {
}

1;  # to ensure that the 'require' or 'use' succeeds
