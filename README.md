# colorjamo

A LaTeX package for colorizing Hangul jamo characters

## usage

```
\usepackage{colorjamo}
...
\begin{colorjamo}
한글...
\end{colorjamo}
```

* HarfBuzz 모드에서는 잘 작동하지 않는다.
* HCR Batang/Dotum LVT 폰트는 `Ligatures=RequiredOff` 옵션을 주어야 한다.
* KoPubWorld Batang/Dotum 폰트는 `RawFeature=-ccmp` 옵션을 주어야 한다.
* Nanum Myeongjo/BarunGothic Yethangul 폰트도 `RawFeature=-ccmp` 옵션을 주어야 한다.
* 폰트에 따라서는 잘 작동하지 않는 폰트들이 있다. 가령 Noto Serif/Sans CJK.

## options
```
\jamocolorcho {FF0000} % color of leading consonants. default is red.
\jamocolorjung{00FF00} % color of medial vowels. default is green.
\jamocolorjong{0000FF} % color of final consonants. default is blue.
\jamotransparency {BB} % FF: full opacity, 00: full transparency
```

## license

Public domain.

