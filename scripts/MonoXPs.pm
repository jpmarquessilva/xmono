package MonoXPs;

use strict;
use warnings;

use Data::Dumper;

use POSIX qw( !assert );
use Exporter;

require Utils;  # Must use require, to get INC updated
import Utils qw( &assert &mark_curr_time &read_elapsed_time );

require Writers;
import Writers qw( write_cnf write_xp );

use Solver qw( &run_sat_solver );

use Model qw( &run_classifier );

use constant DBG => 1;   ## Also, comment out unused 'uses'
use constant CHK => 1;


BEGIN {
    @MonoXPs::ISA = ('Exporter');
    @MonoXPs::EXPORT_OK =
        qw( &compute_one_axp &compute_one_cxp &compute_xps
            &set_def_vect &validate_prediction &update_stats &init_stats );
}


# Required: starting Univs must be specified.
# When enumerating, boots(trapped)=1, and so both Univs+Fixes initialized
sub compute_one_axp()
{
    my ($opts, $mxp, $stats, $boots) = @_;
    if (defined($opts->{v}) && $opts->{v} >= 5) {
        my @Us = sort {$a<=>$b} keys %{$mxp->{Univs}};
        print "Finding one AXp (w/ Univs: [@Us])\n";
    }
    # 1. Set vLB and vUB = v (i.e. starting point in feature space)
    # 2. For each universal feature i:
    # 2.1 Update vLB with the LBi and update vUB with the UBi
    # 2.2 Optional invariant: vLB = vUB
    # 2.3 See all other features to fixed
    if (!$boots) { &set_axp_vect($opts, $mxp); }
    # 3. For each feature j:
    for(my $idx=1; $idx<=$mxp->{NF}; ++$idx) {
        next if $mxp->{Univs}->{$idx};
        # 3.1 Update vLB with LBj and update vUB with UBj
        # 3.2 Make feature universal (i.e. not in explanation)
        &make_feature_universal($opts, $mxp, $idx);
        # 3.2 Simulate ML model with vLB and vUB
        my $clb = &run_classifier($opts, $stats, $mxp, $mxp->{vLB});
        my $cub = &run_classifier($opts, $stats, $mxp, $mxp->{vUB});
        if ($opts->{s}) { $stats->{NSIM} += 2; }
        if (DBG && $opts->{d}) { print "$clb vs $cub\n"; }
        # 3.3. If both prediction are the same: done
        if ($clb eq $cub) { next; }
        # 3.4. If the two predictions differ:
        else {
            # 3.4.1 Undo change to bounds of j; feature j becomes fixed
            &make_feature_fixed($opts, $mxp, $idx);
        }
    }
    if (DBG && $opts->{d}) { print Data::Dumper->Dump([ $mxp ], [ qw(mxp) ]); }
    # 4. Return set of features in explanation
    my @xp = sort {$a <=> $b} keys %{$mxp->{Fixes}};
    return \@xp;
}

# Required: starting Fixes must be specified.
# When enumerating, boots(trapped)=1, and so both Univs+Fixes initialized
sub compute_one_cxp()
{
    my ($opts, $mxp, $stats, $boots) = @_;
    if (defined($opts->{v}) && $opts->{v} >= 5) {
        my @Fs = sort {$a<=>$b} keys %{$mxp->{Fixes}};
        print "Finding one CXp (w/ Fixes: [@Fs])\n";
    }
    # 1. Set vLB and vUB resp. with the LB and UB values of all features
    # 2. For each fixed feature i, fix coordinate of vLB and vUB to vi
    if (!$boots) { &set_cxp_vect($opts, $mxp); }
    # 3. For each feature j:
    for(my $idx=1; $idx<=$mxp->{NF}; ++$idx) {
        next if $mxp->{Fixes}->{$idx};
        # 3.1. Update vLB with vj and update vUB with vj
        &make_feature_fixed($opts, $mxp, $idx);
        # 3.2 Simulate ML model with vLB and vUB
        my $clb = &run_classifier($opts, $stats, $mxp, $mxp->{vLB});
        my $cub = &run_classifier($opts, $stats, $mxp, $mxp->{vUB});
        if ($opts->{s}) { $stats->{NSIM} += 2; }
        if (DBG && $opts->{d}) { print "$clb vs $cub\n"; }
        # 3.3 If the two predictions (still) differ:
        if ($clb ne $cub) { next; }
        # 3.4 If both prediction are the same:
        else {
            # 3.4.1 Undo change to bounds of j; feature j becomes fixed
            &make_feature_universal($opts, $mxp, $idx);
        }
    }
    if (DBG && $opts->{d}) { print Data::Dumper->Dump([ $mxp ], [ qw(mxp) ]); }
    # 4. Return set of features in explanation
    my @xp = sort {$a <=> $b} keys %{$mxp->{Univs}};
    return \@xp;
}

