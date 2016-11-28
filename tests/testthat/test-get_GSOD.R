context("get_GSOD")
# Check that .validate_years handles invalid years -----------------------------
test_that(".validate_years handles invalid years", {
  skip_on_cran()

  expect_error(.validate_years(years = NULL),
               "\nYou must provide at least one year of data to download in a numeric\n         format.\n")
  expect_error(.validate_years(years = "nineteen ninety two"),
                "\nYou must provide at least one year of data to download in a numeric\n         format.\n")
  expect_error(.validate_years(years = 1923),
               "\nThe GSOD data files start at 1929, you have entered a year prior\n             to 1929.\n")
  expect_error(.validate_years(years = 1901 + as.POSIXlt(Sys.Date())$year),
               "\nThe year cannot be greater than current year.\n")

})

# Check that .validate_years handles valid years -------------------------------
test_that(".validate_years handles valid years", {
  skip_on_cran()
  expect_error(.validate_years(years = 1929:2016), regexp = NA)

  expect_error(.validate_years(years = 2016), regexp = NA)

})

# Check that invalid stations are handled --------------------------------------
test_that("invalid stations are handled", {
  skip_on_cran()
  stations <- get_station_list()
  expect_error(.validate_station(years = 2015, station = "aaa-bbbbbb", stations),
               "\naaa-bbbbbb is not a valid station ID number, please check\n      your entry. Station IDs are provided as a part of the GSODR package in the\n      'stations' data\nin the STNID column.\n")
})

# Check that invalid dsn is handled --------------------------------------------
test_that("invalid dsn is handled", {
  skip_on_cran()

  expect_error(.validate_fileout(CSV = FALSE, dsn = "~/NULL", filename = NULL,
                                 GPKG = FALSE),
               "\nFile dsn does not exist: ~/NULL.\n")
  expect_error(.validate_fileout(CSV = FALSE, dsn = NULL, filename = "test",
                                 GPKG = FALSE),
               "\nYou need to specify a filetype, CSV or GPKG.")
})

# Check stations list and associated metadata for validity ---------------------
test_that("stations list and associated metatdata", {
  skip_on_cran()

  stations <- get_station_list()

  expect_length(stations, 13)

  expect_is(stations, "data.table")
  expect_is(stations$USAF, "character")
  expect_is(stations$WBAN, "character")
  expect_is(stations$STN_NAME, "character")
  expect_is(stations$CTRY, "character")
  expect_is(stations$STATE, "character")
  expect_is(stations$CALL, "character")
  expect_is(stations$LAT, "numeric")
  expect_is(stations$LON, "numeric")
  expect_is(stations$ELEV_M, "numeric")
  expect_is(stations$BEGIN, "numeric")
  expect_is(stations$END, "numeric")
  expect_is(stations$STNID, "character")
  expect_is(stations$ELEV_M_SRTM_90m, "numeric")

  expect_gt(nrow(stations), 2300)
})

# Check missing days in non-leap years -----------------------------------------
test_that("missing days check allows stations with permissible days missing,
          non-leap year", {
            skip_on_cran()
            max_missing <- 5
            td <- tempdir()
            just_right_2015 <- data.frame(c(rep(12, 360)), c(rep("X", 360)))
            too_short_2015 <- data.frame(c(rep(12, 300)), c(rep("X", 300)))
            df_list <- list(just_right_2015, too_short_2015)

            filenames <- c("just_right_2015", "too_short_2015")
            sapply(1:length(df_list),
                   function(x) write.csv(df_list[[x]],
                                         file = gzfile(
                                           paste0(td, "/", filenames[x],
                                                  ".csv.gz"))
                   )
            )
            GSOD_list <-
              list.files(path = td,
                         pattern = ".2015.csv.gz$",
                         full.names = TRUE)
            GSOD_list_filtered <- .validate_missing_days(max_missing, GSOD_list)

            expect_length(GSOD_list, 2)
            expect_match(basename(GSOD_list_filtered), "just_right_2015.csv.gz")
            unlink(td)
          })

# Check missing days in leap years ---------------------------------------------
test_that("missing days check allows stations with permissible days missing,
          leap year", {
            skip_on_cran()
            max_missing <- 5
            td <- tempdir()
            just_right_2016 <- data.frame(c(rep(12, 361)), c(rep("X", 361)))
            too_short_2016 <- data.frame(c(rep(12, 300)), c(rep("X", 300)))
            df_list <- list(just_right_2016, too_short_2016)

            filenames <- c("just_right_2016", "too_short_2016")
            sapply(1:length(df_list),
                   function(x) write.csv(df_list[[x]],
                                         file = gzfile(
                                           paste0(td, "/", filenames[x],
                                                  ".csv.gz"))
                   )
            )
            GSOD_list <-
              list.files(path = td,
                         pattern = ".2016.csv.gz$",
                         full.names = TRUE)
            GSOD_list_filtered <- .validate_missing_days(max_missing, GSOD_list)

            expect_length(GSOD_list, 2)
            expect_match(basename(GSOD_list_filtered), "just_right_2016.csv.gz")
            unlink(td)
          })

