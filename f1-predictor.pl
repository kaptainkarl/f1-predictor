#!/usr/bin/perl
use strict; use warnings;
use Data::Dumper;
use Try::Tiny;
use Scalar::Util qw(looks_like_number);
use Math::BigInt;
use Number::Format;

sub true {1}
sub false {0}

# Temporary hack before it ends up in config

my $season = 2022;
my $this_output_dir="./output/$season/";
if ( ! -d $this_output_dir) {
    die "Can't find output dir $this_output_dir\n";
}
my $this_season_dir="./data/$season/";
chdir $this_season_dir or die "Can't chdir to $this_season_dir \n";

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

my $o_suppress_rounds_tables;
sub printoutrnd ($){
    return if $o_suppress_rounds_tables;
    print $_[0];
}

sub printout ($){
    print $_[0];
}

my $o_debug = 0;
sub prdebug ($$) {
    my ($out, $level) = @_;
    print $out if $o_debug > $level;
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

    --leo
        this is a set of scoring CLI options short cut.
        
        It sets the --score-sys to 'exact'
        and --score-times-power-of-100

        it undefs --score-times-current
                  --score-times-1990

        Basically it is a short cut to how I think Leo
        wants the predictions rated.

    --score-sys  karl-8, karl-32 , differential_scoring, diff, exact
        defaults to differential_scoring

        diff and differential_scoring are the same thing.

        i.e.
        --score-sys karl-8
            would run the 8,4,2,1 scoring system.

        --score-sys karl-32
            would run the 32-16-8-4-2-1 Karl systems.

        --score-sys exact
            a single point is only awarded to an exactly
            correction prediction.


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

    --multi-points-factor 2 , 3 , 2.5 , whatever you like !
        This is used in conjunction with the --multi-points JOKE option.

    --player-fia-score
        Instead of adding up the underlying alogithm ranking score for sorting the
        positions , the positions of the players is mapped against proper F1 scoring in 2022
        i.e. P1 player get 25 points and so on .

    --player-rating-score
        Displays the rating score in individual rounds and 
        the totals table.

        The average score table is a special case.
        that only makes sense with the underlying rating
        scoring. So it always does this option.

    if neither --player-fia-score or --player-rating-score are specified
    script defaults to --player-fia-score

    --no-pre-code
        This suppresses the </pre></code>
        that is useful for disqus formating of tables.

    --suppress-detail-score
        suppresses the position player scores of the round.

    --suppress-average-table
        suppresses the average table

    --suppress-totals
        suppresses the totals table

    --suppress-rounds
        suppresses the rounds output tables


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

    --debug .
        Defaults to 0
        --debug 1 shows minimal debug.
             2,3 a bit more ...

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
    exact => 1,
};

my $o_drivers_count       = 20;
my $o_constructors_count  = 10;

my $o_score_upto_pos = 6;

my ( $o_score_sys, $o_score_times_pos, $o_score_times_1990_pos);
my ( $o_score_times_power_hundred );
my ($o_html_output);
my ($o_run, $o_help);
my $o_suppress_detail_score;
my ($o_minus_points, $o_multi_points);
my $o_multi_points_factor = 2;
my $o_player_fia_score;
my $o_player_rating_score;
my $o_suppress_average_table;
my $o_score_leo;
my $o_disp_plyrs_upto_pos = 99999999;
my $o_suppress_totals_tables;
my $o_no_pre_code;

