#!/usr/bin/perl
use strict; use warnings;
use Data::Dumper;
use Try::Tiny;
use Scalar::Util qw(looks_like_number);
use Math::BigInt;
use Number::Format;

sub true {1}
sub false {0}

# FIXED constants.
my $DATA_DIR = "./";
my $ZDATA_DRIVERS       = 'zdata.drivers';
my $ZDATA_CONSTRUCTORS  = 'zdata.constructors';
my $ZDATA_RACES         = 'zdata.races';
my $ZDATA_PLAYERS       = 'zdata.players';

sub dierr {
    my ($msg) = @_;
    $msg = "ERROR $msg" ;
    die "\n$msg\n";
}

# These are -1 out, so 0 is really P1 !!! :
my $real_f1_pos_scores = {
    0 => 25,
    1 => 18,
    2 => 15,
    3 => 12,
    4 => 10,
    5 => 8,
    6 => 6,
    7 => 4,
    8 => 2,
    9 => 1,
};

# These are -1 out, so 0 is really P1 !!! :
my $real_1990_f1_pos_scores = {
    0 => 9,
    1 => 6,
    2 => 4,
    3 => 3,
    4 => 2,
    5 => 1,
};


# These are -1 out, so 0 is really P1 !!! :
# This is basically 100^(pos-6)
# I guess I could just do it in a sum.
# But a hash map keeps it to the first 6 places.
# We're only doing P1 -> P6 predictions.
my $power_hundred_score_multiplier = {
#   0 => 1,00,00,00,00,00,
    0 => 10000000000,
    1 => 100000000,
    2 => 1000000,
    3 => 10000,
    4 => 100,
    5 => 1,
};

sub usage {
    my ($msg) = @_;

    $msg //= "";

    die <<EOUSAGE;

$msg

################################################
Options :

    --score-only-up-to-pos  with integer from 1 to 20 for drivers
        or 1 to 10 for constructors.
        (will take account of the --drivers-count, and
            --constructors-count params)

        i.e. --score-only-up-to-position  5
            would only score the top 5 places for where they are.

        since we are only doing first six positions then this defaults to 6 in the code.
        and the player files with the lines of predictions must only have 6 lines.

    --score-sys  karl-8, karl-32 , differential_scoring, diff
        defaults to differential_scoring

        diff and differential_scoring are the same thing.

        i.e.
        --score-sys karl-8
            would run the 8,4,2,1 scoring system.

        --score-sys karl-32
            would run the 32-16-8-4-2-1 Karl systems.

    --score-times-current
        This multiplies the score for
            P1 prediction by 25
            P2 prediction by 18
            P3 prediction by 15
            ... (you know these numbers !!)
            P10 prediction by 1

    --score-times-1990  (1990 ish scoring system)
        This multiplies the score for
            P1 x 9
            P2 x 6
            P3 x 4
            P4 x 3
            P5 x 2
            P6 x 1

    --score-times-power-of-100
            basically for the top 6 postions
            (This script is kind of becoming a top-6-only-predictor)
            it is :
            Pos - 6 ^ 100
            Where Pos is the Position of the Prediction. So for P1 prediction
            ( 6-1 ) ^ 100

    --minus-points.
        So for a JOKE. If there's a driver or constructor who's deemed to be
        "annoying" , their names can be put on this option in a comma
        separated list.
        The full lookup names should work, although joke names with a \$
        will need quoting or they will not work via the command line.

        i.e. --minus-points STR,HAM,MAG,VER,LEC

        if any player has those predictions, they get MINUS points :-D

        (TO BE IMPLEMENTED)

    --multi-points.
        So for a JOKE. If there's a driver or constructor who's deemed to be
        "awesome" , their names can be put on this option in a comma
        separated list.
        The full lookup names should work, although joke names with a \$
        will need quoting or they will not work via the command line.

        i.e. --multi-points STR,HAM,MAG,VER,LEC

        if any player has those predictions, they get points multiplied :-D

        They will be multiplied by the --multi-point-factor, which defaults to 2.

        although I guess you could multiply by 0.1 or -3 and use this option
        to reduce scores for certain driver predictions.

        (TO BE IMPLEMENTED)

    --multi-points-factor 2 , 3 , 2.5 , whatever you like !
        This is used in conjunction with the --multi-points JOKE option.


    --full-output
        don't know what I put this is for !

    --tab-output
        prints out nice at the command line.

    --html-output
        generates html table output
        (NOT YET WRITTEN)

    --run  wdc, wcc , race-name

    --drivers-count. This defaults to 20
        the current amount on the 2022 grid.
        so you shouldn't have to set it.
        unless the numbers of drivers on the grid changes.

    --constructors-count . This defaults to 10
        the current amount on the 2022 grid.
        so you shouldn't have to set it.
        unless the numbers of constructors on the grid changes.

    --pad-results
        puts spaces in to line up the results.

    See README file for full explanation of files in the directory.

    Questions to answer.
        substitute drivers ? just ignore them ?

EOUSAGE
}

