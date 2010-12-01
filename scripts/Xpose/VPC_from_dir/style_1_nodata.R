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
    xpose.VPC(
        vpc.info = paste(npc_dir, "/vpc_results.csv", sep=""),
        vpctab = paste(npc_dir,"/vpctab",sep=""),
        type="n",
        PI.ci="area",
        PI.ci.med.arcol=rgb(0.1,0.1,0.1,1),
        PI.ci.med.lty="dotted",
        PI.ci.up.arcol=rgb(0.6,0.6,.6,1),
        PI.ci.down.arcol=rgb(0.6,0.6,.6,1),
        PI='a', PI.real='lines',
        PI.real.up.col='grey51',
        PI.real.down.col='grey51',
        PI.real.med.col='black',
        PI.limits=c(0.1,0.9),
        max.plots.per.page=1,
        PI.ci.area.smooth=T
    )
}
dev.off()

print (paste("#", "PIRANA_OUT ","pirana_temp/xpose_vpc_",names(models)[1], ".pdf", sep=""))

quit()
