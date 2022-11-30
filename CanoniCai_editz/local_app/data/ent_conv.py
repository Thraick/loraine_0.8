# import os
# l = [
#     {
#         "context": "I just need a mohawk on monday at 1 pm",
#         "entities": [
#             {
#                 "entity_value": "mohawk",
#                 "entity_type": "haircut_style",
#                 "start_index": 14,
#                 "end_index": 20
#             },
#             {
#                 "entity_value": "monday",
#                 "entity_type": "dayofweek",
#                 "start_index": 24,
#                 "end_index": 30
#             },
#             {
#                 "entity_value": "1 pm",
#                 "entity_type": "time",
#                 "start_index": 34,
#                 "end_index": 38
#             }
#         ]
#     }]

# print(l)
# print(l[0]['context'].find('mohawk'))
# i = l[0]['context'].find('mohawk')

# ll = []

# for x in l:
#     for e in l[0]['entities']:
#         if e['entity_value'] in l[0]['context']:
#             ll.append(l[0]['context'].replace(
#                 e['entity_value'], '[' + e['entity_value'] + '] ' + '(' + e['entity_type'] + ')'))
# print(ll)

import json
import os


dir_path = os.path.dirname(os.path.realpath(__file__))


def convert(input, output):
    data = str(dir_path)+input
    out = str(dir_path)+output
    with open(data, 'r') as f: l = json.load(f)
    # with open(out, 'r') as f: lis = json.load(f)


    ll = []
    # print(data)


    for e in range(len(l)):
        # print(l[e]['context'])
        # for e in l[e]['entities']:
        # print(l[e]['entities'])
        for ent in range(len(l[e]['entities'])):
            # print(l[e]['entities'][ent])
            if l[e]['entities'][ent]['entity_value'] in l[e]['context']:
                # print('yes')
                val = l[e]['entities'][ent]['entity_value']
                typ = l[e]['entities'][ent]['entity_type']
                ll.append(l[e]['context'].replace(
                    val, '[' + val + '] ' + '(' + typ + ')'))
    
                
    
    with open(out, "w") as outfile: json.dump(ll, outfile)
    return ll




convert('/que_dataset.json', '/ner_train.json')