use Getopt::Long;

my $score_sys_lkup = {
    "karl-8"     => 1,
    "karl-32"    => 1,
    differential_scoring => 1,
};

my $o_drivers_count       = 20;
my $o_constructors_count  = 10;

my $o_score_upto_pos = 6;

my ( $o_score_sys, $o_score_times_pos, $o_score_times_1990_pos);
my ( $o_score_times_power_hundred );
my ($o_full_output, $o_tab_output, $o_html_output);
my ($o_run, $o_help, $o_debug);
my ($o_pad_results);
my ($o_minus_points, $o_multi_points);
my $o_multi_points_factor = 2;

GetOptions (
    "pad-results"           => \$o_pad_results,
    "score-only-upto-pos=i" => \$o_score_upto_pos,
    "score-times-current"   => \$o_score_times_pos,
    "score-times-1990"      => \$o_score_times_1990_pos,
    "score-times-power-100" => \$o_score_times_power_hundred,
    "minus-points=s"        => \$o_minus_points,
    "multi-points=s"        => \$o_multi_points,
    "multi-points-factor=s" => \$o_multi_points_factor,
    "score-sys=s"           => \$o_score_sys,
    "full-output"           => \$o_full_output,
    "tab-output"            => \$o_tab_output,
    "html-output"           => \$o_html_output,
    "drivers-count=i"       => \$o_drivers_count,
    "constructors-count=i"  => \$o_constructors_count,
    "run=s"                 => \$o_run,
    "h|help"                => \$o_help,
    "debug"                 => \$o_debug,
) or usage();

usage() if $o_help;

if ( ! looks_like_number $o_multi_points_factor ){
    die "--multi-points-factor $o_multi_points_factor does not look like a number\n";
}

my $z_races   = z_data_single($ZDATA_RACES);
print "Dump of races = ".Dumper($z_races) if $o_debug;

my $z_players = z_data_single($ZDATA_PLAYERS);
print "Dump of players = ".Dumper($z_players) if $o_debug;

my $z_drivers = z_data_pipe_split($ZDATA_DRIVERS);
print "Dump of drivers = ".Dumper($z_drivers) if $o_debug;

# Only works on drivers. Doesn't seem much point on WCC
my $z_minus_points = {};
if ($o_minus_points){

    for my $mpdrv ( split /,/,$o_minus_points){
        $mpdrv = uc(trim($mpdrv));

        if ( ! exists $z_drivers->{$mpdrv} ){
            die "The --minus-points driver name of [$mpdrv] can't be found\n";
        }

        $z_minus_points->{$z_drivers->{$mpdrv}} = 1;
    }
    print "Dump of minus_points_driver lookup \n".Dumper($z_minus_points)
        if $o_debug;
}

