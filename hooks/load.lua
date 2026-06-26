local KeyBind = require 'engine.KeyBind'

class:bindHook('ToME:load', function(self, data)
  KeyBind:defineAction {
    default = { 'sym:_p:false:true:true:false' },
    type = 'TOGGLE_AUTO_USE',
    group = 'miscellaneous',
    name = 'Toggle auto-use ON/OFF',
  }
end)

class:bindHook('ToME:load', function(self, data)
  KeyBind:defineAction {
    default = { 'sym:_o:false:true:true:false' },
    type = 'AUTO_USE_LIST',
    group = 'miscellaneous',
    name = 'Set talent auto-use ordering',
  }
end)

class:bindHook('ToME:load', function(self, data)
  KeyBind:defineAction {
    default = { 'sym:_x:false:true:true:false' },
    type = 'TOGGLE_AUTO_USE_ORDER',
    group = 'miscellaneous',
    name = 'Toggle auto-use custom talent ordering ON/OFF',
  }
end)

class:bindHook('ToME:runDone', function(self, data)
  game.key:addBinds {
    TOGGLE_AUTO_USE = function()
      local p = game.player
      if p.talents_auto_off then
        p.talents_auto_off = false
        game.log("Auto-use Enabled")
      else
        p.talents_auto_off = true
        game.log("Auto-use Disabled")
      end
    end,
    AUTO_USE_LIST = function()
      local AutoUserOrderListDialog = require('mod.dialogs.AutoUserOrderListDialog')
      game:registerDialog(AutoUserOrderListDialog.new(game))
    end,
    TOGGLE_AUTO_USE_ORDER = function()
      local p = game.player
      if p.talents_auto_ordering_off then
        p.talents_auto_ordering_off = false
        game.log("Auto-use Custom Ordering Enabled")
      else
        p.talents_auto_ordering_off = true
        game.log("Auto-use Custom Ordering Disabled")
      end
    end
  }
end)

class:bindHook("ToME:run", function(self, data)
	KeyBind:load("toggle-autotarget")
	game.key:addBinds {
		TOGGLE_AUTOTARGET = function()
			config.settings.auto_accept_target  = not config.settings.auto_accept_target
			game.log("#GOLD#Auto-accept target mode: %s", config.settings.auto_accept_target and "#LIGHT_GREEN#enabled" or "#LIGHT_RED#disabled")
			end
		}
end)
