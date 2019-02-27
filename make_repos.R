library("miniCRAN")

# get regular and BioC repositories, omegahat for RDCOMClient
repos <- c(BiocManager::repositories(), "http://www.omegahat.net/R")

pdb <- pkgAvail(repos = repos, type = "win.binary")
pdb <- addPackageListingGithub(pdb = pdb, "rickhelmus/patRoon")
pdb <- addPackageListingGithub(pdb = pdb, "rickhelmus/patRoonData")
pdb <- addPackageListingGithub(pdb = pdb, "cbroeckl/RAMClustR")
# pdb <- miniCRAN:::addPackageListing(pdb, miniCRAN:::readDescription("~/Rproj/patRoon/DESCRIPTION"))

pkgList <- pkgDep(c("patRoon", "patRoonData", "RAMClustR", "installr", "BiocManager", "rJava", "remotes", "pkgbuild", "RDCOMClient"),
                  availPkgs = pdb, repos = repos, type = "win.binary", suggests = FALSE)

makeGHPackage <- function(repos, pkgDir)
{
    cloneDir <- tempfile("ghclone");
    git2r::clone(paste0("https://github.com/", repos), cloneDir)
    dir.create(pkgDir, recursive = TRUE)
    devtools::build(cloneDir, pkgDir, binary = TRUE, vignettes = FALSE)
}

pkgDir <- tempfile("ghpkgs")
makeGHPackage("rickhelmus/patRoon", pkgDir)
makeGHPackage("rickhelmus/patRoonData", pkgDir)
makeGHPackage("cbroeckl/RAMClustR", pkgDir)

if (TRUE)
{
    regex <- "^Package: (.*)$" # inspired by https://github.com/andrie/miniCRAN/issues/79
    packagesFile <- readLines("bin/windows/contrib/3.5/PACKAGES")
    packages <- packagesFile[grepl(regex, packagesFile)]
    packages <- gsub(regex, "\\1", packages)
    
    removedPackages <- packages[!packages %in% pkgList]
    newPackages <- pkgList[!pkgList %in% packages]
    
    # will be re-added
    removedPackages <- union(removedPackages, c("patRoon", "patRoonData", "RAMClustR"))
    
    if (length(removedPackages) > 0)
    {
        file.remove(list.files("bin/windows/contrib/3.5/", full.names = TRUE,
                               pattern = paste0(sprintf("^%s_.+\\.zip", removedPackages), collapse = "|")))
        updateRepoIndex(".", "win.binary")
    }
    
    if (length(newPackages) > 0)
        addPackage(newPackages, ".", repos = repos, type = "win.binary")
    
    updatePackages(".", repos = repos, ask = FALSE, type = "win.binary")
    addLocalPackage("patRoon|patRoonData|RAMClustR", pkgDir, ".", "win.binary", build = FALSE, deps = TRUE)
    
} else
{
    unlink("bin", recursive = TRUE)
    makeRepo(pkgList, path = ".", repos = repos, type = c("win.binary"))    
    
    addLocalPackage("patRoon|patRoonData|RAMClustR", pkgDir, ".", "win.binary", build = FALSE, deps = TRUE)
    addPackage(c("installr", "BiocManager", "rJava", "remotes", "pkgbuild"), ".", type = "win.binary") # needed for install script    
    addPackage("RDCOMClient", ".", repos = c("http://www.omegahat.net/R", repos), type = "win.binary")
}



# updatePackages(".", repos = repos, type = "win.binary", ask = FALSE)


# after building binary package in RStudio
# addLocalPackage("patRoon", "~/Rproj", ".", type = "win.binary")

# p <- makeDepGraph("patRoon", availPkgs = pdb)
# plot(p)
