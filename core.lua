local addonName, bepgp = ...
local addon = LibStub("AceAddon-3.0"):NewAddon(bepgp, addonName, "AceConsole-3.0", "AceHook-3.0", "AceEvent-3.0", "AceTimer-3.0", "AceBucket-3.0", "AceComm-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)
local AC = LibStub("AceConfig-3.0")
local ACD = LibStub("AceConfigDialog-3.0")
local ADBO = LibStub("AceDBOptions-3.0")
local LDBO = LibStub("LibDataBroker-1.1"):NewDataObject(addonName)
local LDI = LibStub("LibDBIcon-1.0")
local LDD = LibStub("LibDropdown-1.0")
local LD = LibStub("LibDialog-1.0")
local C = LibStub("LibCrayon-3.0")
local DF = LibStub("LibDeformat-3.0")
local G = LibStub("LibGratuity-3.0")
local T = LibStub("LibQTip-1.0")

bepgp._DEBUG = false
bepgp.VARS = {
  basegp = 100,
  minep = 0,
  baseaward_ep = 100,
  decay = 0.8,
  max = 1000,
  timeout = 60,
  minlevel = 68,
  maxloglines = 500,
  prefix = "BASTIONLOOT_PFX",
  pricesystem = "BastionEPGPFixed_bc-1.0",
  bop = C:Red(L["BoP"]),
  boe = C:Yellow(L["BoE"]),
  nobind = C:White(L["NoBind"]),
  msgp = L["Mainspec GP"],
  osgp = L["Offspec GP"],
  bankde = L["Bank-D/E"],
  unassigned = C:Red(L["Unassigned"]),
  autoloot = {
    [29434] = "Badge",
    [28558] = "SpiritShard",
    [29425] = "MarkKJ",
    [30809] = "MarkSG",
    [29426] = "SignetFW",
    [30810] = "SignetSF",
    [24368] = "Coilfang",
    [25433] = "Warbead",
    [29209] = "Zaxxis",
  },
}
bepgp._playerName = GetUnitName("player")

local raidStatus,lastRaidStatus
local lastUpdate = 0
local running_check
local partyUnit,raidUnit = {},{}
local hexClassColor, classToEnClass = {}, {}
local hexColorQuality = {}
local price_systems = {}
local special_frames = {}
local label = string.format("|cff33ff99%s|r",addonName)
local out_chat = string.format("%s: %%s",addonName)
local icons = {
  epgp = "Interface\\PetitionFrame\\GuildCharter-Icon",
  plusroll = "Interface\\Buttons\\UI-GroupLoot-Dice-Up"
}
local modes = {
  epgp = L["EPGP"],
  plusroll = L["PlusRoll"]
}
local switch_icon = "|TInterface\\Buttons\\UI-OptionsButton:16|t"..L["Switch Mode"]
do
  for i=1,40 do
    raidUnit[i] = "raid"..i
  end
  for i=1,4 do
    partyUnit[i] = "party"..i
  end
end
do
  for i=0,5 do
    hexColorQuality[ITEM_QUALITY_COLORS[i].hex] = i
  end
end
do
  for eClass, class in pairs(LOCALIZED_CLASS_NAMES_MALE) do
    hexClassColor[class] = RAID_CLASS_COLORS[eClass].colorStr:gsub("^(ff)","")
    classToEnClass[class] = eClass
  end
  for eClass, class in pairs(LOCALIZED_CLASS_NAMES_FEMALE) do
    hexClassColor[class] = RAID_CLASS_COLORS[eClass].colorStr:gsub("^(ff)","")
  end
end
do
  local star,star_off = CreateAtlasMarkup("tradeskills-star"),CreateAtlasMarkup("tradeskills-star-off")
  bepgp._favmap = {
    [1]=string.format("%s%s%s%s%s",star,star_off,star_off,star_off,star_off),
    [2]=string.format("%s%s%s%s%s",star,star,star_off,star_off,star_off),
    [3]=string.format("%s%s%s%s%s",star,star,star,star_off,star_off),
    [4]=string.format("%s%s%s%s%s",star,star,star,star,star_off),
    [5]=string.format("%s%s%s%s%s",star,star,star,star,star),
  }
end
do
  bepgp._specmap = {
    DRUID = {
      Icon = CreateAtlasMarkup("classicon-druid"),
      Balance = CreateAtlasMarkup("GarrMission_ClassIcon-Druid-Balance"),
      FeralCombat = CreateAtlasMarkup("GarrMission_ClassIcon-Druid-Feral"),
      FeralTank = CreateAtlasMarkup("GarrMission_ClassIcon-Druid-Guardian"),
      Restoration = CreateAtlasMarkup("GarrMission_ClassIcon-Druid-Restoration")
    },
    HUNTER = {
      Icon = CreateAtlasMarkup("classicon-hunter"),
      BeastMastery = CreateAtlasMarkup("GarrMission_ClassIcon-Hunter-BeastMastery"),
      Marksmanship = CreateAtlasMarkup("GarrMission_ClassIcon-Hunter-Marksmanship"),
      Survival = CreateAtlasMarkup("GarrMission_ClassIcon-Hunter-Survival")
    },
    MAGE = {
      Icon = CreateAtlasMarkup("classicon-mage"),
      Arcane = CreateAtlasMarkup("GarrMission_ClassIcon-Mage-Arcane"),
      Fire = CreateAtlasMarkup("GarrMission_ClassIcon-Mage-Fire"),
      Frost = CreateAtlasMarkup("GarrMission_ClassIcon-Mage-Frost")
    },
    PALADIN = {
      Icon = CreateAtlasMarkup("classicon-paladin"),
      Holy = CreateAtlasMarkup("GarrMission_ClassIcon-Paladin-Holy"),
      Protection = CreateAtlasMarkup("GarrMission_ClassIcon-Paladin-Protection"),
      Retribution = CreateAtlasMarkup("GarrMission_ClassIcon-Paladin-Retribution")
    },
    PRIEST = {
      Icon = CreateAtlasMarkup("classicon-priest"),
      Discipline = CreateAtlasMarkup("GarrMission_ClassIcon-Priest-Discipline"),
      Holy = CreateAtlasMarkup("GarrMission_ClassIcon-Priest-Holy"),
      Shadow = CreateAtlasMarkup("GarrMission_ClassIcon-Priest-Shadow")
    },
    ROGUE = {
      Icon = CreateAtlasMarkup("classicon-rogue"),
      Assasination = CreateAtlasMarkup("GarrMission_ClassIcon-Rogue-Assassination"),
      Combat = CreateAtlasMarkup("GarrMission_ClassIcon-Rogue-Outlaw"),
      Subtlety = CreateAtlasMarkup("GarrMission_ClassIcon-Rogue-Subtlety")
    },
    SHAMAN = {
      Icon = CreateAtlasMarkup("classicon-shaman"),
      Elemental = CreateAtlasMarkup("GarrMission_ClassIcon-Shaman-Elemental"),
      Enhancement = CreateAtlasMarkup("GarrMission_ClassIcon-Shaman-Enhancement"),
      Restoration = CreateAtlasMarkup("GarrMission_ClassIcon-Shaman-Restoration")
    },
    WARLOCK = {
      Icon = CreateAtlasMarkup("classicon-warlock"),
      Affliction = CreateAtlasMarkup("GarrMission_ClassIcon-Warlock-Affliction"),
      Demonology = CreateAtlasMarkup("GarrMission_ClassIcon-Warlock-Demonology"),
      Destruction = CreateAtlasMarkup("GarrMission_ClassIcon-Warlock-Destruction")
    },
    WARRIOR = {
      Icon = CreateAtlasMarkup("classicon-warrior"),
      Arms = CreateAtlasMarkup("GarrMission_ClassIcon-Warrior-Arms"),
      Fury = CreateAtlasMarkup("GarrMission_ClassIcon-Warrior-Fury"),
      Protection = CreateAtlasMarkup("GarrMission_ClassIcon-Warrior-Protection")
    }
  }
end
local item_bind_patterns = {
  CRAFT = "("..USE_COLON..")",
  BOP = "("..ITEM_BIND_ON_PICKUP..")",
  QUEST = "("..ITEM_BIND_QUEST..")",
  BOU = "("..ITEM_BIND_ON_EQUIP..")",
  BOE = "("..ITEM_BIND_ON_USE..")",
  BOUND = "("..ITEM_SOULBOUND..")"
}

local defaults = {
  profile = {
    announce = "GUILD",
    decay = bepgp.VARS.decay,
    minep = bepgp.VARS.minep,
    system = bepgp.VARS.pricesystem,
    progress = "T4",
    discount = 0.1,
    altspool = false,
    altpercent = 1.0,
    main = false,
    minimap = {
      hide = false,
    },
    guildcache = {},
    alts = {},
  },
  char = {
    raidonly = false,
    tooltip = {
      prinfo = true,
      mlinfo = true,
      favinfo = true,
      useinfo = false,
    },
    classgroup = false,
    standby = false,
    bidpopup = false,
    mode = "epgp", -- "plusroll"
    logs = {},
    loot = {},
    favorites = {},
    reserves = {
      locked=false,
      players={},
      items={}
    },
    wincount = {},
    plusroll_logs = {},
    wincountmanual = true,
    wincounttoken = true,
    wincountstack = true,
    plusrollepgp = false,
    rollfilter = false,
    favalert = false,
    groupcache = {},
  },
}
local admincmd, membercmd =
{type = "group", handler = bepgp, args = {
    bids = {
      type = "execute",
      name = L["Bids"],
      desc = L["Show Bids Table."],
      func = function()
        local bids = bepgp:GetModule(addonName.."_bids")
        if bids then
          bids:Toggle()
        end
      end,
      order = 1,
    },
    show = {
      type = "execute",
      name = L["Standings"],
      desc = L["Show Standings Table."],
      func = function()
        local standings = bepgp:GetModule(addonName.."_standings")
        if standings then
          standings:Toggle()
        end
      end,
      order = 2,
    },
    browser = {
      type = "execute",
      name = L["Favorites"],
      desc = L["Show Favorites Table."],
      func = function()
        local browser = bepgp:GetModule(addonName.."_browser")
        if browser then
          browser:Toggle()
        end
      end,
      order = 3,
    },
    clearloot = {
      type = "execute",
      name = L["ClearLoot"],
      desc = L["Clear Loot Table."],
      func = function()
        local loot = bepgp:GetModule(addonName.."_loot")
        if loot then
          loot:Clear()
        end
      end,
      order = 4,
    },
    clearlogs = {
      type = "execute",
      name = L["ClearLogs"],
      desc = L["Clear Logs Table."],
      func = function()
        local logs = bepgp:GetModule(addonName.."_logs")
        if logs then
          logs:Clear()
        end
      end,
      order = 5,
    },
    progress = {
      type = "execute",
      name = L["Progress"],
      desc = L["Print Progress Multiplier."],
      func = function()
        bepgp:Print(bepgp.db.profile.progress)
      end,
      order = 6,
    },
    offspec = {
      type = "execute",
      name = L["Offspec"],
      desc = L["Print Offspec Price."],
      func = function()
        bepgp:Print(string.format("%s%%",bepgp.db.profile.discount*100))
      end,
      order = 7,
    },
    mode = {
      type = "select",
      name = L["Mode of Operation"],
      desc = L["Select mode of operation."],
      get = function()
        return bepgp.db.char.mode
      end,
      set = function(info, val)
        bepgp.db.char.mode = val
        bepgp:SetMode(bepgp.db.char.mode)
      end,
      values = { ["epgp"]=L["EPGP"], ["plusroll"]=L["PlusRoll"]},
      sorting = {"epgp", "plusroll"},
      order = 8,
    },
    restart = {
      type = "execute",
      name = L["Restart"],
      desc = L["Restart BastionLoot if having startup problems."],
      func = function()
        bepgp:OnEnable()
        bepgp:Print(L["Restarted"])
      end,
      order = 9,
    },
  }},
{type = "group", handler = bepgp, args = {
    show = {
      type = "execute",
      name = L["Standings"],
      desc = L["Show Standings Table."],
      func = function()
        local standings = bepgp:GetModule(addonName.."_standings")
        if standings then
          standings:Toggle()
        end
      end,
      order = 1,
    },
    browser = {
      type = "execute",
      name = L["Favorites"],
      desc = L["Show Favorites Table."],
      func = function()
        local browser = bepgp:GetModule(addonName.."_browser")
        if browser then
          browser:Toggle()
        end
      end,
      order = 2,
    },
    progress = {
      type = "execute",
      name = L["Progress"],
      desc = L["Print Progress Multiplier."],
      func = function()
        bepgp:Print(bepgp.db.profile.progress)
      end,
      order = 3,
    },
    offspec = {
      type = "execute",
      name = L["Offspec"],
      desc = L["Print Offspec Price."],
      func = function()
        bepgp:Print(string.format("%s%%",bepgp.db.profile.discount*100))
      end,
      order = 4,
    },
    mode = {
      type = "select",
      name = L["Mode of Operation"],
      desc = L["Select mode of operation."],
      get = function()
        return bepgp.db.char.mode
      end,
      set = function(info, val)
        bepgp.db.char.mode = val
        bepgp:SetMode(bepgp.db.char.mode)
      end,
      values = { ["epgp"]=L["EPGP"], ["plusroll"]=L["PlusRoll"]},
      sorting = {"epgp", "plusroll"},
      order = 5,
    },
    restart = {
      type = "execute",
      name = L["Restart"],
      desc = L["Restart BastionLoot if having startup problems."],
      func = function()
        bepgp:OnEnable()
        bepgp:Print(L["Restarted"])
      end,
      order = 6,
    },
  }}
bepgp.cmdtable = function()
  if (bepgp:admin()) then
    return admincmd
  else
    return membercmd
  end
end

function bepgp:options()
  if not (self._options) then
    self._options = 
    {
      type = "group",
      handler = bepgp,
      args = {
        general = {
          type = "group",
          name = _G.OPTIONS,
          childGroups = "tab",
          args = {
            main = {
              type = "group",
              name = _G.GENERAL,
              order = 1,
              args = { },
            },
            ttip = {
              type = "group",
              name = L["Tooltip"],
              desc = L["Tooltip Additions"],
              order = 2,
              args = { },
            }
          }
        }
      }
    }
    self._options.args.general.args.ttip.args["prinfo"] = {
      type = "toggle",
      name = L["EPGP Info"],
      desc = L["Add EPGP Information to Item Tooltips"],
      order = 10,
      get = function() return not not bepgp.db.char.tooltip.prinfo end,
      set = function(info, val)
        bepgp.db.char.tooltip.prinfo = not bepgp.db.char.tooltip.prinfo
        bepgp:tooltipHook()
      end,
    }
    self._options.args.general.args.ttip.args["mlinfo"] = {
      type = "toggle",
      name = L["Masterlooter Hints"],
      desc = L["Show Masterlooter click action hints on item tooltips"],
      order = 11,
      get = function() return not not bepgp.db.char.tooltip.mlinfo end,
      set = function(info, val)
        bepgp.db.char.tooltip.mlinfo = not bepgp.db.char.tooltip.mlinfo
        bepgp:tooltipHook()
      end,
    }
    self._options.args.general.args.ttip.args["favinfo"] = {
      type = "toggle",
      name = L["Favorites Info"],
      desc = L["Show Favorite ranking on item tooltips"],
      order = 12,
      get = function() return not not bepgp.db.char.tooltip.favinfo end,
      set = function(info, val)
        bepgp.db.char.tooltip.favinfo = not bepgp.db.char.tooltip.favinfo
        bepgp:tooltipHook()
      end,
    }
    self._options.args.general.args.ttip.args["useinfo"] = {
      type = "toggle",
      name = L["Usable Info"],
      desc = L["Show Class and Spec Hints on item tooltips"],
      order = 13,
      get = function() return not not bepgp.db.char.tooltip.useinfo end,
      set = function(info, val)
        bepgp.db.char.tooltip.useinfo = not bepgp.db.char.tooltip.useinfo
        bepgp:tooltipHook()
      end,
    }
    self._options.args.general.args.main.args["set_main"] = {
      type = "input",
      name = L["Set Main"],
      desc = L["Set your Main Character for Standby List."],
      order = 70,
      usage = "<MainChar>",
      get = function() return bepgp.db.profile.main end,
      set = function(info, val) bepgp.db.profile.main = (bepgp:verifyGuildMember(val)) end,
    }
    self._options.args.general.args.main.args["raid_only"] = {
      type = "toggle",
      name = L["Raid Only"],
      desc = L["Only show members in raid."],
      order = 80,
      get = function() return not not bepgp.db.char.raidonly end,
      set = function(info, val)
        bepgp.db.char.raidonly = not bepgp.db.char.raidonly
        local standings = bepgp:GetModule(addonName.."_standings")
        if standings then
          standings._widgetraid_only:SetValue(bepgp.db.char.raidonly)
        end
        bepgp:refreshPRTablets()
      end,
    }
    self._options.args.general.args.main.args["class_grouping"] = {
      type = "toggle",
      name = L["Group by class"],
      desc = L["Group members by class."],
      order = 81,
      get = function() return not not bepgp.db.char.classgroup end,
      set = function(info, val)
        bepgp.db.char.classgroup = not bepgp.db.char.classgroup
        local standings = bepgp:GetModule(addonName.."_standings")
        if standings then
          standings._widgetclass_grouping:SetValue(bepgp.db.char.classgroup)
        end
        bepgp:refreshPRTablets()
      end,
    }
    self._options.args.general.args.main.args["bid_popup"] = {
      type = "toggle",
      name = L["Bid Popup"],
      desc = L["Show a Bid Popup in addition to chat links"],
      order = 83,
      get = function() return not not bepgp.db.char.bidpopup end,
      set = function(info, val)
        bepgp.db.char.bidpopup = not bepgp.db.char.bidpopup
      end,
    }
    self._options.args.general.args.main.args["minimap"] = {
      type = "toggle",
      name = L["Hide from Minimap"],
      desc = L["Hide from Minimap"],
      order = 84,
      get = function() return bepgp.db.profile.minimap.hide end,
      set = function(info, val)
        bepgp.db.profile.minimap.hide = val
        if bepgp.db.profile.minimap.hide then
          LDI:Hide(addonName)
        else
          LDI:Show(addonName)
        end
      end
    }
    self._options.args.general.args.main.args["rollfilter"] = {
      type = "toggle",
      name = L["Hide Rolls"],
      desc = L["Hide other player rolls from the chatframe"],
      order = 85,
      get = function() return not not bepgp.db.char.rollfilter end,
      set = function(info, val)
        bepgp.db.char.rollfilter = not bepgp.db.char.rollfilter
      end,
      --hidden = function() return bepgp.db.char.mode ~= "plusroll" end,
    }
    self._options.args.general.args.main.args["favalert"] = {
      type = "toggle",
      name = L["Favorite Alert"],
      desc = L["Alert presence of Favorite Link or Loot"],
      order = 86,
      get = function() return not not bepgp.db.char.favalert end,
      set = function(info, val)
        bepgp.db.char.favalert = not bepgp.db.char.favalert
      end,
    }
    self._options.args.general.args.main.args["admin_options_header"] = {
      type = "header",
      name = L["Admin Options"],
      order = 87,
      hidden = function() return (not bepgp:admin()) end,
    }
    self._options.args.general.args.main.args["progress_tier_header"] = {
      type = "header",
      name = string.format(L["Progress Setting: %s"],bepgp.db.profile.progress),
      order = 88,
      hidden = function() return bepgp:admin() end,
    }
    self._options.args.general.args.main.args["progress_tier"] = {
      type = "select",
      name = L["Raid Progress"],
      desc = L["Highest Tier the Guild is raiding.\nUsed to adjust GP Prices.\nUsed for suggested EP awards."],
      order = 90,
      hidden = function() return not (bepgp:admin()) end,
      get = function() return bepgp.db.profile.progress end,
      set = function(info, val)
        bepgp.db.profile.progress = val
        bepgp:refreshPRTablets()
        if (IsGuildLeader()) then
          bepgp:shareSettings(true)
        end
      end,
      values = {
        ["T6.5"]=L["4.Sunwell Plateau"],
        ["T6"]=L["3.Black Temple, Hyjal"],
        ["T5"]=L["2.Serpentshrine Cavern, The Eye"],
        ["T4"]=L["1.Karazhan, Magtheridon, Gruul, World Bosses"]},
      sorting = {"T6.5", "T6", "T5", "T4"},
    }
    self._options.args.general.args.main.args["report_channel"] = {
      type = "select",
      name = L["Reporting channel"],
      desc = L["Channel used by reporting functions."],
      order = 95,
      hidden = function() return not (bepgp:admin()) end,
      get = function() return bepgp.db.profile.announce end,
      set = function(info, val) bepgp.db.profile.announce = val end,
      values = { ["PARTY"]=_G.PARTY, ["RAID"]=_G.RAID, ["GUILD"]=_G.GUILD, ["OFFICER"]=_G.OFFICER },
    }
    self._options.args.general.args.main.args["decay"] = {
      type = "execute",
      name = L["Decay EPGP"],
      desc = string.format(L["Decays all EPGP by %s%%"],(1-(bepgp.db.profile.decay or bepgp.VARS.decay))*100),
      order = 100,
      hidden = function() return not (bepgp:admin()) end,
      func = function() bepgp:decay_epgp() end
    }
    self._options.args.general.args.main.args["set_decay_header"] = {
      type = "header",
      name = string.format(L["Weekly Decay: %s%%"],(1-(bepgp.db.profile.decay or bepgp.VARS.decay))*100),
      order = 105,
      hidden = function() return bepgp:admin() end,
    }
    self._options.args.general.args.main.args["set_decay"] = {
      type = "range",
      name = L["Set Decay %"],
      desc = L["Set Decay percentage (Admin only)."],
      order = 110,
      get = function() return (1.0-bepgp.db.profile.decay) end,
      set = function(info, val)
        bepgp.db.profile.decay = (1 - val)
        self._options.args.general.args.main.args["decay"].desc = string.format(L["Decays all EPGP by %s%%"],(1-bepgp.db.profile.decay)*100)
        if (IsGuildLeader()) then
          bepgp:shareSettings(true)
        end
      end,
      min = 0.01,
      max = 0.5,
      step = 0.01,
      bigStep = 0.05,
      isPercent = true,
      hidden = function() return not (bepgp:admin()) end,
    }
    self._options.args.general.args.main.args["set_discount_header"] = {
      type = "header",
      name = string.format(L["Offspec Price: %s%%"],bepgp.db.profile.discount*100),
      order = 111,
      hidden = function() return bepgp:admin() end,
    }
    self._options.args.general.args.main.args["set_discount"] = {
      type = "range",
      name = L["Offspec Price %"],
      desc = L["Set Offspec Items GP Percent."],
      order = 115,
      hidden = function() return not (bepgp:admin()) end,
      get = function() return bepgp.db.profile.discount end,
      set = function(info, val)
        bepgp.db.profile.discount = val
        if (IsGuildLeader()) then
          bepgp:shareSettings(true)
        end
      end,
      min = 0,
      max = 1,
      step = 0.05,
      isPercent = true
    }
    self._options.args.general.args.main.args["set_min_ep_header"] = {
      type = "header",
      name = string.format(L["Minimum EP: %s"],bepgp.db.profile.minep),
      order = 117,
      hidden = function() return bepgp:admin() end,
    }
    self._options.args.general.args.main.args["set_min_ep"] = {
      type = "input",
      name = L["Minimum EP"],
      desc = L["Set Minimum EP"],
      usage = "<minep>",
      order = 118,
      get = function() return tostring(bepgp.db.profile.minep) end,
      set = function(info, val)
        bepgp.db.profile.minep = tonumber(val)
        bepgp:refreshPRTablets()
        if (IsGuildLeader()) then
          bepgp:shareSettings(true)
        end
      end,
      validate = function(info, val)
        local n = tonumber(val)
        if n and n >= 0 and n <= bepgp.VARS.max then
          return true
        else
          return string.format("Value must be greater than zero and smaller than %s",bepgp.VARS.max) --localization
        end
      end,
      hidden = function() return not bepgp:admin() end,
    }
    self._options.args.general.args.main.args["reset"] = {
     type = "execute",
     name = L["Reset EPGP"],
     desc = string.format(L["Resets everyone\'s EPGP to 0/%d (Guild Leader only)."],bepgp.VARS.basegp),
     order = 120,
     hidden = function() return not (IsGuildLeader()) end,
     func = function() LD:Spawn(addonName.."DialogResetPoints") end
    }
    self._options.args.general.args.main.args["system"] = {
      type = "select",
      name = L["Select Price Scheme"],
      desc = L["Select From Registered Price Systems"],
      order = 135,
      hidden = function() return not (bepgp:admin()) end,
      get = function() return bepgp.db.profile.system end,
      set = function(info, val)
        bepgp.db.profile.system = val
        bepgp:SetPriceSystem()
        bepgp:refreshPRTablets()
      end,
      values = function()
        local v = {}
        for k,_ in pairs(price_systems) do
          v[k]=k
        end
        return v
      end,
    }
    self._options.args.general.args.main.args["mode_options_header"] = {
      type = "header",
      name = L["PlusRoll"].."/"..L["EPGP"],
      order = 137,
    }
    self._options.args.general.args.main.args["mode"] = {
      type = "select",
      name = L["Mode of Operation"],
      desc = L["Select mode of operation."],
      get = function()
        return bepgp.db.char.mode
      end,
      set = function(info, val)
        bepgp.db.char.mode = val
        bepgp:SetMode(bepgp.db.char.mode)
      end,
      values = { ["epgp"]=L["EPGP"], ["plusroll"]=L["PlusRoll"]},
      sorting = {"epgp", "plusroll"},
      order = 140,
    }
    self._options.args.general.args.main.args["lootclear"] = {
      type = "execute",
      name = L["Clear Loot"],
      desc = L["Clear Loot"],
      order = 142,
      func = function()
        local loot = bepgp:GetModule(addonName.."_loot")
        if loot then
          loot:Clear()
        end
      end,
      hidden = function() return (bepgp.db.char.mode ~= "epgp") or (bepgp.db.char.mode == "epgp" and not bepgp:admin()) end,
    }
    self._options.args.general.args.main.args["wincountclear"] = {
      type = "execute",
      name = L["Clear Wincount"],
      desc = L["Clear Wincount"],
      order = 145,
      func = function()
        local plusroll_loot = bepgp:GetModule(addonName.."_plusroll_loot")
        if plusroll_loot then
          plusroll_loot:Clear()
        end
      end,
      hidden = function()
        return (bepgp.db.char.mode ~= "plusroll") or (not bepgp.db.char.wincountmanual)
      end,
    }
    self._options.args.general.args.main.args["reserveclear"] = {
      type = "execute",
      name = L["Clear reserves"],
      desc = L["Clear reserves"],
      order = 146,
      func = function()
        local plusroll_reserves = bepgp:GetModule(addonName.."_plusroll_reserves")
        if plusroll_reserves then
          plusroll_reserves:Clear()
        end
      end,
      hidden = function() return bepgp.db.char.mode ~= "plusroll" end,
    }
    self._options.args.general.args.main.args["wincountopt"] = {
      type = "toggle",
      name = L["Manual Wincount"],
      desc = L["Manually reset Wincount at end of raid."],
      order = 150,
      get = function() return not not bepgp.db.char.wincountmanual end,
      set = function(info, val)
        bepgp.db.char.wincountmanual = not bepgp.db.char.wincountmanual
      end,
      hidden = function() return bepgp.db.char.mode ~= "plusroll" end,
    }
    self._options.args.general.args.main.args["wincounttoken"] = {
      type = "toggle",
      name = L["Skip Autoroll Items"],
      desc = L["Skip Autoroll Items from Wincount Prompts."],
      order = 155,
      get = function() return not not bepgp.db.char.wincounttoken end,
      set = function(info, val)
        bepgp.db.char.wincounttoken = not bepgp.db.char.wincounttoken
      end,
      hidden = function() return bepgp.db.char.mode ~= "plusroll" end,
    }
    self._options.args.general.args.main.args["wincountstack"] = {
      type = "toggle",
      name = L["Skip Stackable Items"],
      desc = L["Skip Stackable Items from Wincount Prompts."],
      order = 157,
      get = function() return not not bepgp.db.char.wincountstack end,
      set = function(info,val)
        bepgp.db.char.wincountstack = not bepgp.db.char.wincountstack
      end,
      hidden = function() return bepgp.db.char.mode ~= "plusroll" end,
    }
    self._options.args.general.args.main.args["plusrollepgp"] = {
      type = "toggle",
      name = L["Award GP"],
      desc = L["Guild members that win items also get awarded GP."],
      order = 158,
      get = function() return not not bepgp.db.char.plusrollepgp end,
      set = function(info,val)
        bepgp.db.char.plusrollepgp = not bepgp.db.char.plusrollepgp
      end,
      hidden = function() return not (bepgp.db.char.mode == "plusroll" and bepgp:admin()) end,
    }
  end
  return self._options
end

function bepgp:ddoptions(refresh)
  local members = bepgp:buildRosterTable()
  self:debugPrint(string.format(L["Scanning %d members for EP/GP data. (%s)"],#(members),(bepgp.db.char.raidonly and "Raid" or "Full")))
  if not self._dda_options then
    self._dda_options = {
      type = "group",
      name = L["BastionLoot options"],
      desc = L["BastionLoot options"],
      handler = bepgp,
      args = { }
    }
    self._dda_options.args["mode"] = {
      type = "execute",
      name = switch_icon,
      desc = L["Switch Mode of Operation"],
      order = 5,
      func = function(info)
        local mode = bepgp.db.char.mode
        if mode == "epgp" then
          bepgp.db.char.mode = "plusroll"
          bepgp:SetMode("plusroll")
        else
          bepgp.db.char.mode = "epgp"
          bepgp:SetMode("epgp")
        end
      end,
    }
    self._dda_options.args["ep_raid"] = {
      type = "execute",
      name = L["+EPs to Raid"],
      desc = L["Award EPs to all raid members."],
      order = 10,
      func = function(info)
        LD:Spawn(addonName.."DialogGroupPoints", {"ep", C:Green(L["Effort Points"]), _G.RAID})
      end,
    }
    self._dda_options.args["ep"] = {
      type = "group",
      name = L["+EPs to Member"],
      desc = L["Account EPs for member."],
      order = 40,
      args = { },
    }
    self._dda_options.args["gp"] = {
      type = "group",
      name = L["+GPs to Member"],
      desc = L["Account GPs for member."],
      order = 50,
      args = { },
    }
    self._dda_options.args["roster"] = {
      type = "execute",
      name = L["Export Raid Roster"],
      desc = L["Export Raid Roster"],
      order = 55,
      func = function(info)
        local roster = bepgp:GetModule(addonName.."_roster")
        if roster then
          roster:Toggle()
        end
      end,
    }
  end
  if not self._ddm_options then
    self._ddm_options = {
      type = "group",
      name = L["BastionLoot options"],
      desc = L["BastionLoot options"],
      handler = bepgp,
      args = { }
    }
    self._ddm_options.args["mode"] = {
      type = "execute",
      name = switch_icon,
      desc = L["Switch Mode of Operation"],
      order = 5,
      func = function(info)
        local mode = bepgp.db.char.mode
        if mode == "epgp" then
          bepgp.db.char.mode = "plusroll"
          bepgp:SetMode("plusroll")
        else
          bepgp.db.char.mode = "epgp"
          bepgp:SetMode("epgp")
        end
      end,
    }
    self._ddm_options.args["roster"] = {
      type = "execute",
      name = L["Export Raid Roster"],
      desc = L["Export Raid Roster"],
      order = 10,
      func = function(info)
        local roster = bepgp:GetModule(addonName.."_roster")
        if roster then
          roster:Toggle()
        end
      end,
      disabled = function(info)
        local wrong_mode = (bepgp.db.char.mode ~= "plusroll")
        local not_ml = not (bepgp:lootMaster())
        return (wrong_mode or not_ml)
      end,
    }
  end
  if #(members) > 0 then
    self._dda_options.args["ep"].args = bepgp:buildClassMemberTable(members,"ep")
    self._dda_options.args["gp"].args = bepgp:buildClassMemberTable(members,"gp")
  else
    self._dda_options.args["ep"].args = {[_G.NONE]={type="execute",name=_G.NONE,func=function()end}}
    self._dda_options.args["gp"].args = {[_G.NONE]={type="execute",name=_G.NONE,func=function()end}}
  end
  return self._dda_options, self._ddm_options
end

function bepgp.OnLDBClick(obj,button)
  local is_admin = bepgp:admin()
  local mode = bepgp.db.char.mode
  local logs = bepgp:GetModule(addonName.."_logs")
  local alts = bepgp:GetModule(addonName.."_alts")
  local browser = bepgp:GetModule(addonName.."_browser")
  local standby = bepgp:GetModule(addonName.."_standby")
  local loot = bepgp:GetModule(addonName.."_loot")
  local bids = bepgp:GetModule(addonName.."_bids")
  local standings = bepgp:GetModule(addonName.."_standings")
  -- plusroll
  local reserves = bepgp:GetModule(addonName.."_plusroll_reserves")
  local rollbids = bepgp:GetModule(addonName.."_plusroll_bids")
  local rollloot = bepgp:GetModule(addonName.."_plusroll_loot")
  local rolllogs = bepgp:GetModule(addonName.."_plusroll_logs")
  local roll_admin = rollloot and rollloot:raidLootAdmin() or false
  if is_admin then
    if button == "LeftButton" then
      if IsControlKeyDown() and IsShiftKeyDown() then
        -- logs TODO: conditionally plusroll wincount
        if mode == "epgp" then
          if logs then
            logs:Toggle()
          end
        elseif mode == "plusroll" and roll_admin then
          if rollloot then -- wincount
            rollloot:Toggle()
          end
        end
      elseif IsControlKeyDown() and IsAltKeyDown() then
        -- alts
        if alts then
          alts:Toggle()
        end
      elseif IsAltKeyDown() and IsShiftKeyDown() then
        -- favorites
        if browser then
          browser:Toggle()
        end
      elseif IsControlKeyDown() then
        -- standby
        if standby then
          standby:Toggle()
        end
      elseif IsShiftKeyDown() then
        -- loot or reserves conditionally
        if mode == "epgp" then
          if loot then
            loot:Toggle()
          end
        elseif mode == "plusroll" and roll_admin then
          if reserves then
            reserves:Toggle()
          end
        end
      elseif IsAltKeyDown() then
        -- bids conditionally
        if mode == "epgp" then
          if bids then
            bids:Toggle(obj)
          end
        elseif mode == "plusroll" and roll_admin then
          if rollbids then
            rollbids:Toggle(obj)
          end
        end
      else
        if standings then
          standings:Toggle()
        end
      end
    elseif button == "RightButton" then
      bepgp:OpenAdminActions(obj)
    elseif button == "MiddleButton" then
      InterfaceOptionsFrame_OpenToCategory(bepgp.blizzoptions)
      InterfaceOptionsFrame_OpenToCategory(bepgp.blizzoptions)
    end
  else
    if button == "LeftButton" then
      if IsAltKeyDown() then
        if browser then
          browser:Toggle()
        end
      elseif IsControlKeyDown() and IsShiftKeyDown() and (mode == "plusroll") and roll_admin then
        if rollloot then
          rollloot:Toggle()
        end
      elseif IsControlKeyDown() and (mode == "plusroll") and roll_admin then
        if rollbids then
          rollbids:Toggle()
        end
      elseif IsShiftKeyDown() and (mode == "plusroll") and roll_admin then
        if reserves then
          reserves:Toggle()
        end
      else
        if standings then
          standings:Toggle()
        end
      end
    elseif button == "RightButton" then
      bepgp:OpenAdminActions(obj)
    elseif button == "MiddleButton" then
      InterfaceOptionsFrame_OpenToCategory(bepgp.blizzoptions)
      InterfaceOptionsFrame_OpenToCategory(bepgp.blizzoptions)
    end
  end
end

function bepgp.OnLDBTooltipShow(tooltip)
  tooltip = tooltip or GameTooltip
  local is_admin = bepgp:admin()
  local mode = bepgp.db.char.mode
  local title = string.format("%s [%s]",label,modes[mode])
  local rollloot = bepgp:GetModule(addonName.."_plusroll_loot")
  local roll_admin = rollloot and rollloot:raidLootAdmin() or false
  tooltip:SetText(title)
  tooltip:AddLine(" ")
  local hint = L["|cffff7f00Click|r to toggle Standings."]
  tooltip:AddLine(hint)
  if is_admin then
    tooltip:AddLine(" ")
    hint = L["|cffff7f00Alt+Click|r to toggle Bids."]
    tooltip:AddLine(hint)
    if mode == "epgp" then
      hint = L["|cffff7f00Shift+Click|r to toggle Loot."]
      tooltip:AddLine(hint)
    elseif mode == "plusroll" and roll_admin then
      hint = L["|cffff7f00Shift+Click|r to toggle Reserves."]
      tooltip:AddLine(hint)
    end
    hint = L["|cffff7f00Ctrl+Click|r to toggle Standby."]
    tooltip:AddLine(hint)
    hint = L["|cffff7f00Ctrl+Alt+Click|r to toggle Alts."]
    tooltip:AddLine(hint)
    hint = L["|cffff7f00Shift+Alt+Click|r to toggle Favorites."]
    tooltip:AddLine(hint)
    if mode == "epgp" then
      hint = L["|cffff7f00Ctrl+Shift+Click|r to toggle Logs."]
      tooltip:AddLine(hint)
    elseif mode == "plusroll" and roll_admin then
      hint = L["|cffff7f00Ctrl+Shift+Click|r to toggle Wincount."]
      tooltip:AddLine(hint)
    end
    tooltip:AddLine(" ")
    hint = L["|cffff7f00Middle Click|r for %s"]:format(L["Admin Options"])
    tooltip:AddLine(hint)
    hint = L["|cffff7f00Right Click|r for %s."]:format(L["Admin Actions"])
    tooltip:AddLine(hint)
  else
    hint = L["|cffff7f00Alt+Click|r to toggle Favorites."]
    tooltip:AddLine(hint)
    if mode == "plusroll" and roll_admin then
      hint = L["|cffff7f00Ctrl+Click|r to toggle Bids."]
      tooltip:AddLine(hint)
      hint = L["|cffff7f00Shift+Click|r to toggle Reserves."]
      tooltip:AddLine(hint)
      hint = L["|cffff7f00Ctrl+Shift+Click|r to toggle Wincount."]
      tooltip:AddLine(hint)
    end
    hint = L["|cffff7f00Right Click|r for %s."]:format(L["Member Actions"])
    tooltip:AddLine(hint)
    hint = L["|cffff7f00Middle Click|r for %s"]:format(L["Member Options"])
    tooltip:AddLine(hint)
  end
end

function bepgp:templateCache(id)
  local key = addonName..id
  self._dialogTemplates = self._dialogTemplates or {}
  if self._dialogTemplates[key] then return self._dialogTemplates[key] end
  if not self._dialogTemplates[key] then
    if id == "DialogMemberPoints" then
      self._dialogTemplates[key] = {
        hide_on_escape = true,
        show_whlle_dead = true,
        text = L["You are assigning %s %s to %s."],
        on_show = function(self)
          local what = self.data[1]
          local amount
          if what == "ep" then
            amount = bepgp:suggestEPAward()
          elseif what == "gp" then
            amount = 0
          end
          self.text:SetText(string.format(L["You are assigning %s %s to %s."],amount,self.data[2],self.data[3]))
        end,
        on_update = function(self,elapsed)
          self._elapsed = (self._elapsed or 0) + elapsed
          if self._elapsed > 0.9 and self._elapsed < 1.0 then
            self.delegate.on_show(self)
            self.delegate.on_update = nil
            self._elapsed = nil
          end
        end,
        editboxes = {
          {
            on_enter_pressed = function(self)
              local who = self:GetParent().data[3]
              local what = self:GetParent().data[1]
              local amount = tonumber(self:GetText())
              if amount then
                if what == "ep" then
                  bepgp:givename_ep(who,amount,true)
                elseif what == "gp" then
                  bepgp:givename_gp(who,amount)
                end
              end
              LD:Dismiss(addonName.."DialogMemberPoints")
            end,
            on_escape_pressed = function(self)
              self:ClearFocus()
            end,
            on_text_changed = function(self, userInput)
              local dialog_text = self:GetParent().text
              local data = self:GetParent().data
              dialog_text:SetText(string.format(L["You are assigning %s %s to %s."],self:GetText(),data[2],data[3]))
            end,
            on_show = function(self)
              local amount
              local data = self:GetParent().data
              local what = data[1]
              if what == "ep" then
                amount = bepgp:suggestEPAward()
              elseif what == "gp" then
                amount = 0
              end
              self:SetText(tostring(amount))
              self:SetFocus()
            end,
            text = tostring(bepgp:suggestEPAward()),
          },
        },
        buttons = {
          {
            text = _G.ACCEPT,
            on_click = function(self, button, down)
              local data = self.data
              local what, who = data[1],data[3]
              local amount = self.editboxes[1]:GetText()
              amount = tonumber(amount)
              if amount then
                if what == "ep" then
                  bepgp:givename_ep(who,amount,true)
                elseif what == "gp" then
                  bepgp:givename_gp(who,amount)
                end
              end
              LD:Dismiss(addonName.."DialogMemberPoints")
            end,
          },
        },
      }
    elseif id == "DialogGroupPoints" then
      self._dialogTemplates[key] = {
        hide_on_escape = true,
        show_whlle_dead = true,
        text = L["You are assigning %s %s to %s."],
        on_show = function(self)
          local amount = bepgp:suggestEPAward()
          self.text:SetText(string.format(L["You are assigning %s %s to %s."],amount,self.data[2],self.data[3]))
        end,
        on_update = function(self,elapsed)
          self._elapsed = (self._elapsed or 0) + elapsed
          if self._elapsed > 0.9 and self._elapsed < 1.0 then
            self.delegate.on_show(self)
            self.delegate.on_update = nil
            self._elapsed = nil
          end
        end,
        editboxes = {
          {
            on_enter_pressed = function(self)
              local who = self:GetParent().data[3]
              local what = self:GetParent().data[1]
              local amount = tonumber(self:GetText())
              if amount then
                if who == _G.RAID then
                  bepgp:award_raid_ep(amount)
                elseif who == L["Standby"] then
                  bepgp:award_standby_ep(amount)
                end
              end
              LD:Dismiss(addonName.."DialogGroupPoints")
            end,
            on_escape_pressed = function(self)
              self:ClearFocus()
            end,
            on_text_changed = function(self, userInput)
              local dialog_text = self:GetParent().text
              local data = self:GetParent().data
              dialog_text:SetText(string.format(L["You are assigning %s %s to %s."],self:GetText(),data[2],data[3]))
            end,
            on_show = function(self)
              local amount = bepgp:suggestEPAward()
              self:SetText(tostring(amount))
              self:SetFocus()
            end,
            text = tostring(bepgp:suggestEPAward()),
          },
        },
        buttons = {
          {
            text = _G.ACCEPT,
            on_click = function(self, button, down)
              local data = self.data
              local what, who = data[1],data[3]
              local amount = self.editboxes[1]:GetText()
              amount = tonumber(amount)
              if amount then
                if who == _G.RAID then
                  bepgp:award_raid_ep(amount)
                elseif who == L["Standby"] then
                  bepgp:award_standby_ep(amount)
                end
              end
              LD:Dismiss(addonName.."DialogGroupPoints")
            end,
          },
        },
      }
    elseif id == "DialogItemPoints" then
      self._dialogTemplates[key] = {
        hide_on_escape = true,
        show_whlle_dead = true,
        text = L["%s looted %s. What do you want to do?"],
        on_show = function(self)
          local data = self.data
          local loot_indices = data.loot_indices
          self.text:SetText(string.format(L["%s looted %s. What do you want to do?"],data[loot_indices.player_c],data[loot_indices.item]))
          if not bepgp:IsHooked(self.close_button, "OnClick") then
            bepgp:HookScript(self.close_button,"OnClick",function(f,button,down)
              local dialog = f:GetParent()
              if dialog then
                local data = dialog.data
                local loot_indices = data.loot_indices
                if loot_indices and loot_indices.action then
                  data[loot_indices.action] = bepgp.VARS.unassigned
                  local update = data[loot_indices.update] ~= nil
                  local loot = bepgp:GetModule(addonName.."_loot")
                  if loot then
                    loot:addOrUpdateLoot(data, update)
                  end
                end
              end
            end)
          end
        end,
        on_cancel = function(self)
          local data = self.data
          local loot_indices = data.loot_indices
          data[loot_indices.action] = bepgp.VARS.unassigned
          local update = data[loot_indices.update] ~= nil
          local loot = bepgp:GetModule(addonName.."_loot")
          if loot then
            loot:addOrUpdateLoot(data, update)
          end
        end,
        buttons = {
          { -- MainSpec GP
            text = L["Add MainSpec GP"],
            on_click = function(self, button, down)
              local data = self.data
              local loot_indices = data.loot_indices
              data[loot_indices.action] = bepgp.VARS.msgp
              local update = data[loot_indices.update] ~= nil
              local loot = bepgp:GetModule(addonName.."_loot")
              if loot then
                loot:addOrUpdateLoot(data, update)
              end
              local name = data[loot_indices.player]
              local gp = tonumber(data[loot_indices.price])
              bepgp:givename_gp(name, gp)
              LD:Dismiss(addonName.."DialogItemPoints")
            end,
          },
          { -- OffSpec GP
            text = L["Add OffSpec GP"],
            on_click = function(self, button, down)
              local data = self.data
              local loot_indices = data.loot_indices
              data[loot_indices.action] = bepgp.VARS.osgp
              local update = data[loot_indices.update] ~= nil
              local loot = bepgp:GetModule(addonName.."_loot")
              if loot then
                loot:addOrUpdateLoot(data, update)
              end
              local name = data[loot_indices.player]
              local gp = data[loot_indices.off_price]
              bepgp:givename_gp(name, gp)
              LD:Dismiss(addonName.."DialogItemPoints")
            end,
          },
          { -- Bank/D-E
            text = L["Bank or D/E"],
            on_click = function(self, button, down)
              local data = self.data
              local loot_indices = data.loot_indices
              data[loot_indices.action] = bepgp.VARS.bankde
              local update = data[loot_indices.update] ~= nil
              local loot = bepgp:GetModule(addonName.."_loot")
              if loot then
                loot:addOrUpdateLoot(data, update)
              end
              LD:Dismiss(addonName.."DialogItemPoints")
            end,
          },
          --[[{ -- Remind Me Later
            text = L["Remind me Later"],
            on_click = function(self, button, down)
              local data = self.data
              local loot_indices = data.loot_indices
              LD:Dismiss(addonName.."DialogItemPoints")
            end,
          },]]
        },
      }
    elseif id == "DialogItemPlusPoints" then
      self._dialogTemplates[key] = {
        hide_on_escape = true,
        show_whlle_dead = true,
        text = L["%s looted to %s. Mark it as.."],
        on_show = function(self)
          local data = self.data
          local loot_indices = data.loot_indices
          local from_log = data[loot_indices.log]
          self.text:SetText(string.format(L["%s looted to %s. Mark it as.."],data[loot_indices.item],data[loot_indices.player_c]))
        end,
        on_cancel = function(self)
          local data = self.data
          local loot_indices = data.loot_indices
          local player = data[loot_indices.player]
          local player_c = data[loot_indices.player_c]
          local item = data[loot_indices.item]
          local item_id = data[loot_indices.item_id]
          local from_log = data[loot_indices.log]
          local plusroll_loot = bepgp:GetModule(addonName.."_plusroll_loot")
          local plusroll_logs = bepgp:GetModule(addonName.."_plusroll_logs")
          if from_log then -- update from log
            local log_indices = data.log_indices
            local log_entry = bepgp.db.char.plusroll_logs[from_log]
            local tag = log_entry[log_indices.tag]
            if tag ~= "none" then
              if tag == "+1" then
                -- remove from wincount and update log
              end
            end
          else -- new entry
            if plusroll_logs then
              plusroll_logs:addToLog(player,player_c,item,item_id,"none")
            end
          end
        end,
        buttons = {
          { -- Won as reserve
            text = L["Reserve"],
            on_click = function(self, button, down)
              local data = self.data
              local loot_indices = data.loot_indices
              local player = data[loot_indices.player]
              local player_c = data[loot_indices.player_c]
              local item = data[loot_indices.item]
              local item_id = data[loot_indices.item_id]
              local from_log = data[loot_indices.log]
              local reserves = bepgp:GetModule(addonName.."_plusroll_reserves")
              local plusroll_logs = bepgp:GetModule(addonName.."_plusroll_logs")
              local plusroll_loot = bepgp:GetModule(addonName.."_plusroll_loot")
              if from_log then -- update
                local log_entry = bepgp.db.char.plusroll_logs[from_log]
                local log_indices = data.log_indices
                local tag = log_entry[log_indices.tag]
                if tag ~= "res" then
                  if reserves then
                    if reserves:IsReservedExact(player,item_id) then
                      reserves:RemoveReserve(player,item_id)
                    end
                  end
                  if tag == "+1" then
                    if plusroll_loot then
                      plusroll_loot:removeWincount(player,item_id)
                    end
                  end
                  if plusroll_logs then
                    plusroll_logs:updateLog(from_log,"res")
                  end
                end
              else -- new entry
                if bepgp.db.char.plusrollepgp then
                  local price = bepgp:GetPrice(item_id, bepgp.db.profile.progress)
                  if price and price > 0 then
                    bepgp:givename_gp(player, price)
                  end
                end
                if reserves then
                  if reserves:IsReservedExact(player,item_id) then
                    reserves:RemoveReserve(player,item_id)
                  end
                end
                if plusroll_logs then
                  plusroll_logs:addToLog(player,player_c,item,item_id,"res")
                end
              end
              LD:Dismiss(addonName.."DialogItemPlusPoints")
            end,
          },
          { -- Won as mainspec
            text = L["Mainspec"],
            on_click = function(self, button, down)
              local data = self.data
              local loot_indices = data.loot_indices
              local player = data[loot_indices.player]
              local player_c = data[loot_indices.player_c]
              local item = data[loot_indices.item]
              local item_id = data[loot_indices.item_id]
              local from_log = data[loot_indices.log]
              local plusroll_loot = bepgp:GetModule(addonName.."_plusroll_loot")
              local plusroll_logs = bepgp:GetModule(addonName.."_plusroll_logs")
              if from_log then
                local log_entry = bepgp.db.char.plusroll_logs[from_log]
                local log_indices = data.log_indices
                local tag = log_entry[log_indices.tag]
                if tag ~= "+1" then
                  if plusroll_loot then
                    plusroll_loot:addWincount(player,item_id)
                  end
                  if plusroll_logs then
                    plusroll_logs:updateLog(from_log,"+1")
                  end
                end
              else -- new entry
                if bepgp.db.char.plusrollepgp then
                  local price = bepgp:GetPrice(item_id, bepgp.db.profile.progress)
                  if price and price > 0 then
                    bepgp:givename_gp(player, price)
                  end
                end
                if plusroll_loot then
                  plusroll_loot:addWincount(player,item_id)
                end
                if plusroll_logs then
                  plusroll_logs:addToLog(player,player_c,item,item_id,"+1")
                end
              end
              LD:Dismiss(addonName.."DialogItemPlusPoints")
            end,
          },
          { -- Won as offspec
            text = L["Offspec"],
            on_click = function(self, button, down)
              local data = self.data
              local loot_indices = data.loot_indices
              local player = data[loot_indices.player]
              local player_c = data[loot_indices.player_c]
              local item = data[loot_indices.item]
              local item_id = data[loot_indices.item_id]
              local from_log = data[loot_indices.log]
              local plusroll_logs = bepgp:GetModule(addonName.."_plusroll_logs")
              local plusroll_loot = bepgp:GetModule(addonName.."_plusroll_loot")
              if from_log then
                local log_entry = bepgp.db.char.plusroll_logs[from_log]
                local log_indices = data.log_indices
                local tag = log_entry[log_indices.tag]
                if tag ~= "os" then
                  if tag == "+1" then
                    if plusroll_loot then
                      plusroll_loot:removeWincount(player,item_id)
                    end
                  end
                  if plusroll_logs then
                    plusroll_logs:updateLog(from_log,"os")
                  end
                end
              else -- new entry
                if bepgp.db.char.plusrollepgp then
                  local price = bepgp:GetPrice(item_id, bepgp.db.profile.progress)
                  if price and price > 0 then
                    local off_price = math.floor(price*bepgp.db.profile.discount)
                    if off_price > 0 then
                      bepgp:givename_gp(player, off_price)
                    end
                  end
                end
                if plusroll_logs then
                  plusroll_logs:addToLog(player,player_c,item,item_id,"os")
                end
              end
              LD:Dismiss(addonName.."DialogItemPlusPoints")
            end,
          },
        },
      }
    elseif id == "DialogMemberBid" then
      self._dialogTemplates[key] = {
        hide_on_escape = true,
        show_whlle_dead = true,
        is_exclusive = true,
        duration = 30,
        text = L["Bid Call for %s [%ds]"],
        on_show = function(self)
          local data = self.data
          local link = data[1]
          self.text:SetText(string.format(L["Bid Call for %s [%ds]"],link,self.duration))
          self:SetScript("OnEnter", function(f)
            GameTooltip:SetOwner(f, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(link)
            GameTooltip:Show()
          end)
          self:SetScript("OnLeave", function(f)
            if GameTooltip:IsOwned(f) then
              GameTooltip_Hide()
            end
          end)
          if not bepgp:IsHooked(self, "OnHide") then
            bepgp:HookScript(self,"OnHide",function(f)
              if GameTooltip:IsOwned(f) then
                GameTooltip_Hide()
              end
            end)
          end
        end,
        on_update = function(self,elapsed)
          local remain = self.time_remaining
          local link = self.data[1]
          self.text:SetText(string.format(L["Bid Call for %s [%ds]"],link,remain))
        end,
        buttons = {
          { -- MainSpec
            text = L["Bid Mainspec/Need"],
            on_click = function(self, button, down)
              local data = self.data
              local masterlooter = data[2]
              SendChatMessage("+","WHISPER",nil,masterlooter)
              LD:Dismiss(addonName.."DialogMemberBid")
            end,
          },
          { -- OffSpec
            text = L["Bid Offspec/Greed"],
            on_click = function(self, button, down)
              local data = self.data
              local masterlooter = data[2]
              SendChatMessage("-","WHISPER",nil,masterlooter)
              LD:Dismiss(addonName.."DialogMemberBid")
            end,
          },
        },
      }
    elseif id == "DialogMemberRoll" then
      self._dialogTemplates[key] = {
        hide_on_escape = true,
        show_whlle_dead = true,
        is_exclusive = true,
        duration = 30,
        text = L["Bid Call for %s [%ds]"],
        width = 360,
        on_show = function(self)
          local link = self.data
          self.text:SetText(string.format(L["Bid Call for %s [%ds]"],link,self.duration))
          self:SetScript("OnEnter", function(f)
            GameTooltip:SetOwner(f, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(link)
            GameTooltip:Show()
          end)
          self:SetScript("OnLeave", function(f)
            if GameTooltip:IsOwned(f) then
              GameTooltip_Hide()
            end
          end)
          if not bepgp:IsHooked(self, "OnHide") then
            bepgp:HookScript(self,"OnHide",function(f)
              if GameTooltip:IsOwned(f) then
                GameTooltip_Hide()
              end
            end)
          end
        end,
        on_update = function(self,elapsed)
          local remain = self.time_remaining
          local link = self.data
          self.text:SetText(string.format(L["Bid Call for %s [%ds]"],link,remain))
        end,
        buttons = {
          { -- MainSpec
            text = L["Roll Mainspec/Reserve"],
            on_click = function(self, button, down)
              RandomRoll("1", "100")
              LD:Dismiss(addonName.."DialogMemberRoll")
            end,
          },
          { -- OffSpec
            text = L["Roll Offspec/Sidegrade"],
            on_click = function(self, button, down)
              RandomRoll("1", "50")
              LD:Dismiss(addonName.."DialogMemberRoll")
            end,
          },
        },
      }
    elseif id == "DialogSetMain" then
      self._dialogTemplates[key] = {
        hide_on_escape = true,
        show_whlle_dead = true,
        text = L["Set your main to be able to participate in Standby List EPGP Checks."],
        on_show = function(self)
          self.text:SetText(L["Set your main to be able to participate in Standby List EPGP Checks."])
        end,
        editboxes = {
          {
            on_enter_pressed = function(self)
              local main = self:GetText()
              main = bepgp:Capitalize(main)
              local name, class = bepgp:verifyGuildMember(main)
              if name then
                bepgp.db.profile.main = name
              end
              LD:Dismiss(addonName.."DialogSetMain")
            end,
            on_escape_pressed = function(self)
              self:ClearFocus()
            end,
            on_show = function(self)
              self:SetText(bepgp.db.profile.main or "")
              self:SetFocus()
            end,
            text = bepgp.db.profile.main or "",
          },
        },
        buttons = {
          {
            text = _G.ACCEPT,
            on_click = function(self, button, down)
              local main = self.editboxes[1]:GetText()
              main = bepgp:Capitalize(main)
              local name, class = bepgp:verifyGuildMember(main)
              if name then
                bepgp.db.profile.main = name
              end
              LD:Dismiss(addonName.."DialogSetMain")
            end,
          },
        },
      }
    elseif id == "DialogClearLoot" then
      self._dialogTemplates[key] = {
        hide_on_escape = true,
        show_whlle_dead = true,
        text = L["There are %d loot drops stored. It is recommended to clear loot info before a new raid. Do you want to clear it now?"],
        on_show = function(self)
          self.text:SetText(L["There are %d loot drops stored. It is recommended to clear loot info before a new raid. Do you want to clear it now?"]:format(self.data))
        end,
        on_cancel = function(self)
          local data = self.data
          bepgp:Print(L["Loot info can be cleared at any time from the loot window button or '/bastionloot clearloot' command"])
        end,
        buttons = {
          {
            text = _G.YES,
            on_click = function(self, button, down)
              local loot = bepgp:GetModule(addonName.."_loot")
              if loot then
                loot:Clear()
              end
              LD:Dismiss(addonName.."DialogClearLoot")
            end,
          },
          {
            text = L["Show me"],
            on_click = function(self, button, down)
              local loot = bepgp:GetModule(addonName.."_loot")
              if loot then
                loot:Toggle()
              end
              LD:Dismiss(addonName.."DialogClearLoot")
              bepgp:Print(L["Loot info can be cleared at any time from the loot window or '/bastionloot clearloot' command"])
            end,
          },
        },
      }
    elseif id == "DialogStandbyCheck" then
      self._dialogTemplates[key] = {
        hide_on_escape = true,
        show_whlle_dead = true,
        text = L["Standby AFKCheck. Are you available? |cff00ff00%0d|rsec."],
        on_show = function(self)
          self.text:SetText(L["Standby AFKCheck. Are you available? |cff00ff00%0d|rsec."]:format(self.data))
        end,
        on_cancel = function(self)
          local data = self.data
          bepgp:Print(L["AFK Check Standby"])
        end,
        on_update = function(self,elapsed)
          self.data = self.data - elapsed
          self.text:SetText(L["Standby AFKCheck. Are you available? |cff00ff00%0d|rsec."]:format(self.data))
        end,
        duration = bepgp.VARS.timeout,
        buttons = {
          {
            text = _G.YES,
            on_click = function(self, button, down)
              local standby = bepgp:GetModule(addonName.."_standby")
              if standby then
                standby:sendCheckResponse()
              end
              LD:Dismiss(addonName.."DialogStandbyCheck")
            end,
          },
          {
            text = _G.NO,
            on_click = function(self, button, down)
              LD:Dismiss(addonName.."DialogStandbyCheck")
            end,
          },
        },
      }
    elseif id == "DialogResetPoints" then
      self._dialogTemplates[key] = {
        hide_on_escape = true,
        show_whlle_dead = true,
        text = L["|cffff0000Are you sure you want to wipe all EPGP data?|r"],
        buttons = {
          {
            text = _G.YES,
            on_click = function(self, button, down)
              bepgp:wipe_epgp()
            end,
          },
          {
            text = _G.CANCEL,
            on_click = function(self, button, down)
              LD:Dismiss(addonName.."DialogResetPoints")
            end,
          },
        }
      }
    end
  end
  return self._dialogTemplates[key]
end

function bepgp:OnInitialize() -- 1. ADDON_LOADED
  -- guild specific stuff should go in profile named after guild
  -- player specific in char
  self._versionString = GetAddOnMetadata(addonName,"Version")
  self._websiteString = GetAddOnMetadata(addonName,"X-Website")
  self._labelfull = string.format("%s %s",label,self._versionString)
  self.db = LibStub("AceDB-3.0"):New("BastionLootDB", defaults)
  self:options()
  self._options.args.profile = ADBO:GetOptionsTable(self.db)
  self._options.args.profile.guiHidden = true
  self._options.args.profile.cmdHidden = true
  AC:RegisterOptionsTable(addonName.."_cmd", self.cmdtable, {"bastionloot"})
  AC:RegisterOptionsTable(addonName, self._options)
  self.blizzoptions = ACD:AddToBlizOptions(addonName,nil,nil,"general")
  --self.blizzoptions:SetParent(InterfaceOptionsFramePanelContainer)
  --InterfaceOptionsFrame.categoryList = InterfaceOptionsFrame.categoryList or {}
  self.blizzoptions.profile = ACD:AddToBlizOptions(addonName, "Profiles", addonName, "profile")
  --self.blizzoptions.profile:SetParent(InterfaceOptionsFramePanelContainer)
  --tinsert(InterfaceOptionsFrame.categoryList, self.blizzoptions.profile)
  self.db.RegisterCallback(self, "OnProfileChanged", "RefreshConfig")
  self.db.RegisterCallback(self, "OnProfileCopied", "RefreshConfig")
  self.db.RegisterCallback(self, "OnProfileReset", "RefreshConfig")
  LDBO.type = "launcher"
  LDBO.text = label
  LDBO.label = string.format("%s %s",addonName,self._versionString)
  LDBO.icon = icons.epgp
  LDBO.OnClick = bepgp.OnLDBClick
  LDBO.OnTooltipShow = bepgp.OnLDBTooltipShow
  LDI:Register(addonName, LDBO, bepgp.db.profile.minimap)
end

function bepgp:OnEnable() -- 2. PLAYER_LOGIN
  if IsInGuild() then
    local guildname = GetGuildInfo("player")
    if not guildname then
      GuildRoster()
    end
    self._playerLevel = UnitLevel("player")
    if self._playerLevel and self._playerLevel < MAX_PLAYER_LEVEL then
      self:RegisterEvent("PLAYER_LEVEL_UP")
    end
    self._bucketGuildRoster = self:RegisterBucketEvent("GUILD_ROSTER_UPDATE",3.0)
  else
    bepgp:RegisterEvent("PLAYER_GUILD_UPDATE")
    -- TODO: Refactor parts that shouldn't be reliant on guild to initialize properly without a guild
    bepgp:ScheduleTimer("deferredInit",5)
  end
  self:SetMode(self.db.char.mode)
  if self:table_count(self.VARS.autoloot) > 0 then
    bepgp:RegisterEvent("LOOT_READY", "autoLoot")
    bepgp:RegisterEvent("LOOT_OPENED", "autoLoot")
  end
end

function bepgp:OnDisable() -- ADHOC

end

function bepgp:RefreshConfig()

end

function bepgp:SetMode(mode)
  self:Print(string.format(L["Mode set to %s."],modes[mode]))
  LDBO.icon = icons[mode]
  LDBO.text = string.format("%s [%s]",label,modes[mode])
end

function bepgp:guildInfoSettings()
  local now = GetTime()
  if not self._lastInfoScan or (self._lastInfoScan and (now - self._lastInfoScan) > self.VARS.timeout) then
    local ginfotxt = GetGuildInfoText()
    if ginfotxt and ginfotxt ~= "" and ginfotxt ~= GUILD_INFO_EDITLABEL then
      local system = self.db.profile.system
      local pricesystem = ginfotxt:match("{([^%c{}]+)}")
      if pricesystem and pricesystem ~= system then
        self.db.profile.system = pricesystem
        self:SetPriceSystem(GUILD_INFORMATION)
        self._lastInfoScan = now
      end
    end
  end
end

function bepgp:deferredInit(guildname)
  if self._initdone then return end
  local realmname = GetRealmName()
  if not realmname then return end
  local panelHeader = self:admin() and L["Admin Options"] or L["Member Options"]
  if guildname then
    self._guildName = guildname
    self:guildInfoSettings()
    self:guildBranding()

    local profilekey = guildname.." - "..realmname
    self._options.name = self._labelfull
    self._options.args.general.name = panelHeader
    self.db:SetProfile(profilekey)
    -- register our dialogs
    LD:Register(addonName.."DialogMemberPoints", self:templateCache("DialogMemberPoints"))
    LD:Register(addonName.."DialogGroupPoints", self:templateCache("DialogGroupPoints"))
    LD:Register(addonName.."DialogSetMain", self:templateCache("DialogSetMain"))
    LD:Register(addonName.."DialogClearLoot", self:templateCache("DialogClearLoot"))
    LD:Register(addonName.."DialogResetPoints", self:templateCache("DialogResetPoints"))
    self:tooltipHook()
    -- handle unnamed frames Esc
    self:RawHook("CloseSpecialWindows",true)
    -- comms
    self:RegisterComm(bepgp.VARS.prefix)
    -- monitor officernote changes
    if self:admin() then
      if not self:IsHooked("GuildRosterSetOfficerNote") then
        self:RawHook("GuildRosterSetOfficerNote",true)
      end
    end
    -- version check
    self:parseVersion(bepgp._versionString)
    local major_ver = self._version.major
    local addonMsg = string.format("VERSION;%s;%d",bepgp._versionString,major_ver)
    self:addonMessage(addonMsg,"GUILD")
    -- main
    self:testMain()
    -- group status change
    self:RegisterEvent("GROUP_ROSTER_UPDATE","testLootPrompt")
    self:RegisterEvent("GROUP_JOINED","testLootPrompt")
    self:RegisterEvent("GROUP_LEFT","testLootPrompt")
    self:RegisterEvent("PLAYER_ENTERING_WORLD","testLootPrompt")
    -- set price system
    bepgp:SetPriceSystem()
    -- register whisper responder
    self:setupResponder()
    -- set roll filter
    self:setupRollFilter()

    self._initdone = true
    self:SendMessage(addonName.."_INIT_DONE")
  else
    local profilekey = realmname
    local profilekey = realmname
    self._options.name = self._labelfull
    self._options.args.general.name = panelHeader
    self.db:SetProfile(profilekey)
    self:tooltipHook()
    -- handle unnamed frames Esc
    self:RawHook("CloseSpecialWindows",true)
    -- set price system
    bepgp:SetPriceSystem()
    -- set roll filter
    self:setupRollFilter()

    self._initdone = true
    self:SendMessage(addonName.."_INIT_DONE")
  end
  -- 2.5.1.39170 masterlooterframe bug workaround
  local oMasterLooterFrame_Show = _G.MasterLooterFrame_Show
  _G.MasterLooterFrame_Show = function(...)
    MasterLooterFrame:ClearAllPoints()
    oMasterLooterFrame_Show(...)
  end
  hooksecurefunc("MasterLooterFrame_OnHide", function(...)
    MasterLooterFrame:ClearAllPoints()
  end)
  -- workaround end
end

function bepgp:tooltipHook()
  local tipOptionGroup = bepgp.db.char.tooltip
  local status = tipOptionGroup.prinfo or tipOptionGroup.mlinfo or tipOptionGroup.favinfo or tipOptionGroup.useinfo
  if status then
    -- tooltip
    if not self:IsHooked(GameTooltip, "OnTooltipSetItem") then
      self:HookScript(GameTooltip, "OnTooltipSetItem", "AddTipInfo")
    end
    if not self:IsHooked(ItemRefTooltip, "OnTooltipSetItem") then
      self:HookScript(ItemRefTooltip, "OnTooltipSetItem", "AddTipInfo")
    end
  else
    -- tooltip
    if self:IsHooked(GameTooltip, "OnTooltipSetItem") then
      self:Unhook(GameTooltip, "OnTooltipSetItem")
    end
    if self:IsHooked(ItemRefTooltip, "OnTooltipSetItem") then
      self:Unhook(ItemRefTooltip, "OnTooltipSetItem")
    end
  end
end

function bepgp:AddTipInfo(tooltip,...)
  local name, link = tooltip:GetItem()
  local tipOptionGroup = bepgp.db.char.tooltip
  if name and link then
    local mode_epgp = bepgp.db.char.mode == "epgp"
    local mode_plusroll = bepgp.db.char.mode == "plusroll"
    local price, useful = self:GetPrice(link, self.db.profile.progress)
    local roll_admin = self:GroupStatus()=="RAID" and self:lootMaster()
    local is_admin = self:admin()
    local owner = tooltip:GetOwner()
    local item = Item:CreateFromItemLink(link)
    local itemid = item:GetItemID()
    if price then
      if tipOptionGroup.prinfo then
        local off_price = math.floor(price*self.db.profile.discount)
        local ep,gp = (self:get_ep(self._playerName) or 0), (self:get_gp(self._playerName) or bepgp.VARS.basegp)
        local pr,new_pr,new_pr_off = ep/gp, ep/(gp+price), ep/(gp+off_price)
        local pr_delta = new_pr - pr
        local pr_delta_off = new_pr_off - pr
        local textRight2 = string.format(L["pr:|cffff0000%.02f|r(%.02f) pr_os:|cffff0000%.02f|r(%.02f)"],pr_delta,new_pr,pr_delta_off,new_pr_off)
        local off_price = price*self.db.profile.discount
        local textRight = string.format(L["gp:|cff32cd32%d|r gp_os:|cff20b2aa%d|r"],price,off_price)
        tooltip:AddDoubleLine(label, textRight)
        tooltip:AddDoubleLine(" ", textRight2)
      end
      if tipOptionGroup.mlinfo then
        if roll_admin and is_admin and mode_epgp then
          if owner and owner._bepgpclicks then
            tooltip:AddDoubleLine(C:Yellow(L["Alt Click/RClick/MClick"]), C:Orange(L["Call for: MS/OS/Both"]))
          end
        end
      end
    end
    if tipOptionGroup.mlinfo and (roll_admin and mode_plusroll) then
      if owner and owner._bepgprollclicks then
        tooltip:AddDoubleLine(C:Yellow(L["Alt Click"]), C:Orange(L["Call for Rolls"]))
      end
    end
    local favorite = self.db.char.favorites[itemid]
    if tipOptionGroup.favinfo and favorite  then
      tooltip:AddLine(self._favmap[favorite])
    end
    if tipOptionGroup.useinfo and (type(useful)=="table" and #(useful)>0) then
      local line1,line2,line3 = "","",""
      for prio,class_specs in ipairs(useful) do
        if prio == 1 then -- 90%+ of top
          for k=1,#(class_specs),2 do
            local class,spec = class_specs[k],class_specs[k+1]
            local classspecstring = self:ClassSpecString(class,spec)
            if line1 == "" then
              line1 = classspecstring
            else
              line1 = line1 .. ", " .. classspecstring
            end
          end
          tooltip:AddDoubleLine(string.format("|cff33ff99%s|r",L["Useful for"]),line1)
        elseif prio == 2 then --80%+ of top
          for k=1,#(class_specs),2 do
            local class,spec = class_specs[k],class_specs[k+1]
            local classspecstring = self:ClassSpecString(class,spec)
            if line2 == "" then
              line2 = classspecstring
            else
              line2 = line2 .. ", " .. classspecstring
            end
          end
          tooltip:AddDoubleLine(" ",line2)
        elseif prio == 3 then --70%+ of top
          for k=1,#(class_specs),2 do
            local class,spec = class_specs[k],class_specs[k+1]
            local classspecstring = self:ClassSpecString(class,spec)
            if line3 == "" then
              line3 = classspecstring
            else
              line3 = line3 .. ", " .. classspecstring
            end
          end
          tooltip:AddDoubleLine(" ",line3)
        end
      end
    end
  end
end

function bepgp:autoLoot(event,auto)
  local numLoot = GetNumLootItems()
  if numLoot == 0 then return end
  if auto or (GetCVarBool("autoLootDefault") ~= IsModifiedClick("AUTOLOOTTOGGLE")) then
    return
  end
  for slot = numLoot,1,-1 do
    if LootSlotHasItem(slot) then
      local itemLink = GetLootSlotLink(slot)
      if (itemLink) then
        local _,_,_,itemID = self:getItemData(itemLink)
        if bepgp.VARS.autoloot[itemID] then
          LootSlot(slot)
          ConfirmLootSlot(slot)
        end
        if bepgp.db.char.favalert then
          if bepgp.db.char.favorites[itemID] then
            bepgp:Alert(string.format(L["BastionLoot Favorite: %s"],itemLink))
          end
        end
      end
    end
  end
end

local recipients = {}
function bepgp:sendThrottle(recipient)
  local now = GetTime()
  local prev = recipients[recipient]
  recipients[recipient] = now
  if prev and ((now-prev) < TOOLTIP_UPDATE_TIME) then
    return true
  end
end

local function epgpResponder(frame, event, text, sender, ...)
  if event == "CHAT_MSG_WHISPER" then
    local epgp, name = text:match("^[%c%s]*(![pP][rR])[%c%s%p]*([^%c%d%p%s]*)")
    local sender_stripped = Ambiguate(sender,"short")
    local guild_name, _, _, guild_officernote = bepgp:verifyGuildMember(sender_stripped,true,true) -- ignore level req
    if epgp and (epgp:upper()=="!PR") and guild_name then
      local _,perms = bepgp:getGuildPermissions()
      if perms.OFFICER then
        if name and strlen(name)>=2 then
          name = bepgp:Capitalize(name)
          local g_name, _, _, g_officernote = bepgp:verifyGuildMember(name,true)
          if g_name then
            local ep,gp
            local main_name, _, _, main_onote = bepgp:parseAlt(g_name, g_officernote)
            if main_name then
              ep = bepgp:get_ep(main_name,main_onote)
              gp = bepgp:get_gp(main_name,main_onote)
            else
              ep = bepgp:get_ep(g_name,g_officernote)
              gp = bepgp:get_gp(g_name,g_officernote)
            end
            if ep and gp then
              local pr = ep/gp
              local msg = string.format(L["{bepgp}%s has: %d EP %d GP %.03f PR."], name, ep,gp,pr)
              if not bepgp:sendThrottle(sender_stripped) then
                SendChatMessage(msg,"WHISPER",nil,sender_stripped)
              end
              return true
            end
          end
        else
          if sender_stripped ~= bepgp._playerName then
            local ep,gp
            local main_name, _, _, main_onote = bepgp:parseAlt(guild_name, guild_officernote)
            if main_name then
              ep = bepgp:get_ep(main_name,main_onote)
              gp = bepgp:get_gp(main_name,main_onote)
            else
              ep = bepgp:get_ep(guild_name,guild_officernote)
              gp = bepgp:get_gp(guild_name,guild_officernote)
            end
            if ep and gp then
              local pr = ep/gp
              local msg = string.format(L["{bepgp}You have: %d EP %d GP %.03f PR"], ep,gp,pr)
              if not bepgp:sendThrottle(sender_stripped) then
                SendChatMessage(msg,"WHISPER",nil,sender_stripped)
              end
              return true
            end
          end
        end
      end
    end
    return false, text, sender, ...
  elseif event == "CHAT_MSG_WHISPER_INFORM" then
    local epgp = text:match("^({bepgp}).*")
    if epgp then
      return true
    else
      return false, text, sender, ...
    end
  end
end

function bepgp:setupResponder()
  -- Hopefully anyone that can think of doing this
  -- also knows enough to not cause side-effects for filters coming after their own.
  local filters_incoming = ChatFrame_GetMessageEventFilters("CHAT_MSG_WHISPER")
  if filters_incoming and #(filters_incoming) > 0 then
    for index, filterFunc in next, filters_incoming do
      if ( filterFunc == epgpResponder ) then
        return
      end
    end
    tinsert(filters_incoming,1,epgpResponder)
  else
    ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", epgpResponder)
  end
  local filters_outgoing = ChatFrame_GetMessageEventFilters("CHAT_MSG_WHISPER_INFORM")
  if filters_outgoing and #(filters_outgoing) > 0 then
    for index, filterFunc in next, filters_outgoing do
      if ( filterFunc == epgpResponder ) then
        return
      end
    end
    tinsert(filters_outgoing,1,epgpResponder)
  else
    ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER_INFORM", epgpResponder)
  end
end

local function rollfilter(frame, event, text, sender, ...)
  local wrong_mode = bepgp.db.char.mode ~= "plusroll"
  local filter_off = not bepgp.db.char.rollfilter
  local not_raid = not IsInRaid()
  if wrong_mode or filter_off or not_raid then
    return false, text, sender, ...
  end
  local who, roll, low, high = DF.Deformat(text, RANDOM_ROLL_RESULT)
  if who then
    who = Ambiguate(who,"short")
    if who == bepgp._playerName then
      return false, text, sender, ...
    else
      return true
    end
  end
  return false, text, sender, ...
end

function bepgp:setupRollFilter()
  ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", rollfilter)
end

function bepgp:guildBranding()
  local f = CreateFrame("Frame", nil, UIParent)
  f:SetWidth(64)
  f:SetHeight(64)
  f:SetPoint("CENTER",UIParent,"CENTER",0,0)

  local tabardBackgroundUpper, tabardBackgroundLower, tabardEmblemUpper, tabardEmblemLower, tabardBorderUpper, tabardBorderLower = GetGuildTabardFileNames()
  if ( not tabardEmblemUpper ) then
    tabardBackgroundUpper = "Textures\\GuildEmblems\\Background_49_TU_U"
    tabardBackgroundLower = "Textures\\GuildEmblems\\Background_49_TL_U"
  end

  f.bgUL = f:CreateTexture(nil, "BACKGROUND")
  f.bgUL:SetWidth(32)
  f.bgUL:SetHeight(32)
  f.bgUL:SetPoint("TOPLEFT",f,"TOPLEFT",0,0)
  f.bgUL:SetTexCoord(0.5,1,0,1)
  f.bgUR = f:CreateTexture(nil, "BACKGROUND")
  f.bgUR:SetWidth(32)
  f.bgUR:SetHeight(32)
  f.bgUR:SetPoint("LEFT", f.bgUL, "RIGHT", 0, 0)
  f.bgUR:SetTexCoord(1,0.5,0,1)
  f.bgBL = f:CreateTexture(nil, "BACKGROUND")
  f.bgBL:SetWidth(32)
  f.bgBL:SetHeight(32)
  f.bgBL:SetPoint("TOP", f.bgUL, "BOTTOM", 0, 0)
  f.bgBL:SetTexCoord(0.5,1,0,1)
  f.bgBR = f:CreateTexture(nil, "BACKGROUND")
  f.bgBR:SetWidth(32)
  f.bgBR:SetHeight(32)
  f.bgBR:SetPoint("LEFT", f.bgBL, "RIGHT", 0,0)
  f.bgBR:SetTexCoord(1,0.5,0,1)

  f.bdUL = f:CreateTexture(nil, "BORDER")
  f.bdUL:SetWidth(32)
  f.bdUL:SetHeight(32)
  f.bdUL:SetPoint("TOPLEFT", f.bgUL, "TOPLEFT", 0,0)
  f.bdUL:SetTexCoord(0.5,1,0,1)
  f.bdUR = f:CreateTexture(nil, "BORDER")
  f.bdUR:SetWidth(32)
  f.bdUR:SetHeight(32)
  f.bdUR:SetPoint("LEFT", f.bdUL, "RIGHT", 0,0)
  f.bdUR:SetTexCoord(1,0.5,0,1)
  f.bdBL = f:CreateTexture(nil, "BORDER")
  f.bdBL:SetWidth(32)
  f.bdBL:SetHeight(32)
  f.bdBL:SetPoint("TOP", f.bdUL, "BOTTOM", 0,0)
  f.bdBL:SetTexCoord(0.5,1,0,1)
  f.bdBR = f:CreateTexture(nil, "BORDER")
  f.bdBR:SetWidth(32)
  f.bdBR:SetHeight(32)
  f.bdBR:SetPoint("LEFT", f.bdBL, "RIGHT", 0,0)
  f.bdBR:SetTexCoord(1,0.5,0,1)

  f.emUL = f:CreateTexture(nil, "BORDER")
  f.emUL:SetWidth(32)
  f.emUL:SetHeight(32)
  f.emUL:SetPoint("TOPLEFT", f.bgUL, "TOPLEFT", 0,0)
  f.emUL:SetTexCoord(0.5,1,0,1)
  f.emUR = f:CreateTexture(nil, "BORDER")
  f.emUR:SetWidth(32)
  f.emUR:SetHeight(32)
  f.emUR:SetPoint("LEFT", f.bdUL, "RIGHT", 0,0)
  f.emUR:SetTexCoord(1,0.5,0,1)
  f.emBL = f:CreateTexture(nil, "BORDER")
  f.emBL:SetWidth(32)
  f.emBL:SetHeight(32)
  f.emBL:SetPoint("TOP", f.emUL, "BOTTOM", 0,0)
  f.emBL:SetTexCoord(0.5,1,0,1)
  f.emBR = f:CreateTexture(nil, "BORDER")
  f.emBR:SetWidth(32)
  f.emBR:SetHeight(32)
  f.emBR:SetPoint("LEFT", f.emBL, "RIGHT", 0,0)
  f.emBR:SetTexCoord(1,0.5,0,1)

  f.bgUL:SetTexture(tabardBackgroundUpper)
  f.bgUR:SetTexture(tabardBackgroundUpper)
  f.bgBL:SetTexture(tabardBackgroundLower)
  f.bgBR:SetTexture(tabardBackgroundLower)

  f.emUL:SetTexture(tabardEmblemUpper)
  f.emUR:SetTexture(tabardEmblemUpper)
  f.emBL:SetTexture(tabardEmblemLower)
  f.emBR:SetTexture(tabardEmblemLower)

  f.bdUL:SetTexture(tabardBorderUpper)
  f.bdUR:SetTexture(tabardBorderUpper)
  f.bdBL:SetTexture(tabardBorderLower)
  f.bdBR:SetTexture(tabardBorderLower)

  f.mask = f:CreateMaskTexture()
  f.mask:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
  f.mask:SetSize(48,48)
  f.mask:SetPoint("CENTER", f, "CENTER", 0,0)
  f.bgUL:AddMaskTexture(f.mask)
  f.bgUR:AddMaskTexture(f.mask)
  f.bgBL:AddMaskTexture(f.mask)
  f.bgBR:AddMaskTexture(f.mask)
  f.bdUL:AddMaskTexture(f.mask)
  f.bdUR:AddMaskTexture(f.mask)
  f.bdBL:AddMaskTexture(f.mask)
  f.bdBR:AddMaskTexture(f.mask)

  f:SetScript("OnEnter",function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(bepgp._guildName)
    GameTooltip:AddLine(string.format(INSPECT_GUILD_NUM_MEMBERS,bepgp:table_count(bepgp.db.profile.guildcache)),1,1,1)
    GameTooltip:Show()
  end)
  f:SetScript("OnLeave",function(self)
    if GameTooltip:IsOwned(self) then
      GameTooltip_Hide()
    end
  end)
  self._guildLogo = f
  self._guildLogo:SetParent(self.blizzoptions)
  self._guildLogo:ClearAllPoints()
  self._guildLogo:SetPoint("TOPRIGHT", self.blizzoptions, "TOPRIGHT", 0,0)
  --self._guildLogo:SetIgnoreParentAlpha(true)
end

function bepgp:GuildRosterSetOfficerNote(index,note,fromAddon)
  if (fromAddon) then
    self.hooks["GuildRosterSetOfficerNote"](index,note)
  else
    local name, _, _, _, _, _, _, prevnote, _, _ = GetGuildRosterInfo(index)
    name = Ambiguate(name, "short")
    local _,_,_,oldepgp,_ = string.find(prevnote or "","(.*)({%d+:%d+})(.*)")
    local _,_,_,epgp,_ = string.find(note or "","(.*)({%d+:%d+})(.*)")
    if (self.db.profile.altspool) then
      local oldmain = self:parseAlt(name,prevnote)
      local main = self:parseAlt(name,note)
      if oldmain ~= nil then
        if main == nil or main ~= oldmain then
          self:adminSay(string.format(L["Manually modified %s\'s note. Previous main was %s"],name,oldmain))
          self:Print(string.format(L["|cffff0000Manually modified %s\'s note. Previous main was %s|r"],name,oldmain))
        end
      end
    end
    if oldepgp ~= nil then
      if epgp == nil or epgp ~= oldepgp then
        self:adminSay(string.format(L["Manually modified %s\'s note. EPGP was %s"],name,oldepgp))
        self:Print(string.format(L["|cffff0000Manually modified %s\'s note. EPGP was %s|r"],name,oldepgp))
      end
    end
    local safenote = string.gsub(note,"(.*)({%d+:%d+})(.*)",self.sanitizeNote)
    return self.hooks["GuildRosterSetOfficerNote"](index,safenote)
  end
end

function bepgp:addonMessage(msg, distro, target)
  local prio = "BULK"
  if distro == "WHISPER" then
    prio = "NORMAL"
  end
  self:SendCommMessage(bepgp.VARS.prefix,msg,distro,target,prio)
end

function bepgp:OnCommReceived(prefix, msg, distro, sender)
  if not prefix == bepgp.VARS.prefix then return end -- not our message
  local sender = Ambiguate(sender, "short")
  if sender == self._playerName then return end -- don't care for our own message
  local name, class, rank = self:verifyGuildMember(sender, true)
  if not name and class then return end -- only messages from guild
  local is_admin = self:admin()
  local who,what,amount
  for name,epgp,change in string.gmatch(msg,"([^;]+);([^;]+);([^;]+)") do
    who = name
    what = epgp
    amount = tonumber(change)
  end
  if (who) and (what) and (amount) then
    local out
    local for_main = (self.db.profile.main and (who == self.db.profile.main))
    if (who == self._playerName) or (for_main) then
      if what == "EP" then
        if amount < 0 then
          out = string.format(L["You have received a %d EP penalty."],amount)
        else
          out = string.format(L["You have been awarded %d EP."],amount)
        end
      elseif what == "GP" then
        out = string.format(L["You have gained %d GP."],amount)
      end
    elseif who == "ALL" and what == "DECAY" then
      out = string.format(L["%s%% decay to EP and GP."],amount)
    elseif who == "RAID" and what == "AWARD" then
      out = string.format(L["%d EP awarded to Raid."],amount)
    elseif who == "STANDBY" and what == "AWARD" then
      out = string.format(L["%d EP awarded to Reserves."],amount)
    elseif who == "VERSION" then
      local out_of_date, version_type = self:parseVersion(self._versionString,what)
      if (out_of_date) and self._newVersionNotification == nil then
        self._newVersionNotification = true -- only inform once per session
        self:Print(string.format(L["New %s version available: |cff00ff00%s|r"],version_type,what))
        self:Print(string.format(L["Visit %s to update."],self._websiteString))
      end
      if (IsGuildLeader()) then
        self:shareSettings()
      end
    elseif who == "SETTINGS" then
      for progress,discount,decay,minep,alts,altspct in string.gmatch(what, "([^:]+):([^:]+):([^:]+):([^:]+):([^:]+):([^:]+)") do
        discount = tonumber(discount)
        decay = tonumber(decay)
        minep = tonumber(minep)
        alts = (alts == "true") and true or false
        altspct = tonumber(altspct)
        local settings_notice
        if progress and progress ~= bepgp.db.profile.progress then
          bepgp.db.profile.progress = progress
          settings_notice = L["New raid progress"]
        end
        if discount and discount ~= bepgp.db.profile.discount then
          bepgp.db.profile.discount = discount
          if (settings_notice) then
            settings_notice = settings_notice..L[", offspec price %"]
          else
            settings_notice = L["New offspec price %"]
          end
        end
        if minep and minep ~= bepgp.db.profile.minep then
          bepgp.db.profile.minep = minep
          settings_notice = L["New Minimum EP"]
          bepgp:refreshPRTablets()
        end
        if decay and decay ~= bepgp.db.profile.decay then
          bepgp.db.profile.decay = decay
          if (is_admin) then
            if (settings_notice) then
              settings_notice = settings_notice..L[", decay %"]
            else
              settings_notice = L["New decay %"]
            end
          end
        end
        if alts ~= nil and alts ~= bepgp.db.profile.altspool then
          bepgp.db.profile.altspool = alts
          if (is_admin) then
            if (settings_notice) then
              settings_notice = settings_notice..L[", alts"]
            else
              settings_notice = L["New Alts"]
            end
          end
        end
        if altspct and altspct ~= bepgp.db.profile.altpercent then
          bepgp.db.profile.altpercent = altspct
          if (is_admin) then
            if (settings_notice) then
              settings_notice = settings_notice..L[", alts ep %"]
            else
              settings_notice = L["New Alts EP %"]
            end
          end
        end
        if (settings_notice) and settings_notice ~= "" then
          local _,_, hexclass = self:getClassData(class)
          local sender_rank = string.format("%s(%s)",C:Colorize(hexclass,sender),rank)
          settings_notice = settings_notice..string.format(L[" settings accepted from %s"],sender_rank)
          self:Print(settings_notice)
          self._options.args.general.args.main.args["progress_tier_header"].name = string.format(L["Progress Setting: %s"],bepgp.db.profile.progress)
          self._options.args.general.args.main.args["set_discount_header"].name = string.format(L["Offspec Price: %s%%"],bepgp.db.profile.discount*100)
          self._options.args.general.args.main.args["set_min_ep_header"].name = string.format(L["Minimum EP: %s"],bepgp.db.profile.minep)
        end
      end
    end
    if out and out~="" then
      self:Print(out)
      self:my_epgp(for_main)
    end
  end
end

function bepgp:debugPrint(msg,onlyWhenDebug)
  if onlyWhenDebug and not self._DEBUG then return end
  if not self._debugchat then
    for i=1,NUM_CHAT_WINDOWS do
      local tab = _G["ChatFrame"..i.."Tab"]
      local cf = _G["ChatFrame"..i]
      local tabName = tab:GetText()
      if tab ~= nil and (tabName:lower() == "debug") then
        self._debugchat = cf
        ChatFrame_RemoveAllMessageGroups(self._debugchat)
        ChatFrame_RemoveAllChannels(self._debugchat)
        self._debugchat:SetMaxLines(1024)
        break
      end
    end
  end
  if self._debugchat then
    self:Print(self._debugchat,msg)
  else
    self:Print(msg)
  end
end

function bepgp:simpleSay(msg)
  local perms = self:getGuildPermissions()
  if perms[self.db.profile.announce] then
    SendChatMessage(out_chat:format(msg), self.db.profile.announce)
  else
    self:Print(msg)
  end
end

function bepgp:adminSay(msg)
  local perms = self:getGuildPermissions()
  if perms.OFFICER then
    SendChatMessage(out_chat:format(msg),"OFFICER")
  end
end

local alertCache = {}
function bepgp:Alert(text)
  local now = GetTime()
  local lastAlert = alertCache[text]
  if not lastAlert or ((now - lastAlert) > 30) then
    PlaySound(SOUNDKIT.ALARM_CLOCK_WARNING_3,"Master")
    UIErrorsFrame:AddMessage(text, 1.0, 1.0, 0.0, 28, 4)
    alertCache[text] = now
  end
end

function bepgp:my_epgp_announce(use_main)
  local ep,gp
  local main = self.db.profile.main
  if (use_main) then
    ep,gp = (self:get_ep(main) or 0), (self:get_gp(main) or bepgp.VARS.basegp)
  else
    ep,gp = (self:get_ep(self._playerName) or 0), (self:get_gp(self._playerName) or bepgp.VARS.basegp)
  end
  local pr = ep/gp
  local msg = string.format(L["You now have: %d EP %d GP |cffffff00%.03f|r|cffff7f00PR|r."], ep,gp,pr)
  self:Print(msg)
  local pr_decay, cap_ep, cap_pr = self:capcalc(ep,gp)
  if pr_decay < 0 then
    msg = string.format(L["Close to EPGP Cap. Next Decay will change your |cffff7f00PR|r by |cffff0000%.4g|r."],pr_decay)
    self:Print(msg)
  end
  self._myepgpTimer = nil
end

function bepgp:my_epgp(use_main)
  GuildRoster()
  if not self._myepgpTimer then
    self._myepgpTimer = self:ScheduleTimer("my_epgp_announce",3,use_main)
  end
end

function bepgp:shareSettings(force)
  local now = GetTime()
  if self._lastSettingsShare == nil or (now - self._lastSettingsShare > 30) or (force) then
    self._lastSettingsShare = now
    local addonMsg = string.format("SETTINGS;%s:%s:%s:%s:%s:%s;1",self.db.profile.progress, self.db.profile.discount, self.db.profile.decay, self.db.profile.minep, tostring(self.db.profile.altspool), self.db.profile.altpercent)
    self:addonMessage(addonMsg,"GUILD")
  end
end

function bepgp:parseVersion(version,otherVersion)
  if not bepgp._version then bepgp._version = {} end
  for major,minor,patch in string.gmatch(version,"(%d+)[^%d]?(%d*)[^%d]?(%d*)") do
    bepgp._version.major = tonumber(major)
    bepgp._version.minor = tonumber(minor)
    bepgp._version.patch = tonumber(patch)
  end
  if (otherVersion) then
    if not bepgp._otherversion then bepgp._otherversion = {} end
    for major,minor,patch in string.gmatch(otherVersion,"(%d+)[^%d]?(%d*)[^%d]?(%d*)") do
      bepgp._otherversion.major = tonumber(major)
      bepgp._otherversion.minor = tonumber(minor)
      bepgp._otherversion.patch = tonumber(patch)
    end
    if (bepgp._otherversion.major ~= nil and bepgp._version.major ~= nil) then
      if (bepgp._otherversion.major < bepgp._version.major) then -- we are newer
        return
      elseif (bepgp._otherversion.major > bepgp._version.major) then -- they are newer
        return true, "major"
      else -- tied on major, go minor
        if (bepgp._otherversion.minor ~= nil and bepgp._version.minor ~= nil) then
          if (bepgp._otherversion.minor < bepgp._version.minor) then -- we are newer
            return
          elseif (bepgp._otherversion.minor > bepgp._version.minor) then -- they are newer
            return true, "minor"
          else -- tied on minor, go patch
            if (bepgp._otherversion.patch ~= nil and bepgp._version.patch ~= nil) then
              if (bepgp._otherversion.patch < bepgp._version.patch) then -- we are newer
                return
              elseif (bepgp._otherversion.patch > bepgp._version.patch) then -- they are newwer
                return true, "patch"
              end
            elseif (bepgp._otherversion.patch ~= nil and bepgp._version.patch == nil) then -- they are newer
              return true, "patch"
            end
          end
        elseif (bepgp._otherversion.minor ~= nil and bepgp._version.minor == nil) then -- they are newer
          return true, "minor"
        end
      end
    end
  end
end

function bepgp:widestAudience(msg)
  local groupstatus = self:GroupStatus()
  local channel
  if groupstatus == "RAID" then
    if (self:raidLeader() or self:raidAssistant()) then
      channel = "RAID_WARNING"
    else
      channel = "RAID"
    end
  elseif groupstatus == "PARTY" then
    channel = "PARTY"
  end
  if channel then
    SendChatMessage(msg, channel)
  end
end

function bepgp:CloseSpecialWindows()
  local found = securecall(self.hooks["CloseSpecialWindows"])
  for key,object in pairs(special_frames) do
    object:Hide()
  end
  return found
end

function bepgp:make_escable(object,operation)
  if type(object) == "string" then
    local found
    for i,f in ipairs(UISpecialFrames) do
      if f==object then
        found = i
      end
    end
    if not found and operation=="add" then
      table.insert(UISpecialFrames,object)
    elseif found and operation=="remove" then
      table.remove(UISpecialFrames,found)
    end
  elseif type(object) == "table" then
    if object.Hide then
      local key = tostring(object):gsub("table: ","")
      if operation == "add" then
        special_frames[key] = object
      else
        special_frames[key] = nil
      end
    end
  end
end

function bepgp:OpenAdminActions(obj)
  local is_admin = self:admin()
  if is_admin then
    self:ddoptions()
    self._ddmenu = LDD:OpenAce3Menu(self._dda_options)
  else
    self:ddoptions()
    self._ddmenu = LDD:OpenAce3Menu(self._ddm_options)
  end
  local scale, x, y = UIParent:GetEffectiveScale(), GetCursorPosition()
  local half_width, half_height = GetScreenWidth()*scale/2, GetScreenHeight()*scale/2
  local prefix,postfix,anchor
  if x >= half_width then
    postfix = "RIGHT"
  else
    postfix = "LEFT"
  end
  if y >= half_height then
    prefix = "TOP"
  else
    prefix = "BOTTOM"
  end
  anchor = prefix..postfix
  self._ddmenu:SetClampedToScreen(true)
  self._ddmenu:SetClampRectInsets(-25, 200, 25, -150)
  self._ddmenu:SetPoint(anchor, UIParent, "BOTTOMLEFT", x/scale, y/scale)
end

function bepgp:PLAYER_GUILD_UPDATE(...)
  local unitid = ...
  if unitid and UnitIsUnit(unitid,"player") then
    if IsInGuild() then
      self:OnEnable()
    end
  end
end

function bepgp:PLAYER_LEVEL_UP(event,...)
  local level = ...
  self._playerLevel = level
  if self._playerLevel == MAX_PLAYER_LEVEL then
    self:UnregisterEvent("PLAYER_LEVEL_UP")
  end
  if self._playerLevel and self._playerLevel >= bepgp.VARS.minlevel then
    self:testMain()
  end
end

function bepgp:GUILD_ROSTER_UPDATE()
  if GuildFrame and GuildFrame:IsShown() or InCombatLockdown() then
    return
  end
  local guildname = GetGuildInfo("player")
  if guildname then
    self:deferredInit(guildname)
  end
  if not self._initdone then return end
  local members = self:buildRosterTable()
  self:guildCache()
end

function bepgp:admin()
  return IsInGuild() and (CanEditOfficerNote())
end

function bepgp:lootMaster()
  if not IsInRaid() then return false end
  local method, partyidx, raididx = GetLootMethod()
  if method == "master" then
    if raididx and UnitIsUnit("player", "raid"..raididx) then
      return true
    elseif partyidx and (partyidx == 0) then
      return true
    else
      return false
    end
  else
    return false
  end
end

function bepgp:raidLeader()
  return IsInRaid() and UnitIsGroupLeader("player")
end

function bepgp:raidAssistant()
  return IsInRaid() and UnitIsGroupAssistant("player")
end

function bepgp:inRaid(name)
  local rid = UnitInRaid(name)
  local inraid = IsInRaid() and rid and (rid >= 0)
  if inraid then
    local groupcache = self.db.char.groupcache
    if not groupcache[name] then
      groupcache[name] = {}
      local member, rank, subgroup, level, lclass, eclass, zone, online, isDead, role, isML = GetRaidRosterInfo(rid)
      member = Ambiguate((member or ""),"short")
      if member and (member == name) and (member ~= _G.UNKNOWNOBJECT) then
        local _,_,hexColor = self:getClassData(lclass)
        local colortab = RAID_CLASS_COLORS[eclass]
        groupcache[member]["level"] = level
        groupcache[member]["class"] = lclass
        groupcache[member]["hex"] = hexColor
        groupcache[member]["color"] = colortab
      end
    end
  end
  return inraid
end

function bepgp:GroupStatus()
  if IsInRaid() and GetNumGroupMembers() > 0 then
    return "RAID"
  elseif UnitExists("party1") then
    return "PARTY"
  else
    return "SOLO"
  end
end

local raidZones = {
  [(GetRealZoneText(532))] = "T4",   -- Karazhan
  [(GetRealZoneText(565))] = "T4",   -- Gruul's Lair
  [(GetRealZoneText(544))] = "T4",   -- Magtheridon's Lair
  [(GetRealZoneText(550))] = "T5",   -- Tempest Keep (The Eye)
  [(GetRealZoneText(548))] = "T5",   -- Coilfang: Serpentshrine Cavern
  [(GetRealZoneText(564))] = "T6",   -- Black Temple
  [(GetRealZoneText(534))] = "T6",   -- The Battle for Mount Hyjal
  [(GetRealZoneText(568))] = "T5",   -- Zul'Aman
  [(GetRealZoneText(580))] = "T6.5"  -- The Sunwell
}
local mapZones = {
  [(C_Map.GetAreaInfo(3483))] = {"T4",(C_Map.GetAreaInfo(3547))}, -- Hellfire Peninsula - Throne of Kil'jaeden, Doom Lord Kazzak
  [(C_Map.GetAreaInfo(3520))] = {"T4",""}, -- Shadowmoon Valley, Doomwalker
}
local tier_multipliers = {
  ["T6.5"] =   {["T6.5"]=1,["T6"]=0.75,["T5"]=0.5,["T4"]=0.25},
  ["T6"]   =   {["T6.5"]=1,["T6"]=1,   ["T5"]=0.7,["T4"]=0.4},
  ["T5"]   =   {["T6.5"]=1,["T6"]=1,   ["T5"]=1,  ["T4"]=0.5},
  ["T4"]   =   {["T6.5"]=1,["T6"]=1,   ["T5"]=1,  ["T4"]=1}
}
function bepgp:suggestEPAward(debug)
  local currentTier, zoneLoc, checkTier, multiplier
  local inInstance, instanceType = IsInInstance()
  local inRaid = IsInRaid()
  if inInstance and instanceType == "raid" then
    local locZone, locSubZone = GetRealZoneText(), GetSubZoneText()
    checkTier = raidZones[locZone]
    if checkTier then
      currentTier = checkTier
    else -- fallback to substring check
      for zone, tier in pairs(raidZones) do
        if zone:find(locZone) then
          currentTier = tier
          break
        end
      end
    end
  else
    if inRaid then
      local locZone, locSubZone = GetRealZoneText(), GetSubZoneText()
      checkTier = mapZones[locZone] and mapZones[locZone][1]
      if checkTier then
        currentTier = checkTier
      end
    end
  end
  if currentTier then
    multiplier = tier_multipliers[self.db.profile.progress][currentTier]
    return tostring(multiplier*self.VARS.baseaward_ep)
  end
  return tostring(self.VARS.baseaward_ep)
end

function bepgp:SetPriceSystem(context)
  local system = self.db.profile.system
  if not price_systems[system] then
    self.GetPrice = price_systems[self.VARS.pricesystem]
    self.db.profile.system = self.VARS.pricesystem
    context = "DEFAULT"
  else
    self.GetPrice = price_systems[system]
  end
  if not (type(self.GetPrice)=="function") then -- fallback to first available
    for name,func in pairs(price_systems) do
      self.db.profile.system = name
      self.GetPrice = func
      context = "FALLBACK"
      break
    end
  end
  self:debugPrint(string.format(L["Price system set to: %q %s"],self.db.profile.system,(context or "")))
end

function bepgp:RegisterPriceSystem(name, priceFunc)
  price_systems[name]=priceFunc
end

function bepgp:getRaidID()
  if self.db.char.wincountmanual then
    return "RID:MANUAL"
  end
  local inInstance, instanceType = IsInInstance()
  local instanceMapName, instanceName, instanceID, instanceReset
  if inInstance and instanceType=="raid" then
    instanceMapName = GetRealZoneText()
    local savedInstances = GetNumSavedInstances()
    if savedInstances > 0 then
      for i=1,savedInstances do
        instanceName, instanceID, instanceReset = GetSavedInstanceInfo(i)
        if instanceName:lower() == instanceMapName:lower() then
          return string.format("%s:%s",instanceName,instanceID)
        end
      end
    end
  end
end

-------------------------------------------
--// UTILITY
-------------------------------------------
function bepgp:num_round(i)
  return math.floor(i+0.5)
end

function bepgp:table_count(t)
  local count = 0
  if type(t) == "table" then
    for k,v in pairs(t) do
      count = count+1
    end
  end
  return count
end

function bepgp:Capitalize(word)
  return (string.gsub(word,"^[%c%s]*([^%c%s%p%d])([^%c%s%p%d]*)",function(head,tail)
    return string.format("%s%s",string.upper(head),string.lower(tail))
    end))
end

local classSpecStringCache = {}
function bepgp:ClassSpecString(class,spec,text) -- pass it CLASS
  local key = class..(spec and "-"..spec or "")..(text and "text" or "")
  local cached = classSpecStringCache[key]
  if cached then
    return cached
  else
    if text then
      local eClass, lClass, hexclass = bepgp:getClassData(class) -- CLASS, class, classColor
      if spec then
        cached = string.format("|cff%s%s%s-%s%s|r",hexclass,lClass,bepgp._specmap[class].Icon,spec,bepgp._specmap[class][spec])
        classSpecStringCache[key] = cached
      else
        cached = string.format("|cff%s%s|r",hexclass,lClass,bepgp._specmap[class].Icon)
        classSpecStringCache[key] = cached
      end
    else
      if spec then
        cached = string.format("(%s:%s)",bepgp._specmap[class].Icon,bepgp._specmap[class][spec])
        classSpecStringCache[key] = cached
      else
        cached = string.format("(%s)",bepgp._specmap[class].Icon)
        classSpecStringCache[key] = cached
      end
    end
    if cached then return cached end
  end
end

function bepgp:getServerTime()
  local epoch = GetServerTime()
  local d = date("%Y-%m-%d",epoch)
  local t = date("%H:%M:%S",epoch)
  local timestamp = string.format("%s %s",d,t)
  return epoch, timestamp
end

function bepgp:sanitizeNote(epgp,postfix)
  local prefix = self
  -- reserve 12 chars for the epgp pattern {xxxxx:yyyy} max public/officernote = 31
  local remainder = string.format("%s%s",prefix,postfix)
  local clip = math.min(31-12,string.len(remainder))
  local prepend = string.sub(remainder,1,clip)
  return string.format("%s%s",prepend,epgp)
end

function bepgp:getClassData(class) -- CLASS, class, classColor
  local eClass = classToEnClass[class]
  local lClass = LOCALIZED_CLASS_NAMES_MALE[class] or LOCALIZED_CLASS_NAMES_FEMALE[class]
  if eClass then
    return eClass, class, hexClassColor[class]
  elseif lClass then
    return class, lClass, hexClassColor[lClass]
  end
end

function bepgp:getItemData(itemLink) -- itemcolor, itemstring, itemname, itemid
  local link_found, _, itemColor, itemString, itemName = string.find(itemLink, "^(|c%x+)|H(.+)|h(%[.+%])")
  if link_found then
    local itemID = GetItemInfoInstant(itemString)
    return itemColor, itemString, itemName, itemID
  else
    return
  end
end

--/print tostring(BastionLoot:itemBinding("item:19727"))
-- item:19865,item:19724,item:19872,item:19727,item:19708,item:19802,item:22637
function bepgp:itemBinding(itemString)
  G:SetHyperlink(itemString)
  if G:Find(item_bind_patterns.CRAFT,2,4,nil,true) then
  else
    if G:Find(item_bind_patterns.BOP,2,4,nil,true) then
      return bepgp.VARS.bop
    elseif G:Find(item_bind_patterns.QUEST,2,4,nil,true) then
      return bepgp.VARS.bop
    elseif G:Find(item_bind_patterns.BOE,2,4,nil,true) then
      return bepgp.VARS.boe
    elseif G:Find(item_bind_patterns.BOU,2,4,nil,true) then
      return bepgp.VARS.boe
    else
      return bepgp.VARS.nobind
    end
  end
  return
end

function bepgp:getItemQualityData(quality) -- id, name, qualityColor
  -- WARNING: itemlink parsed color does NOT match the one returned by the ITEM_QUALITY_COLORS table
  local id, hex = tonumber(quality), type(quality) == "string"
  if id and id >=0 and id <= 5 then
    return id, _G["ITEM_QUALITY"..id.."_DESC"], ITEM_QUALITY_COLORS[id].hex
  elseif hex then
    id = hexColorQuality[quality]
    if id then
      return id, _G["ITEM_QUALITY"..id.."_DESC"], quality
    end
  end
end

-- local fullName, rank, rankIndex, level, class, zone, note, officernote, online, isAway, classFileName, achievementPoints, achievementRank, isMobile, canSoR, repStanding, GUID = GetGuildRosterInfo(index)
function bepgp:verifyGuildMember(name,silent,levelignore)
  for i=1,GetNumGuildMembers(true) do
    local g_name, g_rank, g_rankIndex, g_level, g_class, g_zone, g_note, g_officernote, g_online, g_status, g_eclass, _, _, g_mobile, g_sor, _, g_GUID = GetGuildRosterInfo(i)
    g_name = Ambiguate(g_name,"short") --:gsub("(\-.+)","")
    local level = tonumber(g_level)
    if (string.lower(name) == string.lower(g_name)) and ((level >= bepgp.VARS.minlevel) or (levelignore and level > 0)) then
      return g_name, g_class, g_rank, g_officernote
    end
  end
  if (name) and name ~= "" and not (silent) then
    self:Print(string.format(L["%s not found in the guild or not raid level!"],name))
  end
  return
end

local speakPermissions,readPermissions = {},{}
function bepgp:getGuildPermissions()
  table.wipe(speakPermissions)
  table.wipe(readPermissions)
  for i=1,GetNumGuildMembers(true) do
    local name, _, rankIndex = GetGuildRosterInfo(i)
    name = Ambiguate(name,"short") --:gsub("(\-.+)","")
    if name == self._playerName then
      speakPermissions.OFFICER = C_GuildInfo.GuildControlGetRankFlags(rankIndex+1)[4]
      readPermissions.OFFICER = C_GuildInfo.GuildControlGetRankFlags(rankIndex+1)[11]
      break
    end
  end
  speakPermissions.GUILD = C_GuildInfo.CanSpeakInGuildChat()
  local groupstatus = self:GroupStatus()
  speakPermissions.PARTY = (groupstatus == "PARTY") or (groupstatus == "RAID")
  speakPermissions.RAID = groupstatus == "RAID"
  return speakPermissions,readPermissions
end

function bepgp:testMain()
  if not IsInGuild() then return end
  if (not self.db.profile.main) or self.db.profile.main == "" then
    if self._playerLevel and (self._playerLevel < bepgp.VARS.minlevel) then
      return
    else
      LD:Spawn(addonName.."DialogSetMain")
    end
  end
end

function bepgp:testLootPrompt(event)
  raidStatus = (self:GroupStatus() == "RAID") and true or false
  if (raidStatus == false) and (lastRaidStatus == nil or lastRaidStatus == true) then
    local hasLoothistory = #(self.db.char.loot)
    if hasLoothistory > 0 then
      LD:Spawn(addonName.."DialogClearLoot",hasLoothistory)
    end
  end
  lastRaidStatus = raidStatus
end

function bepgp:parseAlt(name,officernote)
  if (officernote) then
    local _,_,_,main,_ = string.find(officernote or "","(.*){([^%c%s%d{}][^%c%s%d{}][^%c%s%d{}]*)}(.*)")
    if type(main)=="string" and (string.len(main) < 13) then
      main = self:Capitalize(main)
      local g_name, g_class, g_rank, g_officernote = self:verifyGuildMember(main,true)
      if (g_name) then
        return g_name, g_class, g_rank, g_officernote
      else
        return nil
      end
    else
      return nil
    end
  else
    for i=1,GetNumGuildMembers(true) do
      local g_name, g_rank, g_rankIndex, g_level, g_class, g_zone, g_note, g_officernote, g_online, g_status, g_eclass, _, _, g_mobile, g_sor, _, g_GUID = GetGuildRosterInfo(i)
      g_name = Ambiguate(g_name,"short") --:gsub("(\-.+)","")
      if (name == g_name) then
        return self:parseAlt(g_name, g_officernote)
      end
    end
  end
  return nil
end

function bepgp:guildCache()
  table.wipe(self.db.profile.guildcache)
  table.wipe(self.db.profile.alts)
  for i = 1, GetNumGuildMembers(true) do
    local member_name,rank,_,level,class,_,note,officernote,_,_ = GetGuildRosterInfo(i)
    member_name = Ambiguate((member_name or ""),"short") --:gsub("(\-.+)","")
    if member_name and level and (member_name ~= UNKNOWNOBJECT) and (level > 0) then
      self.db.profile.guildcache[member_name] = {level,rank,class,(officernote or "")}
    end
  end
  for name,data in pairs(self.db.profile.guildcache) do
    local class,officernote = data[3], data[4]
    local main, main_class, main_rank = self:parseAlt(name,officernote)
    if (main) then
      data[5]=main
      if ((self._playerName) and (name == self._playerName)) then
        if (not self.db.profile.main) or (self.db.profile.main and self.db.profile.main ~= main) then
          self.db.profile.main = main
          self:Print(string.format(L["Your main has been set to %s"],self.db.profile.main))
        end
      end
      main = C:Colorize(hexClassColor[main_class], main)
      self.db.profile.alts[main] = self.db.profile.alts[main] or {}
      self.db.profile.alts[main][name] = class
    end
  end
  return self.db.profile.guildcache, self.db.profile.alts
end

function bepgp:buildRosterTable()
  local g, r = { }, { }
  local numGuildMembers = GetNumGuildMembers(true)
  if (self.db.char.raidonly) and self:GroupStatus()=="RAID" then
    for i = 1, GetNumGroupMembers() do
      local name, rank, subgroup, level, class, fileName, zone, online, isDead, role, isML = GetRaidRosterInfo(i)
      if name and name ~= _G.UNKNOWNOBJECT then
        name = Ambiguate(name,"short")
        if (name) then
          r[name] = true
        end
      end
    end
  end
  for i = 1, numGuildMembers do
    local member_name,rank,_,level,class,_,note,officernote,_,_ = GetGuildRosterInfo(i)
    if member_name and member_name ~= _G.UNKNOWNOBJECT then
      member_name = Ambiguate(member_name,"short") --:gsub("(\-.+)","")
      local level = tonumber(level)
      local is_raid_level = level and level >= bepgp.VARS.minlevel
      local main, main_class, main_rank = self:parseAlt(member_name,officernote)
      if (self.db.char.raidonly) and next(r) then
        if r[member_name] and is_raid_level then
          table.insert(g,{["name"]=member_name,["class"]=class,["onote"]=officernote,["alt"]=(not not main)})
        end
      else
        if is_raid_level then
          table.insert(g,{["name"]=member_name,["class"]=class,["onote"]=officernote,["alt"]=(not not main)})
        end
      end
    end
  end
  return g
end

function bepgp:buildClassMemberTable(roster,epgp)
  local desc,usage
  if epgp == "ep" then
    desc = L["Account EPs to %s."]
    usage = "<EP>"
  elseif epgp == "gp" then
    desc = L["Account GPs to %s."]
    usage = "<GP>"
  end
  local c = { }
  for i,member in ipairs(roster) do
    local class,name,is_alt = member.class, member.name, member.alt
    if (class) and (not is_alt) and (c[class] == nil) then
      c[class] = { }
      c[class].type = "group"
      c[class].name = C:Colorize(hexClassColor[class],class)
      c[class].desc = class .. " members"
      c[class].order = 1
      c[class].args = { }
    end
    if is_alt and (c["ALTS"] == nil) then
      c["ALTS"] = { }
      c["ALTS"].type = "group"
      c["ALTS"].name = C:Silver(L["Alts"])
      c["ALTS"].desc = L["Alts"]
      c["ALTS"].order = 9
      c["ALTS"].args = { }
    end
    local key
    if name and class then
      key = is_alt and "ALTS" or class
    end
    if (key) then
      if key == "ALTS" then
        local initial = name:sub(1,1)
        if c[key].args[initial] == nil then
          c[key].args[initial] = { }
          c[key].args[initial].type = "group"
          c[key].args[initial].name = initial
          c[key].args[initial].desc = initial
          c[key].args[initial].args = { }
        end
        if c[key].args[initial].args[name] == nil then
          c[key].args[initial].args[name] = { }
          c[key].args[initial].args[name].type = "execute"
          c[key].args[initial].args[name].name = name
          c[key].args[initial].args[name].desc = string.format(desc,name)
          c[key].args[initial].args[name].func = function(info)
            local what = epgp == "ep" and C:Green(L["Effort Points"]) or C:Red(L["Gear Points"])
            LD:Spawn(addonName.."DialogMemberPoints", {epgp, what, name})
          end
        end
      else
        if (c[key].args[name] == nil) then
          c[key].args[name] = { }
          c[key].args[name].type = "execute"
          c[key].args[name].name = name
          c[key].args[name].desc = string.format(desc,name)
          c[key].args[name].func = function(info)
            local what = epgp == "ep" and C:Green(L["Effort Points"]) or C:Red(L["Gear Points"])
            LD:Spawn(addonName.."DialogMemberPoints", {epgp, what, name})
          end
        end
      end
    end
  end
  return c
end

function bepgp:groupCache(member,update)
  local groupcache = self.db.char.groupcache
  if groupcache[member] and (not update) then
    return groupcache[member]
  else
    if self:GroupStatus()=="RAID" then
      groupcache[member] = groupcache[member] or {}
      for i=1,GetNumGroupMembers() do
        local name, rank, subgroup, level, lclass, eclass, zone, online, isDead, role, isML = GetRaidRosterInfo(i)
        name = Ambiguate((name or ""),"short")
        if name and (name == member) and (name ~= _G.UNKNOWNOBJECT) then
          local _,_,hexColor = self:getClassData(lclass)
          local colortab = RAID_CLASS_COLORS[eclass]
          groupcache[member]["level"] = level
          groupcache[member]["class"] = lclass
          groupcache[member]["hex"] = hexColor
          groupcache[member]["color"] = colortab
          break
        end
      end
      if self:table_count(groupcache[member]) > 0 then
        return groupcache[member]
      end
    end
  end
end

function bepgp:award_raid_ep(ep) -- awards ep to raid members in zone
  if IsInRaid() and GetNumGroupMembers()>0 then
    local guildcache = self:guildCache()
    for i = 1, GetNumGroupMembers() do
      local name, rank, subgroup, level, class, fileName, zone, online, isDead, role, isML = GetRaidRosterInfo(i)
      if name and name ~= _G.UNKNOWNOBJECT then
        if level == 0 or (not online) then
          level = (guildcache[name] and guildcache[name][1]) or 0
          self:debugPrint(string.format(L["%s is offline. Getting info from guild cache."],name))
        end
        if level >= bepgp.VARS.minlevel then
          local main = guildcache[name] and guildcache[name][5] or false
          if main and self:inRaid(main) then
            self:debugPrint(string.format(L["Skipping %s. Main %q is also in the raid."],name,main))
          else
            self:givename_ep(name,ep)
          end
        end
      end
    end
    self:simpleSay(string.format(L["Giving %d ep to all raidmembers"],ep))
    local logs = self:GetModule(addonName.."_logs")
    if logs then
      logs:addToLog(string.format(L["Giving %d ep to all raidmembers"],ep))
    end
    self:refreshPRTablets()
    local addonMsg = string.format("RAID;AWARD;%s",ep)
    self:addonMessage(addonMsg,"RAID")
  --[[else UIErrorsFrame:AddMessage(L["You aren't in a raid dummy"],1,0,0)]]
  end
end

function bepgp:award_standby_ep(ep) -- awards ep to reserve list
  local standby = self:GetModule(addonName.."_standby")
  if standby then
    if #(standby.roster) > 0 then
      self:guildCache()
      for i, standby in ipairs(standby.roster) do
        local name, class, rank, alt = unpack(standby)
        self:givename_ep(name, ep)
      end
      self:simpleSay(string.format(L["Giving %d ep to active standby"],ep))
      local logs = self:GetModule(addonName.."_logs")
      if logs then
        logs:addToLog(string.format(L["Giving %d ep to active standby"],ep))
      end
      local addonMsg = string.format("STANDBY;AWARD;%s",ep)
      self:addonMessage(addonMsg,"GUILD")
      table.wipe(standby.roster)
      table.wipe(standby.blacklist)
      self:refreshPRTablets()
      local standby = self:GetModule(addonName.."_standby")
      if standby then
        standby:Refresh()
      end
    end
  end
end

function bepgp:decay_epgp()
  if not (bepgp:admin()) then return end
  local decay = self.db.profile.decay
  local announce = self.db.profile.announce
  for i = 1, GetNumGuildMembers(true) do
    local name,_,_,_,class,_,note,officernote,_,_ = GetGuildRosterInfo(i)
    local ep,gp = self:get_ep(name,officernote), self:get_gp(name,officernote)
    if (ep and gp) then
      ep = self:num_round(ep*decay)
      gp = self:num_round(gp*decay)
      self:update_epgp(ep,gp,i,name,officernote)
    end
  end
  local msg = string.format(L["All EP and GP decayed by %s%%"],(1-decay)*100)
  self:simpleSay(msg)
  if not (announce=="OFFICER") then self:adminSay(msg) end
  local logs = self:GetModule(addonName.."_logs")
  if logs then
    logs:addToLog(msg)
  end
  self:refreshPRTablets()
  local addonMsg = string.format("ALL;DECAY;%s",(1-(decay or bepgp.VARS.decay))*100)
  self:addonMessage(addonMsg,"GUILD")
end

function bepgp:wipe_epgp()
  if not IsGuildLeader() then return end
  local announce = self.db.profile.announce
  for i = 1, GetNumGuildMembers(true) do
    local name,_,_,_,class,_,note,officernote,_,_ = GetGuildRosterInfo(i)
    local ep,gp = self:get_ep(name,officernote), self:get_gp(name,officernote)
    if (ep and gp) then
      self:update_epgp(0,bepgp.VARS.basegp,i,name,officernote)
    end
  end
  local msg = L["All EP and GP data has been reset."]
  self:simpleSay(msg)
  if not (announce=="OFFICER") then self:adminSay(msg) end
  local logs = self:GetModule(addonName.."_logs")
  if logs then
    logs:addToLog(msg)
  end
  self:refreshPRTablets()
end

function bepgp:get_ep(getname,officernote) -- gets ep by name or note
  if (officernote) then
    local _,_,ep = string.find(officernote,".*{(%d+):%d+}.*")
    return tonumber(ep)
  end
  for i = 1, GetNumGuildMembers(true) do
    local name, _, _, _, class, _, note, officernote, _, _ = GetGuildRosterInfo(i)
    name = Ambiguate(name,"short") --:gsub("(\-.+)","")
    local _,_,ep = string.find(officernote,".*{(%d+):%d+}.*")
    if (name==getname) then return tonumber(ep) end
  end
  return
end
function bepgp:get_gp(getname,officernote) -- gets gp by name or officernote
  if (officernote) then
    local _,_,gp = string.find(officernote,".*{%d+:(%d+)}.*")
    return tonumber(gp)
  end
  for i = 1, GetNumGuildMembers(true) do
    local name, _, _, _, class, _, note, officernote, _, _ = GetGuildRosterInfo(i)
    name = Ambiguate(name,"short") --:gsub("(\-.+)","")
    local _,_,gp = string.find(officernote,".*{%d+:(%d+)}.*")
    if (name==getname) then return tonumber(gp) end
  end
  return
end

function bepgp:init_notes(guild_index,name,officernote)
  local ep,gp = self:get_ep(name,officernote), self:get_gp(name,officernote)
  if not (ep and gp) then
    local initstring = string.format("{%d:%d}",0,bepgp.VARS.basegp)
    local newnote = string.format("%s%s",officernote,initstring)
    newnote = string.gsub(newnote,"(.*)({%d+:%d+})(.*)",self.sanitizeNote)
    officernote = newnote
  else
    officernote = string.gsub(officernote,"(.*)({%d+:%d+})(.*)",self.sanitizeNote)
  end
  GuildRosterSetOfficerNote(guild_index,officernote,true)
  return officernote
end

function bepgp:update_epgp(ep,gp,guild_index,name,officernote,special_action)
  officernote = self:init_notes(guild_index,name,officernote)
  local newnote
  if (ep) then
    ep = math.max(0,ep)
    newnote = string.gsub(officernote,"(.*{)(%d+)(:)(%d+)(}.*)",function(head,oldep,divider,oldgp,tail)
      return string.format("%s%s%s%s%s",head,ep,divider,oldgp,tail)
      end)
  end
  if (gp) then
    gp = math.max(bepgp.VARS.basegp,gp)
    if (newnote) then
      newnote = string.gsub(newnote,"(.*{)(%d+)(:)(%d+)(}.*)",function(head,oldep,divider,oldgp,tail)
        return string.format("%s%s%s%s%s",head,oldep,divider,gp,tail)
        end)
    else
      newnote = string.gsub(officernote,"(.*{)(%d+)(:)(%d+)(}.*)",function(head,oldep,divider,oldgp,tail)
        return string.format("%s%s%s%s%s",head,oldep,divider,gp,tail)
        end)
    end
  end
  if (newnote) then
    GuildRosterSetOfficerNote(guild_index,newnote,true)
  end
end

function bepgp:givename_ep(getname,ep,single) -- awards ep to a single character
  if not (self:admin()) then return end
  local postfix, alt = ""
  local guildcache = self.db.profile.guildcache
  local main = guildcache[getname] and guildcache[getname][5] or false
  if (main) then
    if self.db.profile.altspool then
      alt = getname
      getname = main
      ep = self:num_round(ep * self.db.profile.altpercent)
      postfix = string.format(L[", %s\'s Main."],alt)
    else
      local msg = string.format(L["%s is %s and %s is an Alt of %s. Skipping %s."],L["Enable Alts"],_G.OFF,getname,main,string.upper(L["ep"]))
      self:debugPrint(msg)
      return
    end
  end
  local newep = ep + (self:get_ep(getname) or 0)
  self:update_ep(getname,newep)
  local msg = string.format(L["Giving %d ep to %s%s."],ep,getname,postfix)
  local logs = self:GetModule(addonName.."_logs")
  if ep < 0 then -- inform member of penalty
    msg = string.format(L["%s EP Penalty to %s%s."],ep,getname,postfix)
    self:debugPrint(msg)
    self:adminSay(msg)
    if logs then
      logs:addToLog(msg)
    end
    local addonMsg = string.format("%s;%s;%s",getname,"EP",ep)
    self:addonMessage(addonMsg,"WHISPER",getname)
  else
    self:debugPrint(msg)
    if (single == true) then
      self:adminSay(msg)
      if logs then
        logs:addToLog(msg)
      end
    end
  end
end

function bepgp:givename_gp(getname,gp) -- assigns gp to a single character
  if not (self:admin()) then return end
  local postfix, alt = ""
  local guildcache = self.db.profile.guildcache
  local main = guildcache[getname] and guildcache[getname][5] or false
  if (main) then
    if self.db.profile.altspool then
      alt = getname
      getname = main
      postfix = string.format(L[", %s\'s Main."],alt)
    else
      local msg = string.format(L["%s is %s and %s is an Alt of %s. Skipping %s."],L["Enable Alts"],_G.OFF,getname,main,string.upper(L["gp"]))
      self:debugPrint(msg)
      return
    end
  end
  local oldgp = (self:get_gp(getname) or bepgp.VARS.basegp)
  local newgp = gp + oldgp
  self:update_gp(getname,newgp)
  self:debugPrint(string.format(L["Giving %d gp to %s%s."],gp,getname,postfix))
  local msg = string.format(L["Awarding %d GP to %s%s. (Previous: %d, New: %d)"],gp,getname,postfix,oldgp,math.max(bepgp.VARS.basegp,newgp))
  self:adminSay(msg)
  local logs = self:GetModule(addonName.."_logs")
  if logs then
    logs:addToLog(msg)
  end
  local addonMsg = string.format("%s;%s;%s",getname,"GP",gp)
  self:addonMessage(addonMsg,"WHISPER",getname)
end

function bepgp:update_ep(getname,ep)
  for i = 1, GetNumGuildMembers(true) do
    local name, _, _, _, class, _, note, officernote, _, _ = GetGuildRosterInfo(i)
    name = Ambiguate(name,"short") --:gsub("(\-.+)","")
    if (name==getname) then
      self:update_epgp(ep,nil,i,name,officernote)
    end
  end
end
function bepgp:update_gp(getname,gp)
  for i = 1, GetNumGuildMembers(true) do
    local name, _, _, _, class, _, note, officernote, _, _ = GetGuildRosterInfo(i)
    name = Ambiguate(name,"short") --:gsub("(\-.+)","")
    if (name==getname) then
      self:update_epgp(nil,gp,i,name,officernote)
    end
  end
end

function bepgp:capcalc(ep,gp,gain)
  -- CAP_EP = EP_GAIN*DECAY/(1-DECAY) CAP_PR = CAP_EP/base_gp
  local pr = ep/gp
  local ep_decayed = self:num_round(ep*self.db.profile.decay)
  local gp_decayed = math.max(bepgp.VARS.basegp,self:num_round(gp*self.db.profile.decay))
  local pr_decay = tonumber(string.format("%.03f",pr))-tonumber(string.format("%.03f",ep_decayed/gp_decayed))
  if (pr_decay < 0.1) then
    pr_decay = 0
  else
    pr_decay = -tonumber(string.format("%.02f",pr_decay))
  end
  local cycle_gain = tonumber(gain)
  local cap_ep, cap_pr
  if (cycle_gain) then
    cap_ep = self:num_round(cycle_gain*self.db.profile.decay/(1-self.db.profile.decay))
    cap_pr = tonumber(string.format("%.03f",cap_ep/bepgp.VARS.basegp))
  end
  return pr_decay, cap_ep, cap_pr
end

function bepgp:refreshPRTablets()
  local standings = self:GetModule(addonName.."_standings")
  if standings then
    standings:Refresh()
  end
  local bids = self:GetModule(addonName.."_bids")
  if bids then
    bids:Refresh()
  end
  local browser = self:GetModule(addonName.."_browser")
  if browser then
    browser:Refresh()
  end
end

_G[addonName] = bepgp

