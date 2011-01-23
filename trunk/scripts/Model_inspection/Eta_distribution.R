### R-Script supplied with Pirana
### by Ron Keizer, Jan 2010
###
### Required: - Eta values outputted by NONMEME as .ETA file
###
### Description: This R-script looks for a table file named ".ETA" among
### the files generated using $TABLE and creates histograms of the eta
### distributions
###
### Example $TABLE record specification:
###    $TABLE ID ETA(1) ETA(2) ETA(3) FIRSTONLY NOAPPEND NOPRINT FILE=001.ETA
###

models <- #PIRANA_IN
model <- names(models)[1]
tabfiles <- models[[model]]$tables
eta_tab <- c(tabfiles[grep(".ETA", tabfiles)], tabfiles[grep(".eta", tabfiles)])[1]
etas <- read.table (file = unlist(eta_tab)[1], header=T, skip=1)

n_etas <- length(etas[1,])-1
etas   <- etas[,2:(n_etas+1)]
pdf_file <- paste("pirana_temp/etas_",model,".pdf",sep="")
pdf (file = pdf_file) ;
layout (mat = matrix ( c(1:n_etas) , ncol=2, nrow = round(n_etas/2) ) )
par (mar = c(2.5, 4, 4, 1) )
for (i in 1:n_etas) {
    hist (etas[,(i)], main = colnames(etas)[i], col = "darkgrey", border=NA, xlab="")
    med <- median (etas[,i])
    abline (v = med, col="darkred", lwd=3) }
dev.off()

print (paste("#", "PIRANA_OUT ","pirana_temp/etas_",model, ".pdf", sep=""))

quit()

