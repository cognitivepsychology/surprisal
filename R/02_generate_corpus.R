############################################################
# 02_generate_corpus.R
# Generate probabilistic artificial-language corpora
############################################################

source("R/01_define_grammar.R")

sample_one <- function(x) sample(x, size = 1)

marker_to_class <- setNames(
  marker_mapping$expected_verb_class,
  marker_mapping$marker
)

get_expected_class <- function(marker_token) {
  out <- unname(marker_to_class[[marker_token]])
  if (is.null(out) || length(out) != 1) stop("Invalid marker token: ", marker_token)
  out
}

get_opposite_class <- function(verb_class) {
  if (identical(verb_class, "A")) return("B")
  if (identical(verb_class, "B")) return("A")
  stop("verb_class must be either 'A' or 'B'.")
}

sample_verb_by_class <- function(verb_class) {
  if (identical(verb_class, "A")) return(sample_one(TOKENS$verb_A))
  if (identical(verb_class, "B")) return(sample_one(TOKENS$verb_B))
  stop("verb_class must be either 'A' or 'B'.")
}

generate_sentence <- function(
    simulation_id,
    corpus_id,
    local_sentence_id,
    regularity,
    regularity_label,
    dependency,
    condition_id
) {
  n1 <- sample_one(TOKENS$n1)
  n2 <- sample_one(TOKENS$n2)
  filler <- sample_one(TOKENS$filler)
  marker <- sample_one(TOKENS$marker)
  expected_class <- get_expected_class(marker)
  is_regular <- runif(1) < regularity
  actual_class <- if (is_regular) expected_class else get_opposite_class(expected_class)
  verb <- sample_verb_by_class(actual_class)

  if (dependency == "adjacent") {
    tokens <- c(n1, n2, marker, verb)
    critical_position <- 4L
  } else if (dependency == "nonadjacent") {
    tokens <- c(n1, marker, n2, filler, verb)
    critical_position <- 5L
  } else {
    stop("dependency must be either 'adjacent' or 'nonadjacent'.")
  }

  tibble(
    simulation_id = simulation_id,
    corpus_id = corpus_id,
    local_sentence_id = local_sentence_id,
    regularity = regularity,
    regularity_label = regularity_label,
    dependency = as.character(dependency),
    condition_id = condition_id,
    marker = marker,
    expected_verb_class = expected_class,
    actual_verb_class = actual_class,
    is_regular = is_regular,
    n1 = n1,
    n2 = n2,
    filler = ifelse(dependency == "nonadjacent", filler, NA_character_),
    verb = verb,
    critical_token = verb,
    critical_position = critical_position,
    sentence_length = length(tokens),
    sentence = paste(tokens, collapse = " ")
  )
}

generate_corpus <- function(
    n_simulations = PROJECT_PARAMS$n_simulations,
    n_sentences_per_condition = PROJECT_PARAMS$n_sentences_per_condition
) {
  write_message("Generating artificial-language corpora...")

  design_grid <- tidyr::expand_grid(
    simulation_id = seq_len(n_simulations),
    conditions,
    local_sentence_id = seq_len(n_sentences_per_condition)
  ) %>%
    mutate(
      # corpus_id, not simulation_id alone, identifies one independently
      # generated corpus. The same simulation number is reused across the
      # six conditions and therefore must not be used alone as a cluster ID.
      corpus_id = sprintf("%s__sim%02d", condition_id, simulation_id)
    )

  pmap_dfr(
    design_grid,
    function(
      simulation_id,
      regularity,
      dependency,
      regularity_label,
      condition_id,
      local_sentence_id,
      corpus_id
    ) {
      generate_sentence(
        simulation_id = simulation_id,
        corpus_id = corpus_id,
        local_sentence_id = local_sentence_id,
        regularity = regularity,
        regularity_label = regularity_label,
        dependency = as.character(dependency),
        condition_id = condition_id
      )
    }
  ) %>%
    mutate(
      global_sentence_id = row_number(),
      regularity_label = factor(
        regularity_label,
        levels = c("high_100", "mid_80", "low_60")
      ),
      dependency = factor(
        dependency,
        levels = c("adjacent", "nonadjacent")
      ),
      condition_id = factor(condition_id),
      corpus_id = factor(corpus_id)
    ) %>%
    relocate(global_sentence_id, .before = simulation_id)
}

validate_corpus <- function(corpus) {
  by_corpus <- corpus %>%
    group_by(corpus_id, simulation_id, regularity_label, dependency) %>%
    summarise(
      n_sentences = n(),
      observed_regular_rate = mean(is_regular),
      n_regular = sum(is_regular),
      n_irregular = sum(!is_regular),
      .groups = "drop"
    )

  overall <- corpus %>%
    group_by(regularity_label, dependency) %>%
    summarise(
      n_sentences = n(),
      n_corpora = n_distinct(corpus_id),
      observed_regular_rate = mean(is_regular),
      n_regular = sum(is_regular),
      n_irregular = sum(!is_regular),
      n_unique_sentences = n_distinct(sentence),
      duplicate_rate = 1 - n_unique_sentences / n_sentences,
      .groups = "drop"
    )

  expected_n_corpora <- PROJECT_PARAMS$n_simulations * nrow(conditions)
  if (n_distinct(corpus$corpus_id) != expected_n_corpora) {
    stop("Unexpected number of independent corpora.")
  }
  if (any(by_corpus$n_sentences != PROJECT_PARAMS$n_sentences_per_condition)) {
    stop("At least one corpus has an unexpected sentence count.")
  }

  list(by_corpus = by_corpus, overall = overall)
}

artificial_corpus <- generate_corpus()
validation_results <- validate_corpus(artificial_corpus)

readr::write_csv(artificial_corpus, "data/raw/artificial_corpus.csv")
readr::write_csv(validation_results$by_corpus, "tables/corpus_validation_by_corpus.csv")
readr::write_csv(validation_results$overall, "tables/corpus_validation_overall.csv")

write_message("Corpus generation complete.")
print(validation_results$overall, n = 20)
