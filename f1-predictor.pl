#!/usr/bin/perl
use strict; use warnings;
use Data::Dumper;
use Try::Tiny;

sub true {1}
sub false {0}

# FIXED constants.
my $DATA_DIR = "./";
my $DRIVER_COUNT = 20;
my $CONSTRUCTORS_COUNT = 10;

my $ZDATA_DRIVERS       = 'zdata.drivers';
my $ZDATA_CONSTRUCTORS  = 'zdata.constructors';
my $ZDATA_RACES         = 'zdata.races';
my $ZDATA_PLAYERS       = 'zdata.players';

#my $CURRENT_DRIVER_POS_FILE='constructor-current-positions.dat';
#my $CURRENT_DRIVER_POS_FILE='driver-current-positions.dat';

sub usage {
die <<EOUSAGE;
    --score-only-up-to-position  with integer from 1 to 20 for drivers
        or 1 to 10 for constructors.

        i.e. --score-only-up-to-position  5
            would only score the top 5 places for where they are.

    --score-sys  karl or difflow or diffhigh
        defaults to difflow
        i.e.  --score-sys karl 
        would run the 8,4,2,1 scoring system.

    --tab-output
        prints out nice at the command line.
        This is the default output.

    --html-output
        generates html table output

    --run  wdc, wcc , race-name

    --drivers-count . This defaults to 20
        the current amount on the 2022 grid.
        so you shouldn't have to set it.
        unless the numbers of drivers on the grid changes.
        
    --constructors-count . This defaults to 10
        the current amount on the 2022 grid.
        so you shouldn't have to set it.
        unless the numbers of constructors on the grid changes.


    you can't have a player with the name of "result" because :

    wcc.result
    wdc.result 
    bahrain.result
    ...
    abudhabi.result
    is reserved for well the results !

    The player's predictions are stored :
    wdc.player-name

    player names can't have spaces in them. a-z , underscores, hyphens only.
    preferably all lower-case.


    Questions to answer.
        substitute drivers ? just ignore them ?

EOUSAGE
}

use Getopt::Long;

my $o_score_upto_pos;
my $o_score_sys;
my $o_tab_out;
my $o_html_out;
my $o_run;
my $o_help;

GetOptions (
#    "i|ip|iprange=s" => \$nmap_iprange,
#    "a|args=s"       => \$nmap_args,
#    "t|timer=s"      => \$timer,
    "run=s"          => \$o_run
    "h|help"         => \$o_help,
) or usage();

usage() if $o_help;
















process_predictions();


sub process_predictions {
    my ($pred_type) = @_;
    # pred_type , wdc, 

    my ( $dlk, $can_use_partnames ) = config_lookup();

    print Dumper($dlk);
    print "\n key count = ".scalar(keys %$dlk)."\n";
    print "\n can use part names = ".($can_use_partnames ? "YES" : "NO" )."\n";

    opendir(DIR, $DATA_DIR) or die $!;

    # All users results :
    my $results = [];

    while (my $file = readdir(DIR)) {

        # user's results.
        #  for drivers this is 
        #  { HAM => { predict => 2, score => 8 } }
        my $user = {};

        # Use a regular expression to ignore files beginning with a period
        next if ($file =~ m/^\./);
        next if ! -f $file || $file !~ /\.txt$/;

	print "processing $file\n";
        my $user_data = slurp("$DATA_DIR/$file");

        #print $user_data."\n";




        push @$results, $user;
    }

    closedir(DIR);

}

sub config_lookup {

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

    my $cfg = zdata_drivers();


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
            # if ( ! $can_use_partnames || exists $dedup->{$npart} ){
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

sub zdata_drivers {
# TODO should really be in an easily editable file.
#    i.e. slurp this is $CONFIG_DAT_FILE
#    pipe separated like so :
#   HAM|Lewis Hamilton

# for constructors could be 
#   MER|Mercedes
#   RDB|Red Bull
#   AFT|Alpha Tauri
#  etc.

    slurp(


    return {
#        LND => 'Lewis NOT A DRIVER Hamilton',
        HAM => 'Lewis Hamilton',
        BOT => 'Valtteri Bottas',
        VER => 'Max Verstappen',
        PER  => 'Sergio Perez',
        RIC => 'Daniel Ricciardo',
        NOR => 'Lando Norris',
        VET => 'Sebastian Vettel',
        STR => 'Lance Stroll',
        ALO => 'Fernando Alonso',
        OCO => 'Esteban Ocon',
        LEC => 'Charles Leclerc',
        SAI => 'Carlos Sainz',
        GAS => 'Pierre Gasly',
        TSU => 'Yuki Tsunoda',
        MSC => 'Mick Schumacher',
        MAZ => 'Nikita Mazepin',
        RUS => 'George Russell',
        LAT => 'Nicholas Latifi',
        ZHO => 'Guanyu Zhou',
        ALB => 'Antonio Giovinazzi',
    }
}


