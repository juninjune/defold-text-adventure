-- 안개 속의 여섯 사람 -- story data.
-- Consumed by main/game.gui_script. See the engine for the state API:
--   state:add_clue(id) -> bool, state:has(id), state:set(flag, v), state:get(flag)
--   state.visited[scene_id] (visit count), state.attempts (report submissions)
-- choice.next: scene id | "@back" | "@notebook" | "@restart" | function(state) -> id

local S = {}

S.title = "안개 속의 여섯 사람"
S.start = "title"

-- helpers for conditions --------------------------------------------------

local function has(id) return function(st) return st:has(id) end end
local function lacks(id) return function(st) return not st:has(id) end end
local function flag(name) return function(st) return st:get(name) end end
local function noflag(name) return function(st) return not st:get(name) end end
local function all(...)
	local fs = { ... }
	return function(st)
		for _, f in ipairs(fs) do if not f(st) then return false end end
		return true
	end
end
local function any(...)
	local fs = { ... }
	return function(st)
		for _, f in ipairs(fs) do if f(st) then return true end end
		return false
	end
end
local function clue(id) return function(st) st:add_clue(id) end end
local function clues(...)
	local ids = { ... }
	return function(st) for _, id in ipairs(ids) do st:add_clue(id) end end
end

-- clues (notebook entries) --------------------------------------------------

S.clues = {
	body = { title = "시신의 상태", text = "윤재석. 등대 나선계단 맨 아래. 목이 꺾이고 뒤통수가 깨졌다. 술 냄새가 난다. 코트 단추는 하나도 빠지지 않았다." },
	brass_button = { title = "오른손의 놋쇠 단추", text = "시신의 오른손에 놋쇠 단추 하나가 꽉 쥐어져 있었다. 닻과 별 문양. 동방해운 제복 단추다. 실이 뜯겨 나온 채였다." },
	footprints = { title = "계단의 발자국", text = "철계단 위쪽에 마른 진흙 발자국 두 사람분. 하나는 큰 구두, 하나는 작은 구두. 장화 자국은 없다." },
	empty_chest = { title = "램프실의 빈 궤짝", text = "램프실 구석의 궤짝이 뚜껑이 열린 채 비어 있었다. 먼지 위에 누군가 손으로 헤집은 자국." },
	shoes_lim = { title = "임지호의 구두", text = "신발장 속 임지호의 구두. 젖은 헝겊으로 급히 닦았지만 밑창 홈에 진흙이 남아 있다. 치수가 작다." },
	boots_dry = { title = "장길수의 장화", text = "장길수의 장화는 바싹 말라 있다. 어젯밤 밖에 나간 적이 없다." },
	shoes_doyun = { title = "강도윤의 장화", text = "강도윤은 장화를 신는다. 등대 안 발자국은 장화가 아니었다." },
	key_mud = { title = "등대 열쇠", text = "현관 걸이의 등대 열쇠. 열쇠와 걸이 못에 마르지 않은 진흙이 묻어 있다. 밤사이 누군가 열쇠를 가져갔다가 도로 걸었다." },
	register = { title = "숙박부", text = "1호 윤재석(동방해운 화물감독관), 2호 서연우(사진사), 3호 백현식(장기 투숙, 3년째), 4호 임지호(동방해운 서기). 서연우는 사흘 전, 윤재석과 임지호는 어제 도착." },
	memorial = { title = "백조호 희생자 명단", text = "3년 전 백조호 침몰로 죽은 선원 넷. 갑판장 강동수, 선원 김태오, 박무열, 이정구. 강동수는 여관 주인 한명희의 남편이다." },
	doors3 = { title = "현관문 소리 세 번", text = "한명희의 말. 자정 무렵 현관문이 열리는 소리가 두 번 잇달아 났고, 얼마 뒤 한 번 더 났다. 둘이 나가고 하나만 돌아왔다." },
	alibi_jang = { title = "장길수의 알리바이", text = "한명희가 새벽 한 시에 식당에서 곯아떨어진 장길수에게 이불을 덮어 주었다. 장길수는 밤새 식당을 떠나지 않았다." },
	sewing_kit = { title = "새벽의 반짇고리", text = "동틀 무렵 임지호가 한명희에게 반짇고리를 빌려 갔다. 단추가 떨어졌다고 했다." },
	telegram = { title = "윤재석의 전보", text = "「기자 서 무영도로 향함. 백에게서 일지 반드시 회수할 것. 입 다물게 하라. 사장」 윤재석은 조사하러 온 것이 아니라 없애러 왔다." },
	whisky = { title = "빈 위스키 병", text = "윤재석의 방에 반쯤 빈 위스키 병. 잔은 하나. 술은 혼자 마셨다." },
	roster = { title = "출장 명령서", text = "「화물감독관 윤재석, 서기 임지호 동행. 백조호 관련 서류 회수.」 임지호는 입사 여섯 달째. 이전 이력 없음." },
	shorthand = { title = "속기 노트", text = "서연우의 방에서 나온 노트. 사진사가 쓸 법한 것이 아니다. 빽빽한 속기 부호. 어젯밤 날짜 아래 「3호」 「등대」 「궤짝」이라는 글자만 읽을 수 있다." },
	press_id = { title = "기자증", text = "서연우의 외투 안주머니에서 나온 경성일보 기자증. 사진사라는 말은 거짓이다." },
	letter_draft = { title = "백현식의 편지 초안", text = "「나는 더 이상 침묵하지 않겠다. 일지는 믿을 수 있는 사람에게 넘겼다. 강 갑판장, 김군, 박군, 이군에게 이 늙은이가 할 수 있는 것은 이것뿐이다.」 날짜는 그저께." },
	meds = { title = "백현식의 약", text = "머리맡의 심장약과 지팡이. 백현식은 등대 계단을 오를 수 있는 몸이 아니다." },
	coat_button = { title = "임지호의 코트", text = "동방해운 제복 코트. 셋째 단추만 색이 다르고 실이 새것이다. 밤사이 단추를 새로 달았다." },
	photo = { title = "두 소년의 사진", text = "임지호의 가방 속 낡은 사진. 등대 앞에 선 두 소년. 뒷면에 「태오, 지호. 무영도.」" },
	resemblance = { title = "김씨네 둘째", text = "한명희의 말. 임 서기의 얼굴이 옛날 섬에 살던 김씨네 둘째 아이와 닮았다. 김씨네 형제는 부모를 잃고 육지의 친척집으로 갔는데, 형 태오는 나중에 백조호를 탔다." },
	overheard = { title = "벽 너머의 대화", text = "서연우의 말. 어젯밤 아홉 시, 옆방에서 윤재석이 백현식을 협박했다. 백현식은 일지가 등대 램프실 궤짝에 있다고 했고, 윤재석은 나중에 가져오겠다며 나갔다." },
	logbook = { title = "백조호의 진짜 항해일지", text = "마지막 항해. 「화물칸 비어 있음. 선주 지시로 침로 변경, 검은여 암초로.」 백조호는 빈 배였고, 일부러 가라앉혔다. 보험 사기다." },
	baek_confession = { title = "백현식의 고백", text = "동방해운 사장의 돈을 받고 빈 배를 좌초시켰다. 선원은 전원 구조될 계획이었으나 밤 폭풍이 심해져 넷이 죽었다. 윤재석은 화물을 빼돌린 실행자였다." },
	lie_chest = { title = "궤짝의 거짓말", text = "백현식의 말. 일지는 이미 서연우에게 넘겼다. 윤재석에게는 시간을 벌려고 등대 궤짝에 있다고 둘러댔다. 윤재석은 그 말을 믿고 등대로 갔다." },
	timeline_doyun = { title = "등대 문과 열쇠", text = "강도윤의 말. 밤 열 시에 등대 문을 잠그고 열쇠를 현관 걸이에 건다. 새벽 다섯 시 반, 문이 열려 있는 것을 보고 들어갔다가 시신을 발견했다." },
	lim_identity = { title = "임지호의 정체", text = "임지호는 김지호다. 백조호에서 죽은 김태오의 동생. 육지의 임씨 집안 양자로 들어가 성이 바뀌었다. 형의 죽음을 캐려고 동방해운에 들어갔다." },
	lim_silence = { title = "임지호의 침묵", text = "단추 이야기를 꺼내자 임지호는 얼굴이 하얗게 질린 채 「경찰이 오면 말하겠습니다」라고만 했다." },
	jang_lim = { title = "떨리는 손", text = "장길수의 말. 어젯밤 저녁 식사 때 임 서기는 술을 한 방울도 안 마셨는데 숟가락 든 손이 덜덜 떨렸다." },
}

