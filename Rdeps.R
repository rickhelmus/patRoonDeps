getRDependencies <- function()
{
    list(
        RDCOMClient = list(type = "gh", user = "omegahat"),
        RAMClustR = list(
            type = "gh",
            user = "cbroeckl",
            commit = "e005614",
            deps = list(
                InterpretMSSpectrum = list(type = "gh", user = "cran", tag = "1.3.3")
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
}
