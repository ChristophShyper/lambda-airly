import json
import os
import requests
import boto3

# parameters in environment variables passed by Terraform during deployment
api_key = os.environ.get('API_KEY')
base_url = os.environ.get('BASE_URL')
function_name = os.environ.get('FUNCTION_NAME', 'airly-api-notifications')  # for easier local testing
max_distance = os.environ.get('MAX_DISTANCE')
measurements_nearest = os.environ.get('MEASUREMENTS_NEAREST')
measurements_point = os.environ.get('MEASUREMENTS_POINT')
sns_topic_email = os.environ.get('SNS_TOPIC_EMAIL', '')
sns_topic_text = os.environ.get('SNS_TOPIC_TEXT', '')
use_interpolation = os.environ.get('USE_INTERPOLATION').lower() == 'true'

# global config
pollutants = [
    {'name': 'PM10', 'type': 'PM10', 'symbol': '\u2B1B'},
    {'name': 'PM25', 'type': 'PM2.5', 'symbol': '\u25FE'},
    {'name': 'PM1', 'type': 'PM1.0', 'symbol': '\u25AA'},
]
index_levels = [
    {'name': 'VERY_LOW', 'symbol': '\U0001F600'},
    {'name': 'LOW', 'symbol': '\U0001F609'},
    {'name': 'MEDIUM', 'symbol': '\U0001F612'},
    {'name': 'HIGH', 'symbol': '\U0001F616'},
    {'name': 'VERY_HIGH', 'symbol': '\U0001F621'}
]


# returns json payload of response call to airly api
def call_airly_api(apikey, interpolation, query_params=None):
    headers = {
        'content-type': 'application/json',
        'apikey': apikey
    }
    method = measurements_point if interpolation else measurements_nearest
    api_method = '{}{}'.format(base_url, method)
    print(' -> Calling API: {} with parameters: {}'.format(api_method, query_params))
    response = requests.get(api_method, headers=headers, params=query_params)
    # print(' -> API response: \n{}'.format(response.json()))
    return response.json()


# returns dict of query parameters to call airly api
def set_parameters(interpolation, location, distance):
    parameters = {}
    parameters['lat'] = location['lat']
    parameters['lng'] = location['lng']
    if not interpolation:
        parameters['maxDistanceKM'] = distance
    return parameters


# returns slick dict based on airly api response
def prepare_response(payload):
    response = {'indexes': []}
    for index in payload['current']['indexes']:
        response['indexes'].append({
            'name': index['name'],
            'level': index['level'],
            'symbol': [index_level['symbol'] for index_level in index_levels if index_level['name'] == index['level']][0],
            'description': index['description'],
            'advice': index['advice'],
        })
    response['pollutants'] = []
    for poll in pollutants:
        if poll['name'] in [value['name'] for value in payload['current']['values']]:
            percentage_available = True if poll['name'] in [standard['pollutant'] for standard in
                                                            payload['current']['standards']] else False
            percentage = str([standard['percent'] for standard in payload['current']['standards'] if
                              standard['pollutant'] == poll['name']][0]) + '%' if percentage_available else ''
            value = str([value['value'] for value in payload['current']['values'] if value['name'] == poll['name']][
                            0]) + 'µg/m³'
            response['pollutants'].append({
                'symbol': poll['symbol'],
                'type': poll['type'],
                'value': value,
                'percentage': percentage,
            })
    temperature_available = True if 'TEMPERATURE' in [value['name'] for value in
                                                      payload['current']['values']] else False
    temperature = str([value['value'] for value in payload['current']['values'] if value['name'] == 'TEMPERATURE'][
                      0]) + '°C' if temperature_available else ''
    pressure_available = True if 'PRESSURE' in [value['name'] for value in payload['current']['values']] else False
    pressure = str([value['value'] for value in payload['current']['values'] if value['name'] == 'PRESSURE'][
                   0]) + 'hPa' if pressure_available else ''
    humidity_available = True if 'HUMIDITY' in [value['name'] for value in payload['current']['values']] else False
    humidity = str([value['value'] for value in payload['current']['values'] if value['name'] == 'HUMIDITY'][
                   0]) + '%' if humidity_available else ''
    response['weather'] = []
    response['weather'].append({
        'symbol': '\U0001F321',
        'name': 'TEMPERATURE',
        'value': temperature
    }) if temperature_available else None
    response['weather'].append({
        'symbol': '\U0001F4C8',
        'name': 'PRESSURE',
        'value': pressure
    }) if pressure_available else None
    response['weather'].append({
        'symbol': '\U0001F4A7',
        'name': 'HUMIDITY',
        'value': humidity
    }) if humidity_available else None
    return response


