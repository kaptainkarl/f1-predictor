#!/usr/bin/perl
use strict; use warnings;
use Data::Dumper;
use Try::Tiny;
use JSON;
use Text::CSV qw( csv );
use DateTime;

use Scalar::Util qw(looks_like_number);
use Number::Format;
use Cwd;
sub true {1}
sub false {0}
sub karl_winner_ta {"winner-takes-all"}
sub leo_winner_ta {"top-6-winner-takes-all-broken"}

my $dt_now = DateTime->now();
my $season = $dt_now->year();
# TODO season also needs an $o_season CLI option.

my $cwd = getcwd();

die "Not running from correct directory\n" if ! -f "f1-predictor.pl";

# dirs where the script will die if they don't already exist :
sub data_dir          {check_dir("$cwd/data/$season/")}
sub output_dir        {check_dir("$cwd/output/$season/")}

# dirs that will get "made" :
sub output_all_alg_dir{check_dir(output_dir()."all-algorithms/", true)}
sub output_json_dir   {check_dir(output_dir()."json/", true)}
sub output_csv_dir    {check_dir(output_dir()."csv/", true)}

sub check_all_dirs{
    output_dir();
    output_all_alg_dir();
    output_json_dir();
    output_csv_dir();
    data_dir();
}
check_all_dirs();

# FIXED constants.
my $ZDATA_DRIVERS       = 'zdata.drivers';
my $ZDATA_CONSTRUCTORS  = 'zdata.constructors';
my $ZDATA_RACES         = 'zdata.races';
my $ZDATA_PLAYERS       = 'zdata.players';

my $out_fh;
sub dierr {
    my ($msg) = @_;

    close $out_fh if $out_fh;

    $msg = "ERROR $msg" ;
    die "\n$msg\n";
}


