library("miniCRAN")

# get regular and BioC repositories, omegahat for XML
# repos <- c(BiocManager::repositories(), "http://www.omegahat.net/R")
repos <- c(BiocManager::repositories())

GHDeps <- c("BSchamberger/RDCOMClient", # fixes for recent R versions
            "cbroeckl/RAMClustR",
            "blosloos/nontargetData",
            "blosloos/nontarget",
            "rickhelmus/KPIC2",
            "Bioconductor/GenomeInfoDbData", # dep that doesn't have binaries. Put before cliqueMS!
            "rickhelmus/cliqueMS",
            "KelseyChetnik/MetaClean")
            

pdb <- pkgAvail(repos = repos, type = "win.binary")
pdb <- addPackageListingGithub(pdb = pdb, "rickhelmus/patRoon", branch = "master")
for (dep in GHDeps)
    pdb <- addPackageListingGithub(pdb = pdb, dep, branch = "master")
# pdb <- miniCRAN:::addPackageListing(pdb, miniCRAN:::readDescription("~/Rproj/patRoon/DESCRIPTION"))

pkgDeps <- c("RDCOMClient", "RAMClustR", "nontargetData", "nontarget", "KPIC", "cliqueMS", "MetaClean")
pkgList <- pkgDep(c("patRoon", "installr", "BiocManager", "rJava", "remotes", "pkgbuild", pkgDeps),
                  availPkgs = pdb, repos = repos, type = "win.binary", suggests = FALSE)

makeGHPackage <- function(repos, pkgDir)
{
    cloneDir <- tempfile("ghclone");
    git2r::clone(paste0("https://github.com/", repos), cloneDir)
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
        remotes::install_github("rickhelmus/patRoon")
    }
    makeGHPackage("rickhelmus/patRoon", pkgDir)
}

for (dep in GHDeps)
    makeGHPackage(dep, pkgDir)

RVers <- paste(R.Version()$major, floor(as.numeric(R.Version()$minor)), sep = ".")
packagesFile <- paste0("bin/windows/contrib/", RVers, "/PACKAGES")

localPackages <- c(pkgDeps, "GenomeInfoDbData", "patRoon")
if (R.Version()$major < 4)
    localPackages <- c(localPackages, "XML")

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
    
    if (file.exists(packagesFile) && length(removedPackages) > 0)
    {
        file.remove(list.files(paste0("bin/windows/contrib/", RVers), full.names = TRUE,
                               pattern = paste0(sprintf("^%s_.+\\.zip", removedPackages), collapse = "|")))
        updateRepoIndex(".", "win.binary")
    }
    
    if (length(newPackages) > 0)
        addPackage(newPackages, ".", repos = repos, type = "win.binary")
    
    updatePackages(".", repos = repos, ask = FALSE, type = "win.binary")
    
    
    
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
    else
        addLocalPackage(pkg, pkgDir, ".", "win.binary", build = FALSE, deps = TRUE)
    
}

# updatePackages(".", repos = repos, type = "win.binary", ask = FALSE)


# after building binary package in RStudio
# addLocalPackage("patRoon", "~/Rproj", ".", type = "win.binary")

# p <- makeDepGraph("patRoon", availPkgs = pdb)
# plot(p)