# Only works on drivers. Doesn't seem much point on WCC
my $z_multi_points = {};
if ($o_multi_points){
    for my $mpdrv ( split /,/,$o_multi_points){
        $mpdrv = uc(trim($mpdrv));

        if ( ! exists $z_drivers->{$mpdrv} ){
            die "The --multi-points driver name of [$mpdrv] can't be found\n";
        }

        $z_multi_points->{$z_drivers->{$mpdrv}} = 1;
    }
    print "Dump of multi_points_driver lookup \n".Dumper($z_multi_points)
        if $o_debug;
}

my $z_constructors = z_data_pipe_split($ZDATA_CONSTRUCTORS);
print "Dump of constructors = ".Dumper($z_constructors) if $o_debug;

print "constructors count  = $o_constructors_count\n" if $o_debug;
print "drivers count       = $o_drivers_count\n" if $o_debug;

if (!$o_run) {
    dierr("You must define --run , with wcc , wdc or the race-name");
}

$o_score_sys = "differential_scoring" if ! $o_score_sys || $o_score_sys eq "diff";
if ( ! exists $score_sys_lkup->{$o_score_sys} ){
    dierr("[--score-sys $o_score_sys] isn't valid\n");
}

if ($o_drivers_count < 2){
    dierr("[--drivers-count $o_drivers_count] needs to be more than 2!");
}

if ($o_constructors_count < 2){
    dierr("[--constructors-count $o_constructors_count] needs to be more than 2!");
}

if ( $o_tab_output && $o_html_output ){
    dierr("you can't define both [--tab-output --html-output] only one or the other");
}