S.notebook_choices = {
	{ label = "사건 보고서를 쓴다", next = "report", cond = flag("can_report") },
}

-- scenes --------------------------------------------------------------------

S.scenes = {}

S.scenes.title = {
	art = "island",
	style = "title",
	title = "",
	text = [[안개 속의 여섯 사람

무영도 · 해무장 여관 · 등대

연락선이 끊긴 밤, 여관에는 여섯 사람이 있었다.
아침에 한 사람이 죽어 있었다.]],
	choices = {
		{ label = "시작한다", next = "intro1" },
	},
}

S.scenes.intro1 = {
	art = "ferry",
	title = "연락선 · 아침",
	text = [[안개가 걷히지 않는다. 뱃머리에서 다섯 걸음 앞도 보이지 않는다.

북성해상보험 조사부. 사흘 전 회사로 편지 한 통이 왔다. 발신인 없음. 「백조호는 빈 배였다. 무영도의 백 선장이 알고 있다.」

백조호. 3년 전 폭풍 속에서 검은여 암초에 걸려 가라앉은 동방해운의 화물선. 선원 넷이 죽었고, 회사는 화물 값으로 거액의 보험금을 받았다. 그 돈을 지급한 것이 우리 회사다.

재조사 명목으로 무영도행 연락선을 탔다. 어젯밤 안개로 결항된 배가 오늘 아침 첫 배다.

무영도. 그림자 없는 섬. 안개가 해를 삼켜 섬에는 그림자가 서지 않는다고, 뱃사람들이 그렇게 부른다.

기적이 울린다. 안개 속에서 등대가 먼저 나타난다. 불은 꺼져 있다.]],
	choices = {
		{ label = "배에서 내린다", next = "intro2" },
	},
}

S.scenes.intro2 = {
	art = "pier+doyun",
	title = "무영도 · 선착장",
	text = [[선착장에 젊은 남자가 서 있다. 장화에 기름때 묻은 작업복. 등대지기 보조라고 한다. 이름은 강도윤.

「여관 손님이십니까. 죄송하지만… 지금 여관에 시신이 있습니다.」

새벽에 등대 안에서 사람이 죽어 있는 것을 발견했다고 한다. 어젯밤 여관에 든 손님 중 하나. 동방해운의 화물감독관, 윤재석.

「경찰은 오후 배로 옵니다. 그때까지 아무도 섬을 못 나갑니다.」

동방해운. 윤재석. 그 이름은 백조호 사건 서류에서 본 적이 있다. 화물 선적을 감독한 책임자였다.]],
	choices = {
		{ label = "여관으로 간다", next = "intro3" },
	},
}

S.scenes.intro3 = {
	art = "hall+han",
	title = "해무장 여관 · 현관",
	text = [[해무장. 섬 유일의 여관. 등대 바로 아래 비탈에 서 있다. 나무 현관문을 밀자 종이 울린다.

여관 주인 한명희가 나온다. 쉰 남짓. 얼굴이 밤새 잠을 못 잔 사람의 얼굴이다.

「보험회사에서 오셨다고요. 경찰이 오려면 여섯 시간은 남았습니다. 그동안… 봐 주실 수 있겠습니까. 모두 사고라고 합니다만, 저는 모르겠습니다.」

여관에 남은 사람은 다섯이다. 주인 한명희와 아들 강도윤. 투숙객인 사진사 서연우, 은퇴한 선장 백현식, 죽은 윤재석의 부하 임지호. 그리고 식당에서 밤을 새운 어부 장길수.

경찰선이 오기 전에 이 섬에서 무슨 일이 있었는지 알아내야 한다.]],
	on_enter = clue("register"),
	choices = {
		{ label = "조사를 시작한다", next = "yard" },
	},
}

S.scenes.yard = {
	art = "yard",
	title = "해무장 · 마당",
	text = function(st)
		if st.visited.yard == 1 then
			return [[여관 마당. 안개가 무릎께까지 깔려 있다. 왼쪽 비탈 위로 등대가, 오른쪽 아래로 선착장이 흐릿하게 보인다.

여관은 2층. 1층에 현관과 식당, 2층에 객실 넷.

어디부터 볼 것인가.]]
		end
		if st:get("can_report") then
			return [[여관 마당. 안개는 조금씩 옅어지고 있다. 오후 배가 오기 전에 정리해 두어야 한다.

수첩은 화면 오른쪽 위에 있다.]]
		end
		return [[여관 마당. 안개 너머로 등대와 선착장이 있다. 여관은 현관, 식당, 2층 객실.]]
	end,
	choices = {
		{ label = "현관", next = "hall" },
		{ label = "식당", next = "dining" },
		{ label = "2층 객실", next = "corridor" },
		{ label = "등대", next = "lighthouse" },
		{ label = "선착장", next = "pier" },
	},
}

-- hall ----------------------------------------------------------------------

S.scenes.hall = {
	art = "hall",
	title = "해무장 · 현관",
	text = [[좁은 현관. 벽에 열쇠 걸이와 낡은 괘종시계. 신발장에는 신발이 줄지어 있다. 계산대 위에 숙박부가 펼쳐져 있다.]],
	choices = {
		{ label = "신발장을 살핀다", next = "hall_shoes" },
		{ label = "열쇠 걸이를 본다", next = "hall_key" },
		{ label = "숙박부를 읽는다", next = "hall_register" },
		{ label = "마당으로", next = "yard", back = true },
	},
}

S.scenes.hall_shoes = {
	art = "hall",
	title = "현관 · 신발장",
	text = [[신발 여섯 켤레.

윤재석의 구두는 없다. 시신이 신고 있을 것이다.

임지호의 구두. 검은 가죽 구두, 치수가 작다. 누군가 젖은 헝겊으로 닦았지만 밑창 홈에 진흙이 그대로 박혀 있다. 안창이 아직 축축하다.

장길수의 장화. 바싹 말라 있다. 갈라진 고무에 마른 소금기가 하얗다.

강도윤의 장화는 없다. 지금 신고 있을 것이다. 한명희의 고무신. 서연우의 여자 부츠, 굽에 모래. 백현식의 헝겊신 한 켤레, 옆에 지팡이 자국이 난 바닥.]],
	on_enter = clues("shoes_lim", "boots_dry"),
	choices = {
		{ label = "현관으로", next = "hall", back = true },
	},
}

S.scenes.hall_key = {
	art = "hall",
	title = "현관 · 열쇠 걸이",
	text = [[못 다섯 개. 객실 열쇠 넷과, 맨 끝에 「등대」라고 나무패가 달린 큰 열쇠.

등대 열쇠에 진흙이 묻어 있다. 못에도 묻어 있다. 아직 마르지 않았다. 밤사이 누군가 진흙 묻은 손으로 이 열쇠를 가져갔다가 도로 걸었다.]],
	on_enter = clue("key_mud"),
	choices = {
		{ label = "현관으로", next = "hall", back = true },
	},
}

