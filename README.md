# dev-tools-bash
A few tools for doing things on command line

Useful for other software engineers that work **in the tech departnment at the company I work** and have local environments set up with the `dev` commands.

# Setup

1. First check out this repo somewhere outside the fancy case-sensitive file system.  If you like order, perhaps somewhere like `~/projects/`
2. Add the following lines to your `.profile` or `.bash_profile` file in your home folder (change 0 to 1 for specialty tools to enable, see [Conditional Commands](#conditional-commands)):
    ```
    # Enable / Disable Specialty Tools - change to 1 to enable each one
    export DEVTOOLS_phpunit=0
    export DEVTOOLS_job=0
    export DEVTOOLS_listener=0

    # Include the dev-tools
    . ~/projects/dev-tools-bash/dev-tools.sh
    ```

3. Adjust the last line if needed to point to where you checked out this repo in step 1.  Also change the other lines if you want to enable those non-standard tools.
4. Open a new console and try out one of the new `dev-` commands.
5. If you use case sensitive file system, create a sym-link to onboarding so the tools will know where to find it (adjust to match your setup):
    ```
	$ ln -s ~/onboarding /Volumes/ZumbaEnv/onboarding
	```

# Commands

Note that any of these tools that require the `<CONTAINER>`, you only have to specify the first part, you can **leave off `-development`**.  The tools always assume you are working in development.  They also make a few other assumptions, so if a command errors, it could be because you are missing one of the containers or apps or something like that.

List of commands:

* [dev-create](#dev-create) *app auto-detected*
* [dev-create-prebuilt](#dev-create) *app auto-detected*
* [dev-build](#dev-build) *app auto-detected*
* [dev-ssh](#dev-ssh)
* [dev-log](#dev-log) *app auto-detected*
* [dev-test](#dev-test) *app auto-detected*
* [dev-phpunit](#dev-phpunit)
* [dev-job](#dev-job)
* [dev-listener](#dev-listener)
* [dev-clear](#dev-clear)
* [dev-restart](#dev-restart)
* [dev-restart-apache](#dev-restart-apache)
* [dev-xdebug-init](#dev-xdebug-init)
* [dev-init](#dev-init) *app auto-detected*
* [dev-env](#dev-env) *app auto-detected*
* [dev-cp](#dev-cp) *app auto-detected*
* [dev-tableplus](#dev-tableplus)
  * [dev-tableplus-sommos](#dev-tableplus-sommos)
* [dev-sequelpro](#dev-sequelpro)
  * [dev-sequelpro-sommos](#dev-sequelpro-sommos)

*app auto-detected*: If you are already in an app's base folder, the app name can be omitted from these commands and it will use the app you are in.

Commands that require adding `DEVTOOLS-commandname=1` to use (see [Conditional Commands](#conditional-commands))

* [phpunit](#phpunit)
* [job](#job)
* [listener](#listener)

## dev-create

**usage:**
```bash
dev-create [app-name]
```

`[app-name]` optional: if ommitted, will use current directory for the app.

Shortcut for creating a container, you only have to specify the app name as long as it matches the contain name.  It also enables the xdebug grain by default.

**Note:** This will use the `--force` option automatically so that if the container already exists it will automatically destroy it first.

## dev-create-prebuilt

**usage:**
```bash
dev-create-prebuilt [app-name]
```

`[app-name]` optional: if ommitted, will use current directory for the app.

Shortcut for creating a container, using prebuilt image, you only have to specify the app name as long as it matches the contain name.

**Note:** This will use the `--force` option automatically so that if the container already exists it will automatically destroy it first.

## dev-build

**usage:**
```bash
dev-build [app-name]
```

`[app-name]` optional: if omitted, will use current directory for the app.

If the app name and container do not match and is not derived by the app name, you can specify both:

```bash
dev-build [container] [app-name]
```
Note that most miss-matched naming is accounted for you like `primer` automatically assumes `jobs` container, so specifying both is not often needed.

## dev-ssh

**usage:**
```bash
 dev-ssh [app-name] [username or 1]
```

`[app-name]` optional: will `ssh` into `guest` if omitted.

`[username or 1]` optional: If you use a string it will use that as the username starting out.  If you pass in 1 it will use the same username as the app.  If omitted it will use root.

**example:** SSH to netsuite (automatically uses job box) with root user:
```bash
dev-ssh netsuite
```

**example:** SSH to service with service user:
```bash
dev-ssh service 1
```

Note: no arguments will ssh into the guest box, it will not derive the container based on current folder.  If you want that, use [`dev-test`](#dev-test) instead.

## dev-log

**usage:**
```bash
dev-log [app-name] [line-count]
```

`[app-name]` optional: if omitted, will use current directory for the app.

`[line-count]` optional: if omitted, will start with default of 10, note that the app name is not needed to specify number of lines.

This does a little more than just a simple `dev show-logs --container ...`, it also specifies the log file to use depending on the specific container / app.  For instance, if you use `dev-log service` it will use `/tmp/zs_debug`.

If you need the system log you may just need to use the normal `dev show-logs` command directly.

## dev-test

**usage:**
```bash
dev-test [app-name]
```

`[app-name]` optional: if omitted, will use current directory for the app.

Starts SSH, puts you in the app folder `/var/www/[app-name]/current`, and sets up alias for `phpunit` so you can use `phpunit ...` instead of `./vendor/bin/phpunit ...` or similar.

**Difference from `dev-phpunit`:** This opens a shell in the container instead of running phpunit in the container once, so is useful for for running phpunit multiple times, or if you need to do anything in the container and just want to start in the `/var/www/app/current` folder.

**Note:** while the shell is open, any ssh calls into the same container/app/user will also be set up as described above as it temporarily changes the `.bash_profile` for the app user.

## dev-phpunit

**usage:**
```bash
dev-phpunit [app-name] [phpunit argument(s)]
```

`[app-name]` **not** optional: since this accepts any number of arguments, to simplify everything, it will not try to auto-detect the app.  If you want that see the [`phpunit`](#phpunit) command.

`[phpunit argument(s)]` optional: specify whatever you want to pass to phpunit on the command line.  See examples below.

**Note:** With no additional arguments, it will run all tests for the app.

**example:**  Run phpunit for UserTest model in service:
```bash
dev-phpunit service Zumba/Test/Model/UserTest.php
```
**Difference from `dev-test`:** this runs a single phpunit command without having to go into the container

## dev-job

**usage:**
```bash
dev-job [app-name] [job argument(s)]
```

`[app-name]` **not** optional: since this accepts any number of arguments, to simplify everything, it will not try to auto-detect the app.  If you want that see the [`job`](#job) command.

`[job argument(s)]` optional: just like running the job in the container, you don't need to provide any additional arguments, in which case it will print out the list of jobs available.  The arguments are just like you would expect, specify which job and which action to run that job (see examples below).

**Note**: When using xdebug, note that this runs in `job` container, so need to select the xdebug option for job container.

**example:**  Run ShopJob listJobs in service app:
```bash
dev-job service ShopJob listJobs
```

**example:**  List all available jobs in userservice app:
```bash
dev-job userservice
```

## dev-listener

**usage:**
```bash
dev-listener [app-name] [listener class]
```

`[app-name]` **not** optional: since this accepts any number of arguments, to simplify everything, it will not try to auto-detect the app.  If you want that see the [`listener`](#listener) command.

`[listener class]` optional: The listener class to run. If none provided, it will list all the listener classes found in the app.

**Note**: When using xdebug, note that this runs in `job` container, so need to select the xdebug option for job container.

**example:**  Run AddressListener in service app:
```bash
dev-listener service AddressListener
```

See list of listeners in service app:
```bash
dev-listener service
```

## dev-clear
**usage:**
```bash
dev-clear
```

This one is just an alias for `dev clear-caches`.  It originally did some extra stuff, but that stuff is now built into the main command, so today it's just an alias.

## dev-restart

**usage:**
```bash
dev-restart
```

For when things are just getting a little too funky in your VM.

This is the last step before calling Ghost Busters.  It actually halts the VM (not just suspend like `dev stop`) then starts it up again with `dev start`.

## dev-restart-apache

**usage:**
```bash
dev-restart-apache
```

This restarts apache in all the containers you have configured.

## dev-xdebug-init

**usage:**
```bash
dev-xdebug-init
```

This will:
* Set up the Visual Studio Code configurations for each app folder.  It will set up dual configs for service apps, to be able to debug in the service container OR the job container for that app.
* Set up a different port to use for each container to make debugging multiple apps at same time possible.
* Enable the xdebug grain if it looks like it is not already enabled (if it has to do this, it could take a long time, if already enabled it goes pretty fast)

If you use this, be sure to run it after using `dev update` since that will reset the ports to default in all the containers.

Note that after the script runs, it will give some instructions to make sure the VSC config files don't end up showing as changes in git.  You only need to follow those the first time.

## dev-init

**usage:**
```bash
dev-init [app]
```

[app] optional : The app to initialize.  If not set on command line, uses current folder.  Must be one of:
* core
* elasticsearchunit
* mongounit
* primer
* swivel
* symbiosis
* zql
* zumba-coding-standards

This initializes one of the "library" apps inside the **job-development** container.  Use this so you can run PHPUnit tests for primer and other libraries inside the **job-development** container.

Make sure the **job-development** container is already created before calling this, if it is not you can create it using `dev-create primer` first.

If the job-development container is blown away and re-created, or if somehow the library is no longer set up in job-development container, just run this command again to re-initialize it.

## dev-env

**usage:**
```bash
dev-env [app-name] [param search]
```

`[app-name]` optional: if omitted, will use current directory for the app. Required if wishing to also include search params.

`[param search]`  optional: allows only showing lines that match (case insensitive)

This allows you to easily view the shared environment config without needing to ssh and other stuff.

#### Examples
**Get the full shared for userservice:**
```bash
dev-env userservice
```

**Get the mongo settings for userservice:**
```bash
dev-env userservice mongo
```

## dev-cp

**usage:**
```bash
dev-env [from-library-name] [to-app-name]
```

`[from-library-name]` **not** optional: The app to copy into the other app, for example `common` or `core`.

`[to-app-name]` optional: if omitted, will use current directory for the app.

This allows you to easily copy changes to a library into an app to start testing using it, without having to commit the changes to the library first.

For instance if you need to make changes to `primer`, this allows you to make those changes.  Then use this command to copy `primer` into another app to test the changes before you make any changes with silly mistakes in it.

#### Examples
**Copy local changes to primer into service:**
```bash
dev-cp primer service
```

**same as above but using the auto-detected folder:**
```bash
cd zumba/git/service
dev-cp primer
```

## dev-tableplus

**usage:**
```bash
dev-tableplus [env] [role] [company]
```
**Order of attributes not significant (role can go first)**

`[env]` optional: Defaults to `dev` if not specified.

`[role]` optional: Defaults to `reader` if not specified.

`[company]` optional: Defaults to `zumba` if not specified.

This is a shortcut for `dev tableplus`.

### dev-tableplus-sommos

Shortcut on the shortcut, to allow for faster auto-complete.  This will specify sommos as the company and pro as env.
It is the same as calling:

```bash
dev-tableplus sommos pro
# OR:
dev tableplus --environment production --username iam_reader_pro --company sommos
```

## dev-sequelpro

**usage:**
```bash
dev-sequelpro [env] [role] [company]
```
**Order of attributes not significant (role can go first)**

`[env]` optional: Defaults to `dev` if not specified.

`[role]` optional: Defaults to `reader` if not specified.

`[company]` optional: Defaults to `zumba` if not specified.

This is a shortcut for `dev sequelpro`.

### dev-sequelpro-sommos

Shortcut on the shortcut, to allow for faster auto-complete.  This will specify sommos as the company and pro as env.
It is the same as calling:

```bash
dev-sequelpro sommos pro
# OR:
dev sequelpro --environment production --username iam_reader_pro --company sommos
```

# Conditional Commands

These are commands that are available but are not "turned on" by default because they don't follow the typical usage for other tools.  Or it may break things depending on how you do things on your local.

So far, all of these are basically shortcuts that allow auto-detecting the app for commands that normally do not auto-detect the app since they accept additional arguments.  In other words, they allow you to `cd` into the app folder and use them without having to specify the app name each time.

## phpunit

To enable, in your **.bash_profile** file, set `DEVTOOLS_phpunit` to `1`.  Or if you are missing the line, add this above the line that includes dev-tools.sh file:
```bash
export DEVTOOLS_phpunit=1
```

**To use:**
This adds a handy alias for `phpunit`.  From the host machine, just `cd` into any app folder, then use `phpunit ...` directly in the folder.

This is basically a shortcut for calling `dev-phpunit app-name ...`, as long as you are in the app's main folder, no need to specify the app name.

**Warning:**
If you have phpunit already installed in the main path for your host machine, this may interfere with that.

**example:**
Run `phpunit` for user model in service:
```bash
cd zumba/git/service
phpunit Zumba/Test/Model/UserTest.php
```

## job

To enable, in your **.bash_profile** file, set `DEVTOOLS_job` to `1`.  Or if you are missing the line, add this above the line that includes dev-tools.sh file:
```bash
export DEVTOOLS_job=1
```

**To use:**
This adds a handy alias for running a job.  From the host machine, just `cd` into any app folder (that has jobs), then use `job ...` directly in the folder.

This is basically a shortcut for calling `dev-job app-name ...`, as long as you are in the app's main folder, no need to specify the app name.

**Warning:**
If you have `job` already resolves to something in bash, this may interfere with that.

**example**

List all the available jobs in service repo
```bash
cd zumba/git/service
job
```

## listener

To enable, in your **.bash_profile** file, set `DEVTOOLS_listener` to `1`.  Or if you are missing the line, add this above the line that includes dev-tools.sh file:
```bash
export DEVTOOLS_listener=1
```

**To use:**
This adds a handy alias for running a listener.  From the host machine, just `cd` into any app folder, then use `listener ...` directly in the folder.

This is basically a shortcut for calling `dev-listener app-name ...`, as long as you are in the app's main folder, no need to specify the app name.

**Warning:**
If you have `listener` already resolves to something in bash, this may interfere with that.

**example**
Run the benefit listener:
```bash
cd zumba/git/service
listener BenefitListener
```

# App from Current Directory

Some dev-* commands can derive the app or container to use based on the current folder that you run the command from.  Each command will document whether the app name is required or whether it can use the current directory.

# Special Apps

The dev-* tools are all built to automatically know which container to use for the following special case apps:

The following automatically use the **job-development** container:
* `netsuite`
* `eventd`
* `core`
* `elasticsearchunit`
* `mongounit`
* `primer`
* `swivel`
* `symbiosis`
* `zumba-coding-standards`
