# compute derivatives of data in rows by finite differences.
# returns derivatives at interval midpoints
#' @importFrom utils head
derive_matrix <- function(data, arg, order) {
  for (i in 1:order) {
    delta <- diff(arg)
    data <- t(diff(t(data)) / delta)
    arg <- (arg[-1] + head(arg, -1)) / 2
  }
  list(data = data, arg = arg)
}

# trapezoidal quadrature
quad_trapez <- function(arg, evaluations) {
  c(0, 0.5 * diff(arg) * (head(evaluations, -1) + evaluations[-1]))
}

#-------------------------------------------------------------------------------

#' Differentiating functional data: approximating derivative functions
#'
#' Derivatives of `tf`-objects use finite differences of the evaluations for
#' `tfd` and finite differences of the basis functions for `tfb`.
#'
#' The derivatives of `tfd` objects use centered finite differences, e.g. for
#' first derivatives \eqn{f'((t_i + t_{i+1})/2) \approx \frac{f(t_i) +
#' f(t_{i+1})}{t_{i+1} - t_i}}, so the **domains of differentiated `tfd` will
#' shrink (slightly) at both ends**. Unless the `tfd` has a rather fine and
#' regular grid, representing the data in a suitable basis representation with
#' [tfb()] and then computing the derivatives or integrals of those is usually
#' preferable.
#'
#' Note that, for some spline bases like `"cr"` or `"tp"` which always begin/end
#' linearly, computing second derivatives will produce artefacts at the outer
#' limits of the functions' domain due to these boundary constraints. Basis
#' `"bs"` does not have this problem for sufficiently high orders, but tends to
#' yield slightly less stable fits.
#' @param f a `tf`-object
#' @param order order of differentiation. Maximal value for `tfb_spline` is 2.
#' @param arg grid to use for the finite differences.
#'   Not the `arg` of the returned object for `tfd`-inputs, see Details.
#' @param ... not used
#' @returns a `tf` (with slightly different `arg` or `basis` for the
#'   derivatives, see Details)
#' @export
#' @family tidyfun calculus functions
tf_derive <- function(f, arg, order = 1, ...) UseMethod("tf_derive")

#' @export
tf_derive.default <- function(f, arg, order = 1, ...) .NotYetImplemented()

#' @export
#' @describeIn tf_derive row-wise finite differences
tf_derive.matrix <- function(f, arg, order = 1, ...) {
  if (missing(arg)) arg <- unlist(find_arg(f))
  assert_numeric(arg,
    any.missing = FALSE, finite = TRUE, len = ncol(f),
    sorted = TRUE, unique = TRUE
  )
  ret <- derive_matrix(data = f, order = order, arg = arg)
  structure(ret[[1]], arg = ret[[2]])
}

#' @export
#' @describeIn tf_derive derivatives by finite differencing.
tf_derive.tfd <- function(f, arg, order = 1, ...) {
  # TODO: should this interpolate back to the original grid? shortens the domain
  # (slightly), for now. this is necessary so that we don't get NAs when trying
  # to evaluate derivs over their default domain etc.
  if (is_irreg(f)) {
    warning("Differentiating over irregular grids can be unstable.", call. = FALSE)
  }
  assert_count(order)
  data <- as.matrix(f, arg, interpolate = TRUE)
  arg <- as.numeric(colnames(data))
  derived <- derive_matrix(data, arg, order)
  ret <- tfd(derived$data, derived$arg,
    domain = range(derived$arg) # !! shorter
  )
  tf_evaluator(ret) <- attr(f, "evaluator_name")
  setNames(ret, names(f))
}
#' @export
#' @describeIn tf_derive derivatives by finite differencing.
tf_derive.tfb_spline <- function(f, arg, order = 1, ...) {
  # TODO: make this work for iterated application tf_derive(tf_derive(fb))
  if (!is.null(attr(f, "basis_deriv"))) {
    stop(
      "Can't integrate or derive previously integrated or derived tfb_spline.",
      call. = FALSE
    )
  }
  if (attr(f, "family")$link != "identity") {
    stop(
      "Can't integrate or derive tfb_spline with non-identity link function.",
      call. = FALSE
    )
  }
  if (missing(arg)) {
    arg <- tf_arg(f)
  }
  assert_arg(arg, f)
  assert_choice(order, choices = c(-1, 1, 2))
  s_args <- attr(f, "basis_args")
  s_call <- as.call(c(quote(s), quote(arg), s_args))
  s_spec <- eval(s_call)
  spec_object <- smooth.construct(s_spec,
    data = data.frame(arg = arg), knots = NULL
  )
  eps <- min(diff(arg)) / 1000
  basis_constructor <- smooth_spec_wrapper(spec_object, deriv = order, eps = eps)
  attr(f, "basis") <- basis_constructor
  attr(f, "basis_label") <- deparse(s_call, width.cutoff = 60)[1]
  attr(f, "basis_args") <- s_args
  attr(f, "basis_matrix") <- basis_constructor(arg)
  attr(f, "basis_deriv") <- order
  attr(f, "domain") <- range(arg)
  f
}
#' @export
#' @describeIn tf_derive derivatives by finite differencing.

