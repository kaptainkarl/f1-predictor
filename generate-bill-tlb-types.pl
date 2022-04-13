#!/usr/bin/perl
use strict;use warnings;

# for running all the races and putting the output in the output dir.
use FindBin;
use lib "$FindBin::RealBin/.";
use GenerateRaces;
my $runs = $GenerateRaces::RUNS;

for my $r (keys %$runs){
    my $cmd = "./f1-predictor.pl ";
    $cmd .= " --out-sub-dir bill-tlb ";
    $cmd .= " --no-pre-code";
    #$cmd .= " --no-pos-col";
    $cmd .= " --out-file $r";

    $cmd .= " --separator '' ";
    $cmd .= " --no-detail ";
    $cmd .= " --case-change-not-exact-predictions ";
    $cmd .= " --fia --fia-simple ";
    $cmd .= " --wta ";
    $cmd .= " --run $runs->{$r}\n";

    system( $cmd ) ;
}

for my $r (keys %$runs){
    my $cmd = "./f1-predictor.pl ";
    # $cmd .= " --player-rating-score ";
    $cmd .= " --out-sub-dir bill-tlb-detailed ";
    $cmd .= " --no-pre-code";
    $cmd .= " --no-pos-col";
    $cmd .= " --out-file $r";
    # $cmd .= " --separator ', ' ";

    $cmd .= " --fia --fia-simple ";
    $cmd .= " --wta ";
    $cmd .= " --run $runs->{$r}\n";

    system( $cmd ) ;
}

for my $r (keys %$runs){
    my $cmd = "./f1-predictor.pl ";
    $cmd .= " --player-rating-score ";
    $cmd .= " --out-sub-dir bill-tlb-very-detailed ";
    $cmd .= " --no-pre-code";
    $cmd .= " --no-pos-col";
    $cmd .= " --out-file $r";
    # $cmd .= " --separator ', ' ";

    $cmd .= " --fia --fia-simple ";
    $cmd .= " --wta ";
    $cmd .= " --run $runs->{$r}\n";

    system( $cmd ) ;
}
