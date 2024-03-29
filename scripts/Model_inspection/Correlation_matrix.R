### R script supplied with Pirana
### by Ron Keizer, 2010
###
### Required: - R package 'ellipse' installed
###           - NONMEM 7 output ( .cor file )
###
### Description: This R-script create a correlation plot from a correlation
### matrix. It assumes a file named xxxx.cor is created (NONMEM7 only) which
### contains the correlation matrix (xxxx is the model name).
###

if (length(grep ("ellipse",installed.packages()))==0) {
  print ("Please install package 'ellipse' to use this script!")
} else {
  library(ellipse)
}

colors <- c("#A50F15","#DE2D26","#FB6A4A","#FCAE91","#FEE5D9","white",
            "#EFF3FF","#BDD7E7","#6BAED6","#3182BD","#08519C")

# Read the correlation file outputted by NONMEM
models       <- #PIRANA_IN
model        <- names(models)[1]
cor          <- readLines (paste(model,".cor", sep=""))
cor_flag     <- 0
methods      <- c()
methods_idx  <- c()
methods_idx2 <- c()
all          <- list()

# filter out info
methods      <- cor[grep("TABLE", cor)]
cor          <- cor[-grep("TABLE", cor)]
methods_idx  <- grep ("NAME", cor)
cor          <- cor[-grep("NAME", cor)]
methods_idx  <- methods_idx - (seq(1:length(methods_idx))-1)
methods_idx2 <- methods_idx - 1
methods_idx2 <- c(methods_idx2, length(cor))
methods_idx2 <- methods_idx2[-1]

if (!(file.exists("pirana_temp"))) { dir.create("pirana_temp") }
write.table(cor, file=paste("pirana_temp/",model,"_temp.cor",sep=""), quote=F, row.names=F, col.names=T, sep=",")
co <- data.frame ( read.fwf (file=paste("pirana_temp/",model,"_temp.cor", sep=""), widths=c(rep(13, (length(cor)+1))), skip=1 ) )
co <- co[,1:length( co[1, !is.na(co[1,]) ] )]

col_names <- gsub (" ", "", as.matrix( data.frame(co[methods_idx[1]:(methods_idx2[1]),1])) )
co <- co[, -1]
colnames (co) <- c(col_names)
n_par     <- length(col_names)
n_methods <- length(methods_idx)

pdf (file=paste("pirana_temp/corr_matrix_",model,".pdf",sep=""))
for (i in 1:n_methods) {
    co_method <- co[methods_idx[i]:(methods_idx2[i]),]
    rownames (co_method) <- c((col_names))
    plotcorr(as.matrix(co_method[1:n_par,1:n_par]),
         col = colors[5*as.matrix(co_method[1:n_par,1:n_par])+6],
         type = "lower",
         diag=T,
         main = methods[i]
         )
}
dev.off()

print (paste("#", "PIRANA_OUT ","pirana_temp/corr_matrix_",model, ".pdf", sep=""))

quit()

