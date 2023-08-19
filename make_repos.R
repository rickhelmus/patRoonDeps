library("miniCRAN")

# get regular and BioC repositories, omegahat for XML
# repos <- c(BiocManager::repositories(), "http://www.omegahat.net/R")
repos <- c(BiocManager::repositories())

GHDeps <- c("omegahat/RDCOMClient",
            "cran/RAMClustR",
            "blosloos/nontargetData",
            "blosloos/nontarget",
            "rickhelmus/KPIC2",
            "Bioconductor/GenomeInfoDbData", # dep that doesn't have binaries. Put before cliqueMS!
            "rickhelmus/cliqueMS",
            "souravc83/fastAdaboost", # For Metaclean, removed from CRAN (9/22)
            "KelseyChetnik/MetaClean")
GHBranches <- rep("master", length(GHDeps))
GHBranches[grepl("GenomeInfoDbData", fixed = TRUE, GHDeps)] <- "devel"

pdb <- pkgAvail(repos = repos, type = "win.binary")

patRoonRef <- Sys.getenv("GITHUB_REF", "master")
pdb <- addPackageListingGithub(pdb = pdb, "rickhelmus/patRoon", branch = patRoonRef)

pdb <- addPackageListingGithub(pdb = pdb, "cran/InterpretMSSpectrum", branch = "1.3.3")

for (i in seq_along(GHDeps))
    pdb <- addPackageListingGithub(pdb = pdb, GHDeps[i], branch = GHBranches[i])

pkgDeps <- c("RDCOMClient", "InterpretMSSpectrum", "RAMClustR", "nontargetData", "nontarget", "KPIC", "cliqueMS",
             "fastAdaboost", "MetaClean")
pkgList <- pkgDep(c("patRoon", "installr", "BiocManager", "rJava", "remotes", "pkgbuild", pkgDeps),
                  availPkgs = pdb, repos = repos, type = "win.binary", suggests = FALSE)

makeGHPackage <- function(repos, pkgDir, branch = "master")
{
    cloneDir <- tempfile("ghclone");
    git2r::clone(paste0("https://github.com/", repos), cloneDir, branch = branch)
    dir.create(pkgDir, recursive = TRUE, showWarnings = FALSE)
    devtools::build(cloneDir, pkgDir, binary = TRUE, vignettes = FALSE,
                    args = c("--no-test-load", ""))
}

fromArtifact <- !is.na(Sys.getenv("APPVEYOR", unset = NA)) &&
    rversions::r_release()$version == paste(R.Version()$major, R.Version()$minor, sep = ".")

pkgDir <- tempfile("ghpkgs")

if (!fromArtifact)
{
    if (!requireNamespace("patRoon", quietly = TRUE))
    {
        BiocManager::install("CAMERA")
        if (R.Version()$major < 4)
            install.packages("XML", repos = "https://mran.revolutionanalytics.com/snapshot/2020-07-01")
        # UNDONE: could this be combined with making the package?
        remotes::install_github("rickhelmus/patRoon", ref = patRoonRef)
    }
    makeGHPackage("rickhelmus/patRoon", pkgDir)
}

for (i in seq_along(GHDeps))
    makeGHPackage(GHDeps[i], pkgDir, branch = GHBranches[i])

localPackages <- c(pkgDeps, "GenomeInfoDbData", "patRoon")
if (R.Version()$major < 4)
    localPackages <- c(localPackages, "XML")

RVers <- paste(R.Version()$major, floor(as.numeric(R.Version()$minor)), sep = ".")
pkgPath <- file.path("bin", "windows", "contrib", RVers)
packagesFile <- file.path(pkgPath, "PACKAGES")

if (file.exists(packagesFile))
{
    regex <- "^Package: (.*)$" # inspired by https://github.com/andrie/miniCRAN/issues/79
    pLines <- readLines(packagesFile)
    packages <- pLines[grepl(regex, pLines)]
    packages <- gsub(regex, "\\1", packages)
    
    removedPackages <- packages[!packages %in% pkgList]
    newPackages <- pkgList[!pkgList %in% packages]
    newPackages <- setdiff(newPackages, localPackages)
    
    # will be re-added
    removedPackages <- union(removedPackages, localPackages)
    
    if (length(removedPackages) > 0)
    {
        file.remove(list.files(pkgPath, full.names = TRUE,
                               pattern = paste0(sprintf("^%s_.+\\.zip", removedPackages), collapse = "|")))
        updateRepoIndex(".", "win.binary")
    }
    
    if (length(newPackages) > 0)
        addPackage(newPackages, ".", repos = repos, type = "win.binary")
    
    updatePackages(".", repos = repos, ask = FALSE, type = "win.binary")
    
    # remove old versions
    pkgM <- readRDS(file.path(pkgPath, "PACKAGES.rds"))
    curPkgs <- paste0(pkgM[, "Package"], "_", pkgM[, "Version"], ".zip")
    curPkgs <- file.path(pkgPath, curPkgs)
    oldPkgs <- setdiff(list.files(pkgPath, pattern = "\\.zip", full.names = TRUE), curPkgs)
    cat("Removing old packages: ", paste0(oldPkgs, collapse = "\n"), "\n", sep = "")
    file.remove(oldPkgs)
} else
{
    unlink(file.path("bin/windows/contrib", RVers), recursive = TRUE)
    makeRepo(pkgList, path = ".", repos = repos, type = c("win.binary"))    
    # addPackage(c("installr", "BiocManager", "rJava", "remotes", "pkgbuild"), ".", type = "win.binary") # needed for install script    
    # addPackage("RDCOMClient", ".", repos = c("http://www.omegahat.net/R", repos), type = "win.binary")
}

for (pkg in localPackages)
{
    if (pkg == "patRoon")
    {
        if (fromArtifact)
        {
            # should be downloaded as artifact from AppVeyor
            addLocalPackage("patRoon", "C:/Projects", ".", "win.binary", build = FALSE, deps = TRUE)
        }
        else
            addLocalPackage("patRoon", pkgDir, ".", "win.binary", build = FALSE, deps = TRUE)
    }
    else if (pkg == "XML")
        addPackage("XML", ".", "https://mran.revolutionanalytics.com/snapshot/2020-07-01")
    else if (pkg == "InterpretMSSpectrum")
        addPackage(pkg, ".", repos = repos, type = "win.binary")
    else
        addLocalPackage(pkg, pkgDir, ".", "win.binary", build = FALSE, deps = TRUE)
    
}

# updatePackages(".", repos = repos, type = "win.binary", ask = FALSE)


# after building binary package in RStudio
# addLocalPackage("patRoon", "~/Rproj", ".", type = "win.binary")

# p <- makeDepGraph("patRoon", availPkgs = pdb)
# plot(p)
