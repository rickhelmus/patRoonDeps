library("miniCRAN")

printf <- function(...) cat(sprintf(...), sep = "")

# Check without loading namespace, from: https://hohenfeld.is/posts/check-if-a-package-is-installed-in-r/
# Otherwise upgrading packages etc will fail with files being in use
isInstalled <- function(pkg, ...) nzchar(system.file(package = pkg, ...))

installFromOurRepos <- function(pkg)
{
    utils::install.packages(pkg, repos = paste0("file:///", normalizePath(".", winslash = "/")), type = "win.binary")
}

dependencies <- list(
    RDCOMClient = list(type = "gh", user = "omegahat"),
    RAMClustR = list(
        type = "cran",
        deps = list(
            InterpretMSSpectrum = list(type = "gh", user = "cran", tag = "1.3.3")
        )
    ),
    enviPick = list(type = "gh", user = "blosloos"),
    nontarget = list(
        type = "gh",
        user = "blosloos",
        deps = list(
            nontargetData = list(type = "gh", user = "blosloos"),        
        )
    ),
    KPIC = list(
        type = "gh",
        user = "rickhelmus",
        repos = "KPIC2",
        deps = list(
            ropls = list(type = "bioc")
        )
    ),
    cliqueMS = list(
        type = "gh",
        user = "rickhelmus",
        deps = list(
            GenomeInfoDbData = list(type = "gh", user = "BioConductor", branch = "devel")
        )
    ),
    MetaClean = list(
        type = "gh",
        user = "KelseyChetnik",
        deps = list(
            BiocStyle = list(type = "bioc"),
            Rgraphviz = list(type = "bioc"),
            fastAdaboost = list(type = "gh", user = "souravc83")
        )
    ),
    # MetaCleanData = list(type = "gh", user = "KelseyChetnik"), # package is too big file for GitHub :-(
    splashR = list(type = "gh", user = "berlinguyinca", repos = "spectra-hash", pkgroot = "splashR"),
    patRoon = list(type = "gh", user = "rickhelmus", branch = Sys.getenv("GITHUB_REF_NAME", "master"))
)

addPkgListingGH <- function(pdb, pkgs)
{
    for (dep in names(pkgs))
    {
        md <- pkgs[[dep]]
        if (md$type == "gh")
        {
            printf("Adding GH listings: %s\n", dep)
            repos <- if (!is.null(md[["repos"]])) md$repos else dep
            branch <- if (!is.null(md[["branch"]]))
                md$branch
            else if (!is.null(md[["tag"]]))
                md$tag
            else
                "master"
            if (!is.null(md[["pkgroot"]]))
            {
                # HACK: if the package is not in the repos root then set branch = "<branch>/subdir"
                branch <- paste0(branch, "/", md$pkgroot)
            }
            
            pdb <- addPackageListingGithub(pdb, repos, md$user, branch)
        }
        
        if (!is.null(md[["deps"]]))
            pdb <- addPkgListingGH(pdb, md$deps)
    }
    
    return(pdb)
}

packageOrigRepos <- c(BiocManager::repositories())
packageDB <- pkgAvail(repos = packageOrigRepos, type = "win.binary")
packageDB <- addPkgListingGH(packageDB, dependencies)

getPkgDeps <- function(pkgs)
{
    ret <- names(pkgs)
    for (md in pkgs)
    {
        if (!is.null(md[["deps"]]))
            ret <- c(ret, getPkgDeps(md$deps))
    }
    return(ret)
}

allDependencyNames <- getPkgDeps(dependencies)
packagesForRepos <- pkgDep(allDependencyNames, availPkgs = packageDB, repos = packageOrigRepos,
                           type = "win.binary", suggests = FALSE)

thisRVersion <- paste(R.Version()$major, floor(as.numeric(R.Version()$minor)), sep = ".")
reposPkgPath <- file.path("bin", "windows", "contrib", thisRVersion)
packagesFile <- file.path(reposPkgPath, "PACKAGES")
if (file.exists(packagesFile))
{
    regex <- "^Package: (.*)$" # inspired by https://github.com/andrie/miniCRAN/issues/79
    pLines <- readLines(packagesFile)
    packages <- pLines[grepl(regex, pLines)]
    packages <- gsub(regex, "\\1", packages)
    
    removedPackages <- setdiff(packages, packagesForRepos)
    newPackages <- setdiff(packagesForRepos, packages)
    newPackages <- setdiff(newPackages, allDependencyNames)
    
    # will be re-added
    # removedPackages <- union(removedPackages, localPackages)
    
    if (length(removedPackages) > 0)
    {
        file.remove(list.files(reposPkgPath, full.names = TRUE,
                               pattern = paste0(sprintf("^%s_.+\\.zip", removedPackages), collapse = "|")))
        updateRepoIndex(".", "win.binary")
    }
    
    if (length(newPackages) > 0)
        addPackage(newPackages, ".", repos = packageOrigRepos, type = "win.binary")
    
    updatePackages(".", repos = packageOrigRepos, ask = FALSE, type = "win.binary")
    
    # remove old versions
    pkgM <- readRDS(file.path(reposPkgPath, "PACKAGES.rds"))
    curPkgs <- paste0(pkgM[, "Package"], "_", pkgM[, "Version"], ".zip")
    curPkgs <- file.path(reposPkgPath, curPkgs)
    oldPkgs <- setdiff(list.files(reposPkgPath, pattern = "\\.zip", full.names = TRUE), curPkgs)
    cat("Removing old packages: ", paste0(oldPkgs, collapse = "\n"), "\n", sep = "")
    file.remove(oldPkgs)
} else
{
    unlink(file.path("bin/windows/contrib", thisRVersion), recursive = TRUE)
    makeRepo(packagesForRepos, path = ".", repos = packageOrigRepos, type = c("win.binary"))    
}

