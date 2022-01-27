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

    --score-sys  karl or difflow or diffhigh
        defaults to difflow
        i.e.  --score-sys karl 
        would run the 8,4,2,1 scoring system.

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
    karl     => 1,
    difflow  => 1,
    diffhigh => 1,
};

my $o_drivers_count       = 20;
my $o_constructors_count  = 10;
my ($o_score_upto_pos, $o_score_sys);
my ($o_full_output, $o_tab_output, $o_html_output);
my ($o_run, $o_help, $o_debug);

GetOptions (
    "score-only-upto-pos=i" => \$o_score_upto_pos,
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

if ($o_run ne 'wcc' && $o_run ne 'wdc' && ! exists $z_races->{$o_run}){
    dierr("[--run $o_run] is not valid. You must define --run , with wcc , wdc or a valid race-name");
}

if ( defined $o_score_upto_pos ){
    my $cmp_tot = expected_count();

    if ( $o_score_upto_pos < 1 or $o_score_upto_pos > $cmp_tot){
        dierr("For [--run $o_run] you cannot define a [--score-only-upto-pos of $o_score_upto_pos], the max is $cmp_tot\n");
    }
} else {
    $o_score_upto_pos = expected_count();
}
print "score_upto_pos      = $o_score_upto_pos\n" if $o_debug;

$o_score_sys = "difflow" if ! $o_score_sys;
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



process();

#################################
# subs

sub expected_count {
    return $o_run eq 'wcc' ?  $o_constructors_count : $o_drivers_count ;
}

sub z_drivers_or_constructors {
    return $o_run eq 'wcc' ?  $z_constructors : $z_drivers;
}

sub z_drivers_or_constructors_file {
    return $o_run eq 'wcc' ?  $ZDATA_CONSTRUCTORS : $ZDATA_DRIVERS;
}

sub process{

    # is it driver or constructor ?
    # races are only driver.

    my $exp_tot = expected_count();

    my $file_results = "$o_run.results";

    my $results = run_file($file_results);

    print "Results are ".Dumper($results) if $o_debug;

    my $results_lkup = { } ;
    for (my $i=0; $i<$exp_tot; $i++){
        my $resname = uc($results->[$i]);

        if ( ! exists z_drivers_or_constructors()->{$resname} ){
            die "Can't find [$resname] from [$file_results] in file [".z_drivers_or_constructors_file()."]\n";
        }

        $results_lkup->{z_drivers_or_constructors()->{$resname}}=$i;

    }
    print "Results Lookup is ".Dumper($results_lkup) if $o_debug;

    if (scalar @$results != $exp_tot){
        die "The results file [$file_results] has [".scalar @$results."] rows and not [$exp_tot]\n";
    }

# Name => [
#                {   
#                },
#
#            ]
    my $player_scores = {};

    my @skip_player_errs = ();

PLYR:
    for my $plyr (sort keys %$z_players){
        print "Processing Player $plyr\n";

        my $plyr_data;
        my $plyr_file = "$o_run.$plyr";
        try {
            $plyr_data = run_file("$DATA_DIR/$plyr_file");
        } catch {
            push @skip_player_errs,
                "Skip [$plyr] because can't load file [$plyr_file] [$!]";
        };
        next if ! $plyr_data;

        print Dumper($plyr_data) if $o_debug;

        if (scalar @$plyr_data != $exp_tot){
            push @skip_player_errs,
                "Skip [$plyr] because [".scalar @$plyr_data."] lines in file [$plyr_file] isn't [$exp_tot]";
            next;
        }

        # TODO here 

        for (my $i=0; $i<$o_score_upto_pos; $i++){
            my $plyr_pred = uc($plyr_data->[$i]);
            if ( ! exists z_drivers_or_constructors()->{$plyr_pred} ){
                push @skip_player_errs,
                    "Skip [$plyr] because prediction [".
                        ($i+1)."][$plyr_pred] in file [$plyr_file] not found in [".z_drivers_or_constructors_file()."]";

                next PLYR;
            }
            # get the 3 char abbrieviation :
            $plyr_pred = z_drivers_or_constructors()->{$plyr_pred} ;

            if ( ! exists $results_lkup->{$plyr_pred}){
                # This is a programming error.
                die 'The lookup $results_lkup->{$plyr_pred} should work. Programmng error'."\n";
            }





        }


    }
    print "Skipped players due to errors : \n  ".join("\n  ",@skip_player_errs)."\n"
        if @skip_player_errs;
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

