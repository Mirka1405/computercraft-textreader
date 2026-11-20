import re
from sys import argv

def replace_tags(s):
  s=re.sub(r' \w+?=.+?>',">",s) # remove html attrs
  return s\
  .replace("<p>","")\
  .replace("</p>","\n\n")\
  .replace("<br>","\n")\
  .replace("<br />","\n")\
  .replace("<hr>","\n\n---------\n\n")\
  .replace("<hr />","\n\n---------\n\n")\
  .replace("<div>","")\
  .replace("</div>","")\
  .replace("<em>","~")\
  .replace("</em>","~")\
  .replace("&mdash;","--")\
  .replace("&rsquo;","'")\
  .replace("&lsquo;","'")\
  .replace("”",'"')\
  .replace("“",'"')\
  .replace("—",'-')\
  .replace("&ldquo;",'"')\
  .replace("&rdquo;",'"')\
  .replace("<span>",'')\
  .replace("</span>",'')\
  .replace("<h1>",'# ')\
  .replace("</h1>",'')\
  .replace("<b>",'*')\
  .replace("</b>",'*')\
  .replace("<i>",'_')\
  .replace("</i>",'_')\
  .replace("‘","'")\
  .replace(chr(160)," ")\
  .strip()

def replace_starting_space(t):
  return re.sub(r'^ +',"",t,flags=re.MULTILINE)
assert replace_starting_space("""   a
  b d
c""")=="a\nb d\nc"

html = open(argv[1] if len(argv)>2 else input("Enter path of the downloaded file in .html format: "),encoding="utf-8").read()

chapters = []
tags = []
# chapter = {"chapter":"abc","text":"""aaaaaa<br>""","notes":[None,"abcdef"]}
point = html.find("<b>")
work_title = html[point+3:(point:=html.find("</b>",point))]
for i in ("Rating","Archive Warning","Category","Fandom","Character","Additional Tags"):
  newpoint = html.find(f"<dt>{i}:</dt>",point)
  if newpoint==-1:continue
  point=newpoint

  while True:
    point = html.find('">',point)
    endpoint = html.find("</a>",point)
    endgroup = html.find("</dd>",point)
    tags.append(html[point+2:(point:=endpoint)])
    if endpoint+4==endgroup: break

rel = 0
for i,v in enumerate(("Gen","F/M", "M/M", "F/F", "Multi"),start=1):
  if v in tags: rel=i

point = html.find('<div class="byline">',point)
point = html.find('">',point+19)
author = html[point+2:(point:=html.find("</a>",point))]

work_summary = ""
summary = html.find("<p>Summary</p>",point)
if summary!=-1:
  point=html.find('">',summary+1)
  work_summary = replace_tags(html[point+2:(point:=html.find("</blockquote>",point))])

notes = html.find("<p>Notes</p>",point)
if notes!=-1:
  point=html.find('">',notes+1)
  work_summary += "\n\nWork notes:\n"+replace_tags(html[point+2:(point:=html.find("</blockquote>",point))])

multiple_chapters = html.find('<h2 class="heading">',point) != -1

while multiple_chapters:
  # print("processing",point)
  point=html.find('<h2 class="heading">',point+1)
  if point == -1: break
  chap_title = replace_starting_space(html[point+20:(point:=html.find("</h2>",point))])
  chap_title=" ".join(chap_title.split(maxsplit=2)[2:])
  # print("chapter",chap_title)
  notes = [None,None]
  start_note = html.find('<p>Chapter Notes</p>',point)
  if start_note!=-1:
    end_note=html.find("</div>",start_note)
    if '<div class="endnote-link">' not in html[start_note:end_note]:
      start_note=html.find('<blockquote class="userstuff">',start_note,end_note)
      assert start_note!=-1
      start_note=html.find('">',start_note+1)
      notes[0] = replace_tags(html[point+2:(point:=html.find("</blockquote>",start_note,end_note))])
      point = end_note

  content = ""
  point=html.find('<!--chapter content-->',point)
  point=html.find('">',point+1)
  endpoint=html.find('<!--/chapter content-->',point)
  # print(locals())
  # print("end content",endpoint)
  content=replace_tags(html[point+2:endpoint])
  # if endpoint==13077: print(content)
  # print(content)

  start_note = html.find('<p>Chapter End Notes</p>',endpoint,endpoint+92)
  # print(html[start_note:start_note+400])
  print("note start",start_note)
  if start_note!=-1:
    end_note=html.find("</blockquote>",start_note)
    print("note end",end_note)
    start_note=html.find('<blockquote class="userstuff">',start_note,end_note)
    # print(html[start_note:start_note+400])
    assert start_note!=-1
    start_note=html.find('">',start_note+1)
    # print(html[start_note:start_note+400])
    notes[1] = replace_tags(html[start_note+2:(point:=html.find("</blockquote>",start_note))])
    # if endpoint==13077: print(notes)
    # point = end_note

  # print(len(notes[1]))

  point=endpoint+1
  chapters.append({"chapter":chap_title,"text":content,"notes":notes})
else:
  point=html.find('<h2 class="toc-heading">',point)
  chap_title = replace_starting_space(html[point+24:(point:=html.find("</h2>",point))])
  point = html.find('<div class="userstuff">',point)
  endpoint=html.find('</div>\n\n<div id="afterword">',point)
  content = replace_tags(html[point:endpoint])
  notes = [None,None]
  endnotes = html.find('<p>End Notes</p>',endpoint)
  if endnotes!=-1:
    point=html.find('">',endnotes+1)
    notes[1] = replace_tags(html[point+2:(point:=html.find("</blockquote>",point))])
  chapters.append({"chapter":chap_title,"text":content,"notes":notes})

tagstr = ",".join(f'"{i}"' for i in tags)
n = lambda s: "nil" if s is None else f"[[{s}]]"
chapstr=",".join(('{["chapter"]=[[%s]],["text"]=[[%s]],["notes"]={%s,%s}}' % (v["chapter"],v["text"],n(v["notes"][0]),n(v["notes"][1]))) for v in chapters)

print('{["author"]="%s",["title"]="%s", ["summary"]=[[%s]], ["rel"]=%d, ["tags"]={%s}, ["contents"]={%s}}'
      % (author, work_title, work_summary, rel, tagstr, chapstr), file=open(f"{id}.ftxt","w",encoding="utf-8"))