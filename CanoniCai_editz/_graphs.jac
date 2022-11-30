import {*} with "./_globals.jac";

edge transition: has intent_label;

node user_state {
    has id;
    has profile = {};
    has dialogue_context = {};
    has last_conv_state = null;
    has load_from_api = "";

    can start_conv with talker entry {
        visitor.user_context = here.profile;
        if (here.last_conv_state == null) {
            here.last_conv_state = *(global.conv_root_state);
        }
        if(visitor.start_new_dialogue){
            here.dialogue_context = {};
            here.last_conv_state = *(global.conv_root_state);
        }

        visitor.starting_state = here.last_conv_state;
        visitor.dialogue_context = here.dialogue_context;
    }

    can update_with_conv with maintainer entry {
        here.profile.d::update(visitor.user_context);
        here.dialogue_context.d::update(visitor.dialogue_context);
        here.last_conv_state = visitor.last_conv_state;
    }
}

node state {
    has anchor name;
    has cand_intents = [];
    has terms_emb = {};
    has terms_ac = {};
    has terms_data;
    has study_prompt = "";
    has ans_respons = "";

    can use.encode, vector.cosine_sim;
    can bi_enc.get_context_emb, bi_enc.get_candidate_emb, bi_enc.infer;
    can vector.dot_product, vector.softmax;
    can ent_ext.entity_detection;
    can use.answer_encode;
    can use.question_encode;
    can use.text_classify;

    can state.gen_response;
    can twilio.twilio_bot;
    can state.events_list;


    can listen with talker entry {
        if (visitor.hoping) {
            ::classify_intent;
            ::extract_entities;
        }
    }

    can plan with talker entry {
        if (visitor.hoping) {
            std.out(here.name);
            if (visitor.ask_again){
                visitor.destination_state = here;
            }
            elif(visitor.predicted_intent){
                visitor.destination_state = -[transition(intent_label == visitor.predicted_intent)]->[0];
            }
            else{
                visitor.destination_state = here;
            }
        }
    }

    can think with talker entry {
        if (!visitor.hoping) {
            ::business_logic;
            # If this is a leaf node, return the root node as the node to continue from for next query
            ::collect_intents;
            if (here.cand_intents.length == 0)  {
                visitor.state_for_continuing = *(global.conv_root_state);
            } else {
                visitor.state_for_continuing = here;
            }
        }
    }

    can speak with talker entry {
        if (!visitor.hoping and here.name != "conv_root_state") {
            ::gen_response;

            report {
                "question": visitor.question,
                "name": here.name,
                "response": visitor.answer
            };
            global.info["request_context"];
        }
    }

    can cleanup with talker entry {
        if (!visitor.hoping) {
            spawn *(global.cai_root) walker::maintainer( 
                user_id = visitor.user_id,
                user_context = visitor.user_context,
                dialogue_context = visitor.dialogue_context,
                last_conv_state = visitor.state_for_continuing
            );
        }
    }

    can collect_intents {
        here.cand_intents = [];
        for i in -[transition]->.edge {
            here.cand_intents.l::append(i.intent_label);
        }
    }
    can classify_intent {
        if (visitor.hoping) {
            if (visitor.overwrite_intent != "") {
                visitor.predicted_intent = visitor.overwrite_intent;
                visitor.intent_confidence = 1;
            } else {
                if (visitor.clf_to_use == "biencoder") {
                    ::collect_intents;
                    std.out(here.cand_intents);
                    # Use the model to perform inference
                    # returns the list of context with the suitable candidates
                    resp_data = bi_enc.infer(
                        contexts=[visitor.question],
                        candidates=here.cand_intents,
                        context_type="text",
                        candidate_type="text"
                    );

                    # Iterate through the candidate labels and their predicted scores
                    max_score = 0;
                    max_intent = "";
                    pred=resp_data[0];

                    for j=0 to j<pred["candidate"].length by j+=1 {
                        if (pred["score"][j] > max_score){
                            max_intent = pred["candidate"][j];
                            max_score = pred["score"][j];
                        }
                    }
                    std.out(resp_data);
                    if(max_score > global.intent_confidence_threshold){
                        visitor.predicted_intent = max_intent;
                        visitor.intent_confidence = max_score;
                    }

                } elif (visitor.clf_to_use == "use_encoder") {
                    dataset = -[transition]->.edge.intent_label;
                    std.out(dataset);

                    resp_data = use.text_classify(visitor.question, dataset);
                    max_value = null;
                    std.out(resp_data);
                    for num in resp_data['scores']:
                        if(max_value == null or num > max_value): max_value = num;
                        
                    std.out(resp_data);
                    if(max_value > global.intent_confidence_threshold){
                        visitor.predicted_intent = resp_data['match'];
                        visitor.intent_confidence = max_value;
                    }
                } else {
                    yield report {"message": "missing/invalid data in clf_to_use for walker talker"};
                    disengage;
                }

                # for follow ups
                if (global.yes_label in here.cand_intents and global.no_label in here.cand_intents) {
                    # try use qa first
                    yes_prompt = "Yes";
                    no_prompt = "No";
                    q_emb = use.encode(visitor.question)[0];
                    yes_emb = use.encode(yes_prompt)[0];
                    no_emb = use.encode(no_prompt)[0];
                    yes_cos = vector.cosine_sim(q_emb, yes_emb);
                    no_cos = vector.cosine_sim(q_emb, no_emb);
                    max_score = 0;
                    pred_label = "";
                    if (yes_cos > no_cos) {
                        pred_label = global.yes_label;
                        max_score = yes_cos;
                        max_diff = (yes_cos - no_cos)/yes_cos;
                    } else {
                        pred_label = global.no_label;
                        max_score = no_cos;
                        max_diff = (no_cos - yes_cos)/no_cos;
                    }
                    if (max_score > 0.1) {
                        visitor.predicted_intent = pred_label;
                        visitor.intent_confidence = 1.0;
                    } else {
                        here.cand_intents = [];
                        for i in -[transition]->.edge {
                            if (i.intent_label not in [global.yes_label, global.no_label]){
                                here.cand_intents.l::append(i.intent_label);
                            }
                        }
                    }
                }
            }
        }
    }

    can extract_entities {
        if (visitor.overwrite_entity != {}) {
            visitor.extracted_entities = visitor.overwrite_entity;
        } else {
            entity_result = ent_ext.entity_detection(
                text=visitor.question, ner_labels=['haircut_style','time','dayofweek']
            );
            for ent in entity_result['entities'] {
                if (ent["conf_score"] > global.entity_confidence_threshold){
                    entity_label = ent["entity_value"];
                    entity_text = ent["entity_text"];
                    if (entity_label not in visitor.extracted_entities) {
                        visitor.extracted_entities[entity_label] = [];
                    }
                    visitor.extracted_entities[entity_label] += [entity_text];
                }
            }
        }
    }

    can business_logic {
        
        if (!visitor.hoping) {
            visitor.dialogue_context.dict::update(visitor.extracted_entities);
            if ("haircut_style" in visitor.extracted_entities) {
                visitor.dialogue_context["haircut_style"] = visitor.extracted_entities["haircut_style"];
            }elif ("dayofweek" in visitor.extracted_entities) {
                visitor.dialogue_context["dayofweek"] = visitor.extracted_entities["dayofweek"];
            }elif ("time" in visitor.extract_entities) {   
                visitor.dialogue_context["time"] = visitor.extracted_entities["time"];
            }
            time_dataset = file.load_json("local_app/data/time.json");
            if 'time' in visitor.dialogue_context{
                for time in visitor.dialogue_context["time"]{
                    ex_time = use.text_classify(time, time_dataset);
                    visitor.dialogue_context['time_format'] = [];
                    visitor.dialogue_context["time_format"] = [ex_time['match']];
                }
            }
        }
    }

    can gen_response {
        s_data = file.load_json("local_app/data/zstate.json");
        for i in s_data{
            if (!visitor.hoping) {
                if (here.name == i["state"].str){
                    std.out(visitor.dialogue_context);
                    ans = state.gen_response(i["state"],i["response"],i["extracted_item"], visitor.dialogue_context,i["service_price"]);
                    visitor.answer = ans[0];
                    if (ans.length > 2){
                        visitor.dialogue_context['dayofweek'] = [ans[1]];
                        visitor.dialogue_context['time'] = [ans[2]];
                        visitor.ask_again = true;
                    }
                    elif(ans.length > 1){
                        if (ans[1]){
                            visitor.dialogue_context['appt_id'] = [ans[1]];
                            id = visitor.dialogue_context['appt_id'][0];
                            htime = state.events_list(id);
                            visitor.dialogue_context['htime']=[htime];
                        }   
                    }
                    twilio.twilio_bot(visitor.answer, visitor.phone_number);
                }
            }
        }
    } 

}

