#!/usr/bin/perl
use strict;use warnings;
# for running all the races and putting the output in the output dir.
use FindBin;
use lib "$FindBin::RealBin/.";
use GenerateRaces;
my $runs = $GenerateRaces::RUNS;
for my $r (keys %$runs){
    next if $r ne "RACES";
    my $cmd = "./f1-predictor.pl ";
    $cmd .= " --out-sub-dir bill ";
    $cmd .= " --bill";
    # --bill implies :
    # --wta, --no-pre-code --fia-simple
    # --no-pos-col
    $cmd .= " --out-file $r";
    $cmd .= " --run $runs->{$r}\n";

    system( $cmd );
}
