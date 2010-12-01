library(ellipse)
csv <- read.csv(file="matrix_corr.csv")
rownames(csv) <- colnames(csv)
x <- 1:length(csv)
pdf(file="matrix_corr.pdf", width=8, height=8)
colors <- c("#A50F15","#DE2D26","#FB6A4A","#FCAE91","#FEE5D9","white",
            "#EFF3FF","#BDD7E7","#6BAED6","#3182BD","#08519C")  

del <- c()
for(i in 1:length(csv[,1]) ) {
  if (sum(csv[i,]^2)==0) { del <- c(del, i) }
}
csv <- csv[-del,-del]

plotcorr(as.matrix(csv), col=colors[5*as.matrix(csv)+6], type = "lower", diag=T)
dev.off()