node cai_root:state;
node cost:state;
 

node soc:state{

    can listen with talker entry {
    }

    can plan with talker entry {
        visitor.destination_state = *(global.conv_root_state);
    }

    can think with talker entry {
        visitor.state_for_continuing = *(global.conv_root_state);
    }

    can speak with talker entry {
        if (!visitor.hoping and here.name != "conv_root_state") {
            ::gen_response;

            report {
                "question": visitor.question,
                "name": here.name,
                "response": visitor.answer
            };
        }
        std.out('test work\n\n');
        global.info["request_context"];
    }

    can cleanup with talker entry {
        if (!visitor.hoping) {
            spawn *(global.cai_root) walker::maintainer( 
                user_id = visitor.user_id,
                user_context = visitor.user_context,
                dialogue_context = visitor.dialogue_context,
                last_conv_state = visitor.state_for_continuing
            );
        }
    }

}
node eoc:state{
    can listen with talker entry {
    }

    can plan with talker entry {
        visitor.destination_state = *(global.conv_root_state);
    }

    can think with talker entry {
        visitor.state_for_continuing = *(global.conv_root_state);
    }

    can speak with talker entry {
        if (!visitor.hoping and here.name != "conv_root_state") {
            ::gen_response;

            report {
                "question": visitor.question,
                "name": here.name,
                "response": visitor.answer
            };
        }
    }

    can cleanup with talker entry {
        if (!visitor.hoping) {
            spawn *(global.cai_root) walker::maintainer( 
                user_id = visitor.user_id,
                user_context = visitor.user_context,
                dialogue_context = visitor.dialogue_context,
                last_conv_state = visitor.state_for_continuing
            );
        }
    }
    
}

