Ok, I’m gonna be away, so here is a quick summary.

predictions.py
```
#!/usr/bin/python3

''' This is the piece of software in charge of tracking the accuracy of the
Big Mouths’ predictions. That shall avoidably turn out to be completely and
horribly wrong.

Copyright (c) 2022 Pylade
Licensed under the WTFPL v2 <http: www.wtfpl.net="" about=""/> '''

drivers = {
'VER': (1, 'Max Emilian Verstappen', 'Stewart'),
'VAN': (2, 'Stoffel Vandoorne', None),
'RIC': (3, 'Daniel Ricciardo', 'McLaren'),
'NOR': (4, 'Lando Norris', 'McLaren'),
'VET': (5, 'Sebastian Vettel', 'Jordan'),
'LAT': (6, 'King Nicholas Latifi', 'Williams'),
'RAI': (7, 'Kimi Räikkönen', None),
'GRO': (8, 'Romain Grosjean', None),
'MAZ': (9, 'Никита Дмитриевич Мазепин', 'Haas'),
'GAS': (10, 'Pierre Gasly', 'Minardi'),
'PER': (11, 'Sergio Pérez', 'Stewart'),
'NAS': (12, 'Felipe Nasr', None),
'MAL': (13, 'Pastor Maldonado', None),
'ALO': (14, 'Fernando Alonso Díaz', 'Toleman'),
'LEC': (16, 'Charles Leclerc', 'Ferrari'),
'STR': (18, 'Lance Stroll', 'Jordan'),
'TSU': (22, 'Yuki Tsunoda', 'Minardi'),
'ALB': (23, 'Alexander Albon', 'Williams'),
'ZHO': (24, 'Zhou Guanyu', 'Sauber'),
'OCO': (31, 'Esteban Ocon', 'Toleman'),
'HAM': (44, 'Sir Lewis Hamilton', 'Tyrell'),
'MSC': (47, 'Mick Schumacher', 'Haas'),
'SAI': (55, 'Carlos Sainz Jr', 'Ferrari'),
'RUS': (63, 'George Russell', 'Tyrell'),
'BOT': (77, 'Valtteri Bottas', 'Sauber')
}

def continuous_scoring(stand, pred):
if len(pred) != len(stand):
raise IndexError('inconsistent number of drivers')
score = 0
for i in range(len(stand)):
score += abs(pred.index(stand[i]) - i)
return score

def karls_scoring(stand, pred):
if len(pred) != len(stand):
raise IndexError('inconsistent number of drivers')
score = 0
tally = {0: 8, 1: 4, 2: 2, 3: 1}
for i in range(len(stand)):
diff = abs(pred.index(stand[i]) - i)
if diff in tally:
score += tally[diff]
return score

with open('standings.csv') as file:
standings = file.read().strip().split(',')
for d in standings:
if d not in drivers:
raise ValueError('unknown driver in standings.csv')

predic = dict()
with open('predictions.csv') as file:
for p in file.readlines():
ps = p.strip().split(',')
for d in ps[1:]:
if d not in drivers:
raise ValueError('unknown driver in predictions.csv')
predic[ps[0]] = ps[1:]

print(predic)

for p in predic:
try:
print('Karl’s scoring:', p, karls_scoring(standings, predic[p]))
print('Conituous scoring:', p,
continuous_scoring(standings, predic[p]))
print('Reverse continuous scoring:', p,
400 - continuous_scoring(standings, predic[p]))
except IndexError:
pass
```

predictions.csv
```
Bill,HAM,VER,RUS,LEC,NOR,SAI,PER,RIC,GAS,ALO,VET,OCO,STR,TSU,BOT,ZHO,ALB,LAT,MSC,MAZ
Leo,RUS,VER,HAM,SAI,LEC,ALO,PER,RIC,NOR,GAS,OCO,ALB,TSU,VET,STR,MSC,ZHO,BOT,LAT,MAZ
Pylade,LEC,VER,SAI,RIC,RUS,NOR,HAM,ALO,PER,GAS,OCO,VET,STR,BOT,LAT,ALB,TSU,MSC,ZHO,MAZ
TLB
Karl,VER,RUS,LEC,HAM,SAI,PER,NOR,RIC,ALO,OCO,GAS,ALB,TSU,LAT,VET,STR,BOT,MSC,ZHO,MAZ
Ray,RUS
```

standings.csv
```
VER,PER,HAM,RUS,LEC,SAI,RIC,NOR,ALO,OCO,TSU,GAS,VET,STR,LAT,ALB,BOT,ZHO,MSC,MAZ
```

Yes, I had a bit of useless fun with the driver list.
