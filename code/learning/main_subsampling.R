######################################################################
# Author: Begum Topcuoglu
# Date: 2018-12-20
# Title: Main pipeline for 7 classifiers in R programming language
######################################################################

######################################################################
# Description: 

# This script will read in data from Baxter et al. 2016
#     - 0.03 subsampled OTU dataset
#     - CRC metadata: SRN information


# It will run the following machine learning pipelines:
#     - L2 Logistic Regression 
#     - L1 and L2 Linear SVM
#     - RBF SVM
#     - Decision Tree
#     - Random Forest 
#     - XGBoost 
######################################################################

######################################################################
# Dependencies and Outputs: 

# Be in the project directory.

# The outputs are:
#   (1) AUC values for cross-validation and testing for each data-split 
#   (2) meanAUC values for each hyper-parameter tested during each split.
######################################################################


################### IMPORT LIBRARIES and FUNCTIONS ###################
# The dependinces for this script are consolidated in the first part
deps = c("dplyr", "tictoc", "caret" ,"rpart", "xgboost", "randomForest", "kernlab","LiblineaR", "pROC", "tidyverse");
for (dep in deps){
  if (dep %in% installed.packages()[,"Package"] == FALSE){
    install.packages(as.character(dep), quiet=TRUE, repos = "http://cran.us.r-project.org", dependencies=TRUE);
  }
  library(dep, verbose=FALSE, character.only=TRUE)
}
# Load in needed functions and libraries
source('code/learning/model_selection.R')
source('code/learning/model_pipeline_subsampling.R')
source('code/learning/generateAUCs_subsampling.R')
source('code/learning/model_interpret.R')
source('code/learning/permutation_importance.R')
######################################################################


######################## RUN PIPELINE #############################
# Choose which classification methods we want to run on command line
#                "L2_Logistic_Regression", 
#                "L1_Linear_SVM", 
#                "L2_Linear_SVM",
#                "RBF_SVM", 
#                "Decision_Tree", 
#                "Random_Forest",
#                "XGBoost"

# We will run main.R from command line with arguments
#  - These arguments will be saved into variable "input"
#  - First argument is the seed number which is the array index
#  - Second argument is the model name (one of the list above)
#  - Third argument is the subsample proportion [490, 245, 120, 60, 30, 15]
input <- commandArgs(trailingOnly=TRUE) 
seed <- as.numeric(input[1])
model <- input[2]
subsample_number <- as.numeric(input[3])/490 # To answer the question of when the model breaks
subsample_name <- as.numeric(input[3])
######################## DATA PREPARATION #############################
# Features: Hemoglobin levels(FIT) and 16S rRNA gene sequences(OTUs) in the stool 
# Labels: - Colorectal lesions of 490 patients. 
#         - Defined as cancer or not.(Cancer here means: SRN)
#                                     SRNs are adv adenomas+carcinomas

# Read in metadata and select only sample Id and diagnosis columns
meta <- read.delim('data/metadata.tsv', header=T, sep='\t') %>%
  select(sample, Dx_Bin, fit_result)
# Read in OTU table and remove label and numOtus columns
shared <- read.delim('data/baxter.0.03.subsample.shared', header=T, sep='\t') %>%
  select(-label, -numOtus)
# Merge metadata and OTU table.
# Group advanced adenomas and cancers together as cancer and normal, high risk normal and non-advanced adenomas as normal
# Then remove the sample ID column
data <- inner_join(meta, shared, by=c("sample"="Group")) %>%
  mutate(dx = case_when(
    Dx_Bin== "Adenoma" ~ "normal",
    Dx_Bin== "Normal" ~ "normal",
    Dx_Bin== "High Risk Normal" ~ "normal",
    Dx_Bin== "adv Adenoma" ~ "cancer",
    Dx_Bin== "Cancer" ~ "cancer"
  )) %>%
  select(-sample, -Dx_Bin, -fit_result) %>%
  drop_na() 

# We want the diagnosis column to be a factor
data$dx <- factor(data$dx)

if(subsample_number!=1){
  # Stratified subsampling of the data
  set.seed(seed)
  data <- data %>% group_by(dx)
  data <- sample_frac(data, subsample_number)
  # We want the first sample to be a cancer so we shuffle the dataset with a specific   seed to get cancer as the first sample
  set.seed(1)
  data <- data[sample(1:nrow(data)), ]
  ###################################################################
  # Then arguments 1 and 2 will be placed respectively into the functions:
  #   1. set.seed() : creates reproducibility and variability
  #   2. get_results(): self-defined function that
  #                     - runs the modeling pipeline
  #                     - saves performance and hyper-parameters and imp features
  set.seed(seed)
  # Run the model
  get_results(data, model, seed, subsample_number, subsample_name)
  ###################################################################
}else{
  # No subsampling
  # We want the first sample to be a cancer so we shuffle the dataset with a specific seed to get cancer as the first sample
  set.seed(0)
  data <- data[sample(1:nrow(data)), ]
  ###################################################################
  # Then arguments 1 and 2 will be placed respectively into the functions:
  #   1. set.seed() : creates reproducibility and variability
  #   2. get_results(): self-defined function that
  #                     - runs the modeling pipeline
  #                     - saves performance and hyper-parameters and imp features
  set.seed(seed)
  # Run the model
  get_results(data, model, seed, subsample_number, subsample_name)
  ###################################################################
}






