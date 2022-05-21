#!/usr/bin/perl
use strict;use warnings;
# for running all the races and putting the output in the output dir.
use FindBin;
use lib "$FindBin::RealBin/.";
use GenerateRaces;
my $runs = $GenerateRaces::RUNS;

# some global option twiddling on all outputs.
my $o_method = " --closest-p1-20 ";
my $o_fia_sprint_qual_diff = " --fia-sprint-qual-diff ";
# $o_fia_sprint_qual_diff = "";
my $only_races = 1;


for my $r (keys %$runs){
    next if $r ne "RACES" && $only_races;
    my $cmd = "./f1-predictor.pl ";
    $cmd .= " --out-sub-dir bill ";
    $cmd .= " $o_method ";
    $cmd .= " $o_fia_sprint_qual_diff ";
    $cmd .= " --bill";
    $cmd .= " --out-file $r";
    $cmd .= " --run $runs->{$r}";

    $cmd .= " --html-out ";
    print "$cmd\n";
    system( $cmd );

    $cmd = "./f1-predictor.pl ";
    $cmd .= " --out-sub-dir bill ";
    $cmd .= " $o_method ";
    $cmd .= " --fia ";
    $cmd .= " $o_fia_sprint_qual_diff ";
    $cmd .= " --suppress-average-table ";
    $cmd .= " --no-pre-code ";
    $cmd .= " --no-detail ";
    $cmd .= " --out-file $r-MINI-DETAIL ";
    $cmd .= " --run $runs->{$r}";
    $cmd .= " --html-out ";
    print "$cmd\n";
    system( $cmd );

    $cmd = "./f1-predictor.pl ";
    $cmd .= " --out-sub-dir bill ";
    $cmd .= " $o_method ";
    $cmd .= " --fia ";
    $cmd .= " $o_fia_sprint_qual_diff ";
    $cmd .= " --suppress-average-table ";
    $cmd .= " --no-pre-code ";
    $cmd .= " --out-file $r-DETAILED ";
    $cmd .= " --run $runs->{$r}";
    $cmd .= " --html-out ";
    print "$cmd\n";
    system( $cmd );


    $cmd = "./f1-predictor.pl ";
    $cmd .= " --out-sub-dir bill ";
    $cmd .= " $o_method ";
    $cmd .= " --fia ";
    $cmd .= " $o_fia_sprint_qual_diff ";
    $cmd .= " --suppress-average-table ";
    $cmd .= " --no-pre-code ";
    $cmd .= " --out-file $r-DETAILED-RATING ";
    $cmd .= " --closest-p1-20-details ";
    $cmd .= " --no-prediction-detail ";
    $cmd .= " --run $runs->{$r}";
    $cmd .= " --html-out ";
    print "$cmd\n";
    system( $cmd );


    $cmd = "./f1-predictor.pl ";
    $cmd .= " --out-sub-dir bill ";
    $cmd .= " $o_method ";
    $cmd .= " --fia ";
    $cmd .= " $o_fia_sprint_qual_diff ";
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

