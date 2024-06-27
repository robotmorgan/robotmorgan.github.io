SUCCESS=0
DB_BUILD_FAIL=1
TEST_TOOLS_BUILD_FAIL=2
status_string=([0]="SUCCESS" [1]="DB BUILD FAILED" [3]="TEST TOOLS BUILD FAILED")

MAX_COMMITS=50

fail_icon='<?xml version="1.0" ?><svg height="40"  width="40" id="Layer_1" style="enable-background:new 0 0 612 792;" version="1.1" viewBox="0 0 612 792" xml:space="preserve" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink"><style type="text/css">
    .st0{fill:#E44061;}
</style><g><path class="st0" d="M562,396c0-141.4-114.6-256-256-256S50,254.6,50,396s114.6,256,256,256S562,537.4,562,396L562,396z M356.8,396   L475,514.2L424.2,565L306,446.8L187.8,565L137,514.2L255.2,396L137,277.8l50.8-50.8L306,345.2L424.2,227l50.8,50.8L356.8,396   L356.8,396z"/></g></svg>'

success_icon='<?xml version="1.0" ?><svg height="40" width="40" id="Layer_1" style="enable-background:new 0 0 612 792;" version="1.1" viewBox="0 0 612 792" xml:space="preserve" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink"><style type="text/css">
    .st0{fill:#41AD49;}
</style><g><path class="st0" d="M562,396c0-141.4-114.6-256-256-256S50,254.6,50,396s114.6,256,256,256S562,537.4,562,396L562,396z    M501.7,296.3l-241,241l0,0l-17.2,17.2L110.3,421.3l58.8-58.8l74.5,74.5l199.4-199.4L501.7,296.3L501.7,296.3z"/></g></svg>'

function generate_html () {

	if (( $1 == 0 ))
	then
		status_icon=$success_icon
	else
		status_icon=$fail_icon
	fi

	echo "<html>" > index.html
	echo "<head>" >> index.html
	echo "<title>comdb2 mac build</title>" >> index.html
	echo "</head>" >> index.html
	echo "<style>
	html {
		display: table;
		margin: auto;
	}

	body {
		display: table-cell;
		vertical-align: middle;
		background-color: LightGray;
	}
	</style>" >> index.html
	echo "<body>" >> index.html
	echo '<div style="display:flex; align-items: center;">' >> index.html
	echo "Latest mac build status" >> index.html
	echo $status_icon >> index.html
	echo "</div>" >> index.html
	echo "<ul>" >> index.html
	while IFS= read -r line; do
    	echo "<li>$line</li>" >> index.html
	done < log
	echo "</ul>" >> index.html
	echo "</body>" >> index.html
	echo "</html>" >> index.html
}

function send_status () {
	cd $basedir

	if ! test -f log; then
		echo "$latest_local_commit status: ${status_string[status]}" > log
	else
		echo "$latest_local_commit status: ${status_string[status]}\n$(cat log) " > log
	fi

	lines=$(cat log | wc -l)
	if (( lines > MAX_COMMITS ));
	then
		head -n -$MAX_COMMITS log > log
	fi
	generate_html $1
}

function shutdown () {
# cleanup and exit
	cd $basedir
	rm -rf robomorgan_comdb2
	
	needtopush=$(git diff --exit-code index.html)
	if (( needtopush == 1 ))
	then
		git add index.html log .latest_commit
		git commit -m "Add build status for $latest_commit"
		git push
	fi

	exit 0
}

basedir=$(pwd)

latest_remote_commit=$(git ls-remote https://github.com/bloomberg/comdb2.git refs/heads/main)
latest_local_commit=$(cat .latest_commit)
echo "$latest_remote_commit" | grep "$latest_local_commit" &> /dev/null
rc=$?
if (( rc == 0 ));
then
	# We've already processed this commit. Don't do it again.
	exit 0
fi

git clone https://github.com/bloomberg/comdb2.git robomorgan_comdb2
cd robomorgan_comdb2
latest_local_commit=$(git rev-parse HEAD)
echo "$latest_local_commit" > $basedir/.latest_commit

mkdir build; cd build; cmake ..

make -j4
rc=$?
if (( rc != 0 ));
then
	send_status $DB_BUILD_FAIL
	shutdown
fi

make -C tests/tools
rc=$?
if (( rc != 0 ));
then
	send_status $DB_BUILD_FAIL
	shutdown
fi

send_status $SUCCESS
shutdown
