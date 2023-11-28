### functions to get/output cross-references

# scan a qmd file for section references
get_qmd_secs <- function(qmd_file) {
  
  if (is.na(qmd_file)) {
    return(NULL)
  }
  
  x <- readLines(qmd_file)
  
  tibble::tibble(
    input = x[grepl("#sec-", x)]
  ) |>
    dplyr::mutate(
      level = nchar(gsub("(^#+).*", "\\1", input)),
      reference = gsub(".*\\{#(sec.+)}$", "\\1", input),
      name = gsub("^#+ (.*) \\{#sec.+}$", "\\1", input),
      sec_num = dplyr::row_number() - 1
    ) |>
    dplyr::select(-input)
  
}

# scan a qmd file for tbl refefences
get_qmd_tbls <- function(qmd_file) {
  
  if (is.na(qmd_file)) {
    return(NULL)
  }
  
  x <- readLines(qmd_file)
  
  tibble::tibble(
    input = x[grepl("#\\| (label: tbl|tbl-cap|  )", x)]
  ) |>
    dplyr::mutate(
      what = dplyr::case_when(
        grepl("#\\| label:", input) ~ "reference",
        TRUE ~ "name"
      ),
      group = cumsum(what == "reference"),
      text = gsub("#\\| (label: |tbl-cap: |  )", "", input)
    ) |>
    tidyr::pivot_wider(
      id_cols = group,
      names_from = what,
      values_from = text,
      values_fn = ~paste0(.x, collapse = " ")
    )
  
}

# scan a qmd file for fig refefences
get_qmd_figs <- function(qmd_file) {
  
  if (is.na(qmd_file)) {
    return(NULL)
  }
  
  x <- readLines(qmd_file)
  
  inline_fig_pos <- which(grepl("#fig", x))
  
  inline_figs <- tibble::tibble(
    input = x[grepl("#fig", x)],
    fig_pos = which(grepl("#fig", x))
  ) |>
    dplyr::mutate(
      group = dplyr::row_number(),
      reference = gsub(".*\\{#(fig-.+)\\}.*", "\\1", input),
      name = gsub(".*\\[(.+)\\].*", "\\1", input)
    ) |>
    dplyr::select(-input)
  
  code_figs <- tibble::tibble(
    input = x[grepl("#\\| (label: fig|fig-cap)", x)],
    fig_pos = which(grepl("#\\| (label: fig)", x))
    ) |>
    dplyr::mutate(
      what = dplyr::case_when(
        grepl("#\\| label:", input) ~ "reference",
        TRUE ~ "name"
      ),
      group = cumsum(what == "reference"),
      text = gsub("#\\| (label: |fig-cap: |  )", "", input)
    ) |>
    tidyr::pivot_wider(
      id_cols = c(group, fig_pos),
      names_from = what,
      values_from = text,
      values_fn = ~paste0(.x, collapse = " ")
    )
  
  inline_figs |>
    dplyr::bind_rows(code_figs) |>
    dplyr::arrange(fig_pos) |>
    dplyr::mutate(group = dplyr::row_number()) |>
    dplyr::select(-fig_pos)
  
}

# get a df of parts from a quarto book
get_book_parts <- function(what = c("sec", "tbl", "fig"), input = ".",
                           insert_breaks = TRUE) {
  
  what <- match.arg(what)
  
  x <- quarto::quarto_inspect(input)
  y <- x$config$project$render
  
  if (what == "sec") {
    out <- purrr::map_dfr(y, get_qmd_secs, .id = "source") |>
      dplyr::mutate(
        source = y[as.numeric(source)],
        indent = purrr::map_chr(
          level, 
          ~paste0(rep(" ", (.x - 1) * 4), collapse = "")
        ),
        output = paste0(indent, "* @", reference, ": ", name),
        output = dplyr::if_else(
          grepl("unnumbered", reference),
          paste0(indent, "* [", name,"](", source, ")"),
          output
        )
      )
  } else if (what == "tbl" | what == "fig") {
    
    if (what == "tbl") {
      df <- purrr::map_dfr(y, get_qmd_tbls, .id = "source")
    } else if (what == "fig") {
      df <- purrr::map_dfr(y, get_qmd_figs, .id = "source")
    }
    
    out <- df |>
      dplyr::mutate(source = y[as.numeric(source)]) |>
      dplyr::add_row(
        source = sort(unique(y)),
        group = Inf
      ) |>
      dplyr::add_count(source) |>
      dplyr::filter(n > 1) |>
      dplyr::arrange(source, group) |>
      dplyr::mutate(
        output = dplyr::if_else(
          group == Inf,
          "\n******\n",
          paste0("* @", reference, ": ", name)
        )
      )
    
    if (!insert_breaks) {
      out <- out |>
        dplyr::filter(output != "\n******\n")
    } else if (out$output[nrow(out)] == "\n******\n") {
      out <- out[1:(nrow(out) - 1), ]
    }
    
  } else {
    return(NULL)
  }
  
  return(out)
  
}

# generate a markdown list for inclusion in a document
get_content_list <- function(what = c("sec", "tbl", "fig"), input = ".",
                             insert_breaks = TRUE) {
  
  what <- match.arg(what)
  
  x <- get_book_parts(what, input, insert_breaks)
  
  return(x$output)
  
}
