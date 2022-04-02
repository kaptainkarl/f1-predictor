#!/usr/bin/perl
use strict;use warnings;

# for running favourite algorithms and putting in the output dir.

my $runs = {
    RACES => "bahrain-race,jeddah-race",
    QUAL  => "bahrain-qual,jeddah-qual",
    ALL   => "bahrain-qual,bahrain-race,jeddah-qual,jeddah-race",
};

my $favs = [
    " --score-sys=exact --score-times-power-100 ",
    " --score-sys=diff  --score-times-1990 ",
];

for my $fv ( @$favs ){
    for my $r (keys %$runs){
        my $cmd = "./f1-predictor.pl --player-fia-score --player-rating-score ";

        $cmd .= " --out-favourites $fv --out-file $r --run $runs->{$r}\n";

        system( $cmd ) ;

    }
}
