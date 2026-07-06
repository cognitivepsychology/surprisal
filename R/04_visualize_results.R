############################################################
# 04_visualize_results.R
# Hypothesis-focused figures with corpus-level uncertainty
############################################################

source("R/00_setup.R")

plot_pkgs <- c("showtext", "sysfonts", "systemfonts", "ragg")
missing_plot_pkgs <- plot_pkgs[!plot_pkgs %in% rownames(installed.packages())]
if (length(missing_plot_pkgs) > 0) install.packages(missing_plot_pkgs)
invisible(lapply(plot_pkgs, library, character.only = TRUE))

set_korean_font <- function() {
  font_tbl <- systemfonts::system_fonts()
  nanum_families <- c(
    "NanumGothic",
    "Nanum Gothic",
    "나눔고딕",
    "NanumGothicOTF",
    "Nanum Gothic OTF"
  )

  nanum_fonts <- font_tbl %>%
    filter(family %in% nanum_families)

  if (nrow(nanum_fonts) == 0) {
    stop(
      "나눔고딕 글꼴을 찾을 수 없습니다. ",
      "운영체제에 나눔고딕을 설치한 뒤 04_visualize_results.R을 다시 실행하세요."
    )
  }

  regular_font <- nanum_fonts %>%
    filter(
      stringr::str_detect(
        style,
        stringr::regex("Regular|Normal|보통", ignore_case = TRUE)
      ) |
        is.na(style) |
        style == ""
    ) %>%
    slice_head(n = 1)

  if (nrow(regular_font) == 0) {
    regular_font <- nanum_fonts %>% slice_head(n = 1)
  }

  bold_font <- nanum_fonts %>%
    filter(
      stringr::str_detect(
        style,
        stringr::regex("Bold|ExtraBold|SemiBold|굵게", ignore_case = TRUE)
      )
    ) %>%
    slice_head(n = 1)

  if (nrow(bold_font) > 0) {
    sysfonts::font_add(
      family = "nanumgothic",
      regular = regular_font$path[[1]],
      bold = bold_font$path[[1]]
    )
  } else {
    sysfonts::font_add(
      family = "nanumgothic",
      regular = regular_font$path[[1]]
    )
  }

  showtext::showtext_auto()
  showtext::showtext_opts(dpi = 300)

  write_message("Figure font selected: NanumGothic")
  write_message("Regular font path: {regular_font$path[[1]]}")
  if (nrow(bold_font) > 0) {
    write_message("Bold font path: {bold_font$path[[1]]}")
  }

  "nanumgothic"
}

BASE_FAMILY <- set_korean_font()
input_path <- "data/processed/critical_by_corpus_block.csv"
if (!file.exists(input_path)) stop("Run R/03_compute_surprisal.R first.")

critical_by_corpus_block <- readr::read_csv(input_path, show_col_types = FALSE) %>%
  mutate(
    regularity_label = factor(
      regularity_label,
      levels = c("high_100", "mid_80", "low_60"),
      labels = c("100% 규칙", "80% 규칙", "60% 규칙")
    ),
    dependency = factor(
      dependency,
      levels = c("adjacent", "nonadjacent"),
      labels = c("인접", "비인접")
    ),
    model_order = factor(
      model_order,
      levels = c("2-gram", "3-gram"),
      labels = c("2-그램", "3-그램")
    ),
    exposure_block = as.integer(exposure_block)
  )

summarise_corpus_ci <- function(data, outcome, conf_level = PROJECT_PARAMS$confidence_level) {
  data %>%
    summarise(
      mean = mean({{ outcome }}, na.rm = TRUE),
      sd = sd({{ outcome }}, na.rm = TRUE),
      n_corpora = dplyr::n(),
      se = sd / sqrt(n_corpora),
      critical_t = qt((1 + conf_level) / 2, df = n_corpora - 1),
      ci95 = critical_t * se,
      .groups = "drop"
    )
}

save_plot <- function(plot, filename, width, height, dpi = 300) {
  showtext::showtext_opts(dpi = dpi)
  ggsave(
    file.path("figures", paste0(filename, ".png")), plot,
    width = width, height = height, units = "in", dpi = dpi,
    device = ragg::agg_png, bg = "white"
  )
  ggsave(
    file.path("figures", paste0(filename, ".pdf")), plot,
    width = width, height = height, units = "in",
    device = grDevices::cairo_pdf, bg = "white"
  )
}

