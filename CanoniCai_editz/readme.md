pip install jaseci --upgrade
pip install jaseci-ai-kit --upgrade
pip install jaseci-serv --upgrade

Jsserv makemigrations base
Jsserv migrate
Jsserv runserver 0.0.0.0:8008

login http://0.0.0.0:8008/

actions load local local_app/twilio_bot.py
actions load local local_app/flow.py
actions load local local_app/cre_dataset.py

actions load module jaseci_ai_kit.tfm_ner
actions load module jaseci_ai_kit.use_qa
actions load module jaseci_ai_kit.use_enc
actions load module jaseci_ai_kit.bi_enc
actions load module jaseci_ai_kit.ent_ext
actions load module jaseci_ai_kit.cl_summer



graph delete active:graph
jac build _main.jac
graph create -set_active true
sentinel register -set_active true -mode ir _main.jir


walker run init

jac build _main.jac
sentinel set -snt active:sentinel -mode ir _main.jir
walker run init

graph get -mode dot -o .main.dot 
dot -Tpng .main.dot -o .main.png



## tfm_ner
jac run .tfm_ner.jac -walk train -ctx "{\"train_file\": \"local_app/data/ner_train.json\"}"
jac run tfm_ner.jac -walk infer

-- serv
waler run .tfm_ner.jac -walk train -ctx "{\"train_file\": \"local_app/data/ner_train.json\"}"
waler run .tfm_ner.jac -walk infer



// ## ent_ext use tfm_ner 
// jac run .ent_ext.jac -walk train_and_val_flair -ctx "{\"train_file\":\"local_app/data/que_dataset.json\",\"val_file\":\"local_app/data/que_dataset.json\",\"test_file\":\"local_app/data/que_dataset.json\",\"model_name\":\"prajjwal1/bert-tiny\",\"model_type\":\"trfmodel\",\"num_train_epochs\":\"10\",\"batch_size\":\"8\",\"learning_rate\":\"0.02\"}"
// jac run .ent_ext.jac -walk predict_flair -ctx "{\"text\":\"I would like to create an appointment. my son needs a manbun on saturday at 4 pm. \"}"

// -- serv
// walker run train_and_val_flair -ctx "{\"train_file\":\"local_app/data/que_dataset.json\",\"val_file\":\"local_app/data/que_dataset.json\",\"test_file\":\"local_app/data/que_dataset.json\",\"model_name\":\"prajjwal1/bert-tiny\",\"model_type\":\"trfmodel\",\"num_train_epochs\":\"20\",\"batch_size\":\"8\",\"learning_rate\":\"0.02\"}"
// walker run predict_flair -ctx "{\"text\":\"I would like to create an appointment. my son needs a manbun on saturday at 4 pm. \"}"


## bi_enc
jac run .bi_enc.jac -walk bi_encoder_train -ctx "{\"train_file\": \"local_app/data/_clf_dataset.json\"}"
jac run .bi_enc.jac -walk bi_encoder_infer -ctx "{\"labels\": [\"appointment\", \"i have a question\", \"cost of service\",\"yes\",\"no\"]}"
jac run .bi_enc.jac -walk bi_encoder_save_model -ctx "{\"model_path\": \"dialogue_intent_model\"}"
jac run .bi_enc.jac -walk bi_encoder_load_model -ctx "{\"model_path\": \"dialogue_intent_model\"}"

--serv
walker run bi_encoder_train -ctx "{\"train_file\": \"local_app/data/_clf_dataset.json\"}"
walker run bi_encoder_infer -ctx "{\"labels\": [\"appointment\", \"i have a question\", \"cost of service\",\"yes\",\"no\"]}"
walker run bi_encoder_save_model -ctx "{\"model_path\": \"dialogue_intent_model\"}"
walker run bi_encoder_load_model -ctx "{\"model_path\": \"dialogue_intent_model\"}"


walker run talker -ctx "{\"question\": \"how much for a mohawk\"}"
walker run talker -ctx "{\"question\": \"what time do you open\"}"
walker run talker -ctx "{\"question\": \"yes\"}"
walker run talker -ctx "{\"question\": \"hi\"}"
walker run talker -ctx "{\"question\": \"my son also want a haircut. I think he want a buzzcut on sunday at 5 pm. Can you set that up too\"}"




// walker run createGraph -ctx "{\"intent\": [\"greetings\", \"goodbye\", \"faq_question\"]}"
// walker run createGraph -ctx "{\"intent\": [\"greetings\", \"goodbye\", \"cost\",\"faq_question\",\"cancel\",\"appointment\"]}"
// walker run createGraph -ctx "{\"intent\": [\"greetings\", \"goodbye\", \"cost\"]}"
// walker run createGraph -ctx "{\"intent\": [\"greetings\", \"goodbye\", \"appointment\", \"cost\"]}"