sub main {
    my $plyr_tots = {};
    my $run_arrs = [];

    for my $s_run ( split /,/ , $o_run ){

        $s_run =~ s/^\s*//g;
        $s_run =~ s/\s*$//g;

        if ($s_run ne 'wcc' && $s_run ne 'wdc' && ! exists $z_races->{$s_run}){
            dierr("[--run $s_run] is not valid. You must define --run , with wcc , wdc or a valid race-name");
        }

        if ( defined $o_score_upto_pos ){
            my $cmp_tot = expected_count($s_run);

            if ( $o_score_upto_pos < 1 or $o_score_upto_pos > $cmp_tot){
                dierr("For [--run $o_run] you cannot define a [--score-only-upto-pos of $o_score_upto_pos], the max is $cmp_tot\n");
            }
        } else {
            $o_score_upto_pos = expected_count($s_run);
        }
        print "score_upto_pos      = $o_score_upto_pos\n" if $o_debug;

        my $plyr_res = process($s_run);

        push @$run_arrs, $plyr_res;
    }

    print "\n\n\n";
    print "##############################################################\n";
    print "OUTPUT Section\n";
    print "##############################################################\n";

    if ($o_minus_points || $o_multi_points  ) {
        print "This is a JOKE table, with silly factors applied to certain driver predictions\n\n";

        if ($o_minus_points) {
            print "The predictions for driver(s) ".join(", ", keys %$z_minus_points)." score negative points\n";
        }

        if ($o_multi_points) {
            print "The predictions for driver(s) ".join(", ", keys %$z_multi_points)." have score multiplied by $o_multi_points_factor\n";
        }

        print "\n";

    } else {
        print "This is a REAL table (no Karl fiddle factors applied)\n\n";
    }

    print "Code and data is pushed to https://github.com/kaptainkarl/f1-predictor for those that want to check that kind of thing !\n";


    print "'zzz' is an imaginary player who got a perfect score , so who's really winning is the line after 'zzz'\n\n" if exists $z_players->{zzz};

    if ( $o_score_sys eq "karl-8") {
        print "Scoring is Karl's crazy 8, 4, 2, 1 \n";
        print "Get the position exactly correct then 8 points\n";
        print "Get the position 3 places out then 1 point\n";
        print "More than 3 places out, then 0 points \n";
    }
    elsif ( $o_score_sys eq "karl-32" ) {
        print "\nKarl-32,16,8,4,2,1 scoring . i.e Postion exactly correct 32 points.\n";
        print " if 5 places out then 1 point\n";
    }
    elsif ( $o_score_sys eq "differential_scoring" ) {
        print "Differential scoring . i.e. Get a prediction exactly correct then it is \n";
        print " 20 - 0 = 20 points\n";
    }
    print "\n";
    if ($o_score_times_power_hundred){
        print "Positional Scores are multiplied by HUGE numbers ...\n";
        print "P1 is multiplied by 10000000000\n";
        print "then 100 times less for each position. until ...\n";
        print "P5 is times 100 and P6 is times 1\n";
        print "Basically, P1 accuracy trumps P2->P6 accuracy\n";
        print "and P2 accuracy trumps P3->P6 accuracy, etc ...\n";
        print "In the individual rounds the Positional score in the table shows\n";
        print "the score BEFORE the multiplier\n";
        print "The 'Total' has a comma to separate HUNDREDs (and not the usual Thousands)\n";
        print "Thus you can easily see the Positional scores in the Total\n";
        print "The most accurate P1 wins, ALWAYS\n\n";
        print "In the Totals table you just see the HUGE Numbers\n";
        print "I hope this makes sense, even my eyes are GLAZING over !\n";
    }
    elsif ($o_score_times_pos) {
        print "Scores are multiplied by 25,18,15,12 ... depending on the position\n";
    }
    elsif ($o_score_times_1990_pos) {
        print "Scores are multiplied by 9,6,4,3,2,1  depending on the position\n";
    }
    else {
        print "Scores are NOT multiplied depending on the position\n";
    }

    print "\nindividual rounds ...\n\n";
    my $max_p_pos = 6; # used for classifying winning by the first 6 positions.

    for my $pr_run (@$run_arrs) {
        for my $ln (@$pr_run){
            my $pos = $ln->{pos};
            print pp($pos).$ln->{output};

            die "unknown player . prog error \n" if ! $ln->{player};
            my $plyr = $ln->{player};

            $plyr_tots->{$plyr}{player} = $plyr;

            $plyr_tots->{$plyr}{"p$pos"}++;

            $plyr_tots->{$plyr}{total} = $plyr_tots->{$plyr}{total}   // 0;
            $plyr_tots->{$plyr}{played} = $plyr_tots->{$plyr}{played} // 0;

            $plyr_tots->{$plyr}{total} += $ln->{score};
            $plyr_tots->{$plyr}{played} ++ if ! $ln->{skipped};

        }
        print "\n\n";
    }

    if (@$run_arrs <2){
        print "\nonly run for one round, not showing totals\n";
        return;
    }

    print "##############################################################\n";
    print "Tables run for ". join(", ", split (",", $o_run))."\n\n";
    print "Total Score table\n";
    print "-----------------\n";

    my $tots_arr = [];

    for my $tpname ( keys %$plyr_tots ){
        my $tp = $plyr_tots->{$tpname};

        if ( $tp->{played}){
            $tp->{ave_score} = sprintf ( "%0.2f", $tp->{total} / $tp->{played});
        } else {
            $tp->{ave_score} = 0;
        }

        for my $p_pos ( 1..$max_p_pos ){
            # fill in the pNUM hash keys that are undef with 0;
            $tp->{"p$p_pos"} = $tp->{"p$p_pos"} // 0;
        }

        push @$tots_arr, $tp;
    }

    print Dumper $plyr_tots if $o_debug;
    print Dumper $tots_arr if $o_debug;

    my $pp = 1;
    for my $tl (sort { $b->{total} <=> $a->{total} } @$tots_arr ){
        totals_pad($pp, $tl, "total", false);
        $pp++;
    }

    print "\nSo for players who might not have entered predictions for all rounds an Average Score table\n";
    print   "--------------------\n";
    $pp = 1;
    for my $tl (sort { $b->{ave_score} <=> $a->{ave_score} } @$tots_arr ){
        totals_pad($pp, $tl, "ave_score", false);
        $pp++;
    }

    print "\n\nSo following table is for those who think P1 is the most important metric\n";
    print "This is sorted by the Position in the rounds P1->P6 and then the Average Score\n";
    print "i.e. The most P1s wins, if that's all level then P2s .... finally to ave-score as a tie break\n";
    print "So to get a P1 a player needed to win in the table calculated for the specific round (see above)\n";
    print   "--------------------\n";
    $pp = 1;
    for my $tl (sort {
                $b->{p1} <=> $a->{p1} ||
                $b->{p2} <=> $a->{p2} ||
                $b->{p3} <=> $a->{p3} ||
                $b->{p4} <=> $a->{p4} ||
                $b->{p5} <=> $a->{p5} ||
                $b->{p6} <=> $a->{p6} ||
                $b->{ave_score} <=> $a->{ave_score}

            } @$tots_arr
    ){
        totals_pad($pp, $tl, "ave_score", true);
        $pp++;
    }

}
#################################
#################################
#################################
#################################
# subs
sub thousands ($){
    my ($sc) = @_;

    return $sc if ! $o_score_times_power_hundred ;

    my $b = reverse int($sc);
    my @c = unpack("(A3)*", $b);
    my $d = join ',', @c;
    my $e = reverse $d;
    return $e;
}
sub hundreds ($){
    my ($sc) = @_;

    return $sc if ! $o_score_times_power_hundred ;

    my $b = reverse $sc;
    my @c = unpack("(A2)*", $b);
    my $d = join ',', @c;
    my $e = reverse $d;
    return $e;
}