S.scenes.hall_register = {
	art = "hall",
	title = "현관 · 숙박부",
	text = [[숙박부.

1호 윤재석, 동방해운 화물감독관. 어제 도착.
2호 서연우, 사진사. 사흘 전 도착.
3호 백현식, 직업란 공란. 3년째 장기 투숙.
4호 임지호, 동방해운 서기. 어제 도착.

3년째. 백조호가 가라앉은 것이 3년 전이다. 백현식이라는 이름은 백조호의 선장 이름과 같다.]],
	on_enter = clue("register"),
	choices = {
		{ label = "현관으로", next = "hall", back = true },
	},
}

-- dining --------------------------------------------------------------------

S.scenes.dining = {
	art = "dining",
	title = "해무장 · 식당",
	text = function(st)
		if st.visited.dining == 1 then
			return [[탁자 네 개짜리 식당. 난로 옆 긴 의자에 어부 장길수가 이불을 감고 앉아 있다. 술이 덜 깬 얼굴이다. 한명희는 부엌에서 나오다 말고 선 채로 이쪽을 본다.

벽에 액자 하나가 걸려 있다.]]
		end
		return [[식당. 장길수는 여전히 난로 옆이고, 한명희는 부엌 문가에 있다.]]
	end,
	choices = {
		{ label = "장길수와 이야기한다", next = "talk_jang" },
		{ label = "한명희와 이야기한다", next = "talk_han" },
		{ label = "벽의 액자를 본다", next = "dining_frame" },
		{ label = "마당으로", next = "yard", back = true },
	},
}

S.scenes.dining_frame = {
	art = "dining",
	title = "식당 · 벽의 액자",
	text = [[신문 조각을 오려 넣은 액자. 「동방해운 백조호, 검은여 해역에서 침몰. 선원 4명 실종.」

그 아래 손으로 쓴 명단.

갑판장 강동수.
선원 김태오.
선원 박무열.
선원 이정구.

강동수. 여관 주인 한명희의 성은 한씨지만, 아들은 강도윤이다.]],
	on_enter = clue("memorial"),
	choices = {
		{ label = "식당으로", next = "dining", back = true },
	},
}

S.scenes.talk_jang = {
	art = "dining+jang",
	title = "식당 · 장길수",
	text = function(st)
		if st.visited.talk_jang == 1 then
			return [[장길수. 쉰 넘은 어부. 얼굴이 벌겋고 손등이 갈라져 있다.

「보험쟁이라고? 흥. 그 작자 죽은 건 나하고 상관없어. 술 처먹고 굴러떨어진 거지.」]]
		end
		return [[장길수가 이불을 고쳐 여민다. 「또 뭐요.」]]
	end,
	choices = {
		{ label = "어젯밤 윤재석과의 다툼", next = "jang_fight" },
		{ label = "어젯밤 어디 있었나", next = "jang_night" },
		{ label = "3년 전 백조호", next = "jang_past" },
		{ label = "임지호에 대해", next = "jang_lim" },
		{ label = "식당으로", next = "dining", back = true },
	},
}

S.scenes.jang_fight = {
	art = "dining+jang",
	title = "식당 · 장길수",
	text = [[「다툼? 그래, 다퉜지. 저녁 먹는데 그 작자가 술김에 지껄이더군. 섬 것들이 가라앉은 배에서 물건 건져다 팔아먹는다고. 백조호 얘기야.」

「내가 뭐라고 했냐고? 한 번만 더 지껄이면 바다에 처넣어 버린다고 했지. 그게 다야. 그러고 나서 술 더 마시고 잤어.」

「당신 같으면 안 그러겠어? 그 배에서 죽은 사람들 중에 이 집 주인 남편이 있어.」]],
	choices = {
		{ label = "다른 것을 묻는다", next = "@back" },
	},
}

S.scenes.jang_night = {
	art = "dining+jang",
	title = "식당 · 장길수",
	text = [[「여기. 이 의자. 아홉 시쯤엔 이미 곯아떨어졌을걸. 눈 떠 보니 새벽이고, 도윤이가 뛰어 들어와서 사람이 죽었다고 하더군.」

「밖에 나갔냐고? 안개 낀 밤에 술 취해서 어딜 나가. 장화 보면 알 거 아냐, 바싹 말랐을 테니.」]],
	choices = {
		{ label = "다른 것을 묻는다", next = "@back" },
	},
}

S.scenes.jang_past = {
	art = "dining+jang",
	title = "식당 · 장길수",
	text = [[「백조호. 그날 밤도 이런 안개에 폭풍이었어. 검은여에 걸렸다고 했지. 근데 이상한 게, 그 배는 이 항로로 다닐 배가 아니야. 검은여 쪽으로는 아무도 안 가.」

「백 선장? 그 사람 그 후로 배 안 타. 여기 와서 3년째 방구석에 앉아 바다만 봐. 죄지은 사람 얼굴이지.」

「죽은 사람들? 강 갑판장은 이 집 주인 남편이고. 김태오는… 옛날에 이 섬에 김씨네가 살았어. 애 둘 데리고. 아비가 바다에서 죽고 어미도 곧 죽어서, 애들은 육지 친척집으로 갔지. 그 큰애가 나중에 뱃사람 돼서 백조호를 탄 거야. 동생은 어찌 됐는지 몰라.」]],
	on_enter = function(st) st:set("heard_kim", true) end,
	choices = {
		{ label = "다른 것을 묻는다", next = "@back" },
	},
}

S.scenes.jang_lim = {
	art = "dining+jang",
	title = "식당 · 장길수",
	text = [[「그 젊은 서기? 하얗고 말수 없는 놈. 제 상관이 그렇게 떠들어 대는데 한마디도 안 하더군.」

「근데 말이야. 술은 한 방울도 안 마시면서, 숟가락 든 손이 덜덜 떨리더라고. 추워서 그런 줄 알았는데.」]],
	on_enter = clue("jang_lim"),
	choices = {
		{ label = "다른 것을 묻는다", next = "@back" },
	},
}

S.scenes.talk_han = {
	art = "dining+han",
	title = "식당 · 한명희",
	text = function(st)
		if st.visited.talk_han == 1 then
			return [[한명희가 앞치마에 손을 닦는다.

「무엇이든 물어보세요. 저는 밤새 잠을 못 잤으니 들은 건 다 기억합니다.」]]
		end
		return [[한명희. 「네, 말씀하세요.」]]
	end,
	choices = {
		{ label = "어젯밤 들은 소리", next = "han_doors" },
		{ label = "장길수는 밤새 식당에 있었나", next = "han_jang" },
		{ label = "남편에 대해", next = "han_husband" },
		{ label = "반짇고리에 대해", next = "han_sewing", cond = has("coat_button") },
		{ label = "김씨네 형제에 대해", next = "han_kim", cond = any(has("photo"), flag("heard_kim")) },
		{ label = "식당으로", next = "dining", back = true },
	},
}

S.scenes.han_doors = {
	art = "dining+han",
	title = "식당 · 한명희",
	text = [[「저희 방은 현관 바로 뒤예요. 현관문 종소리는 다 들립니다.」

「자정 조금 전이었을 거예요. 종이 울렸어요. 그리고 얼마 안 있어 또 한 번. 둘이 따로 나간 거죠. 그러고 한참 있다가… 한 시 다 돼서, 한 번 더. 하나만 들어왔어요.」

「누군지는 못 봤어요. 일어나 볼 걸 그랬습니다.」]],
	on_enter = clue("doors3"),
	choices = {
		{ label = "다른 것을 묻는다", next = "@back" },
	},
}

S.scenes.han_jang = {
	art = "dining+han",
	title = "식당 · 한명희",
	text = [[「길수 씨요? 한 시쯤 물 마시러 나왔다가 봤어요. 저 의자에서 코를 골고 있길래 이불을 덮어 줬습니다. 그 사람은 밤새 저기 있었어요.」]],
	on_enter = clue("alibi_jang"),
	choices = {
		{ label = "다른 것을 묻는다", next = "@back" },
	},
}

