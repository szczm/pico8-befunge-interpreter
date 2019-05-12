pico-8 cartridge // http://www.pico-8.com
version 17
__lua__
-- befunge-93 interpreter
-- by @szczm_

local cur={ x=0, y=0 }
local status="edit" -- no enums in lua
local input=""
local hint, hint_i="", ""
local last_press=t()

-- when cpu starts interpreting
function running_cb()
  status="running"
end

-- when cpu prompts for a character
function prompt_char_cb()
  status="prompt_char"
end

-- when cpu prompts for a number
function prompt_numeric_cb()
  status="prompt_numeric"
  input=""
end

-- when cpu is done interpreting
function stopped_cb()
  status="edit"
end

function _init()
  poke(24365, 1) -- enable keyboard support

  settings.init()
  cpu.init({
    prompt_char=prompt_char_cb,
    prompt_numeric=prompt_numeric_cb,
    running=running_cb,
    stopped=stopped_cb
  })  
end

function _update60()
  if status == "running" then
    -- stat(30) - is key press available
    -- stat(31) - get corresponding char

    if stat(30) and stat(31) == "\t" then
      cpu.stop()
    else
      cpu.resume()
      return
    end
  end
  
  if status == "prompt_numeric" then
    if stat(30) then
      local c=stat(31)
      local _, success=toascii(c)
      
      -- if not printable/desired
      if (not success) return

      -- if printable
      if c ~= "\r" and c ~= "\t" and c ~= "\b" then
        log.put(c)
        input=input .. c
      end
    
      -- if backspace
      if c == "\b" then
        log.unput()
        input=sub(input, 0, max(0, #input-1))
      end

      -- if tab/enter
      if c=="\r" or c=="\t" then
        log.put("\r")
        cpu.resume(input)
      end
    end
    
    return
  elseif status == "prompt_char" then
    if (not stat(30)) return
    
    local c=stat(31)
    local _, success=toascii(c)
    
    if success then
      log.put(tochar(c))
      cpu.resume(c)
    end
    
    return
  end -- elseif mode=="edit"
  
  local x, y=cur.x, cur.y

  -- cursor movement
  if (btnp(0)) x-=1
  if (btnp(1)) x+=1
  
  if (btnp(2)) y-=1
  if (btnp(3)) y+=1
    
  x%=grid.w
  y%=grid.h
  
  if stat(30) then
    local c=stat(31)
    
    if c ~= "\r" and c ~= "\t" and c ~= "\b" then
      local _, success=toascii(c)
      
      if success then
        grid[y+1][x+1]=c
        x+=1
      end
    end
    
    if c == "\b" then
      grid[y+1][x+1]=" "
      x-=1
      sound.play(36)
    end
    
    if c == "\t" then
      if (settings.autosave) settings.save_code()
      cpu.start()
    end
  end
  
  if x ~= cur.x or y ~= cur.y then
    cur.x=x%grid.w
    cur.y=y%grid.h

    last_press=t()
    hint,hint_i=nil
    
    sound.play()
  end
  
  if t() > last_press+1 and not hint_i then
    hint_i=grid[cur.y+1][cur.x+1]
    hint=hints[hint_i]
  end
end

function _draw()
  -- cls()
  
  -- draw code
  draw.grid_area(0, 0, colors.code.bg)
  
  if status == "edit" then
    -- draw edit cursor w/shadow
    draw.cell(cur.x, cur.y, colors.code.fg, true)
  else
    cpu.draw_cursor()
  end

  -- draw grid
  for y=0, grid.h-1 do for x=0, grid.w-1 do
    local c, d
    local char=grid[y+1][x+1]
    local cursor_on=y == cur.y and x == cur.x and status == "edit"

    -- draw nonp. as a "glitch"
    if type(char)~="string" then
      char=tochar(flr(33 + rnd(96-33)))
      c=colors.nonprintable
    end

    -- if cursor placed on cell
    if cursor_on then
      c=colors.code.bg
    else
      c=c or colors.code.fg -- don't overwrite the "bug" color
    end
    
    -- shadowed if cursor on
    draw.char(char, x, y, c, cursor_on)
  end end
  
  -- draw log
  draw.grid_area(0, grid.area.h, colors.log.bg)
  
  for y=1, #log do
    local s=log[y]
    
    for x=1, #s do
      draw.char(sub(s, x, x), x-1, y-1+grid.h, colors.log.fg)
    end
  end
  
  log.draw_cursor()

  -- draw hint
  if (status == "edit" and hint) draw.hint(hint, hint_i)
end
-->8
-- cpu
--
-- this is the interpreter
-- engine. named cpu, because
-- it's shorter than "engine",
-- and definitely shorter than
-- "interpreter".
cpu={}

-- callbacks used for
-- communication with cpu;
-- see cpu.init()
cpu._callbacks={
  prompt_char=function() end,
  prompt_numeric=function() end,
  running=function() end,
  stopped=function() end
}

-- currently only assigns
-- callbacks used for comm.
--
-- arguments:
-- - callbacks: table
--     contains callbacks to
--     used for cpu<->main loop
--     communication; callback
--     names should match the
--     ones assigned in
--     cpu._callbacks
function cpu.init(callbacks)
  assert(callbacks == nil or type(callbacks) == "table", "argument to cpu.init should be a table")
  for name, func in pairs(callbacks) do
    assert(cpu._callbacks[name], "cpu callback with given name does not exist")
    assert(type(func) == "function", "given cpu callback is not a function")

    cpu._callbacks[name]=func
  end
end

-- sets initial values and 
-- starts the interpreting
-- proccess
function cpu.start()
  cpu._coroutine=cocreate(cpu._interpret)
  cpu._stack={}
  cpu._ip={ x=0, y=0, u=1, v=0 }
  cpu._ascii_mode=false
  
  settings.set_menuitem("stop_code")

  cpu.resume()
end

-- continue the interpreting
-- process and optionally pass
-- provided data to the inter-
-- preting function
--
-- arguments:
-- - ...: any
--     any arguments that need
--     to be passed to the cpu,
--     context-dependent
function cpu.resume(...)
  cpu._callbacks.running()
  coresume(cpu._coroutine, ...)
end

-- stop the execution (through
-- menus, '@' instruction etc.)
function cpu.stop()
  cpu._coroutine=nil
  cpu._callbacks.stopped()
  settings.set_menuitem("run_code")
end

-- draw instruction pointer
function cpu.draw_cursor()
  draw.cell(cpu._ip.x, cpu._ip.y, colors.ip.bg)
end

 -----------------------------
-- private zone do not enter --
 -----------------------------

cpu._ascii_mode=false
cpu._coroutine=nil
cpu._stack={}

-- short for instruction pointer
cpu._ip={ x=0, y=0, u=1, v=0 }

-- main interpreting function,
-- designed solely for use
-- through a coroutine
function cpu._interpret()
  while true do
    local i=grid[cpu._ip.y+1][cpu._ip.x+1]
    sound.play(toascii(i) - 32)

    if (debug.print) printh("instruction: " .. i)
    
    if not cpu._ascii_mode then
      if i == "v" then
        cpu._ip.u, cpu._ip.v=0, 1
      elseif i == "^" then
        cpu._ip.u, cpu._ip.v=0, -1
      elseif i == ">" then
        cpu._ip.u, cpu._ip.v=1, 0
      elseif i == "<" then
        cpu._ip.u, cpu._ip.v=-1, 0
      elseif i == "?" then
        -- generate cardinal direction
        local a=flr(rnd(4))/4
        cpu._ip.u, cpu._ip.v=cos(a), sin(a)
      elseif tonum(i) then -- if is a number
        cpu._push(tonum(i))
      elseif i == "+" then
        local b, a=cpu._pop(), cpu._pop()
        cpu._push(a+b)
      elseif i == "-" then
        local b, a=cpu._pop(), cpu._pop()
        cpu._push(a-b)
      elseif i == "*" then
        local b, a=cpu._pop(), cpu._pop()
        cpu._push(a*b)
      elseif i == "/" then
        local b, a=cpu._pop(), cpu._pop()
        cpu._push(flr(a/b))
      elseif i == "%" then
        local b, a=cpu._pop(), cpu._pop()
        cpu._push(a%b)
      elseif i == "!" then
        local a=cpu._pop()
        cpu._push(a == 0 and 1 or 0)
      elseif i == "`" then
        local b, a=cpu._pop(), cpu._pop()
        cpu._push(a>b and 1 or 0)
      elseif i == "_" then
        local a=cpu._pop()
        cpu._ip.u, cpu._ip.v=(a == 0 and 1 or -1),0
      elseif i == "|" then
        local a=cpu._pop()
        cpu._ip.u, cpu._ip.v=0,(a == 0 and 1 or -1)
      elseif i == '"' then
        cpu._ascii_mode=true
      elseif i == ":" then
        local a=cpu._pop()
        cpu._push(a)
        cpu._push(a)
      elseif i == "\\" then
        local b, a=cpu._pop(), cpu._pop()
        cpu._push(b)
        cpu._push(a)
      elseif i == "$" then
        cpu._pop()
      elseif i == "," then
        local a, success=tochar(cpu._pop())
        log.put(success and a or " ")
      elseif i == "." then
        local a=cpu._pop()
        log.put(tostr(a) .. " ")
      elseif i == "#" then
        cpu._ip.x+=cpu._ip.u
        cpu._ip.y+=cpu._ip.v
      elseif i == "p" then
        local y, x, v=cpu._pop(), cpu._pop(), cpu._pop()
        grid[y%grid.h+1][x%grid.w+1]=tochar(v)
      elseif i == "g" then
        local y, x=cpu._pop(), cpu._pop()
        local c=grid[y%grid.h+1][x%grid.w+1]
        if (type(c) == "string") c=toascii(c)
        cpu._push(c)
      elseif i == "&" then
        cpu._callbacks.prompt_numeric()
        local message=yield()
        assert(type(message) == "string", "arguments given to cpu should be of string type")
        cpu._push(tonum(message))
      elseif i == "~" then
        cpu._callbacks.prompt_char()
        local message=yield()
        assert(type(message) == "string", "arguments given to cpu should be of string type")
        cpu._push(toascii(message))
      elseif i == "@" then
        cpu.stop()
        return
      end
    else
      if i == '"' then
        cpu._ascii_mode=false
      else
        cpu._push(toascii(i))
      end
    end
    
    if debug.print then
      s=""
      for v in all(cpu._stack) do s=s .. ", " .. v end
      printh("stack: " .. sub(s, 3))
    end
  
    cpu._ip.x+=cpu._ip.u
    cpu._ip.y+=cpu._ip.v
    
    cpu._ip.x%=grid.w
    cpu._ip.y%=grid.h
  
    if (debug.step) yield()
  end
end

-- pop value from stack and
-- return it; return 0 if stack
-- is empty
-- 
-- returns: number
function cpu._pop()
  local v=cpu._stack[#cpu._stack]
  cpu._stack[#cpu._stack]=nil
  return v or 0
end

-- push value to stack
--
-- arguments:
-- - v: number
--   a value to be pushed
function cpu._push(v)
  assert(type(v) == "number", "somehow, a " .. type(v) .. " got into the stack. that shouldn't be possible.")
  add(cpu._stack, v)
end

-->8
-- grid
--
-- holds data about the code,
-- also about the grid and cell
-- area/size
grid={}

-- area in which the cells
-- should fit, in pixels
grid.area={ w=128, h=64 }

-- pixel size of a single cell
grid.cell={ w=4, h=8 }

-- width/height in cells
grid.w=grid.area.w/grid.cell.w
grid.h=grid.area.h/grid.cell.h

-- clear the grid, assigning
-- " " (noop) to all cells
function grid.clear()
  for y=1, grid.h do
    grid[y]={}
    
    for x=1, grid.w do
      grid[y][x]=" "
    end
  end
end
-->8
-- settings/debug
--
-- the settings class is used
-- for operations like saving
-- or loading the code grid,
-- toggling sound, autosaving
-- and handling options avail-
-- able in the menu
--
-- since pico-8 provides only
-- 256 bytes of save data, and
-- more than that is required,
-- code data is saved to a se-
-- parate cart

debug={
  -- print stack/instructions
  -- to the console
  print=false,
  
  -- show every cpu step
  step=true
}

settings={}

settings.autosave=true
settings.sound=true

-- settings.get_menuitems() is
-- used to strictly control the
-- few (6) possible menuitems
-- and is assigned runtime to
-- avoid missing references
function settings.get_menuitems()
  return {
    run_code={ id=1, label="run code", callback=function()
      if (settings.autosave) settings.save_code()
      cpu.start()
    end },
    stop_code={ id=1, label="stop code", callback=cpu.stop, init=false },
    save_code={ id=2, label="save", callback=settings.save_code },
    clear_grid={ id=3, label="clear grid", callback=grid.clear },
    enable_autosave={ id=4, label="enable autosave", callback=settings._enable_autosave, init=false },
    disable_autosave={ id=4, label="disable autosave", callback=settings._disable_autosave },
    enable_sound={ id=5, label="enable sound", callback=settings._enable_sound, init=false },
    disable_sound={ id=5, label="disable sound", callback=settings._disable_sound },
  }
end

-- add inital menuitems and
-- load the code
function settings.init()
  settings._add_menuitems()
  settings._load_code()
end

-- set one of the menuitems
-- available in the settings.
-- .get_menuitems(); if menu-
-- item with matching id is
-- already set, replace it
--
-- arguments:
-- - name: string
--   names a menuitem item de-
--   signated in settings.
--   .get_menuitems() to be set
function settings.set_menuitem(name)
  assert(type(name) == "string", "argument to settings.set_menuitem should be a string")
  assert(settings.menuitems[name], "menuitem with given name does not exist")

  local opts=settings.menuitems[name]
    
  menuitem(opts.id, opts.label, opts.callback)
end

-- saves code to separate cart
function settings.save_code()
  for y=1, grid.h do
    for x=1, grid.w do
      local char=grid[y][x]
      
      if type(char) == "string" then
        poke(
          settings._code_address + (y-1)*grid.w + (x-1),
          toascii(char)
        )
      end
    end
  end
  
  cstore(
    settings._code_address,
    settings._code_address,
    grid.w*grid.h,
    settings._save_filename
  )
end

 -----------------------------
-- private zone do not enter --
 -----------------------------

settings._save_filename="_picofunge_save.p8"

-- address to which, and from,
-- the code data will be copied.
-- should point to an unused
-- area in memory
settings._code_address=0x1000

-- assign the menuitems field
-- and add initial items
function settings._add_menuitems()
  if (settings.menuitems) return
  
  settings.menuitems = settings.get_menuitems()
  
  for name, opts in pairs(settings.menuitems) do
    if opts.init ~= false then
      settings.set_menuitem(name)
    end
  end
end

-- load code from separate cart
-- and assigns it to the grid
function settings._load_code()
  grid.clear()

  reload(
    settings._code_address,
    settings._code_address,
    grid.w*grid.h,
    settings._save_filename
  )
  
  for y=1, grid.h do
    for x=1, grid.w do
      local val=peek(settings._code_address + (y-1)*grid.w + (x-1))
      local char, success=tochar(val)
      
      if (success) grid[y][x]=char
    end
  end
end

function settings._enable_autosave()
  settings.autosave=true
  settings.set_menuitem("disable_autosave")
end

function settings._disable_autosave()
  settings.autosave=false
  settings.set_menuitem("enable_autosave")
end

function settings._enable_sound()
  settings.sound=true
  settings.set_menuitem("disable_sound")
end

function settings._disable_sound()
  settings.sound=false
  settings.set_menuitem("enable_sound")
end
-->8
-- sound
--
-- currently holds just one
-- function used to play a note
sound={}

-- play a single sine note
-- passed as the argument (with
-- 0 being c0, and 63 d#5)
function sound.play(i)
  assert(i == nil or type(i) == "number", "argument to sound.play should be a number")
  
  i=i or sound._default_note

  if type(i) == "number" and settings.sound then
    poke(0x3200, i) -- sfx 0 address
    sfx(0)
  end
end

 -----------------------------
-- private zone do not enter --
 -----------------------------

-- default note is c2
sound._default_note=24
-->8
-- log
--
-- holds text displayed in the
-- log section, and facilitates
-- printing/erasing operations
log={ "" }

-- erase one character
function log.unput()
  if #log == 1 and #log[#log] == 0 then
    return
  end
  
  local row=log[#log]
  
  if #row == 0 and #log > 1 then
    log[#log]=nil
    row=log[#log]
  end

  row=sub(row, 1, #row-1)
    
  log[#log]=row
end

-- takes a string and adds it
-- to the log, taking into
-- account line breaks and such
--
-- arguments:
-- - s: string
--   text to add to the log
function log.put(s)
  assert(type(s) == "string", "argument to log.put should be a string")
  
  for i=1, #s do
    local c=sub(s, i, i)
    
    if c == "\r" or c == "\t" then
      add(log, "")
    else
      log[#log]=log[#log] .. c
    end
    
    if #log[#log] >= grid.w then
      add(log, "")
    end
    
    if #log > grid.h-1 then
      del(log, log[1])
    end
  end
end

-- draws the caret
function log.draw_cursor()
  local x, y=#log[#log], #log-1+grid.h
  local c=(t() % log._blink_period < log._blink_period/2) and colors.log.fg or colors.log.bg
  
  draw.cell(x, y, c)
end

 -----------------------------
-- private zone do not enter --
 -----------------------------

-- period (in secs), in which
-- the caret should blink once
log._blink_period=0.8
-->8
-- colors/helpers/hints

colors={
  code={ bg=3, fg=11 },
  log={ bg=0, fg=7 },
  hint={ bg=9, fg=5 },
  ip={ bg=9 },
  nonprintable=0,
  shadow=1
}

-- as pico lacks ascii-char
-- conversion, a string lookup
-- is used. pico treats enter/
-- return key is "\r", and "\n"
-- is not used, which is why it
-- is used as a trap/an unknown
-- symbol.

-- tries to convert given char
-- to its ascii value; if con-
-- verted succesfully, returns
-- ascii value, otherwise re-
-- turns the passed char. as
-- second value returns status
--
-- arguments:
-- - c: string
--   the character to try and
--   convert into ascii
--
-- returns: number, string
local str_ascii="\n\n\n\n\n\n\n\n\t\n\n\n\r\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n !\"#$%&'()*+,-./0123456789:;<=>?@abcdefghijklmnopqrstuvwxyz[\\]^_`\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n{|}~"
function toascii(c)
  assert(type(c) == "string", "argument passed to toascii should be a string")
  
  for i=1, #str_ascii do
    if (sub(str_ascii, i, i) == c) return i, true
  end
  
  return c, false
end

-- works the same as toascii,
-- just in reverse
--
-- returns: the same as toascii,
--          just not in reverse
function tochar(i)
  assert(type(i) == "number", "argument to tochar should be a number")

  local c=sub(str_ascii, i, i)
  
  if c == "" or c == "\n" then
    return i, false
  else
    return c, true
  end
end

-- source: https://git.catseye.tc/befunge-93/blob/master/doc/befunge-93.markdown#appendix-a-command-summary
hints={
  ["+"]="pop a and b, push a+b; in string mode: push ascii value (43)",
  ["-"]="pop a and b, push a-b; in string mode: push ascii value (45)",
  ["*"]="pop a and b, push a*b; in string mode: push ascii value (42)",
  ["/"]="pop a and b, push a/b; in string mode: push ascii value (47)",
  ["%"]="pop a and b, push a%b; in string mode: push ascii value (37)",
  ["!"]="pop a, push 0 if a != 0, 1 otherwise; in string mode: push ascii value (33)",
  ["`"]="pop a and b, push 1 if a is greater than b, 0 otherwise; in string mode: push ascii value (96)",
  [">"]="go right; in string mode: push ascii value (62)",
  ["<"]="go left; in string mode: push ascii value (60)",
  ["^"]="go up; in string mode: push ascii value (94)",
  ["v"]="go down;; in string mode: push ascii value (86)",
  ["?"]="go in random direction; in string mode: push ascii value (63)",
  ["_"]="pop a, go right if a equals 0, left otherwise; in string mode: push ascii value (95)",
  ["|"]="pop a, go up if a equals 0, down otherwise; in string mode: push ascii value (124)",
  ["\""]="string mode; until next \", push all characters as ascii values",
  [":"]="duplicate topmost value on stack; in string mode: push ascii value (58)",
  ["\\"]="swap two topmost values on stack; in string mode: push ascii value (92)",
  ["$"]="discard topmost value on stack; in string mode: push ascii value (36)",
  ["."]="pop value and output it as a number; in string mode: push ascii value (46)",
  [","]="pop value and output it as a character",
  ["#"]="skip next instruction; in string mode: push ascii value (35)",
  ["g"]="pop y, x, get value at corresponding coordinates and push it; in string mode: push ascii value (71)",
  ["p"]="pop y, x, v, put v at coordinates x, y; in string mode: push ascii value (80)",
  ["&"]="prompt for number and push it; in string mode: push ascii value (38)",
  ["~"]="prompt for one character and push it's ascii value; in string mode: push ascii value (126)",
  ["@"]="end program; in string mode: push ascii value (64)",
  ["1"]="push 1; in string mode: push ascii value (49)",
  ["2"]="push 2; in string mode: push ascii value (50)",
  ["3"]="push 3; in string mode: push ascii value (51)",
  ["4"]="push 4; in string mode: push ascii value (52)",
  ["5"]="push 5; in string mode: push ascii value (53)",
  ["6"]="push 6; in string mode: push ascii value (54)",
  ["7"]="push 7; in string mode: push ascii value (55)",
  ["8"]="push 8; in string mode: push ascii value (56)",
  ["9"]="push 9; in string mode: push ascii value (57)",
  ["0"]="push 0; in string mode: push ascii value (48)",
  ["a"]="in string mode: push ascii value (65)",
  ["b"]="in string mode: push ascii value (66)",
  ["c"]="in string mode: push ascii value (67)",
  ["d"]="in string mode: push ascii value (68)",
  ["e"]="in string mode: push ascii value (69)",
  ["f"]="in string mode: push ascii value (70)",
  ["h"]="in string mode: push ascii value (72)",
  ["i"]="in string mode: push ascii value (73)",
  ["j"]="in string mode: push ascii value (74)",
  ["k"]="in string mode: push ascii value (75)",
  ["l"]="in string mode: push ascii value (76)",
  ["m"]="in string mode: push ascii value (77)",
  ["n"]="in string mode: push ascii value (78)",
  ["o"]="in string mode: push ascii value (79)",
  ["q"]="in string mode: push ascii value (81)",
  ["r"]="in string mode: push ascii value (82)",
  ["s"]="in string mode: push ascii value (83)",
  ["t"]="in string mode: push ascii value (84)",
  ["u"]="in string mode: push ascii value (85)",
  ["w"]="in string mode: push ascii value (87)",
  ["x"]="in string mode: push ascii value (88)",
  ["y"]="in string mode: push ascii value (89)",
  ["z"]="in string mode: push ascii value (90)",
  [" "]="no-op (no operation); do nothing; in string mode: push ascii value (32)"
}
-->8
-- draw
--
-- used to standardize/unify
-- the commonly used drawing
-- methods and declutter the
-- main _draw function
draw={}

-- draws a cell grid on given
-- cell coordinates
--
-- arguments:
-- - x, y, c: number
--   respectively, the x and y
--   coordinates and colour of
--   cell to be drawn
-- - shadow: boolean
--   should the cell be drawn
--   with a shadow?
function draw.cell(x, y, c, shadow)
  assert(type(x) == "number", "first argument to draw.cell should be a number")
  assert(type(y) == "number", "second argument to draw.cell should be a number")
  assert(type(c) == "number", "third argument to draw.cell should be a number")
  assert(shadow == nil or type(shadow) == "boolean", "third argument to draw.cell should be a boolean")

  local x=x*grid.cell.w
  local y=y*grid.cell.h
  local w=grid.cell.w
  local h=grid.cell.h
  local dy=(shadow and -1 or 0)
  
  rectfill(x, y, x+w, y+h, colors.shadow)
  rectfill(x, y+dy, x+w, y+h+dy, c)
end

-- draws the area of a grid
--
-- arguments:
-- - x, y, c: number
--   respectively, the x and y
--   coordinates of area start
--   and colour of the area
--   to be drawn
function draw.grid_area(x, y, c)
  assert(type(x) == "number", "first argument to draw.cell should be a number")
  assert(type(y) == "number", "second argument to draw.cell should be a number")
  assert(type(c) == "number", "third argument to draw.cell should be a number")

  rectfill(x, y, x+grid.area.w, y+grid.area.h, c)
end

-- draws a char inside a corres-
-- ponding cell
--
-- arguments:
-- - char: string
--   a character to be drawn
-- - x, y, c: number
--   respectively, the x and y
--   coordinates and colour of
--   cell to be drawn
-- - shadow: boolean
--   should the cell be drawn
--   with a shadow?
function draw.char(char, x, y, c, shadow)
  assert(type(char) == "string", "first argument to draw.char should be a string")
  assert(type(x) == "number", "second argument to draw.char should be a number")
  assert(type(y) == "number", "third argument to draw.char should be a number")
  assert(type(c) == "number", "fourth argument to draw.char should be a number")
  assert(shadow==nil or type(shadow) == "boolean", "fifth argument to draw.char should be a boolean")

  local dy=(shadow and -1 or 0)
  print(char, grid.cell.w*x + 1, grid.cell.h*y + 2+dy, c)
end

-- draws the hint that desc-
-- ribes the instruction in the
-- currently selected cell
--
-- arguments:
-- - hint: string
--   instruction description 😐
-- - hint_i: string
--   instruction symbol
function draw.hint(hint, hint_i)
  assert(type(hint) == "string", "first argument to draw.hint should be a string")
  assert(type(hint_i) == "string", "second argument to draw.hint should be a string")
  
  local x, y=3, 0.5
  local z=1
  
  -- draw first background part
  rectfill(0, grid.area.h, grid.area.w, grid.area.h + 2*grid.cell.h, colors.hint.bg)
  
  -- print hint with linebreaks
  for i=1, #hint do    
    if x + i-z > grid.w-2 then
      x, y=3, y+1
      rectfill(0, grid.area.h + y*grid.cell.h, grid.area.w, grid.area.h + (y + 1.5)*grid.cell.h, colors.hint.bg)
    end

    if sub(hint, i, i) == " " then      
      print(sub(hint, z, i), x*grid.cell.w + 1, grid.area.h + y*grid.cell.h + 2, colors.hint.fg)
      x+=i-z+1
      z=i+1
    end
  end

  -- print last word
  print(sub(hint, z), x*grid.cell.w + 1, grid.area.h + y*grid.cell.h + 2, colors.hint.fg)

  -- draw symbol  
  draw.cell(1, grid.h+0.5, colors.hint.fg, true)
  draw.char(hint_i, 1, grid.h+0.5, colors.hint.bg, true)
end
__label__
3333333333333333333333333333bbbbb33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
3333333333333333333333333333b333b33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
3bbb3bbb33333bbb3b3b3bbb3bbbb3b3bb3b3333333333333333333333333333333333333bbb333333b333333333333333333333333333333333333333333333
3b3b333b33b33b3b33b33b3b333bb333bb3b3333333333333333333333333333333333333bb333b333b333333333333333333333333333333333333333333333
3bbb3bbb3bbb3bbb3bbb3b3b333bb3bbbb3b33333333333333333333333333333333333333bb333333b333333333333333333333333333333333333333333333
333b3b3333b3333b33b33b3b333bb3bbbbbb33b3333333333333333333333333333333333bbb33b333b333333333333333333333333333333333333333333333
333b3bbb3333333b3b3b3bbb333bbbbbb3b33b333bbb333333333333333333333333333333b3333333b333333333333333333333333333333333333333333333
3333333333333333333333333333bbbbb33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333331111133333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
3b3333333333333333333333333333333b33333333b33333333b33333333333333333333333333333b333333333333333bbb3bbb33bb33b33b3b33b3333333b3
33b3333333333333333333333333333333b333b33b3b33b333b3333333333333333333333333333333b3333333333333333b3b3b3b3333b33bbb3b3b33333b3b
333b3333333333333333333333333333333b3333333333333b333333333333333333333333333333333b333333333333333b3b3b3b3333b33b3b3b3b33333333
33b3333333333333333333333333333333b333b3333333b333b3333333333333333333333333333333b3333333333333333b3b3b3b3b33333bbb3b3333333333
3b3333333333333333333333333333333b33333333333333333b33333333333333333333333333333b33333333333333333b3bbb3bbb33b33b3b33bb3bbb3333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33b3333333333b333bbb3bbb33333bb333bb3bbb3bbb3b3b3bbb33bb3bbb3bbb3b333bbb33bb333333bb3bbb33333bbb3bbb3bbb3bbb333333bb3bb33b3b333b
3b3b33b333b33b33333b3b3b33b333b33b33333b3b3b3b3b3b3b3b3b33b333b33b333b333b3333333b3b3b3333333b3b3b333b333b3b33333b3b3b3b3b3b33b3
333333333bbb3bbb333b3b3b3bbb33b33b33333b3b3b33333bb33b3b33b333b33b333bb33bbb33333b3b3bb333333bb33bb33bb33bb333333b3b3b3b33333b33
333333b333b33b3b333b3b3b33b333b33b3b333b3b3b33333b3b3b3b33b333b33b333b33333b33333b3b3b3333333b3b3b333b333b3b33333b3b3b3b333333b3
3333333333333bbb333b3bbb33333bbb3bbb333b3bbb33333bbb3bb333b333b33bbb3bbb3bb333333bb33b3333333bbb3bbb3bbb3b3b33333bb33b3b3333333b
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
3b333b3b33bb3bbb3b333bbb3bbb33bb3bbb3b3b3bbb3bbb33bb3bb333333bbb3b333bbb33333b3b33333b333b333bbb3b3b33333bbb3b3b3bbb33333b3b33b3
33b33b3b3b333b333b3333b333b33b3b3b3b3b3b3b3b333b3b3333b333b33b3b3b33333b33b33b3b33333b333b333b3b3b3b33333b333b3b33b333333b3b3b3b
333b33333bbb3bb33b3333b333b33b3b3bb333333b3b333b3b3333b33bbb3b3b3bbb333b3bbb333333333b333b333bbb3b3b33333bb33bbb33b3333333333333
33b33333333b3b333b3333b333b33b3b3b3b33333b3b333b3b3b33b333b33b3b3b3b333b33b3333333b33b333b333b3b3bbb33333b333b3b33b3333333333333
3b3333333bb33bbb3bbb33b333b33bb33bbb33333bbb333b3bbb3bbb33333bbb3bbb333b333333333b333bbb3bbb3b3b3bbb33333bbb3b3b33b3333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33b33b3b333333bb3bbb33333bbb3bbb3bbb3bbb3b3b33333bbb3b333b3b3bbb3bbb3b3b3bbb333333bb3bb33bbb33333bb333bb3b3b3bb333333bbb3b3b333b
3b3b3b3b33333b3b3b3333333b3b3b333b333b3b3b3b33b3333b3b333b3b33b33b3b3b3b3b3333333b3b3b3b3b3333333b3b3b3b3b3b3b3b33333b3b3b3b33b3
3333333333333b3b3bb333333bb33bb33bb33bb333333bbb333b3bbb333333b33bbb3bb33bb333333b3b3b3b3bb333333b3b3b3b3b3b3b3b33333bbb33333b33
3333333333333b3b3b3333333b3b3b333b333b3b333333b3333b3b3b333333b33b3b3b3b3b3333333b3b3b3b3b3333333b3b3b3b3bbb3b3b33333b3b333333b3
3333333333333bb33b3333333bbb3bbb3bbb3b3b33333333333b3bbb333333b33b3b3b3b3bbb33333bb33b3b3bbb33333bbb3bb33bbb3b3b33333b3b3333333b
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
3b333b3b3b333bbb3bbb33bb3bbb3b3b3bbb3bbb33bb3bbb3b3b3bb33bb33b3b33bb3bbb3bbb33333bbb3bbb333333bb33bb3bbb3bbb33333bb33bb33b3b33b3
33b33b3b3b3333b333b33b3b3b3b3b3b3b3b333b3b333b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b333333b333b333333b333b333b3b3b3b33333b3b3b3b3b3b3b3b
333b33333b3333b333b33b3b3bb333333b3b333b3b333b3b33333b3b3b3b3b3b3b3b3bb33bbb333333b333b333333bbb3bbb3bbb3bbb33333b3b3b3b33333333
33b333333b3333b333b33b3b3b3b33333b3b333b3b3b3b3b33333b3b3b3b3b3b3b3b3b3b3b3b333333b333b33333333b333b3b3b3b3333333b3b3b3b33333333
3b3333333bbb33b333b33bb33bbb33333bbb333b3bbb3bbb33333bbb3b3b33bb3bb33b3b3b3b333333b33bbb33333bb33bb33b3b3b3333333bbb3b3b33333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33b33b3b3bbb33bb333333bb3bbb33333bbb3bbb3bbb3bbb333333bb3bb333333bbb3b3b3bbb33333b3b3bbb3b333b3333b33b3b33333bbb3b3333333333333b
3b3b3b3b3b333b3333333b3b3b3333333b3b3b333b333b3b33333b3b3b3b333333b33b3b3b3333333b3b3b3b3b333b3333b33b3b33b3333b3b333333333333b3
333333333bb33bbb33333b3b3bb333333bb33bb33bb33bb333333b3b3b3b333333b33bbb3bb333333b3b3bbb3b333b3333b333333bbb333b3bbb333333333b33
333333333b33333b33333b3b3b3333333b3b3b333b333b3b33333b3b3b3b333333b33b3b3b3333333bbb3b3b3b333b333333333333b3333b3b3b3333333333b3
333333333bbb3bb333333bb33b3333333bbb3bbb3bbb3b3b33333bb33b3b333333b33b3b3bbb33333bbb3b3b3bbb3bbb33b333333333333b3bbb33333333333b
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
3030333333333333333333333333333333333333333333333b3b3bbb3bbb3bbb3333333333333bb3333b33333333333333333333333333333333333333333333
3030333333333333333333333333333333333333333333333b3b3b3b333b3b3b333333b3333333b333b333333333333333333333333333333333333333333333
3303333333333333333333333333333333333333333333333b3b3bbb333b3b3b333333333bbb33b33b3333333333333333333333333333333333333333333333
3030333333333333333333333333333333333333333333333bbb3b33333b3b3b333333b3333333b333b333333333333333333333333333333333333333333333
30303333333333333333333333333333333333333333333333b33b33333b3bbb33b3333333333bbb333b33333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99995555599999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99995555599999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99995999599999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99995959599995559955955599999595999999999595999999999595999999999555959595559999959599999555955599999999999999999999999999999999
99995999599995959595959599999595999999999595999999999595999999999595959599599999959599999595995999999999999999999999999999999999
99995955599995559595955599999555999999999959999999999595999999999555959599599999959599999555995999999999999999999999999999999999
99995955599995999595959999999995995999999595995999999555995999999599959599599999955599999595995999999999999999999999999999999999
99995555599995999559959999999555959999999595959999999959959999999599995599599999995999999595995999999999999999999999999999999999
99995555599999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99991111199999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999559955995595559559955595599555955595559955999995959999999995959999999995559559999999559555955595559559995599999999
99999999999995999595959595959595995995959595995995999599999995959999999995959959999999599595999995999959959599599595959999999999
99999999999995999595959595599595995995959555995995599555999999599999999995559999999999599595999995559959955999599595959999999999
99999999999995999595959595959595995995959595995995999995999995959959999999959959999999599595999999959959959599599595959599999999
99999999999999559559955995959555955595959595995995559559999995959599999995559599999995559595999995599959959595559595955599999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999995559955955995559999999995559595995595959999955599559955955595559999959595559599959595559999995995559555995999999999
99999999999995559595959595999959999995959595959995959999959595999599995999599999959595959599959595999999959995959595999599999999
99999999999995959595959595599999999995559595955595559999955595559599995999599999959595559599959595599999959995559595999599999999
99999999999995959595959595999959999995999595999595959999959599959599995999599999955595959599959595999999959995959595999599999999
99999999999995959559955595559999999995999955955995959999959595599955955595559999995995959555995595559999995995559555995999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ff
0777077700000777007707770777070007770077000000770777000007770777077707770000000000f000000000000000000000000000000000000000000000
07070707000007070707f070007007000700070000000707070000000707070007000707000000000000000000000000000000000000000f0000000000000000
07770777000007700707007000700700077007770000070707700000077007700770077000000000000000000000000000000000000000000000000000000000
0007070700000707070700700070070007000007000007070700000007070700070007070000000000000000000000000000000000f000000000000000000000
00070777000007770770007000700777077707700000077007000000077707770777070700000000000000000000000000000000000000000000000000000000
0f000000000000000000000000000000000f000000f00000000000000000000000000000000000000000000000000000000000000000000000000000000f0000
00000000000000000000000000000f000000000f0000000000000000000000000000000000000000000000000000000000000000f0f000000000000f00000000
0000000f00000000000000000000000000000000000000000000f000000000000000000000000000000000000000000000000f00000000000000000f00000000
f777077707070777000000770770077700000770007707070770f000077707700770000007770777007700770000077707770000077707770077070707700770
00700707070707000000070707070700000007070707070707070000070707070707000007070707070007000000007000700000070707070707070707070707
007007770770077000f0070707070770000007070707070707070000077707070707000007770777077707770000007000700000077707700707070707070707
f0700707070707000000070707070700000007070707077707070000070707070707000007000707000700070000007000700000070707070707070707070707
00700707070707770000077007070777000007770770077707070000070707070777000007000707077007700000077700700000070707070770007707070777
0000000000000000000000000000000000000000000000000000000f000000000000000000f00000000000000f000000000f000000000000000000f000000000
000000000000000000f000000000000000000000000077777000000000000000000000000000f000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000777770000000000000000000000000000000000000000000000000000000000000f00000000000000f00
07770777000007770077077707770700077700770000777770000000000000000000000000000000000000000000000000000000000000000000000000000000
07070007000007070707007000700700070007000000777770000000000000000000000000000000000000000000000000000000000000000000000000000000
0777000700000770070700700070070007700777000077777000000000000000000000000000000f000000000000000000000000000000000000000000000000
000700070000070707070f700070070007000007000077777000000000000000f00000000000000000000000000000f00000000000000000000000000000f000
000700070000077707700070007007770777077000007777700000000000000f0000000000000000000000000000000000000000000000000000000000000000
0000000f000000000000000000000000000000000000777770000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000077777000f000000000000000000000000000000000000000000000000000000000000f00000000000000
00000000000000000000000000000000000000000000000000000000000000f000000000000000f00000000000000f0000000000000000000000000000000000
00000000000000000000000000f0000000000000000000000000000000000000000f000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000f0f000000000000000000000f000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000f0f00000000000000000000000000000000000000000000000f0000f000f00000000000000000000000000000000000f00000
00000000000000000000000f00000000000000000000000000000000000000000000000000000000000000000000000f0f00000f000f00000000000000000f00
00000000000000000000000000000000000000000000000000000000000000000000000000000000000f00000000000000000000000000000000000000000000

__sfx__
000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
