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
    $cmd .= " --out-file $r";
    $cmd .= " --run $runs->{$r}";

    $cmd .= " --html-out ";
    print "$cmd\n";
    system( $cmd );
}

for my $r (keys %$runs){
    next if $r ne "RACES";
    my $cmd = "./f1-predictor.pl ";
    $cmd .= " --out-sub-dir bill ";
    $cmd .= " --closest-p1-20 ";
    $cmd .= " --fia --fia-sprint-qual-diff ";
    $cmd .= " --suppress-average-table ";
    $cmd .= " --no-pre-code ";
    $cmd .= " --out-file $r-DETAILED ";
    $cmd .= " --run $runs->{$r}";
    $cmd .= " --html-out ";
    print "$cmd\n";
    system( $cmd );
}

for my $r (keys %$runs){
    next if $r ne "RACES";
    my $cmd = "./f1-predictor.pl ";
    $cmd .= " --out-sub-dir bill ";
    $cmd .= " --closest-p1-20 ";
    $cmd .= " --fia --fia-sprint-qual-diff ";
    $cmd .= " --suppress-average-table ";
    $cmd .= " --no-pre-code ";
    $cmd .= " --out-file $r-DETAILED-RATING ";
    $cmd .= " --closest-p1-20-details ";
    $cmd .= " --no-prediction-detail ";
    $cmd .= " --run $runs->{$r}";
    $cmd .= " --html-out ";
    print "$cmd\n";
    system( $cmd );
}

for my $r (keys %$runs){
    next if $r ne "RACES";
    my $cmd = "./f1-predictor.pl ";
    $cmd .= " --out-sub-dir bill ";
    $cmd .= " --closest-p1-20 ";
    $cmd .= " --fia --fia-sprint-qual-diff ";
    $cmd .= " --suppress-average-table ";
    $cmd .= " --no-pre-code ";
    $cmd .= " --out-file $r-TOO-MUCH-DETAIL ";
    $cmd .= " --closest-p1-20-details ";
    $cmd .= " --run $runs->{$r}";
    $cmd .= " --html-out ";
    $cmd .= " --separator '|'";
    print "$cmd\n";
    system( $cmd );
}

