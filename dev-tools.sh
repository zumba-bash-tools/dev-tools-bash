###
# Tools used to make things easier
#
# See https://github.com/jonyo/dev-tools-bash
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
# no arguments will ssh into guest
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
#
# Starts SSH, puts you in the app folder, and sets up alias for phpunit
#
# Difference from dev-phpunit: This opens a shell instead of running phpunit in the container once, so is useful for
# for running phpunit multiple times.
#
# Note: while the shell is open, any ssh calls into the same container/app/user will also be set up as described above
# as it temporarily changes the .bash_profile for the app user
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
#
# example:
# Run phpunit for UserTest model in service:
# dev-phpunit service Zumba/Test/Model/UserTest.php
#
# Difference from dev-test: this runs a single phpunit command
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
#
# Clears all caches on all containers
#
# TODO: Remove this once this is part of `dev clear-caches` tool (or sections if just one part is incorporated into
# clear-caches)
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
#
# For when things are just getting a little too funky in your VM.
# This is the last step before calling Ghost Busters.
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