node appointment:state;
node appt_confirm:state{
    can listen with talker entry {
    }

    can plan with talker entry {
        visitor.destination_state = *(global.conv_root_state);
    }

    can think with talker entry {
        visitor.state_for_continuing = *(global.conv_root_state);
    }

    can speak with talker entry {
        if (!visitor.hoping and here.name != "conv_root_state") {
            ::gen_response;

            report {
                "question": visitor.question,
                "name": here.name,
                "response": visitor.answer
            };
        }
    }

    can cleanup with talker entry {
        if (!visitor.hoping) {
            spawn *(global.cai_root) walker::maintainer( 
                user_id = visitor.user_id,
                user_context = visitor.user_context,
                dialogue_context = visitor.dialogue_context,
                last_conv_state = visitor.state_for_continuing
            );
        }
    }
    
}

node appt_denial:state{
    can listen with talker entry {
    }

    can plan with talker entry {
        visitor.destination_state = *(global.conv_root_state);
    }

    can think with talker entry {
        visitor.state_for_continuing = *(global.conv_root_state);
    }

    can speak with talker entry {
        if (!visitor.hoping and here.name != "conv_root_state") {
            ::gen_response;

            report {
                "question": visitor.question,
                "name": here.name,
                "response": visitor.answer
            };
        }
    }

    can cleanup with talker entry {
        if (!visitor.hoping) {
            spawn *(global.cai_root) walker::maintainer( 
                user_id = visitor.user_id,
                user_context = visitor.user_context,
                dialogue_context = visitor.dialogue_context,
                last_conv_state = visitor.state_for_continuing
            );
        }
    }
    
}


