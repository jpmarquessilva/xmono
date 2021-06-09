package HardCoded;

use strict;
use warnings;

use POSIX qw( !assert );
use Exporter;

require Utils;
import Utils qw( &max &ite );


BEGIN {
    @HardCoded::ISA = ('Exporter');
    @HardCoded::EXPORT_OK =  qw( &rdt_classifier &grd_classifier &rand_gen );
}


# Classifier for the bankruptcy risk monotonic decision tree (P&B'00 paper)
sub rdt_classifier()
{
    my ($vect) = @_;
    my @x = @{$vect};
    my $class =
        &ite($x[6]<=3,
             &ite($x[5]<=1,&ite($x[4],1,&ite($x[7],1,2)),2),
             &ite($x[8]<=3,2,3));
    return $class;
}

# Classifier for the student grade (random) dataset
sub grd_classifier()
{
    my ($vect) = @_;
    if (0) { print "\@vect=@{$vect}\n"; }
    #my $Vs = $inst->{Vs};
    #my ($Q, $E, $H, $R) = ($Vs->{1}, $Vs->{2}, $Vs->{3}, $Vs->{4});
    my ($Q, $E, $H, $R) = @{$vect};
    if (0) { print "(Q,E,H,R)=($Q,$E,$H,$R)\n"; }
    #
    # S = max [0.3 × Q + 0.6 × E + 0.1 × H, R]
    my $S = &max(0.3*$Q+0.6*$E+0.1*$H, $R);
    #
    # M = ITE(S ≥ 9,A,ITE(S ≥ 7,B,ITE(S ≥ 5,C,ITE(S ≥ 4,D,ITE(S ≥ 2,E,F)))))
    my $M = &ite($S>=9,'A', &ite($S>=7,'B', &ite($S>=5,'C', &ite($S>=4,'D',  &ite($S>=2,'E','F')))));
    if (0) { print "M=$M\n"; }
    return $M;
}


END {
}

1;  # to ensure that the 'require' or 'use' succeeds
