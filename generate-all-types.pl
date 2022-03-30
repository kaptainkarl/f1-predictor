#!/usr/bin/perl
use strict;use warnings;

my $runs = {
    RACES => "bahrain-race,jeddah-race",
    QUAL  => "bahrain-qual,jeddah-qual",
    ALL   => "bahrain-qual,bahrain-race,jeddah-qual,jeddah-race",
};


my $score_sys = [
    "karl-8",
    "karl-32",
    "diff",
    "exact",
];

my $multipliers = [
    " --score-times-current ",
    " --score-times-1990 ",
    " --score-times-power-100 ",
    "", # no multiplier
];

#./f1-predictor.pl --run bahrain-qual,jeddah-qual   --no-pre-code --out-file "blah"

for my $sc ( @$score_sys ) {
    for my $ml ( @$multipliers ){
        for my $r (keys %$runs){
            my $cmd = "./f1-predictor.pl --player-fia-score --player-rating-score ";

            $cmd .= " --score-sys $sc $ml --out-file $r --run $runs->{$r}\n";

            system( $cmd ) ;



        }
    }
}
