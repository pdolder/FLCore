# FLComp - Basic VIRTUAL class for all FLQuant-based classes
# FLCore/R/FLComp.R

# Copyright 2003-2015 FLR Team. Distributed under the GPL 2 or later
# Maintainer: Iago Mosqueira, EC JRC G03

# summary		{{{
setMethod("summary", signature(object="FLComp"),
	function(object, ...){

		cat("An object of class \"", class(object), "\"\n\n", sep="")
		cat("Name:", object@name, "\n")
		
    desc <- ifelse(nchar(object@desc) > getOption("width"),
      paste(substr(object@desc, 1, getOption("width") - 6), "[...]"),
      object@desc) 
		cat("Description:", desc, "\n")

    # character slots
		cnames <- getSlotNamesClass(object, 'character')
    cnames <- cnames[!cnames%in%c('name', 'desc')]
    if(length(cnames) > 0)
    {
      for (s in cnames)
        cat(paste(toupper(substring(s, 1,1)), substring(s, 2), sep=""), ": ",
          slot(object, s), "\n")
    }

    # FLArray slots
		qnames <- getSlotNamesClass(object, 'FLArray')
    dms <- dims(object)
    # Quant
		cat("Quant:", dms$quant, "\n")
    # Dims
		cat("Dims: ", quant(slot(object, qnames[1])), "\tyear\tunit\tseason\tarea\titer\n")
		cat("", dms[[dms$quant]], dim(slot(object, qnames[1]))[-c(1,6)],
      dms$iter, "\n\n", sep="\t")
		# Range
    cat("Range: ", paste(sub('plusgroup', 'pgroup', names(object@range)),
      collapse="\t"), "\n")
		cat("", object@range, "\n\n", sep="\t")

		for (s in qnames) {
			#if (sum(!complete.cases(slot(object, s))) == length(slot(object,s)))
			#	cat(substr(paste(s, "          "), start=1, stop=12), " : EMPTY\n") else
				cat(substr(paste(s, "          "), start=1, stop=12), " : [",
					dim(slot(object,s)),"], units = ", slot(object,s)@units, "\n")
		}
	}
)	# }}}

# window    {{{
setMethod("window", signature(x="FLComp"),
	  function(x, start=dims(x)$minyear, end=dims(x)$maxyear, extend=TRUE, frequency=1) {
      x <- qapply(x, window, start=start, end=end, extend=extend, frequency=frequency)
  		x@range["minyear"] <- start
	  	x@range["maxyear"] <- end

		return(x)
	}
)	# }}}

# propagate {{{
setMethod("propagate", signature(object="FLComp"),
	function(object, iter, fill.iter=TRUE) {

		# GET object iters
		mit <- unlist(qapply(object, function(x) dim(x)[6]))

		# CHECK iter can only be 1 or dim(object)[6]
		if(sum(mit) > length(mit) & !iter %in% mit)
			stop("incompatible number of iters requested")

		# GET slots to extend
		idx <- mit[mit != iter]

		for(s in names(idx)) {
			slot(object, s) <- propagate(slot(object, s), iter, fill.iter=fill.iter)
		}

		# DO for FLPar
		pnms <- getSlots(class(object))
		pnames <- names(pnms)[pnms == "FLPar"]
		for(i in pnames)
			slot(object, i) <- propagate(slot(object, i), iter)
		return(object)
	}
) # }}}

# iter {{{
setMethod("iter", signature(obj="FLComp"),
	  function(obj, iter) {

		# copy the iterate into the new slots
		names. <- c(getSlotNamesClass(obj, 'FLArray'),getSlotNamesClass(obj, 'FLPar'))
		for(s. in names.)
		{
			if(dims(slot(obj, s.))$iter == 1)
				slot(obj, s.) <- iter(slot(obj, s.), 1)
			else
				slot(obj, s.) <- iter(slot(obj, s.), iter)
		}

		return(obj)
	  }
) # }}}

# iter<-  {{{
setMethod("iter<-", signature(object="FLComp", value="FLComp"),
	function(object, iter, value)
	{
		object[,,,,,iter] <- value
		return(object)
	}
)   # }}}

