### {gt} helpers
### functions to assist with table output

# read markdown table
read_md_tbl <- function(x) {
  
  x <- readLines(x)
  
  readr::read_delim(
    I(x[!grepl("^(:?)={2}", x)]),
    delim = "|",
    trim_ws = TRUE
  )
  
}

# function to convert character percentages into dbl vectors with formatting
convert_percent <- function(x, digits = 0, scale = 100) {
  formattable::percent(
    as.numeric(gsub("%", "", x))/scale,
    digits = digits
  )
}

# function to insert a RAG rating image
rag_image <- function(x) {
  
  x <- tolower(substr(x, 1, 1))
  
  alt <- dplyr::case_when(
    x == "g" ~ "Green",
    x == "a" ~ "Amber",
    x == "r" ~ "Red",
    TRUE ~ "x"
  )
  
  img <- dplyr::case_when(
    x == "g" ~ "figures/green-circle.png",
    x == "a" ~ "figures/amber-circle.png",
    x == "r" ~ "figures/red-circle.png",
    TRUE ~ "figures/grey-x.png"
  )
  
  paste0("<img src=\"", img, "\" alt=\"", alt,"\">")
  
}

# function to strip a gt::gt() for optimal processing
#   - convert to HTML object and force css class names
#   - remove containing div (local style defs), set as a table.table
strip_gt <- function(x) {
  x |> 
    gt::as_raw_html(inline_css = FALSE) |>
    gsub(".*?<table.+?>", "<table class=\"table\">", x = _) |>
    gsub("</table>.*", "</table>", x = _)
}

# function to create standard composition tables in chapter 3
composition_table <- function(x, ind) {
  x |>
    dplyr::filter(indicator == ind) |>
    dplyr::select(theme, label, source_out, type, proxy, transform, wt_intheme,
                  wt_theme, wt_total, source_definition) |>
    gt::gt(groupname_col = "theme") |>
    gt::tab_spanner(label = "Weighting within indicator",
                    columns = c(wt_intheme, wt_theme, wt_total)) |>
    gt::cols_label(
      theme = "Theme", label = "Metric", source_out = "Source", type = "Type",
      proxy = "Public sector proxy", transform = "Data transformation",
      wt_intheme = "In theme (A)", wt_theme = "Theme (B)",
      wt_total = "Total (C=A*B)",
      source_definition = "Definition of the source metric (e.g. question wording)"
    ) |>
    gt::cols_align("center", c(source_out, wt_intheme, wt_theme, wt_total))
}

composite_metrics_table <- function(df, ind, footnote) {
  
  out <- df |>
    dplyr::filter(indicator == ind) |>
    dplyr::arrange(order) |>
    dplyr::group_by(metric_label) |>
    dplyr::select(order, metric_label, datapoint_label, coding, composite_calc) |>
    dplyr::add_count(metric_label, name = "rowspan") |>
    dplyr::mutate(
      lead_cell = tidyr::replace_na(metric_label != dplyr::lag(metric_label), TRUE)
    ) |>
    tidyr::pivot_longer(cols = c(-order, -rowspan, -lead_cell)) |>
    dplyr::mutate(
      content = gsub(" (\\[Range)", "<br>\\1", value),
      tr_open = dplyr::if_else(name == "metric_label", "<tr>\n", ""),
      tr_close = dplyr::if_else(name == "composite_calc", "</tr>\n", ""),
      td_tag = dplyr::case_when(
        lead_cell & name == "metric_label" ~ 
          paste0("<td class=\"gt_row gt_left\" rowspan=\"", rowspan,"\">", content, "</td>\n"),
        lead_cell & name == "composite_calc" ~ 
          paste0("<td class=\"gt_row gt_left\" rowspan =\"", rowspan,"\">", content, "</td>\n"),
        name == "metric_label" | name == "composite_calc" ~ "",
        TRUE ~ paste0("<td class=\"gt_row gt_left\">", content, "</td>\n")
      ),
      html_line = paste0(tr_open, td_tag, tr_close)
    )
  
  html_tbl_top <- paste0(
    c("<table class=\"table table-sm small composite-metrics-tbl\">",
      "<colgroup>",
      "<col span=\"1\" style=\"width: 20%;\">",
      "<col span=\"1\" style=\"width: 40%;\">",
      "<col span=\"1\" style=\"width: 20%;\">",
      "<col span=\"1\" style=\"width: 20%;\">",
      "</colgroup>",
      "<thead>\n<tr class=\"header gt_col_headings\">",
      "<th class=\"gt_col_heading gt_columns_bottom_border\" scope=\"col\">InCiSE metric</th>",
      "<th class=\"gt_col_heading gt_columns_bottom_border\" scope=\"col\">Source variables</th>",
      "<th class=\"gt_col_heading gt_columns_bottom_border\" scope=\"col\">Coding</th>",
      "<th class=\"gt_col_heading gt_columns_bottom_border\" scope=\"col\">Calculation</th>",
      "</tr>\n</thead>\n<tbody class=\"gt_table_body\">\n"), 
    collapse = "\n"
  )
  
  html_tbl_bottom <- paste0(
    c("</tbody>",
      "<tfoot class=\"gt_footnotes\"><tr>",
      paste0("<td class=\"gt_footnote\" colspan=\"4\">", footnote, "</td>"),
      "</tr></tfoot>",
      "</table>"),
    collapse = "\n"
  )
  
  html_out <- paste0(
    html_tbl_top, paste0(out$html_line, collapse = ""), html_tbl_bottom
  )
  
  htmltools::HTML(html_out)
  
}
