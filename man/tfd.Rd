% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/tfd-class.R
\name{tfd}
\alias{tfd}
\alias{tfd.matrix}
\alias{tfd.numeric}
\alias{tfd.data.frame}
\alias{tfd.list}
\alias{tfd.tf}
\alias{tfd.default}
\alias{as.tfd}
\alias{as.tfd_irreg}
\title{Constructors for vectors of "raw" functional data}
\usage{
tfd(data, ...)

\method{tfd}{matrix}(data, arg = NULL, domain = NULL, evaluator = tf_approx_linear, ...)

\method{tfd}{numeric}(data, arg = NULL, domain = NULL, evaluator = tf_approx_linear, ...)

\method{tfd}{data.frame}(
  data,
  id = 1,
  arg = 2,
  value = 3,
  domain = NULL,
  evaluator = tf_approx_linear,
  ...
)

\method{tfd}{list}(data, arg = NULL, domain = NULL, evaluator = tf_approx_linear, ...)

\method{tfd}{tf}(data, arg = NULL, domain = NULL, evaluator = NULL, ...)

\method{tfd}{default}(data, arg = NULL, domain = NULL, evaluator = tf_approx_linear, ...)

as.tfd(data, ...)

as.tfd_irreg(data, ...)
}
\arguments{
\item{data}{a \code{matrix}, \code{data.frame} or \code{list} of suitable shape, or another
\code{tf}-object. when this argument is \code{NULL} (i.e. when calling \code{tfd()}) this
returns a prototype of class \code{tfd}}

\item{...}{not used in \code{tfd}, except for \code{tfd.tf} -- specify \code{arg} and
\code{ìnterpolate = TRUE} to turn an irregular \code{tfd} into a regular one, see
examples.}

\item{arg}{\code{numeric}, or list of \code{numeric}s. The evaluation grid.
For the \code{data.frame}-method: the
name/number of the column defining the evaluation grid. The \code{matrix} method
will try to guess suitable \code{arg}-values from the column names of \code{data} if
\code{arg} is not supplied. Other methods fall back on integer sequences
(\verb{1:<length of data>}) as the default if not provided.}

\item{domain}{range of the \code{arg}.}

\item{evaluator}{a function accepting arguments \verb{x, arg, evaluations}. See
details for \code{\link[=tfd]{tfd()}}.}

\item{id}{The name or number of the column defining which data belong to
which function.}

\item{value}{The name or number of the column containing the function
evaluations.}
}
\value{
an \code{tfd}-object (or a \code{data.frame}/\code{matrix} for the conversion
functions, obviously.)
}
\description{
Various constructor methods for \code{tfd}-objects.

\code{tfd.matrix} accepts a numeric matrix with one function per
\emph{row} (!). If \code{arg} is not provided, it tries to guess \code{arg} from the
column names and falls back on \code{1:ncol(data)} if that fails.

\code{tfd.data.frame} uses the first 3 columns of \code{data} for
function information by default: (\code{id}, \code{arg}, \code{value})

\code{tfd.list} accepts a list of vectors of identical lengths
containing evaluations or a list of 2-column matrices/data.frames with
\code{arg} in the first and evaluations in the second column

\code{tfd.default} returns class prototype when argument to tfd() is
NULL or not a recognised class
}
\details{
\strong{\code{evaluator}}: must be the (quoted or bare) name of a
function with signature \verb{function(x, arg, evaluations)} that returns
the functions' (approximated/interpolated) values at locations \code{x} based on
the function \code{evaluations} available at locations \code{arg}.\cr
Available \code{evaluator}-functions:
\itemize{
\item \code{tf_approx_linear} for linear interpolation without extrapolation (i.e.,
\code{\link[zoo:na.approx]{zoo::na.approx()}} with \code{na.rm = FALSE})  -- this is the default,
\item \code{tf_approx_spline} for cubic spline interpolation, (i.e., \code{\link[zoo:na.approx]{zoo::na.spline()}}
with \code{na.rm = FALSE}),
\item \code{tf_approx_fill_extend} for linear interpolation and constant extrapolation
(i.e., \code{\link[zoo:na.fill]{zoo::na.fill()}} with \code{fill = "extend"})
\item \code{tf_approx_locf} for "last observation carried forward"  (i.e.,
\code{\link[zoo:na.locf]{zoo::na.locf()}} with \code{na.rm = FALSE} and
\item \code{tf_approx_nocb} for "next observation carried backward" (i.e.,
\code{\link[zoo:na.locf]{zoo::na.locf()}} with \verb{na.rm = FALSE, fromLast = TRUE}).
See \code{tf:::zoo_wrapper} and \code{tf:::tf_approx_linear}, which is simply
\code{zoo_wrapper(zoo::na.tf_approx, na.rm = FALSE)}, for examples of
implementations of this.
}
}
\examples{
# turn irregular to regular tfd by evaluating on a common grid:

f <- c(
  tf_rgp(1, arg = seq(0, 1, length.out = 11)),
  tf_rgp(1, arg = seq(0, 1, length.out = 21))
)
tfd(f, arg = seq(0, 1, length.out = 21))

set.seed(1213)
f <- tf_rgp(3, arg = seq(0, 1, length.out = 51)) |> tf_sparsify(0.9)
# does not yield regular data because linear extrapolation yields NAs
#   outside observed range:
tfd(f, arg = seq(0, 1, length.out = 101))
# this "works" (but may not yield sensible values..!!) for
#   e.g. constant extrapolation:
tfd(f, evaluator = tf_approx_fill_extend, arg = seq(0, 1, length.out = 101))
plot(f, col = 2)
tfd(f,
  arg = seq(0, 1, length.out = 151), evaluator = tf_approx_fill_extend
) |> lines()
}
\concept{tfd-class}
