#!/usr/bin/perl
use strict;use warnings;

# for running all the races and putting the output in the output dir.
use FindBin;
use lib "$FindBin::RealBin/.";
use GenerateRaces;
my $runs = $GenerateRaces::RUNS;

for my $r (keys %$runs){
    my $cmd = "./f1-predictor.pl --player-rating-score ";

    $cmd .= " --out-sub-dir bill-tlb ";
    # $cmd .= " --out-accuracy-sub-dir";
    $cmd .= " --out-file $r";

    $cmd .= " --wta ";
    $cmd .= " --run $runs->{$r}\n";

    system( $cmd ) ;
}


for my $r (keys %$runs){
    my $cmd = "./f1-predictor.pl --player-rating-score ";

    $cmd .= " --out-sub-dir bill-tlb-detailed ";
    # $cmd .= " --out-accuracy-sub-dir";
    $cmd .= " --out-file $r";

    $cmd .= " --wta ";
    $cmd .= " --run $runs->{$r}\n";

    system( $cmd ) ;
}
