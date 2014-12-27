import os, unicode, unsigned
import termbox as tb

# TODO: make independent of termbox for javascript compatibility

type
  BoxIndex = enum sp, ─, │, ┌, ┐, └, ┘, ├, ┤, ┬, ┴, ┼

  Box = array[BoxIndex, Rune]

  Window = object
    x, y, w, h: int
    title: string
    content: seq[string]

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

proc render(ws: openarray[Window]) =
  for w in ws:
    combineCell w.x,     w.y,     ┌, TB_BLACK or TB_BOLD, TB_BLACK
    combineCell w.x+w.w, w.y,     ┐, TB_BLACK or TB_BOLD, TB_BLACK
    combineCell w.x,     w.y+w.h, └, TB_BLACK or TB_BOLD, TB_BLACK
    combineCell w.x+w.w, w.y+w.h, ┘, TB_BLACK or TB_BOLD, TB_BLACK

    for p in w.x+1 .. < w.x+w.w:
      combineCell p, w.y, ─, TB_BLACK or TB_BOLD, TB_BLACK
      combineCell p, w.y+w.h, ─, TB_BLACK or TB_BOLD, TB_BLACK
    for p in w.y+1 .. < w.y+w.h:
      combineCell w.x, p, │, TB_BLACK or TB_BOLD, TB_BLACK
      combineCell w.x+w.w, p, │, TB_BLACK or TB_BOLD, TB_BLACK

  for w in ws:
    for i, line in w.content:
      if i > w.h - 2:
        break
      let text = if line.len > w.w - 3: line[0 .. < w.w - 3] else: line
      tbEcho w.x+2, w.y+1+i, TB_WHITE or TB_BOLD, TB_BLACK, text

  for w in ws:
    if w.title.len > 0:
      let text = if w.title.len > w.w - 5: w.title[0 .. < w.w - 5] else: w.title
      tbEcho w.x+2, w.y, TB_CYAN or TB_BOLD, TB_BLACK, " ", text, " "

proc initWindow(x, y, w, h: int, title = "", content: seq[string] = @[]): Window =
  Window(x: x, y: y, w: w, h: h, title: title, content: content)

when isMainModule:
  usedBox = roundBox
  var
    windows = newSeq[Window]()
    running = true
    event: tbEvent

  windows.add initWindow(0, 0, 30, 5, "Foobarasdjlkasdjaskdjasdklasjdkasdjas", @["abc", "defg", "=)aslkdjaskdlajdklasjdklasjdkasjdklasdjkasldjaskldjaskldj", "c", "d", "e", "f"])
  windows.add initWindow(30, 0, 20, 5, "OMG")
  windows.add initWindow(0, 5, 25, 4, "Dadada")
  windows.add initWindow(25, 5, 25, 4, "Nanana")

  discard tb.init()
  while running:
    render windows
    tb.present()
    case poll_event(addr(event))
    of 0: # No event
      discard
    of TB_EVENT_KEY:
      if event.key == TB_KEY_CTRL_C:
        running = false
    of TB_EVENT_RESIZE:
      discard
    else: # Error
      running = false
  tb.shutdown()
