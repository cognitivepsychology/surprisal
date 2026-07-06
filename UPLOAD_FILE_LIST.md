# GitHub 업로드 파일 목록

이 문서는 재현 가능성 자료를 GitHub 저장소에 올릴 때 사용할 체크리스트이다.

## 1. 반드시 올릴 파일

### 저장소 안내

- [ ] `README.md`
- [ ] `.gitignore`

### R 스크립트

- [ ] `R/00_setup.R`
- [ ] `R/01_define_grammar.R`
- [ ] `R/02_generate_corpus.R`
- [ ] `R/03_compute_surprisal.R`
- [ ] `R/04_visualize_results.R`
- [ ] `R/05_analyze_results.R`

이 여섯 파일은 번호 순서대로 실행한다.

### 문법 및 설계 자료

- [ ] `tables/lexicon.csv`
- [ ] `tables/marker_mapping.csv`
- [ ] `tables/experimental_conditions.csv`
- [ ] `tables/corpus_validation_by_corpus.csv`
- [ ] `tables/corpus_validation_overall.csv`

### 그림과 그림용 자료

- [ ] `figures/fig1_critical_learning_curve.png`
- [ ] `figures/fig2_final_block_critical_surprisal.png`
- [ ] `tables/figure1_critical_learning_curve_data.csv`
- [ ] `tables/figure2_final_block_critical_surprisal_data.csv`
- [ ] `tables/table_critical_surprisal_final_block_for_manuscript.csv`

### 분석 결과와 진단 자료

- [ ] `tables/model_outputs/analysis_structure_check.csv`
- [ ] `tables/model_outputs/exposure_models_CR2_coefficients.csv`
- [ ] `tables/model_outputs/early_vs_later_drop_by_corpus.csv`
- [ ] `tables/model_outputs/early_vs_later_drop_coefficients.csv`
- [ ] `tables/model_outputs/early_vs_later_drop_overall.csv`
- [ ] `tables/model_outputs/early_vs_later_drop_cells.csv`
- [ ] `tables/model_outputs/final_block_models_coefficients.csv`
- [ ] `tables/model_outputs/final_block_factor_coefficients.csv`
- [ ] `tables/model_outputs/final_block_emmeans.csv`
- [ ] `tables/model_outputs/final_block_pairwise_regularities.csv`
- [ ] `tables/model_outputs/final_block_pairwise_dependencies.csv`
- [ ] `tables/model_outputs/descriptive_final_block_critical.csv`
- [ ] `tables/model_outputs/analysis_diagnostics.txt`

## 2. 선택적으로 올릴 파일

- [ ] 그림의 PDF 또는 SVG 버전
- [ ] 출판 허용 범위를 확인한 뒤 원고의 사전공개본 또는 출판 후 저자 최종본
- [ ] `CITATION.cff`
- [ ] 코드와 자료의 이용 조건을 밝히는 `LICENSE`
- [ ] 패키지 버전을 고정하는 `renv.lock`

## 3. 기본 저장소에서 제외할 파일

다음 파일은 크기가 크고 R 스크립트와 고정된 난수 시드로 다시 만들 수 있으므로 기본 저장소에서는 제외하는 편이 좋다.

- [ ] `data/raw/artificial_corpus.csv`
- [ ] `data/processed/token_surprisal.csv`
- [ ] `data/processed/critical_surprisal.csv`

다음 파일은 비교적 작으므로 필요하면 올릴 수 있지만, 전체 실행으로 다시 생성할 수 있다.

- [ ] `data/processed/critical_by_corpus_block.csv`

## 4. 올리면 안 되는 파일

- [ ] 글꼴 파일
- [ ] 개인 인증정보, 토큰, 비밀번호, `.Renviron`
- [ ] GitHub 접근 토큰이 들어간 스크립트나 로그
- [ ] 논문 투고 시스템의 심사 정보나 개인정보가 포함된 파일
- [ ] 분석에 사용하지 않은 이전 버전의 R 스크립트와 폐기된 탐색 분석 결과

## 5. 업로드 전 최종 점검

- [ ] `RUN_MODE`가 `"final"`인지 확인한다.
- [ ] 난수 시드가 `20260630`인지 확인한다.
- [ ] `05_analyze_results.R`이 혼합효과모형이 아닌 CR2/HC3 수정 분석본인지 확인한다.
- [ ] 그림 1·2의 신뢰구간 단위가 30개 독립 말뭉치 평균인지 확인한다.
- [ ] `analysis_diagnostics.txt`에 R 버전과 패키지 정보가 들어 있는지 확인한다.
- [ ] 저장소를 새 폴더에 내려받아 README의 실행 순서대로 실제 재실행한다.
- [ ] 생성된 핵심 계수, 표, 그림이 원고의 값과 일치하는지 확인한다.
- [ ] 저장소를 공개하기 전에 원고의 저장소 주소가 정확한지 확인한다.
