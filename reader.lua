--[[
CC reader for tagged works

Saves your reading progress for the last opened file

Written during the 2026 October-November outage
]]
local args = {...}
if args[1] == "help" then -- yes i know it can be a hashmap
  print("CC reader")
  print("reader <file.ftxt> - read tagged saved text")
  --print("reader <file.txt> - read untagged text")
  print("reader download <work_id> <file.ftxt> - scrape web and save tagged text")
  print("reader set help - help with settings")
  print("reader set darkmode - dark mode")
  return
end
local function err()
  error("Invalid argument or command; see help")
end
if args[1] == "set" then 
  local c = args[2]
  if c==nil or c=="help" then
    print("...set fgcol 0 255 0 - set text colour to green")
    print("...set bgcol 255 255 255 - set background colour to white")
    print("...set accentcol 183 133 11 - set accent color to mustard yellow")
    print("...set darkmode - swap text and bg colours")
    return
  end
  if c=="darkmode" then
    local f = settings.get("reader.fgcol",0)
    settings.set("reader.fgcol",settings.get("reader.bgcol",0xffffff))
    settings.set("reader.bgcol",f)
    settings.save()
    return
  end
  local argr = args[3]
  if argr == nil then err() end
  local argg = args[4]
  local argb = args[5]
  if argb == nil or argg == nil then err() end
  if c=="fgcol" then -- todo: DRY
    settings.set("reader.fgcol",colours.packRGB(argr+0,argg+0,argb+0))
    settings.save()
    return
  end
  if c=="bgcol" then
    settings.set("reader.bgcol",colours.packRGB(argr+0,argg+0,argb+0))
    settings.save()
    return
  end
  if c=="accentcol" then
    settings.set("reader.accentcol",colours.packRGB(argr+0,argg+0,argb+0))
    settings.save()
    return
  end
end

local w,h = term.getSize()

local reltags = {"\x7f","&","\x0b\x0c","\x0b","\x0c","\x99"}
local scr = math.floor(settings.get("reader.savestate.char",0)/(w-1))
local chap = settings.get("reader.savestate.chapter",0) -- 0 is tag page
local file = settings.get("reader.savestate.file",nil)
if args[1] and file~=args[1] then
  file=args[1]
  chap=0
  scr=0
end

if file==nil then
  error("You have no open works; see help to open any file")
end
local f=fs.open(shell.resolve(file),"r")
if f==nil then error("No such file") end
local work_unpr = f.readAll()
local work = textutils.unserialise(work_unpr)
-- print(work)
-- read()
if work==nil then
  work = {
    ["title"]=shell.resolve(file),
    ["author"]="unknown author",
    ["summary"]="A plain-text document",
    ["tags"]={"Unknown"},
    ["rel"]=0,
    ["contents"]={{["chapter"]="",["text"]=work_unpr,["notes"]={nil,nil}}}}
end
work_unpr = nil
f.close()

local BGC = colours.black
local FGC = colours.white
local ACC = colours.red

-- print(textutils.serialise(work))
-- read()

term.setBackgroundColour(BGC)
term.setBackgroundColour(FGC)
local showuihints = true
if term.isColour() then
  showuihints = settings.get("reader.showkeystrokes", false)
  term.setPaletteColour(BGC,settings.get("reader.bgcol", 0xffffff))
  term.setPaletteColour(FGC,settings.get("reader.fgcol", 0))
  term.setPaletteColour(ACC,settings.get("reader.accentcol", 0x940000))
end

local function resetScreen()
  term.clear()
  term.setCursorPos(1,1)
end

local function sideBar(line, totallines)
  local yb = math.floor((h-2)*line/totallines)+1
  for y=2,h-1 do
    term.setCursorPos(w,y)
    if y==yb then write("\x07")
    else write("|") end
  end
end
local function writeText(ttab,fromline,w)
  local y=2
  for i=fromline+1,fromline+h-2 do
    w.setCursorPos(1,y)
    w.write(ttab[i] or "")
    y=y+1
  end
end
local function processTextToLineTable(text)
  local maxw=w-1

  local result = {} -- https://stackoverflow.com/a/72298997
  for line in string.gmatch(text .. "\n", "(.-)\n") do
    table.insert(result, line)
  end
  local el=1
  while el<=#result do
    if #result[el]>maxw then
      table.insert(result,el,string.sub(result[el],1,maxw)) -- todo: break by last space instead
      result[el+1]=string.sub(result[el+1],maxw+1)
    end
    el=el+1
  end
  table.insert(result,"") -- last line deletes itself sometimes for some reason, so if this is the last line nobody will notice
  return result
end
local function saveAndExit() -- todo: fix functions taking globals
  settings.set("reader.savestate.char",scr*(w-1))
  settings.set("reader.savestate.chapter",chap)
  settings.set("reader.savestate.file",file)
  settings.save()
  term.setPaletteColour(colours.black,term.nativePaletteColour(colours.black))
  term.setPaletteColour(colours.white,term.nativePaletteColour(colours.white))
  term.setPaletteColour(colours.red,term.nativePaletteColour(colours.red))
  term.setCursorPos(1,1)
  term.clear()
  print("Progress saved: chapter "..chap..", line "..scr)
