--!strict

--[[
	@name render
	@author driftingAurora, dullflowerr, alias; kioukaii
	@time June 12, 2026
]]

--// imports
local ConfigModule = require("../../config")

local Imports = {
	Config = ConfigModule,

	Controller = require("./elements/backend/controller"),
	Formatter = require("./elements/backend/formatter"),

	Result = require("./elements/backend/result"),
	Text = require("./elements/misc/text"),
}

local Types = require("../../types/uiTypes")

--// types
export type ConfigOverrides = Types.ConfigOverrides
export type Config = Types.Config
export type Client = Types.Client

--// public api
local Render = {
	Formatter = Imports.Formatter,
	Result = Imports.Result,
	Text = Imports.Text,
}

function Render.config(options: ConfigOverrides?): Config
	return Imports.Config.merge(options)
end

function Render.new(options: ConfigOverrides?): Client
	return Imports.Controller.new(Imports.Config.merge(options))
end

return Render
