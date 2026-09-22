local function OnSessionLoaded()
	-- Change "Musical Instrument" to "Trinket" on tooltips for BetterTooltips users.
	Ext.Loca.UpdateTranslatedString("h70a42b6bg2d66g48e1ga2d9g25afceabd190", "Trinket")
end

Ext.Events.SessionLoaded:Subscribe(OnSessionLoaded)

Ext.Require("Shared/_Init.lua")
Ext.Require("Client/_Init.lua")