#$o_out_file_suffix
sub printout ($){
    my ($txt) = @_;
    if ($out_fh){
        print $out_fh ($txt);

        #print $txt;
    }
    else {
        print $txt;
    }
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
my $real_1990_f1_pos_scores_reverse = {
    0 => 1,
    1 => 2,
    2 => 3,
    3 => 4,
    4 => 6,
    5 => 9,
};

# These are -1 out, so 0 is really P1 !!! :
# This is basically 100^(pos-6)
# I guess I could just do it in a sum.
# But a hash map keeps it to the first 6 places.
# We're only doing P1 -> P6 predictions.
my $power_hundred_score_multiplier = {
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

        It sets the --score-accuracy-sys to 'exact'
        and --score-times-sys to power-100

        Basically it is a short cut to how Leo wants the predictions calculated.

        The --leo option also only outputs a very concise output.
        if you want to see the numbers that 
            --score-accuracy-sys to 'exact' --score-times-sys to power-100
        you need to run them without the --leo option.

        This isn't quite Leo's method.
        It's the first part.
        Leo's method as a tie break , then looks for non exact positions of drivers
        predicted to be in the top 6 , who were in the top 6. They are counted up.
        It is possible to have a draw.
        Thus this still needs some coding.

    --karl-winner-takes-all
        this is more than a short cut.
        it is 2 scoring systems, used to then order the results.
        Using FIA points probably makes the most sense because
        Adding the 2 scores together would be silly.

        First it sorts the rounds by the scores calculated by 
            exact and power-100.
        This is the same as the first half of Leo's winner takes all.

        A secondary sort is then done on the scoring system
            diff and power-100
        This will then split apart the positions with the same score as the first sort.
        About the only way I can see a position being shared is if 2 or more players make
        exactly the same predictions.

        Having a "diff" , with P1 trumping all will mean that the players with the most
        accurate, but not exact P1 (then P2) predictions will win.

        The sequence of players can then be assigned FIA style positional points.
        The can be used in a Totals table.

        Totals tables could also be sorted on the 2 independent scores.
        The exact-and-power-100 one again having the higher priority.


    --score-accuracy-sys  karl-8, karl-32, karl-96-16, differential_scoring, diff, exact
        defaults to differential_scoring

        diff and differential_scoring are the same thing.

        i.e.
        --score-accuracy-sys diff
            would run the :
                20 - prediction-error = score system.

        --score-accuracy-sys karl-8
            would run the 8,4,2,1 scoring system.

        --score-accuracy-sys karl-32
            would run the 32-16-8-4-2-1 Karl systems.

        --score-accuracy-sys karl-96-16
            would run the 96-16-8-4-2-1 Karl systems.

        --score-accuracy-sys exact
            a single point is only awarded to an exactly
            correct prediction.

    --show-test-plyr --show-test-player
        a "test-plyr" needs adding to the zdata.players file for this to work
        in normal outputs the test-plyr will be ignored.
        This option will runs the calcs with the test player.

    --show-only-test-plyr --show-only-test-player
        a "test-plyr" needs adding to the zdata.players file for this to work
        in normal outputs the test-plyr will be ignored.
        This option will runs the calcs with the test player.
        It also doesn't calculate non "test-plyr" scores

    --score-times-sys  none , 9-to-1 , 1-to-9 , 25-to-8, power-100

        none ( this is the default ) :
            no multiplier applied to the positional predictions.

        25-to-8 :
            This multiplies the score for
                P1 prediction by 25
                P2 prediction by 18
                P3 prediction by 15
                ... (you know these numbers !!)
                P6 prediction by 8
                ...
                P10 prediction by 1

                25-to-8 name comes from refering to P1 -> P6 predictions only

        9-to-1 (1990 ish scoring system) :
            This multiplies the score for
                P1 x 9
                P2 x 6
                P3 x 4
                P4 x 3
                P5 x 2
                P6 x 1

        1-to-9
            This is the reverse of 9-to-1
            So P6 is multiplied by 9 etc.

        power-100 :
            Currently for the top 6 postions only
            (This script is kind of becoming a top-6-only-predictor)
            it is :
            ( Pos - 6 ) ^ 100
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

    --player-rating-score  --score  --rating
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

    --suppress-position-column
        suppresses the position column

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

    --out-file-suffix
        if the script is to write an output file it needs a suffix
        So this option is doing 2 things.
        tell the script to write to a file,
        and say what the suffix is.

        Currently the script is dumping to a hard coded directory

    --out-sub-dir
        if this is not specified, output will go to the "all-algorithms"
        directory.
        if it is specified, output will go to the "favourites" directory.
        ( in the "output" directory )
        for 2022 the directories are :
        ./output/2022/favourites
        ./output/2022/all-algorithms
        ./output/2022/tlb

    --out-accuracy-sub-dir
        if this is specified the output will go to a sub directory 
        with the name of the "accuracy" part of the scoring system.

        thus
            --out-accuracy-sub-dir --score-accuracy-system "diff" --score-times-system 9-to-1

        would output the file to something like :

        ./output/2022/all-algorithms/diff/positions-times-9-to-1-ALL

    --debug
        Defaults to 0 . No debug.
        --debug 1 shows minimal debug,  2 and 3 a bit more ...

    See README file for full explanation of files in the directory.

EOUSAGE
}

use Getopt::Long;

my $score_accuracy_sys_lkup = {
    "karl-8"     => 1,
    "karl-32"    => 1,
    "karl-96-16" => 1,
    "differential_scoring" => 1,
    "exact" => 1,
};

my $score_times_sys_lkup = {
    "none"       => 1,
    "9-to-1"     => 1,
    "1-to-9"     => 1,
    "25-to-8"    => 1,
    "power-100"  => 1,
};

my $o_score_accuracy_sys;
my $o_score_times_sys;

sub is_score_times_power_100 {
    my ($times) = @_;
    $times //= $o_score_times_sys;
    return $times eq 'power-100' ? true : false;
}
sub is_score_times_none {
    my ($times) = @_;
    $times //= $o_score_times_sys;
    return $times eq 'none' ? true : false;
}
sub is_score_times_9_to_1 {
    my ($times) = @_;
    $times //= $o_score_times_sys;
    return $times eq '9-to-1' ? true : false;
}
sub is_score_times_1_to_9 {
    my ($times) = @_;
    $times //= $o_score_times_sys;
    return $times eq '1-to-9' ? true : false;
}
sub is_score_times_25_to_8 {
    my ($times) = @_;
    $times //= $o_score_times_sys;
    return $times eq '25-to-8' ? true : false;
}

my $o_drivers_count       = 20;
my $o_constructors_count  = 10;
my $o_score_upto_pos = 6;
my ($o_run, $o_help);

my $o_html_output;
my $o_suppress_detail_score;
my ($o_minus_points, $o_multi_points);
my $o_multi_points_factor = 2;
my $o_player_fia_score;
my $o_player_rating_score;
my $o_suppress_average_table;
my $o_score_leo;
my $o_score_karl_winner_takes_all;
my $o_disp_plyrs_upto_pos = 99999999;
my $o_suppress_totals_tables;
my $o_suppress_rounds_tables;
my $o_no_pre_code;
my $o_out_file_suffix;
my $o_out_sub_dir;
my $o_out_accuracy_sub_dir;
my $o_show_test_player;
my $o_show_only_test_player;
my $o_suppress_position_column;

GetOptions (
    "score-only-upto-pos=i"  => \$o_score_upto_pos,
    "leo"                   => \$o_score_leo,
    "karl-winner-takes-all" => \$o_score_karl_winner_takes_all,
    "score-accuracy-sys=s"  => \$o_score_accuracy_sys,
    "score-times-sys=s"     => \$o_score_times_sys,
    "minus-points=s"        => \$o_minus_points,
    "multi-points=s"        => \$o_multi_points,
    "multi-points-factor=s" => \$o_multi_points_factor,
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
    "no-pos-col|suppress-position-column"
                            => \$o_suppress_position_column, # TODO implement this.
    "no-pre-code"
                            => \$o_no_pre_code,

    "show-test-plyr|show-test-player"
                            => \$o_show_test_player,
    "show-only-test-plyr|show-only-test-player"
                            => \$o_show_only_test_player,
    #### << display type options

    "out-file-suffix=s"     => \$o_out_file_suffix,
    "out-sub-dir=s"         => \$o_out_sub_dir,
    "out-accuracy-sub-dir"  => \$o_out_accuracy_sub_dir,

    "drivers-count=i"       => \$o_drivers_count,
    "constructors-count=i"  => \$o_constructors_count,
    "run=s"                 => \$o_run,
    "h|help"                => \$o_help,
    "debug=i"               => \$o_debug,
) or die "Option errors\n";

usage() if $o_help;

if ( ! looks_like_number $o_multi_points_factor ){
    dierr( "--multi-points-factor $o_multi_points_factor does not look like a number\n");
}

if ($o_score_leo && $o_score_karl_winner_takes_all ){
    dierr("Can't use --leo and --karl-winner-takes-all both at the same time\n");
}
if ($o_score_leo || $o_score_karl_winner_takes_all ){
    $o_score_accuracy_sys = "exact";
    $o_score_times_sys    = "power-100";
}

my $z_races   = z_data_single(data_dir().$ZDATA_RACES);
prdebug( "Dump of races = ".Dumper($z_races), 2 );
json_out_dump($ZDATA_RACES, $z_races, false);

my $z_players = z_data_single(data_dir().$ZDATA_PLAYERS);
prdebug( "Dump of players = ".Dumper($z_players),2 );
json_out_dump($ZDATA_PLAYERS, $z_players, false);

my $z_drivers = z_data_pipe_split(data_dir().$ZDATA_DRIVERS);
prdebug( "Dump of drivers = ".Dumper($z_drivers), 2 );
json_out_dump($ZDATA_DRIVERS, $z_drivers, false);

# Only works on drivers. Doesn't seem much point on WCC
my $z_minus_points = {};
if ($o_minus_points){

    for my $mpdrv ( split /,/,$o_minus_points){
        $mpdrv = uc(trim($mpdrv));

        if ( ! exists $z_drivers->{$mpdrv} ){
            dierr( "The --minus-points driver name of [$mpdrv] can't be found\n");
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
            dierr( "The --multi-points driver name of [$mpdrv] can't be found\n");
        }

        $z_multi_points->{$z_drivers->{$mpdrv}} = 1;
    }
    prdebug( "Dump of multi_points_driver lookup \n".Dumper($z_multi_points),2);
}

my $z_constructors = z_data_pipe_split(data_dir().$ZDATA_CONSTRUCTORS);
prdebug ( "Dump of constructors = ".Dumper($z_constructors),2);
json_out_dump($ZDATA_CONSTRUCTORS, $z_constructors, false);

prdebug("constructors count  = $o_constructors_count\n", 2 );
prdebug("drivers count       = $o_drivers_count\n", 2 );

if (!$o_run) {
    dierr("You must define --run , with wcc , wdc or the race-name");
}

$o_score_accuracy_sys = "differential_scoring"
    if ! $o_score_accuracy_sys || $o_score_accuracy_sys eq "diff";

if ( ! exists $score_accuracy_sys_lkup->{$o_score_accuracy_sys} ){
    dierr("[--score-sys $o_score_accuracy_sys] isn't valid\n");
}

$o_score_times_sys //= "none";
if ( ! exists $score_times_sys_lkup->{$o_score_times_sys} ){
    dierr("[--score-sys $o_score_times_sys] isn't valid\n");
}

if ($o_drivers_count < 2){
    dierr("[--drivers-count $o_drivers_count] needs to be more than 2!");
}

if ($o_constructors_count < 2){
    dierr("[--constructors-count $o_constructors_count] needs to be more than 2!");
}

if ( $o_out_file_suffix ) {
    my $file_name = get_out_file();
    open( $out_fh, ">" , $file_name ) || dierr( "Can't create $file_name $!") ;
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

    my $max_p_pos = 6; # used for classifying winning by the first 6 positions.

    # iterating over the rounds to build up a plyr_tots hash by
    # plyr name lookup.
    for my $pr_hsh (@$run_arrs) {
        my $pr_run = $pr_hsh->{plydata};

        for my $ln (@$pr_run){

            my $pos = $ln->{pos};
            my $plyr = $ln->{player};
            dierr( "unknown player . prog error \n") if ! $ln->{player};

            $plyr_tots->{$plyr}{player} = $plyr;

            $plyr_tots->{$plyr}{"p$pos"}++;

            $plyr_tots->{$plyr}{fia_total} = $plyr_tots->{$plyr}{fia_total} // 0;
            $plyr_tots->{$plyr}{total}     = $plyr_tots->{$plyr}{total}     // 0;
            $plyr_tots->{$plyr}{played}    = $plyr_tots->{$plyr}{played}    // 0;

            $plyr_tots->{$plyr}{wta_score1_tot} = $plyr_tots->{$plyr}{wta_score1_tot} // 0;
            $plyr_tots->{$plyr}{wta_score2_tot} = $plyr_tots->{$plyr}{wta_score2_tot} // 0;

            $plyr_tots->{$plyr}{fia_total} += $ln->{fia_score};
            $plyr_tots->{$plyr}{total}     += $ln->{score};
            $plyr_tots->{$plyr}{played} ++ if ! $ln->{skipped};

            $plyr_tots->{$plyr}{wta_score1_tot}
                         += $ln->{all_algos}{exact}{"power-100"}{total};

            $plyr_tots->{$plyr}{wta_score2_tot}
                         += $ln->{all_algos}{differential_scoring}{"power-100"}{total};

        }
    }

    # $tots_arr contains all the totals with ave scores
    my $tots_arr = [];
    for my $tpname ( keys %$plyr_tots ){
        my $tp = $plyr_tots->{$tpname};

        if ( $tp->{played}){

            $tp->{ave_score} =  $tp->{total} / $tp->{played};
            $tp->{ave_fia}   =  $tp->{fia_total} / $tp->{played};
            $tp->{ave_wta_score1} = $tp->{wta_score1_tot} / $tp->{played};
            $tp->{ave_wta_score2} = $tp->{wta_score2_tot} / $tp->{played};

        } else {
            $tp->{ave_wta_score1} = 0;
            $tp->{ave_wta_score2} = 0;
            $tp->{ave_score} = 0;
            $tp->{ave_fia}   = 0;
        }

        for my $p_pos ( 1..$max_p_pos ){
            # fill in the pNUM hash keys that are undef with 0;
            $tp->{"p$p_pos"} = $tp->{"p$p_pos"} // 0;
        }

        push @$tots_arr, $tp;
    }

    prdebug("plyr_tots : ".Dumper($plyr_tots),1);
    prdebug("tots_arr  : ".Dumper($tots_arr),1);
die "debug";

    json_out_dump("z-totals-hash",$plyr_tots, true);
    json_out_dump("z-totals-array",$tots_arr, true);

    if ( $o_score_leo ){
        leo_output ($plyr_tots, $run_arrs, $tots_arr);
    }
    elsif ( $o_score_karl_winner_takes_all ){
        wta_output ($plyr_tots, $run_arrs, $tots_arr);
    }
    else {
        main_header_out();
        main_totals_output($plyr_tots, $run_arrs, $tots_arr);
        main_rounds_out(   $plyr_tots, $run_arrs, $tots_arr);
    }
    # deliberately not printout() :
    print get_out_file()."\n";
}

sub wta_output {
    my ($plyr_tots, $run_arrs, $tots_arr ) = @_;
    printout("Winner Takes All\n");
    printout("---------------------\n\n");

    for my $pr_hsh (@$run_arrs) {

        my $pr_run = $pr_hsh->{plydata};

        printout( round_name($pr_hsh->{round})." : ");

        my $winners = "";

        for my $ln (@$pr_run){

            my $pos = $ln->{pos};
            my $plyr = $ln->{player};
            dierr( "unknown player . prog error \n") if ! $ln->{player};

            my $plyr_n = $z_players->{$plyr} //
                dierr( "Can't lookup player uppercased name (leo_output 1)\n");

            if ($ln->{score} > 0 && $pos == 1){
                $winners .= "$plyr_n, ";
            }
        }

        $winners = $winners ? $winners: "No Winners";

        $winners =~ s/, $//g;
        printout("$winners\n\n");
    }

    ##############################
    # Output the Individual Rounds

    if ( @$run_arrs >1 && ! $o_suppress_rounds_tables ){
        printout( "\n-----------------\n");
          printout( "WTA Individual rounds\n");
          printout( "-----------------\n");
    }

    for my $pr_hsh (@$run_arrs) {
        # could be done better :
        next if $o_suppress_rounds_tables;

        my $pr_run = $pr_hsh->{plydata};

        printout( "Method is '". get_scoring_type_out()."'\n");
        printout( "---------------\n");

        printout( round_name($pr_hsh->{round})."\n\n");

        pre_code_open();
        # Header row
        my $underline = "-" x 15;
        printout( "P   Player     ");

        if ($o_player_rating_score){
            printout(sprintf( "%18s|", "score 1  ")) ;
            $underline .= "-" x 19;
            printout(sprintf( "%18s|", "score 2  ")) ;
            $underline .= "-" x 19;
        }

        if ($o_player_fia_score) {
            printout(sprintf("%4s   |",'FIA'));
            $underline .= "-" x 8;
        }

        my  $fmt  ="%-".(length($pr_run->[0]{output})-1)."s";
        printout(sprintf ("$fmt", $pr_hsh->{details_header} ));

# TODO next line needs fixing, can't use the sub process built up output.
        $underline .= ("-" x length($pr_run->[0]{output}));

        printout ("\n");
        printout ("$underline\n");

        # Body rows :
        for my $ln (@$pr_run){

            my $pos = $ln->{pos};
            my $plyr = $ln->{player};
            dierr( "unknown player . prog error \n") if ! $ln->{player};

            next if $pos > $o_disp_plyrs_upto_pos;
            my $plyr_n = $z_players->{$plyr} //
                 dierr( "Can't lookup player uppercased name (rounds)\n");

            if ($ln->{skipped}){
                printout(sprintf("    %-10s ",$plyr_n));
                printout($ln->{output}."\n");
                next;
            }

            printout(sprintf("%-3s %-10s ",$pos, $plyr_n));

            if ($o_player_rating_score){
                my $sc_str = hundreds($ln->{all_algos}{exact}{"power-100"}{total});
                printout(sprintf( "%18s|", "$sc_str "));

                $sc_str = hundreds($ln->{all_algos}{differential_scoring}{"power-100"}{total});
                printout(sprintf( "%18s|", "$sc_str "));
            }

            if ($o_player_fia_score) {
                my $fia_s = sprintf("%.2f",$ln->{fia_score});
                $fia_s =~ s/.00$/   /g;
                printout(sprintf("%6s |",$fia_s));
            }


            my $oline = "";

            for (my $i=0; $i<$o_score_upto_pos; $i++){

                my $pred = $ln->{preds}[$i];
                my $score =$ln->{all_algos}{differential_scoring}{"power-100"}{hundreds_positions}[$i];
                if ( not defined $score ){
                    $score = "DNS";
                    $pred = lc ($pred);
                }
                elsif ( $score == 20 ){
                    $score = "";
                } else {
                    # $pred = lc ($pred);
                }

                $oline .= sprintf(" %s %4s |", $pred, $score);

            }

            printout($oline);


            printout ("\n");
        }
        printout ("$underline\n");
        pre_code_close();

    }

    printout ("Totals Tables run for ". join(", ", split (",", $o_run))."\n\n");

    # P1->6 table.
    printout("------------------------\n");
    printout( "Method is '".get_scoring_type_out()."'\n\n");
    printout("P1 -> P6 then FIA Total Score \n");
    printout("------------------------\n");
    pre_code_open();
    totals_header("FIA", true, false);
    my $pp = 1;
    for my $tl (sort {
                $b->{p1} <=> $a->{p1} ||
                $b->{p2} <=> $a->{p2} ||
                $b->{p3} <=> $a->{p3} ||
                $b->{p4} <=> $a->{p4} ||
                $b->{p5} <=> $a->{p5} ||
                $b->{p6} <=> $a->{p6} ||
                $b->{fia_total}  <=> $a->{fia_total} ||
                $b->{player} cmp $a->{player}
            } @$tots_arr
    ){
        totals_row($pp, $tl, "fia_total", true, false);
        $pp++;
    }
    totals_header("Total", true, false,true);
    pre_code_close();

    if ($o_player_rating_score){



    }

    if ( $o_player_fia_score ){

        # Total FIA
        printout ("---------------------\n");
        printout( "Method is '".get_scoring_type_out()."'\n\n");
        printout ("Total FIA Score table\n");
        printout ("---------------------\n");
        pre_code_open();
        totals_header("FIA", false, true);
        $pp = 1;
        for my $tl ( sort { $b->{fia_total} <=> $a->{fia_total}
                         || $b->{player}    cmp $a->{player}
                    } @$tots_arr
        ) {
            totals_row($pp, $tl, "fia_total", false, true);
            $pp++;
        }
        totals_header("FIA", false, true, true);
        pre_code_close();


        if ( !$o_suppress_average_table) {
            # Ave FIA table
            printout ("---------------------\n");
            printout( "Method is '".get_scoring_type_out()."'\n\n");
            printout ("Average FIA Score\n");
            printout ("For players who have not entered all rounds\n");
            printout ("---------------------\n");
            pre_code_open();
            totals_header("FIA", false, true);
            $pp = 1;
            for my $tl ( sort { $b->{ave_fia} <=> $a->{ave_fia}
                             || $b->{player}  cmp $a->{player}
                        } @$tots_arr
            ) {
                totals_row($pp, $tl, "ave_fia", false, true);
                $pp++;
            }
            totals_header("FIA", false, true, true);
            pre_code_close();
        }
    }
}

sub leo_output {
    my ($plyr_tots, $run_arrs, $tots_arr ) = @_;

    printout("Leo Winner Takes All\n");
    printout("--------------------\n\n");

    for my $pr_hsh (@$run_arrs) {

        my $pr_run = $pr_hsh->{plydata};

        printout( round_name($pr_hsh->{round})." : ");

        my $winners = "";

        for my $ln (@$pr_run){

            my $pos = $ln->{pos};
            my $plyr = $ln->{player};
            dierr( "unknown player . prog error \n") if ! $ln->{player};

            my $plyr_n = $z_players->{$plyr} //
                dierr( "Can't lookup player uppercased name (leo_output 1)\n");

            if ($ln->{score} > 0 && $pos == 1){
                $winners .= "$plyr_n, ";
            }
        }

        $winners = $winners ? $winners: "No Winners";

        $winners =~ s/, $//g;
        printout("$winners\n\n");
    }

    if ( ! $o_suppress_rounds_tables){
        printout("\n\n");
        printout("--------------\n");
        printout("Rounds Details\n");
        printout("--------------\n");
    }

    for my $pr_hsh (@$run_arrs) {

        # could be done better :
        next if $o_suppress_rounds_tables;

        my $pr_run = $pr_hsh->{plydata};
        pre_code_open();

        printout( "\n---------------\n");
        printout( "Method is '".get_scoring_type_out()."'\n\n");

        printout( round_name($pr_hsh->{round})."\n\n");

        # Header row
        my $underline = "-" x 15;
        printout( "P   Player     ");

        if ($o_player_fia_score) {
            printout(sprintf("%4s   |",'FIA'));
            $underline .= "-" x 8;
        }

        printout(sprintf("%6s |",'Top 6'));
        $underline .= "-" x 8;

        my  $fmt  ="%-".(length($pr_run->[0]{output})-1)."s";
        printout(sprintf ("$fmt", $pr_hsh->{details_header} ));

        $underline .= ("-" x length($pr_run->[0]{output}));

        printout ("\n");
        printout ("$underline\n");

        # Body rows :
        for my $ln (@$pr_run){

            my $pos = $ln->{pos};
            my $plyr = $ln->{player};
            dierr( "unknown player . prog error \n") if ! $ln->{player};
            my $plyr_n = $z_players->{$plyr} //
                dierr( "Can't lookup player uppercased name (leo_output 1)\n");

            next if $pos > $o_disp_plyrs_upto_pos;

            # Output section :
            if ($ln->{skipped}){
                printout(sprintf("    %-10s ",$plyr_n));
                printout($ln->{output}."\n");
                next;
            }

            printout(sprintf("%-3s %-10s ",$pos, $plyr_n));

            if ($o_player_fia_score) {
                my $fia_s = sprintf("%.2f",$ln->{fia_score});
                $fia_s =~ s/.00$/   /g;
                printout(sprintf("%6s |",$fia_s));
            }

            printout(sprintf("   %2s  |",$ln->{top6_count}));

            my $outline = $ln->{output};
            $outline =~s/0/ /g;

            printout($outline);

            printout ("\n");
        }
        printout ("$underline\n");
        pre_code_close();
    }

    if ( $o_player_fia_score ){
        printout ("Totals Tables run for ". join(", ", split (",", $o_run))."\n\n");
        pre_code_open();
        printout ("---------------------\n");
        printout( "Method is '".get_scoring_type_out()."'\n\n");
        printout ("Total FIA Score table\n");
        printout ("---------------------\n");
        totals_header("FIA", false, true);
        my $pp = 1;
        for my $tl ( sort { $b->{fia_total} <=> $a->{fia_total}
                         || $b->{player}    cmp $a->{player}
                    } @$tots_arr
        ) {
            totals_row($pp, $tl, "fia_total", false, true);
            $pp++;
        }
        totals_header("FIA", false, true, true);
        pre_code_close();

        # Ave FIA table
        pre_code_open();
        printout ("---------------------\n");
        printout( "Method is '".get_scoring_type_out()."'\n\n");
        printout ("Average FIA Score\n");
        printout ("For players who have not entered all rounds\n");
        printout ("---------------------\n");
        totals_header("FIA", false, true);
        $pp = 1;
        for my $tl ( sort { $b->{ave_fia} <=> $a->{ave_fia}
                         || $b->{player}  cmp $a->{player}
                    } @$tots_arr
        ) {
            totals_row($pp, $tl, "ave_fia", false, true);
            $pp++;
        }
        totals_header("FIA", false, true, true);
        pre_code_close();

        # P1->6 table.
        pre_code_open();
        printout("------------------------\n");
        printout( "Method is '".get_scoring_type_out()."'\n\n");
        printout("P1 -> P6 then FIA Total Score \n");
        printout("------------------------\n");
        totals_header("FIA", true, false);
        $pp = 1;
        for my $tl (sort {
                    $b->{p1} <=> $a->{p1} ||
                    $b->{p2} <=> $a->{p2} ||
                    $b->{p3} <=> $a->{p3} ||
                    $b->{p4} <=> $a->{p4} ||
                    $b->{p5} <=> $a->{p5} ||
                    $b->{p6} <=> $a->{p6} ||
                    $b->{fia_total}  <=> $a->{fia_total} ||
                    $b->{player} cmp $a->{player}
                } @$tots_arr
        ){
            totals_row($pp, $tl, "fia_total", true, false);
            $pp++;
        }
        totals_header("Total", true, false,true);
        pre_code_close();
    }
}

sub main_header_out {

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

    if ( ! $o_no_pre_code && ! $o_score_leo) {
        printout ( "The <code><pre> ... </pre></code> Tags wrapping the tables sections below are there for if you want to copy and paste to disqus comments.\n");
        printout ( "The Tags will format a lined up table\n\n" );

        printout ( "Please note you will see some colour highlighting because disqus thinks it is computer code.\n" );

        printout ( "See https://help.disqus.com/en/articles/1717236-syntax-highlighting for a better explanation\n\n" );

    }

    printout ("The way the scores are calculated is described at https://github.com/kaptainkarl/f1-predictor/blob/master/docs/algorithms_description.txt\n\n") if ! $o_score_leo ;

}

sub main_rounds_out {
    my ($plyr_tots, $run_arrs, $tots_arr) = @_;

    ##############################
    # Output the Individual Rounds
    if ($o_suppress_rounds_tables){
        print("Rounds have been suppressed by CLI option\n");
        return;
    }

    if ( @$run_arrs >1 ){
        printout( "\n-----------------\n");
          printout( "Individual rounds\n");
          printout( "-----------------\n");
    }

    for my $pr_hsh (@$run_arrs) {

        my $pr_run = $pr_hsh->{plydata};

        pre_code_open() if ! $o_suppress_rounds_tables;

        printout( "Method is '". get_scoring_type_out()."'\n");
        printout( "---------------\n");

        printout( round_name($pr_hsh->{round})."\n\n");

        # Header row
        my $underline = "-" x 15;
        printout( "P   Player     ");


        if ($o_player_rating_score){
            if (is_score_times_power_100()){
                printout(sprintf( "%18s|", "score ")) ;
                $underline .= "-" x 19;
            }
            else {
                printout(sprintf( "%7s|", "score " ));
                $underline .= "-" x 8;
            }
        }

        if ($o_player_fia_score) {
            printout(sprintf("%4s   |",'FIA'));
            $underline .= "-" x 8;
        }

        my  $fmt  ="%-".(length($pr_run->[0]{output})-1)."s";
        printout(sprintf ("$fmt", $pr_hsh->{details_header} ));

        $underline .= ("-" x length($pr_run->[0]{output}));


        printout ("\n");
        printout ("$underline\n");

        # Body rows :
        for my $ln (@$pr_run){

            my $pos = $ln->{pos};
            my $plyr = $ln->{player};
            dierr( "unknown player . prog error \n") if ! $ln->{player};

            next if $pos > $o_disp_plyrs_upto_pos;
            my $plyr_n = $z_players->{$plyr} //
                 dierr( "Can't lookup player uppercased name (rounds)\n");

            if ($ln->{skipped}){
                printout(sprintf("    %-10s ",$plyr_n));
                printout($ln->{output}."\n");
                next;
            }

            printout(sprintf("%-3s %-10s ",$pos, $plyr_n));

            if ($o_player_rating_score){
                if (is_score_times_power_100()){
                    my $sc_str = hundreds($ln->{score});
                    printout(sprintf( "%18s|", "$sc_str "));
                }
                else {
                    printout(sprintf( "%7s|", "$ln->{score} "));
                }
            }

            if ($o_player_fia_score) {
                my $fia_s = sprintf("%.2f",$ln->{fia_score});
                $fia_s =~ s/.00$/   /g;
                printout(sprintf("%6s |",$fia_s));
            }

            printout($ln->{output});

            printout ("\n");
        }
        printout ("$underline\n");

        pre_code_close() if ! $o_suppress_rounds_tables;
    }
}

sub main_totals_output {
    my ($plyr_tots, $run_arrs, $tots_arr ) = @_;

    if (@$run_arrs <2){
        printout ("\nOnly run for one round, not showing totals\n");
        return;
    }

    if ($o_suppress_totals_tables){
        print ("\nTotals have been suppress by CLI option\n");
        return;
    }

    printout ("\n\n\n----------------------\n");
    printout ("Totals Tables run for ". join(", ", split (",", $o_run))."\n\n");

    # TODO get rid of this when fixed 
    printout ( "The P column currently doesn't work out shared places\n" );
    printout ( "So until it is fixed it is not being displayed below\n\n" );

    # TODO if fia scoring is display this will need to sort by "fia_total";
    # Or maybe just generate another table.
    my $pp;
    if ($o_player_rating_score){
        pre_code_open();
        printout ("-----------------\n");
        printout( "Method is '".get_scoring_type_out()."'\n\n");
        printout ("Total Score table\n");
        printout ("-----------------\n");
        totals_header("Total", false, false);
        $pp = 1;
        for my $tl ( sort { $b->{total}  <=> $a->{total}
                         || $b->{player} cmp $a->{player}
                     } @$tots_arr
        ) {
            totals_row($pp, $tl, "total", false, false);
            $pp++;
        }
        totals_header("Total", false, false, true);
        pre_code_close();
    }

    if ($o_player_rating_score){
        pre_code_open();
        printout ("--------------------------------\n");
        printout( "Method is '".get_scoring_type_out()."'\n\n");
        printout ("Total Score table. Reverse Order\n");
        printout ("--------------------------------\n");
        totals_header("Total", false, false);
        $pp = scalar @$tots_arr;
        for my $tl ( sort { $a->{total}  <=> $b->{total}
                         || $a->{player} cmp $b->{player}
                    } @$tots_arr
        ) {
            totals_row($pp, $tl, "total", false, false);
            $pp--;
        }
        totals_header("Total", false, false, true);
        pre_code_close();
    }

    if ( ! $o_suppress_average_table && $o_player_rating_score ){
        pre_code_open();
        printout ("-------------------------------------------\n");
        printout( "Method is '".get_scoring_type_out()."'\n\n");
        printout ("Average score\n");
        printout ("For players who have not entered all rounds\n");
        printout ("-------------------------------------------\n");
        totals_header("Ave Score", false, false);
        $pp = 1;
        for my $tl ( sort { $b->{ave_score} <=> $a->{ave_score}
                         || $b->{player}    cmp $a->{player}
                     } @$tots_arr
        ) {
            totals_row($pp, $tl, "ave_score", false, false);
            $pp++;
        }
        totals_header("Ave Score", false, false, true);
        pre_code_close();
    }

    if ( $o_player_fia_score ){
        pre_code_open();
        printout ("---------------------\n");
        printout( "Method is '".get_scoring_type_out()."'\n\n");
        printout ("Total FIA Score table\n");
        printout ("---------------------\n");
        totals_header("FIA", false, true);
        $pp = 1;
        for my $tl ( sort { $b->{fia_total} <=> $a->{fia_total}
                         || $b->{player}    cmp $a->{player}
                    } @$tots_arr
        ) {
            totals_row($pp, $tl, "fia_total", false, true);
            $pp++;
        }
        totals_header("FIA", false, true, true);
        pre_code_close();

        if ( ! $o_suppress_average_table ){
            # Ave FIA table
            pre_code_open();
            printout ("---------------------\n");
            printout( "Method is '".get_scoring_type_out()."'\n\n");
            printout ("Average FIA Score table\n");
            printout ("For players who have not entered all rounds\n");
            printout ("---------------------\n");
            totals_header("FIA", false, true);
            $pp = 1;
            for my $tl ( sort { $b->{ave_fia} <=> $a->{ave_fia}
                             || $b->{player}  cmp $a->{player}
                        } @$tots_arr
            ) {
                totals_row($pp, $tl, "ave_fia", false, true);
                $pp++;
            }
            totals_header("FIA", false, true, true);
            pre_code_close();
        }
    }

    { # P1->6 table.
        pre_code_open();
        printout ("------------------------\n");
        printout( "Method is '".get_scoring_type_out()."'\n\n");
        printout ("P1 -> P6 then Total Score \n");
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
                    $b->{total}  <=> $a->{total} ||
                    $b->{player} cmp $a->{player}
                } @$tots_arr
        ){
            totals_row($pp, $tl, "total", true, false);
            $pp++;
        }
        totals_header("Total", true, false,true);
        pre_code_close();
    }
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

    return $sc if ! is_score_times_power_100() ;

    my $b = reverse $sc;
    my @c = unpack("(A2)*", $b);
    my $d = join ',', @c;
    my $e = reverse $d;
    return $e;
}

