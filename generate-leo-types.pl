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
    $cmd .= " --wta ";
    $cmd .= " --no-detail ";
    #$cmd .= " --no-pre-code ";
    $cmd .= " --run $runs->{$r}";

    system( $cmd ) ;
}
