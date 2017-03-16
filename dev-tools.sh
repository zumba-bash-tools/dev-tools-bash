###
# Tools used to make things easier
#
# See https://github.com/jonyo/dev-tools-bash
#
# See README.md for additional documentation on each tool
#
###

# usage: dev-create <APP-NAME>
dev-create() {
	dev create-container --container "$1-development" --build-app --grains xdebug
}

# usage: dev-build <APP-NAME|CONTAINER> <optional: APP-NAME>
dev-build() {
	if [ $2 ]; then
		dev build-app --container "$1-development" --app $2;
	else
		dev build-app --container "$1-development" --app $1;
	fi
}

# usage: dev-ssh <OPTIONAL: APP-NAME> <OPTIONAL: USER>
dev-ssh() {
	if [ $2 ]; then
		dev container-ssh --container "$1-development" --user "$2";
	elif [ $1 ]; then
		dev container-ssh --container "$1-development";
	else
		dev ssh;
	fi
}

# usage: dev-log <APP-NAME> <OPTIONAL: LINES>
dev-log() {
	local lines log;
	if [ $2 ]; then
		lines="--lines $2"
	fi
	if [ $1 == "service" ]; then
		log="--log /tmp/zs_debug";
	elif [ $1 == "rulesengineservice" ]; then
		log="--log /tmp/rulesengine.log";
	elif [ $1 == "userservice" ]; then
		log="--log /tmp/user.log";
	fi
	dev show-log --container "$1-development" $log $lines;
}

# usage: dev-test <APP-NAME>
dev-test() {
	local phpunit commands
	phpunit="./vendor/phpunit/phpunit/phpunit"
	# Add any special cases here for location of phpunit executable...
	if [ $1 == "service" ]; then
		phpunit="./lib/phpunit/phpunit/phpunit"
	fi
	commands="cd /var/www/$1/current; alias phpunit=\\\"${phpunit}\\\";"
	dev ssh --command "lxc exec $1-development -- su - $1 -c \"echo '$commands . ~/.profile;' >> /home/$1/.bash_profile\""
	dev-ssh $1 $1
	dev ssh --command "lxc exec $1-development -- su - $1 -c \"rm /home/$1/.bash_profile\""
}

# usage: dev-phpunit <APP-NAME> <OPTIONAL: PHPUNIT ARGUMENT(S)>
dev-phpunit() {
        local service="${1}"
        shift
        if [[ $service == "service" ]]; then
                local path="./lib/bin/phpunit"
        else
                local path="./vendor/bin/phpunit"
        fi
        dev container-ssh --container "$service-development" --command "cd /var/www/$service/current && $path $*"
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
	dev clear-caches &> /dev/null &&
	echo "All caches cleared successfully..."
}

# usage: dev-restart
dev-restart() {
	echo "Halting the VM..."
	# Actually halt the VM.  Don't do dev stop - that only suspends the VM and you may end up with same problems once
	# it starts back up
	cd ~/zumba/git/onboarding &&
	vagrant halt &&
	cd - &&
	echo "Starting things back up..." &&
	# Use `vagrant halt` then `dev start` that way all the initialization stuff that happens in `dev start` runs (unlike
	# doing just a `vagrant reload`)
	dev start
}

# Usage: dev-xdebug-init
dev-xdebug-init() {
	local vsconfig=$(cat ~/zumba/git/dev-tools-bash/vscode-config.json)
	local apps=(admin api public rulesengineservice service userservice zumba)
	local port=9000
	local appconfig appfolder cmd
	for app in ${apps[@]}; do
		appfolder="$HOME/zumba/git/$app/"
		if [[ -d $appfolder ]]; then
			echo "Updating things for $app using port $port"
			echo "Updating vscode configuration..."
			[ -d "${appfolder}.vscode/" ] || mkdir -p "${appfolder}.vscode/"
			echo "$(printf "$vsconfig" $port $app)" > "${appfolder}.vscode/launch.json"

			echo "Updating xdebug.ini in container..."
			cmd="sed -i 's/xdebug.remote_port=[0-9]\{4\}/xdebug.remote_port=${port}/' /etc/php/5.6/mods-available/xdebug.ini"
			dev container-ssh --container "${app}-development" --command "$cmd"
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
