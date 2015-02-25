F.automated.CDA=function (dist, group.size = 1, area = 1, transects = NULL, transect.lengths=NULL, 
          w.lo = 0, w.hi = max(dist,na.rm=T), likelihoods = c("halfnorm", "hazrate", 
                                                      "uniform", "negexp", "Gamma"), series = c("cosine", "hermite", 
                                                                                                "simple"), expansions = 0:3, plot = TRUE, ...) 
{
  f.save.result <- function(results, dfunc, like, ser, expan, 
                            plot) {
    esw <- ESW(dfunc)
    if (!is.na(esw) & (esw > dfunc$w.hi)) {
      scl.ok <- "Not ok"
      scl.ok.flag <- 0
      aic <- NA
    }
    else {
      scl.ok <- "Ok"
      scl.ok.flag <- 1
      aic = AIC(dfunc)
    }
    conv <- dfunc$convergence
    if (conv != 0) {
      if (conv == -1) {
        conv.str <- "Bad"
      }
      else {
        conv.str <- "No"
      }
      aic <- NA
      scl.ok <- "NA"
      scl.ok.flag <- NA
    }
    else {
      conv.str <- "Yes"
    }
    results <- rbind(results, data.frame(like = like, series = ser, 
                                         expansions = expan, converge = conv, scale = scl.ok.flag, 
                                         aic = aic))
    if (nchar(like) < 8) 
      sep1 <- "\t\t"
    else sep1 <- "\t"
    cat(paste(like, sep1, ser, "\t", expan, "\t", conv.str, 
              "\t\t", scl.ok, "\t", round(aic, 4), sep = ""))
    if (plot) {
      plot(dfunc)
      k <- readline(" Next?[entr=y,n]")
      if (length(k) == 0) 
        k <- "y"
    }
    else {
      cat("\n")
      k <- "y"
    }
    list(results = results, k = k)
  }
  
  
  
  wwarn <- options()$warn
  options(warn = -1)
  fit.table <- NULL
  cat("Likelihood\tSeries\tExpans\tConverged?\tScale?\tAIC\n")
  for (like in likelihoods) {
    if (like == "Gamma") {
      dfunc <- F.dfunc.estim2(dist, likelihood = like, w.lo = w.lo, 
                             w.hi = w.hi, ...)
      ser <- ""
      expan <- 0
      fit.table <- f.save.result(fit.table, dfunc, like, 
                                 ser, expan, plot)
      cont <- fit.table$k
      fit.table <- fit.table$results
    }
    else {
      for (expan in expansions) {
        if (expan == 0) {
          ser <- "cosine"
          dfunc <- F.dfunc.estim2(dist, likelihood = like, 
                                 w.lo = w.lo, w.hi = w.hi, expansions = expan, 
                                 series = ser, ...)
          fit.table <- f.save.result(fit.table, dfunc, 
                                     like, ser, expan, plot)
          cont <- fit.table$k
          fit.table <- fit.table$results
        }
        else {
          for (ser in series) {
            dfunc <- F.dfunc.estim2(dist, likelihood = like, 
                                   w.lo = w.lo, w.hi = w.hi, expansions = expan, 
                                   series = ser, ...)
            fit.table <- f.save.result(fit.table, dfunc, 
                                       like, ser, expan, plot)
            cont <- fit.table$k
            fit.table <- fit.table$results
            if (cont == "n") 
              break
          }
        }
        if (cont == "n") 
          break
      }
      if (cont == "n") 
        break
    }
  }
  if (sum(fit.table$converge != 0) > 0) 
    cat("Note: Some models did not converge or had parameters at their boundaries.\n")
  fit.table$aic <- ifelse(fit.table$converge == 0, fit.table$aic, 
                          Inf)
  fit.table <- fit.table[order(fit.table$aic), ]
  dfunc <- F.dfunc.estim2(dist, likelihood = fit.table$like[1], 
                         w.lo = w.lo, w.hi = w.hi, expansions = fit.table$expansions[1], 
                         series = fit.table$series[1], ...)
  if (plot) {
    plot(dfunc)
    mtext("BEST FITTING FUNCTION", side = 3, cex = 1.5, line = 3)
  }
  if (missing(group.size)) {
    abund <- F.abund.estim2(dfunc, avg.group.size = 1, area = area, 
                            transects = transects, transect.lengths=transect.lengths)
  }
  else {
    abund <- F.abund.estim2(dfunc, group.sizes = group.size, 
                           area = area,  transects = transects, transect.lengths=transect.lengths)
  }
  cat("\n\n---------------- Final Automated CDS Abundance estimate -------------------------------\n")
  print(abund)
  options(warn = wwarn)
  abund
}