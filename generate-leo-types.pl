#!/usr/bin/perl

use strict;use warnings;

use FindBin;
use lib "$FindBin::RealBin/.";
use GenerateRaces;
my $runs = $GenerateRaces::RUNS;

for my $r (keys %$runs){
    next if $r ne "ALL";

    my $cmd = "./f1-predictor.pl --player-rating-score ";

    $cmd .= " --out-sub-dir leo ";
    $cmd .= " --out-file $r ";
    $cmd .= " --leo --no-pre-code ";
    $cmd .= " --run $runs->{$r}";

    system( $cmd ) ;
}
