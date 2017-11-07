# Requires:
# export DEVTOOLS_phpunit=1

# usage: cd to repo path, then phpunit ...
phpunit() {
	dev-phpunit ${PWD##*/} $@
}
