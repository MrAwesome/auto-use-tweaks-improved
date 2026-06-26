require 'engine.class'
local Dialog = require 'engine.ui.Dialog'
local ListColumns = require 'engine.ui.ListColumns'
local Textzone = require "engine.ui.Textzone"
local TextzoneList = require "engine.ui.TextzoneList"
local Separator = require 'engine.ui.Separator'
local Config = require "mod.auto_use.config"
local Summary = require "mod.auto_use.summary"

module(..., package.seeall, class.inherit(Dialog))

local function table_copy(t)
  local u = {}
  for k, v in pairs(t) do u[k] = v end
  return setmetatable(u, getmetatable(t))
end

_M.block_notify = 0
_M.pending_notify = false

function _M:init(game)
  self.talents_auto = table_copy(game.player.talents_auto or {})
  self.talents_auto_order = game.player.talents_auto_order or {}
  if game.player.talents_auto_ordering_off == nil then game.player.talents_auto_ordering_off = false end

  local talents_auto_order_new = {}
  local talents_auto_temp = self.talents_auto
  for index, talent in ipairs(self.talents_auto_order) do
    if talents_auto_temp[talent] ~= nil then
      table.insert(talents_auto_order_new, talent)
      talents_auto_temp[talent] = nil
    end
  end
  for k,v in pairs(talents_auto_temp) do
    table.insert(talents_auto_order_new, k)
  end
  self.talents_auto_order = talents_auto_order_new

  Dialog.init(self, 'Auto-use Talent Ordering', math.max(800, game.w*0.8), math.max(600, game.h*0.8))

  self.c_note = Textzone.new {
    width = math.floor(self.iw * 0.65 - 10),
    auto_height = true,
    text = string.toTString [[#SLATE#Reorder with #00FF00#Shift-Up#LAST# / #00FF00#Shift-Down#LAST#. Click a row to configure rules.]]
  }
  self.talent_c_list = ListColumns.new {
    width = math.floor(self.iw * 0.65 - 10),
    height = self.ih - self.c_note.h - 20,
    columns = {
      { name = 'Talent', width = 30, display_prop = 'display_name', sort='idx' },
      { name = 'Rules', width = 30, display_prop = 'rules', sort = 'rules' },
      { name = 'Range', width = 9, display_prop = 'range', sort = 'range' },
      { name = 'Cooldown', width = 13, display_prop = 'cooldown', sort = 'cooldown' },
    },
    sortable = false,
    scrollbar = true,
    list = {},
    fct = function(item)
      local menu = require("mod.dialogs.AutoUseOptions").new(item)
      game:registerDialog(menu)
    end,
    select = function(item, sel) self:selectItem(item) end,
  }
  self.c_desc = TextzoneList.new {
    width = math.floor(self.iw * 0.35 - 15),
    height = self.ih - 10,
    no_color_bleed = true,
  }

  self:generateList()

  local sep = Separator.new { dir = 'horizontal', size = self.ih - 10 }
  self:loadUI {
    { left = 0, top = 0, ui = self.c_note },
    { left = 0, top = self.c_note.h + 10, ui = self.talent_c_list },
    { right = 0, top = 0, ui = self.c_desc },
    { left = self.iw * 0.65 - 5, top = 0, ui = sep },
  }
  self:setFocus(self.talent_c_list)
  self:setupUI()

  self.key:addBinds {
    EXIT = function()
      game:unregisterDialog(self)
      game.player.talents_auto_order = self.talents_auto_order
    end
  }
  self.talent_c_list.key:addCommands {
    [{'_UP','shift'}] = function() self:moveItem(-1) end,
    [{'_DOWN','shift'}] = function() self:moveItem(1) end,
  }
end

function _M:moveItem(delta)
  self.talent_c_list.last_input_was_keyboard = true
  if self.talent_c_list.sel < 1 or self.talent_c_list.sel > #self.talents_auto_order then return end
  local newpos = util.minBound(self.talent_c_list.sel + delta, 1, #self.talents_auto_order)
  if newpos == self.talent_c_list.sel then return end
  local item = table.remove(self.talents_auto_order, self.talent_c_list.sel)
  table.insert(self.talents_auto_order, newpos, item)
  self:generateList()
  self.talent_c_list.sel = newpos
  self:selectItem(self.talent_c_list.list[self.talent_c_list.sel])
end

function _M:selectItem(item)
  if item then
    local talent = game.player.talents_def[item.name]
    if talent then
      local desc = game.player:getTalentFullDescription(talent)
      self.c_desc:switchItem(item, desc, true)
    else
      self.c_desc:switchItem('', '')
    end
  else
    self.c_desc:switchItem('', '')
  end
end

function _M:generateList()
  local list = {}
  for index, talent_id in ipairs(self.talents_auto_order) do
    local talent = game.player.talents_def[talent_id]
    local cfg = Config.get(game.player, talent_id)
    local entry = {
      idx = index,
      display_name = talent and game.player:getTalentDisplayName(talent) or talent_id,
      name = talent_id,
      rules = Summary.describe(cfg),
      range = talent and game.player:getTalentRange(talent) or 1,
      cooldown = talent and game.player:getTalentCooldown(talent) or "?",
    }
    table.insert(list, entry)
  end
  self.list = list
  self.talent_c_list:setList(self.list)
end
