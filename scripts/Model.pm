package Model;

use strict;
use warnings;

use Data::Dumper;

use POSIX qw( !assert );
use Exporter;

require Utils;  # Must use require, to get INC updated
import Utils  qw( &assert &mark_curr_time &read_elapsed_time );

require Parsers;
import Parsers qw( parse_cmt_outp parse_mbt_outp );

require HardCoded;
import HardCoded qw( &rdt_classifier &grd_classifier );

use constant DBG => 1;   ## Also, comment out unused 'uses'
use constant CHK => 1;

use constant F_ERR_MSG =>
    "Please check file name, existence, permissions, etc.\n";
use constant HLPMAP => 1;
use constant CCAT_CH => '_';
use constant CCHK => 0;


BEGIN {
    @Model::ISA = ('Exporter');
    @Model::EXPORT_OK = qw( &run_classifier );
}


my $fout = './scripts/outp/clsf_output';


sub run_classifier()
{
    my ($opts, $stats, $mxp, $vect) = @_;
    my $class = -1;
    my $rtime = &mark_curr_time();
    if ($opts->{t} eq 'GRD' ||
        DBG && CHK && defined($opts->{k}) && $opts->{k}>5) {
        #$class = &grd_classifier($opts, $stats, $mxp, $vect);
        $class = &grd_classifier($vect);
    }
    elsif ($opts->{t} eq 'RDT') {
        #$class = &rdt_classifier($opts, $stats, $mxp, $vect);
        $class = &rdt_classifier($vect);
    }
    elsif ($opts->{t} eq 'CMT') {
        $class = &cmt_classifier($opts, $stats, $mxp, $vect);
    }
    elsif ($opts->{t} eq 'MBT') {
        $class = &mbt_classifier($opts, $stats, $mxp, $vect);
    }
    my $elapsed = &read_elapsed_time($rtime);
    if ($opts->{s}) { $stats->{SIMTIME} += $elapsed; }
    if (defined($opts->{v}) && $opts->{v} >= 5) {
        print "Classif([@{$vect}])=$class";
        if ($opts->{v} >= 8) { print "  => time: $elapsed\n"; }
        else                 { print "\n"; }
    }
    if (DBG && $opts->{d}) { print "Class: $class\n"; }
    return "$class";
}

use constant INLINE => 0;

# Monoboost classifier
sub mbt_classifier()
{
    my ($opts, $stats, $mxp, $vect) = @_;
    my $classifier = '/usr/local/opt/python@3.9/bin/python3.9 ./tools/monoboost/mbrun.py';
    my $mbm = "$opts->{c}";
    my $inst = join(',', @{$vect});
    my $class = '';
    if (INLINE) {
        $class = &run_mbt_classifier($mbm, $inst);
    } else {
        my $cmd = "$classifier -m $mbm $inst > $fout";
        ##print "CMD: $cmd\n";
        if (DBG && $opts->{d}) { print "Running classifier w/ cmd: $cmd\n"; }
        system("$cmd");
        $class = &parse_mbt_outp($opts, $fout);
    }
    ##print "CLASS: $class\n";
    return "$class";
}

# COMET classifier
sub cmt_classifier()
{
    my ($opts, $stats, $mxp, $vect) = @_;
    my $classifier = './scripts/monosim.py';
    my $class = -1;
    my $cfg = $opts->{c};
    my $inst = join(',', @{$vect});
    my $cmd = "$classifier -i $inst -c $cfg > $fout";
    if (DBG && $opts->{d}) { print "Running classifier w/ cmd: $cmd\n"; }
    system("$cmd");
    my $prediction = &parse_cmt_outp($opts, $fout);
    my @Cls = sort {$a <=> $b} values %{$mxp->{Cls}};
    for(my $i=0; $i<=$#Cls; ++$i) {
        if ($Cls[$i]<=$prediction && ($i==$#Cls || $Cls[$i+1]>$prediction)) {
            $class = $Cls[$i]; last;
        }
    }
    if ($opts->{m}) {
        $class = &enforce_monotonicity($opts, $stats, $mxp, $vect, $class);
    }
    return $class;
}

sub enforce_monotonicity()
{
    my ($opts, $stats, $mxp, $vect, $class) = @_;
    if (!defined($mxp->{Preds})) { $mxp->{Preds} = []; }
    my $predictions = $mxp->{Preds};
    
    my ($rcl, $rvect, $hasv, $skip) = ($class, [], 0, 0);
    for(my $i=0; $i<=$#{$predictions}; ++$i) {
        my ($pvect, $pcl) = @{${$predictions}[$i]};
        if (DBG && $opts->{d}) { print "CHECKING VS: @{$pvect} and $pcl\n"; }
        if (&equals_to($pvect, $vect) && $pcl == $class) { $skip = 1; last; }
        if (&greater_than($pvect, $vect) && $pcl < $class) {
            if(!$hasv || &greater_than($rvect, $pvect) && $pcl <= $rcl) {
                ($rvect, $rcl, $hasv) = ($pvect, $pcl, 1);
            }
        }
        elsif (&greater_than($vect, $pvect) && $class < $pcl) {
            if(!$hasv || &greater_than($pvect, $rvect) && $rcl <= $pcl) {
                ($rvect, $rcl, $hasv) = ($pvect, $pcl, 1);
            }
        }
    }
    if (!$skip) {  # Skip if same instance exists in predictions...
        my @nvect = @{$vect};
        push @{$predictions}, [ \@nvect, $rcl ];
        if ($opts->{s} && $rcl != $class) { $stats->{MFIXES}++; }
        if ($opts->{v} >= 8 && $rcl != $class) {
            print "WARN: Corrected Classif[@{$vect}], from $class to $rcl, due to [@{$rvect}]\n";
        }
    }
    if (DBG && $opts->{d}) {
        print Data::Dumper->Dump([ $predictions ], [ qw(preds) ]); }
    return $rcl;
}

sub greater_than()
{
    my ($rv1, $rv2) = @_;
    my $gt = 1;
    for (my $i=0; $i<=$#{$rv1}; ++$i) {
        if (${$rv1}[$i] < ${$rv2}[$i]) { $gt = 0; last; }
    }
    return $gt;
}

sub equals_to()
{
    my ($rv1, $rv2) = @_;
    my $eqs = 1;
    for (my $i=0; $i<=$#{$rv1}; ++$i) {
        if (${$rv1}[$i] != ${$rv2}[$i]) { $eqs = 0; last; }
    }
    return $eqs;
}

## OBS: This is not working; calling classifier w/ system call
#use Inline Python => <<'END_OF_PYTHON_CODE';
#import numpy as np
#import pickle
#
#def run_mbt_classifier(model, inst):
#    with open(model, 'rb') as fobj:
#        mb_clf = pickle.load(fobj)
#
#    #print(int(round(mb_clf.predict(np.array([inst]))[0])))
#    return int(round(mb_clf.predict(np.array([inst]))[0]))
#
#END_OF_PYTHON_CODE

END {
}

1;  # to ensure that the 'require' or 'use' succeeds
