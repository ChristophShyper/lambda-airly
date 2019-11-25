import json
import os
import requests

# parameters in env vars passed by Terraform during deployment
max_distance = os.environ.get('MAX_DISTANCE')
api_key = os.environ.get('API_KEY')
base_url = os.environ.get('BASE_URL')
measurements = os.environ.get('MEASUREMENTS')

# global config
pollutants = [
    {'name': 'PM10', 'type': ' PM10', 'symbol': '\u2593'},
    {'name': 'PM25', 'type': 'PM2.5', 'symbol': '\u2592'},
    {'name': 'PM1', 'type': 'PM1.0', 'symbol': '\u2591'},
]

# test parameters TODO: delete
test_file = 'test.json'
locations = [
    {
        'latlng': '#50.06170,19.93734',
        'name': 'Sukiennice',
    },
]


# returns json payload of response call to airly api
def call_airly_api(apikey, method, query_params=None):
    headers = {
        'content-type': 'application/json',
        'apikey': apikey
    }
    response = requests.get('{}/{}'.format(base_url, method), headers=headers, params=query_params)
    return response.json()


# returns dict of query parameters to call airly api
def set_parameters(location, distance):
    parameters = {
        'lat': location.replace('#', '').split(',')[0],
        'lng': location.split(',')[1],
        'maxDistanceKM': distance
    }
    return parameters


def prepare_response(payload):
    response = {'index': []}
    for index in payload['current']['indexes']:
        response['index'].append({
            'name': index['name'],
            'level': index['level'],
            'description': '{descr} {adv}'.format(
                descr=index['description'],
                adv=index['advice'],
            )
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
    print('resp: {}'.format(response))
    return response


def prepare_message(payload):
    message = ''
    for index in payload['current']['indexes']:
        message += '{name}: {level} - {descr} {adv}\n'.format(
            name=index['name'],
            level=index['level'],
            descr=index['description'],
            adv=index['advice'],
        )
        output['index'].append({
            'name': index['name'],
            'level': index['level'],
            'description': '{descr} {adv}'.format(
                descr=index['description'],
                adv=index['advice'],
            )
        })
    output['pollutants'] = []
    for poll in pollutants:
        if poll['name'] in [value['name'] for value in payload['current']['values']]:
            percentage_available = True if poll['name'] in [standard['pollutant'] for standard in
                                                            payload['current']['standards']] else False
            percentage = '(' + str([standard['percent'] for standard in payload['current']['standards'] if
                                    standard['pollutant'] == poll['name']][0]) + '%)' if percentage_available else ''
            value = str([value['value'] for value in payload['current']['values'] if value['name'] == poll['name']][
                            0]) + 'µg/m³'
            message += '{ico} {poll}: {val} {perc}{sep}'.format(
                ico=poll['symbol'],
                poll=poll['type'],
                val=value,
                perc=percentage,
                sep='\n',
            )
            output['pollutants'].append()
    temperature_available = True if 'TEMPERATURE' in [value['name'] for value in
                                                      payload['current']['values']] else False
    temperature = [value['value'] for value in payload['current']['values'] if value['name'] == 'TEMPERATURE'][
        0] if temperature_available else ''
    pressure_available = True if 'PRESSURE' in [value['name'] for value in payload['current']['values']] else False
    pressure = [value['value'] for value in payload['current']['values'] if value['name'] == 'PRESSURE'][
        0] if pressure_available else ''
    humidity_available = True if 'HUMIDITY' in [value['name'] for value in payload['current']['values']] else False
    humidity = [value['value'] for value in payload['current']['values'] if value['name'] == 'HUMIDITY'][
        0] if humidity_available else ''
    message += '\U0001F321 TEMPERATURE: {}°C \n'.format(temperature) if temperature_available else ''
    message += '\U0001F4C8 PRESSURE: {} hPa \n'.format(pressure) if pressure_available else ''
    message += '\U0001F4A7 HUMIDITY: {}% \n'.format(humidity) if temperature_available else ''
    print(message)
    return message, output


def handler(event, context):
    # print("Event: {}".format(event))
    params = set_parameters(locations[0]['latlng'], max_distance)
    payload = call_airly_api(api_key, measurements, params)
    response = prepare_response(payload)
    # print("{}".format(message))
    return payload


# call from outside only locally for testing
if __name__ == '__main__':
    with open(test_file) as json_file:
        test_data = json.load(json_file)
    handler(test_data, {})
