# re-process sensitivity results for graphing

read_tbl_long <- function(x, delim = "|", trim_ws = TRUE) {
  
  if (delim == ",") {
    df <- readr::read_csv(x)
  } else {
    df <- readr::read_delim(x, delim = delim, trim_ws = trim_ws)
  }
  
  df |> tidyr::pivot_longer(cols = -cc_iso3c, names_to = "var")
  
}

sens_all <- purrr::map_dfr(.x = dir("tables", 
                                    pattern = "table_B.*txt",
                                    full.names = TRUE),
                           .f = read_tbl_long,
                           .id = "group") |>
  dplyr::mutate(
    group = as.numeric(dplyr::if_else(grepl("2019", var), "0", group)),
  ) |>
  dplyr::distinct() |>
  dplyr::mutate(ord = dplyr::row_number(), .by = "cc_iso3c") |>
  dplyr::filter(cc_iso3c != "MAE") |>
  dplyr::arrange(cc_iso3c, ord, var) |>
  dplyr::select(cc_iso3c, var, value, group, ord)

readr::write_excel_csv(sens_all, "tables/table_B.csv")
