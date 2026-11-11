"""Collect tagged text work from https://catscradle.neocities.org/."""
import requests as rq
import re

def search_for(haystack,start,end):
  mn=haystack.find(start)
  assert mn!=-1, f"start not found"
  mn+=len(start)
  mx=haystack.find(end,mn)
  assert mx!=-1, f"end not found"
  return haystack[mn:mx].strip()
def replace_tags(s):
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
  .strip() # there probably is a better way to do this

def replace_starting_space(t):
  return re.sub(r'^ +',"",t,flags=re.MULTILINE) # also probably must be a better way to do this


def get_chapter(i):
  return rq.get(f"https://catscradle.neocities.org/chapter-{i}.html").text
def p(args):
  print(args)
  return args

file = '''{["title"]="Cat\'s Cradle",["author"]="Kurt Vonnegut",["rel"]=1,["summary"]=[[(From https://catscradle.neocities.org/)

For Kenneth Littquer,
a man of gallantry and taste.

Nothing in this book is true.

"Live by the foma* that makes you brave and kind and healthy and happy."
-The Books of Bokonon. 1:5
* Harmless untruths ]],["tags"]={"no tags"},["contents"]={'''

chapters = []
# chapter: {["chapter"]="hello world",["text"]="hello world1234",["notes"]={nil,"end"}}

for i in range(1,128):
  print(f"Scraping chapter {i}")
  raw = get_chapter(i)
  if i==127:
    # last page doesn't have a "next page" button, and the easiest solution is to mimic it not to break the parser
    raw=raw.replace("</p>\n    </div>",'<p style="text-align: right;">')
  chapter = search_for(raw,'<hr />','<p style="text-align: right;">').split("\n",maxsplit=1)
  title = chapter[0].removeprefix("<h3>").removesuffix("</h3>").split(maxsplit=1)[1]
  # god i want pipelines from elixir |> |> |>
  text = replace_tags(replace_starting_space(chapter[1]))
  chapters.append('{'f'["chapter"]="{title}",["text"]=[[{text}]],["notes"]=''{nil,nil}}')
  #break

file+=",".join(chapters)+'}}'

with open("catscradle.ftxt","w") as f:
  f.write(file)

q=set(re.findall(r"&.*?;",file))
assert len(q)==0, q
# note: i manually Ctrl+F'd over all rsquos because im tired of fixing titles too