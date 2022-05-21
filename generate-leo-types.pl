#!/usr/bin/perl
use strict;use warnings;
use FindBin;
use lib "$FindBin::RealBin/.";
use GenerateRaces;
my $runs = $GenerateRaces::RUNS;
for my $r (keys %$runs){
    next if $r ne "ALL";
    my $cmd = "./f1-predictor.pl ";
    $cmd .= " --out-sub-dir leo ";
    $cmd .= " --out-file $r ";
    $cmd .= " --closest-p1-20 ";
    $cmd .= " --no-detail ";
    $cmd .= " --no-pre-code ";
    # $cmd .= " --show-winners-summary ";
    $cmd .= " --suppress-totals ";
    # $cmd .= " --show-p1-to-p10-totals ";
    $cmd .= " --run $runs->{$r}";
    print "$cmd\n";
    system( $cmd ) ;

#    $cmd = "./f1-predictor.pl ";
#    $cmd .= " --out-sub-dir leo ";
#    $cmd .= " --out-file $r-DETAILED ";
#    $cmd .= " --closest-p1-20 ";
#    $cmd .= " --closest-p1-20-details ";
#    $cmd .= " --no-detail ";
#    $cmd .= " --no-prediction-detail ";
#    $cmd .= " --no-pre-code ";
#    #$cmd .= " --show-winners-summary ";
#    $cmd .= " --show-p1-to-p10-totals ";
#    $cmd .= " --run $runs->{$r}";
#    print "$cmd\n";
#    system( $cmd ) ;

}
