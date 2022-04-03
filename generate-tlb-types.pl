#!/usr/bin/perl
use strict;use warnings;

# for running all the races and putting the output in the output dir.

my $runs = {
    RACES => "bahrain-race,jeddah-race",
    QUAL  => "bahrain-qual,jeddah-qual",
    ALL   => "bahrain-qual,bahrain-race,jeddah-qual,jeddah-race",
};

my $score_sys = [
    "karl-8",
    "karl-32",
    "karl-96-16",
    "diff",
    "exact",
];

my $multipliers = [
    "none",
    "9-to-1",
    "1-to-9",
    "25-to-8",
    "power-100",
];

for my $sc ( @$score_sys ) {
    for my $ml ( @$multipliers ){
        for my $r (keys %$runs){
            my $cmd = "./f1-predictor.pl --player-rating-score ";

            $cmd .= " --out-sub-dir tlb ";
            $cmd .= " --out-accuracy-sub-dir";
            $cmd .= " --out-file $r";

            $cmd .= " --score-accuracy $sc --score-times $ml ";
            $cmd .= " --run $runs->{$r}\n";

            system( $cmd ) ;
        }
    }
}
