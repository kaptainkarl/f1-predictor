#!/usr/bin/perl
use strict;use warnings;

my $runs = {
    ALL   => "jeddah-race,jeddah-qual,bahrain-race,bahrain-qual",
};

for my $r (keys %$runs){
    my $cmd = "./f1-predictor.pl --player-rating-score ";

    $cmd .= " --out-sub-dir leo ";
    $cmd .= " --out-file $r ";
    $cmd .= " --leo --no-pre-code ";
    $cmd .= " --run $runs->{$r}";

    system( $cmd ) ;
}