sub compute_xps()
{
    my ($opts, $mxp, $stats) = @_;
    # 1a. Initialize SAT solver, e.g. # of vars
    &init_cnf($opts, $mxp);
    # 1b. While there are solutions of CNF formula
    my $cntxp = (defined($opts->{N})) ? 1 : 0; my $numxp = 0; my $done = 0;
    while (!$done) {
        my $rtime = &mark_curr_time();
        # 2. Create CNF file
        &write_cnf($opts, $mxp->{CNF}->{FNAME}, $mxp->{CNF});
        # 2. Call SAT solver
        if ($opts->{s}) { $stats->{NSAT}++; }
        my ($outc, $model) =
            &run_sat_solver($opts, $stats, $mxp->{CNF}, $mxp->{CNF}->{FNAME});
        # 2.1 If UNSAT, then terminate
        if (!$outc) { last; }
        if (defined($opts->{v}) && $opts->{v} >= 5) {
            print "Deciding whether to extract one AXp or one CXp\n";
        }
        # 2.2 Else:
        # 2.2.1 Construct vLB and vUB
        &mk_ref_vlb_vub($stats, $mxp, $model);
        # 2.2.2 Run classifier on both vLB and vUB
        my $clb = &run_classifier($opts, $stats, $mxp, $mxp->{vLB});
        my $cub = &run_classifier($opts, $stats, $mxp, $mxp->{vUB});
        if ($opts->{s}) { $stats->{NSIM} += 2; }
        # 2.2.3 If clb = cub:
        if ($clb eq $cub) {
            # 2.2.3.1 Extract AXp
            my $xp = &compute_one_axp($opts, $mxp, $stats, 1);
            # 2.2.3.2 Process AXp: block, print, analyze, etc.
            $done = &process_xp($opts, $stats, $mxp, $xp, 'AXp', $rtime);
        }
        # 2.2.4 Else:
        else {
            # 2.2.4.1 Extract CXp
            my $xp = &compute_one_cxp($opts, $mxp, $stats, 1);
            # 2.2.4.2 Process CXp: block, print, analyze, etc.
            $done = &process_xp($opts, $stats, $mxp, $xp, 'CXp', $rtime);
        }
        if ($cntxp && ++$numxp == $opts->{N}) { last; }
        if (DBG && $opts->{d}) {
            print Data::Dumper->Dump([ $mxp ], [ qw(mxp) ]); }
    }
    return;
}


# Auxiliary functions

sub process_xp()
{
    my ($opts, $stats, $mxp, $xp, $xtype, $rtime) = @_;
    my $done = (@{$xp} == 0);
    if ($xtype eq 'AXp') { &block_axp($opts, $mxp, $xp); }
    else                 { &block_cxp($opts, $mxp, $xp); }

    if ($opts->{w} || $opts->{l}) { &write_xp($opts, $mxp, $xp, $xtype); }

    
    if ($opts->{s}) { &update_stats($opts, $stats, $xp, $xtype); }
    if (defined($opts->{v}) && $opts->{v} > 1) {
        if ($done) {
            print "Empty $xtype. No need to enumerate. Terminating...\n";
        }
        my $elapsed = &read_elapsed_time($rtime);
        my $ptime = sprintf("%7.6f", $elapsed);
        print "Elapsed time:   $ptime s\n";
    }
    return $done;        # If xp empty, then must terminate...
}
    

