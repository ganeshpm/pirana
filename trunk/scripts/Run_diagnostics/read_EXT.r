library(lattice)

models <- #PIRANA_IN
model_names <- names(models)
dir.create ("pirana_temp")
if (file.exists (paste("pirana_temp/plot_EXT_",names(models)[1],".pdf", sep=""))){
    file.remove (paste("pirana_temp/plot_EXT_",names(models)[1],".pdf", sep=""))
}
pdf (file = paste("pirana_temp/plot_EXT_",names(models)[1],".pdf", sep=""))
for (c in model_names){
 con <- readLines(file(paste(c,".ext",sep="")))
 methodLines <- grep("TABLE",con)

 for(i in 1:length(methodLines)){
  start <- methodLines[i]; stop <- c(methodLines[i+1]-1)
  method <- strsplit(substr(con[methodLines[i]],start=15, stop=200),":")[[1]][1]
  if(i == length(methodLines)){stop <- length(con)}
  txt <- readLines(file(paste(c,".ext",sep="")))[start:stop]
  dat <- read.table(textConnection(txt), skip=1, header=T)
  dat <- dat[dat$ITERATION>c(-10000000),]
  dat <- cbind(rep(dat$ITERATION, ncol(dat)-1), stack(dat[,2:ncol(dat)]))
  names(dat)<-c("iteration","value","parameter")
  pl<-xyplot(value ~ iteration|as.factor(parameter), data=dat, type="l", scales="free",
   main=method, cex.main=.5, par.settings = list(par.main.text = list(cex = 0.7)))
  print(pl)
  closeAllConnections()
 }
}
dev.off()