source("R/paper-lookup-table.R")
stopifnot(identical(lookup_enroute_class(c(29999,30000,33999,34000,NA_real_,Inf)),
 c("Below FL300","FL300-339","FL300-339","FL340+","Altitude unobserved","Altitude unobserved")))
stopifnot(all(is.na(lookup_quantiles(1:29))),lookup_quantiles(1:30)[2]==15.5,
 all(is.na(lookup_quantiles(c(1:29,NA,Inf)))))
# Median flight rate is not the ratio of median fuel and median duration.
fuel<-c(100,100,900);duration<-c(1,10,20)
stopifnot(lookup_quantiles(fuel/duration,min_n=3)[2]==45,
 median(fuel)/median(duration)==10)
cat("Lookup class boundaries, sparse-cell suppression and rate quantiles passed.\n")
