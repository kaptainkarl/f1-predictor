#!/bin/bash

git rm -r output/2022/*
rm -r output/2022/*

./generate-all-types.pl
./generate-fav-types.pl
./generate-bill-types.pl
# ./generate-bill-tlb-types.pl
./generate-leo-types.pl

