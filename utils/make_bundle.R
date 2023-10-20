# RExePath <- "../R-win.exe" # on Appveyor

RExePath <- if (Sys.getenv("GITHUB_ACTIONS") == "true")
{
    sprintf("D:/a/_temp/R-%s-win.exe", getRversion()) # HACK: maybe not very maintainable, let's see...
} else {
    dl <- tempfile(fileext = ".exe")
    stopifnot(download.file("https://cloud.r-project.org/bin/windows/base/R-4.3.1-win.exe",
                            dl, mode = "wb") == 0)
    dl
}


IEZip <- tempfile(fileext = ".zip")
stopifnot(download.file("https://constexpr.org/innoextract/files/innoextract-1.9-windows.zip",
                        IEZip, mode = "wb") == 0)

IEDir <- tempfile()
unzip(IEZip, exdir = IEDir)

RExtrDir <- tempfile()
stopifnot(system2(file.path(IEDir, "innoextract.exe"), c("-ed", RExtrDir, RExePath)) == 0)

file.rename(file.path(RExtrDir, "app"), file.path(RExtrDir, "R"))
file.copy("bundle/Renviron.site", file.path(RExtrDir, "R", "etc"), overwrite = TRUE)

# UNDONE: for now leave the repos as the default, mainly since patRoonInst already deals with setting up the repos
# cat("\n# Customization of patRoon",
#     "options(repos = c(CRAN = \"https://cran.rstudio.com/\", patRoonDeps = \"https://rickhelmus.github.io/patRoonDeps/\"))",
#     sep = "\n", file = file.path(RExtrDir, "R", "etc", "Rprofile.site"), append = TRUE)
cat("\n# Customization of patRoon",
    "options(repos = c(CRAN = \"https://cran.rstudio.com/\"))",
    sep = "\n", file = file.path(RExtrDir, "R", "etc", "Rprofile.site"), append = TRUE)

for (dir in c(file.path(RExtrDir, "user", "library"),
              file.path(RExtrDir, "user", "Rdata"),
              file.path(RExtrDir, "user", "Rconfig"),
              file.path(RExtrDir, "user", "Rcache"),
              file.path(RExtrDir, "tmp")))
     dir.create(dir, recursive = TRUE)

JDKZip <-  tempfile(fileext = ".zip")
stopifnot(download.file("https://api.adoptium.net/v3/binary/latest/17/ga/windows/x64/jdk/hotspot/normal/eclipse",
                        JDKZip, mode = "wb") == 0)
unzip(JDKZip, exdir = RExtrDir)
# remove version from JDK directory name
JDKDir <- list.files(RExtrDir, pattern = "^jdk\\-", full.names = TRUE)
stopifnot(length(JDKDir) == 1)
file.rename(JDKDir, file.path(RExtrDir, "jdk"))

execInR <- function(code)
{
    stopifnot(system2(file.path(RExtrDir, "R", "bin", "Rscript.exe"), c("-e", shQuote(code))) == 0)
}

Rlib <- normalizePath(file.path(RExtrDir, "R", "library"), winslash = "/")

execInR(sprintf(paste('install.packages("remotes")',
                      'thisRVersion <- paste(R.Version()$major, floor(as.numeric(R.Version()$minor)), sep = ".")',
                      'pkgdir <- file.path("%s", thisRVersion)',
                      'install.packages(Sys.glob(paste0(pkgdir, "/*.zip")), repos = NULL, type = "win.binary")',
                      'remotes::install_github("rickhelmus/patRoonData")',
                      'remotes::install_github("rickhelmus/patRoonExt")',
                      'remotes::install_github("rickhelmus/patRoonInst")',
                      sep = ";"),
                normalizePath("bin/windows/contrib", winslash = "/")))

# get current GH hash so we can tag it in the bundle file name
SHA <- read.dcf(file.path(RExtrDir, "user", "library", "patRoon", "DESCRIPTION"))[, "RemoteSha"]

output <- normalizePath(sprintf("patRoon-bundle-%s.zip", strtrim(SHA, 7)), mustWork = FALSE)
unlink(output)
withr::with_dir(RExtrDir, utils::zip(output, Sys.glob("*")))
