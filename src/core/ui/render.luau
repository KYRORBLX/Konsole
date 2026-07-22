--!strict

--[[
	@name render
	@author driftingAurora, dullflowerr, alias; kioukaii
	@time June 12, 2026
]]

--// imports
local ConfigModule = require("../../config")

local imports = {
	Config = ConfigModule,
	Controller = require("./elements/backend/controller"),
	Formatter = require("./elements/backend/formatter"),
	Result = require("./elements/backend/result"),
	Text = require("./elements/misc/text"),
}

--// types
export type ConfigOverrides = ConfigModule.ConfigOverrides
export type Config = ConfigModule.MergedConfig

export type Client = any

--// public api
local Render = {
	Formatter = imports.Formatter,
	Result = imports.Result,
	Text = imports.Text,
}

function Render.config(options: ConfigOverrides?): Config
	return imports.Config.merge(options)
end

function Render.new(options: ConfigOverrides?): Client
	return imports.Controller.new(imports.Config.merge(options))
end

return Render