S.scenes.han_husband = {
	art = "dining+han",
	title = "식당 · 한명희",
	text = [[한명희가 잠시 벽의 액자를 본다.

「강동수. 백조호 갑판장이었어요. 그 배를 타지 말라고 했는데, 회사에서 급히 불렀다고 했어요. 원래 그 항로 배가 아니었는데.」

「백 선장님이 3년 전에 여기 오셨을 때, 저는 문을 안 열어 드리려고 했어요. 그런데 그분이 마당에 하루 종일 서 계셨어요. 그 뒤로 방값을 한 번도 안 밀리셨죠. 미워할 수도 없고.」

「어제 윤이라는 사람이 그 배 얘기를 하면서 웃는 걸 보고… 저는 아무 말도 못 했습니다.」]],
	choices = {
		{ label = "다른 것을 묻는다", next = "@back" },
	},
}

S.scenes.han_sewing = {
	art = "dining+han",
	title = "식당 · 한명희",
	text = [[「반짇고리요? 아, 네. 동틀 무렵에 임 서기님이 부엌으로 와서 빌려 가셨어요. 코트 단추가 떨어졌다고. 검은 실을 달라고 하셨는데 없어서 남색 실을 드렸습니다.」

「그때는 아직 시신이 발견되기 전이었어요.」]],
	on_enter = clue("sewing_kit"),
	choices = {
		{ label = "다른 것을 묻는다", next = "@back" },
	},
}

S.scenes.han_kim = {
	art = "dining+han",
	title = "식당 · 한명희",
	text = [[「김씨네요. 등대 뒤에 살던 집이에요. 태오하고 지호. 태오가 열 살, 지호가 일곱 살쯤에 부모를 다 잃었어요. 육지의 임씨 집안, 어머니 쪽 친척이 데려갔죠.」

「태오는 뱃사람이 돼서… 백조호를 탔어요. 지호는 소식을 몰라요.」

한명희가 말을 멈춘다.

「어제부터 자꾸 마음에 걸린 게 있어요. 그 임 서기님 얼굴이요. 처음 보는 얼굴인데 어디서 본 것 같아서. 이제 알겠어요. 지호예요. 김씨네 둘째. 눈이 그 어머니를 닮았어요.」]],
	on_enter = clue("resemblance"),
	choices = {
		{ label = "다른 것을 묻는다", next = "@back" },
	},
}

-- corridor & rooms -----------------------------------------------------------

S.scenes.corridor = {
	art = "corridor",
	title = "해무장 · 2층 복도",
	text = [[삐걱거리는 복도. 문 넷이 나란히 있다.

1호 윤재석. 2호 서연우. 3호 백현식. 4호 임지호.

3호 문 아래로 불빛이 새어 나온다. 나머지 방은 조용하다.]],
	choices = {
		{ label = "1호 · 윤재석의 방", next = "room1" },
		{ label = "2호 · 서연우의 방", next = "room2" },
		{ label = "3호 · 백현식의 방", next = "room3" },
		{ label = "4호 · 임지호의 방", next = "room4" },
		{ label = "내려간다", next = "yard", back = true },
	},
}

S.scenes.room1 = {
	art = "room1",
	title = "1호 · 윤재석의 방",
	text = [[죽은 사람의 방. 침대는 흐트러지지 않았다. 어젯밤 여기서 자지 않았다.

책상 위에 위스키 병과 잔 하나, 구겨진 종이 한 장. 의자에 가죽 가방.]],
	choices = {
		{ label = "구겨진 종이를 편다", next = "room1_telegram" },
		{ label = "가방을 연다", next = "room1_papers" },
		{ label = "위스키 병을 본다", next = "room1_whisky" },
		{ label = "복도로", next = "corridor", back = true },
	},
}

S.scenes.room1_telegram = {
	art = "room1",
	title = "1호 · 전보",
	text = [[전보. 발신은 동방해운 본사.

「기자 서 무영도로 향함. 백에게서 일지 반드시 회수할 것. 입 다물게 하라. 사장」

기자 서. 백. 일지.

윤재석은 백조호를 조사하러 온 것이 아니다. 무언가를 없애러 왔다.]],
	on_enter = clue("telegram"),
	choices = {
		{ label = "방을 둘러본다", next = "room1", back = true },
	},
}

S.scenes.room1_papers = {
	art = "room1",
	title = "1호 · 가방",
	text = [[출장 명령서. 「화물감독관 윤재석. 서기 임지호 동행. 백조호 관련 서류 회수.」

직원 명부 사본이 끼워져 있다. 임지호. 입사 여섯 달. 이전 이력 없음. 신원보증인 임 아무개.

그 밖에 백조호 보험금 지급 서류 사본. 우리 회사 도장이 찍혀 있다.]],
	on_enter = clue("roster"),
	choices = {
		{ label = "방을 둘러본다", next = "room1", back = true },
	},
}

S.scenes.room1_whisky = {
	art = "room1",
	title = "1호 · 위스키",
	text = [[반쯤 빈 병. 잔은 하나. 잔 바닥에 마른 자국.

혼자 마셨다. 상당히 마셨다. 등대 계단을 오르기에는 나쁜 상태였을 것이다.]],
	on_enter = clue("whisky"),
	choices = {
		{ label = "방을 둘러본다", next = "room1", back = true },
	},
}

S.scenes.room2 = {
	art = "room2",
	title = "2호 · 서연우의 방",
	text = [[비어 있다. 서연우는 아침부터 선착장에 나가 있다고 한다.

삼각대와 사진기. 인화지 상자. 침대 위에 노트 한 권. 옷걸이에 외투.]],
	choices = {
		{ label = "노트를 펼친다", next = "room2_note" },
		{ label = "외투를 살핀다", next = "room2_coat" },
		{ label = "복도로", next = "corridor", back = true },
	},
}

S.scenes.room2_note = {
	art = "room2",
	title = "2호 · 노트",
	text = [[사진 노출 기록이 아니다. 빽빽한 속기 부호. 읽을 수 없다.

어젯밤 날짜가 적힌 쪽에 알아볼 수 있는 글자가 몇 개 섞여 있다. 「3호」. 「등대」. 「궤짝」. 그리고 밑줄 친 시각, 「9시」.]],
	on_enter = clue("shorthand"),
	choices = {
		{ label = "방을 둘러본다", next = "room2", back = true },
	},
}

S.scenes.room2_coat = {
	art = "room2",
	title = "2호 · 외투",
	text = [[안주머니에 딱딱한 것. 기자증이다.

경성일보 사회부 서연우.

사진사가 아니다. 전보의 「기자 서」가 이 사람이다.]],
	on_enter = clue("press_id"),
	choices = {
		{ label = "방을 둘러본다", next = "room2", back = true },
	},
}

S.scenes.room3 = {
	art = "room3",
	title = "3호 · 백현식의 방",
	text = function(st)
		if st.visited.room3 == 1 then
			return [[문을 두드리자 「들어오시오」 하는 낮은 목소리.

노인이 창가 의자에 앉아 바다 쪽을 보고 있다. 무릎에 담요. 지팡이가 의자에 기대어 있다. 백현식. 백조호의 마지막 선장.

「보험회사라고 들었소. 무엇이든 보시오. 숨길 것은 이제 없소.」

책상 위에 쓰다 만 편지. 머리맡에 약병.]]
		end
		return [[백현식은 여전히 창가에 앉아 있다.]]
	end,
	choices = {
		{ label = "백현식과 이야기한다", next = "talk_baek" },
		{ label = "책상의 편지를 읽는다", next = "room3_letter" },
		{ label = "머리맡을 본다", next = "room3_meds" },
		{ label = "복도로", next = "corridor", back = true },
	},
}