node cancel_appt:state;
node cancel_confirm:state{
    can state.cancel_event;
    can listen with talker entry {
        if('appt_id' in visitor.dialogue_context){
            eventId = visitor.dialogue_context['appt_id'][0];
            state.cancel_event(eventId);
        }
        
    }

    can plan with talker entry {
        visitor.destination_state = *(global.conv_root_state);
    }

    can think with talker entry {
        visitor.state_for_continuing = *(global.conv_root_state);
    }

    can speak with talker entry {
        if (!visitor.hoping and here.name != "conv_root_state") {
            ::gen_response;

            report {
                "question": visitor.question,
                "name": here.name,
                "response": visitor.answer
            };
        }
    }

    can cleanup with talker entry {
        if (!visitor.hoping) {
            spawn *(global.cai_root) walker::maintainer( 
                user_id = visitor.user_id,
                user_context = visitor.user_context,
                dialogue_context = visitor.dialogue_context,
                last_conv_state = visitor.state_for_continuing
            );
        }
    }
    
}
node cancel_denial:state{
    can listen with talker entry {
        // if (visitor.hoping) {
        //     std.out('state listen');
        //     ::classify_intent;
        //     ::extract_entities;
        // }
    }

    can plan with talker entry {
        // if (visitor.hoping) {
        //     if (visitor.ask_again){
        //         visitor.destination_state = here;
        //     }
        //     elif(visitor.predicted_intent){
        //         visitor.destination_state = -[transition(intent_label == visitor.predicted_intent)]->[0];
        //     }
        //     else{
        //         visitor.destination_state = -[faq_root]->[0];
        //     }
        //     // else{
        //     //     visitor.destination_state = -[transition(intent_label == visitor.predicted_intent)]->[0];
        //     // }
        // }
        visitor.destination_state = *(global.conv_root_state);
    }

    can think with talker entry {
        // if (!visitor.hoping) {
        //     ::business_logic;
        //     # If this is a leaf node, return the root node as the node to continue from for next query
        //     ::collect_intents;
        //     if (here.cand_intents.length == 0)  {
        //         visitor.state_for_continuing = *(global.conv_root_state);
        //     } else {
        //         visitor.state_for_continuing = here;
        //     }
        // }
        visitor.state_for_continuing = *(global.conv_root_state);
    }

    can speak with talker entry {
        if (!visitor.hoping and here.name != "conv_root_state") {
            ::gen_response;

            report {
                "question": visitor.question,
                "name": here.name,
                "response": visitor.answer
            };
        }
    }

    can cleanup with talker entry {
        if (!visitor.hoping) {
            // global.state_for_continuing = visitor.state_for_continuing;

            spawn *(global.cai_root) walker::maintainer( 
                user_id = visitor.user_id,
                user_context = visitor.user_context,
                dialogue_context = visitor.dialogue_context,
                last_conv_state = visitor.state_for_continuing
            );
        }
    }
    
}


