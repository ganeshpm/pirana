### Template for R-script
###
### If this script is placed in the /scripts directory in the main Pirana
### folder, the script is automatically available from the Pirana menu ("scripts")
###
### Pirana automatically creates an object with information on the model,
### which are available with the following keys:
### modelfile, description, reference_model, data_file, outputfile, tables,
### theta_est, omega_est, sigma_est

models <- #PIRANA_IN

### So, if you want to load the first table specified in $TABLE record
### in the first model file you selected, use e.g.:
model_names <- names(models)
model_1     <- models[[model_names[1]]]
tab_file    <- model_1$tables[1]
tab         <- read.table (tab_file, skip=1, header=T) # NONMEM table with ONEHEADER option

### After running the script, and e.g. creating a plot, you can instruct
### Pirana to open it. These may be either pdf, ps, eps, jpg, gif, png,
### or html files.

dir.create ("pirana_temp")
pdf (file = "pirana_temp/test.pdf")
plot (x=tab$TIME, tab$DV, main=model_1$descr);
dev.off()

### Specify the following to view the file you created. E.g.:
#PIRANA_OUT pirana_temp/test.pdf

quit()
