library("miniCRAN")

# get regular and BioC repositories
repos <- BiocManager::repositories()

pdb <- pkgAvail(repos = repos, type = "win.binary")
pdb <- addPackageListingGithub(pdb = pdb, "rickhelmus/patRoon")
# pdb <- miniCRAN:::addPackageListing(pdb, miniCRAN:::readDescription("~/Rproj/patRoon/DESCRIPTION"))

pkgList <- pkgDep("patRoon", availPkgs = pdb, repos = repos, type = "win.binary", suggests = FALSE)

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

unlink("bin", recursive = TRUE)
makeRepo(pkgList, path = ".", repos = repos, type = c("win.binary"))
addLocalPackage(c("patRoon", "patRoonData", "RAMClustR"), pkgDir, ".", "win.binary", build = FALSE, deps = TRUE)
addPackage(c("installr", "BiocManager", "rJava", "remotes", "pkgbuild"), ".", type = "win.binary") # needed for install script    
addPackage("RDCOMClient", ".", repos = c("http://www.omegahat.net/R", repos), type = "win.binary")

# updatePackages(".", repos = repos, type = "win.binary", ask = FALSE)


# after building binary package in RStudio
# addLocalPackage("patRoon", "~/Rproj", ".", type = "win.binary")

# p <- makeDepGraph("patRoon", availPkgs = pdb)
# plot(p)
