# RExePath <- "../R-win.exe" # on Appveyor

RExePath <- if (Sys.getenv("GITHUB_ACTIONS") == "true")
{
    sprintf("D:/a/_temp/R-%s-win.exe", getRversion()) # HACK: maybe not very maintainable, let's see...
} else {
    dl <- tempfile(fileext = ".exe")
    stopifnot(download.file("https://cloud.r-project.org/bin/windows/base/R-4.3.1-win.exe",
                            dl, mode = "wb") == 0)
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
cat("\n# Customization of patRoon",
    "options(repos = c(CRAN = \"https://cran.rstudio.com/\", patRoonDeps = \"https://rickhelmus.github.io/patRoonDeps/\"))",
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
    system2(file.path(RExtrDir, "R", "bin", "Rscript.exe"), c("-e", shQuote(code)))
}

libSite <- normalizePath(file.path(RExtrDir, "R", "library"), winslash = "/")
execInR(sprintf('install.packages("patRoon", repos = "file:///%s", type = "binary", lib = "%s")',
                normalizePath(".", winslash = "/"), libSite))
execInR(sprintf(paste(lib = "%s",
                      'install.packages("remotes", repos = "cran.rstudio.com", lib = lib)',
                      'remotes::install_github("rickhelmus/patRoonData", lib = lib)',
                      'remotes::install_github("rickhelmus/patRoonExt, lib = lib)',
                      sep = ";"), libSite))

output <- normalizePath(sprintf("patRoon-bundle-%s.zip", packageVersion("patRoon", libSite)))
unlink(output)
withr::with_dir(RExtrDir, utils::zip(output, Sys.glob("*")))