sub totals_pad {
    my ($p, $tl, $score_key, $add_ppos) = @_;

    my $ppos_parts = "";

    $ppos_parts = ": P1=$tl->{p1} : P2=$tl->{p2} : P3=$tl->{p3} : P4=$tl->{p4} : P5=$tl->{p5} : P6=$tl->{p6}"
        if $add_ppos;

    my $score_text = $score_key;

    if ($o_pad_results) {
        printf( "P%-2s : %-10s : played=%-2s %s : %s = %s\n", $p, $tl->{player}, $tl->{played} , $ppos_parts, $score_text, thousands($tl->{$score_key}) );
    } else {
        printf( "P%s : %s : played=%s %s : %s = %s\n", $p, $tl->{player}, $tl->{played} , $ppos_parts, $score_text, thousands($tl->{$score_key}) );
    }
}

sub pp ($) {
    my ($p) = @_;
    return sprintf("P%-2s : ", $p);
}

sub expected_count ($) {
    my ($s_run) = @_;
    return $s_run eq 'wcc' ?  $o_constructors_count : $o_drivers_count ;
}

sub z_drivers_or_constructors ($) {
    my ($s_run) = @_;

    if (($o_minus_points || $o_multi_points )
         && $s_run eq 'wcc'
    ){
        die "the options --minus-points or --multi-points can't be used with --run wcc\n";
    }

    return $s_run eq 'wcc' ?  $z_constructors : $z_drivers;
}

sub z_drivers_or_constructors_file ($) {
    my ($s_run) = @_;
    return $s_run eq 'wcc' ?  $ZDATA_CONSTRUCTORS : $ZDATA_DRIVERS;
}

