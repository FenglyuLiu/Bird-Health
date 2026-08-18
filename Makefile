.PHONY: help status check check-shell

help:
	@printf '%s\n' \
	  'Portable project commands:' \
	  '  make status      Show Git and project status' \
	  '  make check       Run safe repository checks' \
	  '  make check-shell Validate maintained shell scripts'

status:
	@printf '%s\n' 'Workspace:'
	@pwd
	@printf '\n%s\n' 'Git status:'
	@if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then git status --short --branch; else echo 'Not a Git repository yet.'; fi
	@printf '\n%s\n' 'Known projects:'
	@printf '%s\n' '  - DSH Mac Client'

check: check-shell
	@printf '%s\n' 'Repository checks passed.'

check-shell:
	@bash -n 'DSH Mac Client/build.sh'
	@bash -n 'DSH Mac Client/install.sh'