S.scenes.room3_letter = {
	art = "room3",
	title = "3호 · 편지 초안",
	text = [[떨리는 글씨. 날짜는 그저께.

「나는 더 이상 침묵하지 않겠다. 일지는 믿을 수 있는 사람에게 넘겼다. 강 갑판장, 김군, 박군, 이군에게 이 늙은이가 할 수 있는 것은 이것뿐이다. 늦었다는 것을 안다.」

백현식은 이쪽을 보지 않는다.]],
	on_enter = clue("letter_draft"),
	choices = {
		{ label = "방을 둘러본다", next = "room3", back = true },
	},
}

S.scenes.room3_meds = {
	art = "room3",
	title = "3호 · 머리맡",
	text = [[심장약. 처방전에 「계단 오르내림 금지」.

지팡이 손잡이가 손때로 반질반질하다. 이 사람은 등대 계단을 오를 수 없다. 여관 2층까지 올라오는 데도 한명희의 아들 강도윤이 부축한다고 한다.]],
	on_enter = clue("meds"),
	choices = {
		{ label = "방을 둘러본다", next = "room3", back = true },
	},
}

S.scenes.talk_baek = {
	art = "room3+baek",
	title = "3호 · 백현식",
	text = function(st)
		if st:get("baek_admitted") then
			return [[백현식이 담요를 고쳐 덮는다. 「더 묻고 싶은 것이 있소?」]]
		end
		if st.visited.talk_baek == 1 then
			return [[「윤 감독관은 술에 취해 등대에 올라갔다가 떨어졌다고 하더군. 그렇겠지. 그런 사람이오.」

노인의 목소리에는 슬픔도 놀람도 없다.]]
		end
		return [[백현식은 바다를 보고 있다.]]
	end,
	choices = {
		{ label = "어젯밤 윤재석이 찾아왔나", next = "baek_visit" },
		{ label = "백조호에 대해", next = "baek_ship" },
		{ label = "편지 초안을 내민다", next = "baek_confess", cond = all(has("letter_draft"), noflag("baek_admitted")) },
		{ label = "항해일지를 읽었다고 말한다", next = "baek_confess", cond = all(has("logbook"), noflag("baek_admitted")) },
		{ label = "방을 둘러본다", next = "room3", back = true },
	},
}

S.scenes.baek_visit = {
	art = "room3+baek",
	title = "3호 · 백현식",
	text = function(st)
		if st:get("baek_admitted") then
			return [[「아홉 시쯤. 이미 말했소. 일지를 내놓으라고 했고, 나는 등대 궤짝에 있다고 했소. 거짓말이었지.」]]
		end
		return [[「왔소. 아홉 시쯤. 옛날 얘기를 하더군. 회사 사람들끼리 하는 얘기요. 곧 갔소.」

노인은 그 이상 말하지 않는다.]]
	end,
	choices = {
		{ label = "다른 것을 묻는다", next = "@back" },
	},
}

S.scenes.baek_ship = {
	art = "room3+baek",
	title = "3년 전 · 백조호",
	text = function(st)
		if st:get("baek_admitted") then
			return [[「배는 폭풍 때문에 가라앉은 게 아니오. 내가 가라앉혔소. 이미 말한 그대로요.」]]
		end
		return [[「폭풍이었소. 침로를 잃었고, 검은여에 걸렸소. 넷을 잃었소. 그게 다요.」

「왜 여기 사느냐고? 여기서는 검은여가 보이오.」]]
	end,
	choices = {
		{ label = "다른 것을 묻는다", next = "@back" },
	},
}

S.scenes.baek_confess = {
	art = "room3+baek",
	title = "3호 · 백현식의 고백",
	text = [[노인이 오랫동안 편지를 본다. 그리고 지팡이를 끌어당겨 두 손으로 짚는다.

「그렇소. 백조호는 빈 배였소. 화물은 출항 전에 다른 항구에서 빼돌려 팔았소. 그 일을 한 것이 윤재석이오. 사장이 나에게 돈을 주며 말했소. 검은여로 가서 배를 잃으라고. 폭풍 예보가 있는 날을 골랐소. 선원은 구명정으로 전원 내릴 계획이었소.」

「밤이 되니 폭풍이 예보보다 심해졌소. 구명정 하나가 뒤집혔소. 강 갑판장, 김태오, 박무열, 이정구. 내가 죽인 거요.」

「진짜 일지는 내가 가지고 있었소. 공식 일지는 조작해서 냈고. 3년 동안 저 궤짝 같은 마음으로 살았소. 그저께, 서 기자에게 넘겼소. 그 사람이 나를 찾아낸 거요. 아니, 내가 편지를 보냈소. 신문사와 당신네 보험회사에.」

「어젯밤 윤이 왔소. 일지를 내놓으라고. 나도 감옥에 간다고. 나는 시간을 벌고 싶었소. 서 기자가 아침 배로 나가면 끝나는 일이었으니까. 그래서 등대 램프실 궤짝에 있다고 했소. 등대 열쇠는 현관에 있다고. 술이 깨면 가라고 했는데… 그 사람은 밤중에 갔더군.」

「그 사람이 죽은 것은 내 거짓말 때문이오. 하지만 나는 그 계단을 오를 수 없소. 그것은 당신도 알 거요.」]],
	on_enter = function(st)
		st:set("baek_admitted", true)
		st:add_clue("baek_confession")
		st:add_clue("lie_chest")
	end,
	choices = {
		{ label = "다른 것을 묻는다", next = "talk_baek", back = true },
	},
}

S.scenes.room4 = {
	art = "room4",
	title = "4호 · 임지호의 방",
	text = [[비어 있다. 임지호는 등대 앞에 나가 서 있다고 한다.

침대는 잠을 잔 흔적이 거의 없다. 옷걸이에 동방해운 제복 코트. 의자 위에 작은 가방. 책상 위에 반짇고리가 열린 채 놓여 있다.]],
	choices = {
		{ label = "코트를 살핀다", next = "room4_coat" },
		{ label = "가방을 연다", next = "room4_bag" },
		{ label = "복도로", next = "corridor", back = true },
	},
}

S.scenes.room4_coat = {
	art = "room4",
	title = "4호 · 코트",
	text = [[동방해운 제복 코트. 놋쇠 단추 다섯 개. 닻과 별 문양.

셋째 단추만 다르다. 문양은 같지만 색이 더 밝고, 실이 남색이다. 나머지는 검은 실. 실 끝이 아직 뻣뻣하다. 밤사이 새로 달았다.

원래 단추는 어디에 있는가.]],
	on_enter = clue("coat_button"),
	choices = {
		{ label = "방을 둘러본다", next = "room4", back = true },
	},
}

S.scenes.room4_bag = {
	art = "room4",
	title = "4호 · 가방",
	text = [[갈아입을 옷. 서류. 그리고 옷 사이에 끼워 둔 낡은 사진 한 장.

등대 앞에 선 두 소년. 큰 아이가 작은 아이의 어깨에 손을 얹고 있다. 등대는 이 섬의 등대다.

뒷면. 「태오, 지호. 무영도.」]],
	on_enter = clue("photo"),
	choices = {
		{ label = "방을 둘러본다", next = "room4", back = true },
	},
}

-- lighthouse -----------------------------------------------------------------

S.scenes.lighthouse = {
	art = "lighthouse",
	title = "등대 · 앞",
	text = function(st)
		if st.visited.lighthouse == 1 then
			return [[비탈 끝. 흰 등대가 안개 속에 서 있다. 철문이 열려 있고 안쪽은 어둡다.

문 옆 바위에 젊은 남자가 앉아 있다. 제복 바지에 흰 셔츠, 코트는 없다. 임지호. 이쪽을 보고 일어선다.

「감독관님은… 안에 계십니다. 저는 못 들어가겠습니다.」]]
		end
		return [[등대 앞. 임지호는 아직 바위에 앉아 있다. 철문은 열려 있다.]]
	end,
	choices = {
		{ label = "임지호와 이야기한다", next = "talk_lim" },
		{ label = "등대 안으로 들어간다", next = "lh_inside" },
		{ label = "마당으로", next = "yard", back = true },
	},
}

