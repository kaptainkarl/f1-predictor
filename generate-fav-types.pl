#!/usr/bin/perl
use strict;use warnings;

# for running favourite algorithms and putting in the output dir.
use FindBin;
use lib "$FindBin::RealBin/.";
use GenerateRaces;
my $runs = $GenerateRaces::RUNS;

my $favs = [
    " --wta ",
    " --score-accuracy=diff  --score-times 9-to-1 ",

];

for my $fv ( @$favs ){
    for my $r (keys %$runs){
        my $cmd = "./f1-predictor.pl --player-fia-score --player-rating-score ";

        $cmd .= " --out-sub-dir favourites $fv --out-file $r --run $runs->{$r}";

        system( $cmd ) ;
    }
}

for my $fv ( @$favs ){
    for my $r (keys %$runs){
        my $cmd = "./f1-predictor.pl --player-fia-score --player-rating-score ";

        $cmd .= " --out-sub-dir favourites $fv --out-file $r-TOTALS --run $runs->{$r}";
        $cmd .= " --no-rounds";

        system( $cmd ) ;
    }
}
