#' Functional Data Depth
#'
#' Data depths for functional data.
#' Currently implemented: Modified Band-2 Depth, see reference.
#'
#' @param x `tf` (or a matrix of evaluations)
#' @param depth currently available: "MBD", i.e. modified band depth
#' @param arg grid of evaluation points
#' @param na.rm TRUE remove missing observations?
#' @param ... further arguments handed to the function computing the respective
#'   tf_depth.
#' @returns vector of tf_depth values
#' @references `r format_bib("sun2012exact", "lopez2009concept")`
#' @export
#' @rdname tf_depth
#' @family tidyfun ordering and ranking functions
tf_depth <- function(x, arg, depth = "MBD", na.rm = TRUE, ...) {
  UseMethod("tf_depth")
}

#' @export
#' @rdname tf_depth
tf_depth.matrix <- function(x, arg, depth = "MBD", na.rm = TRUE, ...) {
  if (missing(arg)) arg <- unlist(find_arg(x, arg = NULL))
  assert_numeric(arg, finite = TRUE, any.missing = FALSE, len = ncol(x),
                 unique = TRUE, sorted = TRUE)

  depth <- match.arg(depth)
  # TODO: this ignores na.rm -- should it?
  switch(depth, MBD = mbd(x, arg, ...))
}

#' @export
#' @rdname tf_depth
tf_depth.tf <- function(x, arg, depth = "MBD", na.rm = TRUE, ...) {
  if (!missing(arg)) assert_arg_vector(arg, x)
  # TODO: warn if irreg?
  if (na.rm) x <- x[!is.na(x)]
  tf_depth(as.matrix(x, arg = arg, interpolate = TRUE),
    depth = depth,
    na.rm = na.rm, ...
  )
}

#-------------------------------------------------------------------------------

# modified band-2 depth:
mbd <- function(x, arg = seq_len(ncol(x)), ...) {
  if (nrow(x) == 1) return(0.5)
  if (nrow(x) == 2) return(c(0.5, 0.5))

  # algorithm of Sun/Genton/Nychka (2012)
  ranks <- apply(x, 2, rank, na.last = "keep", ...)
  weights <- {
    # assign half interval length to 2nd/nxt-to-last points to 1st and last
    # point, assign other half intervals to intermediate points
    lengths <- diff(arg) / 2
    (c(lengths, 0) + c(0, lengths)) / diff(range(arg))
  }
  n <- nrow(ranks)
  tmp <- colSums(t((n - ranks) * (ranks - 1)) * weights, na.rm = TRUE)
  (tmp + n - 1) / choose(n, 2)
}

#------------------------------------------------------------------------------

#' @importFrom stats quantile
#' @inheritParams stats::quantile
#' @family tidyfun ordering and ranking functions
#' @export
quantile.tf <- function(x, probs = seq(0, 1, 0.25), na.rm = FALSE,
                        names = TRUE, type = 7, ...) {
  # TODO: functional quantiles will need (a lot) more thought,
  # cf. Serfling, R., & Wijesuriya, U. (2017).
  # Depth-based nonparametric description of functional data,
  #   with emphasis on use of spatial depth.
  warning(
    "only pointwise, non-functional quantiles implemented for tfs.",
    call. = FALSE
  )
  summarize_tf(x,
               probs = probs, na.rm = na.rm, names = names,
               type = type, op = "quantile", eval = is_tfd(x), ...
  )
}
