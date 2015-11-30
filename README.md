# colorjamo

A LaTeX package for colorizing Hangul jamo characters

## requirement

You need to have `luatexko` package installed.

## usage

```
\usepackage{colorjamo}
...
\begin{colorjamo}
한글...
\end{colorjamo}
```
The command `\luatexhangulnormalize=2` provided by `luatexko` is recommended
for colorizing precomposed Hangul syllables.

## options
```
\jamocolorcho {FF0000} % color of leading consonants. default is red.
\jamocolorjung{00FF00} % color of medial vowels. default is green.
\jamocolorjong{0000FF} % color of final consonants. default is blue.
\jamotransparency {AA} % FF: full opaque, 00: full transparent
```

## license

Public domain.

