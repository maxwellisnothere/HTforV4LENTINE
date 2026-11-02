-- Insert this at the VERY TOP of the existing api.dukehub.lol/loader response.
-- HT gets its dedicated loader. Other games continue into the existing loader.
if game.GameId == 10769401924 or game.GameId == 10771222399 then
	return loadstring(game:HttpGet("https://raw.githubusercontent.com/maxwellisnothere/HTforV4LENTINE/main/loader.luau"))()
end
