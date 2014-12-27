import os, unicode, unsigned
import termbox as tb

# TODO: make independent of termbox for javascript compatibility

type
  BoxIndex = enum
    #h, v, tl, tr, bl, br, vl, vr, ht, hb, x
    sp, ─, │, ┌, ┐, └, ┘, ├, ┤, ┬, ┴, ┼

  Box = array[BoxIndex, Rune]

  cArray{.unchecked.}[T] = array[0..0, T]

proc initBox(s: string): Box =
  var i = BoxIndex.low
  for r in s.runes:
    assert i <= BoxIndex.high
    result[i] = r
    inc i
  assert i > BoxIndex.high

proc initCombinations: array[BoxIndex, array[BoxIndex, BoxIndex]] =
  var c = addr result
  for i in BoxIndex.low .. BoxIndex.high:
    result[sp][i] = i
    result[i][i]  = i
    result[i][┼]  = ┼

  template `=>`(a, c) =
    result[a[0]][a[1]] = c

  (─,│) => ┼
  (─,┌) => ┬; (│,┌) => ├
  (─,┐) => ┬; (│,┐) => ┤; (┌,┐) => ┬
  (─,└) => ┴; (│,└) => ├; (┌,└) => ├; (┐,└) => ┼
  (─,┘) => ┴; (│,┘) => ┤; (┌,┘) => ┼; (┐,┘) => ┤; (└,┘) => ┴
  (─,├) => ┼; (│,├) => ├; (┌,├) => ├; (┐,├) => ┼; (└,├) => ├; (┘,├) => ┼
  (─,┤) => ┼; (│,┤) => ┤; (┌,┤) => ┼; (┐,┤) => ┤; (└,┤) => ┼; (┘,┤) => ┤
  (─,┬) => ┬; (│,┬) => ┼; (┌,┬) => ┬; (┐,┬) => ┬; (└,┬) => ┼; (┘,┬) => ┼
  (─,┴) => ┴; (│,┴) => ┼; (┌,┴) => ┼; (┐,┴) => ┼; (└,┴) => ┴; (┘,┴) => ┴

  (├,┤) => ┼
  (├,┬) => ┼; (┤,┬) => ┼
  (├,┴) => ┼; (┤,┴) => ┼; (┬,┴) => ┼

const
  asciiBox  = initBox " -|+++++++++"
  thinBox   = initBox " ─│┌┐└┘├┤┬┴┼"
  roundBox  = initBox " ─│╭╮╰╯├┤┬┴┼"
  thickBox  = initBox " ━┃┏┓┗┛┣┫┳┻╋"
  doubleBox = initBox " ═║╔╗╚╝╠╣╦╩╬"

  combinations = initCombinations()

var usedBox = thinBox

proc combine(x, y: BoxIndex): BoxIndex =
  combinations[min(x,y)][max(x,y)]

proc changeCell(x, y: int, r: Rune, fg, bg: uint16) =
  tb.changeCell x.cint, y.cint, r.uint32, fg, bg

proc changeCell(x, y: int, s: string, fg, bg: uint16) =
  tb.changeCell x.cint, y.cint, s.runeAt(0).uint32, fg, bg

proc changeCell(x, y: int, b: BoxIndex, fg, bg: uint16) =
  tb.changeCell x.cint, y.cint, usedBox[b].uint32, fg, bg

proc toBoxIndex(c: uint32): BoxIndex =
  for i, b in usedBox:
    if b.uint32 == c:
      return i

proc toBoxIndex(c: string): BoxIndex =
  for i, b in usedBox:
    if b == c.runeAt(0):
      return i

proc combineCell(x, y: int, r: BoxIndex, fg, bg: uint16) =
  var
    cells = cast[ptr cArray[tbCell]](tb.cellBuffer())
    cell = cells[y * tb.width() + x]
  changeCell x, y, combine(cell.ch.toBoxIndex, r), fg, bg

proc combineCell(x, y: int, s: string, fg, bg: uint16) =
  combineCell x, y, s.toBoxIndex, fg, bg

proc tbEcho[T](x, y: int, fg, bg: uint16, ss: varargs[T, `$`]) =
  var x = x
  for s in ss:
    for r in s.runes:
      changeCell x, y, r, fg, bg
      inc x

proc window(x, y, w, h: int, title: string, content: openarray[string]) =
  combineCell x,   y,   ┌, TB_BLACK or TB_BOLD, TB_BLACK
  combineCell x+w, y,   ┐, TB_BLACK or TB_BOLD, TB_BLACK
  combineCell x,   y+h, └, TB_BLACK or TB_BOLD, TB_BLACK
  combineCell x+w, y+h, ┘, TB_BLACK or TB_BOLD, TB_BLACK

  for p in x+1 .. < x+w:
    combineCell p, y, ─, TB_BLACK or TB_BOLD, TB_BLACK
    combineCell p, y+h, ─, TB_BLACK or TB_BOLD, TB_BLACK
  for p in y+1 .. < y+h:
    combineCell x, p, │, TB_BLACK or TB_BOLD, TB_BLACK
    combineCell x+w, p, │, TB_BLACK or TB_BOLD, TB_BLACK

  tbEcho x+2, y, TB_CYAN or TB_BOLD, TB_BLACK, " ", title, " "

when isMainModule:
  usedBox = roundBox

  discard tb.init()
  tb.clear()
  window 0, 0, 30, 5, "foobar", @["foo", "bar", "foobar"]
  window 30, 0, 20, 5, "OMG", @[]
  tb.present()
  sleep 3000
  tb.shutdown()