sub process ($) {

    my ($s_run) = @_;

    print "##################\n";
    print "$s_run processing ...\n\n";

    # is it driver or constructor ?
    # races are only driver.

    my $exp_tot = expected_count($s_run);

    my $file_results = "$s_run.results";

    my $results = run_file($file_results);

    print "$s_run : Results are ".Dumper($results) if $o_debug;

    my $results_lkup = { } ;
    for (my $i=0; $i<$exp_tot; $i++){
        my $resname = uc($results->[$i]);

        if ( ! exists z_drivers_or_constructors($s_run)->{$resname} ){
            die "Can't find [$resname] from [$file_results] in file [".z_drivers_or_constructors_file($s_run)."]\n";
        }

        $results_lkup->{z_drivers_or_constructors($s_run)->{$resname}}=$i;

    }
    print "$s_run : Results Lookup is ".Dumper($results_lkup) if $o_debug;

    if (scalar @$results != $exp_tot){
        die "The results file [$file_results] has [".scalar @$results."] rows and not [$exp_tot]\n";
    }

    my @skip_player_errs = ();
    my $player_results_arr = [];

    my $all_players_data = get_all_players_data($s_run);

PLYR:
    for my $plyr (sort keys %$z_players){
        print "$s_run : Processing Player $plyr\n";
        my $result_line;
        if ($o_pad_results) {
            $result_line =  sprintf( "%s : %-10s : ", $s_run, $plyr );
        } else {
            $result_line =  sprintf( "%s : %s : ",  $s_run, $plyr );
        }
        my $plyr_tot_score = Math::BigInt->bzero();

        my $skip_result_line = sub {
            my ($skip_reason) = @_;
            $skip_reason //= "";

            push @$player_results_arr ,
                {score => 0, player=>$plyr , output => "${result_line}${skip_reason} : Tot = 0\n", skipped=>1};
        };


        if ( ! exists $all_players_data->{$plyr} ){
            push @skip_player_errs,
                "$s_run : Skip [$plyr] no data in $s_run.all-players file";
            $skip_result_line->("no data (A)");
            next ;
        }

        my $plyr_data = $all_players_data->{$plyr};


        print "$s_run : $plyr : ".Dumper($plyr_data) if $o_debug;

        if (scalar @$plyr_data < $o_score_upto_pos){
            push @skip_player_errs,
                "$s_run : Skip [$plyr] because [".scalar @$plyr_data."] lines in file [".all_player_file($s_run)."] isn't [$o_score_upto_pos]";
            $skip_result_line->("no data (B)");
            next;
        }

        for (my $i=0; $i<$o_score_upto_pos; $i++){

            my $plyr_pred = uc($plyr_data->[$i]);
            if ( ! exists z_drivers_or_constructors($s_run)->{$plyr_pred} ){
                push @skip_player_errs,
                    "$s_run : Skip [$plyr] because prediction [".
                        ($i+1)."][$plyr_pred] in file [".all_player_file($s_run)."] not found in [".z_drivers_or_constructors_file($s_run)."]";

                $skip_result_line->("no data (C)");
                next PLYR;
            }
            # get the 3 char abbrieviation :
            $plyr_pred = z_drivers_or_constructors($s_run)->{$plyr_pred} ;

            my $add_result = sub ($$$){
                my ($pred, $real_score, $disp_hundred_score) = @_;

                $plyr_tot_score += $real_score;

                my $score = $o_score_times_power_hundred ? $disp_hundred_score : $real_score;

                if ($o_pad_results) {
                    $result_line .= sprintf("%s (%3s), ", $pred, $score);
                }else{
                    $result_line .= sprintf("%s (%s), ", $pred, $score);
                }

            };

            if ( ! exists $results_lkup->{$plyr_pred}){
                # This is a programming error.
                # die "The lookup \$results_lkup->{$plyr_pred} []should work. Programmng error"."\n";

                print "$s_run : $plyr : ".($i+1)." $plyr_pred  (0)\n" if $o_debug;
                $add_result->($plyr_pred,0);

            } else {

                my $error = abs($results_lkup->{$plyr_pred}-$i);

                my $score = Math::BigInt->bzero();;

                if ( $o_score_sys eq "karl-8") {
                    if ( $error <= 3){
                        $score = 2 ** (3-$error) ;
                    }
                } elsif ( $o_score_sys eq "karl-32" ) {
                    if ( $error <= 5){
                        $score = 2 ** (5-$error) ;
                    }
                } elsif ( $o_score_sys eq "differential_scoring" ) {
                    $score = $o_drivers_count-$error;
                }

                if (exists $z_minus_points->{$plyr_pred}){
                    $score = -$score;
                }

                if (exists $z_multi_points->{$plyr_pred}){
                    $score = $score * $o_multi_points_factor ;
                }


                my $display_hundreds_score = $score;
                if ($o_score_times_power_hundred){
                    $score = $score * $power_hundred_score_multiplier->{$i}
                } elsif ($o_score_times_pos){
                    $score = $score * $real_f1_pos_scores->{$i}
                }
                elsif ($o_score_times_1990_pos) {
                    $score = $score * $real_1990_f1_pos_scores->{$i}
                }


                print "$s_run : $plyr : ".($i+1)." $plyr_pred  : error $error : score ".int($score)."\n" if $o_debug;
                $add_result->($plyr_pred, $score, $display_hundreds_score);
            }
        }

        $result_line =~ s/, $//g;

        if ($o_pad_results) {
            $result_line .= sprintf( " : Tot = %4s\n", hundreds($plyr_tot_score) );
        } else {
            $result_line .= sprintf( " : Tot = %s\n", hundreds($plyr_tot_score) );
        }

        print "$s_run : $result_line" if $o_debug;

        push @$player_results_arr , {score => $plyr_tot_score, player=>$plyr , output => $result_line};
    }

    my @plyr_ordered_res =  sort { $b->{score} <=> $a->{score} } @$player_results_arr;

    my $last_diff_score;
    my $last_diff_score_highest_pos;

    for ( my $i=0; $i < scalar @plyr_ordered_res; $i++ ){
        my $plyr_rh = $plyr_ordered_res[$i];
        if ( $i == 0 ){

            $plyr_rh->{pos} = $i+1;
            $last_diff_score = $plyr_rh->{score};
            $last_diff_score_highest_pos = $i;
            next;
        }
        elsif ( $plyr_rh->{score} == $last_diff_score ){
            $plyr_rh->{pos} = $last_diff_score_highest_pos+1;
        }
        else {
            $plyr_rh->{pos} = $i+1;
            $last_diff_score = $plyr_rh->{score};
            $last_diff_score_highest_pos = $i;
        }
    }

    #for my $ln (@plyr_ordered_res){
    #    print "$s_run : $ln->{output}";
    #}

    print "$s_run : Skipped players due to errors : \n  ".join("\n  ",@skip_player_errs)."\n"
        if @skip_player_errs;

    return \@plyr_ordered_res;
}

