#!/usr/bin/perl
use strict;use warnings;

use FindBin;
use lib "$FindBin::RealBin/.";
use GenerateRaces;
my $runs = $GenerateRaces::RUNS;


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
            my $cmd = "./f1-predictor.pl --player-fia-score --player-rating-score ";
            $cmd .= " --fia-simple --show-p1-to-p6-totals";

            # $cmd .= " --out-sub-dir all-algorithms "; # don't need this the default.
            $cmd .= " --out-accuracy-sub-dir";
            $cmd .= " --out-file $r";

            $cmd .= " --score-accuracy $sc --score-times $ml ";
            $cmd .= " --run $runs->{$r}\n";

            $cmd .= " --html-out ";
            system( $cmd ) ;
        }
    }
}

for my $sc ( @$score_sys ) {
    for my $ml ( @$multipliers ){
        for my $r (keys %$runs){
            my $cmd = "./f1-predictor.pl --player-fia-score --player-rating-score ";
            $cmd .= " --fia-simple --show-p1-to-p6-totals";

            $cmd .= " --score-accuracy $sc --score-times $ml --out-file $r-TOTALS --run $runs->{$r}";
            $cmd .= " --no-rounds";
            $cmd .= " --out-accuracy-sub-dir";

            $cmd .= " --html-out ";
            system( $cmd ) ;
        }
    }
}