S.scenes.talk_lim = {
	art = "lighthouse+lim",
	title = "등대 앞 · 임지호",
	text = function(st)
		if st:get("lim_silent") then
			return [[임지호는 바다 쪽을 보고 있다. 더는 말하지 않을 얼굴이다.]]
		end
		if st.visited.talk_lim == 1 then
			return [[스물 남짓. 창백하고 조용하다. 손을 주머니에 넣고 있다.

「감독관님을 모시고 어제 왔습니다. 백조호 서류를 회수하는 출장이었습니다. 저는 서류만 담당해서… 자세한 건 모릅니다.」]]
		end
		return [[임지호가 이쪽을 본다. 「네.」]]
	end,
	choices = {
		{ label = "어젯밤 어디 있었나", next = "lim_night", cond = noflag("lim_silent") },
		{ label = "윤재석은 어떤 사람이었나", next = "lim_boss", cond = noflag("lim_silent") },
		{ label = "사진을 내민다", next = "lim_photo", cond = all(has("photo"), any(has("memorial"), has("resemblance")), noflag("lim_identity_done")) },
		{ label = "단추 이야기를 꺼낸다", next = "lim_button", cond = all(has("brass_button"), has("coat_button"), noflag("lim_silent")) },
		{ label = "등대 앞으로", next = "lighthouse", back = true },
	},
}

S.scenes.lim_night = {
	art = "lighthouse+lim",
	title = "등대 앞 · 임지호",
	text = [[「방에 있었습니다. 저녁 먹고 바로 올라가서… 잤습니다.」

「감독관님이 밤에 나가시는 건 몰랐습니다. 아침에 소란이 나서 알았습니다.」

주머니 속 손이 움직인다.]],
	choices = {
		{ label = "다른 것을 묻는다", next = "@back" },
	},
}

S.scenes.lim_boss = {
	art = "lighthouse+lim",
	title = "등대 앞 · 임지호",
	text = [[「…일 잘하시는 분이었습니다. 회사에서는요.」

「어젯밤 식당에서 하신 말씀은… 취하셔서 그런 겁니다. 늘 그러셨습니다. 백조호 얘기를 하실 때는.」

임지호는 등대를 올려다보지 않는다. 한 번도.]],
	choices = {
		{ label = "다른 것을 묻는다", next = "@back" },
	},
}

S.scenes.lim_photo = {
	art = "lighthouse+lim",
	title = "등대 앞 · 사진",
	text = [[사진을 내민다. 임지호가 그것을 오래 본다. 손이 떨린다.

「…형입니다. 김태오. 저는 김지호였습니다. 임씨 집에 양자로 가서 성이 바뀌었습니다.」

「형이 죽은 배가 왜 그 항로에 있었는지, 왜 화물칸이 비어 있었다는 소문이 도는지, 아무도 대답해 주지 않았습니다. 그래서 그 회사에 들어갔습니다. 여섯 달 동안 그 사람 밑에서 서류를 날랐습니다.」

「이 섬에 오는 건 열세 살 이후 처음입니다. 형이 죽은 바다를 처음 봤습니다.」

「하지만 저는 감독관님을 죽이지 않았습니다.」

그 마지막 말만 이쪽을 보지 않고 한다.]],
	on_enter = function(st)
		st:set("lim_identity_done", true)
		st:add_clue("lim_identity")
	end,
	choices = {
		{ label = "다른 것을 묻는다", next = "talk_lim", back = true },
	},
}

S.scenes.lim_button = {
	art = "lighthouse+lim",
	title = "등대 앞 · 단추",
	text = [[「시신의 손에 놋쇠 단추가 있었습니다. 당신 코트의 셋째 단추는 실이 새것입니다.」

임지호의 얼굴에서 핏기가 빠진다. 주머니에서 손이 나온다. 빈손이다.

긴 침묵.

「…경찰이 오면 말하겠습니다.」

그 뒤로 그는 무슨 말을 해도 대답하지 않는다.]],
	on_enter = function(st)
		st:set("lim_silent", true)
		st:add_clue("lim_silence")
	end,
	choices = {
		{ label = "등대 앞으로", next = "lighthouse", back = true },
	},
}

S.scenes.lh_inside = {
	art = "lh_inside",
	title = "등대 · 안",
	text = function(st)
		if st.visited.lh_inside == 1 then
			return [[안은 차고 축축하다. 나선 철계단이 어둠 속으로 감겨 올라간다.

계단 아래, 바닥에 시신이 있다. 담요가 덮여 있다. 강도윤이 벽에 기대 서 있다.

「건드리지 않았습니다. 담요만 덮었습니다.」]]
		end
		return [[등대 안. 시신은 그대로고, 강도윤은 벽에 기대 있다.]]
	end,
	choices = {
		{ label = "시신을 살핀다", next = "lh_body" },
		{ label = "계단을 오른다", next = "lh_stairs" },
		{ label = "강도윤과 이야기한다", next = "talk_doyun" },
		{ label = "밖으로", next = "lighthouse", back = true },
	},
}

S.scenes.lh_body = {
	art = "lh_body",
	title = "등대 · 시신",
	text = [[담요를 걷는다.

윤재석. 마흔 중반. 두꺼운 외투 차림. 목이 부자연스럽게 꺾여 있고 뒤통수에 상처. 철계단 모서리에 부딪힌 자국이다. 술 냄새가 아직 난다.

외투 단추는 다 있다. 찢어진 곳도 없다.

오른손이 주먹을 쥐고 있다. 손가락을 편다.

놋쇠 단추 하나. 닻과 별 문양. 동방해운 제복 단추. 실이 뜯겨 나온 채로.

죽은 사람은 마지막 순간에 누군가의 코트를 붙잡았다.]],
	on_enter = function(st)
		st:add_clue("body")
		st:add_clue("brass_button")
		st:set("can_report", true)
	end,
	choices = {
		{ label = "등대 안으로", next = "lh_inside", back = true },
	},
}

S.scenes.lh_stairs = {
	art = "lh_stairs",
	title = "등대 · 계단",
	text = [[철계단을 오른다. 난간이 차다.

위쪽 층계참부터 마른 진흙 발자국이 있다. 두 사람분. 하나는 크고 넓은 구두. 하나는 작은 구두. 장화는 없다.

큰 발자국은 오르는 방향만 있다. 작은 발자국은 오르는 것과 내려오는 것이 있다.

맨 위, 램프실.]],
	on_enter = clue("footprints"),
	choices = {
		{ label = "램프실로 들어간다", next = "lh_top" },
		{ label = "내려간다", next = "lh_inside", back = true },
	},
}

S.scenes.lh_top = {
	art = "lh_top",
	title = "등대 · 램프실",
	text = [[꺼진 등. 유리창 너머는 온통 흰색이다.

구석에 나무 궤짝. 뚜껑이 열려 있다. 안은 비었다. 먼지 위에 손으로 헤집은 자국. 누군가 이 궤짝에서 무언가를 찾으려고 했다. 그리고 찾지 못했다.

바닥에 램프실 문 쪽으로 몸이 끌린 자국은 없다. 다툼은 계단 위, 문턱에서 일어났다.]],
	on_enter = clue("empty_chest"),
	choices = {
		{ label = "내려간다", next = "lh_inside", back = true },
	},
}

S.scenes.talk_doyun = {
	art = "lighthouse+doyun",
	title = "등대 · 강도윤",
	text = function(st)
		if st.visited.talk_doyun == 1 then
			return [[강도윤. 스물셋. 등대지기 보조. 3년 전 아버지가 백조호에서 죽은 뒤 섬으로 돌아왔다고 한다.

「물어보실 게 있으면 물어보세요.」]]
		end
		return [[강도윤이 고개를 든다.]]
	end,
	choices = {
		{ label = "시신을 발견한 경위", next = "doyun_found" },
		{ label = "등대 문과 열쇠", next = "doyun_key" },
		{ label = "백현식에 대해", next = "doyun_baek" },
		{ label = "어젯밤 어디 있었나", next = "doyun_night" },
		{ label = "등대 안으로", next = "lh_inside", back = true },
	},
}

