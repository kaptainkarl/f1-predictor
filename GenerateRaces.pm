package GenerateRaces;
use strict; use warnings;


our $RUNS =  {
    ALL   => "monaco-race,monaco-qual,spain-race,spain-qual,miami-race,miami-qual,enzo-race,enzo-sprint,enzo-qual,australia-race,australia-qual,jeddah-race,jeddah-qual,bahrain-race,bahrain-qual",
    QUAL  => "monaco-qual,spain-qual,miami-qual,enzo-qual,australia-qual,jeddah-qual,bahrain-qual",
    RACES => "monaco-race,spain-race,miami-race,enzo-race,enzo-sprint,australia-race,jeddah-race,bahrain-race",
    BOT_6_RACES => "monaco-bottom-6-race",
    BOT_6_QUAL  => "monaco-bottom-6-qual",
    BOT_6_ALL   => "monaco-bottom-6-race,monaco-bottom-6-qual",
};

1;