end
local function titlePageToText(c)
  --["title"]="Test Work",["summary"]="a test summary\n\nwololo",["tags"]={"No Archive Warnings Apply","Original Character","Handholding"},
  local title = c.title or "Unknown"
  local author = c.author or "unknown"
  local r = c.rel or 0
  local rtag = reltags[r] or "none"
  local taglist = table.concat(c.tags,", ") or "none"
  local summary = c.summary or "none"
  return "-- "..title.." --\nby "..author.."\n\n"..rtag.."\nTags: "..taglist.."\n\nSummary:\n"..summary
end
local function contentsToText(c,ch_id)
  if ch_id==0 then return titlePageToText(c) end
  -- print(textutils.serialise(c))
  local c = c.contents[ch_id]
  --{ {["chapter"]="hello world", ["text"]="hello world123", ["notes"]={nil,"end"} }, ... }
  local title = "Chapter "..ch_id..". "..c.chapter
  local text = c.text
  local startnotes = ""
  local endnotes = ""
  if c.notes[1] then startnotes="\nNotes:\n"..c.notes[1].."----------\n" end
  if c.notes[2] then endnotes="\n\nNotes:\n"..c.notes[2] end
  return title.."\n\n"..startnotes..text..endnotes
end
local function scrollRedrawBottom(w, shift, scr, ttab)
  w.scroll(shift)
  local wh = h-2
  for y=wh-shift,wh do
    w.setCursorPos(1,y)
    w.write(ttab[scr+y] or "")
  end
end
local function scrollRedrawTop(w, shift, scr, ttab)
  w.scroll(-shift)
  local wh = h-2
  for y=1,shift do
    w.setCursorPos(1,y)
    w.write(ttab[scr+y-1] or "")
  end
end

local function drawTopBar(t)
  term.setBackgroundColour(ACC)
  term.setCursorPos(1,1)
  term.clearLine()
  local title = t.title
  if #title>w-4 then title = string.sub(title,1,w-4)..".." end
  term.write(title)
  term.setCursorPos(w,1)
  term.write("X")
  term.setBackgroundColour(BGC)
end
local function drawBottomBar(t,chap,maxchap)
  term.setBackgroundColour(ACC)
  term.setCursorPos(1,h)
  term.clearLine()
  if chap>0 then term.write("\x11") end -- arrow left

  local title = nil
  if chap>0 then title="Ch. "..chap..". "..t.contents[chap].chapter
  else title="Tags and summary" end
  if #title>w-4 then title = string.sub(title,1,w-6)..".." end
  term.setCursorPos((w-#title)/2,h)
  term.write(title)

  term.setCursorPos(w,h)
  if chap<maxchap then term.write("\x10") end -- arrow right
  term.setBackgroundColour(BGC)
end

local textwindow = window.create(term.current(), 1, 2, w-1,h-2)
local t = processTextToLineTable(contentsToText(work,chap))
local maxscr = #t-h+2
local maxchap = #work.contents

drawTopBar(work)
drawBottomBar(work,chap,maxchap)
writeText(t,scr,textwindow)
while true do
  local chapstart = chap
  local scrstart = scr
  sideBar(scr,maxscr)
  local ev = {os.pullEventRaw()}
  if ev[1]=="terminate" then 
    saveAndExit()
    break
  elseif ev[1]=="key" then
    local k = ev[2]
    if k==keys.down or k==keys.space then scr=scr+1 -- i REALLY need a hashmap here
    elseif k==keys.up then scr=scr-1
    elseif k==keys.left then chap=chap-1
    elseif k==keys.right or k==keys.tab then chap=chap+1
    elseif k==keys.grave or k==keys.x or k==keys.enter or k==keys.backspace then
      saveAndExit()
      break
    end
  elseif ev[1]=="mouse_scroll" then scr=scr+ev[2]
  elseif ev[1]=="term_resize" then
    w,h = term.getSize()

    textwindow = window.create(term.current(), 1, 2, w-1,h-2)
    t = processTextToLineTable(contentsToText(work,chap))
    local maxscr_t = maxscr
    maxscr = #t-h+2
    -- old scroll / new scroll = old max scroll / new max scroll
    -- old scroll * new max scroll / old max scroll = new scroll
    scr = math.floor(scr*maxscr/maxscr_t)
    scrstart=scr
    
    drawTopBar(work)
    drawBottomBar(work,chap,maxchap)
    writeText(t,scr,textwindow)
  elseif ev[1]=="mouse_click" then
     
  end
  if chap<0 then chap=0 end
  if scr<0 then scr=0 end
  if chap>maxchap then chap=maxchap end
  if scr>maxscr then scr=maxscr end

  if scrstart>scr then scrollRedrawTop(textwindow, scrstart-scr, scr, t)
  elseif scrstart<scr then scrollRedrawBottom(textwindow, scr-scrstart, scr, t) end

  if chapstart~=chap then
    scr=0
    t = processTextToLineTable(contentsToText(work,chap))
    maxscr = #t-h+2
    textwindow.clear()
    writeText(t,scr,textwindow)
    drawBottomBar(work,chap,maxchap)
  end
end