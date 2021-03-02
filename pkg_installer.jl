using Pkg
using Pkg.TOML
Pkg.activate(@__DIR__)

# ---------------------------------------------------------------------------------------------
# Parsing ARGS

try; @eval import ArgParse
catch 
    Pkg.add("ArgParse")
    @eval import ArgParse
end
const AP = ArgParse

argset = AP.ArgParseSettings()
AP.@add_arg_table! argset begin
    "--deep", "-d"
        help = "define how many extra version of each pkg to install, " * 
                "from newer to older."
        arg_type = Int
        default = 0
    "--root", "-r"
        help = "The root folder for searching projects."
        arg_type = String
        default = "."
    "--dry-run"
        help = "Run without consequences."
        action = :store_true
end

if isinteractive()
    # Dev values
    deep = 0
    dry_run = true
    root = abspath(".")
else
    parsed_args = AP.parse_args(ARGS, argset)
    deep = parsed_args["deep"]
    dry_run = parsed_args["dry-run"]
    root = abspath(parsed_args["root"])
end

## ---------------------------------------------------------------------------------------------
# Tools
function load_deps(proj_file)
    raw_deps = get(TOML.parsefile(proj_file), "deps", Dict())
    deps = Dict()
    for (name, uuid) in raw_deps
        deps[uuid] = name
    end
    deps
end

function find_projects(root = ".")
    projs = String[]
    c = 1
    root = abspath(root)
    for (dir, subdirs, _) in walkdir(root)
        for subdir in subdirs, projname in Base.project_names
            try
                projfile = joinpath(dir, subdir, projname)
                !isfile(projfile) && continue

                # ignores
                occursin("/.git/", projfile) && continue

                push!(projs, projfile)
                println(c, ": ", relpath(projfile, root))
                c += 1
            catch err; end
        end
    end
    projs
end

reg_dir() = joinpath(first(DEPOT_PATH),"registries")

function findin_regs(name::String, reg_root = reg_dir())
    firstletter = string(first(name))
    founds = []
    for dir in readdir(reg_root)
        reg_dir = joinpath(reg_root, dir, firstletter, name)
        !isdir(reg_dir) && continue
        push!(founds, reg_dir)
    end
    founds
end

function extract_versions(regpath)
    ctx = Pkg.Types.Context()
    di=Pkg.Operations.load_versions(ctx, regpath)
    keys(di) |> collect
end

function extract_uuid(regpath)
    pkg_file = joinpath(regpath, "Package.toml")
    dat = TOML.parsefile(pkg_file)
    return dat["uuid"]
end

function create_temp_proj(proj_dir)
    temp_proj_dir = tempdir()
    mkpath(temp_proj_dir)
    cp(proj_dir, temp_proj_dir; force = true, follow_symlinks = true)
end

## ---------------------------------------------------------------------------------------------
# Looking for projects
println("\n", "-" ^ 45)
@info("Looking for projects", root)
const projs = find_projects(root);

## ---------------------------------------------------------------------------------------------
# Install source projects
const pkgs_pool = Dict()
let
    println("\n", "-" ^ 45)
    @info("Installing source projects", root)

    for proj_file in projs
        try
            # Install and update
            println("\n", "-" ^ 45)
            proj_file = relpath(proj_file, root)
            @info("Found on disk", proj_file)
            proj_file = abspath(proj_file)

            # Collect devs
            pkgs = load_deps(proj_file)
            merge!(pkgs_pool, pkgs)

            # Installing
            if !dry_run 

                # Temp env
                proj_dir = create_temp_proj(dirname(proj_file))
                try
                    proj_file = joinpath(proj_dir, basename(proj_file))
                    Pkg.activate(proj_file)

                    for manf_name in Base.manifest_names
                        manf_file = joinpath(proj_dir, manf_name)
                        isfile(manf_file) && Pkg.instantiate()
                    end
                    Pkg.resolve()
                    Pkg.update()
                    Pkg.build()

                finally
                    rm(proj_dir; force = true, recursive = true)
                end
            end

        catch err
            @warn("ERROR", proj_file, err)
        end
    end
end

## ---------------------------------------------------------------------------------------------
# Install version range
let
    pkgs_count = length(pkgs_pool)
    println("\n", "-" ^ 45)
    @info("Installing pkg versions", pkgs_count, deep)
    
    deep <= 0 && return
    for (uuidpkg, name) in pkgs_pool
        try
            versions = VersionNumber[]
            for path in findin_regs(name)
                uuidfile = extract_uuid(path)
                uuidpkg != uuidfile && continue
                push!(versions, extract_versions.(path)...)
            end
            sort!(unique!(versions), rev = true)

            println("\n" ^ 3, "-" ^ 45)
            @info("Found in register", name, uuidpkg, length(versions))
            
            # Installing version range
            c = 0
            for version in versions 

                c >= deep && break
                c += 1

                println("\n", "-" ^ 45)
                @info("Installing", name, uuidpkg, version)
                
                if !dry_run
                    tempenv = tempdir()
                    mkpath(tempenv)
                    try
                        Pkg.activate(tempenv)
                        pkg = PackageSpec(name, Base.UUID(uuidpkg), version)
                        Pkg.add(pkg)
                        Pkg.build()

                    catch err
                        @warn("ERROR", name, uuidpkg, version, err)
                    finally
                        rm(tempenv; force = true, recursive = true)
                    end
                end
            end
        catch err
            @warn("ERROR", name, uuidpkg, err)
        end
    end
end