sub set_def_vect()
{
    my ($opts, $mxp, $inst) = @_;
    if (!defined($mxp->{NF})) { $mxp->{NF} = $inst->{NF}; }
    @{$mxp->{vect}} = (0) x $mxp->{NF};
    for(my $i=1; $i<=$mxp->{NF}; ++$i) {
        $mxp->{vect}[$i-1] = $inst->{Vs}->{$i};
    }
    if (DBG && $opts->{d}) { print Data::Dumper->Dump([ $mxp ], [ qw(mxp) ]); }
}


sub validate_prediction()
{
    my ($opts, $stats, $mxp, $inst) = @_;
    my $sCl = &run_classifier($opts, $stats, $mxp, $mxp->{vect});
    my $clok = ($sCl eq $inst->{Cl});
    if (!$clok) {
        my $clstr = "Classif([@{$mxp->{vect}}])=$sCl";
        my $insstr = "Inst([@{$mxp->{vect}}])=$inst->{Cl}";
        my $errmsg = ($opts->{V}) ? 'ERROR' : 'WARN';
        my $prtmsg = "$errmsg: $clstr vs. $insstr\n";
        print "$prtmsg";
    }
    else {
        if ($opts->{V}) { print "Classif([@{$mxp->{vect}}]) ok\n"; }
    }
    return $clok;
}


sub make_feature_universal()
{
    my ($opts, $mxp, $idx) = @_;
    if (DBG && $opts->{d}) {
        print "idx: $idx\n";
        print "vLB: @{$mxp->{vLB}}\n";
        print "vUB: @{$mxp->{vUB}}\n";
    }
    $mxp->{Univs}->{$idx} = 1;
    delete $mxp->{Fixes}->{$idx};
    my $i = $idx-1;
    ${$mxp->{vLB}}[$i] = $mxp->{LBs}->{$idx};
    ${$mxp->{vUB}}[$i] = $mxp->{UBs}->{$idx};
    if (DBG && $opts->{d}) {
        print "idx: $idx\n";
        print "vLB: @{$mxp->{vLB}}\n";
        print "vUB: @{$mxp->{vUB}}\n";
    }
}

sub make_feature_fixed()
{
    my ($opts, $mxp, $idx) = @_;
    if (DBG && $opts->{d}) {
        print "idx: $idx\n";
        print "vLB: @{$mxp->{vLB}}\n";
        print "vUB: @{$mxp->{vUB}}\n";
    }
    $mxp->{Fixes}->{$idx} = 1;
    delete $mxp->{Univs}->{$idx};
    my $i = $idx-1;
    ${$mxp->{vLB}}[$i] = $mxp->{vect}[$i];
    ${$mxp->{vUB}}[$i] = $mxp->{vect}[$i];
    if (DBG && $opts->{d}) {
        print "idx: $idx\n";
        print "vLB: @{$mxp->{vLB}}\n";
        print "vUB: @{$mxp->{vUB}}\n";
    }
}


# Required: $mxp->{Fixes} reflects the instances that must be universal
sub set_axp_vect()
{
    my ($opts, $mxp) = @_;
    @{$mxp->{vLB}} = (0) x $mxp->{NF};
    @{$mxp->{vUB}} = (0) x $mxp->{NF};
    for(my $i=0; $i<$mxp->{NF}; ++$i) {
        my $idx = $i+1;
        if (defined($mxp->{Univs}->{$idx})) {
            ${$mxp->{vLB}}[$i] = $mxp->{LBs}->{$idx};
            ${$mxp->{vUB}}[$i] = $mxp->{UBs}->{$idx};
        } else {
            $mxp->{Fixes}->{$idx} = 1;
            ${$mxp->{vLB}}[$i] = ${$mxp->{vect}}[$i];
            ${$mxp->{vUB}}[$i] = ${$mxp->{vect}}[$i];
        }
    }
    if (DBG && $opts->{d}) { print Data::Dumper->Dump([ $mxp ], [ qw(mxp) ]); }
}

