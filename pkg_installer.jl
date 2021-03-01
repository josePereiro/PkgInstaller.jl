using Pkg
using Pkg.TOML

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

function finddir(f::Function, root = pwd())
    founds = []
    for (root, dirs, files) in walkdir(root)
        for dir in dirs
            abspath = joinpath(root, dir)
            f(abspath) && push!(founds, abspath)
        end
    end
    founds
end
finddir(name::String, root = pwd()) = finddir((abspath) -> basename(abspath) == name, root)

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

## ---------------------------------------------------------------------------------------------
# Install registers
let
    regs = ["https://github.com/josePereiro/CSC_Registry.jl"]
    for url in regs
        try
            println("\n", "-" ^ 45)
            @info("Adding registry", url)
            Pkg.Registry.add(RegistrySpec(;url))
        catch err
            @warn("ERROR", url, err)
        end
    end
end

## ---------------------------------------------------------------------------------------------
pkgs_pool = Dict()
# Install source projects
let
    projs_dir = joinpath(@__DIR__, "Projects")
    @assert isdir(projs_dir)

    for proj_dir in readdir(projs_dir)
        
        abs_path = joinpath(projs_dir, proj_dir)
        !isdir(abs_path) && continue

        try
            # Proj files
            proj_file = joinpath(projs_dir, proj_dir, "Project.toml")
            manf_file = joinpath(projs_dir, proj_dir, "Manifest.toml")
            !isfile(proj_file) && (@warn("Not Project.toml found", proj_dir); continue)
            
            # Install and update
            println("\n", "-" ^ 45)
            @info("Project found", proj_dir)
            Pkg.activate(proj_file)
            isfile(manf_file) ? Pkg.instantiate() : Pkg.resolve()
            Pkg.update()
            Pkg.build()

            # Collect
            pkgs = load_deps(proj_file)
            merge!(pkgs_pool, pkgs)

        catch err
            @warn("ERROR", proj_file, err)
        end
    end
end

## ---------------------------------------------------------------------------------------------
# Install version range
let
    VERS_PER_PKG = 50

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
            @info("Found", name, uuidpkg, length(versions))
            
            # Installing version range
            c = 0
            for version in versions 
                println("\n", "-" ^ 45)
                @info("Installing", name, uuidpkg, version)
                
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

                c > VERS_PER_PKG && break
                c += 1

            end
        catch err
            @warn("ERROR", name, uuidpkg, err)
        end
    end
end