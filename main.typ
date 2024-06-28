#import "@preview/polylux:0.3.1": *
#import themes.simple: *

#show: simple-theme.with(
  aspect-ratio: "16-9"
)
#show link: underline


#title-slide[
  = Bitcoin Cash Upgrade 2024-05-15
]

#slide[
  == 自己紹介

  - #link("https://twitter.com/haryu703")[haryu703]
  - コインチェック株式会社 (2020~)
]

#slide[
  == 今回のアップグレードの概要

  今回は下記の1件のプロトコルアップデートが行われた
  - #link("https://gitlab.com/0353F40E/ebaa/-/blob/9606b73b10551e4ef56e238c7a7bedc4f95236dd/README.md")[CHIP-2023-04 Adaptive Blocksize Limit Algorithm for Bitcoin Cash]
    - ブロックサイズの上限を需要に応じて自動で増減させる
]

#slide[
  == ブロックサイズ上限の歴史

  - 2010年-2017年: 1MB
  - 2017年-2018年: 8MB
  - 2018年-2024年: 32MB
  - 2024年-: 32MB -
]

#slide[
  == 背景

  - ブロックサイズの上限はネットワークを健全に維持するために必要
  - 需要や技術の進歩に合わせて上限を変更する必要はある
  - ブロックサイズを上げるには関係者の合意を取るなどのコストがかかる
]

#slide[
  == 目的

  - 今後のブロックサイズに関する合意コストをなくす
  - 需要に応じたブロックサイズの上限を自動で設定する
]

#set text(size: 20pt)

#slide[
  == 方法

  「control function」と「elastic buffer function」という2つの要素で制御される

  $ y_n &= epsilon_n + beta_n \
    epsilon_n &= cases(
      epsilon_0 && "if" n <= n_0,
      epsilon_(n-1) + gamma dot (zeta dot x_(n-1) - epsilon_(n-1) - zeta dot beta_(n-1) dot (zeta dot x_(n-1) - epsilon_(n-1)) / (zeta dot y_(n-1) - epsilon_(n-1))) &&  "if" n > n_0 "and" zeta dot x_(n-1) > epsilon_(n-1),
      max(epsilon_(n-1) + gamma dot (zeta dot x_(n-1) - epsilon_(n-1)), epsilon_0) &&  "if" n > n_0 "and" zeta dot x_(n-1) <= epsilon_(n-1)
    ) \
    beta_n &= cases(
      beta_0 && "if" n <= n_0,
      max(beta_(n-1) - theta dot beta_(n-1) + delta dot (epsilon_n - epsilon_(n-1)), beta_0) && "if" n > n_0 "and" zeta dot x_(n-1) > epsilon_(n-1),
      max(beta_(n-1) - theta dot beta_(n-1), beta_0) && "if" n > n_0 "and" zeta dot x_(n-1) <= epsilon_(n-1)
    ) \
    $
]

#slide[

  - $y$: ブロックサイズの上限
  - $n$: ブロック高
  - $epsilon$: control function
  - $beta$: elastic buffer function
  - $n_0, epsilon_0, beta_0$: 初期値
  - $x$: 実際に作られたブロックのサイズ
  - $gamma$: control function の 「forget factor」
    - ブロックサイズの増減率を調整する
  - $zeta$: control function の「asymmetry factor」
    - ブロックサイズの増加率と減少率の差を調整する
  - $theta$: elastic buffer の減少率
    - control function 側の増加率が$theta$より低いと elastic buffer は減少する
  - $delta$: elastic buffer の「gearing ratio」
    - elastic buffer と control function をどの程度連動させるかを調整する
]

#slide[
  === mainnet のパラメータ
  #set text(size: 19pt)

  - $epsilon_0 &= 16000000$
  - $beta_0 &= 16000000$
  - $n_0 &= "ハードフォーク時点のブロック高"$
  - $zeta &= 1.5$
  - $gamma &= 1 / 37938$
  - $delta = 10$
  - $theta = 1 / 37938$
  \
  - ブロックサイズ上限の初期値は $y_0 = epsilon_0 + beta_0 = 32000000$ でハードフォーク前と同じ
  - このアルゴリズムが有効化されている testnet は$epsilon_0$、$beta_0$および$n_0$が異なる
  - その他、一時的に$y_"temporary_max" = 2000000000 (2 "GB")$が設定されている
    - 32-bit アーキテクチャや p2p プロトコルの制約
    - 2028年5月までに取り除かれるらしい
]