S.scenes.doyun_found = {
	art = "lighthouse+doyun",
	title = "등대 · 강도윤",
	text = [[「새벽 다섯 시 반에 등을 점검하러 옵니다. 그런데 철문이 열려 있었어요. 제가 열 시에 분명히 잠갔는데.」

「들어오니까… 저기 계셨습니다. 이미 차가웠어요. 뛰어 내려가서 어머니를 깨우고, 식당의 길수 아저씨를 깨웠습니다.」]],
	on_enter = clue("timeline_doyun"),
	choices = {
		{ label = "다른 것을 묻는다", next = "@back" },
	},
}

S.scenes.doyun_key = {
	art = "lighthouse+doyun",
	title = "등대 · 강도윤",
	text = [[「열쇠는 하나뿐입니다. 밤 열 시에 등을 확인하고 문을 잠근 다음, 여관 현관 걸이에 겁니다. 아침에 다시 가져옵니다. 3년째 그렇게 합니다.」

「어젯밤에도 걸었습니다. 아침에 보니 걸이에 그대로 있었어요. 그래서 이상했습니다. 열쇠는 걸이에 있는데 문은 열려 있으니까.」

「진흙이요? …네. 열쇠에 진흙이 묻어 있었어요. 제가 만질 때는 묻히지 않았습니다.」]],
	on_enter = clues("timeline_doyun", "key_mud"),
	choices = {
		{ label = "다른 것을 묻는다", next = "@back" },
	},
}

S.scenes.doyun_baek = {
	art = "lighthouse+doyun",
	title = "등대 · 강도윤",
	text = [[「백 선장님은 아버지가 탄 배의 선장이었습니다. 처음엔 미웠습니다. 지금은… 모르겠습니다.」

「그분이 여기 올라올 수 있느냐고요? 못 옵니다. 여관 2층도 제가 부축해야 올라가세요. 이 계단은 백 개가 넘습니다.」]],
	on_enter = clue("meds"),
	choices = {
		{ label = "다른 것을 묻는다", next = "@back" },
	},
}

S.scenes.doyun_night = {
	art = "lighthouse+doyun",
	title = "등대 · 강도윤",
	text = [[「등대 옆 숙소에서 잤습니다. 열 시에 문 잠그고 열쇠 걸어 놓고, 그 뒤로 여관에 안 갔습니다.」

「장화 신고 다닙니다. 이 섬에서 구두 신는 사람은 육지 손님뿐이에요.」]],
	on_enter = clue("shoes_doyun"),
	choices = {
		{ label = "다른 것을 묻는다", next = "@back" },
	},
}

-- pier -----------------------------------------------------------------------

S.scenes.pier = {
	art = "pier",
	title = "무영도 · 선착장",
	text = function(st)
		if st.visited.pier == 1 then
			return [[선착장. 안개가 바다 위에 엎드려 있다. 물 소리만 들린다.

방파제 끝에 여자가 삼각대를 세우고 서 있다. 사진기를 안개 쪽으로 향하고 있지만 셔터는 누르지 않는다. 서연우.

방파제 초입에 작은 돌비석이 하나 있다.]]
		end
		return [[선착장. 서연우는 여전히 방파제 끝에 있다.]]
	end,
	choices = {
		{ label = "서연우와 이야기한다", next = "talk_seo" },
		{ label = "돌비석을 본다", next = "pier_memorial" },
		{ label = "경찰선을 기다리며 보고서를 쓴다", next = "report", cond = flag("can_report") },
		{ label = "마당으로", next = "yard", back = true },
	},
}

S.scenes.pier_memorial = {
	art = "memorial",
	title = "선착장 · 돌비석",
	text = [[「백조호 희생자를 기억함」

강동수. 김태오. 박무열. 이정구.

비석 앞에 마른 국화. 그리고 오늘 아침에 놓인 듯한, 아직 젖어 있는 담배 한 개비.]],
	on_enter = clue("memorial"),
	choices = {
		{ label = "선착장으로", next = "pier", back = true },
	},
}

S.scenes.talk_seo = {
	art = "pier+seo",
	title = "선착장 · 서연우",
	text = function(st)
		if st:get("seo_admitted") then
			return [[서연우가 사진기에서 손을 뗀다. 「더 물을 것이 있나요.」]]
		end
		if st.visited.talk_seo == 1 then
			return [[서른 안팎. 짧은 머리, 남자 외투. 이쪽을 보는 눈이 빠르다.

「사진 찍으러 왔어요. 안개 낀 섬. 근데 안개가 너무 껴서 아무것도 안 찍히네요.」

웃지 않는다.]]
		end
		return [[서연우. 「네?」]]
	end,
	choices = {
		{ label = "어젯밤 무엇을 들었나", next = "seo_night" },
		{ label = "백현식을 아는가", next = "seo_baek" },
		{ label = "기자증과 전보를 내민다", next = "seo_confess", cond = all(has("press_id"), has("telegram"), noflag("seo_admitted")) },
		{ label = "백현식이 고백했다고 말한다", next = "seo_confess", cond = all(flag("baek_admitted"), noflag("seo_admitted")) },
		{ label = "선착장으로", next = "pier", back = true },
	},
}

S.scenes.seo_night = {
	art = "pier+seo",
	title = "선착장 · 서연우",
	text = function(st)
		if st:get("seo_admitted") then
			return [[「아홉 시에 옆방 대화를 들었고, 그 뒤로는 방에서 안 나왔어요. 자정쯤 현관 종소리를 들었고요. 그게 다예요.」]]
		end
		return [[「벽이 얇아서 이것저것 들리긴 해요. 옆방 노인이 손님하고 얘기하는 소리. 무슨 얘기인지는 모르겠고요.」

「자정쯤에 현관 종이 울린 것 같기도 하고. 잤어요.」]]
	end,
	choices = {
		{ label = "다른 것을 묻는다", next = "@back" },
	},
}

S.scenes.seo_baek = {
	art = "pier+seo",
	title = "선착장 · 서연우",
	text = function(st)
		if st:get("seo_admitted") then
			return [[「백 선장이 편지를 보냈어요. 신문사로. 저는 그걸 받고 왔고요. 사흘 동안 설득했어요. 그저께 밤에 일지를 넘겨주셨어요.」]]
		end
		return [[「옆방 노인이요? 인사만 해요. 바다만 보시던데.」]]
	end,
	choices = {
		{ label = "다른 것을 묻는다", next = "@back" },
	},
}

S.scenes.seo_confess = {
	art = "pier+seo",
	title = "선착장 · 서연우의 이야기",
	text = [[서연우가 한참 안개를 본다.

「경성일보 서연우예요. 백조호 건은 1년째 쫓고 있어요. 두 달 전에 백 선장이 신문사로 편지를 보냈어요. 자기가 알고 있다고. 그래서 왔어요.」

「사흘 동안 그분 방에서 이야기했어요. 그저께 밤에 항해일지를 주셨어요. 진짜 일지. 마지막 항해 페이지에 이렇게 적혀 있어요. 화물칸 비어 있음. 선주 지시로 침로 변경, 검은여로.」

「빈 배를 일부러 가라앉힌 거예요. 화물은 미리 팔아먹고 보험금은 따로 챙기고. 그 실무를 윤재석이 했어요.」

「어젯밤 아홉 시, 벽 너머로 들었어요. 윤재석이 백 선장한테 일지를 내놓으라고 했어요. 안 내놓으면 당신도 감옥이라고. 백 선장이 말했어요. 등대 램프실 궤짝에 있다고. 열쇠는 현관에 있다고. 윤재석이 웃으면서 그랬어요. 술 좀 깨고 가져오겠다고.」

「저는 무서웠어요. 일지를 인화지 상자 밑에 숨기고 문을 잠갔어요. 아침 배로 나가려고 했는데… 배가 안 떴죠.」

「일지는 지금 제 가방에 있어요. 경찰이 오면 낼 거예요. 보험회사도 필요하겠죠. 사본을 드릴게요.」]],
	on_enter = function(st)
		st:set("seo_admitted", true)
		st:add_clue("overheard")
		st:add_clue("logbook")
	end,
	choices = {
		{ label = "다른 것을 묻는다", next = "talk_seo", back = true },
	},
}

