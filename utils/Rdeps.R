getRDependencies <- function(patRoonGitRef, os, onlyPDeps = FALSE, withInternal = TRUE, flatten = FALSE,
                             checkVersion = NULL)
{
    if (!is.null(checkVersion))
    {
        # nothing yet, in case we need to handle compatibility issues with eg patRoonInst
    }
    
    ret <- list(
        CAMERA = list(type = "bioc", mandatory = TRUE), # also pulls in other mandatory BioC deps (mzR, XCMS, ...)
        RDCOMClient = list(type = "gh", user = "BSchamberger", os = "windows"),
        RAMClustR = list(
            type = "gh",
            user = "cbroeckl",
            branch = "master", # "release_1.3.x",
            deps = list(
                ff = list(type = "cran"),
                InterpretMSSpectrum = list(
                    type = "cran",
                    deps = list(
                        Rdisop = list(type = "bioc")
                    )
                )
            )
        ),
        enviPick = list(type = "gh", user = "blosloos"),
        nontarget = list(
            type = "gh",
            user = "blosloos",
            deps = list(
                nontargetData = list(type = "gh", user = "blosloos")
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
                GenomeInfoDbData = list(type = "gh", user = "BioConductor", branch = "devel",
                                        os = "windows", internal = TRUE)
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
        MetaCleanData = list(type = "gh", user = "KelseyChetnik", patRoonDeps = FALSE),
        splashR = list(type = "gh", user = "berlinguyinca", repos = "spectra-hash", pkgroot = "splashR"),
        MS2Tox = list(type = "gh", user = "kruvelab", branch = "main"),
        MS2Quant = list(type = "gh", user = "kruvelab", branch = "main"),
        patRoonData = list(type = "gh", user = "rickhelmus", patRoonDeps = FALSE),
        patRoonExt = list(type = "gh", user = "rickhelmus", patRoonDeps = FALSE),
        patRoon = list(type = "gh", user = "rickhelmus", branch = patRoonGitRef)
    )
    
    filterDeps <- function(deps)
    {
        deps <- lapply(deps, function(d)
        {
            if (!is.null(os) && !is.null(d[["os"]]) && d$os != os)
                return(NULL)
            if (onlyPDeps && isFALSE(d[["patRoonDeps"]]))
                return(NULL)
            if (!withInternal && isTRUE(d[["internal"]]))
                return(NULL)
            if (!is.null(d[["deps"]]))
                d$deps <- filterDeps(d$deps)
            return(d)
        })
        return(deps[!sapply(deps, is.null)])
    }
    ret <- filterDeps(ret)
    
    if (flatten)
    {
        flret <- list()
        makeFlat <- function(deps, parent)
        {
            for (d in names(deps))
            {
                md <- deps[[d]]
                if (!is.null(md[["deps"]]))
                {
                    makeFlat(md$deps, d)
                    md$deps <- NULL
                }
                md$parentDep <- parent
                flret <<- c(flret, setNames(list(md), d))
            }
        }
        makeFlat(ret, parent = NULL)
        return(flret)
    }
    
    return(ret)
}

checkRDepsVersion <- function(ver)
{
    # nothing yet, in case we need to handle compatibility issues with eg patRoonInst
    return(TRUE)
}
