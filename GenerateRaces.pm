package GenerateRaces;
use strict; use warnings;

our $RUNS =  {
    ALL   => "hungary-qual,france-race,france-qual,austria-race,austria-sprint,austria-qual,britain-race,britain-qual,canada-race,canada-qual,baku-race,baku-qual,monaco-race,monaco-qual,spain-race,spain-qual,miami-race,miami-qual,enzo-race,enzo-sprint,enzo-qual,australia-race,australia-qual,jeddah-race,jeddah-qual,bahrain-race,bahrain-qual",

    QUAL  => "hungary-qual,france-qual,austria-qual,britain-qual,canada-qual,baku-qual,monaco-qual,spain-qual,miami-qual,enzo-qual,australia-qual,jeddah-qual,bahrain-qual",
    RACES => "france-race,austria-race,austria-sprint,britain-race,canada-race,baku-race,monaco-race,spain-race,miami-race,enzo-race,enzo-sprint,australia-race,jeddah-race,bahrain-race",

    BOT_6_RACES => "france-bottom-6-race,austria-bottom-6-race,austria-bottom-6-sprint,britain-bottom-6-race,canada-bottom-6-race,baku-bottom-6-race,monaco-bottom-6-race",
    BOT_6_QUAL  => "hungary-bottom-6-qual,france-bottom-6-qual,austria-bottom-6-qual,britain-bottom-6-qual,canada-bottom-6-qual,baku-bottom-6-qual,monaco-bottom-6-qual",
    BOT_6_ALL   => "hungary-bottom-6-qual,france-bottom-6-race,france-bottom-6-qual,austria-bottom-6-race,austria-bottom-6-sprint,austria-bottom-6-qual,britain-bottom-6-race,britain-bottom-6-qual,canada-bottom-6-race,canada-bottom-6-qual,baku-bottom-6-race,baku-bottom-6-qual,monaco-bottom-6-race,monaco-bottom-6-qual",
};

1;