# transform {{{
setMethod("transform", signature(`_data`="FLComp"),
function(`_data`, ...)
  {

	env <- new.env(parent=parent.frame())

	for (i in slotNames(`_data`)) {
		assign(i, slot(`_data`, i), envir=env)
	}

	args <- eval(substitute(list(...)), env)

	# IF ... is only FLQuants
	if(is.null(names(args)) & is(args[[1]], 'FLQuants')) {
		args <- unlist(args, recursive=FALSE)
	}

	# IF both FLQuants and promises
	if(any(names(args) == "")) {
		fqs <- unlist(lapply(args, is, 'FLQuants'))
		args <- c(args[!fqs], unlist(args[fqs], recursive=FALSE))
	}

	for (i in 1:length(args)) {
		slot(`_data`, names(args)[i]) <- args[[i]]
	}

	if(validObject(`_data`))
		return(`_data`)
	stop('Attempt to modify object incorrectly: check input dimensions')
	}
)	# }}}

# qapply		{{{
setMethod('qapply', signature(X='FLComp', FUN='function'),
	function(X, FUN, ..., exclude=missing) {

		FUN <- match.fun(FUN)
		slots <- getSlotNamesClass(X, 'FLArray')

		if(!missing(exclude))
      slots <- slots[!slots %in% exclude]

		if(is(do.call(FUN, list(slot(X, slots[1]), ...)), 'FLArray')) {
			res <- X
			for (i in slots)
				slot(res, i) <- do.call(FUN, list(slot(X,i), ...))
		}
		else {
			res  <- vector('list', 0)
			for (i in slots)
				res[[i]] <- do.call(FUN, list(slot(X,i), ...))
		}

		return(res)
	}
)   # }}}

# trim     {{{

#' @rdname trim
#' @aliases trim,FLComp-method

setMethod("trim", signature("FLComp"),
	function(x, ...)
	{
	  args <- list(...)

    names <- getSlotNamesClass(x, 'FLArray')

    c1 <- args[[quant(slot(x, names[1]))]]
	  c2 <- args[["year"]]

    # FLQuants with quant
    x <- qapply(x, trim, ...)

    # range
  	if (length(c1) > 0)
    {
    	x@range["min"] <- c1[1]
	    x@range["max"] <- c1[length(c1)]
	  }
  	if (length(c2)>0 )
    {
    	x@range["minyear"] <- as.numeric(c2[1])
	    x@range["maxyear"] <- as.numeric(c2[length(c2)])
  	}
	  return(x)
	}
) # }}}

# units	    {{{
setMethod("units", signature(x="FLComp"), function(x)
	qapply(x, units)
)
#}}}

# units<-      {{{
setMethod("units<-", signature(x="FLComp", value="list"),
    function(x, value) {
        for(i in seq(along=value))
            if(is.character(value[[i]]))
                units(slot(x, names(value[i]))) <- value[[i]]
        return(x)
	}
) # }}}

# '['       {{{
setMethod('[', signature(x='FLComp'),
	function(x, i, j, k, l, m, n, ..., drop=FALSE) {

		qnames <- names(getSlots(class(x))[getSlots(class(x))=="FLQuant" | getSlots(class(x))=="FLArray" | getSlots(class(x))=="FLCohort"])
		dx <- dim(slot(x, qnames[1]))
    args <- list(drop=FALSE)

		if (!missing(i)) {
      args <- c(args, list(i=i))
		}
		if (!missing(j))
      args <- c(args, list(j=j))
		if (!missing(k))
      args <- c(args, list(k=k))
		if (!missing(l))
      args <- c(args, list(l=l))
		if (!missing(m))
      args <- c(args, list(m=m))
		if (!missing(n))
      args <- c(args, list(n=n))

    for(q in qnames)
      slot(x, q) <- do.call('[', c(list(x=slot(x,q)), args))

    # range
		if (!missing(i)) {
    	x@range['min'] <- dims(slot(x, qnames[1]))$min
    	x@range['max'] <- dims(slot(x, qnames[1]))$max
		}
		if (!missing(j)) {
	    x@range['minyear'] <- dims(slot(x, qnames[1]))$minyear
  	  x@range['maxyear'] <- dims(slot(x, qnames[1]))$maxyear
		}
    return(x)
    }
)   # }}}

