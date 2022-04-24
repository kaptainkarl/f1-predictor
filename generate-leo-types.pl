#!/usr/bin/perl
use strict;use warnings;
use FindBin;
use lib "$FindBin::RealBin/.";
use GenerateRaces;
my $runs = $GenerateRaces::RUNS;
for my $r (keys %$runs){
    # next if $r ne "ALL";
    my $cmd = "./f1-predictor.pl ";
    $cmd .= " --out-sub-dir leo ";
    $cmd .= " --out-file $r ";
    $cmd .= " --closest-p1-20 ";
    $cmd .= " --no-detail ";
    $cmd .= " --no-pre-code ";
    $cmd .= " --show-winners-summary ";
    $cmd .= " --run $runs->{$r}";
    system( $cmd ) ;
}
