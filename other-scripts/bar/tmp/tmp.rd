ssh db2inst1@10.100.1.2

./createGCDDB.sh GCDDB2 db2inst1
db2 activate database GCDDB2
./createGCDDB.sh GCDDB3 db2inst1
db2 activate database GCDDB3

./createAPPDB.sh AEDB2 db2inst1
db2 activate database AEDB2
./createAPPDB.sh AEDB3 db2inst1
db2 activate database AEDB3

./createBAWDB.sh BAWDB2 db2inst1
db2 activate database BAWDB2
./createBAWDB.sh BAWDB3 db2inst1
db2 activate database BAWDB3

./createICNDB.sh ICNDB2 db2inst1
db2 activate database ICNDB2
./createICNDB.sh ICNDB3 db2inst1
db2 activate database ICNDB3

./createOSDB.sh BAWTOS2 db2inst1
db2 activate database BAWTOS2
./createOSDB.sh BAWTOS3 db2inst1
db2 activate database BAWTOS3

./createOSDB.sh BAWDOCS2 db2inst1
db2 activate database BAWDOCS2
./createOSDB.sh BAWDOCS3 db2inst1
db2 activate database BAWDOCS3

./createOSDB.sh BAWDOS2 db2inst1
db2 activate database BAWDOS2
./createOSDB.sh BAWDOS3 db2inst1
db2 activate database BAWDOS3
