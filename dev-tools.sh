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
	if [[ $1 == "netsuite" || $1 == "primer" ]]; then
		echo job-development
		return 0
	fi
	echo "$1-development"
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

# usage: dev-create <APP-NAME>
dev-create() {
	local container=`_devtools-container $1`
	_devtools-execute dev create-container --container $container --build-app --grains xdebug --no-prebuilt
}

# usage: dev-build <APP-NAME|CONTAINER> <optional: APP-NAME>
dev-build() {
	local container=`_devtools-container $1`
	local app=$1
	if [[ $2 ]]; then
		app=$2
	fi
	if [[ $app == "primer" ]]; then
		# composer install
		_devtools-execute dev container-ssh --container job-development --user primer --command "cd /var/www/primer/current && composer install"
	else
		_devtools-execute dev build-app --container $container --app $app
	fi
}

# usage: dev-init-primer
dev-init-primer() {
	# TODO: If this is ever baked in to main dev tools, remove this
	_devtools-execute dev container-ssh --container job-development --command "useradd -m primer && mkdir /home/primer/.composer/ && cp /home/service/.composer/auth.json /home/primer/.composer && chown -R primer:primer /home/primer/.composer"
	echo
	echo Note: you may see a few errors here, that is normal since creating an app not normally meant to exist by itself
	echo in job-development container..
	echo
	_devtools-execute dev build-app --container job-development --app primer
	echo
	echo You should not see errors after this point...
	echo
	_devtools-execute dev container-ssh --container job-development --command "[ ! -L \"/var/www/primer/current\" ] && ln -s /var/www/primer/releases/local_source /var/www/primer/current"
	dev-build primer
}

# usage: dev-ssh <OPTIONAL: APP-NAME> <OPTIONAL: USER or 1 to use APP-NAME for user>
dev-ssh() {
	local container user
	if [[ $1 ]]; then
		container="--container `_devtools-container $1`"
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
	local lines log;
	local container=`_devtools-container $1`
	if [[ $2 ]]; then
		lines="--lines $2"
	fi
	if [[ $1 == "service" ]]; then
		log="--log /tmp/zs_debug"
	elif [[ $1 == "rulesengineservice" ]]; then
		log="--log /tmp/rulesengine.log"
	elif [[ $1 == "userservice" ]]; then
		log="--log /tmp/user.log"
	fi
	_devtools-execute dev show-log --container $container $log $lines
}

# usage: dev-test <APP-NAME>
dev-test() {
	local phpunit commands
	local container=`_devtools-container $1`
	phpunit="./vendor/phpunit/phpunit/phpunit"
	# Add any special cases here for location of phpunit executable...
	if [[ $1 == "service" ]]; then
		phpunit="./lib/phpunit/phpunit/phpunit"
	fi
	commands="cd /var/www/$1/current; alias phpunit=\\\"${phpunit}\\\";"
	_devtools-execute dev ssh --command "lxc exec $container -- su - $1 -c \"echo '$commands . ~/.profile;' >> /home/$1/.bash_profile\""
	_devtools-execute dev-ssh $1 $1
	_devtools-execute dev ssh --command "lxc exec $container -- su - $1 -c \"rm /home/$1/.bash_profile\""
}

# usage: dev-phpunit <APP-NAME> <OPTIONAL: PHPUNIT ARGUMENT(S)>
dev-phpunit() {
	local service="${1}"
	local container=`_devtools-container $service`
	shift
	if [[ $service == "service" ]]; then
		local path="./lib/bin/phpunit"
	else
		local path="./vendor/bin/phpunit"
	fi
	_devtools-execute dev container-ssh --container $container --command "cd /var/www/$service/current && $path $*"
}

# usage: dev-clear
dev-clear() {
	echo "Clearing APC cache in service..." &&
	dev container-ssh --container "service-development" --command "{
			curl -Lksv https://localhost/apc_clear_cache.php;
			exit;
	}" &> /dev/null &&
	echo "Restarting apache in public..." &&
	dev container-ssh --container "public-development" --command "{
			service apache2 restart;
			exit;
	}" &> /dev/null &&
	echo "Clearing file cache for admin..." &&
	dev container-ssh --container admin-development --command "
		cd /var/www/admin/current &&
		rm -Rf app/tmp/* &&
		git checkout -- app/tmp/" &> /dev/null &&
	echo "Running clear-caches..." &&
	_devtools-execute dev clear-caches &> /dev/null &&
	echo "All caches cleared successfully..."
}

# usage: dev-restart
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

# Usage: dev-xdebug-init
dev-xdebug-init() {
	local vsconfig=$(cat $ZUMBA_APPS_REPO_PATH/dev-tools-bash/vscode-config.json)
	local apps=(admin api public rulesengineservice service userservice zumba netsuite)
	local port=9000
	local appconfig appfolder cmd container
	for app in ${apps[@]}; do
		appfolder="$ZUMBA_APPS_REPO_PATH/$app/"
		if [[ -d $appfolder ]]; then
			echo "Updating things for $app using port $port"
			echo "Updating vscode configuration..."
			[ -d "${appfolder}.vscode/" ] || mkdir -p "${appfolder}.vscode/"
			echo "$(printf "$vsconfig" $port $app)" > "${appfolder}.vscode/launch.json"

			container=`_devtools-container $app`
			echo "Updating xdebug.ini in ${container}..."
			cmd="grep -r -l 'xdebug.remote_port' /etc/php/* | xargs sed -i 's/xdebug.remote_port=[0-9]\{4\}/xdebug.remote_port=${port}/g'"
			dev container-ssh --container $container --command "$cmd"
		else
			echo "no $appfolder, so not initializing $app"
		fi
		((port++))
	done

	echo "restarting things so the new ports take effect..."
	dev-restart

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
	local service="${1}"
	local config="${2}"
	local container=`_devtools-container $service`

	if [[ $config != '' ]]; then
		local cmd="grep -i $config"
	else
		local cmd="cat"
	fi

	if [[ $service == service ]]; then
		local path=/var/www/service/shared/config/environment.php
	elif [[ $service == public ]]; then
		local path=/var/www/public/shared/app/Config/environment.php
	else
		local path=/var/www/$service/shared/.env
	fi

	_devtools-execute dev container-ssh --container $container --command "$cmd $path"
}

# Internal - loads the tools in extra_tools only if the env var is set to 1 for the tool
_devtools-extra() {
	local DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
	local filename permission
	# Load the conditional tools...
	for filename in ${DIR}/extra_tools/*.sh
	do
		permission=${filename##*/}
		permission=${permission%.sh}
		permission=DEVTOOLS_$permission
		eval permission=\$$permission
		if [[ $permission == "1" ]]; then
			. $filename
		fi
	done
}
_devtools-extra