# returns message for displaying as email
def prepare_email(payload):
    message = ''
    # payload['indexes'].pop(0)
    for index in payload['indexes']:
        message += '{ico} {name}: {level} - {descr} {adv}{sep}'.format(
            ico=index['symbol'],
            name=index['name'],
            level=index['level'],
            descr=index['description'],
            adv=index['advice'],
            sep='\n',
        )
    for poll in payload['pollutants']:
        percentage_available = True if poll['percentage'] != '' else False
        percentage = '({})'.format(poll['percentage']) if percentage_available else ''
        message += '{ico} {poll}: {val} {perc}{sep}'.format(
            ico=poll['symbol'],
            poll=poll['type'],
            val=poll['value'],
            perc=percentage,
            sep='\n',
        )
    for weather in payload['weather']:
        message += '{ico} {name}: {val}{sep}'.format(
            ico=weather['symbol'],
            name=weather['name'],
            val=weather['value'],
            sep='\n',
        )
    return message


# returns message for displaying as sms
def prepare_text(payload):
    message = '\n'  # needed for sms since it already begins with some string in first line
    # payload['indexes'].pop(0)
    for index in payload['indexes']:
        message += '{ico} {name}: {level}{sep}'.format(
            ico=index['symbol'],
            name=index['name'],
            level=index['level'],
            descr=index['description'],
            adv=index['advice'],
            sep='\n',
        )
    for poll in payload['pollutants']:
        percentage_available = True if poll['percentage'] != '' else False
        message += '{ico} {poll}: {perc}{sep}'.format(
            ico=poll['symbol'],
            poll=poll['type'],
            val=poll['value'],
            perc=poll['percentage'],
            sep='\n',
        ) if percentage_available else ''
    for weather in payload['weather']:
        message += '{ico} {name}: {val}{sep}'.format(
            ico=weather['symbol'],
            name=weather['name'],
            val=weather['value'],
            sep='\n',
        )
    return message


# sends message via sns
def send_sns_message(topic, subject, body):
    if subject is not None:
        response = boto3.client('sns').publish(
            TopicArn=topic,
            Message=body,
            Subject=subject if subject is not None else None,
        )
    else:
        response = boto3.client('sns').publish(
            TopicArn=topic,
            Message=body,
        )
    return response


def get_location(event):
    event_rule_name = event['resources'][0].split("/")[1]
    name_lat_lng = event_rule_name.replace("{}-".format(function_name), "").split("-")
    location = {
        'name': ' '.join(name_lat_lng[0:-2]),
        'lat': name_lat_lng[-2],
        'lng': name_lat_lng[-1],
    }
    return location


# main lambda handler
def handler(event, context):
    print(' -> Received event:\n{}'.format(event))
    location = get_location(event)
    print(' -> Using location: {}'.format(location))
    parameters = set_parameters(use_interpolation, location, max_distance)
    payload = call_airly_api(api_key, use_interpolation, parameters)
    response = prepare_response(payload)
    print(' -> Returned object:\n{}'.format(response))
    subject = '{ico} {location}: {descr}'.format(
        location=location['name'],
        name=response['indexes'][0]['name'],
        ico=response['indexes'][0]['symbol'],
        level=response['indexes'][0]['level'],
        descr=response['indexes'][0]['description'],
    )
    email = prepare_email(response)
    text = prepare_text(response)
    if sns_topic_email != "":
        print(' -> Sending email to SNS: {}'.format(sns_topic_email))
        print(' -> Email content: {}\n{}'.format(subject, email))
        send_sns_message(sns_topic_email, subject, email)
    if sns_topic_text != "":
        print(' -> Sending text to SNS: {}'.format(sns_topic_text))
        print(' -> Text content: {}'.format(text))
        send_sns_message(sns_topic_text, None, text)
    return response


# call from outside only locally for testing
if __name__ == '__main__':
    test_file = 'test.json'
    with open(test_file) as json_file:
        test_data = json.load(json_file)
    handler(test_data, {})
