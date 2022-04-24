#!/bin/bash

git rm -r output/2022/*
rm -r output/2022/*
./generate-both.bash

git add output/2022/
git commit -m "Generated output"
git push github
git push origin