# Check validate country returns a two letter code -----------------------------
test_that("Check validate country returns a two letter code", {
  skip_on_cran()
  country <- "Philippines"
  Philippines <- .validate_country(country)
  expect_match(Philippines, "RP")

  country <- "PHL"
  PHL <- .validate_country(country)
  expect_match(PHL, "RP")

  country <- "PH"
  PH <- .validate_country(country)
  expect_match(PH, "RP")
})

# Check validate country returns an error on invalid entry----------------------
test_that("Check validate country returns an error on invalid entry", {
  skip_on_cran()
  country <- "Philipines"
  expect_error(.validate_country(country),
               "\nPlease provide a valid name or 2 or 3 letter ISO country code;\n              you can view the entire list of valid countries in this data by\n              typing, 'country_list'.\n")

  country <- "RP"
  expect_error(.validate_country(country),
               "\nPlease provide a valid name or 2 or 3 letter ISO country code;\n              you can view the entire list of valid countries in this data by\n              typing, 'country_list'.\n")

})

# Check that .download_files,subsetting agro and ctry stations work.------------
# Check that .process_gz works properly and returns a data table.
test_that(".download_files properly works, subsetting for country and
          agroclimatology works and .process_gz returns a data table", {
            skip_on_cran()
            skip_on_appveyor() # appveyor will not properly untar the file
            years <- 2015
            agroclimatology <- TRUE
            country <- "RP"
            station <- NULL
            cache_dir <- tempdir()
            ftp_base <- "ftp://ftp.ncdc.noaa.gov/pub/data/gsod/%s/"

            stations <- get_station_list()

            GSOD_list <- .download_files(ftp_base, station, years, cache_dir)

            expect_length(GSOD_list, 12976)

            agro_list <- .agroclimatology_list(GSOD_list, stations, cache_dir
                                               , years)
            expect_length(agro_list, 11302)

            RP_list <- .country_list(country, GSOD_list, stations, cache_dir,
                                     years)
            expect_length(RP_list, 53)

# Check that .process_gz returns a properly formated data table-----------------
            gz_file <- GSOD_list[[10]]
            gz_out <- .process_gz(gz_file, stations)

            expect_length(gz_out, 48)

            expect_is(gz_out, "data.table")

            expect_is(gz_out$USAF, "character")
            expect_is(gz_out$WBAN, "character")
            expect_is(gz_out$STNID, "character")
            expect_is(gz_out$STN_NAME, "character")
            expect_is(gz_out$CTRY, "character")
            expect_is(gz_out$CALL, "character")
            expect_is(gz_out$STATE, "character")
            expect_is(gz_out$CALL, "character")
            expect_is(gz_out$LAT, "numeric")
            expect_is(gz_out$LON, "numeric")
            expect_is(gz_out$ELEV_M, "numeric")
            expect_is(gz_out$ELEV_M_SRTM_90m, "numeric")
            expect_is(gz_out$BEGIN, "numeric")
            expect_is(gz_out$END, "numeric")
            expect_is(gz_out$YEARMODA, "character")
            expect_is(gz_out$YEAR, "character")
            expect_is(gz_out$MONTH, "character")
            expect_is(gz_out$DAY, "character")
            expect_is(gz_out$YDAY, "numeric")
            expect_is(gz_out$TEMP, "numeric")
            expect_is(gz_out$TEMP_CNT, "integer")
            expect_is(gz_out$DEWP, "numeric")
            expect_is(gz_out$DEWP_CNT, "integer")
            expect_is(gz_out$SLP, "numeric")
            expect_is(gz_out$SLP_CNT, "integer")
            expect_is(gz_out$STP, "numeric")
            expect_is(gz_out$STP_CNT, "integer")
            expect_is(gz_out$VISIB, "numeric")
            expect_is(gz_out$VISIB_CNT, "integer")
            expect_is(gz_out$WDSP, "numeric")
            expect_is(gz_out$WDSP_CNT, "integer")
            expect_is(gz_out$MXSPD, "numeric")
            expect_is(gz_out$GUST, "numeric")
            expect_is(gz_out$MAX, "numeric")
            expect_is(gz_out$MAX_FLAG, "character")
            expect_is(gz_out$MIN, "numeric")
            expect_is(gz_out$MIN_FLAG, "character")
            expect_is(gz_out$PRCP, "numeric")
            expect_is(gz_out$PRCP_FLAG, "character")
            expect_is(gz_out$SNDP, "numeric")
            expect_is(gz_out$I_FOG, "integer")
            expect_is(gz_out$I_RAIN_DRIZZLE, "integer")
            expect_is(gz_out$I_SNOW_ICE, "integer")
            expect_is(gz_out$I_HAIL, "integer")
            expect_is(gz_out$I_THUNDER, "integer")
            expect_is(gz_out$I_TORNADO_FUNNEL, "integer")
            expect_is(gz_out$EA, "numeric")
            expect_is(gz_out$ES, "numeric")
            expect_is(gz_out$RH, "numeric")

          })