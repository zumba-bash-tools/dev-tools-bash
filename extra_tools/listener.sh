# Requires:
# export DEVTOOLS_listener=1

# usage: cd to repo path, then listener ...
listener() {
	dev-listener ${PWD##*/} $@
}
