#!/usr/bin/perl
use strict;use warnings;
# for running all the races and putting the output in the output dir.
use FindBin;
use lib "$FindBin::RealBin/.";
use GenerateRaces;
my $runs = $GenerateRaces::RUNS;

# some global option twiddling on all outputs.
my $o_method = " --closest-p1-20 ";

# --html-out

run_them( "closest-p1-20-fia-same-points",
          " --fia --show-p1-to-p10-totals ");

run_them( "closest-p1-20-fia-diff-points",
          " --fia --fia-sprint-qual-diff --show-p1-to-p10-totals ");

sub run_them {

    my ($subdir, $opts) = @_;

    for my $r (keys %$runs){

        my $cmd = "./f1-predictor.pl ";
        $cmd .= " --out-sub-dir $subdir $o_method $opts ";

        $cmd .= " --out-file $r ";
        $cmd .= " --no-detail ";
        $cmd .= " --run $runs->{$r}";
        print "$cmd\n";
        system( $cmd ) ;

        $cmd = "./f1-predictor.pl ";
        $cmd .= " --out-sub-dir $subdir $o_method $opts ";

        $cmd .= " --out-file $r-DETAILED ";
        $cmd .= " --run $runs->{$r}";
        print "$cmd\n";
        system( $cmd );


        $cmd = "./f1-predictor.pl ";
        $cmd .= " --out-sub-dir $subdir $o_method $opts ";

        $cmd .= " --out-file $r-DETAILED-RATING ";
        $cmd .= " --closest-p1-20-details ";
        $cmd .= " --no-prediction-detail ";
        $cmd .= " --run $runs->{$r}";
        print "$cmd\n";
        system( $cmd );


        $cmd = "./f1-predictor.pl ";
        $cmd .= " --out-sub-dir $subdir $o_method $opts ";

        $cmd .= " --out-file $r-TOO-MUCH-DETAIL ";
        $cmd .= " --closest-p1-20-details ";
        $cmd .= " --run $runs->{$r}";
        $cmd .= " --separator '|'";
        print "$cmd\n";
        system( $cmd );
    }

}