node faq_root:state{
    can use.qa_classify;
    can twilio.twilio_bot;

    can listen with talker entry {
        answers = -->.answer;
        best_answer = use.qa_classify(
            text = visitor.question,
            classes = answers
        );
        std.out(best_answer);
        score = global.faq_score;
        nn = best_answer['match_idx'];
        if (best_answer['scores'][nn] > score){
            visitor.answer = best_answer['match'];
        }
    }

    can plan with talker entry {
        if(visitor.state_for_continuing){
            std.out('contimue work');
            visitor.destination_state = visitor.state_for_continuing;
        }else:visitor.destination_state = *(global.conv_root_state);
    }

    can think with talker entry {
        visitor.state_for_continuing = *(global.conv_root_state);
    }

    can speak with talker entry {
        if (!visitor.hoping and here.name != "conv_root_state") {
            twilio.twilio_bot(visitor.answer, visitor.phone_number);


            report {
                "question": visitor.question,
                "name": here.name,
                "response": visitor.answer
            };
        }
    }

    can cleanup with talker entry {
        if (!visitor.hoping) {
            spawn *(global.cai_root) walker::maintainer( 
                user_id = visitor.user_id,
                user_context = visitor.user_context,
                dialogue_context = visitor.dialogue_context,
                last_conv_state = visitor.state_for_continuing
            );
        }
    }
    
}
node faq_state{
    has name = 'faq state';
    has question;
    has answer;
}




 graph conv_graph {
    has anchor conv_root;
    spawn {
        conv_root = spawn node::cai_root(name="conv_root_state");
        global.conv_root_state = conv_root.info["jid"];
        std.out("global root id: "+global.conv_root_state);
        

        state_soc = spawn node::soc(name="soc");
        state_eoc = spawn node::eoc(name="eoc");
        // std.out("soc id: "+ state_soc.info["jid"]);

        state_order = spawn node::appointment(name="appointment");
        state_order_confirmation = spawn node::appt_confirm(name="appointment_confirmation");
        state_order_denial = spawn node::appt_denial(name="appointment_denial");
        

        state_cancel = spawn node::cancel_appt(name="appointment_cancel");
        cancel_confirmation = spawn node::cancel_confirm(name="cancel_confirmation");
        cancel_denial = spawn node::cancel_denial(name="cancel_denial");
        
        state_cost = spawn node::cost(name="cost");
        faq_root = spawn node::faq_root(name="faq_root");

        global_states = [
            [state_soc, "greetings"],
            [state_eoc, "goodbye"],
            [state_order, "appointment"],
            [state_cost, "cost"],
            [faq_root, "faq_question"]
        ];

        conv_root -[transition(intent_label = "greetings")]-> state_soc;
        conv_root -[transition(intent_label = "goodbye")]-> state_eoc;
        conv_root -[transition(intent_label = "appointment")]-> state_order;
        conv_root -[transition(intent_label = "cost")]-> state_cost;
        conv_root -[transition(intent_label = "cancel")]-> state_cancel;
        conv_root -[transition(intent_label= "faq_question")]-> faq_root;

        state_cancel -[transition(intent_label = "confirmation")]-> cancel_confirmation;
        state_cancel -[transition(intent_label = "denial")]-> cancel_denial;
        state_cancel -[transition(intent_label= "faq_question")]-> faq_root;


        state_order -[transition(intent_label = "confirmation")]-> state_order_confirmation;
        state_order -[transition(intent_label = "denial")]-> state_order_denial;

        for gstate in global_states {
            state_order -[transition(intent_label = gstate[1])]-> gstate[0];
        }
    }
}




// graph conv_graph {
//     has anchor conv_root;
    
//     spawn {
//         std.out("graph");
//         std.out(global.intent);
//         conv_root = spawn node::cai_root(name="conv_root_state");
//         global.conv_root_state = conv_root.info["jid"];

//         # State of Conversation
//         if ( global.soc_label in global.intent){
//             state_soc = spawn node::soc(name="soc");
//             conv_root -[transition(intent_label = global.soc_label)]-> state_soc;
//         }
//         # End of Conversation
//         if ( global.eoc_label in global.intent){
//             state_eoc = spawn node::eoc(name="eoc");
//             conv_root -[transition(intent_label = global.eoc_label)]-> state_eoc;
//         }
//         # Cost
//         if (global.cost_label in global.intent){
//             state_cost = spawn node::cost(name="cost");
//             conv_root -[transition(intent_label = global.cost_label)]-> state_cost;
//         }
//         # Faq
//         if (global.faq_label in global.intent){
//             faq_root = spawn node::faq_root(name="faq_root");
//             conv_root -[transition(intent_label= global.faq_label)]-> faq_root;
//         }
//         # Appointment
//         if (global.order_label in global.intent){
//             state_order = spawn node::appointment(name="appointment");
//             state_order_confirmation = spawn node::appt_confirm(name="appointment_confirmation");
//             state_order_denial = spawn node::appt_denial(name="appointment_denial");
            
