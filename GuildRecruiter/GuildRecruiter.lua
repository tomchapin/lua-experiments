-- First, we create a namespace for our addon by declaring a top-level table that will hold everything else.
GuildRecruiter = {}
 
-- This isn't strictly necessary, but we'll use this string later when registering events.
-- Better to define it in a single place rather than retyping the same string.
GuildRecruiter.name = "GuildRecruiter"

-- Set the defaults
GuildRecruiter.defaults = {
	playersInvited = {},
	invitationQueue = {},
	guildNumber = 1,
	secondsBetweenInvites = 20,
	lastInviteSent = 0,
	eventLoopInterval = 1000
}

-- Don't touch this! (used for internal tracking purposes)
GuildRecruiter.eventLoopRunning = false
 
-- Next we create a function that will initialize our addon
function GuildRecruiter:Initialize()
	self.savedVariables = ZO_SavedVars:NewAccountWide("guild_recruiter_data", 1, self.name, GuildRecruiter.defaults)

	EVENT_MANAGER:RegisterForEvent(self.name, EVENT_CHAT_MESSAGE_CHANNEL, self.OnChatMessageReceived)
	GuildRecruiter.StartEventLoop()
	
	d("Guild Recruiter loaded...")
end
 
function GuildRecruiter.OnChatMessageReceived(event, messageType, fromName, text)
	-- Only invite if the guild has less than 500 members
	if GuildRecruiter.GuildNotFull() == true then
		-- Only add players seen in say (0) and zone chat (31)
		if messageType == 0 or messageType == 31 then
			local parsedPlayerName = GuildRecruiter.ParsePlayerName(fromName)
			GuildRecruiter.AddPlayerToInviteQueue(parsedPlayerName)
		end
	end
end

function GuildRecruiter.GuildNotFull()
	return GetNumGuildMembers(GuildRecruiter.savedVariables.guildNumber) < 500
end

function GuildRecruiter.RunEventLoop()
	if GuildRecruiter.eventLoopRunning == true and GuildRecruiter.GuildNotFull() == true then
		-- Handle the invitation queue
		GuildRecruiter.HandleInvitationQueue()
	
		-- Look for any players under our mouse reticle
		if IsReticleHidden() == false and IsUnitPlayer("reticleover") == true then
			local parsedPlayerName = GuildRecruiter.ParsePlayerName(GetRawUnitName("reticleover"))
			if parsedPlayerName ~= "" then
				GuildRecruiter.AddPlayerToInviteQueue(parsedPlayerName)
			end			
		end
		
		-- Loop!
		zo_callLater(GuildRecruiter.RunEventLoop, GuildRecruiter.savedVariables.eventLoopInterval)
	end
end

function GuildRecruiter.StartEventLoop()
	GuildRecruiter.eventLoopRunning = true
	GuildRecruiter.RunEventLoop()
end

function GuildRecruiter.StopEventLoop()
	GuildRecruiter.eventLoopRunning = false
end

function GuildRecruiter.ParsePlayerName(pname)
	return pname:gsub("%^Mx",""):gsub("%^Fx",""):gsub("%^n",""):gsub("%^p","")
end

function GuildRecruiter.AddPlayerToInviteQueue(pname)
	if GuildRecruiter.savedVariables.playersInvited[pname] ~= 1 then
		GuildRecruiter.savedVariables.playersInvited[pname] = 1
		table.insert(GuildRecruiter.savedVariables.invitationQueue, pname)
		d(string.format("Added player to guild invite queue: %s", pname))
	end
end

function GuildRecruiter.HandleInvitationQueue()
	if table.getn(GuildRecruiter.savedVariables.invitationQueue) > 0 then
		if GetTimeStamp() - GuildRecruiter.savedVariables.lastInviteSent > GuildRecruiter.savedVariables.secondsBetweenInvites then
			GuildRecruiter.InitiateInviteFromQueue()
		end
	end
end

function GuildRecruiter.InitiateInviteFromQueue()
	if table.getn(GuildRecruiter.savedVariables.invitationQueue) > 0 then
		local playerName = table.remove(GuildRecruiter.savedVariables.invitationQueue, 1)
		GuildRecruiter.AddPlayerToGuild(playerName, GuildRecruiter.savedVariables.guildNumber)
		GuildRecruiter.savedVariables.lastInviteSent = GetTimeStamp()
	end
end

function GuildRecruiter.AddPlayerToGuild(playerName, guildId)
	local guildName = GetGuildName(guildId)
	GuildInvite(guildId, playerName)
	-- d(string.format("Invited %s into guild %s", playerName, guildName))
end

-- Then we create an event handler function which will be called when the "addon loaded" event
-- occurs. We'll use this to initialize our addon after all of its resources are fully loaded.
function GuildRecruiter.OnAddOnLoaded(event, addonName)
	-- The event fires each time *any* addon loads - but we only care about when our own addon loads.
	if addonName == GuildRecruiter.name then
		GuildRecruiter:Initialize()
	end
end
 
-- Finally, we'll register our event handler function to be called when the proper event occurs.
EVENT_MANAGER:RegisterForEvent(GuildRecruiter.name, EVENT_ADD_ON_LOADED, GuildRecruiter.OnAddOnLoaded)