tf_derive.tfb_fpc <- function(f, arg, order = 1, ...) {
  efunctions <- environment(attr(f, "basis"))$efunctions
  environment(attr(f, "basis")) <- new.env()
  new_basis <- if (order > 0) {
    tf_derive(efunctions, arg, order = order)
  } else {
    tf_integrate(efunctions, arg, definite = FALSE, ...)
  }
  environment(attr(f, "basis"))$efunctions <- new_basis
  attr(f, "basis_matrix") <- t(as.matrix(new_basis))
  attr(f, "arg") <- tf_arg(new_basis)
  attr(f, "domain") <- range(tf_arg(new_basis))
  f
}

#-------------------------------------------------------------------------------

#' Integrals and anti-derivatives of functional data
#'
#' Integrals of `tf`-objects are computed by simple quadrature (trapezoid rule).
#' By default the scalar definite integral
#' \eqn{\int^{upper}_{lower}f(s)ds} is returned (option `definite = TRUE`),
#' alternatively for `definite = FALSE` the *anti-derivative* on
#' `[lower, upper]`, e.g. a `tfd` or `tfb` object representing \eqn{F(t) \approx
#' \int^{t}_{lower}f(s)ds}, for \eqn{t \in}`[lower, upper]`, is returned.
#' @inheritParams tf_derive
#' @param arg (optional) grid to use for the quadrature.
#' @param lower lower limits of the integration range. For `definite=TRUE`, this
#'   can be a vector of the same length as `f`.
#' @param upper upper limits of the integration range (but see `definite` arg /
#'   Description). For `definite=TRUE`, this can be a vector of the same length
#'   as `f`.
#' @param definite should the definite integral  be returned (default) or the
#'   antiderivative. See Description.
#' @returns For `definite = TRUE`, the definite integrals of the functions in
#'   `f`. For `definite = FALSE` and `tf`-inputs, a `tf` object containing their
#'   anti-derivatives
#' @export
#' @family tidyfun calculus functions
tf_integrate <- function(f, arg, lower, upper, ...) {
  UseMethod("tf_integrate")
}

#' @rdname tf_integrate
#' @export
tf_integrate.default <- function(f, arg, lower, upper, ...) .NotYetImplemented()

#' @rdname tf_integrate
#' @export
tf_integrate.tfd <- function(f, arg,
                             lower = tf_domain(f)[1], upper = tf_domain(f)[2],
                             definite = TRUE, ...) {
  if (missing(arg)) {
    arg <- tf_arg(f)
  }
  assert_arg(arg, f)
  arg <- ensure_list(arg)
  # TODO: integrate is NA whenever arg does not cover entire domain!
  assert_numeric(lower,
    lower = tf_domain(f)[1], upper = tf_domain(f)[2],
    any.missing = FALSE
  )
  assert_numeric(upper,
    lower = tf_domain(f)[1], upper = tf_domain(f)[2],
    any.missing = FALSE
  )
  stopifnot(
    length(lower) %in% c(1, length(f)),
    length(upper) %in% c(1, length(f))
  )
  limits <- cbind(lower, upper)
  if (nrow(limits) > 1) {
    if (!definite) .NotYetImplemented() # needs vd-data
    limits <- limits |> split(seq_len(nrow(limits)))
  }
  arg <- map2(
    arg, ensure_list(limits),
    \(x, y) c(y[1], x[x > y[1] & x < y[2]], y[2])
  )
  evaluations <- tf_evaluate(f, arg)
  quads <- map2(arg, evaluations, \(x, y) quad_trapez(arg = x, evaluations = y))
  if (definite) {
    map_dbl(quads, sum) |> setNames(names(f))
  } else {
    data_list <- map(quads, cumsum)
    names(data_list) <- names(f)
    tfd(
      data = data_list, arg = unlist(arg), domain = as.numeric(limits),
      evaluator = !!attr(f, "evaluator_name")
    )
  }
  # this is too slow:
  # turn into functions, return definite integrals
  # (Why the hell does this not work without vectorize....?)
  # map(f, ~ possibly(stats::tf_integrate, list(value = NA))(
  #  Vectorize(as.function(.x)), lower = lower, upper = upper, ...)) |>
  # map("value")
}
#' @rdname tf_integrate
#' @export
tf_integrate.tfb <- function(f, arg,
                             lower = tf_domain(f)[1], upper = tf_domain(f)[2],
                             definite = TRUE, ...) {
  if (missing(arg)) {
    arg <- tf_arg(f)
  }
  assert_arg(arg, f)
  assert_numeric(lower,
    lower = tf_domain(f)[1], upper = tf_domain(f)[2],
    any.missing = FALSE
  )
  assert_numeric(upper,
    lower = tf_domain(f)[1], upper = tf_domain(f)[2],
    any.missing = FALSE
  )
  stopifnot(
    length(lower) %in% c(1, length(f)),
    length(upper) %in% c(1, length(f))
  )
  if (definite) {
    return(tf_integrate(tfd(f, arg = arg),
      lower = lower, upper = upper,
      arg = arg
    ))
  }
  limits <- cbind(lower, upper)
  if (nrow(limits) > 1) .NotYetImplemented() # needs vd-data
  arg <- c(
    limits[1], arg[arg > limits[1] & arg < limits[2]],
    limits[2]
  )
  tf_derive(f, order = -1, arg = arg, lower = lower, upper = upper)
}
