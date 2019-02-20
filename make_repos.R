library("miniCRAN")

# get regular and BioC repositories
repos <- BiocManager::repositories()

pdb <- pkgAvail(repos = repos, type = "win.binary")
pdb <- addPackageListingGithub(pdb = pdb, "rickhelmus/patRoon")
# pdb <- miniCRAN:::addPackageListing(pdb, miniCRAN:::readDescription("~/Rproj/patRoon/DESCRIPTION"))

patDir <- tempfile("patRoon"); patDDir <- tempfile("patRoonData"); patPkgDir <- tempfile("patRoonPkg")
git2r::clone("https://github.com/rickhelmus/patRoon", patDir)
git2r::clone("https://github.com/rickhelmus/patRoonData", patDDir)
dir.create(patPkgDir)
devtools::build(patDir, patPkgDir, binary = TRUE, vignettes = FALSE)
devtools::build(patDDir, patPkgDir, binary = TRUE, vignettes = FALSE)

pkgList <- pkgDep("patRoon", availPkgs = pdb, repos = repos, type = "win.binary", suggests = FALSE)

unlink("bin", recursive = TRUE)
makeRepo(pkgList, path = ".", repos = repos, type = c("win.binary"))
addLocalPackage("patRoon", patPkgDir, ".", "win.binary", build = FALSE, deps = TRUE)
addLocalPackage("patRoonData", patPkgDir, ".", "win.binary", build = FALSE, deps = TRUE)
addPackage(c("installr", "BiocManager", "rJava", "remotes", "pkgbuild"), ".", type = "win.binary") # needed for install script    

# updatePackages(".", repos = repos, type = "win.binary", ask = FALSE)


# after building binary package in RStudio
# addLocalPackage("patRoon", "~/Rproj", ".", type = "win.binary")

# p <- makeDepGraph("patRoon", availPkgs = pdb)
# plot(p)
