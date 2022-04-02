#!/usr/bin/perl
use strict;use warnings;

# for running favourite algorithms and putting in the output dir.

my $runs = {
    QUAL  => "bahrain-qual,jeddah-qual",
    RACES => "bahrain-race,jeddah-race",
    ALL   => "bahrain-qual,bahrain-race,jeddah-qual,jeddah-race",
};

my $favs = [
    " --score-sys=exact --score-times-power-100 ",
    " --score-sys=diff  --score-times-1990 ",
];

for my $fv ( @$favs ){
    for my $r (keys %$runs){
        my $cmd = "./f1-predictor.pl --player-fia-score --player-rating-score ";

        $cmd .= " --out-sub-dir favourites $fv --out-file $r --run $runs->{$r}\n";

        system( $cmd ) ;
    }
}
