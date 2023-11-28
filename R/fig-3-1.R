# code to get data for recreating figure 3.1 in the report

oecd_attain_url <- "https://stats.oecd.org/sdmx-json/data/DP_LIVE/.EDUTRY.../OECD?contentType=csv&detail=code&separator=comma&csv-lang=en"

oecd_attain_df <- readr::read_csv(oecd_attain_url)

attain_chart_df <- oecd_attain_df |>
  janitor::clean_names() |>
  dplyr::filter(location %in% c("CAN", "FRA", "JPN", "SWE"),
                subject %in% c("25_34", "55_64"),
                time >= 1997 & time < 2018) |>
  dplyr::mutate(
    subject = paste0(gsub("_", "-", subject), " years"),
    country = dplyr::case_match(
      location,
      "CAN" ~ "Canada",
      "FRA" ~ "France",
      "JPN" ~ "Japan",
      "SWE" ~ "Sweden"
    ),
    group = paste(country, subject)
  ) |>
  dplyr::select(
    country, subject, group, year = time, value
  )

readr::write_csv(attain_chart_df, "tables/fig-3-1-data.csv")

