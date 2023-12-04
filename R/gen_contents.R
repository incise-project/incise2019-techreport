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
      level = nchar(gsub("(^#+).*", "\\1", input)) - 1,
      reference = gsub(".*\\{#(sec\\S+).*\\}.*$", "\\1", input),
      name = gsub("^#+\\s(.*)\\s\\{#sec\\S+.*\\}.*$", "\\1", input),
      unnumbered = grepl("unnumbered", input),
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
                           insert_breaks = TRUE, drop_empty = TRUE) {
  
  what <- match.arg(what)
  
  x <- quarto::quarto_inspect(input)
  y <- x$config$book$render
  
  if (what == "sec") {
    out <- y |> 
      dplyr::mutate(
        order = dplyr::row_number(),
        sections = purrr::map(file, get_qmd_secs)
      ) |>
      tidyr::unnest(sections, keep_empty = TRUE) |>
      dplyr::mutate(
        level = tidyr::replace_na(level, 0),
        full_depth = depth + level,
        name = dplyr::case_when(
          is.na(name) & !is.na(text) ~ gsub("\\s\\{.*", "", text),
          TRUE ~ name
        ),
        out_text = dplyr::case_when(
          is.na(name) ~ NA_character_,
          is.na(file) ~ name,
          is.na(number) & level == 0 ~ 
            paste0("[", name, "](", file, ")"),
          is.na(number) ~ 
            paste0("[", name, "](", file, "#", reference,")"),
          TRUE ~ paste0("@", reference, ": ", name)
        ),
        indent = purrr::map_chr(
          .x = full_depth,
          .f = ~paste0(rep(" ", .x * 4), collapse = "")
        ),
        output = dplyr::if_else(is.na(out_text), NA_character_, 
                                paste0(indent, "* ", out_text))
      ) |>
      dplyr::select(
        type, file, full_depth, order, chapter_number = number,
        section_number = sec_num, reference, name, output
      )
    
    if (drop_empty) {
      out <- out |>
        tidyr::drop_na(output)
    }
      
  } else if (what == "tbl" | what == "fig") {
    
    if (what == "tbl") {
      df <- y |> 
        dplyr::mutate(
          order = dplyr::row_number(),
          tables = purrr::map(file, get_qmd_tbls),
          type = "table"
        ) |>
        tidyr::unnest(tables, keep_empty = FALSE)
    } else if (what == "fig") {
      df <- y |> 
        dplyr::mutate(
          order = dplyr::row_number(),
          figures = purrr::map(file, get_qmd_figs),
          type = "figure"
        ) |>
        tidyr::unnest(figures, keep_empty = FALSE)
    }
    
    out <- df |>
      dplyr::add_row(
        file = sort(unique(y$file)),
        group = Inf
      ) |>
      dplyr::add_count(file) |>
      dplyr::filter(n > 1) |>
      dplyr::arrange(file, group) |>
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
    
    out <- out |>
      dplyr::mutate(order = dplyr::row_number(),
                    type = tidyr::replace_na(type, "spacer")) |>
      dplyr::select(type, file, order, chapter_number = number,
                    item_number = group, reference, name, output)
    
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
