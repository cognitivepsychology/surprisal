############################################################
# 03_compute_surprisal.R
# Compute online n-gram surprisal
############################################################

source("R/01_define_grammar.R")

corpus_path <- "data/raw/artificial_corpus.csv"
if (!file.exists(corpus_path)) stop("Run R/02_generate_corpus.R first.")

artificial_corpus <- readr::read_csv(corpus_path, show_col_types = FALSE)

if (!"corpus_id" %in% names(artificial_corpus)) {
  artificial_corpus <- artificial_corpus %>%
    mutate(corpus_id = sprintf("%s__sim%02d", condition_id, simulation_id))
}

artificial_corpus <- artificial_corpus %>%
  mutate(
    corpus_id = as.character(corpus_id),
    regularity_label = factor(
      regularity_label,
      levels = c("high_100", "mid_80", "low_60")
    ),
    dependency = factor(dependency, levels = c("adjacent", "nonadjacent")),
    condition_id = factor(condition_id)
  ) %>%
  arrange(corpus_id, local_sentence_id)

VOCAB <- lexicon$token
VOCAB_SIZE <- length(VOCAB)
ALPHA <- PROJECT_PARAMS$smoothing_alpha
N_EXPOSURE_BLOCKS <- PROJECT_PARAMS$n_exposure_blocks

split_sentence <- function(sentence) unlist(strsplit(sentence, "\\s+"))
make_context_key <- function(context_tokens) paste(context_tokens, collapse = " ")
increment_env_count <- function(env, key, value = 1) {
  old <- env[[key]]
  env[[key]] <- if (is.null(old)) value else old + value
}
get_env_count <- function(env, key) {
  value <- env[[key]]
  if (is.null(value)) 0 else value
}

compute_online_ngram_for_corpus <- function(corpus_df, n_order = 2, alpha = ALPHA) {
  if (!n_order %in% c(2, 3)) stop("n_order must be 2 or 3.")
  if (n_distinct(corpus_df$corpus_id) != 1) stop("Input must contain exactly one corpus_id.")

  corpus_df <- corpus_df %>% arrange(local_sentence_id)
  max_sentence_id <- max(corpus_df$local_sentence_id)
  ngram_counts <- new.env(hash = TRUE, parent = emptyenv())
  context_counts <- new.env(hash = TRUE, parent = emptyenv())
  output_rows <- vector("list", 0)
  row_counter <- 1L

  for (i in seq_len(nrow(corpus_df))) {
    row_i <- corpus_df[i, ]
    tokens <- split_sentence(row_i$sentence)
    padded_tokens <- if (n_order == 2) c("<s>", tokens) else c("<s>", "<s>", tokens)

    for (pos in seq_along(tokens)) {
      padded_pos <- pos + n_order - 1L
      context_tokens <- padded_tokens[(padded_pos - n_order + 1L):(padded_pos - 1L)]
      target_token <- padded_tokens[padded_pos]
      context_key <- make_context_key(context_tokens)
      ngram_key <- paste(context_key, target_token, sep = " || ")
      ngram_count <- get_env_count(ngram_counts, ngram_key)
      context_count <- get_env_count(context_counts, context_key)
      probability <- (ngram_count + alpha) / (context_count + alpha * VOCAB_SIZE)
      surprisal <- -log2(probability)
      exposure_block <- min(
        ceiling((row_i$local_sentence_id / max_sentence_id) * N_EXPOSURE_BLOCKS),
        N_EXPOSURE_BLOCKS
      )

      output_rows[[row_counter]] <- tibble(
        simulation_id = row_i$simulation_id,
        corpus_id = row_i$corpus_id,
        local_sentence_id = row_i$local_sentence_id,
        global_sentence_id = row_i$global_sentence_id,
        regularity = row_i$regularity,
        regularity_label = as.character(row_i$regularity_label),
        dependency = as.character(row_i$dependency),
        condition_id = as.character(row_i$condition_id),
        model_order = paste0(n_order, "-gram"),
        token_position = pos,
        sentence_length = length(tokens),
        token = target_token,
        context = context_key,
        probability = probability,
        surprisal = surprisal,
        is_critical = pos == row_i$critical_position,
        critical_position = row_i$critical_position,
        is_regular = row_i$is_regular,
        marker = row_i$marker,
        expected_verb_class = row_i$expected_verb_class,
        actual_verb_class = row_i$actual_verb_class,
        exposure_block = exposure_block,
        sentence = row_i$sentence
      )
      row_counter <- row_counter + 1L
      increment_env_count(ngram_counts, ngram_key)
      increment_env_count(context_counts, context_key)
    }
  }
  bind_rows(output_rows)
}

compute_online_ngram_all <- function(corpus, n_order) {
  write_message("Computing {n_order}-gram surprisal...")
  corpus %>%
    group_by(corpus_id) %>%
    group_split() %>%
    purrr::map_dfr(~ compute_online_ngram_for_corpus(.x, n_order = n_order))
}

token_surprisal <- bind_rows(
  compute_online_ngram_all(artificial_corpus, 2),
  compute_online_ngram_all(artificial_corpus, 3)
) %>%
  mutate(
    regularity_label = factor(
      regularity_label,
      levels = c("high_100", "mid_80", "low_60")
    ),
    dependency = factor(dependency, levels = c("adjacent", "nonadjacent")),
    model_order = factor(model_order, levels = c("2-gram", "3-gram")),
    exposure_block = as.integer(exposure_block),
    corpus_id = factor(corpus_id)
  )

critical_surprisal <- token_surprisal %>%
  filter(is_critical) %>%
  select(
    simulation_id, corpus_id, local_sentence_id, global_sentence_id,
    regularity, regularity_label, dependency, condition_id, model_order,
    token_position, token, context, probability, surprisal, is_regular,
    marker, expected_verb_class, actual_verb_class, exposure_block, sentence
  )

# This is the analysis unit used by both the statistical and plotting scripts.
critical_by_corpus_block <- critical_surprisal %>%
  group_by(
    simulation_id, corpus_id, model_order, regularity, regularity_label,
    dependency, condition_id, exposure_block
  ) %>%
  summarise(
    mean_critical_surprisal = mean(surprisal, na.rm = TRUE),
    sd_critical_surprisal = sd(surprisal, na.rm = TRUE),
    n_tokens = n(),
    .groups = "drop"
  )

if (any(critical_by_corpus_block$n_tokens !=
        PROJECT_PARAMS$n_sentences_per_condition / PROJECT_PARAMS$n_exposure_blocks)) {
  stop("Unexpected number of critical tokens in at least one corpus block.")
}

readr::write_csv(token_surprisal, "data/processed/token_surprisal.csv")
readr::write_csv(critical_surprisal, "data/processed/critical_surprisal.csv")
readr::write_csv(
  critical_by_corpus_block,
  "data/processed/critical_by_corpus_block.csv"
)

write_message("Surprisal computation complete.")
write_message("Analysis-ready corpus-block file saved.")
