--- @type Mq
local mq = require("mq")

local loader = {
	types = {
		commands = "commands",
		conditions = "conditions",
		items = "items",
		preferences = "preferences",
		sets = "sets",
	},
}

loader.filename = function(name, type)
	return ("%s/yalm/%s/%s.lua"):format(mq.luaDir, type, name)
end

loader.packagename = function(name, type)
	return ("yalm.config.%s.%s"):format(type, name)
end

loader.unload_package = function(name, type)
	package.loaded[loader.packagename(name, type)] = nil
end

loader.should_load = function(rule, loot_type, char_settings)
	if loot_type == loader.types.commands or loot_type == loader.types.conditions then
		return true
	elseif loot_type == loader.types.sets then
		for i in ipairs(char_settings[loot_type]) do
			local set = char_settings[loot_type][i]
			if rule.name == set.name and set.enabled then
				return true
			end
		end
	end

	return false
end

loader.load = function(rule, loot_type)
	local success, result = pcall(require, ("yalm.config.%s.%s"):format(loot_type, rule.name))
	if not success then
		result = nil
		rule.failed = true
		Write.Warn("%s registration failed: %s", loot_type, rule.name)
		Write.Warn('To get more error output, you could try: "/lua run yalm/config/%s/%s"', loot_type, rule.name)
	else
		if loot_type == loader.types.commands then
			rule.func = result

			if type(rule.func) == "function" then
				local tmp_func = rule.func
				rule.func = { action_func = tmp_func }
			elseif type(rule.func) ~= "table" then
				result = nil
				rule.failed = true
				Write.Warn("%s registration failed: %s, command functions not correctly defined", loot_type, rule.name)
				return
			end
		elseif loot_type == loader.types.conditions then
			rule.func = result

			if type(rule.func) == "function" then
				local tmp_func = rule.func
				rule.func = { condition_func = tmp_func }
			elseif type(rule.func) ~= "table" then
				result = nil
				rule.failed = true
				Write.Warn(
					"%s registration failed: %s, condition functions not correctly defined",
					loot_type,
					rule.name
				)
				return
			end
		elseif loot_type == loader.types.sets then
			rule.conditions = result.conditions
			rule.items = result.items
		end
		Write.Info("Registering %s: \ao%s\ax", loot_type, rule.name)
		rule.loaded = true
	end
end

loader.unload = function(rule, loot_type)
	Write.Info("Deregistering %s: \ao%s\ax", loot_type, rule.name)
	rule.unload_package(rule.name, loot_type)
	rule.loaded = false
	rule.func = nil
	rule.failed = nil
end

loader.reload = function(rule, loot_type)
	loader.unload(rule, loot_type)
	loader.load(rule, loot_type)
end

loader.manage = function(rule_list, loot_type, char_settings)
	for _, rule in pairs(rule_list) do
		local load_event = loader.should_load(rule, loot_type, char_settings)
		if not rule.loaded and not rule.failed and load_event then
			loader.load(rule, loot_type)
		elseif rule.loaded and not load_event then
			loader.unload(rule, loot_type)
		end
	end
end

return loader