GetOptions (
    "score-only-upto-pos=i"  => \$o_score_upto_pos,
    "leo"                   => \$o_score_leo,
    "score-times-current"   => \$o_score_times_pos,
    "score-times-1990"      => \$o_score_times_1990_pos,
    "score-times-power-100" => \$o_score_times_power_hundred,
    "minus-points=s"        => \$o_minus_points,
    "multi-points=s"        => \$o_multi_points,
    "multi-points-factor=s" => \$o_multi_points_factor,
    "score-sys=s"           => \$o_score_sys,
    "html-output"           => \$o_html_output,

    # display type options >>

    "score|rating|player-rating-score"
                            => \$o_player_rating_score,
    "fia|player-fia-score"      => \$o_player_fia_score,

    "disp_players|display-players-upto=i" => \$o_disp_plyrs_upto_pos,

    "no-detail|suppress-detail-score"
                            => \$o_suppress_detail_score,
    "no-ave|suppress-average-table"
                            => \$o_suppress_average_table,

    "no-totals|suppress-totals"
                            => \$o_suppress_totals_tables,
    "no-rounds|suppress-rounds"
                            => \$o_suppress_rounds_tables,
    "no-pre-code"
                            => \$o_no_pre_code,

    #### << display type options

    "drivers-count=i"       => \$o_drivers_count,
    "constructors-count=i"  => \$o_constructors_count,
    "run=s"                 => \$o_run,
    "h|help"                => \$o_help,
    "debug=i"               => \$o_debug,
) or die "Option errors\n";

usage() if $o_help;

if ( ! looks_like_number $o_multi_points_factor ){
    die "--multi-points-factor $o_multi_points_factor does not look like a number\n";
}

if ($o_score_leo){
    $o_score_sys = "exact";
    $o_score_times_pos = undef;
    $o_score_times_1990_pos = undef;
    $o_score_times_power_hundred= 1;
}

my $z_races   = z_data_single($ZDATA_RACES);
prdebug( "Dump of races = ".Dumper($z_races), 2 );

my $z_players = z_data_single($ZDATA_PLAYERS);
prdebug( "Dump of players = ".Dumper($z_players),2 );

my $z_drivers = z_data_pipe_split($ZDATA_DRIVERS);
prdebug( "Dump of drivers = ".Dumper($z_drivers), 2 );

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
    prdebug ("Dump of minus_points_driver lookup \n".Dumper($z_minus_points),2);
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
    prdebug( "Dump of multi_points_driver lookup \n".Dumper($z_multi_points),2);
}

my $z_constructors = z_data_pipe_split($ZDATA_CONSTRUCTORS);
prdebug ( "Dump of constructors = ".Dumper($z_constructors),2);

prdebug("constructors count  = $o_constructors_count\n", 2 );
prdebug("drivers count       = $o_drivers_count\n", 2 );

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

