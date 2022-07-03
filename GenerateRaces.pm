package GenerateRaces;
use strict; use warnings;


our $RUNS =  {
    ALL   => "britain-qual,canada-race,canada-qual,baku-race,baku-qual,monaco-race,monaco-qual,spain-race,spain-qual,miami-race,miami-qual,enzo-race,enzo-sprint,enzo-qual,australia-race,australia-qual,jeddah-race,jeddah-qual,bahrain-race,bahrain-qual",

    QUAL  => "britain-qual,canada-qual,baku-qual,monaco-qual,spain-qual,miami-qual,enzo-qual,australia-qual,jeddah-qual,bahrain-qual",
    RACES => "canada-race,baku-race,monaco-race,spain-race,miami-race,enzo-race,enzo-sprint,australia-race,jeddah-race,bahrain-race",

    BOT_6_RACES => "canada-bottom-6-race,baku-bottom-6-race,monaco-bottom-6-race",
    BOT_6_QUAL  => "britain-bottom-6-qual,canada-bottom-6-qual,baku-bottom-6-qual,monaco-bottom-6-qual",
    BOT_6_ALL   => "britain-bottom-6-qual,canada-bottom-6-race,canada-bottom-6-qual,baku-bottom-6-race,baku-bottom-6-qual,monaco-bottom-6-race,monaco-bottom-6-qual",
};

1;