sub pre_code_open{
    printout ("\n");
    return if $o_no_pre_code;
    printout ( "<pre><code>\n" );
}

sub pre_code_close{
    return if $o_no_pre_code;
    printout ( "</pre></code>\n" );
}

sub get_scoring_type_out() {

    return karl_winner_ta() if $o_score_karl_winner_takes_all ;
    return leo_winner_ta()  if $o_score_leo ;

    return get_scoring_accuracy_type()." and ".get_scoring_multiplier_type();
}

sub get_scoring_type_out_filename_root() {
    my $type = get_scoring_type_out ();
    $type =~ s/\s/-/g;
    return $type;
}

sub get_scoring_accuracy_type {

    my $type;

    if ( $o_score_accuracy_sys eq "karl-8") {
        $type="karl-8";
    }
    elsif ( $o_score_accuracy_sys eq "karl-32" ) {
        $type="karl-32";
    }
    elsif ( $o_score_accuracy_sys eq "karl-96-16" ) {
        $type="karl-96-16";
    }
    elsif ( $o_score_accuracy_sys eq "differential_scoring" ) {
        $type="diff";
    }
    elsif ( $o_score_accuracy_sys eq "exact" ) {
        $type="exact";
    }
    return $type;
}

sub get_scoring_multiplier_type {
    my $type;
    if ( is_score_times_power_100() ){
        $type .= "positions-times-power-one-hundred";
    }
    elsif ( is_score_times_25_to_8() ){
        $type .= "positions-times-25-to-8";
    }
    elsif ( is_score_times_9_to_1() ) {
        $type .= "positions-times-9-to-1";
    }
    elsif ( is_score_times_1_to_9() ) {
        $type .= "positions-times-1-to-9";
    }
    elsif ( is_score_times_none() ) {
        $type .= "no-multiplier";
    }
    else {
        dierr("prog. error in score_times_sys getting scoring type out");
    }
    return $type;
}

