############################################################
# 05_analyze_results.R
# Corrected hypothesis-focused statistical analyses
############################################################

source("R/00_setup.R")

analysis_pkgs <- c("broom", "emmeans", "clubSandwich", "sandwich")
missing_pkgs <- analysis_pkgs[!analysis_pkgs %in% rownames(installed.packages())]
if (length(missing_pkgs) > 0) install.packages(missing_pkgs)
invisible(lapply(analysis_pkgs, library, character.only = TRUE))

dir_create("tables/model_outputs")

input_path <- "data/processed/critical_by_corpus_block.csv"
if (!file.exists(input_path)) stop("Run R/03_compute_surprisal.R first.")

analysis_data <- readr::read_csv(input_path, show_col_types = FALSE) %>%
  mutate(
    corpus_id = factor(corpus_id),
    regularity_label = factor(
      regularity_label,
      levels = c("high_100", "mid_80", "low_60")
    ),
    regularity_label_readable = factor(
      regularity_label,
      levels = c("high_100", "mid_80", "low_60"),
      labels = c("100% regular", "80% regular", "60% regular")
    ),
    dependency = factor(dependency, levels = c("adjacent", "nonadjacent")),
    dependency_readable = factor(
      dependency,
      levels = c("adjacent", "nonadjacent"),
      labels = c("Adjacent", "Non-adjacent")
    ),
    model_order = factor(model_order, levels = c("2-gram", "3-gram")),
    exposure_block = as.integer(exposure_block),
    uncertainty = 1 - regularity
  )

# Use design-level centering/scaling so coefficients have stable meanings.
# uncertainty_z: -1, 0, +1 for 100%, 80%, 60% regularity.
# exposure_block_z: standardized 1--10 block index.
analysis_data <- analysis_data %>%
  mutate(
    uncertainty_z = (uncertainty - 0.20) / 0.20,
    exposure_block_z = as.numeric(scale(
      exposure_block,
      center = mean(1:PROJECT_PARAMS$n_exposure_blocks),
      scale = sd(1:PROJECT_PARAMS$n_exposure_blocks)
    ))
  )

# Structural checks. There must be 6 conditions × 30 independent corpora.
expected_corpora <- n_distinct(analysis_data$condition_id) * PROJECT_PARAMS$n_simulations
if (n_distinct(analysis_data$corpus_id) != expected_corpora) {
  stop("Unexpected number of independent corpus clusters.")
}

structure_check <- analysis_data %>%
  count(corpus_id, model_order, name = "n_blocks")
if (any(structure_check$n_blocks != PROJECT_PARAMS$n_exposure_blocks)) {
  stop("At least one corpus/model combination has an unexpected number of blocks.")
}
readr::write_csv(structure_check, "tables/model_outputs/analysis_structure_check.csv")

# Why no mixed model?
# simulation_id alone is reused across the six independently generated conditions.
# It is therefore not the correct grouping unit. In the full block analysis,
# repeated observations occur within corpus_id. We fit ordinary regressions and
# use CR2 cluster-robust standard errors at corpus_id. This directly addresses
# within-corpus dependence without an unsupported random effect and cannot
# produce a singular mixed-model fit.

robust_coef_table <- function(model, cluster, model_order_label, analysis_name) {
  V_CR2 <- clubSandwich::vcovCR(model, cluster = cluster, type = "CR2")
  test <- clubSandwich::coef_test(model, vcov = V_CR2, test = "Satterthwaite")
  test_df <- as.data.frame(test)
  out <- tibble::tibble(
    analysis = analysis_name,
    model_order = model_order_label,
    term = rownames(test_df),
    estimate = test_df$beta,
    std.error = test_df$SE,
    statistic = test_df$tstat,
    df = test_df$df_Satt,
    p.value = test_df$p_Satt
  ) %>%
    mutate(
      conf.low = estimate - qt(0.975, df) * std.error,
      conf.high = estimate + qt(0.975, df) * std.error
    )
  list(table = out, vcov = V_CR2)
}

robust_hc3_coef_table <- function(model, model_order_label, analysis_name) {
  V_HC3 <- sandwich::vcovHC(model, type = "HC3")
  beta <- stats::coef(model)
  se <- sqrt(diag(V_HC3))
  df <- stats::df.residual(model)
  statistic <- beta / se
  out <- tibble::tibble(
    analysis = analysis_name,
    model_order = model_order_label,
    term = names(beta),
    estimate = unname(beta),
    std.error = unname(se),
    statistic = unname(statistic),
    df = df,
    p.value = 2 * stats::pt(abs(statistic), df = df, lower.tail = FALSE),
    conf.low = estimate - stats::qt(0.975, df) * std.error,
    conf.high = estimate + stats::qt(0.975, df) * std.error
  )
  list(table = out, vcov = V_HC3)
}

