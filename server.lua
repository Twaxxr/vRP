local Tunnel = module("vrp", "lib/Tunnel")
local Proxy = module("vrp", "lib/Proxy")

vRP = Proxy.getInterface("vRP")
vRPclient = Tunnel.getInterface("vRP","vrp_taxi")

vRPStaxi = {}
Tunnel.bindInterface("vrp_taxi",vRPStaxi)
Proxy.addInterface("vrp_taxi",vRPStaxi)
vRPCtaxi = Tunnel.getInterface("vrp_taxi","vrp_taxi")

local taxiState = {}
local taxAmount = 500

RegisterCommand("duty", function(player,args)
	local user_id = vRP.getUserId({player})
	if user_id ~= nil then
		if vRP.hasGroup({user_id,"Taxi"}) then
		    vRPCtaxi.isInTaxiVeh(player,{}, function(taxiId)
			    if taxiId then
                	    if not taxiState[user_id] then
                           TriggerClientEvent("chatMessage",-1,"^4Taxi: ^0Soferul ^4"..GetPlayerName(player).." ^0este acum disponibil")
                           vRPCtaxi.onTaxiDuty(player,{taxiId})
                           taxiState[user_id] = {
                       	        driverId = user_id,
                       	        taxiId = taxiId
                            }
                	    else
                           vRPclient.notify(player,{"~y~Taxi: ~w~Te-ai dat deja pe duty on"})
						   vRPclient.notify(player,{"~r~Info: ~w~Daca vrei sa fii duty off paraseste taxi-ul"})
                	end
			    else
                    vRPclient.notify(player,{"~y~Taxi: ~w~Nu esti intr-un taxi"})
			    end
			end)
		else
			vRPclient.notify(player,{"~y~Taxi: ~w~Nu ai grad de taximetrist"})
		end
	end
end)

RegisterServerEvent("taxi:setFirstPasager")
AddEventHandler("taxi:setFirstPasager", function(nplayer)
	local player = source
	local user_id = vRP.getUserId({player})
	local ped = GetPlayerPed(player)

	local nplayer = nplayer
    local nuser_id = vRP.getUserId({nplayer})

    if taxiState[user_id] then
    	taxiState[user_id].earnings = 0
    	taxiState[user_id].passager = {nplayer,user_id}
    	taxiState[user_id].coords = GetEntityCoords(ped)

        vRPclient.notify(nplayer,{"~w~Te-ai urcat in ~y~taxi!\n~y~"..GetPlayerName(player).."~w~\n~w~Tariful pe kilometru: ~y~15.000$"})

        vRPCtaxi.updateNameAndEarnings(player,{
            GetPlayerName(nplayer),
            taxiState[user_id].earnings
        })

        vRPCtaxi.showOnScreenHud(nplayer,{
        	GetPlayerName(player),
        	taxiState[user_id].earnings,
        	taxiState[user_id].fare,
        	taxiState[user_id].taxiId,
        	user_id
        })
        vRPCtaxi.startClock(player,{})
    end
end)

RegisterServerEvent("taxi:checkPosition")
AddEventHandler("taxi:checkPosition", function()
    local player = source
    local user_id = vRP.getUserId({player})

    local ped = GetPlayerPed(player)
    local coords = GetEntityCoords(ped)
    if taxiState[user_id] then
        if taxiState[user_id].passager ~= nil then
        	if type(taxiState[user_id].passager) == 'table' then
        	local nplayer = taxiState[user_id].passager[1]
        	local nuser_id = taxiState[user_id].passager[2]
        	local nmoney = (vRP.getMoney({nuser_id}) + vRP.getBankMoney({nuser_id}))

        	    if #(coords - taxiState[user_id].coords) > 100 then
        		    taxiState[user_id].earnings = math.floor(((taxiState[user_id].earnings or 0) +(taxiState[user_id].fare or 15000)))
        		    taxiState[user_id].coords = coords
        		    if (nmoney - taxiState[user_id].earnings) < 100 then
        			    vRPclient.notify(player,{"~y~Taxi: ~w~Pasagerul aproape a ramas fara bani!"})
                    end
                end
                vRPCtaxi.updateNameAndPaid(nplayer,{GetPlayerName(player),taxiState[user_id].earnings})
                vRPCtaxi.updateNameAndEarnings(player,{GetPlayerName(nplayer),taxiState[user_id].earnings})
		    end 
        end
    end
end)

RegisterServerEvent("taxi:passagerLeft")
AddEventHandler("taxi:passagerLeft", function(driverId)
	local player = source
	local user_id = vRP.getUserId({player})
	if taxiState[driverId] then
		local nuser_id = driverId
		local nplayer = vRP.getUserSource({nuser_id})
		local payOut = taxiState[nuser_id].earnings
		if nplayer then
			if payOut > 0 then
				if vRP.tryFullPayment({user_id,payOut}) then
					vRP.giveMoney({nuser_id,payOut})
					vRPclient.notify(player,{"Ai platit ~g~"..vRP.formatMoney({payOut}).."$ ~w~pentru cursa cu taxi-ul"})
					vRPclient.notify(nplayer,{"Ai primit ~g~"..vRP.formatMoney({payOut}).."$ ~w~pentru cursa cu taxi-ul"})
				end
			end
			taxiState[nuser_id].earnings = 0
			taxiState[nuser_id].passager = nil
			taxiState[nuser_id].coords = nil
			vRPCtaxi.passagerLeft(nplayer,{})
		end
	end
end)

RegisterServerEvent("taxi:setState")
AddEventHandler("taxi:setState", function(state)
	local player = source
	local user_id = vRP.getUserId({player})
	if not state then
		if type(taxiState[user_id].passager) == 'table' then
			local nplayer = taxiState[user_id].passager[1]
			local nuser_id = taxiState[user_id].passager[2]
			if nplayer then
				vRPclient.notify(nplayer,{"~r~Cursa ~w~a fost anulata, ~y~soferul ~w~a parasit masina"})
				if player then
					if vRP.tryFullPayment({user_id,taxAmount}) then
						vRPclient.notify(player,{"~w~Ai iesit din masina, asa ca ai platit ~y~"..vRP.formatMoney({taxAmount}).."$"})
					end
				end
			end
		end
		taxiState[user_id] = nil
	end
end)

AddEventHandler("playerDropped", function(reason)
	local player = source
	local user_id = vRP.getUserId({player})
	if taxiState[user_id] then
		if type(taxiState[user_id].passager) == 'table' then
			local nplayer = taxiState[user_id].passager[1]
			local nuser_id = taxiState[user_id].passager[2]
			if nplayer then
                vRPclient.notify(player,{"~y~Taxi: ~w~Soferul a dat disconnect, cursa a fost anulata!"})
			end
		end
		taxiState[user_id] = nil
	end
end)