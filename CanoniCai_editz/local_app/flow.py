import datetime
import os
import pickle
from collections import namedtuple

from google.auth.transport.requests import Request
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build


def Create_Service(client_secret_file, api_name, api_version, *scopes, prefix=''):
	CLIENT_SECRET_FILE = client_secret_file
	API_SERVICE_NAME = api_name
	API_VERSION = api_version
	SCOPES = [scope for scope in scopes[0]]
	
	cred = None
	working_dir = os.getcwd()
	token_dir = 'token files'
	pickle_file = f'token_{API_SERVICE_NAME}_{API_VERSION}{prefix}.pickle'

	### Check if token dir exists first, if not, create the folder
	if not os.path.exists(os.path.join(working_dir, token_dir)):
		os.mkdir(os.path.join(working_dir, token_dir))

	if os.path.exists(os.path.join(working_dir, token_dir, pickle_file)):
		with open(os.path.join(working_dir, token_dir, pickle_file), 'rb') as token:
			cred = pickle.load(token)

	if not cred or not cred.valid:
		if cred and cred.expired and cred.refresh_token:
			cred.refresh(Request())
		else:
			flow = InstalledAppFlow.from_client_secrets_file(CLIENT_SECRET_FILE, SCOPES)
			cred = flow.run_local_server()

		with open(os.path.join(working_dir, token_dir, pickle_file), 'wb') as token:
			pickle.dump(cred, token)

	try:
		service = build(API_SERVICE_NAME, API_VERSION, credentials=cred)
		print(API_SERVICE_NAME, API_VERSION, 'service created successfully')
		return service
	except Exception as e:
		print(e)
		print(f'Failed to create service instance for {API_SERVICE_NAME}')
		os.remove(os.path.join(working_dir, token_dir, pickle_file))
		return None

def convert_to_RFC_datetime(year=1900, month=1, day=1, hour=0, minute=0):
	dt = datetime.datetime(year, month, day, hour, minute, 0).isoformat() + 'Z'
	return dt

class GoogleSheetsHelper:
	# --> spreadsheets().batchUpdate()
	Paste_Type = namedtuple('_Paste_Type', 
					('normal', 'value', 'format', 'without_borders', 
					 'formula', 'date_validation', 'conditional_formatting')
					)('PASTE_NORMAL', 'PASTE_VALUES', 'PASTE_FORMAT', 'PASTE_NO_BORDERS', 
					  'PASTE_FORMULA', 'PASTE_DATA_VALIDATION', 'PASTE_CONDITIONAL_FORMATTING')

	Paste_Orientation = namedtuple('_Paste_Orientation', ('normal', 'transpose'))('NORMAL', 'TRANSPOSE')

	Merge_Type = namedtuple('_Merge_Type', ('merge_all', 'merge_columns', 'merge_rows')
					)('MERGE_ALL', 'MERGE_COLUMNS', 'MERGE_ROWS')

	Delimiter_Type = namedtuple('_Delimiter_Type', ('comma', 'semicolon', 'period', 'space', 'custom', 'auto_detect')
						)('COMMA', 'SEMICOLON', 'PERIOD', 'SPACE', 'CUSTOM', 'AUTODETECT')

	# --> Types
	Dimension = namedtuple('_Dimension', ('rows', 'columns'))('ROWS', 'COLUMNS')

	Value_Input_Option = namedtuple('_Value_Input_Option', ('raw', 'user_entered'))('RAW', 'USER_ENTERED')

	Value_Render_Option = namedtuple('_Value_Render_Option',["formatted", "unformatted", "formula"]
							)("FORMATTED_VALUE", "UNFORMATTED_VALUE", "FORMULA")
                            
	@staticmethod
	def define_cell_range(
		sheet_id, 
		start_row_number=1, end_row_number=0, 
		start_column_number=None, end_column_number=0):
		"""GridRange object"""
		json_body = {
			'sheetId': sheet_id,
			'startRowIndex': start_row_number - 1,
			'endRowIndex': end_row_number,
			'startColumnIndex': start_column_number - 1,
			'endColumnIndex': end_column_number
		}
		return json_body

	@staticmethod
	def define_dimension_range(sheet_id, dimension, start_index, end_index):
		json_body = {
			'sheetId': sheet_id,
			'dimension': dimension,
			'startIndex': start_index,
			'endIndex': end_index
		}
		return json_body


