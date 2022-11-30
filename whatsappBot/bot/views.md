# from email import message
import json
import string
from wsgiref import headers

import requests
from django.http import HttpResponse
from django.shortcuts import redirect
from django.views.decorators.csrf import csrf_exempt
from twilio.rest import Client
from twilio.twiml.messaging_response import (Body, Message, MessagingResponse,
                                             Redirect)

# Find your Account SID and Auth Token at twilio.com/console
# and set the environment variables. See http://twil.io/secure
account_sid = ''
auth_token = ''
client = Client(account_sid, auth_token)


auth="Token XXXXXXX"
sent="XXXXXXX"
url = "http://0.0.0.0:8008/js/walker_run"

@csrf_exempt
def bot(request):
    sender_message = request.POST["Body"],
    sender_number = request.POST["From"]


    payload = json.dumps({
        "name": "talker",
        "ctx": {
            "question": sender_message[0], 
            "phone_number":sender_number
            },
        "_req_ctx": {},
        "snt": sent,
        "profiling": False,
        "is_async": False
    })
    headers = {
    'Authorization': auth,
    'Content-Type': 'application/json'
    }

    response = requests.request("POST", url, headers=headers, data=payload)
    print(response.text)

    return HttpResponse(response)




get 

-account_sid
-auth_token 

from https://console.twilio.com/us1/account/keys-credentials/api-keys?frameUrl=%2Fconsole%2Fproject%2Fapi-keys%3Fx-target-region%3Dus1

update

-auth
-sent
-url

from jac server


change twilio_bot.md to twilio_bot.py