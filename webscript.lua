
local CONSUMERTOKEN = 'FITBIT APP TOKEN'
local CONSUMERSECRET = 'FITBIT APP KEY'
 
-- get a request token
local response = http.request {
	url = 'http://api.fitbit.com/oauth/request_token',
	params = { oauth_callback =
		'http://fitbit.webscript.io/callback' },
	auth = { oauth = {
			consumertoken = CONSUMERTOKEN,
			consumersecret = CONSUMERSECRET
		}}
}
 
local ret = http.qsparse(response.content)
 
-- store the token's secret for use in the callback
storage['secret:'..ret.oauth_token] = ret.oauth_token_secret
 
-- redirect the user to login at Fitbit
return 302, '', {
	Location=
	'http://api.fitbit.com/oauth/authorize?oauth_token='
	..ret.oauth_token
}
