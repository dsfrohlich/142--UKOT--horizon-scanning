## Script for comparing island level information with the processed Caribbean IAS database
# 13/04/2018, OL Pescott
#rm(list=ls())
library(reshape2)

# previously processed IAS Db for Caribbean (see processCaribIASDb.R)
iasDbPl_ALL_Std <- read.csv(file = "outputs/IASCaribDb_Plants_longform_FINAL.csv", header = T, stringsAsFactors = F)[,c(2:7)] # avoid uncessary 1st column of row numbers
iasDbPl_ALL_Std$Species.Name <- gsub("\n", " ", x = iasDbPl_ALL_Std$Species.Name)
iasDbPl_ALL_Std$Species.Name <- gsub("[-(-^0-9)]$", "", x = iasDbPl_ALL_Std$Species.Name) # remove any non-alphabetic character from end of string

# read in pathways connecting focal islands to other islands through trade and other pathways (simplied version)
CNlist2 <- read.csv(file = "data/CaribbeanOT_links_GATS_and_PA_withISOs_v1.csv", header = T, stringsAsFactors = F)
# fix a couple of issues with ISO codes

CNlist2[is.na(CNlist2$partner2iso),c(5,30)] # have a look at the ones that have NA, none of importance for the current task
# drop those lines
CNlist2_noNAs <- CNlist2[!is.na(CNlist2$partner2iso),]

# just extract the key info for the moment
CNlist2_noNAs <- CNlist2_noNAs[,c(3,5,28:30)] # focus, partner, source of pathway info, focal ISO, partner ISO

# example of process for AI (Anguilla)
#ai_UniPart <- unique(CNlist2_noNAs[CNlist2_noNAs$reporter=="Anguilla",]$partner2iso)
#iasDbPl_ai_partners <- iasDbPl_ALL_Std[iasDbPl_ALL_Std$iso2code %in% ai_UniPart,]
#iasDbPl_ai <- iasDbPl_ALL_Std[iasDbPl_ALL_Std$iso2code == "AI",]
#iasDbPl_ai_HS <- iasDbPl_ai_partners[!(iasDbPl_ai_partners$Species.Name %in% iasDbPl_ai$Species.Name),]
#length(unique(iasDbPl_ai_HS$Species.Name[iasDbPl_ai_HS$status == "invasive"])) # 268

# turn process into a function
getThreats <- function(country = country, db = db, ...){
  CNlist_tmp <- unique(CNlist2_noNAs[CNlist2_noNAs$reporter2iso==country,]$partner2iso) # get appropriate list of partner data
  partner_data <- db[db$iso2code %in% CNlist_tmp,] # filter db based on list of partners
  focal_data <- db[db$iso2code == country,] # filter db based on focal country
  HS_data <- partner_data[!(partner_data$Species.Name %in% focal_data$Species.Name),] # delete names from partner list that are already reported for focus
  CN_threat_list <- data.frame(species = unique(HS_data$Species.Name[HS_data$status == "invasive"]), country_at_risk = country) # turn the remaining list of species into an HS list of potential future arrivals
  CN_threat_list <- CN_threat_list[order(CN_threat_list$species),] # tidy
  row.names(CN_threat_list) <- 1:nrow(CN_threat_list) # tidy
  return(CN_threat_list) # return
}

# apply across countries of importance
HSlists <- list() # create receiving list for HS threats for each focal island
HSlists <- lapply(unique(CNlist2_noNAs$reporter2iso), function(x) getThreats(country = x, db = iasDbPl_ALL_Std)) # apply across focal islands
names(HSlists) <- unique(CNlist2_noNAs$reporter2iso) # name list items
# flatten list for writing out
HSlists_df <- do.call(rbind, HSlists)
#write.csv(HSlists_df, file = "outputs/HSlists_fromCaribIASDb.csv", row.names = FALSE)

## Also create lists in the per species format required for the HS template (species, island1 (present Y/N), island2 (present Y/N) etc.)
# invasives only
iasDbPl_ALL_invs <- iasDbPl_ALL_Std[iasDbPl_ALL_Std$status=="invasive",]
# only include species that were listed as HS threats based on pathway info
iasDbPl_ALL_invs <- iasDbPl_ALL_invs[iasDbPl_ALL_invs$Species.Name %in% HSlists_df$species,]
iasDbPl_ALL_invs <- unique(iasDbPl_ALL_invs)
iasDbPl_ALL_invsWide <- dcast(iasDbPl_ALL_invs, Species.Name ~ iso2code) # isocode is standardised across country name formats (unlike long forms)
# filter to countries of interest
iasDbPl_ALL_invsWide <- cbind(iasDbPl_ALL_invsWide[,c(1)], iasDbPl_ALL_invsWide[,colnames(iasDbPl_ALL_invsWide) %in% CNlist2_noNAs$reporter2iso])
head(iasDbPl_ALL_invsWide)
names(iasDbPl_ALL_invsWide)[1] <- "species"
# delete any rows at genus level
iasDbPl_ALL_invsWide <- iasDbPl_ALL_invsWide[!grepl("spp", iasDbPl_ALL_invsWide$species),]
# note that there are no records of these species for Turks and Caicos
head(iasDbPl_ALL_invs[iasDbPl_ALL_invs$iso2code=="TC",])
head(iasDbPl_ALL_invsWide) # so no TC column
# add TC column for compatiblity with Gbif outputs
iasDbPl_ALL_invsWide$TC <- 0
iasDbPl_ALL_invsWide <- iasDbPl_ALL_invsWide[,c(1:5,7,6)]

#write.csv(iasDbPl_ALL_invsWide, file = "outputs/HSlists_fromCaribIASDb_WIDEform.csv", row.names = FALSE)
# read back in if needed
#iasDbPl_ALL_invsWide <- read.csv(file = "outputs/HSlists_fromCaribIASDb_WIDEform.csv", header = T, stringsAsFactors = F)

### END