# "[<-"            {{{
setMethod("[<-", signature(x="FLComp"),
	function(x, i, j, k, l, m, n, ..., value="missing")
  {
		qnames <- names(getSlots(class(x))[getSlots(class(x))=="FLQuant"])
		dx <- dim(slot(x, qnames[1]))
    di <- qapply(x, function(y) seq(1, dim(y)[1]))
    dn <- qapply(x, function(y) seq(1, dim(y)[6]))

		if (!missing(i))
      di <- lapply(di, function(x) x <- i)
		if (missing(j))
			j <- seq(1, dx[2])
   	if (missing(k))
			k <- seq(1, dx[3])
		if (missing(l))
			l <- seq(1, dx[4])
		if (missing(m))
			m <- seq(1, dx[5])
		if (!missing(n))
      dn <- lapply(dn, function(x) x <- n)

    for(q in qnames)
      slot(x, q)[di[[q]],j,k,l,m,dn[[q]]] <- slot(value, q)

   	return(x)
	}
)   # }}}

# as.data.frame        {{{
setMethod("as.data.frame", signature(x="FLComp", row.names="missing", optional="missing"),
	function(x, row.names, optional, drop=FALSE, cohort=FALSE)
	{
    qnames <- getSlotNamesClass(x, 'FLArray')
    quant <- quant(slot(x, qnames[1]))
	  df   <- data.frame()
    for(s in qnames)
		{
      sdf <- as.data.frame(slot(x, s), cohort=cohort)
      sdf[[quant]] <- as.character(sdf[[quant]])
      dfq <- cbind(slot=s, sdf)

			df  <- rbind(df, dfq)
	  }
    # drop
    if(drop) {
      idx <- apply(df, 2, function(x) length(unique(x))) == 1
      df <- df[, !idx]
    }

		# add attributes
		attributes(df)$desc <- x@desc
		attributes(df)$name <- x@name
		attributes(df)$range <- x@range

		return(df)
	}
)   # }}}

# mcf	{{{
setMethod('mcf', signature(object='FLComp'),
	function(object, second) {

	qdims <- unlist(qapply(object, function(x) dim(x)[1]))
	qdims <- names(qdims[qdims==max(qdims)][1])

	dimnames <- list()
	dob <- dimnames(slot(object, qdims))
	dse <- dimnames(slot(second, qdims))

	for(i in names(dob))
		dimnames[[i]] <- unique(c(dob[[i]], dse[[i]]))

	foo <- function(x, dimnames) {
		if(all(dimnames(x)[[1]] == 'all'))
			return(FLQuant(x, dimnames=dimnames[-1]))
		else
			return(FLQuant(x))
	}

	res <- new('FLlst')
	res[[1]] <- qapply(object, foo, dimnames=dimnames)
	res[[2]] <- qapply(second, foo, dimnames=dimnames)

	return(res)
	}
)	# }}}

# dims {{{
setMethod("dims", signature(obj="FLComp"),
  # Returns a list with different parameters
  function(obj, ...) {
    qnames <- getSlotNamesClass(obj, 'FLArray')

    range <- as.list(range(obj))
    dimsl <- qapply(obj, dim)
    dnames <- qapply(obj, dimnames)
    dimsl <- dimsl[!names(dnames) %in% 'fbar']
    dims <- matrix(unlist(dimsl), ncol=6, byrow=TRUE)

    iter <- max(dims[,6])
    pnames <- getSlotNamesClass(obj, 'FLPar')
		if(length(pnames) > 0)
			for(p in pnames)
				iter <- max(iter, length(dimnames(slot(obj, p))$iter))

    # Hack for FLBRP
    # TODO Fix for FLstock
    dnames <- dnames[!names(dnames) %in% 'fbar']
    quants <- lapply(dnames, function(x) x[[1]])[unlist(lapply(dimsl,
      function(x) x[1] == max(dims[,1])))][[1]]
    res <- list(
      quant = quant(slot(obj, qnames[1])),
      quants = max(dims[,1]),
      min = ifelse(!is.na(suppressWarnings(as.numeric(quants[1]))),
        suppressWarnings(as.numeric(quants[1])), as.numeric(NA)),
      max = ifelse(!is.na(suppressWarnings(as.numeric(quants[max(dims[,1])]))),
        suppressWarnings(as.numeric(quants[max(dims[,1])])), as.numeric(NA)),
      year = max(dims[,2]),
      minyear = as.numeric(dnames[[1]]$year[1]),
      maxyear = as.numeric(dnames[[1]]$year[max(dims[,2])]),
      plusgroup = ifelse('plusgroup' %in% names(range), range$plusgroup, NA),
      unit = max(dims[,3]),
      season = max(dims[,4]),
      area = max(dims[,5]),
      iter = iter)
    res <- lapply(res, function(x) if(is.null(x)) return(as.numeric(NA)) else return(x))
    names(res)[2] <- res$quant
    return(res)
  }
) # }}}

