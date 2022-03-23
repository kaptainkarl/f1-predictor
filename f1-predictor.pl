#!/usr/bin/perl
use strict; use warnings;
use Data::Dumper;
use Try::Tiny;

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

my $real_1990_f1_pos_scores = {
    0 => 9,
    1 => 6,
    2 => 4,
    3 => 3,
    4 => 2,
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


    --score-sys  karl-8, karl-32 , differential_scoring 
        defaults to karl-8
        i.e.  --score-sys karl-8 
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

    --full-output

    --tab-output
        prints out nice at the command line.
        This is the default output.

    --html-output
        generates html table output

    --run  wdc, wcc , race-name

    --drivers-count. This defaults to 20
        the current amount on the 2022 grid.
        so you shouldn't have to set it.
        unless the numbers of drivers on the grid changes.
        
    --constructors-count . This defaults to 10
        the current amount on the 2022 grid.
        so you shouldn't have to set it.
        unless the numbers of constructors on the grid changes.

    See README file for full explanation of files in the directory.

    Questions to answer.
        substitute drivers ? just ignore them ?

EOUSAGE
}

use Getopt::Long;

my $score_sys_lkup = {
    "karl-8"     => 1,
    "karl-32"    => 1,
#    difflow  => 1,
    differential_scoring => 1,
};

my $o_drivers_count       = 20;
my $o_constructors_count  = 10;

my $o_score_upto_pos = 6;

my ( $o_score_sys, $o_score_times_pos, $o_score_times_1990_pos);
my ($o_full_output, $o_tab_output, $o_html_output);
my ($o_run, $o_help, $o_debug);
my ($o_pad_results);

GetOptions (
    "pad-results"           => \$o_pad_results,
    "score-only-upto-pos=i" => \$o_score_upto_pos,
    "score-times-current"   => \$o_score_times_pos,
    "score-times-1990"      => \$o_score_times_1990_pos,
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

my $z_races   = z_data_single($ZDATA_RACES);
print "Dump of races = ".Dumper($z_races) if $o_debug;

my $z_players = z_data_single($ZDATA_PLAYERS);
print "Dump of players = ".Dumper($z_players) if $o_debug;

my ( $z_drivers, $drivers_can_use_partnames ) =
    z_data_pipe_split($ZDATA_DRIVERS);
print "Dump of drivers = ".Dumper($z_drivers) if $o_debug;
print "drivers can use part names = ".
    ($drivers_can_use_partnames ? "YES" : "NO" )."\n" if $o_debug;

my ( $z_constructors, $constructors_can_use_partnames ) =
    z_data_pipe_split($ZDATA_CONSTRUCTORS);
print "Dump of constructors = ".Dumper($z_constructors) if $o_debug;
print "constructors can use part names = ".
    ($constructors_can_use_partnames ? "YES" : "NO" )."\n" if $o_debug;

print "constructors count  = $o_constructors_count\n" if $o_debug;
print "drivers count       = $o_drivers_count\n" if $o_debug;

if (!$o_run) {
    dierr("You must define --run , with wcc , wdc or the race-name");
}

$o_score_sys = "differential_scoring" if ! $o_score_sys;
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

    #for my $ln (@$plyr_res){
    #    print "$s_run : ".$ln->{output};
    #}

}


print "\n\n\n";
print "##############################################################\n";
print "OUTPUT Section\n";
print "##############################################################\n";
print "'zzz' is an imaginary player who got a perfect score , so who's really winning is the line after 'zzz'\n\n" if exists $z_players->{zzz};

if ( $o_score_sys eq "karl-8") {
    print "Scoring is Karl's crazy 8, 4, 2, 1 \n";
    print "Get the position exactly correct then 8 points\n";
    print "Get the position 3 places out then 1 point\n";
    print "More than 3 places out, then 0 points \n";
}
elsif ( $o_score_sys eq "karl-32" ) {
    print "Not doing this scoring system . The 32,16,8,4,2,1\n";
}
elsif ( $o_score_sys eq "differential_scoring" ) {
    print "Differential scoring . i.e. Get a prediction exactly correct then it is \n";
    print " 20 - 0 = 20 points\n";
    print " Get the position say 2 places out , then it is \n";
    print " 20 - 2 = 18 points\n";
}
print "\n";
if ($o_score_times_pos){
    print "Scores are multiplied by 25,18,15,12 ... depending on the position\n";
}
elsif ($o_score_times_1990_pos) {
    print "Scores are multiplied by 9,6,4,3,2,1  depending on the position\n";
}
else {
    print "Scores are NOT multiplied depending on the position\n";
}

