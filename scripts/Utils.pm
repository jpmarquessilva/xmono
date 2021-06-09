package Utils;

use strict;
use warnings;

use Data::Dumper;

use POSIX qw( !assert strftime );
use Time::HiRes qw(time);
use Exporter();
use Sys::Hostname;


BEGIN {
    @Utils::ISA = ('Exporter');
    @Utils::EXPORT_OK =
        qw( &get_progname &get_progpath &round &SIG_handler &assert
            &set_start_time &mark_curr_time &read_elapsed_time
            &print_update_time &round &rand_gen &max &ite );
}


#------------------------------------------------------------------------------#
# Execution path handling
#------------------------------------------------------------------------------#

sub get_progname() {
    my @progname_toks = split(/\//, $0);
    my $progname = $progname_toks[$#progname_toks];
    #print "$progname\n";
    return $progname;
}

sub get_progpath() {
    my @progname_toks = split(/\//, $0);
    pop @progname_toks;
    my $progpath = join('/', @progname_toks);
    if ($progpath eq '') { $progpath = '\.\/'; }
    #print "Prog Path: $progpath\n"; #exit;
    return $progpath;
}

sub get_hostname() {
    my $full_host_name = &Sys::Hostname::hostname();
    $full_host_name =~ m/(\w+)\.?/;
    my $rhname = $1;
    #print "|$hostname|\n"; exit;
    return $rhname;
}

sub resolve_inc() {    # Kept here as a template; need a copy in each script...
    my ($cref, $pmname) = @_;
    my @progname_toks = split(/\//, $0);
    pop @progname_toks;
    my $progpath = join('/', @progname_toks);
    my $fullname = $progpath . '/' . $pmname;
    my $fh;
    open($fh, "<$fullname") || die "non-existing file: $pmname\n";
    return $fh;
}


#------------------------------------------------------------------------------#
# Signal handling utilities
#------------------------------------------------------------------------------#

sub register_handlers()
{
    $SIG{'INT'} = 'Utils::INT_handler';
    $SIG{'TERM'} = 'Utils::INT_handler';
    $SIG{'ABRT'} = 'Utils::SIG_handler';
    $SIG{'SEGV'} = 'Utils::SIG_handler';
    $SIG{'BUS'} = 'Utils::SIG_handler';
    $SIG{'QUIT'} = 'Utils::SIG_handler';
    $SIG{'XCPU'} = 'Utils::SIG_handler';
}

my @args = ();
my @callback = ();

sub push_arg()
{
    push @args, shift;
}

sub push_callback()
{
    push @callback, shift;
}

sub SIG_handler()
{
    &Utils::INT_handler();
}

sub INT_handler()
{
    # call any declared callbacks, e.g. to prints stats, summaries, etc.
    print "\nReceived system signal. Cleaning up & terminating...\n";
    foreach my $cback (@callback) {
        &{$cback}(\@args);
    }
    exit 20;    # 20 denotes resources exceeded condition (see below)
}


#------------------------------------------------------------------------------#
# Assert function
#------------------------------------------------------------------------------#

sub assert()
{
    my ($cond, $cstr, $line, $file) = @_;
    if (!$cond) {
        die "Condition $cstr fails in line $line of file $file\n";
    }
}


#------------------------------------------------------------------------------#
# Assert function
#------------------------------------------------------------------------------#

my $start;
my $last;

sub set_start_time()
{
    $start = time;
    $last = time;
}

sub mark_curr_time()
{
    return time;
}

sub read_elapsed_time()
{
    my ($rtime) = @_;
    my $ctime = time;
    my $elapsed = $ctime - $rtime;
    return $elapsed;
}

sub print_update_time()
{
    my $ctime = time;
    my $duration = $ctime - $start;
    my $elapsed = $ctime - $last;
    print "Total run time: $duration s\n";
    print "Elapsed time:   $elapsed s\n";
    $last = $ctime;
}


#------------------------------------------------------------------------------#
# Useful utils
#------------------------------------------------------------------------------#

sub max()
{
    my ($a, $b) = @_;
    return ($a >= $b) ? $a : $b;
}

sub ite()
{
    my ($a, $b, $c) = @_;
    return ($a) ? $b : $c;
}

sub round()
{
    my ($rval) = @_;
    return int($rval + 0.5);
}

sub rand_gen()
{
    my ($UB) = @_;
    return int(rand($UB));
}


END {
}

1;  # to ensure that the 'require' or 'use' succeeds