theme_paper <- function(base_size = 18) {
  theme_bw(base_size = base_size, base_family = BASE_FAMILY) +
    theme(
      panel.grid.minor = element_blank(),
      strip.background = element_rect(fill = "grey90", color = "grey40"),
      strip.text = element_text(face = "bold"),
      legend.position = "bottom",
      legend.title = element_text(face = "bold"),
      plot.title = element_text(face = "bold", hjust = 0),
      axis.title = element_text(face = "bold")
    )
}

# Figure 1: first calculate one mean per independently generated corpus and block;
# then calculate uncertainty across the 30 corpus replications.
critical_curve <- critical_by_corpus_block %>%
  group_by(model_order, regularity_label, dependency, exposure_block) %>%
  summarise_corpus_ci(mean_critical_surprisal)

if (any(critical_curve$n_corpora != PROJECT_PARAMS$n_simulations)) {
  stop("Figure 1 uncertainty was not based on the expected number of corpora.")
}

readr::write_csv(critical_curve, "tables/figure1_critical_learning_curve_data.csv")

fig1 <- ggplot(
  critical_curve,
  aes(
    x = exposure_block,
    y = mean,
    group = regularity_label,
    linetype = regularity_label,
    shape = regularity_label
  )
) +
  geom_ribbon(
    aes(ymin = mean - ci95, ymax = mean + ci95, fill = regularity_label),
    alpha = 0.12, color = NA
  ) +
  geom_line(linewidth = 0.8) +
  geom_point(size = 2) +
  facet_grid(dependency ~ model_order) +
  scale_x_continuous(breaks = 1:PROJECT_PARAMS$n_exposure_blocks) +
  labs(
    title = "노출 블록에 따른 핵심 토큰 서프라이절 변화",
    subtitle = "오차띠: 30개 독립 말뭉치 평균의 95% 신뢰구간.",
    x = "노출 블록",
    y = "평균 핵심 토큰 서프라이절",
    linetype = "규칙성", shape = "규칙성", fill = "규칙성"
  ) +
  theme_paper()

save_plot(fig1, "fig1_critical_learning_curve", 9.5, 7)

# Figure 2: final block, again using corpus means as the uncertainty unit.
final_block <- max(critical_by_corpus_block$exposure_block, na.rm = TRUE)
critical_final <- critical_by_corpus_block %>%
  filter(exposure_block == final_block) %>%
  group_by(model_order, regularity_label, dependency) %>%
  summarise_corpus_ci(mean_critical_surprisal)

if (any(critical_final$n_corpora != PROJECT_PARAMS$n_simulations)) {
  stop("Figure 2 uncertainty was not based on the expected number of corpora.")
}

readr::write_csv(
  critical_final,
  "tables/figure2_final_block_critical_surprisal_data.csv"
)
readr::write_csv(
  critical_final %>%
    mutate(across(c(mean, sd, se, ci95), ~ round(.x, 3))),
  "tables/table_critical_surprisal_final_block_for_manuscript.csv"
)

fig2 <- ggplot(
  critical_final,
  aes(x = regularity_label, y = mean, fill = dependency)
) +
  geom_col(position = position_dodge(width = 0.75), width = 0.65, color = "grey25") +
  geom_errorbar(
    aes(ymin = mean - ci95, ymax = mean + ci95),
    position = position_dodge(width = 0.75), width = 0.10, linewidth = 0.5
  ) +
  facet_wrap(~ model_order) +
  labs(
    title = "최종 노출 블록의 조건별 핵심 토큰 서프라이절",
    subtitle = "오차막대: 30개 독립 말뭉치 평균의 95% 신뢰구간.",
    x = "규칙성 조건",
    y = "평균 핵심 토큰 서프라이절",
    fill = "의존성"
  ) +
  theme_paper() +
  theme(axis.text.x = element_text(angle = 20, hjust = 1))

save_plot(fig2, "fig2_final_block_critical_surprisal", 9.5, 6.2)

write_message("Hypothesis-focused visualization complete.")
