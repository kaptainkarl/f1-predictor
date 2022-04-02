#!/bin/bash

git rm output/2022/favourites/*
git rm output/2022/all-algorithms/*

./generate-all-types.pl
./generate-fav-types.pl

git add output/2022/favourites/
git add output/2022/all-algorithms/

git commit -m "generated output"

git push github



