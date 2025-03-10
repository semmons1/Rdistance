#' @title Abundance point estimates
#' 
#' @description Estimate abundance given a distance function, 
#' detection data, site data, and area.  This is called internally 
#' by \code{abundEstim}.  Users should use \code{abundEstim} to estimate
#' abundance. 
#' 
#' @param dfunc An estimate distance function (see \code{dfuncEstim}).
#' 
#' @param detectionData A data frame containing information on 
#' detections.  The minimum amount of information is the detection 
#' distances and transect or point ID where each detection
#' occurred. (see \emph{Input data frames} in help 
#' for \code{dfuncEstim}).
#' 
#' @param siteData A data frame containing information on the 
#' transects or points surveyed  (see \code{dfuncEstim}).
#' 
#' @param area Total area of inference, study area size, or unit conversion.
#' See \code{\link{abundEstim}}.
#' 
#' @param bySite A logical scalar indicating whether to compute site-level
#'   estimates of abundance. The default (\code{bySite=FALSE}) returns only one
#'   overall abundance estimate. See \bold{Value} and \bold{Details}.
#'   
#' 
#' @return If \code{bySite} is FALSE, a list containing the following components:
#'    \item{dfunc}{The input distance function.}
#'    \item{abundance}{Estimated abundance in the study area (if \code{area} >
#'   1) or estimated density in the study area (if \code{area} = 1).}
#'    \item{n}{The number of detections
#'   (not individuals, unless all group sizes = 1) used in the estimate of
#'   abundance.}
#'    \item{area}{Total area of inference. Study area size}
#'    \item{esw}{Effective strip width for line-transects, effective
#'    radius for point-transects.  Both derived from \code{dfunc}}.
#'    \item{n.sites}{Total number of transects for line-transects, 
#'    total number of points for point-transects.}
#'    \item{tran.len}{Total transect length. NULL for point-transects.}
#'    \item{avg.group.size}{Average group size}
#'    
#'    If \code{bySite} is TRUE, a data frame containing site-level 
#'    estimated abundance.  The data frame is an exact copy of \code{siteData}
#'    with the following columns tacked onto the end:
#'     
#'    \item{effDist}{The effective sampling distance at the site.  For line-
#'    transects, this is ESW at the site.  For points, this is EDR. } 
#'    \item{pDetection}{Average probability of detection at the site. 
#'    If only site-level covariates appear in the distance function, 
#'    pDetection is constant within a site. When detection-level 
#'    covariates are present, pDetection is the average at the site.}
#'    \item{observedCount}{The total number of individuals detected at a site.}
#'    \item{abundance}{Estimated abundance at the site. This is the sum
#'    of inflated group sizes at the site. i.e., each group size 
#'    at the site is divided by its pDetection, and then summed.    }
#'    \item{density}{Estimated density at the site. This is abundance 
#'    at the site divided by the sampled area at the site.  E.g., for 
#'    line transects, this is abundance divided by \eqn{2*w*length}. For 
#'    points, this is abundance divided by \eqn{pi*w^2}.}
#'    \item{effArea}{The effective area sampled at the site. This could be used
#'    as an offset in a subsequent linear model. For 
#'    line transects, this is \eqn{2*ESW*length}. For 
#'    points, this is \eqn{pi*EDR^2}.}
#'    
#' @details 
#' If \code{x} is the data frame returned when \code{bySite} = TRUE, 
#' the following is true: 
#' \enumerate{
#'   \item For line transects, \code{sum(x$abundance)*area/(2*w*sum(x$length))}
#'     is the estimate of abundance on the study area or the 
#'     abundance estimate when \code{bySite} = FALSE.
#'     
#'   \item \code{area*sum(x$density)/nrow(x)} is the estimate of abundance 
#'   on the study area or the abundance estimate when \code{bySite} = FALSE.
#' 
#' }
#'         
#'    
#' @author Trent McDonald, WEST Inc.,  \email{tmcdonald@west-inc.com}\cr
#'         Jason Carlisle, University of Wyoming and WEST Inc, \email{jcarlisle@west-inc.com}\cr
#'         Aidan McDonald, WEST Inc., \email{aidan@mcdcentral.org}
#'     
#' @seealso \code{\link{dfuncEstim}}, \code{\link{abundEstim}}
#' 
#' @keywords model
#'
#' @export 