print "\nindividual rounds ...\n\n";
for my $pr_run (@$run_arrs) {
    for my $ln (@$pr_run){
        print $ln->{output};

#        $plyr_tots
        # push @$player_results_arr , {score => $plyr_tot_score, player=>$plyr , output => $result_line};

        die "unknown player . prog error \n" if ! $ln->{player};
        my $plyr = $ln->{player};

        $plyr_tots->{$plyr}{player} = $plyr;
        $plyr_tots->{$plyr}{total} = $plyr_tots->{$plyr}{total}   // 0;
        $plyr_tots->{$plyr}{played} = $plyr_tots->{$plyr}{played} // 0;

        $plyr_tots->{$plyr}{total} += $ln->{score};
        $plyr_tots->{$plyr}{played} ++ if ! $ln->{skipped};

    }
    print "\n\n";
}

print "##############################################################\n";
print "Tables run for ". join(", ", split (",", $o_run))."\n\n";
print "Total Score table\n";
print "-----------------\n";

my $tots_arr = [];
#  map { { player => $plyr_tots->{player} }  } ,  keys %$plyr_tots ];

for my $tpname ( keys %$plyr_tots ){
    my $tp = $plyr_tots->{$tpname};

    $tp->{ave_score} = sprintf ( "%0.2f", $tp->{total} / $tp->{played});

    push @$tots_arr, $tp;
}

#print Dumper $plyr_tots;
#print Dumper $tots_arr;

# print "
    #my @plyr_ordered_res =  sort { $b->{score} <=> $a->{score} } @$player_results_arr;

for my $tl (sort { $b->{total} <=> $a->{total} } @$tots_arr ){
    print "$tl->{player} : played = $tl->{played} : total score = $tl->{total}\n";
}


print "\nSo for players who might not have entered predictions for all rounds an Average Score table\n";
print   "--------------------\n";
for my $tl (sort { $b->{ave_score} <=> $a->{ave_score} } @$tots_arr ){
    print "$tl->{player} : played = $tl->{played} : ave score = $tl->{ave_score}\n";
}


#################################
#################################
#################################
#################################
# subs

sub expected_count ($) {
    my ($s_run) = @_;
    return $s_run eq 'wcc' ?  $o_constructors_count : $o_drivers_count ;
}

