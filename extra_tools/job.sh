# Requires:
# export DEVTOOLS_job=1

# usage: cd to repo path, then job ...
job() {
	dev-job ${PWD##*/} $@
}
