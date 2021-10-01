#!/bin/bash

##############################################################################################
# At any case Don't run this script in your local machine It may disturb your local codebase #
##############################################################################################

function user_from_git {
  funname=`echo "$1" | cut -d "#" -f 2`
  funname1="def $funname "
  funname2="def $funname\$"
  classname=`echo "$1" | cut -d "#" -f 1`
  filepath=`ruby -e "puts \"$classname\".gsub(/::/, '/').gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').gsub(/([a-z\d])([A-Z])/,'\1_\2').tr(\"-\", \"_\").downcase"`
  x=`grep -n -R --include=*.rb -H "$funname1" $2`
  y=`grep -n -R --include=*.rb -H "$funname2" $2`
  if [[ "$x$y" == "" ]]; then
    username=""
  else
    numlines=`echo "$x$y" | awk -F ':' '{print $1}' | wc -l`
    if [[ $numlines -eq 1 ]]; then
      filename=`echo "$x$y" | awk -F ':' '{print $1}'`
    else
      filename=`echo "$x$y" | awk -F ':' '{print $1}' | grep $filepath | head -1`
      if [[ "$filename" == "" ]]; then
        filename=`echo "$x$y" | awk -F ':' '{print $1}' | head -1`
      fi
    fi
    x=`grep -n "$funname1" $filename | head -1`
    y=`grep -n "$funname2" $filename | head -1`
    start=`echo "$x$y" | awk -F ':' '{print $1}'`
    end=`git blame -b -c -t -L $((start+1)) $filename | grep "def test_" | head -1 | awk -F '\t' '{print $4}' | sed "s/^\(.*\))\(.*\)$/\1/"`
    end=$((end-2))
    username=`git blame -w -M -b -c -t -L $start,$end $filename | sort -t$'\t' -k3 -nr | head -1 | awk -F '\t' '{print $2}' | cut -d "(" -f 2`
    ts=`git blame -w -M -b -c -t -L $start,$end $filename | awk -F'\t' '{print $3}' | awk -F' ' '{print $1}' | sort -k1 -nr | head -1`
  fi
}

function user {
  user_from_git "$1" "$2"
  linenumber=`grep -n "$1," script/test/recent_committer_exceptions.txt | awk -F':' '{print $1}'`
  if [[ "$linenumber" != "" ]]; then
    committer_exceptions_ts=`git blame -w -M -b -c -t -L $linenumber,$linenumber script/test/recent_committer_exceptions.txt | awk -F'\t' '{print $3}' | awk -F' ' '{print $1}'`
    if [[ $committer_exceptions_ts -ge $ts ]]; then
      username=`grep "$1," script/test/recent_committer_exceptions.txt | cut -d ',' -f 2`
    fi
  fi
}

function updatefirstrow {
  awk '/[a-zA-Z:]*#test_[a-zA-Z0-9_]*[?!]? = [0-9][0-9]?.[0-9][0-9] s = [.EF]/{ print $0 }' tmp/TestsData/$1 | head -1 | awk '{print "\n" $1 " " $2 " " ($3 - 13) " " $4 " " $5 " " $6}' >> tmp/TestsData/$1
}

function test_suite {
  echo "<table><tr><th>ClassName#TestName</th><th>Recent Developer</th><th>Time(Sec)</th><th>./E/F</th></tr>" >> tmp/TestsData/$MAIL
  awk -F',' '{ print $0 }' tmp/TestsData/$1 | head -30 | while read i;
  do
    echo "<tr><td>" >> tmp/TestsData/$MAIL
    str=`echo $i | cut -d ',' -f 1`
    echo "$str </td><td>" >> tmp/TestsData/$MAIL
    str=`echo $i | cut -d ',' -f 4`
    echo "$str </td><td>" >> tmp/TestsData/$MAIL
    str=`echo $i | cut -d ',' -f 2`
    echo "$str </td><td>" >> tmp/TestsData/$MAIL
    str=`echo $i | cut -d ',' -f 3`
    echo "$str </td></tr>" >> tmp/TestsData/$MAIL
  done
  echo "</table>" >> tmp/TestsData/$MAIL
}

