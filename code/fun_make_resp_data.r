#' Get response data from single and interaction predictors.
#'
#' @param df A data frame of predictor coefficients; may include interaction terms.
#'
#' @return A data frame with a list column of y values as a response to predictors and/or modulators.
#' @export
#' @import magrittr
make_response_data <- function(df){
  # df <- dplyr::filter(df, p_value <= 0.05 | predictor == "Int")
  # keep all single predictors, Intercept, and interactions with significant p_val
  
  # define internal function
  ci <- function(x){qnorm(0.975)*sd(x, na.rm = TRUE)/sqrt(length(x))}
  
  df <- filter(df, p_value <= 0.05 | predictor == "Int" | is.na(modulator))
  
  intercept <- dplyr::filter(df, predictor == "Int") %>% .$coefficient
  
  df <- dplyr::mutate(df, 
               data = purrr::map2(predictor, modulator, function(x,m){
                 # make a seq of x values
                 seq_x <- seq(0,1, 0.1)
                 coefficient_x <- dplyr::filter(df, 
                                                predictor == x,
                                                is.na(modulator)) %>% .$coefficient
                 
                 # check if there is a modulator
                 if(!is.na(m)) {
                   # make a seq of m values and get coefficient
                   seq_m <- seq(0,1, 0.1)
                   coefficient_m <- dplyr::filter(df, 
                                                  predictor == m,
                                                  is.na(modulator)) %>% .$coefficient
                   coefficient_inter <- dplyr::filter(df, 
                                                      predictor == x,
                                                      modulator == m) %>% .$coefficient
                 }
                 else {
                   seq_m <- 0
                   coefficient_m <- 0
                   coefficient_inter <- 0
                 }
                 # make x and m combination df
                 data_resp <- tidyr::crossing(seq_x, seq_m)
                 # calculate y
                 data_resp <- mutate(pred_tbl,
                                    y  = intercept + 
                                      (coefficient_x*seq_x) + 
                                      (coefficient_m*seq_m) +
                                      (coefficient_inter*(seq_x*seq_m)),
                                    y = 1/(1 + exp(-y)))
                 
                 # make groups of the modulator
                 data_resp <- dplyr::mutate(data_resp,
                                     m_group = cut(seq_m, breaks = 2))
                 
                 # group by modulator group and summarise
                 data_resp <- data_resp %>% 
                   group_by(m_group, seq_x) %>% 
                   summarise_at(vars(y), list(mean=mean, ci=ci))
                 return(data_resp)
               }))
  # now filter again on p_value
  df <- filter(df, p_value <= 0.05, predictor != "Int")
  return(df)
}