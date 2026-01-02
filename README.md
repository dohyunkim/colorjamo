# colorjamo

A LaTeX package for colorizing Hangul jamo characters

## usage

	\usepackage{colorjamo}
	...
	\begin{colorjamo}
	한글...
	\end{colorjamo}

* HarfBuzz 모드에서는 잘 작동하지 않는다.
* `Script=Hangul` 옵션만으로 잘 작동하는 폰트:
	* UnBatang
	* Malgun Gothic
	* HCR Dotum
	* HCR Batang _Bold_
	* Hancom Hoonminjeongeum&#95;V
* `Script=Hangul`과 `Ligatures=RequiredOff` 옵션을 주어야 하는 폰트:
	* HCR Batang LVT
	* HCR Dotum LVT
	* HCR Batang _Regular_
* `Script=Hangul`과 `RawFeature=-ccmp` 옵션을 주어야 하는 폰트:
	* Noto Serif CJK KR
	* Noto Sans CJK KR
	* KoPubWorldBatang
	* KoPubWorldDotum
	* NanumMyeongjo YetHangul
	* NanumBarunGothic YetHangul
* luaotfload v3.19 이후부터 모든 폰트에 `RawFeature=-normalize` 옵션도 함께 지시해야 한다.

## options
	\jamocolorcho {FF0000} % color of leading consonants. default is red.
	\jamocolorjung{00FF00} % color of medial vowels. default is green.
	\jamocolorjong{0000FF} % color of final consonants. default is blue.
	\jamotransparency {BB} % FF: full opacity, 00: full transparency

이렇게 16진수로 지시하는 방법말고도, xcolor 패키지나 l3color 모듈의 색상 표현법을 사용할 수 있다. 가령 `\jamocolorcho{red!50}`. color 패키지는 지원하지 않는다.

투명도 또한 소수점 있는 10진수로 지시할 수 있다. 가령 `\jamotransparency{0.5}`. `1.0`은 완전 불투명, `0.0`은 완전 투명을 뜻한다.

## license

Public domain.

