# 3m_solver
 1. 목표
	- 3-match의 play logic을 만들어 본다.
	- 초기값을 제시하면(e.g. random seed) 반복 재생 가능한 play logic을 만들어 보자.
	- n회의 시행 후 게임을 클리어하는 초기값을 찾아낸다.
  
 2. 왜 lua인가?
    - 동시에 많은 instance로 simulation을 돌려야 하기 때문에, memory footprint가 적을 수록 좋다.
    - luajit을 이용하면 실행 속도가 보장된다.
    - dependency가 적을 수록 좋다.
    
 3. 진행상황
    - [x] 기본적인 맵 정의
    - [x] initial seed를 이용한 pseudo-random 구현 (어디선가 베껴옴)
    - [x] 주어진 생성 확률에 따른 block 생성
    - [x] move candidate detect
    - [x] 3개 이상의 연결된 match detect
    - [x] move candidate가 없을 때 block shuffle
    
 4. 실행
  ```
  $ luajit solver.lua
  ```
  
 5. solver.lua 의 test_map() 설명
    - solver.lua에 정의된 map(test_map_rows)을
    - 초기값(test_random_seed)을 사용해서
    - 생성 확률(test_block_defs)에 따라 채우고
    - 5회 3-match를 시도한 다음
    - 생성된 block, 파괴한 block의 정보를 보여주고
    - 종료
    
 5. TODO
    - 대각선으로 미끄러져서 빈 곳을 채우는 로직 구현 필요