sub z_drivers_or_constructors ($) {
    my ($s_run) = @_;
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

PLYR:
    for my $plyr (sort keys %$z_players){
        print "$s_run : Processing Player $plyr\n";
        my $result_line;
        if ($o_pad_results) {
            $result_line =  sprintf( "%s : %8s : ", $s_run, $plyr );
        } else {
            $result_line =  sprintf( "%s : %s : ",  $s_run, $plyr );
        }
        my $plyr_tot_score = 0;

        my $skip_result_line = sub {
            my ($skip_reason) = @_;
            $skip_reason //= "";

            push @$player_results_arr ,
                {score => 0, player=>$plyr , output => "${result_line}${skip_reason} : Tot = 0\n", skipped=>1};
        };

        my $plyr_data;
        my $plyr_file = "$s_run.$plyr";
        try {
            $plyr_data = run_file("$DATA_DIR/$plyr_file");
        } catch {
            push @skip_player_errs,
                "$s_run : Skip [$plyr] because can't load file [$plyr_file] [$!]";
            $skip_result_line->("no data (1)");

        };
        next if ! $plyr_data;

        print "$s_run : $plyr : ".Dumper($plyr_data) if $o_debug;

        if (scalar @$plyr_data < $o_score_upto_pos){
            push @skip_player_errs,
                "$s_run : Skip [$plyr] because [".scalar @$plyr_data."] lines in file [$plyr_file] isn't [$o_score_upto_pos]";
            $skip_result_line->("no data (2)");
            next;
        }

        for (my $i=0; $i<$o_score_upto_pos; $i++){

            my $plyr_pred = uc($plyr_data->[$i]);
            if ( ! exists z_drivers_or_constructors($s_run)->{$plyr_pred} ){
                push @skip_player_errs,
                    "$s_run : Skip [$plyr] because prediction [".
                        ($i+1)."][$plyr_pred] in file [$plyr_file] not found in [".z_drivers_or_constructors_file($s_run)."]";

                $skip_result_line->("no data (3)");
                next PLYR;
            }
            # get the 3 char abbrieviation :
            $plyr_pred = z_drivers_or_constructors($s_run)->{$plyr_pred} ;

            my $add_result = sub {
                my ($pred, $score) = @_;

                if ($o_pad_results) {
                    $result_line .= sprintf("%s (%3s), ", $pred, $score);
                }else{
                    $result_line .= sprintf("%s (%s), ", $pred, $score);
                }

                $plyr_tot_score += $score;
            };

            if ( ! exists $results_lkup->{$plyr_pred}){
                # This is a programming error.
                # die "The lookup \$results_lkup->{$plyr_pred} []should work. Programmng error"."\n";

                print "$s_run : $plyr : ".($i+1)." $plyr_pred  (0)\n" if $o_debug;
                $add_result->($plyr_pred,0);

            } else {

                my $error = abs($results_lkup->{$plyr_pred}-$i);

                my $score = 0;

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

                if ($o_score_times_pos){
                    $score = $score * $real_f1_pos_scores->{$i}
                }
                elsif ($o_score_times_1990_pos) {
                    $score = $score * $real_1990_f1_pos_scores->{$i}
                }

                print "$s_run : $plyr : ".($i+1)." $plyr_pred  : error $error : score $score\n" if $o_debug;
                $add_result->($plyr_pred, $score);
            }
        }

        $result_line =~ s/, $//g;
        if ($o_pad_results) {
            $result_line .= sprintf( " : Tot = %4s\n", $plyr_tot_score );
        } else {
            $result_line .= sprintf( " : Tot = %s\n", $plyr_tot_score );
        }

        print "$s_run : $result_line" if $o_debug;

        push @$player_results_arr , {score => $plyr_tot_score, player=>$plyr , output => $result_line};
    }

    my @plyr_ordered_res =  sort { $b->{score} <=> $a->{score} } @$player_results_arr;
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

        $cfg->{trim($sp[0])} = trim($sp[1]);
    }

    # dedup in the case of Hamilton
    #   is :
    #       $dedup->{"HAM"} => "HAM"
    #       $dedup->{"LEWIS"} => "HAM"
    #       $dedup->{"HAMILTON"} => "HAM"
    #       $dedup->{"LEWIS HAMILTON"} => "HAM"

    my $dedup = {};
    my $dedup_part_names = {};

    my $can_use_partnames = true;

    for my $dref ( keys %$cfg ){

        if (length $dref != 3){
            die "Unique 3-char ref for [$dref] isn't 3 characters long\n";
        }

        my $fullname = uc($cfg->{$dref});

        if ( exists $dedup->{$dref} ){
            die "Unique 3 char ref [$dref] is duplicated\n";
        }
        $dedup->{$dref} = $dref;

        if ( exists $dedup->{$fullname} ){
            die "fullname of [$fullname] is duplicated\n";
        }
        $dedup->{$fullname} = $dref;

        my @splitname = split /\s+/, $fullname;
        for my $npart ( @splitname ){
            if ( exists $dedup->{$npart} || exists $dedup_part_names->{$npart} ){
                $can_use_partnames = false;
            }
            $dedup_part_names->{$npart} = $dref;
        }
    }

    if ($can_use_partnames) {
        for my $pr (keys %$dedup_part_names) {
            $dedup->{$pr} = $dedup_part_names->{$pr};
        }
    }

    return ($dedup, $can_use_partnames );
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

