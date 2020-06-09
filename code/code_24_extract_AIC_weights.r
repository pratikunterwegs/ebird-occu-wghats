## ----load_libs-----------------------------------------------------------------------------
# to load data
library(readxl)

# to handle data
library(dplyr)
library(readr)
library(forcats)
library(tidyr)
library(purrr)
library(stringr)
library(magrittr)

# to wrangle models
source("code/fun_model_estimate_collection.r")
source("code/fun_make_resp_data.r")

# plotting
library(ggplot2)
library(patchwork)
source('code/fun_plot_interaction.r')


## ----get_data_from_sheets------------------------------------------------------------------
# read in the excel sheet containing information on the best supported hypothesis
sheet_names <- readxl::excel_sheets("data/results/all_hypoComparisons_allScales.xlsx")
which_sheet <- which(str_detect(sheet_names, "Best"))

hypothesis_data <- readxl::read_excel("data/results/all_hypoComparisons_allScales.xlsx",
                                      sheet = sheet_names[which_sheet])

# Subsetting the data needed to call in each species' model coefficient information
hypothesis_data <- select(hypothesis_data,
                          Scientific_name, Common_name,
                          contains("Best supported hypothesis"))

# pivot longer
hypothesis_data <- pivot_longer(hypothesis_data,
                                cols = contains("Best"),
                                names_to = "scale", values_to = "hypothesis")
# fix scale to numeric
hypothesis_data <- mutate(hypothesis_data,
                          scale = if_else(str_detect(scale, "10"), "10km", "2.5km"))

# list the supported hypotheses
# first separate the hypotheses into two columns
hypothesis_data <- separate(hypothesis_data, col = hypothesis, sep = "; ", 
                            into = c("hypothesis_01", "hypothesis_02"),
                            fill = "right") %>% 
  # then get the data into long format
  pivot_longer(cols = c("hypothesis_01","hypothesis_02"),
               values_to = "hypothesis") %>% 
  # remove NA where there is only one hypothesis
  drop_na() %>% 
  # remove the name column
  select(-name)

# correct the name landCover to lc
hypothesis_data <- mutate(hypothesis_data,
                          hypothesis = replace(hypothesis,
                                               hypothesis %in% c("landCover", "climate",
                                                                 "elevation"), 
                                               c("lc","clim","elev")))


## ----read_model_importance-----------------------------------------------------------------
# which file to read model importance from
hypothesis_data <- mutate(hypothesis_data,
                          file_read = glue::glue('data/results/Results_{scale}/occuCovs/modelImp/{hypothesis}_imp.xlsx'))

# read in data as list column
model_data <- mutate(hypothesis_data,
                     model_imp = map2(file_read, Scientific_name, function(fr, sn){
                       readxl::read_excel(fr, sheet = sn)
                     }))

# rename model data components and separate predictors
names <- c("predictor", "AICweight")

# get data for plotting: separate the interaction terms and make the response df
model_data <- mutate(model_data, 
                     model_imp = map(model_imp, function(df){
  colnames(df) <- names
  df <- separate_interaction_terms(df)
  return(df)
}))

# remove filename
model_data <- select(model_data, -file_read) %>% 
  unnest(model_imp) 



## ----get_aic_data--------------------------------------------------------------------------
# nest model data
model_data <- model_data %>% 
  group_by(scale) %>%
  nest() %>% 
  ungroup()

# pass function over the data to get cumulative aic weight
model_data <- model_data %>% 
  mutate(aic_data = map(data, function(df){
    group_by(df, predictor, modulator) %>% 
      summarise(cumulative_AIC_weight = sum(as.numeric(AICweight))) %>%
      ungroup() %>% 
      
      # remove .y from predictor names
      mutate_if(is.character, .funs = function(x){
        str_remove(x, pattern = ".y")
        }) %>%
      mutate(predictor_final = glue::glue('{predictor}:{modulator}'))
  }))

# unnest the data
model_data %<>% unnest(cols = "aic_data")

fig_cum_AIC <- 
  ggplot(model_data, 
         aes(x = predictor_final, y = cumulative_AIC_weight, 
             colour=predictor_final)) +   geom_point(size=3)+
  facet_wrap(~scale, scales = "free") + 
  theme_bw()+labs(x = "Predictor", colour = "Predictor")+
  theme(legend.position = "none") +
  theme(axis.text.x = element_text(angle = 90))

# save plot
ggsave(fig_cum_AIC, filename = "figs/fig_cum_AIC.png",
       dpi = 300)

