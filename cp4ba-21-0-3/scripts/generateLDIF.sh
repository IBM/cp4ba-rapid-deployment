#!/bin/bash
###############################################################################
#
# Licensed Materials - Property of IBM
#
# (C) Copyright IBM Corp. 2022. All Rights Reserved.
#
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
###############################################################################

# check if pwgen has been installed
type pwgen > /dev/null 2>&1
if [ $? -eq 1 ]; then
  echo "Please install pwgen utility to continue."
  echo "For RHEL 7 you can download it from https://centos.pkgs.org/7/epel-x86_64/pwgen-2.08-1.el7.x86_64.rpm.html."
  exit
fi

echo -n "Generating passwords..."
pwgen -B -s 8 200 -1 > password.txt

echo "done."
echo ""
echo -n "Generating LDIF file..."

rm -f cp4ba.ldif
rm -f githubpwd.txt

# read password file and save to an array
mapfile userpasswords < password.txt
echo -n "Total ${#userpasswords[*]} common users..."

# generate common user entries
for (( i = 1; i <= ${#userpasswords[*]}; i++)); do
  if [ $i -lt 10 ]; then
    userid="usr00$i"
  elif [ $i -ge 100 ]; then
    userid="usr$i"
  else
    userid="usr0$i"
  fi
  echo "dn: cn=${userid},dc=example,dc=com" >> cp4ba.ldif
  echo "uid: ${userid}" >> cp4ba.ldif
  echo -n "userPassword: ${userpasswords[$i - 1]}" >> cp4ba.ldif
  echo "objectclass: inetorgperson" >> cp4ba.ldif
  echo "objectclass: top" >> cp4ba.ldif
  echo "objectclass: organizationalperson" >> cp4ba.ldif
  echo "objectclass: person" >> cp4ba.ldif
  echo "objectclass: eperson" >> cp4ba.ldif
  echo "sn: ${userid}" >> cp4ba.ldif
  echo "cn: ${userid}" >> cp4ba.ldif
  echo "mail: ${userid}@example.com" >> cp4ba.ldif
  echo "displayName: USER $i" >> cp4ba.ldif
  echo "" >> cp4ba.ldif
done

# generate password details in special format to update on Github
echo -n "Generating text for updating on github..."
echo -n "usr001-usr010: " >> githubpwd.txt && for (( i = 0; i < 10; i++)); do tmp=`echo ${userpasswords[$i]}|tr '\n' ' '` ; echo -n "$tmp" >> githubpwd.txt; done && echo "" >> githubpwd.txt
echo -n "usr011-usr020: " >> githubpwd.txt && for (( i = 10; i < 20; i++)); do tmp=`echo ${userpasswords[$i]}|tr '\n' ' '` ; echo -n "$tmp" >> githubpwd.txt; done && echo "" >> githubpwd.txt 
echo -n "usr021-usr030: " >> githubpwd.txt && for (( i = 20; i < 30; i++)); do tmp=`echo ${userpasswords[$i]}|tr '\n' ' '` ; echo -n "$tmp" >> githubpwd.txt; done && echo "" >> githubpwd.txt 
echo -n "usr031-usr040: " >> githubpwd.txt && for (( i = 30; i < 40; i++)); do tmp=`echo ${userpasswords[$i]}|tr '\n' ' '` ; echo -n "$tmp" >> githubpwd.txt; done && echo "" >> githubpwd.txt 
echo -n "usr041-usr050: " >> githubpwd.txt && for (( i = 40; i < 50; i++)); do tmp=`echo ${userpasswords[$i]}|tr '\n' ' '` ; echo -n "$tmp" >> githubpwd.txt; done && echo "" >> githubpwd.txt 
echo -n "usr051-usr060: " >> githubpwd.txt && for (( i = 50; i < 60; i++)); do tmp=`echo ${userpasswords[$i]}|tr '\n' ' '` ; echo -n "$tmp" >> githubpwd.txt; done && echo "" >> githubpwd.txt 
echo -n "usr061-usr070: " >> githubpwd.txt && for (( i = 60; i < 70; i++)); do tmp=`echo ${userpasswords[$i]}|tr '\n' ' '` ; echo -n "$tmp" >> githubpwd.txt; done && echo "" >> githubpwd.txt 
echo -n "usr071-usr080: " >> githubpwd.txt && for (( i = 70; i < 80; i++)); do tmp=`echo ${userpasswords[$i]}|tr '\n' ' '` ; echo -n "$tmp" >> githubpwd.txt; done && echo "" >> githubpwd.txt 
echo -n "usr081-usr090: " >> githubpwd.txt && for (( i = 80; i < 90; i++)); do tmp=`echo ${userpasswords[$i]}|tr '\n' ' '` ; echo -n "$tmp" >> githubpwd.txt; done && echo "" >> githubpwd.txt 
echo -n "usr091-usr100: " >> githubpwd.txt && for (( i = 90; i < 100; i++)); do tmp=`echo ${userpasswords[$i]}|tr '\n' ' '` ; echo -n "$tmp" >> githubpwd.txt; done && echo "" >> githubpwd.txt  
echo -n "usr101-usr110: " >> githubpwd.txt && for (( i = 100; i < 110; i++)); do tmp=`echo ${userpasswords[$i]}|tr '\n' ' '` ; echo -n "$tmp" >> githubpwd.txt; done && echo "" >> githubpwd.txt
echo -n "usr111-usr120: " >> githubpwd.txt && for (( i = 110; i < 120; i++)); do tmp=`echo ${userpasswords[$i]}|tr '\n' ' '` ; echo -n "$tmp" >> githubpwd.txt; done && echo "" >> githubpwd.txt  
echo -n "usr121-usr130: " >> githubpwd.txt && for (( i = 120; i < 130; i++)); do tmp=`echo ${userpasswords[$i]}|tr '\n' ' '` ; echo -n "$tmp" >> githubpwd.txt; done && echo "" >> githubpwd.txt  
echo -n "usr131-usr140: " >> githubpwd.txt && for (( i = 130; i < 140; i++)); do tmp=`echo ${userpasswords[$i]}|tr '\n' ' '` ; echo -n "$tmp" >> githubpwd.txt; done && echo "" >> githubpwd.txt  
echo -n "usr141-usr150: " >> githubpwd.txt && for (( i = 140; i < 150; i++)); do tmp=`echo ${userpasswords[$i]}|tr '\n' ' '` ; echo -n "$tmp" >> githubpwd.txt; done && echo "" >> githubpwd.txt  
echo -n "usr151-usr160: " >> githubpwd.txt && for (( i = 150; i < 160; i++)); do tmp=`echo ${userpasswords[$i]}|tr '\n' ' '` ; echo -n "$tmp" >> githubpwd.txt; done && echo "" >> githubpwd.txt  
echo -n "usr161-usr170: " >> githubpwd.txt && for (( i = 160; i < 170; i++)); do tmp=`echo ${userpasswords[$i]}|tr '\n' ' '` ; echo -n "$tmp" >> githubpwd.txt; done && echo "" >> githubpwd.txt  
echo -n "usr171-usr180: " >> githubpwd.txt && for (( i = 170; i < 180; i++)); do tmp=`echo ${userpasswords[$i]}|tr '\n' ' '` ; echo -n "$tmp" >> githubpwd.txt; done && echo "" >> githubpwd.txt  
echo -n "usr181-usr190: " >> githubpwd.txt && for (( i = 180; i < 190; i++)); do tmp=`echo ${userpasswords[$i]}|tr '\n' ' '` ; echo -n "$tmp" >> githubpwd.txt; done && echo "" >> githubpwd.txt  
echo -n "usr191-usr200: " >> githubpwd.txt && for (( i = 190; i < 200; i++)); do tmp=`echo ${userpasswords[$i]}|tr '\n' ' '` ; echo -n "$tmp" >> githubpwd.txt; done && echo "" >> githubpwd.txt    

echo "done."
echo ""

echo "Please use:"
echo "  password.txt for RPA chatbot."
echo "  cp4ba.ldif to import user/group to LDAP."
echo "  githubpwd.txt to update passwords on Github."
