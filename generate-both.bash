#!/bin/bash

git rm -r output/2022/*
rm -r output/2022/*

./generate-all-types.pl
./generate-fav-types.pl
./generate-bill-types.pl
./generate-closest-p1-20-detailed.pl
./generate-leo-types.pl

