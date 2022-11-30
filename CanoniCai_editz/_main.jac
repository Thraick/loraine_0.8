import {*} with "./_globals.jac";
import {*} with "./.ent_ext.jac";
import {*} with "./.bi_enc.jac";
import {*} with "./_graphs.jac";
import {*} with "./_walkers.jac";


walker init{
    root{
        // spawn here --> node::user_state;
        // take --> node::user_state else: spawn here --> node::user_state;

        take --> node::cai_root else {
            spawn here --> graph::conv_graph;
            spawn here --> node::user_state;
            spawn here walker::ingest_faq(kb_file="local_app/data/faq_answer.json");

        }
        global.cai_root = here.info["jid"];
    }
}

walker talker {
    has question, user_id=1, start_new_dialogue = false, overwrite_intent = "", overwrite_entity = {};
    has hoping = true; # If the walker needs to make the transition
    has starting_state; # The starting dialogue state for this request
    has predicted_intent = ""; # predicted intent of the incoming question
    has intent_confidence = 0; # confidence of the intent prediction
    has extracted_entities = {}; # entities extracted from the question
    has user_context = {}; # contains user-specific profile data
    has dialogue_context = {}; # context of the current ongoing dialogue session
    has answer; # response 
    has state_for_continuing;
    has destination_state; # State for the walker to hop to after NLU
    has resp_payload = {}; # rich response payload
    has clf_to_use = "biencoder"; # Which classifier you want to use by setting node to either use_encoder or biencoder
    has phone_number;
    has ask_again = false;

    root {
        std.out('root');
        std.out(global.cai_root);
        take -->node::user_state;
    }
    user_state{
        std.out('user state');
        starting_state = here.last_conv_state['__mem_id__'];
        take starting_state;
    }
    state {
        std.out('state');
        // std.out(here.name);
        if (hoping) {
            hoping = false;
            take destination_state else {
                report {
                    "name": "out_of_scope",
                    "response": "Sorry I can't handle that just yet cai."
                };
            }
            std.out(here.name);
        } 
   }
}

walker maintainer {
    has user_id, user_context, dialogue_context, last_conv_state;
    root: take --> node::user_state;
}


