local CONSUMERTOKEN = '---'
local CONSUMERSECRET = '---'

local ACCESSTOKEN = storage.accesstoken or nil
local TOKENSECRET = storage.tokensecret or nil

local threshold = 2000 --steps threshold

local debug = ""

local isAlerted = storage.alerted or false
local checked = storage.checked or false


local date = os.date("%Y").."-"..os.date("%m").."-"..os.date("%d")

local steps = {}
steps[1] = 0

function check_fitbit()
	local response = http.request {
	url='http://api.fitbit.com/1/user/23THB6/activities/date/'..date..'.json',
	auth = { oauth = {
			consumertoken = CONSUMERTOKEN,
			consumersecret = CONSUMERSECRET,
			--accesstoken = '86c1778f981fe910ef64fb41b2c5c045',
			--tokensecret = 'efc03977109afb4a524903be50b41c26'
			accesstoken = ACCESSTOKEN,
			tokensecret = TOKENSECRET
		}}
}
	return {json.parse(response.content).summary.steps}
end

function controlWemo(status, port) 
	local response = http.request {
		url = 'http://83.212.96.61:'..tonumber(port)..'/upnp/control/basicevent1',
		method = 'POST',
		headers = { 
			charset='utf-8', 
			SOAPACTION = '"urn:Belkin:service:basicevent:1#SetBinaryState"'
		},
		data = '<?xml version="1.0" encoding="utf-8"?><s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><s:Body><u:SetBinaryState xmlns:u="urn:Belkin:service:basicevent:1"><BinaryState>'..status..'</BinaryState></u:SetBinaryState></s:Body></s:Envelope>'
	}

	return response
end

function talkPusher(status)
	local pusher = require('pusher')
	local response = pusher.send(35559, 'KEY', 'SECRET', 'fitbit', 'fitbit', status)
end

function docheck()
	local time_zone = (tonumber(os.date("%H"))+2)
	if time_zone < 18 then
		checked = false
		storage.checked = false;
		debug="time reset"
	end
	if isAlerted==true then
		debug = "wemo switch control"
		steps = check_fitbit()
		if tonumber(steps[1])<threshold then
			--controlWemo(0, 5555)
			debug="wemo must be off"
		else
			storage.alerted = false
			storage.checked = true
			--enable switch
			--controlWemo(1, 5555)
			alert.email("Well done mate!")
			debug = "switch enabled"
		end
	else
		if time_zone > 18 then
			debug = "must check"
			if not checked then
				debug = "checking with fitbit"
				steps = check_fitbit()
				if tonumber(steps[1])<threshold then
					storage.alerted = true
					alert.email("You need to move your @$$ today!")
					debug = "checked below threshold"
				else
					storage.alerted = false
					storage.checked = true
					alert.email("Well done! "..tonumber(steps[1]).." steps so far today!")
					debug = "well done today!"
				end
			else
				debug = "already checked for today"
			end	
		end
	end
	steps = check_fitbit()
	
	return isAlerted..":"..storage.checked..":"..steps[1]..":"..time_zone..":"..debug
end


--main script execution starts here
if ACCESSTOKEN==nil and TOKENSECRET==nil then
	--get some credentials to work from fitbit
	local response = http.request {
	url='http://api.fitbit.com/oauth/access_token',
	auth = { oauth = {
			consumertoken = CONSUMERTOKEN,
			consumersecret = CONSUMERSECRET,
			accesstoken = request.query.oauth_token,
			tokensecret = storage['secret:'..request.query.oauth_token],
			verifier = request.query.oauth_verifier
		}}
	}
	local ret = http.qsparse(response.content)
	-- clean up
	storage['secret:'..request.query.oauth_token] = nil

	ACCESSTOKEN = ret.oauth_token
	TOKENSECRET = ret.oauth_token_secret	
	storage.accesstoken = ACCESSTOKEN
	storage.tokensecret = TOKENSECRET
	
	return docheck()
else
	--got oauth credentials, let's check fitbit stats:
	return docheck()
end