# Required: $mxp->{Fixes} reflects the instances that must be fixed
sub set_cxp_vect()
{
    my ($opts, $mxp) = @_;
    @{$mxp->{vLB}} = (0) x $mxp->{NF};
    @{$mxp->{vUB}} = (0) x $mxp->{NF};
    for(my $i=0; $i<$mxp->{NF}; ++$i) {
        my $idx = $i+1;
        if (defined($mxp->{Fixes}->{$idx})) {
            ${$mxp->{vLB}}[$i] = ${$mxp->{vect}}[$i];
            ${$mxp->{vUB}}[$i] = ${$mxp->{vect}}[$i];
        } else {
            $mxp->{Univs}->{$idx} = 1;
            ${$mxp->{vLB}}[$i] = $mxp->{LBs}->{$idx};
            ${$mxp->{vUB}}[$i] = $mxp->{UBs}->{$idx};
        }
    }
    if (DBG && $opts->{d}) { print Data::Dumper->Dump([ $mxp ], [ qw(mxp) ]); }
}


sub init_cnf()
{
    my ($opts, $mxp) = @_;
    $mxp->{CNF}->{FNAME} = './scripts//outp/current_cnt.cnf';
    $mxp->{CNF}->{NV} = $mxp->{NF};
    $mxp->{CNF}->{NC} = 0;
    $mxp->{CNF}->{Cls} = [];
}

sub mk_ref_vlb_vub()
{
    my ($stats, $mxp, $model) = @_;

    %{$mxp->{Univs}} = ();
    %{$mxp->{Fixes}} = ();
    @{$mxp->{vLB}} = (0) x $mxp->{NF};
    @{$mxp->{vUB}} = (0) x $mxp->{NF};
    for(my $i=0; $i<=$#{$model}; ++$i) {
        my $idx = abs(${$model}[$i]);
        if (CHK) { assert(($idx == $i+1), '$idx == $i+1', __LINE__, __FILE__); }
        my $sgn = (${$model}[$i]<0);
        if (!$sgn) {
            ${$mxp->{vLB}}[$i] = $mxp->{LBs}->{$idx};
            ${$mxp->{vUB}}[$i] = $mxp->{UBs}->{$idx};
            $mxp->{Univs}->{$idx} = 1;
        } else {
            ${$mxp->{vLB}}[$i] = ${$mxp->{vect}}[$i];
            ${$mxp->{vUB}}[$i] = ${$mxp->{vect}}[$i];
            $mxp->{Fixes}->{$idx} = 1;
        }
    }
}

sub block_axp()
{
    my ($opts, $mxp, $xp) = @_;
    my $cl = [];
    foreach my $fn (@{$xp}) {
        push @{$cl}, $fn;
    }
    if (DBG && $opts->{d}) { print "Blocking clause: @{$cl}\n"; }
    push @{$mxp->{CNF}->{Cls}}, $cl;
    $mxp->{CNF}->{NC}++;
}

sub block_cxp()
{
    my ($opts, $mxp, $xp) = @_;
    my $cl = [];
    foreach my $fn (@{$xp}) {
        push @{$cl}, -$fn;
    }
    if (DBG && $opts->{d}) { print "Blocking clause: @{$cl}\n"; }
    push @{$mxp->{CNF}->{Cls}}, $cl;
    $mxp->{CNF}->{NC}++;
}

sub init_stats()
{
    my ($opts, $stats) = @_;
    $stats->{AXp}->{Num} = 0;
    $stats->{AXp}->{Lits} = 0;
    $stats->{CXp}->{Num} = 0;
    $stats->{CXp}->{Lits} = 0;
}

sub update_stats()
{
    my ($opts, $stats, $xp, $xtype) = @_;
    if ($xtype eq 'AXp') {
        $stats->{AXp}->{Num}++;
        $stats->{AXp}->{Lits} += ($#{$xp}+1);
    }        
    elsif ($xtype eq 'CXp') {
        $stats->{CXp}->{Num}++;
        $stats->{CXp}->{Lits} += ($#{$xp}+1);
    }
    else { die "Invalid explanation type: $xtype\n"; }
}

END {
}

1;  # to ensure that the 'require' or 'use' succeeds
