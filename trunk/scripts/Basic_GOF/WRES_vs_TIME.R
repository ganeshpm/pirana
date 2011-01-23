### R script supplied with Pirana
### by Ron Keizer, 2010
###
### Required: - NM table file with WRES and TIME on first $TABLE record
###
### Description: This R-script create a plot of WRES versus TIME, for
### multiple selected models
###

library(lattice)

models <- #PIRANA_IN
model_names <- names(models)
dir.create ("pirana_temp")
if (file.exists (paste("pirana_temp/plot_WRES_TIME_",names(models)[1],".pdf", sep=""))){
    file.remove (paste("pirana_temp/plot_WRES_TIME_",names(models)[1],".pdf", sep=""))
}
pdf (file = paste("pirana_temp/plot_WRES_TIME_",names(models)[1],".pdf", sep=""))
for (i in 1:length(model_names)) {
    mod      <- models[[model_names[i]]]
    tab_file <- mod$tables[1]
    if (file.exists (tab_file)) {
        tab      <- read.table (tab_file, skip=1, header=T) # NONMEM table with ONEHEADER option
        if ("MDV" %in% names(tab)) { tab <- tab[tab$MDV==0,] }
        if ("EVID" %in% names(tab)) { tab <- tab[tab$EVID==0,] }
        plot (x=tab$TIME, tab$WRES, main = paste (model_names[i],": ", mod$description, sep=""),
              pch=19, xlab="Population predictions", ylab="Weighted residuals")
    }
}
dev.off()

print (paste("#", "PIRANA_OUT ","pirana_temp/plot_WRES_TIME_",names(models)[1],".pdf", sep=""))

quit()