# model.frame {{{
setMethod('model.frame', signature(formula='FLComp'),
	function(formula, mcf=TRUE, ...)
  {
    lst <- FLQuants()
    names <- getSlotNamesClass(formula, 'FLQuant')
    for(i in names)
      lst[[i]] <- slot(formula, i)
    names(lst) <- names
    if(mcf)
      lst <- mcf(lst)
    return(model.frame(lst, ...))
  }
)
# }}}

# range {{{
setMethod("range", "FLComp",
  function(x, i='missing', ..., na.rm = FALSE)
  {
    if(missing(i))
      slot(x, 'range')
    else
      slot(x, 'range')[i]
  }
)

setReplaceMethod("range", "FLComp",
  function(x, i, value)
  {
    slot(x, 'range')[i] <- value
    return(x)
  }
) # }}}

# expand  {{{
setMethod('expand', signature(x='FLComp'),
  function(x, ...)
  {
    x <- qapply(x, expand, ...)

    # range
    range <- qapply(x, function(x) dimnames(x)[[1]])
    slot <- names(which.max(lapply(range, length)))
    dnames <- dimnames(slot(x, slot))
    range(x, c('min', 'max', 'minyear', 'maxyear')) <- c(as.numeric(dnames[[1]][1]),
      as.numeric(dnames[[1]][length(dnames[[1]])]), as.numeric(dnames[[2]][1]),
      as.numeric(dnames[[2]][length(dnames[[2]])]))

    return(x)
  }
) # }}}

# slots  {{{
setMethod(slots, signature(object='FLComp', name='character'),
  function(object, name, ...) {

		args <- list(...)

    # args
    if(length(args) > 0)
      if(all(unlist(lapply(args, function(x) is(x, 'character')))))
        name <- c(name, unlist(args))
      else
        stop(paste('Only character vectors for slot names allowed:',
          unlist(args[!unlist(lapply(args, function(x) is(x, 'character')))])))

		res <- vector(mode='list', length=length(name))
    names(res) <- name

    for (i in name)
      res[[i]] <- slot(object, i)


    return(new(getPlural(res[[1]]), res))
  }
) # }}}

# age/year vectors {{{
setMethod("rngyear", "FLComp", function(object){
	object@range[c("minyear","maxyear")]
})

setReplaceMethod("rngyear", "FLComp", function(object, value){
	object@range[c("minyear","maxyear")] <- value
	object
})

setMethod("rngage", "FLComp", function(object){
	object@range[c("min","max")]
})

setReplaceMethod("rngage", "FLComp", function(object, value){
	object@range[c("min","max")] <- value
	object
})

setMethod("vecyear", "FLComp", function(object){
	rng <- object@range[c("minyear","maxyear")]
	rng[1]:rng[2]
})

setMethod("vecage", "FLComp", function(object){
	rng <- object@range[c("min","max")]
	rng[1]:rng[2]
}) # }}}

# ibind {{{
ibind <- function(...) {

  args <- list(...)

  its <- length(args)

  res <- propagate(args[[1]], its)

  if(its > 1) {
    for(i in seq(2, its))
      res[,,,,,i] <- args[[i]]
  }
  return(res)
} # }}}