# H1 and the exposure-course component of H2--H4.
# Model orders are analyzed separately because model order is a robustness
# condition rather than an independent theoretical hypothesis.
fit_exposure_model <- function(order_label) {
  dat <- analysis_data %>% filter(model_order == order_label)
  model <- lm(
    mean_critical_surprisal ~ uncertainty_z * dependency * exposure_block_z,
    data = dat
  )
  robust <- robust_coef_table(
    model, dat$corpus_id, order_label, "exposure_course"
  )
  list(model = model, data = dat, coef = robust$table, vcov = robust$vcov)
}

exposure_models <- lapply(levels(analysis_data$model_order), fit_exposure_model)
exposure_coefficients <- bind_rows(lapply(exposure_models, `[[`, "coef"))
readr::write_csv(
  exposure_coefficients,
  "tables/model_outputs/exposure_models_CR2_coefficients.csv"
)

# A planned descriptive test of the nonlinear part of H1:
# Is the block-1-to-2 reduction larger than the average reduction thereafter?
early_late_data <- analysis_data %>%
  select(
    corpus_id, simulation_id, model_order, regularity, regularity_label,
    regularity_label_readable, dependency, dependency_readable, uncertainty_z,
    exposure_block, mean_critical_surprisal
  ) %>%
  tidyr::pivot_wider(
    names_from = exposure_block,
    values_from = mean_critical_surprisal,
    names_prefix = "block_"
  ) %>%
  rowwise() %>%
  mutate(
    early_drop = block_1 - block_2,
    later_mean_drop = mean(c(
      block_2 - block_3,
      block_3 - block_4,
      block_4 - block_5,
      block_5 - block_6,
      block_6 - block_7,
      block_7 - block_8,
      block_8 - block_9,
      block_9 - block_10
    )),
    early_minus_later = early_drop - later_mean_drop
  ) %>%
  ungroup()

fit_early_late <- function(order_label) {
  dat <- early_late_data %>% filter(model_order == order_label)
  model <- lm(early_minus_later ~ uncertainty_z * dependency, data = dat)
  robust_hc3_coef_table(
    model,
    model_order_label = order_label,
    analysis_name = "early_vs_later_drop"
  )$table
}

fit_early_late_overall <- function(order_label) {
  dat <- early_late_data %>% filter(model_order == order_label)
  model <- lm(early_minus_later ~ 1, data = dat)
  robust_hc3_coef_table(
    model,
    model_order_label = order_label,
    analysis_name = "early_vs_later_drop_overall"
  )$table
}

fit_early_late_cells <- function(order_label) {
  dat <- early_late_data %>% filter(model_order == order_label)
  model <- lm(
    early_minus_later ~ regularity_label_readable * dependency_readable,
    data = dat
  )
  V_HC3 <- sandwich::vcovHC(model, type = "HC3")
  emm <- emmeans::emmeans(
    model,
    ~ regularity_label_readable * dependency_readable,
    vcov. = V_HC3
  )
  as.data.frame(emmeans::test(emm, null = 0, adjust = "holm")) %>%
    tibble::as_tibble() %>%
    mutate(model_order = order_label, .before = 1)
}

early_late_coefficients <- bind_rows(
  lapply(levels(analysis_data$model_order), fit_early_late)
)
early_late_overall <- bind_rows(
  lapply(levels(analysis_data$model_order), fit_early_late_overall)
)
early_late_cells <- bind_rows(
  lapply(levels(analysis_data$model_order), fit_early_late_cells)
)
readr::write_csv(
  early_late_data,
  "tables/model_outputs/early_vs_later_drop_by_corpus.csv"
)
readr::write_csv(
  early_late_coefficients,
  "tables/model_outputs/early_vs_later_drop_coefficients.csv"
)
readr::write_csv(
  early_late_overall,
  "tables/model_outputs/early_vs_later_drop_overall.csv"
)
readr::write_csv(
  early_late_cells,
  "tables/model_outputs/early_vs_later_drop_cells.csv"
)

# H2--H4 at the final block. Within each model order, each corpus contributes
# exactly one independent final-block observation, so an ordinary linear model
# is appropriate and no random effect or cluster correction is needed.
final_block <- max(analysis_data$exposure_block)
final_data <- analysis_data %>% filter(exposure_block == final_block)

fit_final_continuous <- function(order_label) {
  dat <- final_data %>% filter(model_order == order_label)
  model <- lm(
    mean_critical_surprisal ~ uncertainty_z * dependency,
    data = dat
  )
  robust_hc3_coef_table(
    model,
    model_order_label = order_label,
    analysis_name = "final_block_continuous"
  )$table
}