sub b($){
    my ($num) = @_;
    return $num ? $num : "";
}

sub totals_header_wta {
    my ($score_key, $add_ppos, $is_fia, $only_underline) = @_;

    my $ppos_parts = $add_ppos ?"| P1 | P2 | P3 | P4 | P5 | P6 ":"";

    my $sc_wide = 14;
    if ( $is_fia ) {
        $sc_wide = 9;
    }
    elsif ( is_score_times_power_100() ){
        $sc_wide = 20;
    };

    my $underline = "---------------------";
    $underline .= "-" x length($ppos_parts);

    $underline .= "-" x ( $sc_wide + 4 );

    printout(sprintf( "P   Player    %${sc_wide}s|Played%s\n", "$score_key   ", $ppos_parts ))
        if ! $only_underline;

    printout("$underline\n");

}

sub totals_row_wta($$$$$) {
    my ($p, $tl, $score_key, $add_ppos, $is_fia) = @_;

    my $ppos_parts = $add_ppos ? sprintf("| %2s | %2s | %2s | %2s | %2s | %2s ", b($tl->{p1}), b($tl->{p2}), b($tl->{p3}),
                                                      b($tl->{p4}), b($tl->{p5}), b($tl->{p6}))
                                : "";

    my $score_text = $score_key;

    my $sc_wide = 14;
    if ( $is_fia ) {
        $sc_wide = 9;
    }
    elsif ( is_score_times_power_100() ){
        $sc_wide = 20;
    };

    my $scr_str;
    my $scr = sprintf( "%0.2f" , $tl->{$score_key});
    if ( my ($intg, $deci) = $scr =~ m/^(\d+)\.(\d+)$/ ){
        $scr_str =  thousands($intg).".$deci";
        $scr_str =~ s/\.00$/   /g;
    } else {
        dierr( "Prog error . Can't split number in totals_row\n");
    }

    # TODO $p is currently broken on equal places.
    # So blanking it :
    $p = "";
    # and $o_suppress_position_column also needs implementing.

    my $plyr_n = $z_players->{$tl->{player}} // dierr("Can't lookup player uppercased name\n");

    printout(sprintf( "%-3s %-10s%${sc_wide}s|%5s %s\n", $p, $plyr_n, $scr_str, $tl->{played} , $ppos_parts));
}

