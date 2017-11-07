# dev-tools-bash
A few tools for doing things on command line

Useful for other software engineers that work **in the tech departnment at the company I work** and have local environments set up with the `dev` commands.

# Setup

1. First check out this repo into your normal folder for git repos.
2. Add the following line to your `.profile` or `.bash_profile` file in your home folder:
    ```
    # Enable / Disable Specialty Tools
    export DEVTOOLS_phpunit=0

    # Include the dev-tools
    . ~/zumba/git/dev-tools-bash/dev-tools.sh
    ```

3. Open a new console and try out one of the new `dev-` commands.

# Commands

Note that any of these tools that require the `<CONTAINER>`, you only have to specify the first part, you can **leave off `-development`**.  The tools always assume you are working in development.  They also make a few other assumptions, so if a command errors, it could be because you are missing one of the containers or apps or something like that.

## dev-create

**usage:**
```bash
dev-create <APP-NAME>
```

Shortcut for creating a container, you only have to specify the app name as long as it matches the contain name.  It also enables the xdebug grain by default.

## dev-build

**usage:**
```bash
dev-build <APP-NAME>
```

If the app name and container do not match:
```bash
dev-build <CONTAINER> <APP-NAME>
```

## dev-ssh

**usage:**
```bash
 dev-ssh <OPTIONAL: APP-NAME> <OPTIONAL: USER OR 1>
```

If you pass in 1 as second argument, it will use the first argument as both the app name and the user.

**example:** SSH to netsuite (automatically uses job box) with root user:
```bash
dev-ssh netsuite
```

**example:** SSH to service with service user:
```bash
dev-ssh service 1
```

Note: no arguments will ssh into the guest box.

## dev-log

**usage:**
```bash
dev-log <APP-NAME> <OPTIONAL: LINES>
```

This does a little more than just a simple `dev show-logs --container ...`, it also specifies the log file to use depending on the specific container / app.  For instance, if you use `dev-log service` it will use `/tmp/zs_debug`.

If you need the system log you may just need to use the normal `dev show-logs` command directly.

## dev-test

**usage:**
```bash
dev-test <APP-NAME>
```

Starts SSH, puts you in the app folder `/var/www/APP-NAME/current`, and sets up alias for `phpunit` so you can use `phpunit ...` instead of `./vendor/bin/phpunit ...` or similar.

**Difference from `dev-phpunit`:** This opens a shell in the container instead of running phpunit in the container once, so is useful for for running phpunit multiple times, or if you need to do anything in the container and just want to start in the `/var/www/app/current` folder.

**Note:** while the shell is open, any ssh calls into the same container/app/user will also be set up as described above as it temporarily changes the `.bash_profile` for the app user.

## dev-phpunit

**usage:**
```bash
dev-phpunit <APP-NAME> <OPTIONAL: PHPUNIT ARGUMENT(S)>
```

**example:**  Run phpunit for UserTest model in service:
```bash
dev-phpunit service Zumba/Test/Model/UserTest.php
```
**Difference from `dev-test`:** this runs a single phpunit command without having to go into the container

## dev-clear
**usage:**
```bash
dev-clear
```

This one is on chopping block, it is about to be built in to the `dev clear-caches` command.

## dev-restart

**usage:**
```bash
dev-restart
```

For when things are just getting a little too funky in your VM.

This is the last step before calling Ghost Busters.  It actually halts the VM (not just suspend) then starts it up again with `dev start`.

## dev-xdebug-init

**usage:**
```bash
dev-xdebug-init
```

This sets up the Visual Studio Code configurations for each repo folder, and sets up a different port to use for each to make debugging multiple apps at same time possible

This is safe to also run **after a `dev update`**, if the ports on the xdebug.ini get reset.  In fact that is the main purpose this was created.

Note that after the script runs, it will give some instructions to make sure the VSC config files don't end up showing as changes in git.

## dev-init-primer

**usage:**
```bash
dev-init-primer
```

This initializes the **primer** app inside the **job-development** container.  Use this so you can run PHPUnit tests for primer inside the **job-development** container.

Make sure the **job-development** container is already created before calling this, if it is not you can create it using `dev-create primer` first.

If the job-development container is blown away and re-created, or if somehow primer is no longer set up in job-development container, just run this command again to re-initialize it.

# Conditional Commands

These are commands that are available but are not "turned on" by default because they don't follow the typical usage for other tools.  Or it may break things depending on how you do things on your local.

## phpunit

To enable, in your **.bash_profile** file, set `DEVTOOLS_phpunit` to `1`.  Or if you are missing the line, add this above the line that includes dev-tools.sh file:
```bash
export DEVTOOLS_phpunit=1
```

**To use:**
This adds a handy alias for `phpunit`.  From the host machine, just `cd` into any repo path that goes to a built app, then use `phpunit ...` directly in the folder.

This is basically a shortcut for calling `dev-phpunit app-name ...`, as long as you are in the app's main folder, no need to specify the app name.

**Warning:**
If you have phpunit already installed in the main path for your host machine, this may interfere with that.

# Special Apps

The dev-* tools are all built to automatically know which container to use for the following special case apps:

* **netsuite** - automatically uses **job-development** container
* **primer** - automatically uses **job-development** container