final_continuous_coefficients <- bind_rows(
  lapply(levels(final_data$model_order), fit_final_continuous)
)
readr::write_csv(
  final_continuous_coefficients,
  "tables/model_outputs/final_block_models_coefficients.csv"
)

# Factor models and planned contrasts.
fit_final_factor <- function(order_label) {
  dat <- final_data %>% filter(model_order == order_label)
  model <- lm(
    mean_critical_surprisal ~ regularity_label_readable * dependency_readable,
    data = dat
  )
  # Cell variances differ substantially, so use an HC3 covariance matrix
  # rather than the pooled homoskedastic OLS covariance.
  V_HC3 <- sandwich::vcovHC(model, type = "HC3")

  emm_reg <- emmeans::emmeans(
    model,
    specs = ~ regularity_label_readable | dependency_readable,
    vcov. = V_HC3
  )
  reg_pairs <- as.data.frame(
    emmeans::contrast(emm_reg, method = "pairwise", adjust = "tukey")
  ) %>%
    tibble::as_tibble() %>%
    mutate(model_order = order_label, .before = 1)

  emm_dep <- emmeans::emmeans(
    model,
    specs = ~ dependency_readable | regularity_label_readable,
    vcov. = V_HC3
  )
  dep_pairs <- as.data.frame(
    emmeans::contrast(emm_dep, method = "pairwise", adjust = "none")
  ) %>%
    tibble::as_tibble() %>%
    mutate(model_order = order_label, .before = 1)

  emm_cells <- as.data.frame(
    emmeans::emmeans(
      model,
      ~ regularity_label_readable * dependency_readable,
      vcov. = V_HC3
    )
  ) %>%
    tibble::as_tibble() %>%
    mutate(model_order = order_label, .before = 1)

  list(
    model = model,
    coefficients = robust_hc3_coef_table(
      model,
      model_order_label = order_label,
      analysis_name = "final_block_factor"
    )$table,
    emmeans = emm_cells,
    regularity_pairs = reg_pairs,
    dependency_pairs = dep_pairs
  )
}

factor_results <- lapply(levels(final_data$model_order), fit_final_factor)
readr::write_csv(
  bind_rows(lapply(factor_results, `[[`, "coefficients")),
  "tables/model_outputs/final_block_factor_coefficients.csv"
)
readr::write_csv(
  bind_rows(lapply(factor_results, `[[`, "emmeans")),
  "tables/model_outputs/final_block_emmeans.csv"
)
readr::write_csv(
  bind_rows(lapply(factor_results, `[[`, "regularity_pairs")),
  "tables/model_outputs/final_block_pairwise_regularities.csv"
)
readr::write_csv(
  bind_rows(lapply(factor_results, `[[`, "dependency_pairs")),
  "tables/model_outputs/final_block_pairwise_dependencies.csv"
)

# Descriptive final-block table based on 30 independent corpus means per cell.
descriptive_final <- final_data %>%
  group_by(model_order, regularity_label_readable, dependency) %>%
  summarise(
    mean = mean(mean_critical_surprisal),
    sd = sd(mean_critical_surprisal),
    n_corpora = n(),
    se = sd / sqrt(n_corpora),
    ci95 = qt(0.975, df = n_corpora - 1) * se,
    .groups = "drop"
  )
readr::write_csv(
  descriptive_final,
  "tables/model_outputs/descriptive_final_block_critical.csv"
)

# Human-readable diagnostic log.
diagnostic_path <- "tables/model_outputs/analysis_diagnostics.txt"
capture.output({
  cat("CORRECTED ANALYSIS\n")
  cat("No mixed-effects model is fitted. Therefore singular fit is not applicable.\n")
  cat("Independent corpus clusters:", n_distinct(analysis_data$corpus_id), "\n")
  cat("Rows in corpus-block analysis:", nrow(analysis_data), "\n")
  cat("Rows in final-block analysis:", nrow(final_data), "\n\n")

  for (i in seq_along(exposure_models)) {
    cat("=== Exposure model:", levels(analysis_data$model_order)[i], "===\n")
    print(exposure_models[[i]]$coef)
    cat("\n")
  }

  cat("=== H1: early drop minus later mean drop (overall) ===\n")
  print(early_late_overall)
  cat("\n")

  for (i in seq_along(factor_results)) {
    cat("=== Final factor model with HC3 inference:", levels(final_data$model_order)[i], "===\n")
    print(factor_results[[i]]$coefficients)
    cat("\n")
  }
  print(sessionInfo())
}, file = diagnostic_path)

write_message("Corrected analysis complete.")
write_message("No lmer model was retained; the singular-fit problem has been removed.")
