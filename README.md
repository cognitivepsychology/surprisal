# 확률적 규칙성과 의존성 거리가 온라인 n-그램 모형의 핵심 토큰 서프라이절에 미치는 영향

**Effects of Probabilistic Regularity and Dependency Distance on Critical-Token Surprisal in Online N-Gram Models**

이 저장소는 「확률적 규칙성과 의존성 거리가 온라인 n-그램 모형의 핵심 토큰 서프라이절에 미치는 영향」에 사용된 재현 가능성 자료를 제공한다. 현재 원고는 국내 학술지 『담화와 인지』에 투고할 목적으로 작성되었다.

저장소에는 인공언어 말뭉치 생성, 온라인 n-그램 서프라이절 계산, 통계분석, 그림 작성에 사용한 R 스크립트와 논문에 보고된 주요 표·그림 산출물이 포함되어 있다.

## 연구 설계 요약

- 규칙성: 100%, 80%, 60%
- 의존성 거리: 인접, 비인접
- 실험 조건: 3 × 2 = 6개
- 조건별 독립 말뭉치: 30개
- 말뭉치별 문장 수: 3,000개
- 전체 문장 수: 540,000개
- 언어모형: 2-그램, 3-그램
- 노출 블록: 10개
- 평활화: 가산 평활화, α = 0.1
- 난수 시드: 20260630

주요 종속변수는 각 문장의 핵심 동사 위치에서 계산한 핵심 토큰 서프라이절이다.

## 저장소 구조

```text
surprisal/
├── README.md
├── UPLOAD_FILE_LIST.md
├── .gitignore
├── R/
│   ├── 00_setup.R
│   ├── 01_define_grammar.R
│   ├── 02_generate_corpus.R
│   ├── 03_compute_surprisal.R
│   ├── 04_visualize_results.R
│   └── 05_analyze_results.R
├── data/
│   ├── README.md
│   ├── raw/                  # 실행 중 생성
│   └── processed/            # 실행 중 생성
├── figures/
│   ├── fig1_critical_learning_curve.png
│   └── fig2_final_block_critical_surprisal.png
└── tables/
    ├── lexicon.csv
    ├── marker_mapping.csv
    ├── experimental_conditions.csv
    ├── corpus_validation_by_corpus.csv
    ├── corpus_validation_overall.csv
    ├── figure1_critical_learning_curve_data.csv
    ├── figure2_final_block_critical_surprisal_data.csv
    ├── table_critical_surprisal_final_block_for_manuscript.csv
    └── model_outputs/
        ├── analysis_structure_check.csv
        ├── exposure_models_CR2_coefficients.csv
        ├── early_vs_later_drop_by_corpus.csv
        ├── early_vs_later_drop_coefficients.csv
        ├── early_vs_later_drop_overall.csv
        ├── early_vs_later_drop_cells.csv
        ├── final_block_models_coefficients.csv
        ├── final_block_factor_coefficients.csv
        ├── final_block_emmeans.csv
        ├── final_block_pairwise_regularities.csv
        ├── final_block_pairwise_dependencies.csv
        ├── descriptive_final_block_critical.csv
        └── analysis_diagnostics.txt
```

## R 환경

최종 분석은 다음 환경에서 실행했다.

- R 4.5.1
- Windows 10 x64
- 시간대: Asia/Seoul

주요 R 패키지는 다음과 같다.

- 자료 처리: `tidyverse`, `glue`, `fs`, `janitor`
- 통계분석: `broom`, `emmeans`, `clubSandwich`, `sandwich`
- 시각화: `ggplot2`, `showtext`, `sysfonts`, `systemfonts`, `ragg`

실제 실행 당시의 패키지 버전과 `sessionInfo()`는 `tables/model_outputs/analysis_diagnostics.txt`에 기록되어 있다. 각 스크립트는 필요한 패키지가 설치되어 있지 않으면 설치를 시도한다.

## 실행 전 준비

1. 저장소를 내려받거나 복제한다.
2. R 또는 RStudio에서 저장소의 최상위 폴더를 작업 디렉터리로 설정한다.
3. 그림의 한글 글꼴을 동일하게 재현하려면 운영체제에 **나눔고딕**을 설치한다. 글꼴 파일은 이 저장소에 포함하지 않는다.
4. 충분한 실행 시간과 저장 공간을 확보한다. 토큰 단위 중간 자료는 행 수가 많아 생성과 저장에 시간이 걸릴 수 있다.

## 전체 분석 재현

