#!/usr/bin/perl
use strict;use warnings;

# for running all the races and putting the output in the output dir.
use FindBin;
use lib "$FindBin::RealBin/.";
use GenerateRaces;
my $runs = $GenerateRaces::RUNS;

for my $r (keys %$runs){
    my $cmd = "./f1-predictor.pl --out-file $r";
    $cmd .= " --out-sub-dir bill-tlb ";

    # $cmd .= " --player-rating-score ";
    $cmd .= " --no-pre-code";

    #$cmd .= " --no-pos-col";
    $cmd .= " --separator '' ";

    $cmd .= " --no-detail ";
    $cmd .= " --case-change-not-exact-predictions ";

    #$cmd .= " --fia ";
    $cmd .= " --fia-simple ";

    $cmd .= " --wta --run $runs->{$r}\n";
    system( $cmd ) ;
}

for my $r (keys %$runs){
    my $cmd = "./f1-predictor.pl --out-file $r";
    $cmd .= " --out-sub-dir bill-tlb-detailed ";

    # $cmd .= " --player-rating-score ";
    $cmd .= " --no-pre-code";

    #$cmd .= " --no-pos-col";
    #$cmd .= " --separator ', ' ";

    #$cmd .= " --no-detail ";
    #$cmd .= " --case-change-not-exact-predictions ";

    $cmd .= " --fia ";
    $cmd .= " --fia-simple ";

    $cmd .= " --wta --run $runs->{$r}\n";
    system( $cmd ) ;
}

for my $r (keys %$runs){
    my $cmd = "./f1-predictor.pl --out-file $r";
    $cmd .= " --out-sub-dir bill-tlb-very-detailed ";

    $cmd .= " --player-rating-score ";
    $cmd .= " --no-pre-code";

    #$cmd .= " --no-pos-col";
    #$cmd .= " --separator ', ' ";

    #$cmd .= " --no-detail ";
    #$cmd .= " --case-change-not-exact-predictions ";

    $cmd .= " --fia ";
    $cmd .= " --fia-simple ";
    $cmd .= " --show-p1-to-p6-totals";

    $cmd .= " --wta --run $runs->{$r}\n";
    system( $cmd ) ;
}
