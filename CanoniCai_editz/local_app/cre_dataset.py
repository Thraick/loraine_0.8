"""
AUTO GENERATE TRAINING FILE FROM NER BASED ON THE UTTERANCE, SLOT TYPE AND VALUE YOU IMPUTTED.
"""
import json
import os

from jaseci.actions.live_actions import jaseci_action  # step 1

# load relative path
dir_path = os.path.dirname(os.path.realpath(__file__))



# take questions to create questions.json which will be used to create dataset. [walker question_data] >> [walker train_data]
@jaseci_action(act_group=["dataset"], allow_remote=True)
def create_question(iquestion:str, ivalue:list, itype:list, file_name:str):

    file = []
    open_json = str(dir_path)+'/data_example/'+file_name+'.json'
    with open(open_json, 'r') as f: data = json.load(f)

    for i in data: file.append(i)

    data_v = {
            "question": iquestion,
            "value": ivalue,
            "type": itype
    }

    file.append(data_v)
    with open(open_json, "w") as outfile: json.dump(file, outfile)

    return data_v
    




#  take questions and create a dataset 
@jaseci_action(act_group=["dataset"], allow_remote=True)
def create_dataset(question_data:str, output_name:str):
    

    open_json = str(dir_path)+'/data_example/'+question_data+'.json'
    file_name = str(dir_path)+'/data_example/'+output_name+'.json'

    with open(open_json, 'r') as f: data = json.load(f)

    que = []
    val = []
    typ = []
    for i in range(len(data)):
        que.append(data[i]["question"])
        typ.append(data[i]["type"])
        val.append(data[i]["value"])

    file = []
    run = True
    utter = []
    entities = []
    entit = []
    i =0

    while run:

        for i in range(len(que)):
            utterance = str(que[i])

            for n in range(len(val[i])):

                entity_value = str(val[i][n])
                entity_type = str(typ[i][n])
                if entity_value not in utterance:
                    print("ERROR ERROR:  value not in utterance")
                    print(utterance)
                    print(entity_value)

                start_index = utterance.index(entity_value)
                end_index = utterance.index(entity_value) + len(entity_value)
                
                entities.append ({
                    "entity_value": entity_value,
                    "entity_type": entity_type,
                    "start_index": start_index,
                    "end_index": end_index,
                })

            entit.append(entities[:])
            entities.clear()
            utter.append(utterance)

            for d in range(len(utter)):

                dataf = {
                    "context": data[d]["question"],
                    "entities": 
                        entit[d]
                }
            file.append(dataf)

        run = False
        with open(file_name, "w") as outfile:
            json.dump(file, outfile)

    print("\nDataset was created!\n")

    return (file_name, open_json)

##################################################
# actions load local local_app/cre_dataset.py
##################################################

# run file on server
if __name__ == "__main__":
    from jaseci.actions.remote_actions import launch_server

    launch_server(port=8000)


# take question and answer to create faq_answer.json
@jaseci_action(act_group=["dataset"], allow_remote=True)
def create_faq(question:str, answer:str, file_name:str):

    file = []
    open_json = str(dir_path)+'/data_example/'+file_name+'.json'
    with open(open_json, 'r') as f: data = json.load(f)

    for i in data: file.append(i)

    data_v = {
            "question": question,
            "answer": answer,
    }

    file.append(data_v)
    with open(open_json, "w") as outfile: json.dump(file, outfile)

    return data_v


    