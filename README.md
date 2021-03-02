# PkgInstaller.jl
And script that install julia packages from a set of `Project.toml` and/or `Manifest.toml`. It search projects from a given root folder
and collect then. After that it will installs/activates/updates them.
Finally, it will install different versions of all explicit deps specified in all `Project.toml`s.
All the work is done in temporal enviroments, so the script have no side effects.

# Usage

You must first add all required [Registries](https://julialang.github.io/Pkg.jl/v1.1/registries/#Adding-registries).

```bash
$ julia pkg_installer.jl --help
usage: pkg_installer.jl [-d DEEP] [-r ROOT] [--dry-run] [-h]

optional arguments:
  -d, --deep DEEP  define how many extra version of each pkg to
                   install, from newer to older. (type: Int64, default: 0)
  -r, --root ROOT  The root folder for searching projects. (default: ".")
  --dry-run        Run without consequences.
  -h, --help       show this help message and exit
```