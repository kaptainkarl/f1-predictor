#!/bin/bash

git rm -r output/2022/*

mkdir -p output/2022/favourites/
mkdir -p output/2022/all-algorithms/
mkdir -p output/2022/tlb/
mkdir -p output/2022/tlb-totals/
mkdir -p output/2022/json/
mkdir -p output/2022/csv/

./generate-all-types.pl
./generate-fav-types.pl
#./generate-tlb-types.pl

#git add output/2022/
#git commit -m "generated output"
#git push github