sub z_data_pipe_split {
    my ($file)  = @_;

    # splits full name on spaces.
    # shoves in hash
    # checks for duplicates
    # if no duplicates then can match on any part of name.
    # if duplicates can then only match on full name or 3 character abbrieviation.
    # it's a fatal error if the 3 char abbrieviation or the driver's fullname
    # isn't unique.

    # probably best for names to use standard latin
    # characters without accents, circumflexes, umlauts etc ...
    # (UTF-8 characters and other encodings cause all sorts of mismatch issues)

    my $data = slurp($file);

    my $cfg = {};

    for my $ln (split /\n/, $data){
        $ln =  trim($ln);
        next if ! $ln;

        my @sp = split /\|/, $ln;

        die "In file [$file], line :\n$ln\ndoesn't split into only 2 parts via a pipe\n" if scalar @sp != 2;

        my $dref = trim($sp[0]);
        if (length $dref != 3){
            die "Unique 3-char ref for [$dref] isn't 3 characters long\n";
        }

        my $names = [];
        for my $comma_split (split /,/, trim($sp[1])){
            push @$names, trim($comma_split);
        }

        $cfg->{$dref} = $names;
    }

    # dedup in the case of Hamilton
    #   is :
    #       $dedup->{"HAM"} => "HAM"
    #       $dedup->{"LEWIS"} => "HAM"
    #       $dedup->{"HAMILTON"} => "HAM"
    #       $dedup->{"LEWIS HAMILTON"} => "HAM"

    my $dedup = {};
    my $dedup_part_names = {};

    for my $dref ( keys %$cfg ){
        if ( exists $dedup->{$dref} ){
            die "Unique 3 char ref [$dref] is duplicated\n";
        }
        $dedup->{$dref} = $dref;

        for my $fullname (@{$cfg->{$dref}}){
            my $fullname = uc($fullname);


            if ( exists $dedup->{$fullname} && $dedup->{$fullname} ne $dref ){
                die "fullname of [$fullname] is duplicated\n";
            }
            $dedup->{$fullname} = $dref;

            my @splitname = split /\s+/, $fullname;
            for my $npart ( @splitname ){

                if (  exists $dedup->{$npart} && $dedup->{$npart} ne $dref ){
                    die "part name of [$fullname] is duplicated over different drivers\n";
                }

                if ( exists $dedup_part_names->{$npart} && $dedup_part_names->{$npart} ne $dref) {
                    die "part name of [$fullname] is duplicated over different drivers\n";
                }

                $dedup_part_names->{$npart} = $dref;
            }
        }
    }

    for my $pr (keys %$dedup_part_names) {
        $dedup->{$pr} = $dedup_part_names->{$pr};
    }

    return $dedup;
}

