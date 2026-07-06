############################################################
# 00_setup.R
# Project setup for artificial-language surprisal simulation
############################################################

required_pkgs <- c(
  "tidyverse",
  "glue",
  "fs",
  "janitor"
)

missing_pkgs <- required_pkgs[!required_pkgs %in% rownames(installed.packages())]
if (length(missing_pkgs) > 0) install.packages(missing_pkgs)
invisible(lapply(required_pkgs, library, character.only = TRUE))

set.seed(20260630)

dir_create("R")
dir_create("data")
dir_create("data/raw")
dir_create("data/processed")
dir_create("figures")
dir_create("tables")
dir_create("tables/model_outputs")
dir_create("manuscript")

RUN_MODE <- "final"

if (RUN_MODE == "pilot") {
  N_SIMULATIONS <- 3
  N_SENTENCES_PER_CONDITION <- 300
} else if (RUN_MODE == "final") {
  N_SIMULATIONS <- 30
  N_SENTENCES_PER_CONDITION <- 3000
} else {
  stop("RUN_MODE must be either 'pilot' or 'final'.")
}

PROJECT_PARAMS <- list(
  run_mode = RUN_MODE,
  n_simulations = N_SIMULATIONS,
  n_sentences_per_condition = N_SENTENCES_PER_CONDITION,
  n_exposure_blocks = 10L,
  smoothing_alpha = 0.1,
  confidence_level = 0.95,
  seed = 20260630
)

write_message <- function(..., .envir = parent.frame()) {
  message(glue::glue(..., .envir = .envir))
}

write_message("Setup complete.")
write_message("Run mode: {PROJECT_PARAMS$run_mode}")
write_message("Number of simulations per condition: {PROJECT_PARAMS$n_simulations}")
write_message("Sentences per corpus: {PROJECT_PARAMS$n_sentences_per_condition}")