function attachment {
  awk '/[a-zA-Z:]*#test_[a-zA-Z0-9_]*[?!]? = [0-9][0-9]?.[0-9][0-9] s = [.EF]/{ print $0 }' tmp/TestsData/$1 | tail -n +2 | sort -nrk3 | while read i;
  do
    str=`echo $i | cut -d ' ' -f 1`
    user "$str" "$2"
    str1=`echo $i | cut -d ' ' -f 3`
    str2=`echo $i | cut -d ' ' -f 6`
    echo "$str,$str1,$str2,$username" >> tmp/TestsData/$ATTACHMENT
  done
}

DATE=`date +%Y-%m-%d`

mkdir -p tmp/TestsData
ps aux | grep -e 'elasticsearch-6.2.4' | grep -v grep | awk '{print $2}' | xargs -i kill {}
elasticsearch_path=`locate -r '/elasticsearch-6.2.4$' | head -1`
$elasticsearch_path/bin/elasticsearch >> tmp/elastic.log &
git pull origin develop

bundle install
rake db:create RAILS_ENV=test TEST_ENV_NUMBER=9
rake db:generate_fixtures RAILS_ENV=test TEST_ENV_NUMBER=9
rake es_indexes:full_indexing FORCE_REINDEX=true RAILS_ENV=test TEST_ENV_NUMBER=9
rake matching:clear_and_full_index_and_refresh RAILS_ENV=test TEST_ENV_NUMBER=9

FUNCTIONAL="$DATE-functional.txt"
rake test:functionals RAILS_ENV=test TEST_ENV_NUMBER=9 TESTOPTS='-v' > tmp/TestsData/$FUNCTIONAL

UNIT="$DATE-unit.txt"
rake test:units RAILS_ENV=test TEST_ENV_NUMBER=9 TESTOPTS='-v' > tmp/TestsData/$UNIT

ENGINE="$DATE-engine.txt"
rake test:engines RAILS_ENV=test TEST_ENV_NUMBER=9 TESTOPTS='-v' > tmp/TestsData/$ENGINE

updatefirstrow "$FUNCTIONAL"
updatefirstrow "$UNIT"
updatefirstrow "$ENGINE"

ATTACHMENT="$DATE-attachment.txt"
attachment "$FUNCTIONAL" "./test/functional/"
attachment "$UNIT" "./test/unit/"
attachment "$ENGINE" "./vendor/engines/"
sort -t$',' -k2 -nr tmp/TestsData/$ATTACHMENT -o tmp/TestsData/$ATTACHMENT

MAIL="$DATE-mail.html"
echo "<!DOCTYPE html><html><head><style>table,th,td{border:1px solid black;border-collapse:collapse;}th,td{padding:5px;}th{text-align:left;}</style></head><body>" > tmp/TestsData/$MAIL
echo "<b style='color:green'>" >> tmp/TestsData/$MAIL
git log -n 1 --pretty=format:"The tests in this mail is executed at %aD, Commit Hash is %H and Commit message is %B" >> tmp/TestsData/$MAIL
echo "</b><br />" >> tmp/TestsData/$MAIL
echo "<b style='color:red'>This is to inform that the following tests are taking alot of time when compared to other and making the test suite running time more, So fix these tests ASAP</b><br />" >> tmp/TestsData/$MAIL
echo "<b style='color:green'>If you feel like this is not your test then add a new line in the file script/test/recent_committer_exceptions.txt with format ClassName#TestName,actual committer name</b><br />" >> tmp/TestsData/$MAIL
test_suite "$ATTACHMENT"
echo "</body></html>" >> tmp/TestsData/$MAIL

ruby script/test/mail.rb tmp/TestsData/$MAIL tmp/TestsData/$ATTACHMENT