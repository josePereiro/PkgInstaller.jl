# PkgInstaller.jl
An script that install julia packages from a set of `Project.toml` and/or `Manifest.toml`. 
It search projects within a given root folder
and collect then (It will ignore .git folders). After that, it will installs/activates/updates/build them. 
Finally, it will install different versions of all explicit deps specified in all `Project.toml`s.
All the work is done in temporal enviroments, so the script have no effects on any enviroment.

It is usefull when you a have not full time internet access and wants to make sure all (and more) is install and build.

# Usage

You must first add all required [Registries](https://julialang.github.io/Pkg.jl/v1.1/registries/#Adding-registries-1).

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
