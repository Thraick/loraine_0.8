import {*} with "./_graphs.jac";
import {*} with "./_globals.jac";


walker question_data {
    can dataset.create_question;
    has question;
    has ivalues;
    has itypes;
    has file_name = "questions"; # name of question file

    report dataset.create_question(question,ivalues,itypes,file_name);
}


walker train_data {
    can dataset.create_dataset;
    has output_file;
    has question_file;

    report dataset.create_dataset(question_file, output_file);
}
 

walker faq_dataset {

    can dataset.create_faq;
    has question;
    has answer;
    has file_name = "faq_answer"; # name of question file

    report dataset.create_faq(question, answer, file_name);
}


walker state_data {
    can state.create_state;
    has state_name;
    has response = [];
    has extracted_item = {};
    has file_name = "state"; # name of question file
    has service_price = 'services_price';


    report state.create_state(state_name, response, extracted_item, file_name, service_price);
}
 
walker ingest_faq {
    has kb_file;

    root: take --> node::cai_root;
    cai_root{
        take --> node::faq_root;
    }
    faq_root {
        kb = file.load_json(kb_file);
        for faq in kb {
            answer = faq["answer"];
            spawn here --> node::faq_state(answer=answer);

        }
    }
}

walker createGraph{
    has intent = [];
    root{
        global.intent = intent;
        std.out(global.intent);

        take --> node::cai_root else {
            spawn here --> graph::conv_graph;
            global.cai_root = here.info["jid"];
            spawn here walker::ingest_faq(kb_file="local_app/data/faq_answer.json");
        }
        report global.intent;
    }
}

walker sample_walker: anyone {
    has fieldOne;
    with entry {
        report 1;
    }
}
