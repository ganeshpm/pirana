### Template for R-script
###
### If this script is placed in the /scripts directory in the main Pirana
### folder, the script is automatically available from the Pirana menu ("scripts")
###
### Arguments that are automatically supplied by Pirana to this script are:

models <- #PIRANA_IN

library(xpose4)
dir.create ("pirana_temp")
pdf (file = paste("pirana_temp/xpose_vpc_",names(models)[1], ".pdf", sep=""))
for (i in 1:length(names(models))) {
    npc_dir <- names(models)[i]
    ps <- xpose.VPC(
        vpc.info = paste(npc_dir, "/vpc_results.csv", sep=""),
        vpctab = paste(npc_dir,"/vpctab",sep=""), type="l"
    )
}
print(ps)
dev.off()

print (paste("#", "PIRANA_OUT ","pirana_temp/xpose_vpc_",names(models)[1], ".pdf", sep=""))

quit()