sub slurp {
    my ( $file ) = @_;
    open( my $fh, $file ) or die "Can't open file $file $!\n";
    my $text = do { local( $/ ) ; <$fh> } ;
    return $text;
}

sub burp {
    my( $file_name ) = shift ;
    open( my $fh, ">" , $file_name ) || die "Can't create $file_name $!" ;
    print $fh @_ ;
}

sub z_data_single {
    my ($file) = @_;

    my $data = slurp($file);

    my $ret = {};

    for my $ln (split /\n/, $data){
        $ln =  trim($ln);
        next if ! $ln;

        if ($ln !~ /^[a-z0-9_-]+$/){
            die  "$ln in file $file doesn't match a-z (lowercase only), 0-9 , hyphen, underscore only format\n";
        }

        $ret->{$ln} = 1;
    }
    return $ret;
}

sub run_file {
    my ($file) = @_;

    my $data = slurp($file);

    my $ret = [];

    for my $ln (split /\n/, $data){
        $ln =  trim($ln);
        next if ! $ln;

        push @$ret, $ln;
    }
    return $ret;
}

sub trim {
    my ($txt) = @_;
    $txt =~ s/^\s+//g;
    $txt =~ s/\s+$//g;
    return $txt;
}

sub get_all_players_data($) {
    my ($s_run) = @_;

    my $all_player_filename =all_player_file($s_run);
    my $filedata = slurp($all_player_filename);

    my $plyr_data = {};

    for my $ln (split /\n/, $filedata){
        $ln =  trim($ln);
        next if ! $ln;

        if ( my ($plyr, $preds) = $ln =~ m{(.*?):(.*)} ){

            $plyr = lc(trim($plyr));

            if ( ! exists $z_players->{$plyr} ){
                die "Can't find player [$plyr] in [$all_player_filename]\n";
            }

            if ( exists $plyr_data->{$plyr} ){
                die "Player [$plyr] has duplicate entries in [$all_player_filename]\n";

            }

            my $p_preds_arr = [
                map { uc(trim ($_)) }
                split ("," ,$preds )
            ];


            my $dup_preds = {};

            for my $pr ( @$p_preds_arr ){
                if ( ! exists z_drivers_or_constructors($s_run)->{$pr} ){
                    die "The prediction [$pr] for player [$plyr] ".
                        " in the file $all_player_filename can't be found\n";
                }

                $pr = z_drivers_or_constructors($s_run)->{$pr};

                if ( exists $dup_preds->{$pr}){
                    die "The prediction [$pr] for player [$plyr] ".
                        " in the file $all_player_filename is duplicated\n";
                }
                $dup_preds->{$pr} = 1;
            }

            $plyr_data->{$plyr} = $p_preds_arr;
        } else {
            die "Can't split line [$ln] in $all_player_filename\n";
        }
    }

    print "Dump of player data from  $all_player_filename\n : ".Dumper ( $plyr_data ) if $o_debug;

    return $plyr_data;
}

sub all_player_file ($) { return "$_[0].all-players" }

main();
