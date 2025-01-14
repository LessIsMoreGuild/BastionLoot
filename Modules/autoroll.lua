local addonName, bepgp = ...
local moduleName = addonName.."_autoroll"
local bepgp_autoroll = bepgp:NewModule(moduleName, "AceEvent-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)
local GUI = LibStub("AceGUI-3.0")
local ACD = LibStub("AceConfigDialog-3.0")
-- -1 = manual rolling, 0 = pass, 1 = need, 2 = greed
-- [9454] = true, -- acidic walkers
-- [9453] = true, -- toxic revenger
-- [9452] = true, -- hydrocane
local autoroll = {
  zg_coin = {
-- ZG coin
    [19698] = true, --zulian
    [19699] = true, --razzashi
    [19700] = true, --hakkari -- turnin 1
    [19701] = true, --gurubashi
    [19702] = true, --vilebranch
    [19703] = true, --witherbark -- turnin 2
    [19704] = true, --sandfury
    [19705] = true, --skullsplitter
    [19706] = true, --bloodscalp -- turnin 3
  },
  zg_bijou = {
-- ZG bijou
    [19707] = true, --red
    [19708] = true, --blue
    [19709] = true, --yellow
    [19710] = true, --orange
    [19711] = true, --green
    [19712] = true, --purple
    [19713] = true, --bronze
    [19714] = true, --silver
    [19715] = true, --gold
  },
  aq_scarab = {
  -- AQ scarabs
    [20858] = true, --stone
    [20859] = true, --gold
    [20860] = true, --silver
    [20861] = true, --bronze
    [20862] = true, --crystal
    [20863] = true, --clay
    [20864] = true, --bone
    [20865] = true, --ivory
  },
  aq_20_idol = {
  -- AQ20 idols
    [20866] = {["HUNTER"]=true,["ROGUE"]=true,["MAGE"]=true}, --azure
    [20867] = {["WARRIOR"]=true,["ROGUE"]=true,["WARLOCK"]=true}, --onyx
    [20868] = {["WARRIOR"]=true,["HUNTER"]=true,["PRIEST"]=true}, --lambent
    [20869] = {["PALADIN"]=true,["HUNTER"]=true,["SHAMAN"]=true,["WARLOCK"]=true}, --amber
    [20870] = {["PRIEST"]=true,["WARLOCK"]=true,["DRUID"]=true}, --jasper
    [20871] = {["PALADIN"]=true,["PRIEST"]=true,["SHAMAN"]=true,["MAGE"]=true}, --obsidian
    [20872] = {["PALADIN"]=true,["ROGUE"]=true,["SHAMAN"]=true,["DRUID"]=true}, --vermillion
    [20873] = {["WARRIOR"]=true,["MAGE"]=true,["DRUID"]=true}, --alabaster
  },
  aq_40_idol = {
  -- AQ40 idols
    [20874] = {["WARRIOR"]=true,["HUNTER"]=true,["ROGUE"]=true,["MAGE"]=true}, --sun
    [20875] = {["WARRIOR"]=true,["ROGUE"]=true,["MAGE"]=true,["WARLOCK"]=true}, --night
    [20876] = {["WARRIOR"]=true,["PRIEST"]=true,["MAGE"]=true,["WARLOCK"]=true}, --death
    [20877] = {["PALADIN"]=true,["PRIEST"]=true,["SHAMAN"]=true,["MAGE"]=true,["WARLOCK"]=true}, --sage
    [20878] = {["PALADIN"]=true,["PRIEST"]=true,["SHAMAN"]=true,["WARLOCK"]=true,["DRUID"]=true}, --rebirth
    [20879] = {["PALADIN"]=true,["HUNTER"]=true,["PRIEST"]=true,["SHAMAN"]=true,["DRUID"]=true}, --life
    [20881] = {["PALADIN"]=true,["HUNTER"]=true,["ROGUE"]=true,["SHAMAN"]=true,["DRUID"]=true}, --strife
    [20882] = {["WARRIOR"]=true,["HUNTER"]=true,["ROGUE"]=true,["DRUID"]=true}, --war
  },
  nx_scrap = {
  -- wartorn scraps
    [22373] = true, --leather
    [22374] = true, --Chain/Mail
    [22375] = true, --Plate
    [22376] = true, --Cloth
  },
}

function bepgp_autoroll:getAction(itemID)
  local group,item
  for option,data in pairs(autoroll) do
    if data[itemID] then
      group = option
      item = data[itemID]
      break
    end
  end
  if group and item then
    if (group == "aq_40_idol") or (group == "aq_20_idol") then
      if item[self._playerClass] then
        return bepgp.db.char.autoroll[group].class
      else
        return bepgp.db.char.autoroll[group].other
      end
    else
      return bepgp.db.char.autoroll[group]
    end
  end
end

local flat_data = {}
function bepgp_autoroll:ItemsHash()
  table.wipe(flat_data)
  for option,data in pairs(autoroll) do
    for item,_ in pairs(data) do
      flat_data[item] = true
    end
  end
  if bepgp:table_count(flat_data) > 0 then
    return flat_data
  else
    return
  end
end

local actions = {
  [0] = {L["passed"],""},
  [1] = {L["rolled"],_G.NEED},
  [2] = {L["rolled"],_G.GREED}
}
function bepgp_autoroll:Roll(event, rollID, rollTime, lootHandle)
  local texture, name, count, quality, bindOnPickUp, canNeed, canGreed = GetLootRollItemInfo(rollID)
  if (name) then
    local link = GetLootRollItemLink(rollID)
    local _, _, _, itemID = bepgp:getItemData(link)
    if (itemID) then
      local action = self:getAction(itemID)
      if (action) and ( action >= 0 ) then
        local shouldRoll = (action == 0) or ((action == 1) and canNeed) or ((action == 2) and canGreed)
        if shouldRoll then
          RollOnLoot(rollID,action)
          bepgp:debugPrint(string.format(L["Auto%s %s for %s"],actions[action][1],actions[action][2],link))
        end
      end
    end
  end
end

local zg_label = string.format("%s %%s",(GetRealZoneText(309)))
local aq20_label = string.format("%s %%s",(GetRealZoneText(509)))
local aq40_label = string.format("%s %%s",(GetRealZoneText(531)))
local aq_label = string.format("%s %%s",(C_Map.GetAreaInfo(3428)))
local nx_label = string.format("%s %%s",(GetRealZoneText(533)))
local options = {
  type = "group",
  name = L["Autoroll"],
  desc = L["Autoroll"],
  handler = bepgp_autoroll,
  args = {
    ["zg_coin"] = {
      type = "select",
      name = string.format(zg_label,L["Coins"]),
      desc = string.format(zg_label,L["Coins"]),
      order = 10,
      get = function() return bepgp.db.char.autoroll.zg_coin end,
      set = function(info, val) bepgp.db.char.autoroll.zg_coin = val end,
      values = { [-1]=_G.TRACKER_SORT_MANUAL, [0]=_G.PASS, [1]=_G.NEED, [2]=_G.GREED },
      sorting = {-1, 1, 2, 0}
    },
    ["zg_bijou"] = {
      type = "select",
      name = string.format(zg_label,L["Bijous"]),
      desc = string.format(zg_label,L["Bijous"]),
      order = 20,
      get = function() return bepgp.db.char.autoroll.zg_bijou end,
      set = function(info, val) bepgp.db.char.autoroll.zg_bijou = val end,
      values = { [-1]=_G.TRACKER_SORT_MANUAL, [0]=_G.PASS, [1]=_G.NEED, [2]=_G.GREED },
      sorting = {-1, 1, 2, 0}
    },
    ["aq_scarab"] = {
      type = "select",
      name = string.format(aq_label,L["Scarabs"]),
      desc = string.format(aq_label,L["Scarabs"]),
      order = 30,
      get = function() return bepgp.db.char.autoroll.aq_scarab end,
      set = function(info, val) bepgp.db.char.autoroll.aq_scarab = val end,
      values = { [-1]=_G.TRACKER_SORT_MANUAL, [0]=_G.PASS, [1]=_G.NEED, [2]=_G.GREED },
      sorting = {-1, 1, 2, 0}
    },
    ["aq_20_idol"] = {
      type = "group",
      name = string.format(aq20_label,L["Idols"]),
      desc = string.format(aq20_label,L["Idols"]),
      order = 40,
      args = {
        ["aq_20_class"] = {
          type = "select",
          name = string.format(aq20_label,L["Class Idols"]),
          desc = string.format(aq20_label,L["Class Idols"]),
          order = 10,
          get = function() return bepgp.db.char.autoroll.aq_20_idol.class end,
          set = function(info, val) bepgp.db.char.autoroll.aq_20_idol.class = val end,
          values = { [-1]=_G.TRACKER_SORT_MANUAL, [0]=_G.PASS, [1]=_G.NEED, [2]=_G.GREED },
          sorting = {-1, 1, 2, 0}
        },
        ["aq_20_other"] = {
          type = "select",
          name = string.format(aq20_label,L["Other Idols"]),
          desc = string.format(aq20_label,L["Other Idols"]),
          order = 20,
          get = function() return bepgp.db.char.autoroll.aq_20_idol.other end,
          set = function(info, val) bepgp.db.char.autoroll.aq_20_idol.other = val end,
          values = { [-1]=_G.TRACKER_SORT_MANUAL, [0]=_G.PASS, [1]=_G.NEED, [2]=_G.GREED },
          sorting = {-1, 1, 2, 0}
        }
      }
    },
    ["aq_40_idol"] = {
      type = "group",
      name = string.format(aq40_label,L["Idols"]),
      desc = string.format(aq40_label,L["Idols"]),
      order = 50,
      args = {
        ["aq_40_class"] = {
          type = "select",
          name = string.format(aq40_label,L["Class Idols"]),
          desc = string.format(aq40_label,L["Class Idols"]),
          order = 10,
          get = function() return bepgp.db.char.autoroll.aq_40_idol.class end,
          set = function(info, val) bepgp.db.char.autoroll.aq_40_idol.class = val end,
          values = { [-1]=_G.TRACKER_SORT_MANUAL, [0]=_G.PASS, [1]=_G.NEED, [2]=_G.GREED },
          sorting = {-1, 1, 2, 0}
        },
        ["aq_40_other"] = {
          type = "select",
          name = string.format(aq40_label,L["Other Idols"]),
          desc = string.format(aq40_label,L["Other Idols"]),
          order = 20,
          get = function() return bepgp.db.char.autoroll.aq_40_idol.other end,
          set = function(info, val) bepgp.db.char.autoroll.aq_40_idol.other = val end,
          values = { [-1]=_G.TRACKER_SORT_MANUAL, [0]=_G.PASS, [1]=_G.NEED, [2]=_G.GREED },
          sorting = {-1, 1, 2, 0}
        }
      }
    },
    ["nx_scrap"] = {
      type = "select",
      name = string.format(nx_label,L["Scraps"]),
      desc = string.format(nx_label,L["Scraps"]),
      order = 60,
      get = function() return bepgp.db.char.autoroll.nx_scrap end,
      set = function(info,val) bepgp.db.char.autoroll.nx_scrap = val end,
      values = { [-1]=_G.TRACKER_SORT_MANUAL, [0]=_G.PASS, [1]=_G.NEED, [2]=_G.GREED },
      sorting = {-1, 1, 2, 0}
    },
  }
}
function bepgp_autoroll:injectOptions() -- .general.args.main.args
  bepgp.db.char.autoroll = bepgp.db.char.autoroll or {
    ["zg_coin"] = 1,
    ["zg_bijou"] = 1,
    ["aq_scarab"] = 1,
    ["nx_scrap"] = 1,
  }
  if bepgp.db.char.autoroll.nx_scrap == nil then
    bepgp.db.char.autoroll.nx_scrap = 1
  end
  bepgp.db.char.autoroll.aq_20_idol = bepgp.db.char.autoroll.aq_20_idol or {
    ["class"] = 1,
    ["other"] = 2,
  }
  bepgp.db.char.autoroll.aq_40_idol = bepgp.db.char.autoroll.aq_40_idol or {
    ["class"] = 1,
    ["other"] = 2,
  }
  bepgp._options.args.general.args.autoroll = options
  -- bepgp._options.args.autoroll = options
  --bepgp._options.args.general.args.autoroll.guiHidden = true
  bepgp._options.args.general.args.autoroll.cmdHidden = true
  --bepgp.blizzoptions.autoroll = ACD:AddToBlizOptions(addonName, "Autoroll", addonName, "autoroll")
  --bepgp.blizzoptions.autoroll:SetParent(InterfaceOptionsFramePanelContainer)
  --tinsert(InterfaceOptionsFrame.categoryList, bepgp.blizzoptions.autoroll)
end

function bepgp_autoroll:delayInit()
  self:injectOptions()
  self:RegisterEvent("START_LOOT_ROLL","Roll")
  local _
  _, self._playerClass = UnitClass("player")
  self._initDone = true
end

function bepgp_autoroll:CoreInit()
  if not self._initDone then
    self:delayInit()
  end
end

function bepgp_autoroll:OnEnable()
  self:RegisterMessage(addonName.."_INIT_DONE","CoreInit")
  self:delayInit()
end
