#!/usr/bin/env bash
###
# Tools used to make things easier
#
# See https://github.com/jonyo/dev-tools-bash
#
# See README.md for additional documentation on each tool
#
###

# For use in functions only to get the container based on the passed in app
_devtools-container() {
	if [[ $1 == "netsuite" ]] || [[ $1 == "eventd" ]] || $(_devtools-is-library $1); then
		echo job-development
		return 0
	fi
	echo "$1-development"
}

# Get the app, either the first parameter or the current folder as the app
_devtools-app() {
	if [[ $1 ]]; then
		echo $1
		return 0
	fi
	echo ${PWD##*/}
}

# Print the line properly including quotes around arguments with spaces
_devtools-println() {
	local whitespace="[[:space:]]"
	local cmd=()
	for i in "$@"; do
		if [[ $i =~ $whitespace ]]; then
			i=\'$i\'
		fi
		cmd+=("$i")
	done
	echo $ ${cmd[*]}
}

# Echo then execute a command
_devtools-execute() {
	_devtools-println "$@"
	"$@"
}

# Get the phpunit command to use based on service
_devtools-phpunit() {
	if [[ $1 == "service" ]]; then
		echo "./lib/bin/phpunit"
		return 0
	elif [[ $1 == "admin" ]]; then
		echo "app/Console/cake test --configuration phpunit.xml --stderr"
		return 0
	elif [[ $1 == "public" ]]; then
		echo "./app/Vendor/bin/cake test -app app"
		return 0
	elif [[ $1 == "api" ]]; then
		echo "./app/Console/cake test -app app --stderr"
		return 0
	elif [[ $1 == "core" ]]; then
		echo "./vendor/bin/phpunit --configuration contrib/phpunit.xml"
		return 0
	fi
	echo "./vendor/bin/phpunit"
}

# Figure out what command to use to run a job in the specific app
_devtools-job() {
	local command="bin/job.php"

	if [[ $1 == "service" ]]; then
		command="job.php"
	fi
	echo "time SERVICE_DEBUG_MODE=1 php $command"
}

# Figure out what command to use to run a listener in the specific app
_devtools-listener() {
	local command="bin/listener.php"

	if [[ $1 == "service" ]]; then
		command="listener.php"
	fi
	echo "time SERVICE_DEBUG_MODE=1 php $command"
}

# Since listener does not do it for us... list all the listeners in the app
_devtools-listener-list() {
	local path="src/Listener"

	if [[ $1 == "service" ]]; then
		path="Zumba/Event/Listener"
	fi
	if [[ ! -d "$ZUMBA_APPS_REPO_PATH/$1/$path" ]]; then
		echo Could not find listeners for the requested app.
		return 0
	fi
	echo Available Listeners for $1:
	echo ----------------------------------
	for entry in "$ZUMBA_APPS_REPO_PATH/$1/$path"/*.php; do
		echo  - $(basename $entry .php)
	done
	echo ----------------------------------
}

# run a single command on a service, just need
# _devtools-some-helper-name app [extra command line options to pass]
_devtools-ssh-command() {
	local cmd=$(${1} ${2})
	shift
	local service="${1}"
	local container=$(_devtools-container $service)
	shift
	_devtools-execute dev container-ssh --container $container --user $service --command "cd /var/www/$service/current && $cmd $*"
}

# same as _devtools-ssh-command but force job-development for container
_devtools-ssh-command-job() {
	local cmd=$(${1} ${2})
	shift
	local service="${1}"
	local container="job-development"
	shift
	_devtools-execute dev container-ssh --container $container --user $service --command "cd /var/www/$service/current && $cmd $*"
}

# see if the library is one of the main libraries
_devtools-is-library() {
	local libs=(core elasticsearchunit mongounit primer swivel symbiosis zql zumba-coding-standards vanilla-js-connect)
	for lib in ${libs[@]}; do
		if [[ $1 == $lib ]]; then
			true
			return 0
		fi
	done

	false
}

# Shortcut for invoking one of the DB helpers, requires helper name (either sequelpro or tableplus)
_devtools-db-helper() {
	if [[ ! $AWS_SESSION_TOKEN ]]; then
		echo
		echo You forgot to copy/paste aws session export lines!
		echo
		echo SEE: https://github.com/zumba/onboarding#getting-a-token
		echo
		return 0
	fi
	local helper=$1
	local role='engineer'
	local env='dev'
	local environment="${env}elopment"
	local whitespace="[[:space:]]"
	shift
	for i in "$@"; do
		if [[ $i == 'pro' ]]; then
			env=$i
			environment="${env}duction"
		elif [[ $i == 'sta' ]]; then
			env=$i
			environment="${env}ging"
		else
			role=$i
		fi
	done
	_devtools-execute dev $helper --environment $environment --username iam_${role}_${env}
}

# usage: dev-1804-create <APP-NAME>
dev-1804-create() {
	local app=$(_devtools-app $@)
	local container=$(_devtools-container $app)
	_devtools-execute dev create-container --container ${container}-1804 --image bionic --no-prebuilt --grains xdebug --force
	dev-1804-rename $app
}

# usage: dev-1804-create-prebuilt <APP-NAME>
dev-1804-create-prebuilt() {
	local app=$(_devtools-app $@)
	local container=$(_devtools-container $app)
	_devtools-execute dev create-container --container ${container}-1804 --image-server office --use-custom-prebuilt  --force
	dev-1804-rename $app
}

# usage: dev-1804-rename <APP-NAME>
dev-1804-rename() {
	local app=$(_devtools-app $@)
	local container=$(_devtools-container $app)
	_devtools-execute dev rename-container --container ${container}-1804 --container-new-name $container
}

# usage: dev-1804-rename-all
dev-1804-rename-all() {
	local containers=$(dev list-containers | awk '/-development-1804/ { print $2 }')
	local app
	for container in $containers; do
		app=${container%-development-1804}
		dev-1804-rename $app
	done
}

# usage: dev-1804-dns
dev-1804-dns() {
	_devtools-execute dev update-host-dns-1804
}

# usage: dev-create <APP-NAME>
# deprecated... probably... creates it the old way
dev-create() {
	local app=$(_devtools-app $@)
	local container=$(_devtools-container $app)
	_devtools-execute dev create-container --container $container --build-app --grains xdebug --no-prebuilt --force
}

# usage: dev-build <APP-NAME|CONTAINER> <optional: APP-NAME>
dev-build() {
	local app=$(_devtools-app $@)
	local container=$(_devtools-container $app)
	if [[ $2 ]]; then
		app=$2
	fi
	if $(_devtools-is-library $app); then
		# no built-in build for library apps, run composer install
		_devtools-execute dev container-ssh --container job-development --user $app --command "cd /var/www/$app/current && composer install"
	else
		_devtools-execute dev build-app --container $container --app $app
	fi
	if [[ $app == 'eventd' ]]; then
		# Also build service, userservice, and rulesengineservice in jobs box
		echo
		echo Since building eventd, also build other apps in job box so eventd can properly delegate...
		echo
		_devtools-execute dev build-app --container job-development --app service
		_devtools-execute dev build-app --container job-development --app userservice
		_devtools-execute dev build-app --container job-development --app rulesengineservice
	fi
}

# usage: dev-init library
dev-init() {
	local lib=$(_devtools-app $@)
	if ! $(_devtools-is-library $lib); then
		echo Invalid library $lib
		return 0
	fi
	# TODO: If this is ever baked in to main dev tools, remove this
	_devtools-execute dev container-ssh --container job-development --command "useradd -m $lib && mkdir /home/$lib/.composer/ && cp /home/service/.composer/auth.json /home/$lib/.composer && chown -R $lib:$lib /home/$lib/.composer"
	echo
	echo Note: you may see a few errors here, that is normal since creating an app not normally meant to exist by itself
	echo in job-development container..
	echo
	_devtools-execute dev build-app --container job-development --app $lib
	echo
	echo You should not see errors after this point...
	echo
	_devtools-execute dev container-ssh --container job-development --command "[ ! -L \"/var/www/$lib/current\" ] && ln -s /var/www/$lib/releases/local_source /var/www/$lib/current"
	dev-build $lib
}

# usage: dev-ssh <OPTIONAL: APP-NAME> <OPTIONAL: USER or 1 to use APP-NAME for user>
dev-ssh() {
	local container user
	if [[ $1 ]]; then
		container="--container $(_devtools-container $1)"
	fi
	if [[ $2 ]]; then
		if [[ $2 == "1" ]]; then
			user="--user $1"
		else
			user="--user $2"
		fi
	fi

	if [[ $container ]]; then
		_devtools-execute dev container-ssh $container $user
	else
		_devtools-execute dev ssh
	fi
}

# usage: dev-log <APP-NAME> <OPTIONAL: LINES>
dev-log() {
	local lines log
	local app=$(_devtools-app $@)
	local numeric='^[0-9]+$'
	if [[ $app =~ $numeric ]]; then
		lines=app
		app=$(_devtools-app)
	fi
	local container=$(_devtools-container $app)
	if [[ $2 ]]; then
		lines="--lines $2"
	fi
	if [[ $app == "rulesengineservice" ]]; then
		log="--log /tmp/rulesengine.log"
	elif [[ $app == "userservice" ]]; then
		log="--log /tmp/user.log"
	fi
	_devtools-execute dev show-log --container $container $log $lines
}

# usage: dev-test <APP-NAME>
dev-test() {
	local app=$(_devtools-app $@)
	local container=$(_devtools-container $app)
	local phpunit=$(_devtools-phpunit $app)
	local commands="cd /var/www/$app/current; alias phpunit=\\\"${phpunit}\\\";"
	_devtools-execute dev ssh --command "lxc exec $container -- su - $app -c \"echo '$commands . ~/.profile;' >> /home/$app/.bash_profile\""
	_devtools-execute dev-ssh $app $app
	_devtools-execute dev ssh --command "lxc exec $container -- su - $app -c \"rm /home/$app/.bash_profile\""
}

# usage: dev-phpunit <APP-NAME> <OPTIONAL: PHPUNIT ARGUMENT(S)>
dev-phpunit() {
	local extra=""
	if [[ "$#" == "1" ]]; then
		# Nothing else passed, depending on app, add what is needed to run all tests
		if [[ $1 == 'admin' ]]; then
			extra=" app TestAllTheThings"
		elif [[ $1 == 'public' ]]; then
			extra=" app AllTests"
		elif [[ $1 == "api" ]]; then
			extra=" app ApiTests"
		fi
	fi
	_devtools-ssh-command _devtools-phpunit $* $extra
}

# usage: dev-clear
dev-clear() {
	_devtools-execute dev clear-caches
}

# usage: dev-restart (requires onboarding to be symlinked from main app folder)
dev-restart() {
	echo "Halting the VM..."
	# Actually halt the VM.  Don't do dev stop - that only suspends the VM and you may end up with same problems once
	# it starts back up
	cd $ZUMBA_APPS_REPO_PATH/onboarding &&
		vagrant halt &&
		cd - &&
		echo "Starting things back up..." &&
		# Use `vagrant halt` then `dev start` that way all the initialization stuff that happens in `dev start` runs (unlike
		# doing just a `vagrant reload`)
		_devtools-execute dev start
}

dev-restart-apache() {
	local container

	echo "Restarting apache..."
	local containers=$(dev list-containers | awk '/-development/ { print $2 }')
	for container in $containers; do
		echo "Restarting apache in container $container"
		_devtools-execute dev container-ssh --container "$container" --command "systemctl restart apache2"
	done
}

# Usage: dev-xdebug-init
dev-xdebug-init() {
	local vsconfig=$(cat $_DEVTOOLS_ROOT/vscode-config.json)
	local vsconfigJobs=$(cat $_DEVTOOLS_ROOT/vscode-config-jobs.json)
	# note: one that uses jobs box must be first to init jobs box port
	local apps=(netsuite admin api public rulesengineservice service userservice primer convention core onlineclassstudent)
	local nextport=9000
	local containers=()
	local ports=()
	local jobPort=9000
	local xdebugLine="xdebug:"
	local saltPath="/etc/salt/grains"
	local appconfig appfolder cmd container port lineFound

	for app in ${apps[@]}; do
		container=$(_devtools-container $app)

		# make sure to use same port for specific container
		port=0
		for i in ${!containers[@]}; do
			if [[ ${containers[$i]} == $container ]]; then
				port=${ports[$i]}
			fi
		done
		if [[ $port == "0" ]]; then
			# port for container not set yet so use next port
			port=$nextport
			ports+=($port)
			containers+=($container)
			((nextport++))
		fi

		appfolder="$ZUMBA_APPS_REPO_PATH/$app/"
		if [[ ! -d $appfolder ]]; then
			echo "$appfolder does not exist, skipping..."
			echo
			continue
		fi
		echo "Updating things for $container : $app using port $port"
		echo "Updating vscode configuration..."
		[ -d "${appfolder}.vscode/" ] || mkdir -p "${appfolder}.vscode/"
		if [[ $app == *"service" ]]; then
			echo "Using dual configs to listen to jobs box if needed..."
			echo "$(printf "$vsconfigJobs" $app $port $app $jobPort $app)" >"${appfolder}.vscode/launch.json"
		else
			echo "$(printf "$vsconfig" $port $app)" >"${appfolder}.vscode/launch.json"
		fi

		echo "Making sure xdebug is enabled in $container grains..."
		cmd="grep '$xdebugLine' $saltPath"
		lineFound=$(dev container-ssh --container $container --command "$cmd")
		if [[ $lineFound == "" ]]; then
			echo "xDebug grain not set, adding grain..."
			cmd="echo 'xdebug: True' >> $saltPath"
			dev container-ssh --container $container --command "$cmd"
		elif [[ $lineFound == *"False"* ]]; then
			echo "xDebug grain set to false, will change to true..."
			cmd="sed -i 's/xdebug: False/xdebug: True/g' $saltPath"
			dev container-ssh --container $container --command "$cmd"
		elif [[ $lineFound == *"True"* ]]; then
			echo "xDebug grain already enabled. :)"
		else
			echo "ERROR: Unexpected grain, will not try to add automatically."
			echo
			echo "Unexpected line:"
			echo $lineFound
			echo
			echo "You will need to fix $saltPath then run salt-call state.highstate in the $container container."
			echo
			continue
		fi

		echo "Checking that xdebug is enabled in php..."
		cmd="php --version | grep Xdebug"
		lineFound=$(dev container-ssh --container $container --command "$cmd")
		if [[ $lineFound == "" ]]; then
			echo "xDebug not installed, running highstate to see if that fixes..."
			echo
			echo "This could take some time..."
			echo
			cmd="salt-call state.highstate --state-output=terse --state-verbose=False"
			dev container-ssh --container $container --command "$cmd"
			echo "done!"
			echo
		fi

		echo "Updating xdebug.ini in ${container}..."
		cmd="grep -r -l 'xdebug.client_port' /etc/php/* | xargs sed -i 's/xdebug.client_port=[0-9]\{4\}/xdebug.client_port=${port}/g'"
		dev container-ssh --container $container --command "$cmd"
	done

	echo "Restarting things so the new ports take effect..."
	dev-restart-apache

	echo
	echo ----------------------------------------------------------------------------------------------
	echo "            INSTRUCTIONS"
	echo
	echo If you have trouble with the .vscode/launch.json files showing up as changes in git:
	echo
	echo Run this line:
	echo
	echo "echo \".vscode/\" >> ~/.gitignore_global"
	echo
	echo Then, if you have never done this in the past, you may also need to run this command:
	echo
	echo "git config --global core.excludesfile ~/.gitignore_global"
	echo
	echo Note: You should only need to do the above ONCE, after that point the vscode config file will no longer show
	echo as a changed file in git in any repos.
	echo
	echo
	echo ----------------------------------------------------------------------------------------------
	echo
}

#gets the shared env
dev-env() {
	local app=$(_devtools-app $@)
	local container=$(_devtools-container $app)

	if [[ $2 ]]; then
		local cmd="grep -i $2"
	else
		local cmd="cat"
	fi

	local path=/var/www/$app/shared
	if [[ $app == service || $app == netsuite ]]; then
		path="$path/config/environment.php"
	elif [[ $app == public || $app == api ]]; then
		path="$path/app/Config/environment.php"
	else
		path="$path/.env"
	fi

	_devtools-execute dev container-ssh --container $container --command "$cmd $path"
}

# usage: dev-job app ExtraStuff
dev-job() {
	_devtools-ssh-command-job _devtools-job $*
}

# usage: dev-listener app SomeListener
dev-listener() {
	if [[ $# == '1' && -d "$ZUMBA_APPS_REPO_PATH/$1/" ]]; then
		_devtools-listener-list $1
		return 0
	fi

	_devtools-ssh-command-job _devtools-listener $*
}

# usage: dev-cp from-library to-app
dev-cp() {
	local lib=$1
	shift
	local app=$(_devtools-app $@)
	local vendor='vendor'
	local from to
	if ! $(_devtools-is-library $lib) && $app; then
		echo Invalid option for dev-cp
		echo
		echo Format:
		echo dev-cp from-library [optional: to-app name]
		echo e.g.
		echo dev-cp common service
		echo
		return 0
	fi
	from=$ZUMBA_APPS_REPO_PATH/$lib
	if [[ $app == 'admin' || $app == 'api' || $app == 'public' ]]; then
		vendor='app/Vendor'
	elif [[ $app == 'service' || $app == 'eventd' ]]; then
		vendor='lib'
	fi
	to=$ZUMBA_APPS_REPO_PATH/$app/$vendor/zumba/$lib
	if [ "$(which rsync)" != '' -a "$from" -a "$to" ]; then
		_devtools-execute rsync -aq --delete --exclude=.git/ $from $(dirname $to)
	else
		if [[ -d $to ]]; then
			_devtools-execute rm -Rf $to
		fi
		_devtools-execute cp -R $from $to
	fi
}

dev-tableplus() {
	_devtools-db-helper tableplus $@
}

dev-sequelpro() {
	_devtools-db-helper sequelpro $@
}

# Internal - initializes any extra_tools only if the env var is set to 1 for the tool and sets needed vars
_devtools-init() {
	local DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
	local filename permission
	# Load the conditional tools...
	for filename in ${DIR}/extra_tools/*.sh; do
		permission=${filename##*/}
		permission=${permission%.sh}
		permission=DEVTOOLS_$permission
		eval permission=\$$permission
		if [[ $permission == "1" ]]; then
			. $filename
		fi
	done
	# Export dir location
	export _DEVTOOLS_ROOT=$DIR
}

_devtools-init
