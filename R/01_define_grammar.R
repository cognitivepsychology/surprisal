############################################################
# 01_define_grammar.R
# Define artificial-language lexicon, grammar, and conditions
############################################################

source("R/00_setup.R")

# Five token categories: N1, N2, FILLER, MARKER, VERB.
lexicon <- tibble::tribble(
  ~token, ~category, ~subclass, ~meaning_note,
  "mab",  "N1",     "agent",   "agent noun 1",
  "tuk",  "N1",     "agent",   "agent noun 2",
  "zep",  "N1",     "agent",   "agent noun 3",
  "lom",  "N1",     "agent",   "agent noun 4",
  "kif",  "N2",     "theme",   "theme noun 1",
  "sol",  "N2",     "theme",   "theme noun 2",
  "nup",  "N2",     "theme",   "theme noun 3",
  "teg",  "N2",     "theme",   "theme noun 4",
  "ven",  "FILLER", "filler",  "intervening token 1",
  "sor",  "FILLER", "filler",  "intervening token 2",
  "dum",  "FILLER", "filler",  "intervening token 3",
  "pal",  "FILLER", "filler",  "intervening token 4",
  "ga",   "MARKER", "A_cue",   "predicts class-A verbs",
  "lu",   "MARKER", "B_cue",   "predicts class-B verbs",
  "dak",  "VERB",   "A",       "class-A verb 1",
  "pil",  "VERB",   "A",       "class-A verb 2",
  "rof",  "VERB",   "B",       "class-B verb 1",
  "nem",  "VERB",   "B",       "class-B verb 2"
)

TOKENS <- list(
  n1 = lexicon %>% filter(category == "N1") %>% pull(token),
  n2 = lexicon %>% filter(category == "N2") %>% pull(token),
  filler = lexicon %>% filter(category == "FILLER") %>% pull(token),
  marker = lexicon %>% filter(category == "MARKER") %>% pull(token),
  verb_A = lexicon %>% filter(category == "VERB", subclass == "A") %>% pull(token),
  verb_B = lexicon %>% filter(category == "VERB", subclass == "B") %>% pull(token)
)

conditions <- tidyr::expand_grid(
  regularity = c(1.00, 0.80, 0.60),
  dependency = c("adjacent", "nonadjacent")
) %>%
  mutate(
    regularity_label = case_when(
      regularity == 1.00 ~ "high_100",
      regularity == 0.80 ~ "mid_80",
      regularity == 0.60 ~ "low_60"
    ),
    dependency = factor(dependency, levels = c("adjacent", "nonadjacent")),
    condition_id = paste(regularity_label, dependency, sep = "__")
  )

marker_mapping <- tibble::tribble(
  ~marker, ~expected_verb_class,
  "ga",    "A",
  "lu",    "B"
)

readr::write_csv(lexicon, "tables/lexicon.csv")
readr::write_csv(conditions, "tables/experimental_conditions.csv")
readr::write_csv(marker_mapping, "tables/marker_mapping.csv")

write_message("Grammar definition complete.")
