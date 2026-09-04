# 안개 속의 여섯 사람

Defold로 만든 클릭 선택형 미스터리 텍스트 어드벤처. 『Return of the Obra Dinn』과 『The Case of the Golden Idol』식 추리 구조를 따른다: 현장을 조사해 단서를 수첩에 모으고, 다섯 칸짜리 사건 보고서를 채워 제출한다.

> 연락선이 끊긴 밤, 여관에는 여섯 사람이 있었다. 아침에 한 사람이 죽어 있었다.

## 실행

1. Defold 1.13 이상으로 `game.project`를 연다.
2. Build ▸ Build (⌘B).

마우스로 선택지를 클릭한다. Space / Enter는 「계속」과 단일 선택지를 진행한다. 화면 오른쪽 위 「수첩」을 열면 모은 단서가 한 줄씩 목록으로 나오고, 하나를 고르면 삽화와 설명이 있는 상세 화면으로 들어간다. 상세 화면에서 이전·다음 단서로 바로 넘길 수 있고, 수첩에서 보고서를 쓴다. 아직 열어보지 않은 단서는 제목이 세미볼드로 표시되고, 읽지 않은 단서가 남아 있는 동안 헤더의 「수첩」 버튼이 은은하게 점멸한다. 새 단서를 얻으면 화면 중앙에 토스트로 알려준다.

### 웹으로 플레이

https://juninjune.github.io/defold-text-adventure/ 에서 설치 없이 바로 플레이한다. 세로 화면(720×1560) 기준이라 폰 브라우저에 맞고, PC 브라우저에서는 가운데 세로 기둥으로 뜬다. 폰에서는 「홈 화면에 추가」로 앱처럼 쓸 수 있다. 진행 저장은 아직 없다.

HTML5 빌드(Project ▸ Build HTML5)의 결과물을 `gh-pages` 브랜치에 그대로 올리면 배포된다. 자세한 절차는 AGENTS.md의 "HTML5 deploy" 절.

## 비주얼

세로 720×1560 모바일 레이아웃. 장면마다 상단에 1비트 디더링 삽화가 붙는다. 초기 매킨토시 어드벤처(Déjà Vu, Shadowgate)와 『Return of the Obra Dinn』의 흑백 점묘를 따른 스타일로, 이미지 파일은 하나도 없다. `main/art.lua`가 실행 중에 작은 회색조 캔버스에 장면을 그리고 Bayer 8×8 오더드 디더링으로 두 색(잉크·종이)으로 바꾼 뒤 `gui.new_texture`로 올린다. 장소 삽화 14종과 인물 초상 6종(한명희·장길수·백현식·서연우·임지호·강도윤)을 조합해 쓰고, 수첩의 단서 31개는 `main/art_clues.lua`에 각각 전용 삽화(물증은 정물, 증언은 초상 + 소재 스케치)가 있다. 삽화 텍스처 자체는 기존 픽셀 크기 그대로 그려지며, 화면에는 축소된 박스로 표시된다.

## 구조

| 파일 | 역할 |
|---|---|
| `main/story.lua` | 스토리 데이터 전부. 장면·선택지·단서·보고서 정답 |
| `main/game.gui_script` | 엔진. 장면 이동, 페이지 분할, 버튼 레이아웃, 삽화 배너, 수첩, 보고서, 미확인 단서 표시 |
| `main/art.lua` | 절차적 1비트 삽화. 장면 키(`island`, `yard`, `dining+han` …)를 받아 텍스처 바이트를 돌려준다 |
| `main/art_clues.lua` | 단서 31개의 삽화. 단서 id를 키로 한 그리기 함수 표 |
| `main/game.gui` | 폰트 선언만(`korean`, `korean_sb`). 노드는 전부 코드로 생성 |
| `main/korean.font` | Pretendard Regular 36px 비트맵 폰트 (완성형 한글 2,350자 + 기호) |
| `main/korean_sb.font` | 같은 문자셋의 Pretendard SemiBold 36px 폰트. 미확인 단서 제목에 쓰인다 |
| `AGENTS.md` | 에이전트용 작업 지침 (빌드·검증 방법, 구조, 함정) |

이 프로젝트는 Defold 에디터의 HTTP API(`/command/build`, `/console`, `/ref`, `/eval`)를 통해 AI 코딩 에이전트가 빌드하고 검증하는 워크플로우를 시험하기 위해 만들어졌다. 자세한 절차는 `AGENTS.md` 참고.

## 스토리를 고치려면

`main/story.lua`만 수정하면 된다. 장면은 `S.scenes.<id> = { art, title, text, choices, on_enter }` 형태이고, 문단은 빈 줄로 나눈다. `art`는 삽화 키로, 장소 키에 `+인물` 을 붙이면 초상이 겹쳐진다(예: `"pier+seo"`). 새 장소가 필요하면 `main/art.lua`의 `S` 테이블에 그리기 함수를 추가한다. 단서는 `S.clues`에 등록하고 `st:add_clue("id")`로 준다. 허브로 돌아가거나 대화를 끝내는 등 '뒤로' 성격의 선택지에는 `back = true`를 붙이면 테두리·라벨이 옅어진 고스트 버튼으로 표시된다(`next = "@back"`이면 자동 적용). 디버그 빌드에서는 시작 시 스토리 그래프와 삽화 키를 검사해 콘솔에 `STORY_OK`를 출력한다. 특정 장면을 바로 열어 보려면 `game.project`의 `[adv] start = <scene id>`를 채우고 빌드한다(디버그 빌드 전용, 비워 두면 타이틀부터). `all_clues = 1`을 함께 주면 단서 31개가 전부 채워진 상태로 시작하므로 `start = @notebook`과 묶어 수첩 화면을 점검할 수 있다. 새 단서를 추가하면 `main/art_clues.lua`에 같은 id의 삽화 함수도 넣어야 한다(없으면 시작 시 `STORY_ERR`).