class GoogleCalendarHelper:
	...

class GoogleDriverHelper:
	...



if __name__ == '__main__':
	g = GoogleSheetsHelper()
	print(g.Delimiter_Type)


########################################################################################################################################################################
########################################################################################################################################################################
########################################################################################################################################################################
########################################################################################################################################################################
########################################################################################################################################################################
########################################################################################################################################################################
########################################################################################################################################################################
########################################################################################################################################################################
########################################################################################################################################################################
########################################################################################################################################################################
########################################################################################################################################################################






import json
import random
from datetime import datetime, timedelta

import pytz
from dateutil import parser
from jaseci.actions.live_actions import jaseci_action  # step 1

CLIENT_SECREATE_FILE = 'local_app/credentials/credentials.json'
API_NAME = 'Calendar'
API_VERSION = 'v3'
SCOPES = ['https://www.googleapis.com/auth/calendar']

service = Create_Service(CLIENT_SECREATE_FILE, API_NAME, API_VERSION, SCOPES)


################################################################################################################################################
################################################################################################################################################

def cal_list():
    page_token = None
    while True:
        calendar_list = service.calendarList().list(pageToken=page_token).execute()
        for calendar_list_entry in calendar_list['items']:
            print(calendar_list_entry['id'])

        page_token = calendar_list.get('nextPageToken')
        if not page_token:
            break
        return calendar_list_entry['id']

# print(cal_list())

def delete_event(eventId):
    o = service.events().delete(calendarId='primary', eventId=eventId).execute()
    return o

def get_events(eventId):
    event = service.events().get(calendarId='primary', eventId=eventId).execute()
    # print (event['summary'])
    e=event['start']['dateTime']
    a = datetime.fromisoformat(e)
    htime = a.strftime("%A, %d %B, at %I:%M %p")

    return htime

# d = get_events(eventId='71qrs0h4hl63mte8ljvco33f5c')

# g = d['start']['dateTime']

# a = datetime.fromisoformat(g)
# print(a.strftime("%A, %d %B, at %I:%M %p"))


################################################################################################################################################
################################################################################################################################################


def create_event(name: str, location: str, description: str, start, end):
    # print('create event')
    start_datetime = start
    stop_datetime = end

    event = {
        'summary': name,
        'location': location,
        'description': description,
        'start': {
            'dateTime': start_datetime.isoformat(),
            'timeZone': 'US/Eastern',
        },
        'end': {
            'dateTime': stop_datetime.isoformat(),
            'timeZone': 'US/Eastern',
        },
        'attendees': [
            {'email': 'lpage@example.com'}
        ]
    }

    event = service.events().insert(calendarId='primary', body=event).execute()

# create_event("testname","testlocation","testdescription",datetime(2022, 10, 1, 1),datetime(2022, 10, 1, 3))

################################################################################################################################################
################################################################################################################################################

def freebusy(start_date, end_date):
    # print("freebusy")

    body = {
        "timeMin": start_date,
        "timeMax": end_date,
        "timeZone": 'US/Eastern',
        "items": [{
            "id": "jtharick@gmail.com"
        }],
    }
    eventsResult = service.freebusy().query(body=body).execute()

    try:
        array = eventsResult["calendars"]['jtharick@gmail.com']['busy'][0]
    except IndexError:
        array = None

    if array:
        # print("busy")
        end = array['end']
        d = parser.isoparse(end)
        dd = parser.isoparse(end)
        d += timedelta(hours=1)
        dd += timedelta(hours=2)

        aval_start = d.isoformat()
        aval_end = dd.isoformat()
        return (True, aval_start, aval_end)
    else:
        # print('free')
        return (False, start_date, end_date)


def check_availability(starttime, endtime):
    # print('check availablility')
    
    busy = freebusy(starttime, endtime)
    print(busy)

    while busy[0]:
        busy = freebusy(busy[1], busy[2])

    return (busy)


# avail = check_availability(the_datetime.isoformat(), the_datetime2.isoformat())
# print(avail)
# print(the_datetime.isoformat(), the_datetime2.isoformat())
# print(avail[1], avail[2])




################################################################################################################################################
################################################################################################################################################


dow = {"monday":0, "tuesday":1, "Wednesday":2, "thursday":3, "friday":4, "saturday":5, "sunday":6}
day="sunday"
time = "5:00 pm"