#slide[
  === パラメータの特徴

  ==== control function
  - ブロックサイズ増加率の上限: $((epsilon_n - epsilon_(n-1)) / epsilon_(n-1))_max = gamma dot (zeta - 1) = 1 / 75876$
    - 年間で最大 +200 %
  - ブロックサイズ減少率の上限: $((epsilon_n - epsilon_(n-1)) / epsilon_(n-1))_min = - gamma = -1 / 37938$
    - 年間で最大 -75 %

  ==== elastic buffer function
  - $epsilon$ に対する $beta$ の上限: $(beta_n / epsilon_n)_max = delta dot gamma / theta dot (zeta -1) / (gamma / theta dot (zeta - 1) + 1) = 3.33$
  - $beta$の減少率は$theta$で、年間で最大 -75 %
    - 半減するのは$log(0.5) / log(1 - theta) = 26296$ブロックで10分間に1ブロックなら約6ヶ月
  - 急激なブロックサイズの上昇に対応できるような増加をするらしい
]

#slide[
  === パラメータの選び方
  ==== Asymmetry factor ($zeta$)

  「Asymmetry factor」は control function の増減率の関係を決める

  $zeta = 2$ だと増加率と減少率は同じになる
  - ハッシュレートを 50 % 持った攻撃者によるスパム TX でブロックサイズを増やす攻撃に対し、防御側が空ブロックを作ることが強制される
    - 防御側は fee を得られないため攻撃側に対して不利
  \
  $zeta = 1.5$だと上記の攻撃シナリオに耐性がつく
  - ハッシュレートが 50:50 の場合、防御側は上限の33%のブロックサイズまで作れる
  - 空ブロックでブロックサイズを小さくする攻撃はしやすくなる
    - こちらは防御側が fee を受け取れるため有利
]

#slide[
  === Forget factor ($gamma$)

  「Forget factor」は control function の増減率の関係を決める

  - 1年間(52959 ブロック)の最大増加率が +100 % になるように設定された
  - BIP-101 で提案されていた増加率よりは高いが、最大増加率を維持するのは現実的ではないため実際に BIP-101 のブロックサイズを超えることは考えにくい

  === Gearing ratio ($delta$) と Decay rate ($theta$)

  「Gearing ratio」と「Decay rate」は elastic buffer の大きさと増減速度を決める

  - 大きさは最大で$beta$が$epsilon$の3.33倍になるように設定されている
    - 数ヶ月でブロックサイズが倍になっても大丈夫らしい
  - 減少速度は半年で半分になるように設定されている
]

#slide[
  == シナリオ

  下記を繰り返す場合
  #footnote[https://gitlab.com/0353F40E/ebaa/-/raw/9606b73b10551e4ef56e238c7a7bedc4f95236dd/simulations/results/abla-ewma-elastic-buffer-bounded-01-ne-scenario-13.png]
  - すべてのブロックがブロックサイズ上限で8ヶ月
  - 33%のブロックがブロックサイズ上限、他のブロックが21MBで4ヶ月

  #figure(
    image("abla-ewma-elastic-buffer-bounded-01-ne-scenario-13.png", width: 30%),
  )

]

#slide[

  90%のブロックがブロックサイズ上限の90%、残りが21MBが続く場合
  #footnote[https://gitlab.com/0353F40E/ebaa/-/raw/9606b73b10551e4ef56e238c7a7bedc4f95236dd/simulations/results/abla-ewma-elastic-buffer-bounded-01-ne-scenario-14.png]
  #figure(
    image("abla-ewma-elastic-buffer-bounded-01-ne-scenario-14.png", width: 40%),
  )
]

#slide[

  ハッシュレートの50%がスパム攻撃をする場合
  #footnote[https://gitlab.com/0353F40E/ebaa/-/raw/9606b73b10551e4ef56e238c7a7bedc4f95236dd/simulations/results/abla-ewma-elastic-buffer-01-scenario-15.png]
  - 1-4年目: 50%のブロックがブロックサイズ上限、残りが10.67MB
  - 5-8年目: 50%のブロックがブロックサイズ上限、残りが21.33MB

  #figure(
    image("abla-ewma-elastic-buffer-01-scenario-15.png", width: 40%),
  )
]

#slide[
  == まとめ

  - ブロックサイズの上限を自動で変更するアルゴリズムが導入された
  - 今後ブロックサイズの上限は需要に応じてハードフォーク無しに変更される
]