estimateN <- function(dfunc, detectionData, siteData, area=1, bySite=FALSE){
  # Truncate detections and calculate some n, avg.group.isze, 
  # tot.trans.len, and esw
  
  # Apply truncation specified in dfunc object (including dist 
  # equal to w.lo and w.hi)
  (detectionData <- detectionData[detectionData$dist >= dfunc$w.lo 
                                    & detectionData$dist <= dfunc$w.hi, ])
  
  # sample size (number of detections, NOT individuals)
  (n <- nrow(detectionData))
  
  # total transect length
  tot.sites <- nrow(siteData)  # number of points or number of transects
  if (dfunc$pointSurvey) {
    tot.trans.len <- NULL  # no transect length
  } else {
    tot.trans.len <- sum(siteData$length)  # total transect length
  }
  
  
  # Estimate abundance ----

  # If dfunc has covariates, esw is a vector of length n. No covars, esw is scalar
  # If dfunc is pointSurveys, esw is EDR.  If line surveys, esw is ESW.
  esw <- effectiveDistance(dfunc)
    
  w <- dfunc$w.hi - dfunc$w.lo
  
  
  if (dfunc$pointSurvey) {
    phat <- (esw / w)^2  # for points
  } else {
    phat <- esw / w  # for lines
  }
  
  
  nhat <- detectionData$groupsize / phat # inflated counts one per detection
  
  if (bySite) {
    # ---- sum statistics by siteID

    (nhat.df <- data.frame(siteID = detectionData$siteID, abundance=nhat))
    (nhat.df <- tapply(nhat.df$abundance, nhat.df$siteID, sum))
    (nhat.df <- data.frame(siteID = names(nhat.df), abundance=nhat.df))

    (observedCount <- tapply(detectionData$groupsize, detectionData$siteID, sum))
    (observedCount <- data.frame(siteID = names(observedCount), observedCount=observedCount))

    (nhat.df <- merge(observedCount, nhat.df))  # should match perfectly

    # If detectionData$siteID is a factor and has all levels, even zero
    # sites, don't need to do this.  But, to be safe merge back to 
    # get zero transects and replace NA with 0 

    # Must do this to get pDetection on 0-sites.  Site must have 
    # non-missing covars if dfunc has covars
    (esw <- effectiveDistance(dfunc, siteData))
    siteData <- data.frame(siteData, esw=esw)
    
    if (dfunc$pointSurvey) {
      siteData$pDetection <- (siteData$esw / w)^2  # for points
    } else {
      siteData$pDetection <- siteData$esw / w  # for lines
    }
    
    
    nhat.df <- merge(siteData, nhat.df, by="siteID", all.x=TRUE)
    nhat.df$observedCount[is.na(nhat.df$observedCount)] <- 0
    nhat.df$abundance[is.na(nhat.df$abundance)] <- 0
    
    # Calculate density
    if (dfunc$pointSurvey) {
      sampledArea <- pi * w^2  # area samled for single point  
    } else {
      sampledArea <- 2 * w * nhat.df$length  # area sampled for single line
    }
    nhat.df$density <- (nhat.df$abundance * area) / sampledArea
    
    
    # Calculate effective area ("effective" as in ESW)
    # This is suggested as the offset term in a GLM model of density
    if (dfunc$pointSurvey) {
      nhat.df$effArea <- (pi * nhat.df$esw^2) / area  # for points
    } else {
      nhat.df$effArea <- (nhat.df$length * nhat.df$esw * 2) / area  # for lines
    }
    
    
    # Replace the column name for "esw", which is edr for points
    if (dfunc$pointSurvey) {
      names(nhat.df)[names(nhat.df)=="esw"] <- "EDR"  # for points
    } else {
      names(nhat.df)[names(nhat.df)=="esw"] <- "ESW"  # for lines
    }
    
    
  } else {
    
    # not bySite
    if(dfunc$pointSurvey){
      nhat.df <- sum(nhat) * area / (pi * w^2 * tot.sites)
    } else {
      nhat.df <-  sum(nhat) * area / (2 * w * tot.trans.len)
    }
    
    nhat.df <- list(dfunc = dfunc,
                  abundance = nhat.df,
                  nhat.sampleArea = sum(nhat),
                  n.sites = tot.sites,
                  n.groups = n,
                  observedCount = sum(detectionData$groupsize),
                  area = area,
                  w = w,
                  tran.len = tot.trans.len,
                  avg.group.size = mean(detectionData$groupsize),
                  pDetection = phat)
  }
    
  # some interesting tidbits:
  #  sampled area = tot.trans.len * 2 * (dfunc$w.hi - dfunc$w.lo)
  #  sum(1/phat) = what Distance calls "N in covered region".  This is
  #    estimated number of groups in the sampled area.
  #  sum(1/phat)*mean(detectionData$groupsize) = an estimate of individuals
  #    in the sampled area. This is probably how Distance would do it.
  #  sum(detectionData$groupsize/phat) = the HT estimate of individuals 
  #    in the sampled area.  How RDistance does it. This and the Distance 
  #    estimate are very close.  Only difference is ratio of sums or sum of 
  #    ratios.
  #  sum(detectionData$groupsize) / (sum(1/phat)*mean(detectionData$groupsize)) = 
  #    n.indivs / (nhat.groups*mean.grp.size) = n.groups / nhat.groups = 
  #    what Distance calls "Average p".  This is different than mean(phat) 
  #    the way Rdistance calculates it.
  
  

  return(nhat.df)
}  # end estimate.nhat function


