#!/bin/bash
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
source ~/.profile

IFS="
"
export RUBYOPT="-KU -E utf-8:utf-8"
cd /tmp
cat << EOF > /tmp/start.ly
\\require "lys"
#(lys:start-server)
EOF

    
while read -r line
do
    until printf "" 2>>/dev/null >>/dev/tcp/localhost/1225; do sleep 0.05; done
    backend=$( echo "$line" | jq -r .backend )
    if [ "$backend" == "musicxml2ly" ]; then
        echo "$line" | jq -r .src | ~/.lyp/lilyponds/2.22.1/bin/musicxml2ly - -o hacklily.musicxml2ly.ly 2> hacklily.err 1>&2
        jq -Rs . hacklily.err > hacklily.err.json
        jq -Rsrc '{files: [.], logs: $errors, midi: ""}' hacklily.musicxml2ly.ly \
    	    --argfile errors hacklily.err.json \
    	    2> /dev/null
        continue
    fi

    echo "$line" | jq -r .src > hacklily.ly 2> /dev/null

    timeout -s15 5 lyp compile -s /tmp/hacklily.ly 2> hacklily.err 1>&2
    if [ $? -eq 137 ]; then
        echo '{"err": "Failed to render song."}'
	echo 'failed to render' >&2
        continue
    fi;

    for f in hacklily*.$backend
    do
        if [ "hacklily*.$backend" == "$f" ]; then
            echo '""' > "hacklily-null.$backend.json"
        elif [ "$backend" == "svg" ]; then
            jq -Rs . $f > $f.json 2>&1
        else
            cat $f | base64 | jq -Rs . > $f.json 2>&1
        fi
    done
    touch hacklily.midi  # Allow blank files
    cat hacklily.midi | base64 | jq -Rs . > hacklily.midi.json 2>&1
    jq -Rs . hacklily.err > hacklily.err.json
    jq -src '{files: ., logs: $errors, midi: $midi}' hacklily*.$backend.json \
	    --argfile errors hacklily.err.json \
	    --argfile midi hacklily.midi.json \
	    2> /dev/null

    rm hacklily* > /dev/null 2> /dev/null
done < "${1:-/dev/stdin}" &

bash -c "lilypond /tmp/start.ly 1>&2"