sub totals_header {
    my ($score_key, $add_ppos, $is_fia, $only_underline) = @_;

    my $ppos_parts = $add_ppos ?"| P1 | P2 | P3 | P4 | P5 | P6 ":"";

    my $sc_wide = 14;
    if ( $is_fia ) {
        $sc_wide = 9;
    }
    elsif ( is_score_times_power_100() ){
        $sc_wide = 20;
    };

    my $underline = "---------------------";
    $underline .= "-" x length($ppos_parts);

    $underline .= "-" x ( $sc_wide + 4 );

    printout(sprintf( "P   Player    %${sc_wide}s|Played%s\n", "$score_key   ", $ppos_parts ))
        if ! $only_underline;

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
    elsif ( is_score_times_power_100() ){
        $sc_wide = 20;
    };

    my $scr_str;
    my $scr = sprintf( "%0.2f" , $tl->{$score_key});
    if ( my ($intg, $deci) = $scr =~ m/^(\d+)\.(\d+)$/ ){
        $scr_str =  thousands($intg).".$deci";
        $scr_str =~ s/\.00$/   /g;
    } else {
        dierr( "Prog error . Can't split number in totals_row\n");
    }

    # TODO $p is currently broken on equal places.
    # So blanking it :
    $p = "";
    # and $o_suppress_position_column also needs implementing.

    my $plyr_n = $z_players->{$tl->{player}} // dierr("Can't lookup player uppercased name\n");

    printout(sprintf( "%-3s %-10s%${sc_wide}s|%5s %s\n", $p, $plyr_n, $scr_str, $tl->{played} , $ppos_parts));
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
        dierr( "the options --minus-points or --multi-points can't be used with --run wcc\n");
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

    my $exp_tot = expected_count($s_run);

    my $file_results = "$s_run.results";

    my $results = run_file(data_dir().$file_results);

    dierr( "Incorrect amount of results in [$file_results] . ".
        "Expected [$exp_tot] . Got [".scalar(@$results)."] \n")
            if @$results != $exp_tot;

    prdebug("$s_run : Results are ".Dumper($results), 1);

    my $results_lkup = { } ;
    my $results_lkup_top6 = { } ;
    my $results_array = [] ;
    for (my $i=0; $i<$exp_tot; $i++){
        my $resname = uc($results->[$i]);

        if ( ! exists z_drivers_or_constructors($s_run)->{$resname} ){
            dierr( "Can't find [$resname] from [$file_results] in file [".z_drivers_or_constructors_file($s_run)."]\n");
        }

        my $char3name = z_drivers_or_constructors($s_run)->{$resname};

        dierr "Duplicate result [$char3name]/[$resname] in [$file_results]\n"
            if exists $results_lkup->{$char3name};

        $results_lkup->{$char3name} = $i;

        $results_lkup_top6->{$char3name} = $i
            if $i <6; # zero based index so 0 -> 5

        push @$results_array, $char3name;
    }
    prdebug("$s_run : Results Lookup is ".Dumper($results_lkup), 1);

    # Build the "details_header"
    my $details_header = "";
    my $add_header_detail = sub ($$$){
        my ($pred) = @_;

        if ($o_suppress_detail_score) {
            $details_header .= sprintf(" %s  ", $pred);
        } else {
            $details_header .= sprintf(" %s %4s  ", $pred, "");
        }
    };
    for (my $i=0; $i<$o_score_upto_pos; $i++){
        $add_header_detail->($results_array->[$i]);
    }

    my @skip_player_errs = ();
    my $player_results_arr = [];

    my $all_players_data = get_all_players_data($s_run);

PLYR:
    for my $plyr (sort keys %$z_players){

        if ( $o_show_only_test_player ) {
            next if ($plyr ne "test-plyr" );
        } else {
            next if ( ! $o_show_test_player && $plyr eq "test-plyr");
        }

        prdebug("$s_run : Processing Player $plyr\n",0);
        my $result_line    = "";

        my $plyr_top6 = {};

        my $plyr_tot_score = 0;
        my $plyr_all_algos = { };

        my $skip_result_line = sub {
            my ($skip_reason) = @_;
            $skip_reason //= "";

            push @$player_results_arr ,
                {score => 0, player=>$plyr , round=> $s_run, top6_count => 0,
                 output => "${result_line}${skip_reason}", skipped=>1};
        };


        if ( ! exists $all_players_data->{$plyr} ){
            push @skip_player_errs,
                "$s_run : Skip [$plyr] no data in $s_run.all-players file";
            $skip_result_line->("no data");
            prdebug("  no data\n",0);
            next ;
        }

        my $plyr_data = $all_players_data->{$plyr};


        prdebug("$s_run : $plyr : ".Dumper($plyr_data),0);

        if (scalar @$plyr_data != $o_score_upto_pos){
            dierr("$s_run : player [$plyr] has  [".scalar @$plyr_data.
                "] predictions and not [$o_score_upto_pos] in file [".all_player_file($s_run)."] ");
        }

        for (my $i=0; $i<$o_score_upto_pos; $i++){


            my $plyr_pred = uc($plyr_data->[$i]);

            # get the 3 char abbrieviation :
            $plyr_pred = z_drivers_or_constructors($s_run)->{$plyr_pred} ;

            my $add_result = sub ($$$){
                my ($pred, $real_score, $disp_hundred_score) = @_;

                $plyr_tot_score += $real_score;

                my $score = is_score_times_power_100() ? $disp_hundred_score : $real_score;

                if ($o_suppress_detail_score) {
                    $result_line .= sprintf(" %s |", $pred);
                } else {
                    $result_line .= sprintf(" %s %4s |", $pred, $score);
                }
            };

            # top 6 counting.
            if ( $i < 6 && exists $results_lkup_top6->{$plyr_pred}) {
                $plyr_top6->{$plyr_pred} = $i;
            }

            if ( ! exists $results_lkup->{$plyr_pred}){
                # TODO have a look at this.
                # This is a programming error.
                # dierr( "The lookup \$results_lkup->{$plyr_pred} []should work. Programmng error"."\n");

                prdebug("$s_run : $plyr : ".($i+1)." $plyr_pred  (0)\n",0);
                $add_result->($plyr_pred,0,0);

            } else {

                my $error = abs($results_lkup->{$plyr_pred}-$i);
                _all_algo_calc( $plyr_all_algos , $plyr_pred, $i, $error );

                my ($score, $display_hundreds_score )
                   = _scorer($o_score_accuracy_sys, $o_score_times_sys, $plyr_pred, $i, $error);

                prdebug("$s_run : $plyr : ".($i+1)." $plyr_pred  : error $error : score ".int($score)."\n",0);
                $add_result->($plyr_pred, $score, $display_hundreds_score);
            }
        }

        $result_line =~ s/, $//g;


        prdebug("$s_run : $result_line",0);

        # Test the all_algos score with the currently run output score .. TODO

        push @$player_results_arr , {
                score => $plyr_tot_score, player=>$plyr , all_algos => $plyr_all_algos ,
                top6 => $plyr_top6,       top6_count => ( (scalar keys %$plyr_top6) // 0 ),
                round=> $s_run,
                output => $result_line,   skipped=>false, preds => $plyr_data };
    }

    #################
    # Post processing
    my @plyr_ordered_res ;

    if ( $o_score_leo ) {
        @plyr_ordered_res =  sort {
                                 $b->{score} <=> $a->{score}
                              || $b->{top6_count} <=> $a->{top6_count}
                              || $a->{skipped} <=> $b->{skipped}
                            } @$player_results_arr;
    }
    elsif ($o_score_karl_winner_takes_all ) {
        # This is for a secondary sort special case.
        @plyr_ordered_res =  sort {
                              $b->{all_algos}{exact}{"power-100"}{total}
                                    <=>
                                    $a->{all_algos}{exact}{"power-100"}{total}
                              || $b->{all_algos}{differential_scoring}{"power-100"}{total}
                                    <=>
                                    $a->{all_algos}{differential_scoring}{"power-100"}{total}
                              || $a->{skipped} <=> $b->{skipped}
                            } @$player_results_arr;

    } else {
        @plyr_ordered_res =  sort {
                                 $b->{score} <=> $a->{score}
                              || $a->{skipped} <=> $b->{skipped}
                            } @$player_results_arr;
    }

    my $last_diff_plyr;
    my $cmp_last_diff_score_plyr = sub {
        my ($pl_cmp) = @_;

        if ($o_score_leo ) {
            return ( $pl_cmp->{score} == $last_diff_plyr->{score}
                      && $pl_cmp->{top6_count} == $last_diff_plyr->{top6_count});
        }
        elsif ($o_score_karl_winner_takes_all ) {
            return (
                             $pl_cmp->{all_algos}{exact}{"power-100"}{total} ==
                     $last_diff_plyr->{all_algos}{exact}{"power-100"}{total}

                      &&

                             $pl_cmp->{all_algos}{differential_scoring}{"power-100"}{total} ==
                     $last_diff_plyr->{all_algos}{differential_scoring}{"power-100"}{total}
            );
        } else {
            return ( $pl_cmp->{score} == $last_diff_plyr->{score});
        }
    };

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

            $last_diff_plyr = $plyr_rh;

            $last_diff_score_highest_pos = $i;

            $add_2_real_fia_score_sharing->($i,$last_diff_score_highest_pos);

            next;
        }
        elsif ( $cmp_last_diff_score_plyr->( $plyr_rh ) ){
            $plyr_rh->{pos} = $last_diff_score_highest_pos+1;
            $add_2_real_fia_score_sharing->($i,$last_diff_score_highest_pos);
        }
        else {
            $plyr_rh->{pos} = $i+1;

            $last_diff_plyr = $plyr_rh;

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
    prdebug("$s_run : Skipped players due to errors : \n  ".join("\n  ",@skip_player_errs)."\n",0)
        if @skip_player_errs;

    my $return = {
        round          => $s_run,
        details_header => $details_header,
        plydata        => \@plyr_ordered_res,
    };

    json_out_dump($s_run,$return, false);

    return $return;
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

        dierr( "In file [$file], line :\n$ln\ndoesn't split into only 2 parts via a pipe\n") if scalar @sp != 2;

        my $dref = trim($sp[0]);
        if (length $dref != 3){
            dierr( "Unique 3-char ref for [$dref] isn't 3 characters long\n");
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
            dierr( "Unique 3 char ref [$dref] is duplicated\n");
        }
        $dedup->{$dref} = $dref;

        for my $fullname (@{$cfg->{$dref}}){
            my $fullname = uc($fullname);


            if ( exists $dedup->{$fullname} && $dedup->{$fullname} ne $dref ){
                dierr( "fullname of [$fullname] is duplicated\n");
            }
            $dedup->{$fullname} = $dref;

            my @splitname = split /\s+/, $fullname;
            for my $npart ( @splitname ){

                if (  exists $dedup->{$npart} && $dedup->{$npart} ne $dref ){
                    dierr( "part name of [$fullname] is duplicated over different drivers\n");
                }

                if ( exists $dedup_part_names->{$npart} && $dedup_part_names->{$npart} ne $dref) {
                    dierr( "part name of [$fullname] is duplicated over different drivers\n");
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
    open( my $fh, $file ) or dierr( "Can't open file $file $!\n");
    my $text = do { local( $/ ) ; <$fh> } ;
    return $text;
}

sub z_data_single {
    my ($file) = @_;

    my $data = slurp($file);

    my $ret = {};

    for my $ln (split /\n/, $data){
        $ln =  trim($ln);
        next if ! $ln;

        if ($ln !~ /^[a-z0-9_-]+$/i){
            dierr(  "$ln in file $file doesn't match A-Z, a-z, 0-9 , hyphen, underscore only format\n");
        }

        $ret->{lc($ln)} = $ln;
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
        next if $ln =~ m{^#};

        if ( my ($plyr, $preds) = $ln =~ m{(.*?):(.*)} ){

            $plyr = lc(trim($plyr));

            if ( ! exists $z_players->{$plyr} ){
                dierr( "Can't find player [$plyr] in [$all_player_filename]\n");
            }

            if ( exists $plyr_data->{$plyr} ){
                dierr( "Player [$plyr] has duplicate entries in [$all_player_filename]\n");

            }

            my $p_preds_arr = [
                map { uc(trim ($_)) }
                split ("," ,$preds )
            ];


            my $dup_preds = {};

            for my $pr ( @$p_preds_arr ){
                if ( ! exists z_drivers_or_constructors($s_run)->{$pr} ){
                    dierr( "Can't find prediction [$pr] for player [$plyr] ".
                        " in the file $all_player_filename\n");
                }

                $pr = z_drivers_or_constructors($s_run)->{$pr};

                if ( exists $dup_preds->{$pr}){
                    dierr( "duplicated prediction [$pr] for player [$plyr] ".
                        " in the file $all_player_filename\n");
                }
                $dup_preds->{$pr} = 1;
            }

            $plyr_data->{$plyr} = $p_preds_arr;
        } else {
            dierr( "Can't split line [$ln] in $all_player_filename\n");
        }
    }

    prdebug("Dump of player data from  $all_player_filename\n : ".Dumper ( $plyr_data ),2);

    return $plyr_data;
}

sub all_player_file ($) { return data_dir()."$_[0].all-players" }

sub get_out_file {
    my $suf = $o_out_file_suffix ? "-$o_out_file_suffix" : "";

    my $fn ;

    # first work out if it is in a sub dir of the output
    # rather than the default all-algorithms.
    if ( $o_out_sub_dir ) {
        $fn = check_dir(output_dir()."$o_out_sub_dir/", true);
    }
    else {
        $fn = output_all_alg_dir();
    }

    if ( $o_score_karl_winner_takes_all ) {
        $fn .= karl_winner_ta().$suf;
        return $fn;
    }

    if ( $o_score_leo ) {
        $fn .= leo_winner_ta().$suf;
        return $fn;
    }

    # Now work out if the output is split on
    # the accuracy part and the position-times part
    if ( $o_out_accuracy_sub_dir ){
        $fn .= get_scoring_accuracy_type()."/";
        check_dir($fn, true);

        $fn .=get_scoring_multiplier_type()."$suf";
    }
    else {
        $fn .= get_scoring_type_out_filename_root()."$suf";
    }

    return $fn;
}

sub get_out_file_json {
    my ($fn_root, $is_totals) = @_;

    # if is a totals file then needs the suffix.
    #
    # if it is for an individual rounds file then
    # the suffix is pointless.

    my $suf = "";
    if ($is_totals) {
        $suf = $o_out_file_suffix ? "-$o_out_file_suffix" : "";
    }
    $suf .= ".json";

    my $fn = output_json_dir()."$fn_root-";

    if ( $o_score_karl_winner_takes_all ) {
        $fn .= karl_winner_ta().$suf;
        return $fn;
    }

    if ( $o_score_leo ) {
        $fn .= leo_winner_ta().$suf;
        return $fn;
    }

    $fn .= get_scoring_type_out_filename_root()."$suf";

    return $fn;
}

sub check_dir {
    my ($dir, $mkdir) = @_;

    if ( $dir !~ m{/$} ) {
        dierr( "directory $dir doesn't have trailing slash\n");
    }

    if ($mkdir && ! -d $dir) {
        system("mkdir -p $dir") and dierr("Couldn't mkdir $dir\n");
    }

    if ( ! -d $dir) {
        dierr( "Can't find directory $dir\n");
    }

    return $dir;
}

sub round_name {
    my ($nm) = @_;
    if( my ($r, $e) = $nm =~ m{(.*?)-(race|qual)}){
        return ucfirst($r)." ".ucfirst($e);
    }
    return $nm;
}

sub _all_algo_calc {
    my ($algo_hsh, $plyr_pred, $pos, $error ) = @_;
    # calcs all the scoring combinations and creates a hash of hashes.

    # This is primarily so that the results can be sorted first by 
    #   exact and power-100
    # then they can be sorted by 
    #   diff and power-100.
    #
    # What this achieves is very close to Leo's Winner Takes All
    # but it does then order the results on the not-exact but more
    # accurate P1 to P6 predictions.

    # The only shared P places in the table should be where 
    #   exact and power-100 are exactly the same
    #   and diff and power-100 are exactly the same.
    # In reality, 2 players would need to have exactly the same predictions.
    # ( I think )

# This will do all currently 25 variants :
#    for my $accuracy ( keys %$score_accuracy_sys_lkup){
#        for my $times ( keys %$score_times_sys_lkup ){
# But we only need diff and exact  run against power-100 so :
    for my $accuracy ( "differential_scoring", "exact" ){
        for my $times ( "power-100" ){

            $algo_hsh->{$accuracy}{$times} =
                {
                    total              => 0,
                    positions          => [],
                    hundreds_positions => [],
                } if ! exists$algo_hsh->{$accuracy}{$times} ;

            my ($sc, $hundreds) = _scorer($accuracy, $times,  $plyr_pred, $pos, $error);

            $algo_hsh->{$accuracy}{$times}{total} += $sc;
            $algo_hsh->{$accuracy}{$times}{positions}[$pos] = $sc;
            $algo_hsh->{$accuracy}{$times}{hundreds_positions}[$pos] = $hundreds;
        }
    }
}

sub _scorer {
    my ($accuracy, $times, $plyr_pred, $pos, $error ) = @_;

    my $score = 0;

    # The accuracy part 
    if ( $accuracy eq "karl-8") {
        if ( $error <= 3){
            $score = 2 ** (3-$error) ;
        }
    }
    elsif ( $accuracy eq "karl-32" ) {
        if ( $error <= 5){
            $score = 2 ** (5-$error) ;
        }
    }
    elsif ( $accuracy eq "karl-96-16" ) {
        if ( $error <= 5){
            $score = 2 ** (5-$error) ;
        }

        if ($error == 0){
            # this is an exact prediction
            # score has already been multiplied by 32 from the above
            # So thus 3 x 32 = 96 
            $score = $score * 3 ;
        }
    }
    elsif ( $accuracy eq "differential_scoring" ) {
        $score = $o_drivers_count-$error;
    }
    elsif ( $accuracy eq "exact" ) {
        $score = $error ? 0 : 1;
    }
    else {
        dierr( "score-sys [$accuracy] invalid. Programming error\n");
    }

    ## The fiddle factors
    if (exists $z_minus_points->{$plyr_pred}){
        $score = -$score;
    }

    if (exists $z_multi_points->{$plyr_pred}){
        $score = $score * $o_multi_points_factor ;
    }

    # The multiplier part
    my $display_hundreds_score = $score;
    if ( is_score_times_power_100($times) ){
        $score = $score * $power_hundred_score_multiplier->{$pos};
    }
    elsif ( is_score_times_25_to_8($times) ){
        $score = $score * $real_f1_pos_scores->{$pos};
    }
    elsif ( is_score_times_9_to_1($times) ) {
        $score = $score * $real_1990_f1_pos_scores->{$pos};
    }
    elsif ( is_score_times_1_to_9($times) ) {
        $score = $score * $real_1990_f1_pos_scores_reverse->{$pos};
    }
    elsif ( is_score_times_none($times) ) {
        # do nothing. effectively :
        # $score = $score * 1;
    }
    else {
        dierr("prog. error in score_times_sys process calc");
    }

    return ( $score, $display_hundreds_score );
}

sub output_total_p {
    my ($tots_arrr, $sort_fields) = @_;

    # TODO  utility method for sorting and printing totals tables
    # with an accurate P column that works out shared
    # positions.

}

sub json_out_dump {
    my ($fn_root, $data, $is_totals) = @_;

    return;
    # TODO needs an $o_* option to switch off the json dump.

    # TODO needs a sorting of hash keys to stop
    #      some json files from having unnecessary updates.

    # TODO "z" files like the season's races, drivers, constructors and players
    #       only need 1 copy, and not 1 per different type of algo.

    dierr ("fn_root needs defining, and to be of at least 3 chars long")
        if ! defined $fn_root || length $fn_root < 3;

    my $fn_full = get_out_file_json($fn_root, $is_totals);

    burp ( $fn_full, to_json($data, {utf8 => 1, pretty => 1}));

}

sub burp {
    my( $file_name, $text) = @_ ;
    open( my $fh, ">" , $file_name ) ||
        die "can't create $file_name $!" ;
    print $fh ($text) ;
    close $fh;
}

sub csv_out_dump {
    my ($filename, $data) = @_;
    output_csv_dir();
    # TODO

}

main();