저장소 최상위 폴더에서 다음 순서로 실행한다.

```r
source("R/00_setup.R")
source("R/01_define_grammar.R")
source("R/02_generate_corpus.R")
source("R/03_compute_surprisal.R")
source("R/04_visualize_results.R")
source("R/05_analyze_results.R")
```

스크립트의 역할은 다음과 같다.

| 스크립트 | 역할 |
|---|---|
| `00_setup.R` | 패키지, 난수 시드, 폴더, 전역 매개변수 설정 |
| `01_define_grammar.R` | 인공언어 어휘, 표지–동사 대응, 실험 조건 정의 |
| `02_generate_corpus.R` | 6개 조건의 독립 말뭉치 생성 및 구성 검증 |
| `03_compute_surprisal.R` | 2-그램·3-그램 온라인 서프라이절 계산 및 블록별 집계 |
| `04_visualize_results.R` | 논문 그림 1·2와 그림용 자료 생성 |
| `05_analyze_results.R` | 가설 중심 회귀분석, 강건 추론, 계획 비교와 진단 자료 생성 |

## 통계분석 개요

### 전체 노출 블록

2-그램과 3-그램을 분리하여 일반 선형회귀모형을 적합했다. 동일한 독립 말뭉치에서 나온 10개 블록의 비독립성을 반영하기 위해 `corpus_id`를 군집 단위로 한 CR2 군집 강건 표준오차와 Satterthwaite 자유도를 사용했다.

### 초기 감소와 이후 감소의 비교

각 말뭉치–모형 조합에서 1–2블록 감소량과 이후 여덟 구간의 평균 감소량을 비교했다. 검정에는 HC3 이분산 강건 표준오차를 사용했고, 조건별 검정은 Holm 방법으로 보정했다.

### 최종 노출 블록

모형 차수별 일반 선형회귀모형과 HC3 이분산 강건 표준오차를 사용했다. 규칙성 조건 간 비교에는 Tukey 보정을 적용했으며, 규칙성 수준별 인접–비인접 차이는 사전에 계획한 비교로 검정했다.

혼합효과모형은 최종 분석에 사용하지 않았다.

## 생성되는 주요 중간 자료

전체 파이프라인을 실행하면 다음 파일이 생성된다.

```text
data/raw/artificial_corpus.csv
data/processed/token_surprisal.csv
data/processed/critical_surprisal.csv
data/processed/critical_by_corpus_block.csv
```

이 가운데 토큰 단위 파일은 크기가 크고 모든 내용이 스크립트와 고정된 난수 시드로 다시 생성되므로 기본 저장소에는 포함하지 않는다. 논문 결과 확인에 필요한 소규모 표, 진단 파일, 최종 그림은 `tables/`와 `figures/`에 포함되어 있다.

## 핵심 산출물

- 그림 1: `figures/fig1_critical_learning_curve.png`
- 그림 2: `figures/fig2_final_block_critical_surprisal.png`
- 전체 블록 회귀계수: `tables/model_outputs/exposure_models_CR2_coefficients.csv`
- 초기 대 후기 감소 검정: `tables/model_outputs/early_vs_later_drop_overall.csv`
- 최종 블록 회귀계수: `tables/model_outputs/final_block_models_coefficients.csv`
- 규칙성 조건 간 비교: `tables/model_outputs/final_block_pairwise_regularities.csv`
- 인접–비인접 비교: `tables/model_outputs/final_block_pairwise_dependencies.csv`
- 최종 블록 기술통계: `tables/model_outputs/descriptive_final_block_critical.csv`
- 분석 구조와 실행 환경: `tables/model_outputs/analysis_diagnostics.txt`

## 그림의 신뢰구간

그림 1의 오차띠와 그림 2의 오차막대는 각 조건의 30개 독립 말뭉치 평균을 기준으로 계산한 95% 신뢰구간이다. 말뭉치 간 변이가 매우 작은 조건에서는 그림 1의 오차띠가 평균선과 거의 완전히 겹쳐 보이지 않을 수 있다.

## 인용

논문이 출판되기 전에는 다음과 같이 인용할 수 있다.

> Lee, Solbin and Eun-Ha Lee. 2026. Effects of probabilistic regularity and dependency distance on critical-token surprisal in online n-gram models. Manuscript submitted to *Discourse and Cognition*.

출판 후에는 최종 권·호·쪽수와 DOI를 반영해 이 항목을 갱신한다.

## 저장소 주소

`https://github.com/cognitivepsychology/surprisal`