-- report ---------------------------------------------------------------------

S.scenes.report = {
	type = "report",
	title = "사건 보고서",
	text = function(st)
		local total = 0
		for _ in pairs(S.clues) do total = total + 1 end
		return string.format("북성해상보험 조사부 · 무영도 사건. 각 항목에 결론을 적는다.\n\n수첩에 기록한 단서 %d / %d.", #st.clue_order, total)
	end,
	back = "yard",
	slots = {
		{
			id = "purpose",
			label = "윤재석이 무영도에 온 목적",
			options = { "백조호 보험금 재조사", "백조호의 진짜 항해일지 회수", "섬의 토지 매입", "휴양" },
			answer = 2,
		},
		{
			id = "sinking",
			label = "3년 전 백조호 침몰의 진상",
			options = { "폭풍에 의한 사고", "암초를 놓친 선장의 과실", "빈 배를 고의로 침몰시킨 보험 사기", "해적의 습격" },
			answer = 3,
		},
		{
			id = "culprit",
			label = "윤재석을 죽인 사람",
			options = { "한명희", "강도윤", "서연우", "백현식", "임지호", "장길수" },
			answer = 5,
		},
		{
			id = "method",
			label = "죽음의 경위",
			options = { "취해서 혼자 굴러떨어졌다", "몸싸움 끝에 계단 위에서 떠밀렸다", "램프에 머리를 맞았다", "술에 독이 들어 있었다" },
			answer = 2,
		},
		{
			id = "motive",
			label = "범행의 동기",
			options = { "보험금을 독차지하려고", "사기를 폭로하지 못하게 하려고", "백조호에서 죽은 형의 복수", "여관의 빚 때문에" },
			answer = 3,
		},
	},
	submit_label = "보고서를 제출한다",
	on_correct = "truth1",
	wrong_text = function(n_wrong, attempts)
		local s = string.format("보고서를 다시 읽는다. 틀린 항목이 %d개 있다.", n_wrong)
		if attempts >= 3 then
			s = s .. "\n\n아직 보지 않은 방, 묻지 않은 질문이 있을지 모른다. 수첩의 단서를 하나씩 대조해 본다."
		end
		return s
	end,
}

-- endings --------------------------------------------------------------------

S.scenes.truth1 = {
	art = "pier",
	style = "ending",
	title = "오후 · 경찰선",
	text = [[오후 두 시. 안개가 갈라지고 경찰선의 기적이 울린다.

보고서를 덮는다.

윤재석은 백조호의 진짜 항해일지를 없애러 왔다. 백조호는 빈 배였고, 회사는 일부러 가라앉혀 보험금을 챙겼다. 어젯밤 윤재석은 백현식의 거짓말을 믿고 등대에 올랐고, 임지호가 그 뒤를 따랐다.

임지호. 김지호. 죽은 김태오의 동생.

계단 맨 위에서 두 사람은 마주 섰다. 윤재석은 웃었을 것이다. 형 얘기를 들으며, 늘 하던 대로. 몸싸움이 있었고, 윤재석은 임지호의 코트를 붙잡은 채 떠밀려 백 개가 넘는 철계단을 굴렀다.

임지호는 열쇠를 도로 걸고, 구두를 닦고, 새벽에 단추를 달았다.

선착장으로 내려간다. 임지호가 방파제 끝에 혼자 서 있다. 이쪽을 보고, 경찰선을 보고, 다시 이쪽을 본다.]],
	choices = {
		{ label = "임지호에게 간다", next = "truth2" },
	},
}

S.scenes.truth2 = {
	art = "pier+lim",
	style = "ending",
	title = "선착장 · 임지호",
	text = [[「알고 계시는군요.」

임지호가 말한다. 목소리가 이상하게 차분하다.

「죽일 생각은 없었습니다. 그 사람이 등대로 올라가는 걸 보고 따라갔습니다. 궤짝 앞에서 물었습니다. 형이 왜 죽었느냐고. 김태오라고 했습니다. 그 사람이 한참 저를 보더니 웃었습니다. 그리고 말했습니다. 네 형은 운이 없었을 뿐이야, 배는 원래 아무도 안 죽게 돼 있었어.」

「그 말을 듣는 순간… 제가 밀었습니다. 그 사람이 제 코트를 잡았고, 단추가 뜯어졌고, 그리고… 소리가 아주 오래 났습니다.」

「무서워서 정리했습니다. 열쇠를 걸고, 구두를 닦고, 단추를 달았습니다. 아침이 되니 다 소용없다는 걸 알았습니다.」

「경찰에 말하겠습니다. 다만… 일지는요. 형의 배 얘기는 세상에 나옵니까.」

경찰선이 방파제에 닿는다. 밧줄이 던져진다.

보고서의 마지막 줄을 어떻게 쓸 것인가.]],
	choices = {
		{ label = "진실 그대로 보고한다", next = "ending_truth" },
		{ label = "사고로 기록한다", next = "ending_accident" },
	},
}

S.scenes.ending_truth = {
	art = "island_lit",
	style = "ending",
	title = "결말 · 기록",
	text = [[보고서에 임지호의 이름을 쓴다. 그는 고개를 끄덕이고, 스스로 경찰 쪽으로 걸어간다.

같은 배로 백현식이 자수한다. 부축하는 것은 강도윤이다. 서연우는 항해일지 사본을 우리 회사에, 원본을 경찰에 넘긴다.

두 달 뒤. 경성일보 1면. 「동방해운 백조호 고의 침몰. 사장 구속.」 북성해상보험은 지급한 보험금 전액에 대한 환수 소송을 건다.

임지호는 재판에서 형의 이름을 말한다. 김태오. 그 이름이 처음으로 법정 기록에 남는다.

한명희는 여관을 계속 한다. 식당 벽의 액자에는 신문 조각이 하나 더 늘었다.

무영도의 등대는 그 뒤로 밤마다 켜졌다.

— 결말 A · 기록 —

다른 결말이 있다.]],
	choices = {
		{ label = "처음으로", next = "@restart" },
	},
}

S.scenes.ending_accident = {
	art = "island_dark",
	style = "ending",
	title = "결말 · 안개",
	text = [[보고서에 쓴다. 「피보험 관련인 윤재석, 음주 후 등대 계단에서 추락사. 목격자 없음.」

임지호가 이쪽을 본다. 아무 말도 하지 않는다. 그것이 감사인지 무엇인지 알 수 없다.

같은 배로 백현식이 자수한다. 항해일지는 경찰과 우리 회사에 넘어간다. 두 달 뒤 동방해운 사장이 구속된다. 회사는 무너지고, 임지호는 그 회사에서 조용히 사라진다.

윤재석의 죽음은 사고로 남는다.

몇 해 뒤, 회사 앞으로 편지가 온다. 발신인 없음. 무영도 등대 사진 한 장. 뒷면에 한 줄.

「형에게 다녀왔습니다.」

안개는 그날 이후로도 자주 낀다.

— 결말 B · 안개 —

다른 결말이 있다.]],
	choices = {
		{ label = "처음으로", next = "@restart" },
	},
}

return S
