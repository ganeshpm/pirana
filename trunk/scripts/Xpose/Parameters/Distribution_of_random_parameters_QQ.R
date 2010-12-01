### R-Script supplied with Pirana
### Description: Creates ranpar.qq() using Xpose

models <- #PIRANA_IN
library(xpose4)

dir.create("pirana_temp")
pdf(paste("pirana_temp/","xpose_dist_randpar_qq_",names(models)[1],".pdf", sep=""))
for (i in 1:length(names(models))) {
    model     <- names(models)[i]
    new.runno <- gsub("run", "", model)
    xpdb      <- xpose.data(new.runno)
    newnam    <- paste("xpdb", new.runno, sep = "")
    assign (pos = 1, newnam, xpdb)
    assign (pos = 1, ".cur.db", xpdb)
    print(ranpar.qq(xpdb))
}
dev.off()

print (paste("#", "PIRANA_OUT ","pirana_temp/xpose_dist_randpar_qq_",names(models)[1], ".pdf", sep=""))

quit()