# build GH packages, as they cannot be added directly with miniCRAN. Unfortunately, we need all dependencies installed
# before a package can be build. The easiest is to just first install the package locally (in a temporary library).

# Iterate through all dependencies:
# - if it's cran/bioc package, only install if not yet present and from the miniCRAN repos if possible
# - if it's a GH package and it's not installed or out of date, then download the repos, install it, build it and add it
#   to the miniCRAN repos.
tempRLibrary <- tempfile("RLibrary")
dir.create(tempRLibrary)
ourPackages <- rownames(miniCRAN::pkgAvail(".", "win.binary"))
GHPackagesPath <- tempfile()
dir.create(GHPackagesPath)

handlePackages <- function(pkgs)
{
    withr::local_libpaths(tempRLibrary, "prefix")
    for (dep in names(pkgs))
    {
        md <- pkgs[[dep]]
        
        # handle nested dependencies first
        if (!is.null(md[["deps"]]))
            handlePackages(md$deps)
        
        if (md$type %in% c("cran", "bioc"))
        {
            # NOTE: CRAN/BioC packages should already be available in our repos
            if (!isInstalled(dep, lib.loc = tempRLibrary))
                installFromOurRepos(dep)
        }
        else # md$type == "gh
        {
            repos <-  if (!is.null(md[["repos"]])) md$repos else dep
            ghrepos <- paste0(md$user, "/", repos)
            doInstall <- !isInstalled(dep, lib.loc = tempRLibrary)
            
            if (doInstall && dep %in% ourPackages)
            {
                # install from the miniCRAN repos so we can see if it needs to be updated
                installFromOurRepos(dep)
                doInstall <- FALSE
            }

            upSHA <- remotes::remote_sha(remotes::github_remote(ghrepos))
            if (!doInstall)
            {
                # check if it's current by using some internals of the remotes package
                locSHA <- packageDescription(dep)[["pdSHA"]] # this is added below before GH packages are built
                doInstall <- is.null(locSHA) || remotes:::different_sha(upSHA, locSHA)
                if (doInstall)
                    printf("SHA changed for %s: %s/%s\n", dep, upSHA, if (is.null(locSHA)) "NULL" else locSHA)
            }
            
            if (doInstall)
            {
                printf("Building/Installing GH package: %s\n", dep)
                
                # from https://docs.github.com/en/repositories/working-with-files/using-files/downloading-source-code-archives#source-code-archive-urls
                url <- if (!is.null(md[["tag"]]))
                    sprintf("https://github.com/%s/archive/refs/tags/%s.zip", ghrepos, md$tag)
                else
                    sprintf("https://github.com/%s/archive/refs/heads/%s.zip", ghrepos,
                            if (!is.null(md[["branch"]])) md$branch else "master")
                outf <- tempfile(fileext = ".zip")
                stopifnot(download.file(url, outf, mode = "wb") == 0)
                
                extrp <- tempfile()
                unzip(outf, exdir = extrp)
                extrp <- list.files(extrp, pattern = repos, full.names = TRUE) # extracted to subdir
                if (!is.null(md[["pkgroot"]]))
                    extrp <- file.path(extrp, md$pkgroot)
                
                # HACK: add SHA so we can check in the future if it changed upstream
                # NOTE: some packages don't have a newline at the end. At the same time R doesn't like empty lines, so
                # we can't just always prepend a newline before our text.
                ds <- readLines(file.path(extrp, "DESCRIPTION"))
                ds <- c(ds, paste("pdSHA:", upSHA))
                writeLines(ds, file.path(extrp, "DESCRIPTION"))

                remotes::install_deps(extrp, upgrade = "never", dependencies = TRUE,
                                      repos = paste0("file:///", normalizePath(".", winslash = "/")), type = "win.binary")
                
                binpkg <- pkgbuild::build(extrp, GHPackagesPath, binary = TRUE, vignettes = FALSE, args = c("--no-test-load", ""))
                # remotes::install_local(extrp, md$subdir, upgrade = "never", force = TRUE)
                # remotes::install_local(binpkg, upgrade = "never", force = TRUE)
                utils::install.packages(binpkg, repos = NULL)
                
                # before the package can be added to the repos, any previous should be removed: addLocalPackage()
                # ignores packages with the same version, and the version number often doesn't change when GH packages
                # are updated
                file.remove(list.files(reposPkgPath, full.names = TRUE, pattern = sprintf("^%s_.+\\.zip", dep)))
                updateRepoIndex(".", "win.binary")
                
                addLocalPackage(dep, GHPackagesPath, ".", "win.binary", build = FALSE, deps = TRUE)
            }
        }
    }
}

handlePackages(dependencies)