def daytodate(dateo:str, time:str): 
    # print('daytodate')
    if dateo.lower() == "tomorrow":
        d = parser.parse(time)
        timezone = pytz.timezone("US/Eastern")
        new_date = timezone.localize(d)
    else:
        d = parser.parse(time)
        timezone = pytz.timezone("US/Eastern")
        todayo = timezone.localize(d)
        weekday_idx = dow[dateo.lower()]
        new_date = todayo + timedelta(days=(weekday_idx - todayo.weekday() + 7) % 7)
    return (new_date.isoformat())

 
# res = daytodate(day, time)
# print(res[0])
# print("Next date of required weekday : " + str(res))


def conv_date(re):
    re
    d = parser.isoparse(re)
    d += timedelta(hours=1)
    start = re
    end = d.isoformat()

    return(start, end)


################################################################################################################################################
################################################################################################################################################


def quickadd(text:str):
    created_event = service.events().quickAdd(
        calendarId='jtharick@gmail.com',
        text=text).execute()
        
    return created_event['id']

# print(quickadd("Appointment at Somewhere on June 3rd 10am-10:25am"))


################################################################################################################################################
################################################################################################################################################

# check available date from day
def cal_date(ext_date, ext_time):

    #get date for day
    res = daytodate(ext_date, ext_time)
    # get start and end time
    time = conv_date(res)
    # check availablility 
    avail = check_availability(time[0], time[1])

    if time[0] == avail[1]:
        aval = True
    else:
        aval = False

    return (aval, avail)


# c = cal_date(day, time)
# print(c)
dir_path = os.path.dirname(os.path.realpath(__file__))



@jaseci_action(act_group=["state"], allow_remote=True)
def create_state(state:str, response:list, extract:dict, file_name:str, service_price:str):
    file = []
    open_json = str(dir_path)+'/data_example/'+file_name+'.json'
    with open(open_json, 'r') as f: data = json.load(f)

    for i in data: file.append(i) 
    data_v = {
            "state": state,
            "response": response,
            "extracted_item": extract,
            "service_price":service_price+'.json'
    }
    file.append(data_v)
    with open(open_json, "w") as outfile: json.dump(file, outfile)
    return data_v
    
    
@jaseci_action(act_group=["state"], allow_remote=True)
def gen_response(state_name:str,response:list, ext:dict, dial_context:dict,service_price:str):

    if (state_name == "appointment"):
        if 'dayofweek' in dial_context and 'time_format' in dial_context:
            aval_check = cal_date(dial_context['dayofweek'][0], dial_context['time_format'][0])

            if not aval_check[0] and not aval_check[1][0]:
                dtime = datetime.fromisoformat( aval_check[1][1])
                tm = dtime.strftime("%A, %d %B, at %I:%M %p")
                answer = "Sorry that date is not available. The next available date is " + tm
                aval_day = dtime.strftime("%A")
                aval_time = dtime.strftime("%I:%M %p")
                return [answer, aval_day, aval_time]
        
    open_json = str(dir_path)+'/data/'+service_price
    mydic = {}
    re = None
    for l in dial_context:
        mydic[l]=dial_context[l][0]
        if (state_name == "cost"):
            with open(open_json) as f:
                services = json.load(f)
            for s in services:
                if s['name'] in mydic['haircut_style']:
                    mydic["cost"]=s["price"]
    num_missing = 0
    l2 = None
    for e in ext:
        if e not in dial_context.keys():
            answer = random.choice(ext[e])
            num_missing += 1
            break
    else: answer = random.choice(response)
    if num_missing == 0 :
        rand = random.choice(response)
        l1 = rand.replace('{{','{')
        l2 = l1.replace('}}','}')
        answer = l2.format(**mydic)
    if (state_name == "appointment_confirmation"):
        re = quickadd(answer)
    return [answer, re]

 

# if __name__ == "__main__":
#     from jaseci.actions.remote_actions import launch_server
#     launch_server(port=8000)


@jaseci_action(act_group=["state"], allow_remote=True)
def cancel_event(eventId):
    delete_event(eventId)

    return True



@jaseci_action(act_group=["state"], allow_remote=True)
def events_list(eventId):
    print('id '+ str(eventId))
    t = get_events(eventId)

    return t
