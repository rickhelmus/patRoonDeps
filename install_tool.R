installPD <- function(library = getOption("patRoonDeps.library"), ask = TRUE, clean = FALSE, instDE = TRUE,
                      repos = "https://rickhelmus.github.io/patRoonDeps")
{
    checkArg <- function(cond, arg, wh)
    {
        if (!cond)
            stop(sprintf("Please set the '%s' argument %s", arg, wh), call. = FALSE)
    }
    
    checkArg(is.character(library) && nzchar(library), "library", "to a valid path")
    checkArg(is.logical(ask), "ask", "TRUE/FALSE")
    checkArg(is.logical(clean), "clean", "as TRUE/FALSE")
    checkArg(is.logical(instDE), "instDE", "as TRUE/FALSE")
    checkArg(is.character(repos) && nzchar(repos), "repos", "to the patRoonDeps repository")

    # utils
    printf <- function(...) cat(sprintf(...), sep = "")
    yesNo = function(title) !interactive() || !ask || menu(c("Yes", "No"), title = title) == 1
    # NOTE: force utils:: to avoid using rstudio shims
    doInstall <- function(pkgs) utils::install.packages(pkgs, lib = library, repos = repos, type = "binary")
    rmPackages <- function(pkgs) utils::remove.packages(pkgs, lib = library)
    # Check without loading namespace, from: https://hohenfeld.is/posts/check-if-a-package-is-installed-in-r/
    isInstalled <- function(pkg, lib.loc = library) nzchar(system.file(package = pkg, lib.loc = lib.loc))
    
    pkgList <- read.csv(paste0(repos, "/patRoonDeps.tsv"), sep = "\t", colClasses = "character")
    
    if (!file.exists(library))
    {
        if (yesNo("The library does not appear to exist. Do you want to initialize it?"))
        {
            if (!dir.create(library))
                stop("Failed to create library directory!", call. = FALSE)
            doInstall(pkgList$Package)
        }
    }
    else
    {
        if (!dir.exists(library))
            stop(sprintf("The specified library ('%s') does not appear to be a directory", library), call. = FALSE)
        
        instPackages <- installed.packages(library, fields = "RemoteSha")[, c("Package", "Version", "RemoteSha")]
        instPackages <- as.data.frame(instPackages)
        instPackages$RemoteSha[is.na(instPackages$RemoteSha)] <- "" # normalize with pkgList
        
        printf("Comparing the package library with patRoonDeps... ")
        ignorePkgs <- c("patRoonData", "patRoonExt")
        checkPkgs <- setdiff(instPackages$Package, ignorePkgs)
        missingPkgs <- setdiff(pkgList$Package, checkPkgs)
        otherPkgs <- setdiff(checkPkgs, pkgList$Package)
        samePkgs <- merge(pkgList, instPackages)$Package
        changedPkgs <- setdiff(checkPkgs, c(samePkgs, missingPkgs))
        printf("Done!\n")

        if (length(otherPkgs) > 0)
        {
            printf("The following %d packages are not part of patRoonDeps: %s\n", length(otherPkgs),
                   paste0(otherPkgs, collapse = ", "))
            if (clean)
            {
                printf("Cleaning... ")
                rmPackages(otherPkgs)
                printf("Done!\n")
            }
            else
                printf("Re-run with clean=TRUE to remove these packages\n")
        }
        
        if ((length(missingPkgs) > 0 || length(changedPkgs) > 0))
        {
            if (length(missingPkgs) > 0)
                printf("The following %d packages are not yet installed: %s\n\n", length(missingPkgs),
                       paste0(missingPkgs, collapse = ", "))
            if (length(changedPkgs) > 0)
                printf("The following %d packages are with a different version: %s\n", length(changedPkgs),
                       paste0(changedPkgs, collapse = ", "))
            
            if (yesNo("Do you want to synchronize the library by installing or updating packages?"))
                doInstall(c(missingPkgs, changedPkgs))
        }
    }
    
    if (instDE)
    {
        # UNDONE: install remotes in patRoon library?
        if (!requireNamespace("remotes", quietly = TRUE))
        {
            stop("Please install the remotes package to install patRoonData/patRoonExt ",
                 "(or set instDE=FALSE to skip the installation", call. = FALSE)
        }
        
        # override .libPaths as install_github() ignores the lib argument when checking if the package already exists
        lp <- .libPaths()
        on.exit(.libPaths(lp), add = TRUE)
        .libPaths(library, include.site = FALSE)
        
        printf("Installing/updating patRoonData/patRoonExt (if needed) ...\n")
        remotes::install_github(c("rickhelmus/patRoonData", "rickhelmus/patRoonExt"), upgrade = "never", lib = library)
    }
    
    printf("All done!\n")
}