sub main {
    my $plyr_tots = {};
    my $run_arrs = [];

    # get all the --run data 
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
        prdebug( "score_upto_pos = $o_score_upto_pos\n", 0);

        my $plyr_res = process($s_run);

        push @$run_arrs, $plyr_res;
    }

    prdebug("\n\n\n",0);
    prdebug("##############################################################\n",0);
    prdebug("OUTPUT Section\n",0);
    prdebug("##############################################################\n",0);


    if ($o_minus_points || $o_multi_points  ) {
        printout( "This is a JOKE table, with silly factors applied to certain driver predictions\n\n");

        if ($o_minus_points) {
            printout("The predictions for driver(s) ".join(", ", keys %$z_minus_points)." score negative points\n");
        }

        if ($o_multi_points) {
            printout("The predictions for driver(s) ".join(", ", keys %$z_multi_points)." have score multiplied by $o_multi_points_factor\n");
        }

        printout("\n");

    }

    printoutrnd( "\nIndividual rounds ...\n\n") if @$run_arrs >1 ;

    print("Rounds have been suppressed by CLI option\n") if $o_suppress_rounds_tables;

    my $max_p_pos = 6; # used for classifying winning by the first 6 positions.

    for my $pr_run (@$run_arrs) {
        pre_code_open();
        printoutrnd( "Scoring is '". get_scoring_type_out()."'\n");
        printoutrnd( "---------------\n");

        printoutrnd( $pr_run->[0]{round}."\n\n");

        # Header row
        my $underline = "-" x 15;
        printoutrnd( "P   Player     |");

        my  $fmt  ="%-".(length($pr_run->[0]{output})-1)."s";
        printoutrnd(sprintf ("$fmt","Details"));

        $underline .= ("-" x length($pr_run->[0]{output}));

        if ($o_player_fia_score) {
            printoutrnd(sprintf("|%4s   ",'FIA'));
            $underline .= "-" x 8;
        }

        if ($o_player_rating_score){
            if ($o_score_times_power_hundred){
                printoutrnd(sprintf( "|%18s", "score ")) ;
                $underline .= "-" x 19;
            }
            else {
                printoutrnd(sprintf( "|%7s", "score " ));
                $underline .= "-" x 8;
            }
        }

        printoutrnd ("\n");
        printoutrnd ("$underline\n");

        # Body rows :

        for my $ln (@$pr_run){

            my $pos = $ln->{pos};
            my $plyr = $ln->{player};
            die "unknown player . prog error \n" if ! $ln->{player};

            $plyr_tots->{$plyr}{player} = $plyr;

            $plyr_tots->{$plyr}{"p$pos"}++;

            $plyr_tots->{$plyr}{fia_total} = $plyr_tots->{$plyr}{fia_total} // 0;
            $plyr_tots->{$plyr}{total}     = $plyr_tots->{$plyr}{total}     // 0;
            $plyr_tots->{$plyr}{played}    = $plyr_tots->{$plyr}{played}    // 0;

            $plyr_tots->{$plyr}{fia_total} += $ln->{fia_score};
            $plyr_tots->{$plyr}{total}     += $ln->{score};
            $plyr_tots->{$plyr}{played} ++ if ! $ln->{skipped};

            next if $pos > $o_disp_plyrs_upto_pos;

            # Output section :
            if ($ln->{skipped}){
                printoutrnd(sprintf("    %-10s ",$plyr));
                printoutrnd($ln->{output}."\n");
                next;
            }

            printoutrnd(sprintf("P%-2s %-10s ",$pos, $plyr));

            printoutrnd($ln->{output});

            if ($o_player_fia_score) {
                my $fia_s = sprintf("%.2f",$ln->{fia_score});
                $fia_s =~ s/.00$/   /g;
                printoutrnd(sprintf("|%6s ",$fia_s));
            }

            if ($o_player_rating_score){
                if ($o_score_times_power_hundred){
                    printoutrnd(sprintf( "|%18s", hundreds($ln->{score})));
                }
                else {
                    printoutrnd(sprintf( "|%7s", $ln->{score}));
                }
            }

            printoutrnd ("\n");


        }
        printoutrnd ("\n\n");
        pre_code_close();
    }

    if (@$run_arrs <2){
        printout ( "</pre></code>\n\n" ) if ! $o_no_pre_code;
        printout ("\nonly run for one round, not showing totals\n");
        return;
    }

    if ($o_suppress_totals_tables){
        printout ( "</pre></code>\n\n" ) if ! $o_no_pre_code;
        print ("\nTotals have been suppress by CLI option\n");
        return;
    }

    printout ("----------------------\n");
    printout ("Tables run for ". join(", ", split (",", $o_run))."\n\n");


    my $tots_arr = [];

    for my $tpname ( keys %$plyr_tots ){
        my $tp = $plyr_tots->{$tpname};

        if ( $tp->{played}){
            #$tp->{ave_score} = sprintf ( "%0.2f", $tp->{total} / $tp->{played});
            $tp->{ave_score} =  $tp->{total} / $tp->{played};
        } else {
            $tp->{ave_score} = 0;
        }

        for my $p_pos ( 1..$max_p_pos ){
            # fill in the pNUM hash keys that are undef with 0;
            $tp->{"p$p_pos"} = $tp->{"p$p_pos"} // 0;
        }

        push @$tots_arr, $tp;
    }

    prdebug("plyr_tots : ".Dumper($plyr_tots),1);
    prdebug("tots_arr  : ".Dumper($tots_arr),1);


    # TODO if fia scoring is display this will need to sort by "fia_total";
    # Or maybe just generate another table.

    my $pp;
    if ($o_player_rating_score){
        pre_code_open();
        printout( "Scoring is '".get_scoring_type_out()."'\n");
        printout ("-----------------\n");
        printout ("Total Score table\n");
        printout ("-----------------\n");
        totals_header("Total", false, false);
        $pp = 1;
        for my $tl (sort { $b->{total} <=> $a->{total} } @$tots_arr ){
            totals_row($pp, $tl, "total", false, false);
            $pp++;
        }
        pre_code_close();
    }

    if ( $o_player_fia_score ){
        pre_code_open();
        printout( "Scoring is '".get_scoring_type_out()."'\n");
        printout ("---------------------\n");
        printout ("Total FIA Score table\n");
        printout ("---------------------\n");
        totals_header("FIA", false, true);
        $pp = 1;
        for my $tl (sort { $b->{fia_total} <=> $a->{fia_total} } @$tots_arr ){
            totals_row($pp, $tl, "fia_total", false, true);
            $pp++;
        }
        pre_code_close();
    }

    if ( !$o_suppress_average_table ){
        pre_code_open();
        printout( "Scoring is '".get_scoring_type_out()."'\n");
        printout ("-------------------------------------------\n");
        printout ("Average score\n");
        printout ("For players who have not entered all rounds\n");
        printout ("-------------------------------------------\n");
        totals_header("Ave Score", false, false);
        $pp = 1;
        for my $tl (sort { $b->{ave_score} <=> $a->{ave_score} } @$tots_arr ){
            totals_row($pp, $tl, "ave_score", false, false);
            $pp++;
        }
        pre_code_close();
    }

    pre_code_open();
    printout( "Scoring is '".get_scoring_type_out()."'\n");
    printout ("------------------------\n");
    printout ("P1->P6 then Total Score \n");
    printout ("------------------------\n");
    totals_header("Total", true, false);
    $pp = 1;
    for my $tl (sort {
                $b->{p1} <=> $a->{p1} ||
                $b->{p2} <=> $a->{p2} ||
                $b->{p3} <=> $a->{p3} ||
                $b->{p4} <=> $a->{p4} ||
                $b->{p5} <=> $a->{p5} ||
                $b->{p6} <=> $a->{p6} ||
                $b->{total} <=> $a->{total}

            } @$tots_arr
    ){
        totals_row($pp, $tl, "total", true, false);
        $pp++;
    }
    pre_code_close();

    print $this_output_dir.get_scoring_type_out_filename_root() ."\n";
}
#################################
#################################
#################################
#################################
# subs
sub thousands ($){
    my ($sc) = @_;
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

sub pre_code_open{
    printout ( "\n<pre><code>\n" ) if ! $o_no_pre_code;
}
sub pre_code_close{
    printout ( "\n</pre></code>\n" ) if ! $o_no_pre_code;
}

sub get_scoring_type_out() {

    my $type;

    if ( $o_score_sys eq "karl-8") {
        $type="karl-8";
    }
    elsif ( $o_score_sys eq "karl-32" ) {
        $type="karl-32";
    }
    elsif ( $o_score_sys eq "differential_scoring" ) {
        $type="diff";
    }
    elsif ( $o_score_sys eq "exact" ) {
        $type="exact";
    }

    if ($o_score_times_power_hundred){
        $type .= " and positions-times-power-one-hundred";
    }
    elsif ($o_score_times_pos) {
        $type .= " and positions-times-25-to-8";
    }
    elsif ($o_score_times_1990_pos) {
        $type .= " and positions-times-9-to-1";
    }
    else {
        $type .= " and no-multiplier";
    }

#    # Special case
#    if ( defined $o_score_sys
#        && $o_score_sys eq "exact"
#        && $o_score_times_power_hundred
#    ) {
#        $type = "Leo-sort ";
#    }

    return $type
}

sub get_scoring_type_out_filename_root() {

    my $type;

    if ( $o_score_sys eq "karl-8") {
        $type="karl-8";
    }
    elsif ( $o_score_sys eq "karl-32" ) {
        $type="karl-32";
    }
    elsif ( $o_score_sys eq "differential_scoring" ) {
        $type="diff";
    }
    elsif ( $o_score_sys eq "exact" ) {
        $type="exact";
    }

    if ($o_score_times_power_hundred){
        $type .= "-and-positions-times-power-one-hundred";
    }
    elsif ($o_score_times_pos) {
        $type .= "-and-positions-times-25-8";
    }
    elsif ($o_score_times_1990_pos) {
        $type .= "-and-positions-times-9-to-1";
    }
    else {
        $type .= "-and-positions-no-multiplier";
    }

    # Special case
    if ( defined $o_score_sys
        && $o_score_sys eq "exact"
        && $o_score_times_power_hundred
    ) {
        $type = "winner-takes-all-detailed";
    }
    return $type;
}

sub b($){
    my ($num) = @_;
    return $num ? $num : "";
}

sub totals_header {
    my ($score_key, $add_ppos, $is_fia) = @_;

    my $ppos_parts = $add_ppos ?"| P1 | P2 | P3 | P4 | P5 | P6 ":"";

    my $sc_wide = 14;
    if ( $is_fia ) {
        $sc_wide = 9;
    }
    elsif ( $o_score_times_power_hundred ){
        $sc_wide = 17;
    };

    my $underline = "---------------------";
    $underline .= "-" x length($ppos_parts);

    $underline .= "-" x ( $sc_wide + 4 );

    printout(sprintf( "P   Player    |Played%s|%${sc_wide}s\n", $ppos_parts, $score_key ));
    printout("$underline\n");

}

sub totals_row($$$$$) {
    my ($p, $tl, $score_key, $add_ppos, $is_fia) = @_;

    my $ppos_parts = $add_ppos ? sprintf("| %2s | %2s | %2s | %2s | %2s | %2s ", b($tl->{p1}), b($tl->{p2}), b($tl->{p3}),
                                                      b($tl->{p4}), b($tl->{p5}), b($tl->{p6}))
                                : "";

    my $score_text = $score_key;

    my $sc_wide = 14;
    if ( $is_fia ) {
        $sc_wide = 9;
    }
    elsif ( $o_score_times_power_hundred ){
        $sc_wide = 20;
    };

    my $scr_str;
    my $scr = sprintf( "%0.2f" , $tl->{$score_key});
    if ( my ($intg, $deci) = $scr =~ m/^(\d+)\.(\d+)$/ ){
        $scr_str =  thousands($intg).".$deci";
        $scr_str =~ s/\.00$/   /g;
    } else {
        die "Prog error . Can't split number in totals_row\n";
    }

    printout(sprintf( "P%-2s %-10s|%5s %s|%${sc_wide}s\n", $p, $tl->{player}, $tl->{played} , $ppos_parts, $scr_str));
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

    prdebug("##################\n",0);
    prdebug("$s_run processing ...\n\n",0);

    # is it driver or constructor ?
    # races are only driver.

    my $exp_tot = expected_count($s_run);

    my $file_results = "$s_run.results";

    my $results = run_file($file_results);

    prdebug("$s_run : Results are ".Dumper($results), 1);

    my $results_lkup = { } ;
    for (my $i=0; $i<$exp_tot; $i++){
        my $resname = uc($results->[$i]);

        if ( ! exists z_drivers_or_constructors($s_run)->{$resname} ){
            die "Can't find [$resname] from [$file_results] in file [".z_drivers_or_constructors_file($s_run)."]\n";
        }

        $results_lkup->{z_drivers_or_constructors($s_run)->{$resname}}=$i;

    }
    prdebug("$s_run : Results Lookup is ".Dumper($results_lkup), 1);

    if (scalar @$results != $exp_tot){
        die "The results file [$file_results] has [".scalar @$results."] rows and not [$exp_tot]\n";
    }

    my @skip_player_errs = ();
    my $player_results_arr = [];

    my $all_players_data = get_all_players_data($s_run);

PLYR:
    for my $plyr (sort keys %$z_players){
        prdebug("$s_run : Processing Player $plyr\n",0);
        my $result_line = "";
        #my $plyr_tot_score = Math::BigInt->bzero();
        my $plyr_tot_score = 0;

        my $skip_result_line = sub {
            my ($skip_reason) = @_;
            $skip_reason //= "";

            push @$player_results_arr ,
                {score => 0, player=>$plyr , round=> $s_run,
                 output => "${result_line}${skip_reason}", skipped=>1};
        };


        if ( ! exists $all_players_data->{$plyr} ){
            push @skip_player_errs,
                "$s_run : Skip [$plyr] no data in $s_run.all-players file";
            $skip_result_line->("|no data (A)");
            prdebug("  no data (A)\n",0);
            next ;
        }

        my $plyr_data = $all_players_data->{$plyr};


        prdebug("$s_run : $plyr : ".Dumper($plyr_data),0);

        if (scalar @$plyr_data < $o_score_upto_pos){
            push @skip_player_errs,
                "$s_run : Skip [$plyr] because [".scalar @$plyr_data."] lines in file [".all_player_file($s_run)."] isn't [$o_score_upto_pos]";
            $skip_result_line->("|no data (B)");
            prdebug("  no data (B)\n",0);
            next;
        }

        for (my $i=0; $i<$o_score_upto_pos; $i++){

            my $plyr_pred = uc($plyr_data->[$i]);
            if ( ! exists z_drivers_or_constructors($s_run)->{$plyr_pred} ){
                push @skip_player_errs,
                    "$s_run : Skip [$plyr] because prediction [".
                        ($i+1)."][$plyr_pred] in file [".all_player_file($s_run)."] not found in [".z_drivers_or_constructors_file($s_run)."]";

                $skip_result_line->("|no data (C)");
                prdebug("  no data (C)\n",0);
                next PLYR;
            }
            # get the 3 char abbrieviation :
            $plyr_pred = z_drivers_or_constructors($s_run)->{$plyr_pred} ;

            my $add_result = sub ($$$){
                my ($pred, $real_score, $disp_hundred_score) = @_;

                $plyr_tot_score += $real_score;

                my $score = $o_score_times_power_hundred ? $disp_hundred_score : $real_score;

                if ($o_suppress_detail_score) {
                    $result_line .= sprintf("|%s", $pred);
                } else {
                    $result_line .= sprintf("|%s %4s", $pred, $score);
                }
            };

            if ( ! exists $results_lkup->{$plyr_pred}){
                # This is a programming error.
                # die "The lookup \$results_lkup->{$plyr_pred} []should work. Programmng error"."\n";

                prdebug("$s_run : $plyr : ".($i+1)." $plyr_pred  (0)\n",0);
                $add_result->($plyr_pred,0,0);

            } else {

                my $error = abs($results_lkup->{$plyr_pred}-$i);

                #my $score = Math::BigInt->bzero();;
                my $score = 0;

                if ( $o_score_sys eq "karl-8") {
                    if ( $error <= 3){
                        $score = 2 ** (3-$error) ;
                    }
                }
                elsif ( $o_score_sys eq "karl-32" ) {
                    if ( $error <= 5){
                        $score = 2 ** (5-$error) ;
                    }
                }
                elsif ( $o_score_sys eq "differential_scoring" ) {
                    $score = $o_drivers_count-$error;
                }
                elsif ( $o_score_sys eq "exact" ) {
                    $score = $error ? 0 : 1;
                }
                else {
                    die "score-sys [$o_score_sys] invalid. Programming error\n";
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

                prdebug("$s_run : $plyr : ".($i+1)." $plyr_pred  : error $error : score ".int($score)."\n",0);
                $add_result->($plyr_pred, $score, $display_hundreds_score);
            }
        }

        $result_line =~ s/, $//g;


        prdebug("$s_run : $result_line",0);

        push @$player_results_arr , {score => $plyr_tot_score, player=>$plyr ,
                                     round=> $s_run, output => $result_line, skipped=>false};
    }

    # Post processing 

    my @plyr_ordered_res =  sort {
                                 $b->{score} <=> $a->{score}
                              || $a->{skipped} <=> $b->{skipped}
                            } @$player_results_arr;

    my $last_diff_score;
    my $last_diff_score_highest_pos;

    my $real_fia_score_sharing = {};

    # Part of calculating the fia_scoring for shared / non-shared positions.
    my $add_2_real_fia_score_sharing = sub {
        my ($has_p, $P) = @_;
        # So $P position has an array of Ps.
        # This is so say 3 players were equal P2,
        # This mean the 3 players should all get (18+15+12)/3 points.

        $real_fia_score_sharing->{$P}{pos} = []
                if ! exists $real_fia_score_sharing->{$P}{pos};


        push @{$real_fia_score_sharing->{$P}{pos}}, $has_p;

    };

    for ( my $i=0; $i < scalar @plyr_ordered_res; $i++ ){
        my $plyr_rh = $plyr_ordered_res[$i];
        if ( $plyr_rh->{skipped} ){
            $plyr_rh->{pos} = $i+1;
            next;
        }
        if ( $i == 0 ){

            $plyr_rh->{pos} = $i+1;
            $last_diff_score = $plyr_rh->{score};
            $last_diff_score_highest_pos = $i;

            $add_2_real_fia_score_sharing->($i,$last_diff_score_highest_pos);

            next;
        }
        elsif ( $plyr_rh->{score} == $last_diff_score ){
            $plyr_rh->{pos} = $last_diff_score_highest_pos+1;
            $add_2_real_fia_score_sharing->($i,$last_diff_score_highest_pos);
        }
        else {
            $plyr_rh->{pos} = $i+1;
            $last_diff_score = $plyr_rh->{score};
            $last_diff_score_highest_pos = $i;
            $add_2_real_fia_score_sharing->($i,$last_diff_score_highest_pos);
        }
    }

    # calculate the fia_scoring for shared / non-shared positions.
    for my $rfp ( keys %$real_f1_pos_scores ){
        if (exists $real_fia_score_sharing->{$rfp}){
            my $tot   = 0;
            my $count = 0;

            for my $has_p (@{$real_fia_score_sharing->{$rfp}{pos}}){
                $count ++;
                $tot += $real_f1_pos_scores->{$has_p} // 0;
            }
            $real_fia_score_sharing->{$rfp}{score_each} = $tot/$count;
        }
    }

    for ( my $i=0; $i < scalar @plyr_ordered_res; $i++ ){
        my $plyr_rh = $plyr_ordered_res[$i];
        my $pos = $plyr_rh->{pos} - 1;

        if ( $plyr_rh->{skipped} ){
            $plyr_rh->{fia_score} = 0;
            next;
        }

        if(exists $real_fia_score_sharing->{$pos}{score_each}){
            $plyr_rh->{fia_score} =
                    $real_fia_score_sharing->{$pos}{score_each};
        }
        else {
            $plyr_rh->{fia_score} = 0;
        }
    }

    prdebug("$s_run real_fia_score_sharing ".Dumper($real_fia_score_sharing),1);

    prdebug("$s_run plyr_ordered_res ".Dumper(\@plyr_ordered_res),1);

    #for my $ln (@plyr_ordered_res){
    #    prdebug("$s_run : $ln->{output}",1);
    #}

    prdebug("$s_run : Skipped players due to errors : \n  ".join("\n  ",@skip_player_errs)."\n",0)
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

    prdebug("Dump of player data from  $all_player_filename\n : ".Dumper ( $plyr_data ),2);

    return $plyr_data;
}

sub all_player_file ($) { return "$_[0].all-players" }

main();
