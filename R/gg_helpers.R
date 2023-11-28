# function to insert plot as raw svg code
# a modified from render_svg from @co-analysis/govukhugo-r
# https://github.com/co-analysis/govukhugo-r/blob/ae27cf184e2b5470b97388800e13c74a38310d4d/R/images.R

render_svg <- function(plot, width, height, units = "px",
                       alt_text = NULL, source_note = NULL, dpi = 72) {
  
  # {ggplot2} is in suggests to reduce install bloat
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("render_svg() requires package {ggplot2} to be installed.",
         call. = FALSE)
  }
  
  # {svglite} is in suggests to reduce install bloat
  if (!requireNamespace("svglite", quietly = TRUE)) {
    stop("render_svg() requires package {svglite} to be installed.",
         call. = FALSE)
  }
  
  # warn if no alt text provided
  if (is.null(alt_text)) {
    warning("You have not provided any alt text for the plot, please reconsider.")
  }
  
  # create a temporary file
  svg_file <- paste0(tempfile(),".svg")
  
  # check ggplot2 version
  # if less than 3.3.5 convert px units to mm
  ggplot_version <- as.character(utils::packageVersion("ggplot2"))
  
  if (utils::compareVersion(ggplot_version, "3.3.5") == -1) {
    if (units == "px") {
      width <- width * (25.4/dpi)
      height <- height * (25.4/dpi)
      units <- "mm"
    }
  }
  
  # render ggplot as an svg
  ggplot2::ggsave(svg_file, plot, device = "svg",
                  width = width, height = height, units = units, dpi = dpi)
  
  # read the svg, drop the DOCTYPE declaration
  x <- readLines(svg_file)[-1]
  
  # remove explicit width/height settings
  x[1] <- gsub("(width|height)='.*?' ", "", x[1])
  
  # generate a unique id for the object
  unique_id <- paste0(c(sample(letters, 5), replicate(5, sample(0:9, 3))),
                      collapse = "")
  
  # create tags for alt_title
  if (!is.null(alt_text)) {
    described_by <- paste0(" aria-labelledby='", unique_id, "-desc'")
    alt_insert <- paste0("<desc id='", unique_id, "-desc'>", alt_text,
                         "</desc>")
  }
  
  # insert alt text tags into svg, if no alt_text still set role='img'
  if (!is.null(alt_text)) {
    x1 <- gsub(">", paste0(described_by," role='img'>"), x[1])
    new_svg <- c(x1, alt_insert, x[2:length(x)])
  } else {
    x1 <- gsub(">", " role='img'>", x[1])
    new_svg <- c(x1, x[2:length(x)])
  }
  
  out_chunk <- paste(new_svg, sep = "\n")
  
  # render as an HTML object, add source note if provided
  if (is.null(source_note)) {
    htmltools::HTML(out_chunk)
  } else {
    source_note <- paste0("<div class='source-note'>",
                          source_note,
                          "</div>", collapse = "")
    htmltools::HTML(c(out_chunk, source_note))
  }
  
  
  
}