//             conv_root -[transition(intent_label = global.order_label)]-> state_order;
//             state_order -[transition(intent_label = global.yes_label)]-> state_order_confirmation;
//             state_order -[transition(intent_label = global.no_label)]-> state_order_denial;
            
//             if (global.cost_label in global.intent){
//                 state_order -[transition(intent_label = global.cost_label)]-> state_cost;
//             }

//             if (global.faq_label in global.intent){
//                 state_order -[transition(intent_label= global.faq_label)]-> faq_root;
//             }
//         }
//         # Appointment Cancel
//         if (global.cancel_label in global.intent){
//             state_cancel = spawn node::cancel_appt(name="appointment_cancel");
//             cancel_confirmation = spawn node::cancel_confirm(name="cancel_confirmation");
//             cancel_denial = spawn node::cancel_denial(name="cancel_denial");
            
//             conv_root -[transition(intent_label = global.cancel_label)]-> state_cancel;
//             state_cancel -[transition(intent_label = global.yes_label)]-> cancel_confirmation;
//             state_cancel -[transition(intent_label = global.no_label)]-> cancel_denial;

//             if (global.faq_label in global.intent){
//                 state_cancel -[transition(intent_label= global.faq_label)]-> faq_root;
//             }
//         }
        

        

//         // state_soc = spawn node::soc(name="soc");
//         // state_eoc = spawn node::eoc(name="eoc");

//         // state_order = spawn node::appointment(name="appointment");
//         // state_order_confirmation = spawn node::appt_confirm(name="appointment_confirmation");
//         // state_order_denial = spawn node::appt_denial(name="appointment_denial");
        

//         // state_cancel = spawn node::cancel_appt(name="appointment_cancel");
//         // cancel_confirmation = spawn node::cancel_confirm(name="cancel_confirmation");
//         // cancel_denial = spawn node::cancel_denial(name="cancel_denial");
        
//         // state_cost = spawn node::cost(name="cost");
//         // faq_root = spawn node::faq_root(name="faq_root");

//         // global_states = [
//         //     [state_soc, global.soc_label],
//         //     [state_eoc, global.eoc_label],
//         //     [state_order, global.order_label],
//         //     [state_cost, global.cost_label],
//         //     [faq_root, global.faq_label]
//         // ];

//         // conv_root -[transition(intent_label = global.soc_label)]-> state_soc;
//         // conv_root -[transition(intent_label = global.eoc_label)]-> state_eoc;
//         // conv_root -[transition(intent_label = global.order_label)]-> state_order;
//         // conv_root -[transition(intent_label = global.cost_label)]-> state_cost;
//         // conv_root -[transition(intent_label = global.cancel_label)]-> state_cancel;
//         // conv_root -[transition(intent_label= global.faq_label)]-> faq_root;

//         // state_cancel -[transition(intent_label = global.yes_label)]-> cancel_confirmation;
//         // state_cancel -[transition(intent_label = global.no_label)]-> cancel_denial;
//         // state_cancel -[transition(intent_label= global.faq_label)]-> faq_root;


//         // state_order -[transition(intent_label = global.yes_label)]-> state_order_confirmation;
//         // state_order -[transition(intent_label = global.no_label)]-> state_order_denial;

//         // for gstate in global_states {
//         //     state_order -[transition(intent_label = gstate[1])]-> gstate[0];
//         // }
//     }
// }
